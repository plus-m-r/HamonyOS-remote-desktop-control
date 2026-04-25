import { Capture } from './Capture';

/**
 * Capture缓存类 - 流式渲染架构
 *
 * 负责管理preCapture基线帧，用于buffer复用优化。
 * 
 * 核心设计：
 * 1. 收到帧立即合并到preCapture（不经过pending队列）
 * 2. 利用ArkUI异步渲染特性，不需要等待完整性
 * 3. preCapture仅用于ImageAssembler的buffer复用，不是渲染前提
 */
export class CaptureCache {
  private preCapture: Capture | null = null;

  constructor() {
    // 新架构不再需要maxSize和purgeSize参数
  }

  /**
   * 设置预捕获对象作为渲染基线
   */
  setPreCapture(capture: Capture): void {
    this.preCapture = capture;
  }

  /**
   * 获取预捕获对象
   */
  getPreCapture(): Capture | null {
    return this.preCapture;
  }

  /**
   * ⭐ 新架构：立即合并capture到preCapture（流式渲染）
   * 
   * 与旧架构的区别：
   * - 不经过pending队列，直接合并
   * - 适用于ArkUI异步渲染场景
   * - 收到帧就立即更新preCapture，不等完整性检查
   */
  mergeCaptureToPreCapture(capture: Capture): void {
    if (!this.preCapture) {
      // 如果没有preCapture，直接设置
      this.setPreCapture(capture);
      return;
    }

    // 检查尺寸是否匹配
    if (
      capture.width !== this.preCapture.width ||
      capture.height !== this.preCapture.height ||
      capture.tileWidth !== this.preCapture.tileWidth ||
      capture.tileHeight !== this.preCapture.tileHeight
    ) {
      // 尺寸变化，替换preCapture
      this.setPreCapture(capture);
      return;
    }

    // 跳过过期帧
    if (capture.id <= this.preCapture.id) {
      return;
    }

    // 立即合并dirty tiles到preCapture
    let mergedCount = 0;
    for (let i = 0; i < capture.dirtyTiles.length; i++) {
      const tile = capture.dirtyTiles[i];
      if (tile !== null && tile.capture !== null) {
        this.preCapture.dirtyTiles[i] = tile;
        mergedCount++;
      }
    }

    // 更新preCapture的ID和merged计数
    this.preCapture = new Capture(
      capture.id,
      false, // reset标志清除
      this.preCapture.skipped,
      this.preCapture.merged + mergedCount,
      this.preCapture.width,
      this.preCapture.height,
      this.preCapture.tileWidth,
      this.preCapture.tileHeight,
      this.preCapture.dirtyTiles,
      this.preCapture.isGrayFrame
    );
  }

  /**
   * 清空所有状态
   */
  clear(): void {
    this.preCapture = null;
  }

  /**
   * 获取待补全队列大小（新架构始终为0）
   */
  getPendingCaptureQueueSize(): number {
    return 0;
  }
}
