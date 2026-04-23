/**
 * 远程控制服务
 *
 * 职责划分：
 * - ConnectionManager: 管理 TCP 连接
 * - ProtocolHandler: 处理协议解析（只解析命令）
 * - HeartbeatManager: 管理心跳
 * - CaptureCache: 帧缓存与合并逻辑（在主线程）
 * - ImageAssembler: 图像组装（在 Worker 线程）
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
import { CompressionConfig } from '../../network/CmdCodec';
import { IProtocolHandler } from '../protocol/IProtocolHandler';
import { IHeartbeatManager } from '../interfaces/IHeartbeatManager';
import { IWorkerRepository, FrameProcessTask, FrameProcessResult } from '../../repository/IWorkerRepository';
import { CmdCodec } from '../../network/CmdCodec';
import { ConcreteCmd } from '../../models/ConcreteCmd';
import { CmdType } from '../../models/CmdProtocol';
import { CmdUtils } from '../../models/CmdFactory';
import { MemByteBuffer } from '../../squeeze/MemByteBuffer';
import { Compressor, CompressionMethod } from '../../squeeze/Compressor';

import { Capture } from '../../squeeze/Capture';
import { CaptureCache } from '../../squeeze/CaptureCache';
import { ImageAssemblerImpl } from '../../squeeze/ImageAssemblerImpl';
import { ChecksumUtils } from '../../utils/ChecksumUtils';
import { PerformanceMonitor } from '../../utils/PerformanceMonitor';
import { DependencyContainer, DependencyKeys } from '../../utils/DependencyContainer';
import hilog from '@ohos.hilog';
import fs from '@ohos.file.fs';
import { util } from '@kit.ArkTS';
import common from '@ohos.app.ability.common';
import { GlobalContext } from '../../utils/GlobalContext';

const DOMAIN: number = 0xFF00;
const TAG: string = 'RemoteControlService';

/**
 * 视频流配置
 */
interface VideoStreamConfig {
  enabled: boolean;
  compressionMethod: number;
}

/**
 * Capture 信息
 */
interface CaptureInfo {
  id: number;
  reset: boolean;
  width: number;
  height: number;
  tileWidth: number;
  tileHeight: number;
  dirtyTilesCount: number;
}

export class RemoteControlService implements IRemoteControlService {
  // 配置
  private config: RemoteControlServiceConfig;

  // 依赖（通过构造函数注入）
  private connectionManager: IConnectionManager;
  private protocolHandler: IProtocolHandler;
  private heartbeatManager: IHeartbeatManager;
  private workerRepository: IWorkerRepository;

  // 帧组装器
  private imageAssembler: ImageAssemblerImpl = new ImageAssemblerImpl();

  // Capture 缓存（用于存储处理后的Capture对象）
  private captureCache: CaptureCache;



  // 视频流配置
  private videoConfig: VideoStreamConfig = {
    enabled: false,
    compressionMethod: 3 // ZSTD
  };

  private useCompressorCache: boolean = true;
  private compressorCacheMaxSize: number = 1000;
  private compressorCachePurgeSize: number = 500;

  // 数据处理队列，确保按顺序处理
  private dataQueue: ArrayBuffer[] = [];
  private isProcessingData: boolean = false;
  private readonly maxDataQueueSize: number = 32;
  private droppedDataQueueCount: number = 0;
  
  // 性能监控
  private performanceMonitor: PerformanceMonitor = PerformanceMonitor.getInstance();
  
  // 帧接收时间戳（用于计算精确的帧延迟）
  private frameReceiveTimestamp: number = 0;

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

    // 使用依赖注入获取CaptureCache实例
    this.captureCache = DependencyContainer.getInstance().get<CaptureCache>(DependencyKeys.CAPTURE_CACHE);
    this.imageAssembler.init({
      maxBufferSize: 64 * 1024 * 1024,
      enableBufferReuse: true
    });

    this.setupCallbacks();
    hilog.info(DOMAIN, TAG, 'RemoteControlService initialized');
    hilog.info(DOMAIN, TAG, 'CaptureCache instance obtained via dependency injection');

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
   * 使用队列确保按顺序处理，避免并发问题
   */
  private async handleReceivedData(data: ArrayBuffer): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Received data: %{public}d bytes', data.byteLength);

    // 接收侧背压：latest-wins，队列超限时丢弃最旧数据包，避免内存持续膨胀
    while (this.dataQueue.length >= this.maxDataQueueSize) {
      this.dataQueue.shift();
      this.droppedDataQueueCount++;
    }

    if (this.droppedDataQueueCount > 0 && this.droppedDataQueueCount % 20 === 0) {
      hilog.warn(DOMAIN, TAG, 'Data queue backpressure active, dropped packets: %{public}d', this.droppedDataQueueCount);
    }
    
    // 将数据加入队列
    this.dataQueue.push(data);
    
    // 如果没有正在处理，开始处理队列
    if (!this.isProcessingData) {
      await this.processDataQueue();
    }
  }

  /**
   * 处理数据队列
   */
  private async processDataQueue(): Promise<void> {
    if (this.isProcessingData || this.dataQueue.length === 0) {
      return;
    }

    this.isProcessingData = true;

    try {
      while (this.dataQueue.length > 0) {
        const data = this.dataQueue.shift()!;
        await this.processSingleData(data);
      }
    } finally {
      this.isProcessingData = false;
    }
  }

  /**
   * 处理单个数据块
   */
  private async processSingleData(data: ArrayBuffer): Promise<void> {
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
    this.imageAssembler.reset();
    this.dataQueue = [];
    this.isProcessingData = false;
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
    this.imageAssembler.reset();
    this.dataQueue = [];
    this.isProcessingData = false;
    hilog.info(DOMAIN, TAG, 'Remote screen closed');
  }

  setScreenCallback(callback: ScreenCallback): void {
    this.screenCallback = callback;
  }



  async sendControlEvent(event: RemoteControlEvent): Promise<void> {
    if (!this.videoConfig.enabled) {
      hilog.warn(DOMAIN, TAG, 'Remote control not enabled');
      return;
    }

    if (event.type === 'mouse' && event.x !== undefined && event.y !== undefined) {
      const action = typeof event.button === 'number' ? event.button : (event.action === 'down' || event.action === 'press' ? 1 : 2);
      await this.sendMouseControl(event.x, event.y, action, undefined);
      return;
    }

    if (event.type === 'keyboard' && event.keyCode !== undefined) {
      const pressed = event.action === 'down' || event.action === 'press';
      await this.sendKeyControl(event.keyCode, pressed);
      return;
    }

    hilog.warn(DOMAIN, TAG, 'Unsupported control event: %{public}s', event.type);
  }

  async sendMouseControl(x: number, y: number, action: number, wheelDelta?: number): Promise<void> {
    if (!this.videoConfig.enabled) {
      hilog.warn(DOMAIN, TAG, 'Remote control not enabled');
      return;
    }

    if (!this.remoteDeviceCode) {
      hilog.warn(DOMAIN, TAG, 'Remote device code not available');
      return;
    }

    try {
      const mouseCmd = CmdUtils.createMouseControlCmd(this.remoteDeviceCode, x, y, action, wheelDelta);
      const encoded = CmdCodec.encode(mouseCmd);
      await this.connectionManager.send(encoded);
      hilog.info(DOMAIN, TAG, 'Sent mouse control: x=%{public}d, y=%{public}d, action=%{public}d, wheelDelta=%{public}s', x, y, action, wheelDelta !== undefined ? String(wheelDelta) : 'none');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to send mouse control: %{public}s', error instanceof Error ? error.message : String(error));
    }
  }

  async sendKeyControl(keyCode: number, pressed: boolean): Promise<void> {
    if (!this.videoConfig.enabled) {
      hilog.warn(DOMAIN, TAG, 'Remote control not enabled');
      return;
    }

    if (!this.remoteDeviceCode) {
      hilog.warn(DOMAIN, TAG, 'Remote device code not available');
      return;
    }

    try {
      const keyCmd = CmdUtils.createKeyControlCmd(this.remoteDeviceCode, keyCode, pressed);
      const encoded = CmdCodec.encode(keyCmd);
      await this.connectionManager.send(encoded);
      hilog.info(DOMAIN, TAG, 'Sent key control: keyCode=%{public}d, pressed=%{public}s', keyCode, String(pressed));
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to send key control: %{public}s', error instanceof Error ? error.message : String(error));
    }
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
    this.imageAssembler.destroy();
    this.captureCache.clear();
    this.performanceMonitor.stop();
    hilog.info(DOMAIN, TAG, 'Service cleaned up');
  }
  
  /**
   * 获取性能监控器实例
   */
  getPerformanceMonitor(): PerformanceMonitor {
    return this.performanceMonitor;
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
        await this.handleCaptureData(cmd);
        break;
      case CmdType.CaptureConfig:
        this.handleCaptureConfigCommand(cmd);
        break;
      case CmdType.CompressorConfig:
        this.handleCompressorConfigCommand(cmd);
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
      this.imageAssembler.reset();
      this.captureCache.clear();
      // TileCache 将通过 CompressorConfig 命令配置
      hilog.info(DOMAIN, TAG, 'Waiting for CompressorConfig to set up tile cache');
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
    const fps = data.fps || 0;
    const captureFrequency = data.captureFrequency || 0;
    const quality = data.quality || 0;
    const maxFps = data.maxFps || 0;

    hilog.info(DOMAIN, TAG, 'CaptureConfig - fps: %{public}d, captureFrequency: %{public}d, quality: %{public}d, maxFps: %{public}d', 
      fps, captureFrequency, quality, maxFps);
  }

  /**
   * 处理压缩器配置
   */
  private handleCompressorConfigCommand(cmd: ConcreteCmd): void {
    const data = cmd.getData();
    const compressionMethod = data.compressionMethod || 3;
    const useCache = data.useCache !== undefined ? data.useCache : true;
    const cacheMaxSize = data.cacheMaxSize || 1000;
    const cachePurgeSize = data.cachePurgeSize || 500;

    hilog.info(DOMAIN, TAG, 'CompressorConfig - compressionMethod: %{public}d', compressionMethod);

    // 更新压缩方法配置
    this.videoConfig.compressionMethod = compressionMethod;
    this.useCompressorCache = useCache;
    this.compressorCacheMaxSize = cacheMaxSize;
    this.compressorCachePurgeSize = cachePurgeSize;
  }

  /**
   * 处理屏幕捕获数据 (CmdCapture 命令)
   * 从命令中提取压缩数据和压缩方法，传递给 onRawVideoData 处理
   */
  private async handleCaptureData(cmd: ConcreteCmd): Promise<void> {
    const data = cmd.getData();
    const imageData = data.imageData;
    const compressionMethod = data.compressionMethod || 3; // 默认 ZSTD
    const compressionConfig: CompressionConfig | undefined = data.compressionConfig;

    if (!imageData || (typeof imageData === 'string' && imageData.length === 0)) {
      hilog.error(DOMAIN, TAG, 'CaptureData command has no image data');
      return;
    }

    // 处理压缩配置（效仿 Java 端 DeCompressorEngine）
    if (compressionConfig) {
      const method = compressionConfig.method || 3;

      hilog.debug(DOMAIN, TAG, 'Capture compression config applied - method: %{public}d', method);
    }

    hilog.debug(DOMAIN, TAG, 'CmdCapture received - imageData size: %{public}d, compressionMethod: %{public}d, hasConfig: %{public}s',
      typeof imageData === 'string' ? imageData.length : (imageData as ArrayBuffer).byteLength,
      compressionMethod,
      compressionConfig ? 'true' : 'false');

    // 将 imageData 转换为 ArrayBuffer (如果是 string 格式)
    let payloadBuffer: ArrayBuffer;
    if (typeof imageData === 'string') {
      // 尝试从 base64 或直接解析
      payloadBuffer = this.decodeImageData(imageData);
    } else {
      payloadBuffer = imageData as ArrayBuffer;
    }

    // 调用 onRawVideoData 处理视频数据
    await this.onRawVideoData(payloadBuffer, compressionMethod, compressionConfig);
  }

  /**
   * 解码图像数据
   * 支持 base64 编码或直接 ArrayBuffer
   */
  private decodeImageData(imageData: string): ArrayBuffer {
    try {
      if (imageData.length === 0) {
        return new ArrayBuffer(0);
      }

      let normalized = imageData.trim();

      // 兼容 data URL：data:...;base64,xxxx
      const dataUrlPrefix = 'base64,';
      const prefixIndex = normalized.indexOf(dataUrlPrefix);
      if (prefixIndex >= 0) {
        normalized = normalized.substring(prefixIndex + dataUrlPrefix.length);
      }

      // 尝试按 base64 解码
      const base64Body = normalized.replace(/\s+/g, '');
      const isBase64Candidate = /^[A-Za-z0-9+/=]+$/.test(base64Body) && base64Body.length % 4 === 0;
      if (isBase64Candidate) {
        return this.decodeBase64ToArrayBuffer(base64Body);
      }

      // 退化到按原始字节字符串解析
      const bytes = new Uint8Array(normalized.length);
      for (let i = 0; i < normalized.length; i++) {
        bytes[i] = normalized.charCodeAt(i) & 0xFF;
      }
      return bytes.buffer;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to decode image data: %{public}s', JSON.stringify(error));
    }
    return new ArrayBuffer(0);
  }

  /**
   * 将base64字符串解码为ArrayBuffer
   */
  private decodeBase64ToArrayBuffer(base64: string): ArrayBuffer {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    const out: number[] = [];

    for (let i = 0; i < base64.length; i += 4) {
      const c0 = base64.charAt(i);
      const c1 = base64.charAt(i + 1);
      const c2 = base64.charAt(i + 2);
      const c3 = base64.charAt(i + 3);

      const n0 = chars.indexOf(c0);
      const n1 = chars.indexOf(c1);
      const n2 = c2 === '=' ? -1 : chars.indexOf(c2);
      const n3 = c3 === '=' ? -1 : chars.indexOf(c3);

      if (n0 < 0 || n1 < 0 || (n2 < 0 && c2 !== '=') || (n3 < 0 && c3 !== '=')) {
        throw new Error('Invalid base64 content');
      }

      const b0 = (n0 << 2) | (n1 >> 4);
      out.push(b0 & 0xFF);

      if (c2 !== '=') {
        const b1 = ((n1 & 0x0F) << 4) | (n2 >> 2);
        out.push(b1 & 0xFF);
      }

      if (c3 !== '=') {
        const b2 = ((n2 & 0x03) << 6) | n3;
        out.push(b2 & 0xFF);
      }
    }

    return new Uint8Array(out).buffer;
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
   * 架构：
   * - 解压缩：在主线程完成（需要 Context）
   * - 帧合并：在主线程完成
   * @param data 压缩的视频数据
   * @param compressionMethod 压缩方法 ordinal (0=NONE, 1=ZIP, 2=XZ, 3=ZSTD)
   */
  private skippedNoPreCaptureCount: number = 0;
  private skippedIncompleteNoBufferCount: number = 0;
  private consecutiveSkipCount: number = 0;
  private readonly consecutiveSkipWarnThreshold: number = 120;
  private renderedFrameCount: number = 0;

  private recordSkip(reason: string, captureId: number): void {
    this.consecutiveSkipCount++;

    if (
      this.consecutiveSkipCount === this.consecutiveSkipWarnThreshold ||
      this.consecutiveSkipCount % this.consecutiveSkipWarnThreshold === 0
    ) {
      hilog.warn(
        DOMAIN,
        TAG,
        'Consecutive skip reached %{public}d (reason=%{public}s, captureId=%{public}d, skippedNoPre=%{public}d, skippedNoBuffer=%{public}d, rendered=%{public}d)',
        this.consecutiveSkipCount,
        reason,
        captureId,
        this.skippedNoPreCaptureCount,
        this.skippedIncompleteNoBufferCount,
        this.renderedFrameCount
      );
    }
  }

  private resetConsecutiveSkipIfNeeded(width: number, height: number): void {
    if (this.consecutiveSkipCount >= this.consecutiveSkipWarnThreshold) {
      hilog.info(
        DOMAIN,
        TAG,
        'Render recovered after consecutive skips: %{public}d (size=%{public}d x %{public}d)',
        this.consecutiveSkipCount,
        width,
        height
      );
    }
    this.consecutiveSkipCount = 0;
  }

  /**
   * 根据待补全积压量自适应调整每轮补全处理数量
   */
  private getAdaptiveIncompleteBatchSize(): number {
    const pending = this.captureCache.getPendingCaptureQueueSize();

    if (pending <= 2) {
      return 2;
    }
    if (pending <= 6) {
      return 4;
    }
    if (pending <= 12) {
      return 8;
    }
    return 12;
  }

  private async onRawVideoData(
    data: ArrayBuffer,
    compressionMethod: number = 3,
    compressionConfig?: CompressionConfig
  ): Promise<void> {
    // 记录帧接收时间，用于计算精确的帧延迟
    this.frameReceiveTimestamp = Date.now();
    
    hilog.debug(DOMAIN, TAG, 'Processing raw video data: %{public}d bytes, compressionMethod: %{public}d',
      data.byteLength, compressionMethod);

    try {
      // 计算接收到的数据的校验和，确保数据完整性
      const checksum = ChecksumUtils.computeAdler32FromBuffer(data);
      hilog.debug(DOMAIN, TAG, 'Received data checksum: %{public}d', checksum);

      // 处理所有帧
      const zippedData = MemByteBuffer.fromArray(new Uint8Array(data));
      let squeezeMethod: CompressionMethod = CompressionMethod.NONE;
      switch (compressionMethod) {
        case 1:
          squeezeMethod = CompressionMethod.ZIP;
          break;
        case 2:
          squeezeMethod = CompressionMethod.XZ;
          break;
        case 3:
          squeezeMethod = CompressionMethod.ZSTD;
          break;
      }
      const compressor = Compressor.get(squeezeMethod);
      const useCache = compressionConfig ? compressionConfig.useCache : this.useCompressorCache;
      const cacheMaxSize = compressionConfig ? compressionConfig.cacheMaxSize : this.compressorCacheMaxSize;
      const cachePurgeSize = compressionConfig ? compressionConfig.cachePurgeSize : this.compressorCachePurgeSize;
      compressor.setTileCacheConfig(useCache, cacheMaxSize, cachePurgeSize);
      const capture: Capture = await compressor.decompress(zippedData);
      
      // 使用 preCapture 作为完整帧基线：增量帧只覆盖变化瓦片
      const currentCapture = capture;
      const existingPreCapture = this.captureCache.getPreCapture();
      const canMergeToPreCapture =
        existingPreCapture !== null &&
        !currentCapture.reset &&
        existingPreCapture.width === currentCapture.width &&
        existingPreCapture.height === currentCapture.height &&
        existingPreCapture.tileWidth === currentCapture.tileWidth &&
        existingPreCapture.tileHeight === currentCapture.tileHeight;

      if (!canMergeToPreCapture) {
        // 重置或尺寸变化，设置新的preCapture
        this.captureCache.setPreCapture(currentCapture);
      } else {
        // 所有增量帧都加入pending队列，由processIncompleteCaptures统一处理
        this.captureCache.addPending(currentCapture);
      }

      // 统一处理：从pending队列合并到preCapture（支持自适应批处理）
      const adaptiveBatch = this.getAdaptiveIncompleteBatchSize();
      const isPreCaptureComplete = this.captureCache.processIncompleteCaptures(adaptiveBatch);

      const renderCaptureCandidate = this.captureCache.getPreCapture();
      if (!renderCaptureCandidate) {
        this.skippedNoPreCaptureCount++;
        this.recordSkip('no preCapture', currentCapture.id);
        if (this.skippedNoPreCaptureCount <= 3 || this.skippedNoPreCaptureCount % 30 === 0) {
          hilog.warn(DOMAIN, TAG,
            'Skip render(no preCapture), count=%{public}d, captureId=%{public}d',
            this.skippedNoPreCaptureCount, currentCapture.id);
        }
        return;
      }
      const renderCapture = renderCaptureCandidate as Capture;

      const hasReusableBuffer = this.imageAssembler.hasReusableBuffer(renderCapture.width, renderCapture.height);
      if (!isPreCaptureComplete && !hasReusableBuffer) {
        this.skippedIncompleteNoBufferCount++;
        this.recordSkip('incomplete+noBuffer', currentCapture.id);
        if (this.skippedIncompleteNoBufferCount <= 3 || this.skippedIncompleteNoBufferCount % 30 === 0) {
          hilog.warn(DOMAIN, TAG,
            'Skip render(incomplete+noBuffer), count=%{public}d, captureId=%{public}d',
            this.skippedIncompleteNoBufferCount, currentCapture.id);
        }
        return;
      }

      const assembleResult = await this.imageAssembler.assemble(renderCapture);
      const cId = currentCapture.id;
      const cReset = currentCapture.reset;

      // 直接使用组装结果，不需要CaptureProcessor中间层（与Java端一致）
      if (this.screenCallback) {
        // 直接调用 screenCallback，由 ViewModel 创建 PixelMap
        const uint8Data = assembleResult.pixelBuffer;
        const bufferData: ArrayBuffer = uint8Data.buffer.slice(uint8Data.byteOffset, uint8Data.byteOffset + uint8Data.byteLength);
        const widthVal: number = assembleResult.width;
        const heightVal: number = assembleResult.height;
        
        try {
          const renderTimestamp = Date.now();
          this.screenCallback(
            bufferData,
            widthVal,
            heightVal,
            renderTimestamp
          );
          
          // 计算精确的帧延迟（从接收到渲染的时间）
          const frameDelay = renderTimestamp - this.frameReceiveTimestamp;
          this.performanceMonitor.recordFrame(frameDelay);
          
          this.resetConsecutiveSkipIfNeeded(widthVal, heightVal);
          this.renderedFrameCount++;
          if (this.renderedFrameCount <= 3 || this.renderedFrameCount % 120 === 0) {
            hilog.debug(DOMAIN, TAG,
              'Render frame success, rendered=%{public}d, skippedNoPre=%{public}d, skippedNoBuffer=%{public}d, size=%{public}d x %{public}d',
              this.renderedFrameCount,
              this.skippedNoPreCaptureCount,
              this.skippedIncompleteNoBufferCount,
              widthVal,
              heightVal);
          }
        } catch (error) {
          hilog.error(DOMAIN, TAG, 'Error in screenCallback: %{public}s', error instanceof Error ? error.message : String(error));
        }
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to process video: %{public}s', error instanceof Error ? error.message : String(error));
      if (error instanceof Error && error.stack) {
        hilog.error(DOMAIN, TAG, 'Error stack: %{public}s', error.stack);
      }
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
