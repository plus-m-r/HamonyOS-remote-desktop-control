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
import { CompressionConfig } from '../../network/CmdCodec';
import { IProtocolHandler } from '../protocol/IProtocolHandler';
import { IHeartbeatManager } from '../interfaces/IHeartbeatManager';
import { IWorkerRepository, FrameProcessTask, FrameProcessResult } from '../../repository/IWorkerRepository';
import { CaptureProcessor, FrameProcessResult as CaptureFrameProcessResult, FrameInfo } from '../../processor/CaptureProcessor';
import { CmdCodec } from '../../network/CmdCodec';
import { ConcreteCmd } from '../../models/ConcreteCmd';
import { CmdType } from '../../models/CmdProtocol';
import { CmdUtils } from '../../models/CmdFactory';
import { MemByteBuffer } from '../../squeeze/MemByteBuffer';
import { Compressor, CompressionMethod } from '../../squeeze/Compressor';

import { Capture } from '../../squeeze/Capture';
import { CaptureCache } from '../../squeeze/CaptureCache';
import { ChecksumUtils } from '../../utils/ChecksumUtils';
import { DependencyContainer, DependencyKeys } from '../../utils/DependencyContainer';
import { DataSamplingUtil } from './DataSamplingUtil';
import hilog from '@ohos.hilog';
import fs from '@ohos.file.fs';
import { util } from '@kit.ArkTS';
import common from '@ohos.app.ability.common';
import { GlobalContext } from '../../utils/GlobalContext';
import { UIContext } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';

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

  // 帧处理器
  private captureProcessor: CaptureProcessor = new CaptureProcessor();

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
    this.captureProcessor.reset();
    this.captureCache.clear();
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
      this.captureProcessor.reset();
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
    const width = data.width || 0;
    const height = data.height || 0;
    const fps = data.fps || 0;
    const captureFrequency = data.captureFrequency || 0;
    const quality = data.quality || 0;
    const maxFps = data.maxFps || 0;

    hilog.info(DOMAIN, TAG, 'CaptureConfig - width: %{public}d, height: %{public}d, fps: %{public}d, captureFrequency: %{public}d, quality: %{public}d, maxFps: %{public}d', 
      width, height, fps, captureFrequency, quality, maxFps);
    
    // 重置帧处理器以适配新配置
    if (width > 0 && height > 0) {
      this.captureProcessor.reset();
    }
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
      
      hilog.info(DOMAIN, TAG, 'Capture compression config applied - method: %{public}d', method);
    }

    hilog.info(DOMAIN, TAG, 'CmdCapture received - imageData size: %{public}d, compressionMethod: %{public}d, hasConfig: %{public}s',
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
   * 架构：
   * - 解压缩：在主线程完成（需要 Context）
   * - 帧合并：在主线程完成
   * @param data 压缩的视频数据
   * @param compressionMethod 压缩方法 ordinal (0=NONE, 1=ZIP, 2=XZ, 3=ZSTD)
   */
  private isFirstFrame: boolean = true; // 设置为 true 启用调试保存
  private saveDataCounter: number = 0;
  private readonly DEBUG_SAVE_FIRST_FRAME: boolean = false; // 控制是否保存第一帧数据

  private async onRawVideoData(
    data: ArrayBuffer,
    compressionMethod: number = 3,
    compressionConfig?: CompressionConfig
  ): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Processing raw video data: %{public}d bytes, compressionMethod: %{public}d',
      data.byteLength, compressionMethod);

    try {
      // 计算接收到的数据的校验和，确保数据完整性
      const checksum = ChecksumUtils.computeAdler32FromBuffer(data);
      hilog.info(DOMAIN, TAG, 'Received data checksum: %{public}d', checksum);

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
      let capture: Capture = await compressor.decompress(zippedData);
      
      // 检查缓存中是否存在相同ID的Capture
      const cachedCapture = this.captureCache.get(capture.id);
      if (cachedCapture) {
        hilog.info(DOMAIN, TAG, 'Capture cache hit for id: %{public}d', capture.id);
        capture = cachedCapture;
      } else {
        // 将新的Capture添加到缓存
        this.captureCache.add(capture);
        hilog.info(DOMAIN, TAG, 'Capture cache miss, added to cache: %{public}d', capture.id);
      }
      
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

      if (canMergeToPreCapture) {
        const pre = existingPreCapture as Capture;
        for (let i = 0; i < currentCapture.dirtyTiles.length; i++) {
          const tile = currentCapture.dirtyTiles[i];
          if (tile !== null && tile.capture !== null) {
            pre.dirtyTiles[i] = tile;
          }
        }
      } else {
        this.captureCache.setPreCapture(currentCapture);
      }

      const renderCapture = this.captureCache.getPreCapture() as Capture;

      const captureWidth = renderCapture.width;
      const captureHeight = renderCapture.height;
      const tileWidth = renderCapture.tileWidth;
      const tileHeight = renderCapture.tileHeight;
      const cId = currentCapture.id;
      const cReset = currentCapture.reset;
      const bufferSize = captureWidth * captureHeight * 4;
      

      
      // 2. 准备图像缓冲区（增量帧复用上一帧）
      let imageBuffer: Uint8Array;
      
      // 保存第一帧的所有步骤数据（仅在 DEBUG_SAVE_FIRST_FRAME 为 true 时执行）
      if (this.DEBUG_SAVE_FIRST_FRAME && this.isFirstFrame) {
        const timestamp = Date.now();

        // 1. 保存原始压缩数据（步骤1）
        await this.saveArrayBufferToFile(`data/step1_raw_${timestamp}.bin`, data);

        // 5. 保存解压后的 Capture 信息（步骤2）
        const captureInfo: CaptureInfo = {
          id: currentCapture.id,
          reset: currentCapture.reset,
          width: renderCapture.width,
          height: renderCapture.height,
          tileWidth: renderCapture.tileWidth,
          tileHeight: renderCapture.tileHeight,
          dirtyTilesCount: renderCapture.dirtyTiles.filter((t) => t !== null).length
        };
        await this.saveJsonToFile(`data/step2_capture_info_${this.saveDataCounter}_${timestamp}.json`, captureInfo);
        this.saveDataCounter++;

        // 6. 保存第一个瓦片的原始数据（如果有）
        const firstDirtyTile = renderCapture.dirtyTiles.find(t => t !== null);
        if (firstDirtyTile && firstDirtyTile.capture) {
          await this.saveArrayBufferToFile(`data/step3_first_tile_data_${timestamp}.bin`, firstDirtyTile.capture.getInternal().buffer as ArrayBuffer);
        }
      }

      // 3. 创建图像缓冲区并清为黑底，再由 preCapture 绘制完整画面
      imageBuffer = new Uint8Array(bufferSize);
      for (let i = 0; i < bufferSize; i += 4) {
        imageBuffer[i] = 0x00; // B 通道：黑色
        imageBuffer[i + 1] = 0x00; // G 通道：黑色
        imageBuffer[i + 2] = 0x00; // R 通道：黑色
        imageBuffer[i + 3] = 0xFF; // A 通道：完全不透明
      }

      // 8. 保存绘制前的缓冲区（步骤4）
      if (this.DEBUG_SAVE_FIRST_FRAME && this.isFirstFrame) {
        const timestamp = Date.now();
        await this.saveArrayBufferToFile(`data/step4_before_draw_${timestamp}.raw`, imageBuffer.buffer as ArrayBuffer);
      }

      // 9. 将 preCapture 的完整瓦片绘制到缓冲区
      renderCapture.drawToBuffer(imageBuffer);

      // 保存第一帧的绘制后数据（仅在 DEBUG_SAVE_FIRST_FRAME 为 true 时执行）
      if (this.DEBUG_SAVE_FIRST_FRAME && this.isFirstFrame) {
        const timestamp = Date.now();
        // 10. 保存绘制后的缓冲区（步骤5）
        await this.saveArrayBufferToFile(`data/step5_after_draw_${timestamp}.raw`, imageBuffer.buffer as ArrayBuffer);
      }

      // 数据采样：保存最终组装后的图像数据（第四层）
      if (DataSamplingUtil.canSample()) {
        // 使用capture.id作为采样ID
        await DataSamplingUtil.saveFinalImageData(capture.id, imageBuffer, "after_draw");
        
        // 生成并保存元数据
        const metadata = DataSamplingUtil.generateMetadata(
          capture.id,
          Date.now(),
          data.byteLength,
          zippedData.size(),
          0, // RLE输入大小（在Compressor中采样）
          0, // RLE输出大小（在Compressor中采样）
          imageBuffer.length * 4, // 最终图像大小
          CompressionMethod[compressionMethod],
          captureWidth,
          captureHeight,
          tileWidth,
          tileHeight,
          renderCapture.dirtyTiles.filter((t) => t !== null).length
        );
        await DataSamplingUtil.saveMetadata(capture.id, metadata);
      }

      // 4. 处理帧
      const frameInfo: FrameInfo = {
        id: cId,
        reset: cReset,
        width: captureWidth,
        height: captureHeight
      };

      const frameResult: CaptureFrameProcessResult = this.captureProcessor.processFrame(imageBuffer, frameInfo);

      // 保存第一帧的最终处理数据（仅在 DEBUG_SAVE_FIRST_FRAME 为 true 时执行）
      if (this.DEBUG_SAVE_FIRST_FRAME && this.isFirstFrame) {
        const timestamp = Date.now();
        // 12. 保存处理后的最终图像数据（步骤6）
        await this.saveArrayBufferToFile(`data/step6_final_image_${timestamp}.raw`, frameResult.buffer.buffer as ArrayBuffer);
        
        // 标记第一帧已处理
        this.isFirstFrame = false;
      }

      if (this.screenCallback) {
        // 直接调用 screenCallback，由 ViewModel 创建 PixelMap
        const uint8Data = frameResult.buffer;
        const bufferData: ArrayBuffer = uint8Data.buffer.slice(uint8Data.byteOffset, uint8Data.byteOffset + uint8Data.byteLength);
        const widthVal: number = frameResult.width;
        const heightVal: number = frameResult.height;
        
        // 添加日志确认 screenCallback 被调用且数据正确
        hilog.info(DOMAIN, TAG, 'Calling screenCallback with data: width=%{public}d, height=%{public}d, size=%{public}d bytes', 
          widthVal, heightVal, bufferData.byteLength);
        
        try {
          this.screenCallback(
            bufferData,
            widthVal,
            heightVal,
            Date.now()
          );
          hilog.info(DOMAIN, TAG, 'screenCallback called successfully');
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

  /**
   * 保存 ArrayBuffer 到文件
   */
  private async saveArrayBufferToFile(filePath: string, buffer: ArrayBuffer): Promise<void> {
    try {
      // 使用 HarmonyOS 的文件 API 保存文件
      const context: common.Context = GlobalContext.getContext().getObject("context") as common.Context;
      const filesDir: string = context.filesDir;
      const fullPath: string = filesDir + '/' + filePath;
      
      // 确保目录存在
      const dirPath: string = fullPath.substring(0, fullPath.lastIndexOf('/'));
      try {
        fs.mkdirSync(dirPath, true);
      } catch (e) {
        // 目录可能已存在，忽略错误
      }
      
      // 写入文件
      const file = await fs.openSync(fullPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      await fs.writeSync(file.fd, buffer);
      await fs.closeSync(file.fd);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to save ArrayBuffer to file: %{public}s', error instanceof Error ? error.message : String(error));
    }
  }

  /**
   * 保存 JSON 到文件
   */
  private async saveJsonToFile(filePath: string, data: object): Promise<void> {
    try {
      // 使用 HarmonyOS 的文件 API 保存文件
      const context: common.Context = GlobalContext.getContext().getObject("context") as common.Context;
      const filesDir: string = context.filesDir;
      const fullPath: string = filesDir + '/' + filePath;
      
      // 确保目录存在
      const dirPath: string = fullPath.substring(0, fullPath.lastIndexOf('/'));
      try {
        fs.mkdirSync(dirPath, true);
      } catch (e) {
        // 目录可能已存在，忽略错误
      }
      
      // 写入文件
      const jsonString: string = JSON.stringify(data, null, 2);
      const encoder: util.TextEncoder = new util.TextEncoder();
      const jsonBuffer: Uint8Array = encoder.encodeInto(jsonString);
      
      const file = await fs.openSync(fullPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      await fs.writeSync(file.fd, jsonBuffer.buffer);
      await fs.closeSync(file.fd);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to save JSON to file: %{public}s', error instanceof Error ? error.message : String(error));
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
