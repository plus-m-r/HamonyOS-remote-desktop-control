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
    
    return {
      fps: this.currentFps,
      avgFps: avgFps,
      minFps: this.minFps === Number.MAX_VALUE ? 0 : this.minFps,
      maxFps: this.maxFps,
      avgFrameDelay: avgDelay,
      currentFrameDelay: this.currentDelay,
      totalFrames: this.totalFrames,
      skippedFrames: this.skippedFrames,
      skipRate: skipRate
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
    
    hilog.info(DOMAIN, TAG, 'Performance stats reset');
  }
}
