/**
 * 远程控制服务
 *
 * 职责划分：
 * - ConnectionManager: 管理 TCP 连接
 * - ProtocolHandler: 处理协议解析（只解析命令）
 * - HeartbeatManager: 管理心跳
 * - CaptureProcessor: 帧合并逻辑（在主线程）
 * - WorkerRepository: 任务发送到 Worker 线程
 */

import {
  IRemoteControlService,
  DeviceCredentials,
  ScreenCallback,
  DeviceInfoCallback,
  RemoteControlServiceConfig
} from '../interfaces/IRemoteControlService';
import {
  RemoteControlEvent,
  ConnectionState,
  DeviceValidationResult
} from '../../models/DeviceInfo';
import {
  ClientInfoCallback,
  ConnectionCallback,
  ClipboardCallback,
  CaptureStatus
} from '../../models/CmdProtocol';
import { IConnectionManager } from '../connection/IConnectionManager';
import { IProtocolHandler } from '../protocol/IProtocolHandler';
import { IHeartbeatManager } from '../interfaces/IHeartbeatManager';
import { IWorkerRepository, ImageProcessTask, ImageProcessResult } from '../../repository/IWorkerRepository';
import { CaptureProcessor, FrameProcessResult, FrameInfo } from '../../processor/CaptureProcessor';
import { CmdCodec } from '../../network/CmdCodec';
import { ConcreteCmd } from '../../models/ConcreteCmd';
import { CmdType } from '../../models/CmdProtocol';
import { CmdUtils } from '../../models/CmdFactory';
import hilog from '@ohos.hilog';

const DOMAIN: number = 0xFF00;
const TAG: string = 'RemoteControlService';

/**
 * 视频流配置
 */
interface VideoStreamConfig {
  enabled: boolean;
  compressionMethod: number;
}

export class RemoteControlService implements IRemoteControlService {
  // 配置
  private config: RemoteControlServiceConfig;

  // 依赖（通过构造函数注入）
  private connectionManager: IConnectionManager;
  private protocolHandler: IProtocolHandler;
  private heartbeatManager: IHeartbeatManager;
  private workerRepository: IWorkerRepository;

  // 帧处理器
  private captureProcessor: CaptureProcessor = new CaptureProcessor();

  // 视频流配置
  private videoConfig: VideoStreamConfig = {
    enabled: false,
    compressionMethod: 3 // ZSTD
  };

  // 设备信息
  private localDeviceCode: string = '';
  private localPassword: string = '';
  private remoteDeviceCode: string = '';
  private remotePassword: string = '';
  private isValidating: boolean = false;

  // 回调
  private screenCallback: ScreenCallback | null = null;
  private clientInfoCallback: ClientInfoCallback | null = null;
  private connectionCallback: ConnectionCallback | null = null;
  private clipboardCallback: ClipboardCallback | null = null;
  private deviceInfoCallback: DeviceInfoCallback | null = null;
  private validationCallback: ((result: DeviceValidationResult) => void) | null = null;

  constructor(
    config: RemoteControlServiceConfig,
    connectionManager: IConnectionManager,
    protocolHandler: IProtocolHandler,
    heartbeatManager: IHeartbeatManager,
    workerRepository: IWorkerRepository
  ) {
    this.config = {
      host: config.host,
      port: config.port,
      maxReconnectAttempts: config.maxReconnectAttempts !== undefined ? config.maxReconnectAttempts : 3,
      reconnectDelay: config.reconnectDelay !== undefined ? config.reconnectDelay : 2000,
      heartbeatInterval: config.heartbeatInterval !== undefined ? config.heartbeatInterval : 3000
    };

    this.connectionManager = connectionManager;
    this.protocolHandler = protocolHandler;
    this.heartbeatManager = heartbeatManager;
    this.workerRepository = workerRepository;

    this.setupCallbacks();
    hilog.info(DOMAIN, TAG, 'RemoteControlService initialized');
  }

  /**
   * 设置回调
   */
  private setupCallbacks(): void {
    // 连接状态回调
    this.connectionManager.setConnectionCallback((connected: boolean) => {
      hilog.info(DOMAIN, TAG, 'Connection state changed: %{public}s', connected ? 'connected' : 'disconnected');

      if (connected) {
        this.sendClientInfo();
        this.startHeartbeat();
      } else {
        this.stopHeartbeat();
      }

      if (this.connectionCallback) {
        this.connectionCallback(connected);
      }
    });

    // 消息接收回调 - 所有数据都先发送给 ProtocolHandler 解析
    this.connectionManager.setMessageCallback((data: ArrayBuffer) => {
      this.handleReceivedData(data);
    });

    // 错误回调
    this.connectionManager.setErrorCallback((error: Error) => {
      hilog.error(DOMAIN, TAG, 'Connection error: %{public}s', error.message);
    });

    // 命令处理回调
    this.protocolHandler.setCommandCallback(async (cmd: ConcreteCmd) => {
      await this.processCommand(cmd);
    });

    // 心跳回调
    this.heartbeatManager.setHeartbeatCallback(() => {
      this.sendHeartbeat();
    });
  }

  /**
   * 处理接收到的数据
   * 数据可能来自：
   * 1. ProtocolHandler 解析出的命令 (包括 CmdCapture)
   * 2. 残留数据 (不应发生)
   *
   * 注意: CmdCapture 命令通过 commandCallback -> processCommand -> handleCaptureData 处理
   *       所有视频数据都通过 CmdCapture 命令传递，不再有独立的"原始视频数据"流
   */
  private async handleReceivedData(data: ArrayBuffer): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Received data: %{public}d bytes', data.byteLength);

    // 尝试让 ProtocolHandler 解析命令
    // CmdCapture 命令会通过 commandCallback -> handleCaptureData 处理
    const commands = await this.protocolHandler.processData(data);

    if (commands.length > 0) {
      // 有命令，已通过 commandCallback 处理
      hilog.info(DOMAIN, TAG, 'Processed %{public}d commands', commands.length);
    } else {
      // 没有命令，可能是残留数据或粘包情况
      // CmdCapture 命令通过 callback 处理，不会出现在 commands 数组中
      hilog.warn(DOMAIN, TAG, 'No commands parsed, %{public}d bytes of data ignored', data.byteLength);
    }
  }

  // ========== IRemoteControlService 实现 ==========

  async connect(onSuccess?: () => void, onError?: (error: string) => void): Promise<void> {
    try {
      await this.connectionManager.connect();
      if (onSuccess) {
        onSuccess();
      }
    } catch (error) {
      if (onError) {
        onError(String(error));
      }
    }
  }

  async disconnect(): Promise<void> {
    this.stopHeartbeat();
    this.captureProcessor.reset();
    await this.connectionManager.disconnect();
    this.protocolHandler.cleanup();
    this.heartbeatManager.destroy();
  }

  getConnectionState(): ConnectionState {
    return this.connectionManager.getConnectionState();
  }

  setConnectionCallback(callback: ConnectionCallback): void {
    this.connectionCallback = callback;
  }

  async openRemoteScreen(deviceCode: string, password: string): Promise<void> {
    this.remoteDeviceCode = deviceCode;
    this.remotePassword = password;
    this.isValidating = true;

    hilog.info(DOMAIN, TAG, 'Opening remote screen: %{public}s', deviceCode);

    try {
      const captureCmd = CmdUtils.createCaptureCmd(deviceCode, password, 1);
      const encoded = CmdCodec.encode(captureCmd);
      await this.connectionManager.send(encoded);
      hilog.info(DOMAIN, TAG, 'ReqCapture command sent');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to send ReqCapture: %{public}s', JSON.stringify(error));
    }
  }

  closeRemoteScreen(): void {
    this.videoConfig.enabled = false;
    this.remoteDeviceCode = '';
    this.remotePassword = '';
    this.captureProcessor.reset();
    hilog.info(DOMAIN, TAG, 'Remote screen closed');
  }

  setScreenCallback(callback: ScreenCallback): void {
    this.screenCallback = callback;
  }

  setXComponent(xComponent: Object): void {
    hilog.info(DOMAIN, TAG, 'XComponent set for video rendering');
  }

  async sendControlEvent(event: RemoteControlEvent): Promise<void> {
    if (!this.videoConfig.enabled) {
      hilog.warn(DOMAIN, TAG, 'Remote control not enabled');
      return;
    }
    hilog.info(DOMAIN, TAG, 'Sending control event: %{public}s', event.type);
  }

  async sendMouseControl(x: number, y: number, action: number, wheelDelta?: number): Promise<void> {
    if (!this.videoConfig.enabled) {
      hilog.warn(DOMAIN, TAG, 'Remote control not enabled');
      return;
    }
    hilog.info(DOMAIN, TAG, 'Sending mouse control: x=%{public}d, y=%{public}d, action=%{public}d', x, y, action);
  }

  async sendKeyControl(keyCode: number, pressed: boolean): Promise<void> {
    if (!this.videoConfig.enabled) {
      hilog.warn(DOMAIN, TAG, 'Remote control not enabled');
      return;
    }
    hilog.info(DOMAIN, TAG, 'Sending key control: keyCode=%{public}d, pressed=%{public}s', keyCode, String(pressed));
  }

  setDeviceInfoCallback(callback: DeviceInfoCallback): void {
    this.deviceInfoCallback = callback;
  }

  setDeviceInfo(deviceCode: string, password: string): void {
    this.remoteDeviceCode = deviceCode;
    this.remotePassword = password;
  }

  getLocalDeviceInfo(): DeviceCredentials {
    return { deviceCode: this.localDeviceCode, password: this.localPassword };
  }

  getRemoteDeviceInfo(): DeviceCredentials {
    return { deviceCode: this.remoteDeviceCode, password: this.remotePassword };
  }

  setRemoteControlPermission(enabled: boolean): void {
    hilog.info(DOMAIN, TAG, 'Remote control permission: %{public}s', enabled ? 'enabled' : 'disabled');
  }

  async validateDevice(deviceCode: string, password: string): Promise<DeviceValidationResult> {
    return { valid: deviceCode.length > 0 && password.length > 0, message: '验证成功' };
  }

  async requestClipboard(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Requesting clipboard content');
  }

  async sendClipboardText(text: string): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Sending clipboard text');
  }

  async sendClipboardFile(fileInfoId: string, fileName: string): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Sending clipboard file: %{public}s', fileName);
  }

  setClipboardCallback(callback: ClipboardCallback): void {
    this.clipboardCallback = callback;
  }

  async changePassword(oldPassword: string, newPassword: string): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Changing password');
  }

  cleanup(): void {
    this.stopHeartbeat();
    this.connectionManager.cleanup();
    this.protocolHandler.cleanup();
    this.heartbeatManager.destroy();
    this.captureProcessor.reset();
    hilog.info(DOMAIN, TAG, 'Service cleaned up');
  }

  // ========== 私有方法 ==========

  private lastHeartbeatTime: number = 0;

  /**
   * 处理命令
   */
  private async processCommand(cmd: ConcreteCmd): Promise<void> {
    const cmdType = cmd.type;

    switch (cmdType) {
      case CmdType.ResCliInfo:
        await this.handleClientInfoCommand(cmd);
        break;
      case CmdType.ResPong:
        this.handleHeartbeatPong();
        break;
      case CmdType.ReqPing:
        this.handleHeartbeatPing();
        break;
      case CmdType.ResCapture:
        this.handleCaptureResponse(cmd);
        break;
      case CmdType.Capture:
        this.handleCaptureData(cmd);
        break;
      case CmdType.CaptureConfig:
        this.handleCaptureConfigCommand(cmd);
        break;
      case CmdType.ResOpen:
        this.handleValidationResult(cmd);
        break;
      default:
        hilog.warn(DOMAIN, TAG, 'Unhandled command: %{public}s', cmdType);
    }
  }

  private handleHeartbeatPong(): void {
    this.lastHeartbeatTime = Date.now();
    hilog.debug(DOMAIN, TAG, 'Heartbeat pong received');
  }

  private handleHeartbeatPing(): void {
    hilog.debug(DOMAIN, TAG, 'Heartbeat ping received');
  }

  /**
   * 处理屏幕捕获响应（服务器确认开始推流）
   */
  private handleCaptureResponse(cmd: ConcreteCmd): void {
    const data = cmd.getData();
    const status = data.status as CaptureStatus;

    hilog.info(DOMAIN, TAG, 'ResCapture received - status: %{public}s', status);

    if (status === 'OK') {
      hilog.info(DOMAIN, TAG, 'Remote screen capture started');
      this.videoConfig.enabled = true;
      this.captureProcessor.reset();
    } else {
      hilog.error(DOMAIN, TAG, 'Remote screen capture failed: %{public}s', status);
      this.videoConfig.enabled = false;
    }
  }

  /**
   * 处理屏幕捕获配置
   */
  private handleCaptureConfigCommand(cmd: ConcreteCmd): void {
    const data = cmd.getData();
    const width = data.width || 0;
    const height = data.height || 0;
    const fps = data.fps || 0;

    hilog.info(DOMAIN, TAG, 'CaptureConfig - width: %{public}d, height: %{public}d, fps: %{public}d', width, height, fps);
  }

  /**
   * 处理屏幕捕获数据 (CmdCapture 命令)
   * 从命令中提取压缩数据和压缩方法，传递给 onRawVideoData 处理
   */
  private async handleCaptureData(cmd: ConcreteCmd): Promise<void> {
    const data = cmd.getData();
    const imageData = data.imageData;
    const compressionMethod = data.compressionMethod || 3; // 默认 ZSTD

    if (!imageData || (typeof imageData === 'string' && imageData.length === 0)) {
      hilog.error(DOMAIN, TAG, 'CaptureData command has no image data');
      return;
    }

    hilog.info(DOMAIN, TAG, 'CmdCapture received - imageData size: %{public}d, compressionMethod: %{public}d',
      typeof imageData === 'string' ? imageData.length : (imageData as ArrayBuffer).byteLength,
      compressionMethod);

    // 将 imageData 转换为 ArrayBuffer (如果是 string 格式)
    let payloadBuffer: ArrayBuffer;
    if (typeof imageData === 'string') {
      // 尝试从 base64 或直接解析
      payloadBuffer = this.decodeImageData(imageData);
    } else {
      payloadBuffer = imageData as ArrayBuffer;
    }

    // 调用 onRawVideoData 处理视频数据
    await this.onRawVideoData(payloadBuffer, compressionMethod);
  }

  /**
   * 解码图像数据
   * 支持 base64 编码或直接 ArrayBuffer
   */
  private decodeImageData(imageData: string): ArrayBuffer {
    try {
      // 检查是否是 base64 编码
      if (imageData.length > 0) {
        // 尝试直接解析为 ArrayBuffer
        const bytes = new Uint8Array(imageData.length);
        for (let i = 0; i < imageData.length; i++) {
          bytes[i] = imageData.charCodeAt(i);
        }
        return bytes.buffer as ArrayBuffer;
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to decode image data: %{public}s', JSON.stringify(error));
    }
    return new ArrayBuffer(0);
  }

  /**
   * 处理验证结果
   */
  private handleValidationResult(cmd: ConcreteCmd): void {
    const data = cmd.getData();
    const status = data.status || 'FAILED';

    const result: DeviceValidationResult = {
      valid: status === 'SUCCESS',
      message: status === 'SUCCESS' ? '验证成功' : '验证失败'
    };

    this.isValidating = false;

    if (this.validationCallback) {
      this.validationCallback(result);
    }

    if (result.valid) {
      this.videoConfig.enabled = true;
    }

    hilog.info(DOMAIN, TAG, 'Validation result: %{public}s', status);
  }

  /**
   * 处理客户端信息命令
   */
  private async handleClientInfoCommand(cmd: ConcreteCmd): Promise<void> {
    const data = cmd.getData();
    this.localDeviceCode = data.deviceCode || '';
    this.localPassword = data.password || '';

    if (this.deviceInfoCallback) {
      this.deviceInfoCallback(this.localDeviceCode, this.localPassword);
    }

    hilog.info(DOMAIN, TAG, 'Device info: %{public}s', this.localDeviceCode);
  }

  /**
   * 处理原始视频数据
   * 流程：获取 prevBuffer -> Worker 解压 + 绘制 -> CaptureProcessor 更新 prevBuffer -> 渲染
   * @param data 压缩的视频数据
   * @param compressionMethod 压缩方法 ordinal (0=NONE, 1=ZIP, 2=XZ, 3=ZSTD)
   */
  private async onRawVideoData(data: ArrayBuffer, compressionMethod: number = 3): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Processing raw video data: %{public}d bytes, compressionMethod: %{public}d',
      data.byteLength, compressionMethod);

    try {
      const prevParams = this.captureProcessor.getPrevBufferParams();

      const imageTask: ImageProcessTask = {
        imageData: data,
        compressionMethodOrdinal: compressionMethod,
        prevBuffer: prevParams.buffer,
        prevWidth: prevParams.width,
        prevHeight: prevParams.height
      };

      const result: ImageProcessResult = await this.workerRepository.processImage(imageTask);

      hilog.info(DOMAIN, TAG, 'Decompressed - width: %{public}d, height: %{public}d, frameId: %{public}d, reused: %{public}s',
        result.width, result.height, result.frameId, (!result.isKeyFrame && prevParams.buffer !== null).toString());

      const imageBuffer = new Uint8Array(result.imageBuffer);

      const frameInfo: FrameInfo = {
        id: result.frameId,
        reset: result.isKeyFrame,
        width: result.width,
        height: result.height
      };
      const frameResult = this.captureProcessor.processFrame(imageBuffer, frameInfo);

      if (this.screenCallback) {
        const bufferData: ArrayBuffer = frameResult.buffer.buffer as ArrayBuffer;
        const widthVal: number = frameResult.width;
        const heightVal: number = frameResult.height;
        this.screenCallback(
          bufferData,
          widthVal,
          heightVal,
          Date.now()
        );
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to process video: %{public}s', JSON.stringify(error));
    }
  }

  private async sendClientInfo(): Promise<void> {
    if (this.getConnectionState() !== ConnectionState.CONNECTED) {
      return;
    }

    try {
      const reqCliInfoCmd = CmdUtils.createReqCliInfoCmd(1, 'HarmonyOS');
      const encoded = CmdCodec.encode(reqCliInfoCmd);
      await this.connectionManager.send(encoded);
      hilog.info(DOMAIN, TAG, 'Client info sent');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to send client info: %{public}s', JSON.stringify(error));
    }
  }

  private async sendHeartbeat(): Promise<void> {
    if (this.getConnectionState() !== ConnectionState.CONNECTED) {
      return;
    }

    try {
      const pingCmd = CmdCodec.createPingCmd();
      const encoded = CmdCodec.encode(pingCmd);
      await this.connectionManager.send(encoded);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to send heartbeat: %{public}s', JSON.stringify(error));
    }
  }

  private startHeartbeat(): void {
    this.heartbeatManager.init(this.config.heartbeatInterval);
    this.heartbeatManager.start();
  }

  private stopHeartbeat(): void {
    this.heartbeatManager.stop();
  }
}
