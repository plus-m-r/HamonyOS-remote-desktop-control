/**
 * 远程控制服务
 *
 * 职责划分：
 * - ConnectionManager: 管理 TCP 连接
 * - ProtocolHandler: 处理协议解析（主线程）
 * - HeartbeatManager: 管理心跳
 * - CaptureCache: 帧缓存与合并逻辑（主线程）
 * - ImageAssembler: 图像组装（主线程）
 */

import {
  IRemoteControlService,
  DeviceCredentials,
  ScreenCallback,
  DeviceInfoCallback,
  RemoteControlServiceConfig,
  TileScreenCallback,
  TileRenderData
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
  CaptureStatus,
  CompressionMethod
} from '../../models/CmdProtocol';
import { IConnectionManager } from '../connection/IConnectionManager';
import { CompressionConfig } from '../../network/CmdCodec';
import { IProtocolHandler } from '../protocol/IProtocolHandler';
import { IHeartbeatManager } from '../interfaces/IHeartbeatManager';
import { CmdCodec } from '../../network/CmdCodec';
import { ConcreteCmd } from '../../models/ConcreteCmd';
import { CmdType } from '../../models/CmdProtocol';
import { CmdUtils } from '../../models/CmdFactory';
import { MemByteBuffer } from '../../squeeze/MemByteBuffer';
import { FrameDecoder } from '../../squeeze/FrameDecoder';

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
  
  // ⭐ 新架构：PixelMap初始化标志（用于区分首帧和增量帧）
  private isPixelMapInitialized: boolean = false;

  // 设备信息
  private localDeviceCode: string = '';
  private localPassword: string = '';
  private remoteDeviceCode: string = '';
  private remotePassword: string = '';
  private isValidating: boolean = false;

  // 回调
  private screenCallback: ScreenCallback | null = null;
  private tileScreenCallback: TileScreenCallback | null = null;
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
    const dataSize = data.byteLength;
    
    // 标记帧开始并记录数据包大小
    this.performanceMonitor.markFrameStart(dataSize);
    
    hilog.info(DOMAIN, TAG, 'Received data: %{public}d bytes', dataSize);

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
    // 标记协议解析开始
    this.performanceMonitor.markProtocolParseStart();
    
    // 尝试让 ProtocolHandler 解析命令
    // CmdCapture 命令会通过 commandCallback -> handleCaptureData 处理
    const commands = await this.protocolHandler.processData(data);
    
    // 记录协议解析完成
    this.performanceMonitor.recordProtocolParseComplete();

    if (commands.length > 0) {
      // 有命令，已通过 commandCallback 处理
      hilog.info(DOMAIN, TAG, 'Processed %{public}d commands', commands.length);
    } else {
      // 没有命令，可能是残留数据或粘包情况
      // CmdCapture 命令通过 callback 处理，不会出现在 commands 数组中
      hilog.debug(DOMAIN, TAG, 'Partial data buffered, %{public}d bytes (awaiting more)', data.byteLength);
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
    
    this.isPixelMapInitialized = false;
    
    await this.connectionManager.disconnect();
    this.protocolHandler.reset();
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
    
    // ⭐ 新架构：重置PixelMap初始化标志
    this.isPixelMapInitialized = false;
    
    hilog.info(DOMAIN, TAG, 'Remote screen closed');
  }

  setScreenCallback(callback: ScreenCallback): void {
    this.screenCallback = callback;
  }

  setTileScreenCallback(callback: TileScreenCallback): void {
    this.tileScreenCallback = callback;
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

  updateConnectionTarget(host: string, port: number): void {
    hilog.info(DOMAIN, TAG, 'Updating connection target: %{public}s:%{public}d', host, port);
    this.connectionManager.updateTarget(host, port);
    this.config.host = host;
    this.config.port = port;
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
      // 禁用瓦片缓存：避免两端缓存不一致导致引用缺失（白块残留/黑块闪动）。
      // 被控端收到 CompressorConfig 后改用 NullTileCache，始终发送完整瓦片数据。
      this.sendCompressorCacheConfig(false);
    } else {
      hilog.error(DOMAIN, TAG, 'Remote screen capture failed: %{public}s', status);
      this.videoConfig.enabled = false;
    }
  }

  /**
   * 发送压缩器配置（瓦片缓存开关）到被控端
   */
  private async sendCompressorCacheConfig(useCache: boolean): Promise<void> {
    if (this.getConnectionState() !== ConnectionState.CONNECTED || !this.remoteDeviceCode) {
      return;
    }
    try {
      const configCmd = CmdUtils.createCompressorConfigCmd(
        this.remoteDeviceCode,
        CompressionMethod.ZSTD,
        0,
        useCache,
        this.compressorCacheMaxSize,
        this.compressorCachePurgeSize
      );
      const encoded = CmdCodec.encode(configCmd);
      await this.connectionManager.send(encoded);
      hilog.info(DOMAIN, TAG, 'CompressorConfig sent - useCache=%{public}s', String(useCache));
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to send CompressorConfig: %{public}s', JSON.stringify(error));
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
    try {
      const helper = new util.Base64Helper();
      const decoded = helper.decodeSync(base64);
      return decoded.buffer.slice(decoded.byteOffset, decoded.byteOffset + decoded.byteLength);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'Base64Helper decode failed: %{public}s', e instanceof Error ? e.message : String(e));
      return new ArrayBuffer(0);
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
        'Consecutive skip reached %{public}d (reason=%{public}s, captureId=%{public}d, skippedNoPre=%{public}d, rendered=%{public}d)',
        this.consecutiveSkipCount,
        reason,
        captureId,
        this.skippedNoPreCaptureCount,
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


  private async onRawVideoData(
    data: ArrayBuffer,
    compressionMethod: number = 3,
    compressionConfig?: CompressionConfig
  ): Promise<void> {
    // 记录帧接收时间，用于计算精确的帧延迟
    this.frameReceiveTimestamp = Date.now();

    try {
      // 标记解压缩开始
      this.performanceMonitor.markDecompressStart();
      
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
      const decoder = FrameDecoder.get(squeezeMethod);
      const useCache = compressionConfig ? compressionConfig.useCache : this.useCompressorCache;
      const cacheMaxSize = compressionConfig ? compressionConfig.cacheMaxSize : this.compressorCacheMaxSize;
      const cachePurgeSize = compressionConfig ? compressionConfig.cachePurgeSize : this.compressorCachePurgeSize;
      decoder.setTileCacheConfig(useCache, cacheMaxSize, cachePurgeSize);
      const capture: Capture = await decoder.decompress(zippedData);
      
      // 记录解压缩完成
      const decompressedSize = capture.dirtyTiles.reduce((sum, tile) => {
        if (tile && tile.capture) {
          return sum + tile.capture.size();
        }
        return sum;
      }, 0);
      this.performanceMonitor.recordDecompressComplete(decompressedSize);
      
      if (this.tileScreenCallback) {
        this.performanceMonitor.markRenderStart();
        try {
          const tileRegions = capture.toTileRegions();

          const tileData: TileRenderData = {
            tiles: tileRegions,
            frameWidth: capture.width,
            frameHeight: capture.height,
            captureId: capture.id,
            isReset: capture.reset
          };
          hilog.info(DOMAIN, TAG, 'Invoking tileScreenCallback: tiles=%{public}d, size=%{public}d x %{public}d, reset=%{public}s, id=%{public}d',
            tileRegions.length, capture.width, capture.height, String(capture.reset), capture.id);
          this.tileScreenCallback(tileData);

          const frameDelay = Date.now() - this.frameReceiveTimestamp;
          this.performanceMonitor.recordRenderComplete(frameDelay);
          this.resetConsecutiveSkipIfNeeded(capture.width, capture.height);
          this.renderedFrameCount++;
          if (this.renderedFrameCount <= 3 || this.renderedFrameCount % 120 === 0) {
            hilog.debug(DOMAIN, TAG,
              'Tile render, rendered=%{public}d, size=%{public}d x %{public}d, tiles=%{public}d, reset=%{public}s',
              this.renderedFrameCount,
              capture.width,
              capture.height,
              tileRegions.length,
              String(capture.reset));
            const hits = decoder.getTileCacheHits();
            const misses = decoder.getTileCacheMisses();
            const totalGets = hits + misses;
            const hitRateStr = (totalGets > 0 ? (100 * hits / totalGets) : 100).toFixed(1) + '%';
            hilog.info(DOMAIN, TAG, 'Tile cache: size=%{public}d, hits=%{public}d, misses=%{public}d, negGets=%{public}d, normAdds=%{public}d, hitRate=%{public}s',
              decoder.getTileCacheSize(), hits, misses,
              decoder.getNegativeGetCount(), decoder.getNormalizedAddCount(),
              hitRateStr);
          }
        } catch (error) {
          hilog.error(DOMAIN, TAG, 'Error in tileScreenCallback: %{public}s', error instanceof Error ? error.message : String(error));
        }
        return;
      }

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
        this.captureCache.setPreCapture(currentCapture);
        this.performanceMonitor.recordCacheAccess(false);
      } else {
        this.captureCache.mergeCaptureToPreCapture(currentCapture);
        this.performanceMonitor.recordCacheAccess(true);
      }
      
      this.performanceMonitor.setPendingQueueSize(this.captureCache.getPendingCaptureQueueSize());

      const renderCaptureCandidate = this.captureCache.getPreCapture();
      if (!renderCaptureCandidate) {
        this.skippedNoPreCaptureCount++;
        this.recordSkip('no preCapture', currentCapture.id);
        this.performanceMonitor.recordSkippedFrame();
        return;
      }
      const renderCapture = renderCaptureCandidate as Capture;

      // ⭐ 新架构：移除完整性检查，只要有preCapture就渲染（与Java客户端一致）
      const hasReusableBuffer = this.imageAssembler.hasReusableBuffer(renderCapture.width, renderCapture.height);
      
      // 记录Buffer复用情况
      this.performanceMonitor.recordBufferReuse(hasReusableBuffer);

      // 标记组装开始
      this.performanceMonitor.markAssembleStart();
      
      const assembleResult = await this.imageAssembler.assemble(renderCapture);
      
      // 记录组装完成
      this.performanceMonitor.recordAssembleComplete();
      
      const cId = currentCapture.id;
      const cReset = currentCapture.reset;

      // 直接使用组装结果，不需要CaptureProcessor中间层（与Java端一致）
      if (this.screenCallback) {
        // ⭐ 新架构：区分首帧和增量帧
        const uint8Data = assembleResult.pixelBuffer;
        const bufferData: ArrayBuffer = uint8Data.buffer.slice(uint8Data.byteOffset, uint8Data.byteOffset + uint8Data.byteLength);
        const widthVal: number = assembleResult.width;
        const heightVal: number = assembleResult.height;
        
        // 标记渲染开始
        this.performanceMonitor.markRenderStart();
        
        try {
          const renderTimestamp = Date.now();
          
          // ⭐ 新架构：首帧初始化PixelMap，后续直接增量更新
          if (!this.isPixelMapInitialized) {
            hilog.info(DOMAIN, TAG, 'First frame received, initializing editable PixelMap');
            // 通过screenCallback传递数据，由ViewModel初始化PixelMap
            this.screenCallback(bufferData, widthVal, heightVal, renderTimestamp);
            this.isPixelMapInitialized = true;
          } else {
            // 增量帧：直接更新PixelMap
            this.screenCallback(bufferData, widthVal, heightVal, renderTimestamp);
          }
          
          // 计算精确的帧延迟（从接收到渲染的时间）
          const frameDelay = renderTimestamp - this.frameReceiveTimestamp;
          
          // 记录渲染完成
          this.performanceMonitor.recordRenderComplete(frameDelay);
          
          this.resetConsecutiveSkipIfNeeded(widthVal, heightVal);
          this.renderedFrameCount++;
          if (this.renderedFrameCount <= 3 || this.renderedFrameCount % 120 === 0) {
            hilog.debug(DOMAIN, TAG,
              'Render frame success, rendered=%{public}d, skippedNoPre=%{public}d, size=%{public}d x %{public}d',
              this.renderedFrameCount,
              this.skippedNoPreCaptureCount,
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
      hilog.info(DOMAIN, TAG, 'Heartbeat encode size=%{public}d', encoded.byteLength);
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
