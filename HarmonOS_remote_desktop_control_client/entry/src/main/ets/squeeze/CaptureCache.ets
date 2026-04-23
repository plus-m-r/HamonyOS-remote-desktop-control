import { Capture } from './Capture';
import { CaptureTile } from './CaptureTile';

/**
 * Capture缓存类
 *
 * 负责管理preCapture基线帧和pending待补全队列。
 * 用于处理异步网络环境下的帧合并和补全。
 */
export class CaptureCache {
  private preCapture: Capture | null = null;
  private pendingCaptures: Map<number, Capture> = new Map();
  private pendingQueue: number[] = [];
  private readonly maxSize: number;
  private readonly purgeSize: number;

  constructor(maxSize: number = 10, purgeSize: number = 5) {
    this.maxSize = maxSize;
    this.purgeSize = purgeSize;
  }

  /**
   * 设置预捕获对象作为渲染基线
   */
  setPreCapture(capture: Capture): void {
    this.preCapture = capture;
    // 从pending队列中移除（如果存在）
    const index = this.pendingQueue.indexOf(capture.id);
    if (index !== -1) {
      this.pendingQueue.splice(index, 1);
      this.pendingCaptures.delete(capture.id);
    }
  }

  /**
   * 获取预捕获对象
   */
  getPreCapture(): Capture | null {
    return this.preCapture;
  }

  /**
   * 处理待补全capture，将其瓦片覆盖到preCapture中
   * 返回值表示当前preCapture是否已经完整。
   */
  processIncompleteCaptures(maxCaptures: number = 2): boolean {
    if (!this.preCapture) {
      return false;
    }

    const tileUpdates: Map<number, CaptureTile> = new Map();
    let processedCount = 0;

    while (processedCount < maxCaptures && this.pendingQueue.length > 0) {
      const pendingId = this.pendingQueue.shift();
      if (pendingId === undefined) {
        break;
      }

      const capture = this.pendingCaptures.get(pendingId);
      if (!capture) {
        continue;
      }

      // 从pending队列中移除
      this.pendingCaptures.delete(pendingId);

      // 跳过过期或尺寸不匹配的帧
      if (capture.id <= this.preCapture.id) {
        continue;
      }

      if (
        capture.width !== this.preCapture.width ||
        capture.height !== this.preCapture.height ||
        capture.tileWidth !== this.preCapture.tileWidth ||
        capture.tileHeight !== this.preCapture.tileHeight
      ) {
        continue;
      }

      processedCount++;

      // 收集有效瓦片
      for (let i = 0; i < capture.dirtyTiles.length; i++) {
        const tile = capture.dirtyTiles[i];
        if (tile !== null && tile.capture !== null) {
          tileUpdates.set(i, tile);
        }
      }
    }

    // 批量应用瓦片更新
    const entries = Array.from(tileUpdates.entries());
    for (let i = 0; i < entries.length; i++) {
      const index = entries[i][0];
      const tile = entries[i][1];
      this.preCapture.dirtyTiles[index] = tile;
    }

    return this.isPreCaptureComplete();
  }

  /**
   * 检查当前preCapture是否已经完整
   */
  isPreCaptureComplete(): boolean {
    if (!this.preCapture) {
      return false;
    }

    for (let i = 0; i < this.preCapture.dirtyTiles.length; i++) {
      const tile = this.preCapture.dirtyTiles[i];
      if (tile === null || tile.capture === null) {
        return false;
      }
    }

    return true;
  }

  /**
   * 添加待补全的Capture到pending队列
   */
  addPending(capture: Capture): void {
    if (!this.pendingCaptures.has(capture.id)) {
      this.pendingCaptures.set(capture.id, capture);
      this.pendingQueue.push(capture.id);
    }
  }

  /**
   * 清空所有状态
   */
  clear(): void {
    this.preCapture = null;
    this.pendingCaptures.clear();
    this.pendingQueue = [];
  }

  /**
   * 获取待补全队列大小
   */
  getPendingCaptureQueueSize(): number {
    return this.pendingQueue.length;
  }
}
