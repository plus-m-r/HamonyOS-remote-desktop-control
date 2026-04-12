import { Capture } from './Capture';

/**
 * Capture缓存类
 * 
 * 用于缓存Capture对象，实现LRU（最近最少使用）策略，
 * 提高远程桌面控制的性能和效率。
 */
export class CaptureCache {
  // 缓存队列
  private cache: Map<number, CacheEntry> = new Map();
  
  private readonly maxSize: number;
  private readonly purgeSize: number;
  private hits: number = 0;

  /**
   * 构造函数
   * @param maxSize 缓存最大容量
   * @param purgeSize 缓存清理数量
   */
  constructor(maxSize: number = 50, purgeSize: number = 25) {
    this.maxSize = maxSize;
    this.purgeSize = purgeSize;
  }

  /**
   * 添加Capture到缓存
   * @param capture 要缓存的Capture对象
   */
  add(capture: Capture): void {
    if (this.cache.size >= this.maxSize) {
      this.purge();
    }
    this.cache.set(capture.id, new CacheEntry(capture));
  }

  /**
   * 从缓存中获取Capture
   * @param id Capture的ID
   * @returns Capture对象，如果缓存中不存在则返回null
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
   * @param id Capture的ID
   */
  remove(id: number): void {
    this.cache.delete(id);
  }

  /**
   * 清空缓存
   */
  clear(): void {
    this.cache.clear();
    this.hits = 0;
  }

  /**
   * 获取缓存大小
   * @returns 缓存中的Capture数量
   */
  size(): number {
    return this.cache.size;
  }

  /**
   * 获取缓存命中次数
   * @returns 缓存命中次数
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
      this.cache.delete(entries[i].capture.id);
    }
  }
}

/**
 * 缓存项类
 */
class CacheEntry {
  readonly capture: Capture;
  lastUsed: number;

  /**
   * 构造函数
   * @param capture Capture对象
   */
  constructor(capture: Capture) {
    this.capture = capture;
    this.lastUsed = Date.now();
  }
}
