import { Capture } from './Capture';
import { CaptureTile } from './CaptureTile';
import { ILifecycleAware } from '../lifecycle/ILifecycleManager';

export interface CaptureQueuePolicy {
  queueMaxSize: number;
  queueMaxBytes: number;
  queueLowWatermarkBytes: number;
  queueHighWatermarkBytes: number;
  pressureStartRatio: number;
  pressureDropDirtyTileRatio: number;
}

/**
 * Capture缓存类
 *
 * 只负责上一帧基线、增量补全和待处理队列管理，不承担最终渲染职责。
 */
export class CaptureCache implements ILifecycleAware {
  private cache: Map<number, CacheEntry> = new Map();
  private pendingCaptureIds: number[] = [];
  private pendingCaptureIdSet: Set<number> = new Set();
  private preCapture: Capture | null = null;

  private readonly maxSize: number;
  private readonly purgeSize: number;
  private hits: number = 0;

  constructor(
    maxSize: number = 50,
    purgeSize: number = 25,
    _queuePolicy?: CaptureQueuePolicy
  ) {
    this.maxSize = maxSize;
    this.purgeSize = purgeSize;
  }

  /**
   * 设置预捕获对象
   */
  setPreCapture(capture: Capture): void {
    this.preCapture = capture;

    if (this.pendingCaptureIdSet.delete(capture.id)) {
      this.compactPendingQueueIfNeeded();
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

    while (processedCount < maxCaptures && this.pendingCaptureIds.length > 0) {
      const pendingId = this.pendingCaptureIds.shift();
      if (pendingId === undefined) {
        break;
      }

      if (!this.pendingCaptureIdSet.has(pendingId)) {
        continue;
      }
      this.pendingCaptureIdSet.delete(pendingId);

      const entry = this.cache.get(pendingId);
      if (!entry) {
        continue;
      }

      const capture = entry.capture;

      if (capture.id <= this.preCapture.id) {
        this.remove(capture.id);
        continue;
      }

      if (
        capture.width !== this.preCapture.width ||
        capture.height !== this.preCapture.height ||
        capture.tileWidth !== this.preCapture.tileWidth ||
        capture.tileHeight !== this.preCapture.tileHeight
      ) {
        this.remove(capture.id);
        continue;
      }

      processedCount++;

      for (let i = 0; i < capture.dirtyTiles.length; i++) {
        const tile = capture.dirtyTiles[i];
        if (tile !== null && tile.capture !== null) {
          tileUpdates.set(i, tile);
        }
      }

      this.remove(capture.id);
    }

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
   * 添加Capture到缓存
   */
  add(capture: Capture): void {
    if (this.cache.size >= this.maxSize) {
      this.purge();
    }

    this.cache.set(capture.id, new CacheEntry(capture));

    if (!this.pendingCaptureIdSet.has(capture.id)) {
      this.pendingCaptureIds.push(capture.id);
      this.pendingCaptureIdSet.add(capture.id);
    }
  }

  /**
   * 从缓存中获取Capture
   */
  get(id: number): Capture | null {
    const entry = this.cache.get(id);
    if (entry) {
      entry.lastUsed = Date.now();
      this.hits++;
      return entry.capture;
    }
    return null;
  }

  /**
   * 从缓存中移除Capture
   */
  remove(id: number): void {
    this.cache.delete(id);
    if (this.pendingCaptureIdSet.delete(id)) {
      this.compactPendingQueueIfNeeded();
    }
  }

  /**
   * 清空缓存
   */
  clear(): void {
    this.cache.clear();
    this.pendingCaptureIds = [];
    this.pendingCaptureIdSet.clear();
    this.preCapture = null;
    this.hits = 0;
  }

  /**
   * 获取待补全队列中有效capture数量
   */
  getPendingCaptureQueueSize(): number {
    return this.pendingCaptureIdSet.size;
  }

  /**
   * 获取缓存大小
   */
  size(): number {
    return this.cache.size;
  }

  /**
   * 获取缓存命中次数
   */
  getHits(): number {
    return this.hits;
  }

  /**
   * 重置命中次数
   */
  resetHits(): void {
    this.hits = 0;
  }

  /**
   * 清理最久未使用的缓存项
   */
  private purge(): void {
    const entries = Array.from(this.cache.values());
    entries.sort((a, b) => a.lastUsed - b.lastUsed);
    const toRemove = Math.min(this.purgeSize, entries.length);
    for (let i = 0; i < toRemove; i++) {
      this.remove(entries[i].capture.id);
    }
  }

  /**
   * 当队列中僵尸ID占比过高时压缩队列
   */
  private compactPendingQueueIfNeeded(): void {
    if (this.pendingCaptureIds.length === 0) {
      return;
    }

    if (this.pendingCaptureIds.length <= this.pendingCaptureIdSet.size * 2) {
      return;
    }

    const compacted: number[] = [];
    for (let i = 0; i < this.pendingCaptureIds.length; i++) {
      const id = this.pendingCaptureIds[i];
      if (this.pendingCaptureIdSet.has(id)) {
        compacted.push(id);
      }
    }

    this.pendingCaptureIds = compacted;
  }

  onCreate(): void {
    console.log('CaptureCache onCreate');
    this.cache = new Map();
    this.pendingCaptureIds = [];
    this.pendingCaptureIdSet = new Set();
    this.preCapture = null;
  }

  onStart(): void {
    console.log('CaptureCache onStart');
  }

  onResume(): void {
    console.log('CaptureCache onResume');
  }

  onPause(): void {
    console.log('CaptureCache onPause');
  }

  onStop(): void {
    console.log('CaptureCache onStop');
  }

  onDestroy(): void {
    console.log('CaptureCache onDestroy');
    this.clear();
  }
}

class CacheEntry {
  readonly capture: Capture;
  lastUsed: number;

  constructor(capture: Capture) {
    this.capture = capture;
    this.lastUsed = Date.now();
  }
}
