/**
 * 性能监控集成示例
 * 
 * 展示如何在RemoteScreenView中集成详细性能监控
 */

import { PerformanceOverlay } from '../components/PerformanceOverlay';
import { PerformanceStats } from '../utils/PerformanceMonitor';
import { RemoteControlService } from '../services/remote/RemoteControlService';

@Component
export struct RemoteScreenViewExample {
  @State showPerformanceOverlay: boolean = false;
  @State performanceStats: PerformanceStats = {
    fps: 0,
    avgFps: 0,
    minFps: 0,
    maxFps: 0,
    avgFrameDelay: 0,
    currentFrameDelay: 0,
    totalFrames: 0,
    skippedFrames: 0,
    skipRate: 0,
    networkReceiveTime: 0,
    protocolParseTime: 0,
    decompressTime: 0,
    decompressedSize: 0,
    assembleTime: 0,
    renderTime: 0,
    endToEndDelay: 0,
    cacheHitRate: 0,
    pendingQueueSize: 0,
    bufferReuseRate: 0,
    dataPacketSize: 0,
    queueWaitTime: 0
  };
  
  private remoteControlService: RemoteControlService | null = null;
  private statsUpdateTimer: number | null = null;
  
  aboutToAppear(): void {
    // 获取RemoteControlService实例
    this.remoteControlService = this.getRemoteControlService();
    
    // 启动性能监控
    if (this.remoteControlService) {
      this.remoteControlService.getPerformanceMonitor().start();
      
      // 定期更新统计数据（每500ms）
      this.statsUpdateTimer = setInterval(() => {
        this.updatePerformanceStats();
      }, 500);
    }
  }
  
  aboutToDisappear(): void {
    // 清理定时器
    if (this.statsUpdateTimer !== null) {
      clearInterval(this.statsUpdateTimer);
      this.statsUpdateTimer = null;
    }
    
    // 停止性能监控
    if (this.remoteControlService) {
      this.remoteControlService.getPerformanceMonitor().stop();
    }
  }
  
  /**
   * 更新性能统计数据
   */
  private updatePerformanceStats(): void {
    if (this.remoteControlService) {
      this.performanceStats = this.remoteControlService.getPerformanceMonitor().getStats();
    }
  }
  
  /**
   * 切换性能监控显示
   */
  private togglePerformanceOverlay(): void {
    this.showPerformanceOverlay = !this.showPerformanceOverlay;
    
    if (this.showPerformanceOverlay) {
      this.remoteControlService?.getPerformanceMonitor().start();
    } else {
      this.remoteControlService?.getPerformanceMonitor().stop();
    }
  }
  
  build() {
    Stack() {
      // 主内容 - 远程屏幕显示
      Column() {
        // ... 您的远程屏幕显示组件
        
        // 控制按钮区域
        Row() {
          Button('性能监控')
            .fontSize(14)
            .backgroundColor(this.showPerformanceOverlay ? '#4CAF50' : '#2196F3')
            .onClick(() => {
              this.togglePerformanceOverlay();
            })
          
          Button('重置统计')
            .fontSize(14)
            .backgroundColor('#FF9800')
            .margin({ left: 10 })
            .onClick(() => {
              this.remoteControlService?.getPerformanceMonitor().reset();
            })
        }
        .padding(10)
        .width('100%')
      }
      .width('100%')
      .height('100%')
      
      // 性能监控浮窗
      if (this.showPerformanceOverlay) {
        PerformanceOverlay({
          stats: this.performanceStats,
          showPerformanceOverlay: $showPerformanceOverlay
        })
      }
    }
    .width('100%')
    .height('100%')
  }
  
  /**
   * 获取RemoteControlService实例
   * 根据您的实际架构调整此方法
   */
  private getRemoteControlService(): RemoteControlService | null {
    // 方式1: 通过依赖注入
    // return DependencyContainer.getInstance().get<RemoteControlService>(DependencyKeys.REMOTE_CONTROL_SERVICE);
    
    // 方式2: 通过ViewModel
    // return this.viewModel.remoteControlService;
    
    // 方式3: 通过全局上下文
    // return GlobalContext.getInstance().getRemoteControlService();
    
    // 请根据实际情况实现
    return null;
  }
}

/**
 * 简化版 - 仅显示关键指标
 */
@Component
export struct SimplePerformanceOverlay {
  @Prop stats: PerformanceStats;
  @Consume showPerformanceOverlay: boolean;
  
  build() {
    Column() {
      Row() {
        Text('性能')
          .fontSize(12)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
        
        Blank()
        
        Text('✕')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.showPerformanceOverlay = false;
          })
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .backgroundColor('rgba(0, 0, 0, 0.7)')
      
      Column() {
        // FPS
        Row() {
          Text('FPS:')
            .fontSize(11)
            .fontColor('#AAAAAA')
            .width(40)
          
          Text(`${this.stats.fps}`)
            .fontSize(11)
            .fontColor(this.getFpsColor(this.stats.fps))
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        
        // 延迟
        Row() {
          Text('Delay:')
            .fontSize(11)
            .fontColor('#AAAAAA')
            .width(40)
          
          Text(`${this.stats.endToEndDelay}ms`)
            .fontSize(11)
            .fontColor(this.getDelayColor(this.stats.endToEndDelay))
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        
        // 解压缩
        Row() {
          Text('Decomp:')
            .fontSize(11)
            .fontColor('#AAAAAA')
            .width(40)
          
          Text(`${this.stats.decompressTime}ms`)
            .fontSize(11)
            .fontColor(this.getTimeColor(this.stats.decompressTime))
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        
        // 组装
        Row() {
          Text('Assemble:')
            .fontSize(11)
            .fontColor('#AAAAAA')
            .width(40)
          
          Text(`${this.stats.assembleTime}ms`)
            .fontSize(11)
            .fontColor(this.getTimeColor(this.stats.assembleTime))
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      }
      .backgroundColor('rgba(0, 0, 0, 0.6)')
    }
    .width(140)
    .borderRadius(8)
    .shadow({
      radius: 10,
      color: 'rgba(0, 0, 0, 0.3)',
      offsetX: 0,
      offsetY: 2
    })
    .position({ x: 10, y: 10 })
    .gesture(
      TapGesture({ count: 2 })
        .onAction(() => {
          this.showPerformanceOverlay = false;
        })
    )
  }
  
  private getFpsColor(fps: number): string {
    if (fps >= 25) return '#00FF00';
    if (fps >= 15) return '#FFAA00';
    return '#FF0000';
  }
  
  private getDelayColor(delay: number): string {
    if (delay <= 50) return '#00FF00';
    if (delay <= 100) return '#FFAA00';
    return '#FF0000';
  }
  
  private getTimeColor(time: number): string {
    if (time <= 20) return '#00FF00';
    if (time <= 40) return '#FFAA00';
    return '#FF0000';
  }
}
