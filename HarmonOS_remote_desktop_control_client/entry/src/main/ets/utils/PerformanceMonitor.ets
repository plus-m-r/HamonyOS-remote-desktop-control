/**
 * 性能监控器
 * 
 * 监控FPS、延迟、跳帧率等性能指标
 */

import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001;
const TAG = 'PerformanceMonitor';

export interface PerformanceStats {
  /** 当前FPS */
  fps: number;
  /** 平均FPS */
  avgFps: number;
  /** 最小FPS */
  minFps: number;
  /** 最大FPS */
  maxFps: number;
  /** 平均帧延迟（ms） */
  avgFrameDelay: number;
  /** 当前帧延迟（ms） */
  currentFrameDelay: number;
  /** 总渲染帧数 */
  totalFrames: number;
  /** 跳帧次数 */
  skippedFrames: number;
  /** 跳帧率（%） */
  skipRate: number;
  
  // 各环节详细性能指标
  /** 网络接收耗时（ms） */
  networkReceiveTime: number;
  /** 协议解析耗时（ms） */
  protocolParseTime: number;
  /** 解压缩耗时（ms） */
  decompressTime: number;
  /** 解压后数据大小（字节） */
  decompressedSize: number;
  /** 图像组装耗时（ms） */
  assembleTime: number;
  /** 渲染耗时（ms） */
  renderTime: number;
  /** 端到端总延迟（ms） */
  endToEndDelay: number;
  
  // 缓存统计
  /** 缓存命中率（%） */
  cacheHitRate: number;
  /** pending队列长度 */
  pendingQueueSize: number;
  /** Buffer复用率（%） */
  bufferReuseRate: number;
  
  // 网络统计
  /** 数据包大小（字节） */
  dataPacketSize: number;
  /** 队列等待时间（ms） */
  queueWaitTime: number;
}

export class PerformanceMonitor {
  private static instance: PerformanceMonitor | null = null;
  
  // FPS统计
  private frameCount: number = 0;
  private lastFpsUpdateTime: number = 0;
  private currentFps: number = 0;
  private fpsSamples: number[] = [];
  private readonly fpsSampleSize: number = 30; // 30秒滑动窗口
  
  // 延迟统计
  private delaySamples: number[] = [];
  private readonly delaySampleSize: number = 60;
  private currentDelay: number = 0;
  
  // 帧统计
  private totalFrames: number = 0;
  private skippedFrames: number = 0;
  
  // FPS极值
  private minFps: number = Number.MAX_VALUE;
  private maxFps: number = 0;
  
  private isRunning: boolean = false;
  private logTimer: number | null = null;
  
  // 各环节性能统计
  private networkReceiveTimes: number[] = [];
  private protocolParseTimes: number[] = [];
  private decompressTimes: number[] = [];
  private decompressedSizes: number[] = [];
  private assembleTimes: number[] = [];
  private renderTimes: number[] = [];
  private endToEndDelays: number[] = [];
  
  // 缓存统计
  private cacheHits: number = 0;
  private cacheMisses: number = 0;
  private bufferReuses: number = 0;
  private bufferTotalOps: number = 0;
  
  // 网络统计
  private dataPacketSizes: number[] = [];
  private queueWaitTimes: number[] = [];
  
  private readonly sampleSize: number = 60;
  
  // 当前帧的时间戳追踪
  private frameStartTime: number = 0;
  private networkReceiveStart: number = 0;
  private protocolParseStart: number = 0;
  private decompressStart: number = 0;
  private assembleStart: number = 0;
  private renderStart: number = 0;
  
  private pendingQueueSizeCurrent: number = 0;
  
  private constructor() {}
  
  static getInstance(): PerformanceMonitor {
    if (!PerformanceMonitor.instance) {
      PerformanceMonitor.instance = new PerformanceMonitor();
    }
    return PerformanceMonitor.instance;
  }
  
  /**
   * 启动性能监控
   */
  start(): void {
    if (this.isRunning) return;
    
    this.isRunning = true;
    this.lastFpsUpdateTime = Date.now();
    this.frameCount = 0;
    this.fpsSamples = [];
    this.delaySamples = [];
    this.totalFrames = 0;
    this.skippedFrames = 0;
    this.minFps = Number.MAX_VALUE;
    this.maxFps = 0;
    
    // 初始化各环节统计数组
    this.networkReceiveTimes = [];
    this.protocolParseTimes = [];
    this.decompressTimes = [];
    this.decompressedSizes = [];
    this.assembleTimes = [];
    this.renderTimes = [];
    this.endToEndDelays = [];
    
    // 初始化缓存统计
    this.cacheHits = 0;
    this.cacheMisses = 0;
    this.bufferReuses = 0;
    this.bufferTotalOps = 0;
    
    // 初始化网络统计
    this.dataPacketSizes = [];
    this.queueWaitTimes = [];
    
    // 启动定期日志输出（每5秒）
    this.logTimer = setInterval(() => {
      this.outputLog();
    }, 5000);
    
    hilog.info(DOMAIN, TAG, 'Performance monitor started');
  }
  
  /**
   * 停止性能监控
   */
  stop(): void {
    if (!this.isRunning) return;
    
    this.isRunning = false;
    if (this.logTimer !== null) {
      clearInterval(this.logTimer);
      this.logTimer = null;
    }
    
    hilog.info(DOMAIN, TAG, 'Performance monitor stopped');
  }
  
  /**
   * 记录一帧渲染成功
   * @param frameDelay 帧延迟（从接收到显示的时间，单位ms）
   */
  recordFrame(frameDelay: number): void {
    if (!this.isRunning) return;
    
    this.totalFrames++;
    this.currentDelay = frameDelay;
    
    // 记录帧延迟样本
    this.delaySamples.push(frameDelay);
    if (this.delaySamples.length > this.delaySampleSize) {
      this.delaySamples.shift();
    }
    
    // 计算FPS
    this.frameCount++;
    const now = Date.now();
    const elapsed = now - this.lastFpsUpdateTime;
    
    // 每秒更新一次FPS
    if (elapsed >= 1000) {
      this.currentFps = Math.round((this.frameCount * 1000) / elapsed);
      
      // 更新FPS样本
      this.fpsSamples.push(this.currentFps);
      if (this.fpsSamples.length > this.fpsSampleSize) {
        this.fpsSamples.shift();
      }
      
      // 更新极值
      if (this.currentFps < this.minFps) {
        this.minFps = this.currentFps;
      }
      if (this.currentFps > this.maxFps) {
        this.maxFps = this.currentFps;
      }
      
      // 重置计数器
      this.frameCount = 0;
      this.lastFpsUpdateTime = now;
    }
  }
  
  /**
   * 记录跳帧
   */
  recordSkippedFrame(): void {
    if (!this.isRunning) return;
    this.skippedFrames++;
  }
  
  /**
   * 获取当前性能统计
   */
  getStats(): PerformanceStats {
    // 计算平均FPS
    const avgFps = this.fpsSamples.length > 0
      ? Math.round(this.fpsSamples.reduce((a, b) => a + b, 0) / this.fpsSamples.length)
      : 0;
    
    // 计算平均延迟
    const avgDelay = this.delaySamples.length > 0
      ? Math.round(this.delaySamples.reduce((a, b) => a + b, 0) / this.delaySamples.length)
      : 0;
    
    // 计算跳帧率
    const totalProcessed = this.totalFrames + this.skippedFrames;
    const skipRate = totalProcessed > 0
      ? Math.round((this.skippedFrames / totalProcessed) * 1000) / 10
      : 0;
    
    // 计算各环节平均耗时
    const avgNetworkReceive = this.networkReceiveTimes.length > 0
      ? Math.round(this.networkReceiveTimes.reduce((a, b) => a + b, 0) / this.networkReceiveTimes.length)
      : 0;
    
    const avgProtocolParse = this.protocolParseTimes.length > 0
      ? Math.round(this.protocolParseTimes.reduce((a, b) => a + b, 0) / this.protocolParseTimes.length)
      : 0;
    
    const avgDecompress = this.decompressTimes.length > 0
      ? Math.round(this.decompressTimes.reduce((a, b) => a + b, 0) / this.decompressTimes.length)
      : 0;
    
    const avgDecompressedSize = this.decompressedSizes.length > 0
      ? Math.round(this.decompressedSizes.reduce((a, b) => a + b, 0) / this.decompressedSizes.length)
      : 0;
    
    const avgAssemble = this.assembleTimes.length > 0
      ? Math.round(this.assembleTimes.reduce((a, b) => a + b, 0) / this.assembleTimes.length)
      : 0;
    
    const avgRender = this.renderTimes.length > 0
      ? Math.round(this.renderTimes.reduce((a, b) => a + b, 0) / this.renderTimes.length)
      : 0;
    
    const avgEndToEnd = this.endToEndDelays.length > 0
      ? Math.round(this.endToEndDelays.reduce((a, b) => a + b, 0) / this.endToEndDelays.length)
      : 0;
    
    // 计算缓存命中率
    const cacheHitRate = (this.cacheHits + this.cacheMisses) > 0
      ? Math.round((this.cacheHits / (this.cacheHits + this.cacheMisses)) * 1000) / 10
      : 0;
    
    // 计算Buffer复用率
    const bufferReuseRate = this.bufferTotalOps > 0
      ? Math.round((this.bufferReuses / this.bufferTotalOps) * 1000) / 10
      : 0;
    
    // 计算平均数据包大小
    const avgDataPacketSize = this.dataPacketSizes.length > 0
      ? Math.round(this.dataPacketSizes.reduce((a, b) => a + b, 0) / this.dataPacketSizes.length)
      : 0;
    
    // 计算平均队列等待时间
    const avgQueueWait = this.queueWaitTimes.length > 0
      ? Math.round(this.queueWaitTimes.reduce((a, b) => a + b, 0) / this.queueWaitTimes.length)
      : 0;
    
    return {
      fps: this.currentFps,
      avgFps: avgFps,
      minFps: this.minFps === Number.MAX_VALUE ? 0 : this.minFps,
      maxFps: this.maxFps,
      avgFrameDelay: avgDelay,
      currentFrameDelay: this.currentDelay,
      totalFrames: this.totalFrames,
      skippedFrames: this.skippedFrames,
      skipRate: skipRate,
      
      networkReceiveTime: avgNetworkReceive,
      protocolParseTime: avgProtocolParse,
      decompressTime: avgDecompress,
      decompressedSize: avgDecompressedSize,
      assembleTime: avgAssemble,
      renderTime: avgRender,
      endToEndDelay: avgEndToEnd,
      
      cacheHitRate: cacheHitRate,
      pendingQueueSize: this.pendingQueueSizeCurrent,
      bufferReuseRate: bufferReuseRate,
      
      dataPacketSize: avgDataPacketSize,
      queueWaitTime: avgQueueWait
    };
  }
  
  /**
   * 输出日志
   */
  private outputLog(): void {
    const stats = this.getStats();
    
    hilog.info(DOMAIN, TAG,
      'FPS: %{public}d (avg: %{public}d, min: %{public}d, max: %{public}d) | ' +
      'Delay: %{public}dms (avg: %{public}dms) | ' +
      'Skip: %{public}d%% (%{public}d/%{public}d)',
      stats.fps,
      stats.avgFps,
      stats.minFps,
      stats.maxFps,
      stats.currentFrameDelay,
      stats.avgFrameDelay,
      stats.skipRate,
      stats.skippedFrames,
      stats.totalFrames + stats.skippedFrames
    );
    
    // 输出详细环节耗时
    hilog.info(DOMAIN, TAG,
      'Pipeline - Network: %{public}dms | Parse: %{public}dms | Decompress: %{public}dms | ' +
      'Assemble: %{public}dms | Render: %{public}dms | EndToEnd: %{public}dms',
      stats.networkReceiveTime,
      stats.protocolParseTime,
      stats.decompressTime,
      stats.assembleTime,
      stats.renderTime,
      stats.endToEndDelay
    );
    
    // 输出缓存和网络统计
    hilog.info(DOMAIN, TAG,
      'Cache Hit: %{public}d%% | Buffer Reuse: %{public}d%% | Pending: %{public}d | ' +
      'Packet Size: %{public}dB | Queue Wait: %{public}dms',
      stats.cacheHitRate,
      stats.bufferReuseRate,
      stats.pendingQueueSize,
      stats.dataPacketSize,
      stats.queueWaitTime
    );
    
    // 低FPS警告
    if (stats.fps < 15 && stats.totalFrames > 10) {
      hilog.warn(DOMAIN, TAG, 'Low FPS detected: %{public}d', stats.fps);
    }
    
    // 高延迟警告
    if (stats.avgFrameDelay > 200 && stats.totalFrames > 10) {
      hilog.warn(DOMAIN, TAG, 'High frame delay: %{public}dms', stats.avgFrameDelay);
    }
    
    // 高跳帧率警告
    if (stats.skipRate > 10 && stats.totalFrames > 10) {
      hilog.warn(DOMAIN, TAG, 'High skip rate: %{public}d%%', stats.skipRate);
    }
    
    // 高解压缩耗时警告
    if (stats.decompressTime > 50 && stats.totalFrames > 10) {
      hilog.warn(DOMAIN, TAG, 'High decompress time: %{public}dms', stats.decompressTime);
    }
    
    // 高组装耗时警告
    if (stats.assembleTime > 30 && stats.totalFrames > 10) {
      hilog.warn(DOMAIN, TAG, 'High assemble time: %{public}dms', stats.assembleTime);
    }
  }
  
  /**
   * 重置统计数据
   */
  reset(): void {
    this.frameCount = 0;
    this.lastFpsUpdateTime = Date.now();
    this.currentFps = 0;
    this.fpsSamples = [];
    this.delaySamples = [];
    this.totalFrames = 0;
    this.skippedFrames = 0;
    this.minFps = Number.MAX_VALUE;
    this.maxFps = 0;
    this.currentDelay = 0;
    
    // 重置各环节统计
    this.networkReceiveTimes = [];
    this.protocolParseTimes = [];
    this.decompressTimes = [];
    this.decompressedSizes = [];
    this.assembleTimes = [];
    this.renderTimes = [];
    this.endToEndDelays = [];
    
    // 重置缓存统计
    this.cacheHits = 0;
    this.cacheMisses = 0;
    this.bufferReuses = 0;
    this.bufferTotalOps = 0;
    
    // 重置网络统计
    this.dataPacketSizes = [];
    this.queueWaitTimes = [];
    
    hilog.info(DOMAIN, TAG, 'Performance stats reset');
  }
  
  /**
   * 标记帧开始（数据接收）
   * @param dataSize 数据包大小
   */
  markFrameStart(dataSize: number = 0): void {
    if (!this.isRunning) return;
    this.frameStartTime = Date.now();
    this.networkReceiveStart = this.frameStartTime;
    
    // 记录数据包大小
    if (dataSize > 0) {
      this.dataPacketSizes.push(dataSize);
      if (this.dataPacketSizes.length > this.sampleSize) {
        this.dataPacketSizes.shift();
      }
    }
  }
  
  /**
   * 标记协议解析开始
   */
  markProtocolParseStart(): void {
    if (!this.isRunning) return;
    this.protocolParseStart = Date.now();
  }
  
  /**
   * 记录协议解析完成
   */
  recordProtocolParseComplete(): void {
    if (!this.isRunning) return;
    const parseTime = Date.now() - this.protocolParseStart;
    this.protocolParseTimes.push(parseTime);
    if (this.protocolParseTimes.length > this.sampleSize) {
      this.protocolParseTimes.shift();
    }
  }
  
  /**
   * 标记解压缩开始
   */
  markDecompressStart(): void {
    if (!this.isRunning) return;
    this.decompressStart = Date.now();
  }
  
  /**
   * 记录解压缩完成
   * @param decompressedSize 解压后数据大小
   */
  recordDecompressComplete(decompressedSize: number): void {
    if (!this.isRunning) return;
    const decompressTime = Date.now() - this.decompressStart;
    this.decompressTimes.push(decompressTime);
    if (this.decompressTimes.length > this.sampleSize) {
      this.decompressTimes.shift();
    }
    
    this.decompressedSizes.push(decompressedSize);
    if (this.decompressedSizes.length > this.sampleSize) {
      this.decompressedSizes.shift();
    }
  }
  
  /**
   * 标记组装开始
   */
  markAssembleStart(): void {
    if (!this.isRunning) return;
    this.assembleStart = Date.now();
  }
  
  /**
   * 记录组装完成
   */
  recordAssembleComplete(): void {
    if (!this.isRunning) return;
    const assembleTime = Date.now() - this.assembleStart;
    
    this.assembleTimes.push(assembleTime);
    if (this.assembleTimes.length > this.sampleSize) {
      this.assembleTimes.shift();
    }
  }
  
  /**
   * 标记渲染开始
   */
  markRenderStart(): void {
    if (!this.isRunning) return;
    this.renderStart = Date.now();
  }
  
  /**
   * 记录渲染完成和整体帧延迟
   * @param frameDelay 从接收到渲染的总延迟
   */
  recordRenderComplete(frameDelay: number): void {
    if (!this.isRunning) return;
    const renderTime = Date.now() - this.renderStart;
    
    this.renderTimes.push(renderTime);
    if (this.renderTimes.length > this.sampleSize) {
      this.renderTimes.shift();
    }
    
    this.endToEndDelays.push(frameDelay);
    if (this.endToEndDelays.length > this.sampleSize) {
      this.endToEndDelays.shift();
    }
    
    this.recordFrame(frameDelay);
  }
  
  /**
   * 记录缓存命中/未命中
   * @param isHit 是否命中缓存
   */
  recordCacheAccess(isHit: boolean): void {
    if (!this.isRunning) return;
    if (isHit) {
      this.cacheHits++;
    } else {
      this.cacheMisses++;
    }
  }
  
  /**
   * 记录Buffer复用
   * @param isReused 是否复用了Buffer
   */
  recordBufferReuse(isReused: boolean): void {
    if (!this.isRunning) return;
    this.bufferTotalOps++;
    if (isReused) {
      this.bufferReuses++;
    }
  }
  
  /**
   * 记录队列等待时间
   * @param waitTime 等待时间（ms）
   */
  recordQueueWait(waitTime: number): void {
    if (!this.isRunning) return;
    this.queueWaitTimes.push(waitTime);
    if (this.queueWaitTimes.length > this.sampleSize) {
      this.queueWaitTimes.shift();
    }
  }
  
  /**
   * 设置pending队列大小
   * @param size 队列长度
   */
  setPendingQueueSize(size: number): void {
    if (!this.isRunning) return;
    this.pendingQueueSizeCurrent = size;
  }
}
