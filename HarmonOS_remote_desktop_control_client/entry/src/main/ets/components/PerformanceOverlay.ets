/**
 * 性能监控浮窗组件
 * 
 * 显示实时性能统计数据
 */

import { PerformanceStats } from '../utils/PerformanceMonitor';

@Component
export struct PerformanceOverlay {
  @Prop stats: PerformanceStats;
  @Consume showPerformanceOverlay: boolean;
  
  // 浮窗位置（可拖动）
  @State overlayX: number = 10;
  @State overlayY: number = 10;
  
  // 拖拽状态
  private startX: number = 0;
  private startY: number = 0;
  
  build() {
    Column() {
      // 标题栏
      Row() {
        Text('性能监控')
          .fontSize(12)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          
        Blank()
          
        // 关闭按钮
        Text('\u2715')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.showPerformanceOverlay = false;
          })
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .backgroundColor('rgba(0, 0, 0, 0.7)')
        
      // 统计数据
      Column() {
        // FPS信息
        Row() {
          Text('FPS:')
            .fontSize(11)
            .fontColor('#AAAAAA')
            .width(60)
            
          Text(`${this.stats.fps}`)
            .fontSize(11)
            .fontColor(this.getFpsColor(this.stats.fps))
            .fontWeight(FontWeight.Bold)
            
          Text(`(avg:${this.stats.avgFps})`)
            .fontSize(10)
            .fontColor('#888888')
            .margin({ left: 5 })
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          
        // 延迟信息
        Row() {
          Text('Delay:')
            .fontSize(11)
            .fontColor('#AAAAAA')
            .width(60)
            
          Text(`${this.stats.currentFrameDelay}ms`)
            .fontSize(11)
            .fontColor(this.getDelayColor(this.stats.currentFrameDelay))
            .fontWeight(FontWeight.Bold)
            
          Text(`(avg:${this.stats.avgFrameDelay}ms)`)
            .fontSize(10)
            .fontColor('#888888')
            .margin({ left: 5 })
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          
        // 端到端延迟
        Row() {
          Text('EndToEnd:')
            .fontSize(11)
            .fontColor('#AAAAAA')
            .width(60)
            
          Text(`${this.stats.endToEndDelay}ms`)
            .fontSize(11)
            .fontColor(this.getDelayColor(this.stats.endToEndDelay))
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          
        // 跳帧信息
        Row() {
          Text('Skip:')
            .fontSize(11)
            .fontColor('#AAAAAA')
            .width(60)
            
          Text(`${this.stats.skipRate}%`)
            .fontSize(11)
            .fontColor(this.getSkipRateColor(this.stats.skipRate))
            .fontWeight(FontWeight.Bold)
            
          Text(`(${this.stats.skippedFrames}/${this.stats.totalFrames + this.stats.skippedFrames})`)
            .fontSize(10)
            .fontColor('#888888')
            .margin({ left: 5 })
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          
        // 环节耗时 - 解压缩
        Row() {
          Text('Decomp:')
            .fontSize(11)
            .fontColor('#AAAAAA')
            .width(60)
            
          Text(`${this.stats.decompressTime}ms`)
            .fontSize(11)
            .fontColor(this.getTimeColor(this.stats.decompressTime))
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          
        // 环节耗时 - 组装
        Row() {
          Text('Assemble:')
            .fontSize(11)
            .fontColor('#AAAAAA')
            .width(60)
            
          Text(`${this.stats.assembleTime}ms`)
            .fontSize(11)
            .fontColor(this.getTimeColor(this.stats.assembleTime))
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          
        // 环节耗时 - 渲染
        Row() {
          Text('Render:')
            .fontSize(11)
            .fontColor('#AAAAAA')
            .width(60)
            
          Text(`${this.stats.renderTime}ms`)
            .fontSize(11)
            .fontColor(this.getTimeColor(this.stats.renderTime))
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          
        // 缓存统计
        Row() {
          Text('Cache:')
            .fontSize(11)
            .fontColor('#AAAAAA')
            .width(60)
            
          Text(`${this.stats.cacheHitRate}%`)
            .fontSize(11)
            .fontColor(this.getCacheColor(this.stats.cacheHitRate))
            .fontWeight(FontWeight.Bold)
            
          Text(`(Buf:${this.stats.bufferReuseRate}%)`)
            .fontSize(10)
            .fontColor('#888888')
            .margin({ left: 5 })
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          
        // 网络统计
        Row() {
          Text('Network:')
            .fontSize(11)
            .fontColor('#AAAAAA')
            .width(60)
            
          Text(`${this.stats.dataPacketSize}B`)
            .fontSize(11)
            .fontColor('#CCCCCC')
            .fontWeight(FontWeight.Bold)
            
          Text(`(Q:${this.stats.queueWaitTime}ms)`)
            .fontSize(10)
            .fontColor('#888888')
            .margin({ left: 5 })
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          
        // 极值信息
        Row() {
          Text('Min/Max:')
            .fontSize(11)
            .fontColor('#AAAAAA')
            .width(60)
            
          Text(`${this.stats.minFps}/${this.stats.maxFps}`)
            .fontSize(11)
            .fontColor('#CCCCCC')
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      }
      .backgroundColor('rgba(0, 0, 0, 0.6)')
    }
    .width(200)
    .borderRadius(8)
    .shadow({
      radius: 10,
      color: 'rgba(0, 0, 0, 0.3)',
      offsetX: 0,
      offsetY: 2
    })
    .position({ x: this.overlayX, y: this.overlayY })
    .gesture(
      PanGesture({ direction: PanDirection.All })
        .onActionStart((event: GestureEvent) => {
          this.startX = this.overlayX - event.offsetX;
          this.startY = this.overlayY - event.offsetY;
        })
        .onActionUpdate((event: GestureEvent) => {
          this.overlayX = this.startX + event.offsetX;
          this.overlayY = this.startY + event.offsetY;
        })
    )
    .gesture(
      TapGesture({ count: 2 })
        .onAction(() => {
          // 双击隐藏
          this.showPerformanceOverlay = false;
        })
    )
  }
  
  /**
   * 根据FPS返回颜色
   */
  private getFpsColor(fps: number): string {
    if (fps >= 25) return '#00FF00'; // 绿色 - 优秀
    if (fps >= 15) return '#FFAA00'; // 橙色 - 一般
    return '#FF0000'; // 红色 - 差
  }
  
  /**
   * 根据延迟返回颜色
   */
  private getDelayColor(delay: number): string {
    if (delay <= 50) return '#00FF00'; // 绿色 - 优秀
    if (delay <= 100) return '#FFAA00'; // 橙色 - 一般
    return '#FF0000'; // 红色 - 差
  }
  
  /**
   * 根据跳帧率返回颜色
   */
  private getSkipRateColor(rate: number): string {
    if (rate <= 2) return '#00FF00'; // 绿色 - 优秀
    if (rate <= 5) return '#FFAA00'; // 橙色 - 一般
    return '#FF0000'; // 红色 - 差
  }
  
  /**
   * 根据耗时返回颜色
   */
  private getTimeColor(time: number): string {
    if (time <= 20) return '#00FF00'; // 绿色 - 优秀
    if (time <= 40) return '#FFAA00'; // 橙色 - 一般
    return '#FF0000'; // 红色 - 差
  }
  
  /**
   * 根据缓存命中率返回颜色
   */
  private getCacheColor(rate: number): string {
    if (rate >= 90) return '#00FF00'; // 绿色 - 优秀
    if (rate >= 70) return '#FFAA00'; // 橙色 - 一般
    return '#FF0000'; // 红色 - 差
  }
}
