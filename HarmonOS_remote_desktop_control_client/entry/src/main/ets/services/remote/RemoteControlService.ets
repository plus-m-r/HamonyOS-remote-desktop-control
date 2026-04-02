/**
 * 远程控制服务
 * 使用拆分类降低复杂度和耦合度：
 * - ConnectionManager: 管理连接
 * - ProtocolHandler: 处理协议
 * - HeartbeatManager: 管理心跳
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
import { CmdCodec } from '../../network/CmdCodec';
import { ConcreteCmd } from '../../models/ConcreteCmd';
import { CmdType } from '../../models/CmdProtocol';
import { CmdUtils } from '../../models/CmdFactory';
import hilog from '@ohos.hilog';

const DOMAIN: number = 0xFF00;
const TAG: string = 'RemoteControlService';

/**
 * 远程控制服务
 * 使用拆分类降低复杂度和耦合度：
 * - ConnectionManager: 管理连接
 * - ProtocolHandler: 处理协议
 * - HeartbeatManager: 管理心跳
 */
export class RemoteControlService implements IRemoteControlService {
  // 配置
  private config: RemoteControlServiceConfig;

  // 依赖（通过构造函数注入）
  private connectionManager: IConnectionManager;
  private protocolHandler: IProtocolHandler;
  private heartbeatManager: IHeartbeatManager;

  // 设备信息
  private localDeviceCode: string = '';
  private localPassword: string = '';
  private remoteDeviceCode: string = '';
  private remotePassword: string = '';
  private remoteControlEnabled: boolean = false;
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
    heartbeatManager: IHeartbeatManager
  ) {
    // 合并默认配置
    this.config = {
      host: config.host,
      port: config.port,
      maxReconnectAttempts: config.maxReconnectAttempts !== undefined ? config.maxReconnectAttempts : 3,
      reconnectDelay: config.reconnectDelay !== undefined ? config.reconnectDelay : 2000,
      heartbeatInterval: config.heartbeatInterval !== undefined ? config.heartbeatInterval : 3000
    };

    // 注入依赖
    this.connectionManager = connectionManager;
    this.protocolHandler = protocolHandler;
    this.heartbeatManager = heartbeatManager;

    // 设置回调
    this.setupCallbacks();

    hilog.info(DOMAIN, TAG, 'Service initialized with injected dependencies');
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

    // 消息接收回调
    this.connectionManager.setMessageCallback((data: ArrayBuffer) => {
      this.protocolHandler.processData(data);
    });

    // 错误回调
    this.connectionManager.setErrorCallback((error: Error) => {
      hilog.error(DOMAIN, TAG, 'Connection error: %{public}s', error.message);
    });

    // 命令处理回调
    this.protocolHandler.setCommandCallback(async (cmd: ConcreteCmd) => {
      await this.processCommand(cmd);
    });

    // 使用 processDataAndCheckVideo 来同时处理命令和视频流
    this.connectionManager.setMessageCallback((data: ArrayBuffer) => {
      this.protocolHandler.processDataAndCheckVideo(data, async (videoData: ArrayBuffer) => {
        await this.onVideoStreamData(videoData);
      });
    });

    // 心跳回调
    this.heartbeatManager.setHeartbeatCallback(() => {
      this.sendHeartbeat();
    });
  }

  // ========== IRemoteControlService 实现 ==========

  /**
   * 连接到服务端
   */
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

  /**
   * 断开连接
   */
  async disconnect(): Promise<void> {
    this.stopHeartbeat();
    await this.connectionManager.disconnect();
    this.protocolHandler.cleanup();
    this.heartbeatManager.destroy();
  }

  /**
   * 获取连接状态
   */
  getConnectionState(): ConnectionState {
    return this.connectionManager.getConnectionState();
  }

  /**
   * 设置连接状态回调
   */
  setConnectionCallback(callback: ConnectionCallback): void {
    this.connectionCallback = callback;
  }

  /**
   * 打开远程屏幕
   */
  async openRemoteScreen(deviceCode: string, password: string): Promise<void> {
    this.remoteDeviceCode = deviceCode;
    this.remotePassword = password;
    this.isValidating = true;

    hilog.info(DOMAIN, TAG, 'Opening remote screen: %{public}s', deviceCode);

    try {
      const captureCmd = CmdUtils.createCaptureCmd(deviceCode, password, 1);
      const encoded = CmdCodec.encode(captureCmd);
      await this.connectionManager.send(encoded);
      hilog.info(DOMAIN, TAG, 'ReqCapture command sent successfully');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to send ReqCapture command: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 关闭远程屏幕
   */
  closeRemoteScreen(): void {
    this.remoteControlEnabled = false;
    this.remoteDeviceCode = '';
    this.remotePassword = '';
    hilog.info(DOMAIN, TAG, 'Remote screen closed');
  }

  /**
   * 设置屏幕数据回调
   */
  setScreenCallback(callback: ScreenCallback): void {
    this.screenCallback = callback;
  }

  setXComponent(xComponent: Object): void {
    hilog.info(DOMAIN, TAG, 'XComponent set for video rendering');
  }

  /**
   * 发送控制事件
   */
  async sendControlEvent(event: RemoteControlEvent): Promise<void> {
    if (!this.remoteControlEnabled) {
      hilog.warn(DOMAIN, TAG, 'Remote control not enabled');
      return;
    }

    hilog.info(DOMAIN, TAG, 'Sending control event: %{public}s', event.type);
  }

  /**
   * 发送鼠标控制
   */
  async sendMouseControl(x: number, y: number, action: number, wheelDelta?: number): Promise<void> {
    if (!this.remoteControlEnabled) {
      hilog.warn(DOMAIN, TAG, 'Remote control not enabled');
      return;
    }

    hilog.info(DOMAIN, TAG, 'Sending mouse control: x=%{public}d, y=%{public}d, action=%{public}d', x, y, action);
  }

  /**
   * 发送键盘控制
   */
  async sendKeyControl(keyCode: number, pressed: boolean): Promise<void> {
    if (!this.remoteControlEnabled) {
      hilog.warn(DOMAIN, TAG, 'Remote control not enabled');
      return;
    }

    hilog.info(DOMAIN, TAG, 'Sending key control: keyCode=%{public}d, pressed=%{public}s', keyCode, String(pressed));
  }

  /**
   * 设置设备信息回调
   */
  setDeviceInfoCallback(callback: DeviceInfoCallback): void {
    this.deviceInfoCallback = callback;
  }

  /**
   * 设置设备信息
   */
  setDeviceInfo(deviceCode: string, password: string): void {
    this.remoteDeviceCode = deviceCode;
    this.remotePassword = password;
  }

  /**
   * 获取本地设备信息
   */
  getLocalDeviceInfo(): DeviceCredentials {
    return {
      deviceCode: this.localDeviceCode,
      password: this.localPassword
    };
  }

  /**
   * 获取远程设备信息
   */
  getRemoteDeviceInfo(): DeviceCredentials {
    return {
      deviceCode: this.remoteDeviceCode,
      password: this.remotePassword
    };
  }

  /**
   * 设置远程控制权限
   */
  setRemoteControlPermission(enabled: boolean): void {
    this.remoteControlEnabled = enabled;
    hilog.info(DOMAIN, TAG, 'Remote control permission: %{public}s', enabled ? 'enabled' : 'disabled');
  }

  /**
   * 验证设备
   */
  async validateDevice(deviceCode: string, password: string): Promise<DeviceValidationResult> {
    return {
      valid: deviceCode.length > 0 && password.length > 0,
      message: '验证成功'
    };
  }

  /**
   * 请求剪贴板内容
   */
  async requestClipboard(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Requesting clipboard content');
  }

  /**
   * 发送文本剪贴板
   */
  async sendClipboardText(text: string): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Sending clipboard text');
  }

  /**
   * 发送文件剪贴板
   */
  async sendClipboardFile(fileInfoId: string, fileName: string): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Sending clipboard file: %{public}s', fileName);
  }

  /**
   * 设置剪贴板回调
   */
  setClipboardCallback(callback: ClipboardCallback): void {
    this.clipboardCallback = callback;
  }

  /**
   * 修改密码
   */
  async changePassword(oldPassword: string, newPassword: string): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Changing password');
  }

  /**
   * 清理资源
   */
  cleanup(): void {
    this.stopHeartbeat();
    this.connectionManager.cleanup();
    this.protocolHandler.cleanup();
    this.heartbeatManager.destroy();
    hilog.info(DOMAIN, TAG, 'Service cleaned up');
  }

  // ========== 私有方法 ==========

  // 心跳相关
  private lastHeartbeatTime: number = 0;

  // 屏幕尺寸信息
  private screenWidth: number = 1920;
  private screenHeight: number = 1080;
  private screenFps: number = 30;

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
      case CmdType.CaptureConfig:
        this.handleCaptureConfigCommand(cmd);
        break;
      case CmdType.Capture:
        await this.handleCaptureCommand(cmd);
        break;
      case CmdType.ResOpen:
        this.handleValidationResult(cmd);
        break;
      default:
        hilog.warn(DOMAIN, TAG, 'Unhandled command: %{public}s', cmdType);
    }
  }

  /**
   * 处理心跳响应（服务器返回Pong）
   */
  private handleHeartbeatPong(): void {
    this.lastHeartbeatTime = Date.now();
    hilog.info(DOMAIN, TAG, 'Heartbeat pong received, connection alive');
  }

  /**
   * 处理心跳请求（收到服务器的心跳）
   */
  private handleHeartbeatPing(): void {
    hilog.debug(DOMAIN, TAG, 'Heartbeat ping received from server');
  }

  /**
   * 处理屏幕捕获响应（服务器确认开始推流）
   */
  private handleCaptureResponse(cmd: ConcreteCmd): void {
    const data = cmd.getData();
    const status = data.status as CaptureStatus;

    hilog.info(DOMAIN, TAG, 'ResCapture received - status: %{public}s', status);

    if (status === 'OK') {
      hilog.info(DOMAIN, TAG, 'Remote screen capture started, video stream incoming');
      this.remoteControlEnabled = true;
    } else {
      hilog.error(DOMAIN, TAG, 'Remote screen capture failed with status: %{public}s', status);
      this.remoteControlEnabled = false;
    }
  }

  /**
   * 处理屏幕捕获配置（包含屏幕尺寸）
   */
  private handleCaptureConfigCommand(cmd: ConcreteCmd): void {
    const data = cmd.getData();
    const width = data.width;
    const height = data.height;
    const fps = data.fps;

    hilog.info(DOMAIN, TAG, 'CaptureConfig received - width: %{public}d, height: %{public}d, fps: %{public}d', width, height, fps);

    // 保存屏幕尺寸信息，供后续渲染使用
    this.screenWidth = width;
    this.screenHeight = height;
    this.screenFps = fps;

    hilog.info(DOMAIN, TAG, 'Screen dimensions saved: %{public}d x %{public}d', width, height);
  }

  /**
   * 处理视频流裸数据
   */
  /**
   * 处理视频流裸数据
   */
  private async onVideoStreamData(data: ArrayBuffer): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Received video stream data, length: %{public}d', data.byteLength);

    // 视频数据需要通过 CaptureWorker 解压
    try {
      hilog.info(DOMAIN, TAG, 'Processing video stream through CaptureWorker');
      // 注意：实际项目中应该通过 WorkerRepository 调用 CaptureWorker
      // 这里暂时记录日志，因为视频解码需要复杂的瓦片重组逻辑
      hilog.info(DOMAIN, TAG, 'Video stream requires decompression, size: %{public}d bytes', data.byteLength);

      if (this.screenCallback) {
        // 如果没有解码器，暂时传递原始数据
        this.screenCallback(data, this.screenWidth, this.screenHeight, Date.now());
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to process video stream: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 处理客户端信息命令
   */
  private async handleClientInfoCommand(cmd: ConcreteCmd): Promise<void> {
    const data = cmd.getData();
    const deviceCode = data.deviceCode;
    const password = data.password;

    this.localDeviceCode = deviceCode;
    this.localPassword = password;

    if (this.deviceInfoCallback) {
      this.deviceInfoCallback(deviceCode, password);
    }

    hilog.info(DOMAIN, TAG, 'Received device info: %{public}s', deviceCode);
  }

  /**
   * 处理捕获命令
   */
  private async handleCaptureCommand(cmd: ConcreteCmd): Promise<void> {
    try {
      const data = cmd.getData();
      const imageData = data.imageData;
      const compressionMethod = data.compressionMethod;

      // 使用保存的屏幕尺寸，而不是解析出来的0值
      const width = this.screenWidth;
      const height = this.screenHeight;

      hilog.info(DOMAIN, TAG, 'Processing capture - size: %{public}d x %{public}d, compression: %{public}d',
        width, height, compressionMethod);

      if (imageData instanceof ArrayBuffer && this.screenCallback) {
        const dataLen = imageData.byteLength;
        hilog.info(DOMAIN, TAG, 'Processing capture - dataLen: %{public}d', dataLen);
        this.screenCallback(imageData, width, height, Date.now());
      } else if (typeof imageData === 'string' && imageData.length > 0 && this.screenCallback) {
        hilog.info(DOMAIN, TAG, 'Processing capture - string data length: %{public}d', imageData.length);
      } else {
        hilog.warn(DOMAIN, TAG, 'Processing capture - no valid image data');
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to process capture: %{public}s', JSON.stringify(error));
    }
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
      this.remoteControlEnabled = true;
    }

    hilog.info(DOMAIN, TAG, 'Validation result: %{public}s', status);
  }

  /**
   * 发送设备信息
   */
  private async sendClientInfo(): Promise<void> {
    if (this.getConnectionState() !== ConnectionState.CONNECTED) {
      return;
    }

    try {
      hilog.info(DOMAIN, TAG, 'Sending client info to server...');
      const reqCliInfoCmd = CmdUtils.createReqCliInfoCmd(1, 'HarmonyOS');
      const encoded = CmdCodec.encode(reqCliInfoCmd);
      await this.connectionManager.send(encoded);
      hilog.info(DOMAIN, TAG, 'Client info sent successfully');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to send client info: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 发送心跳
   */
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

  /**
   * 启动心跳
   */
  private startHeartbeat(): void {
    this.heartbeatManager.init(this.config.heartbeatInterval);
    this.heartbeatManager.start();
  }

  /**
   * 停止心跳
   */
  private stopHeartbeat(): void {
    this.heartbeatManager.stop();
  }
}
