import { Capture } from './Capture';

/**
 * Capture缓存类
 * 
 * 用于缓存Capture对象，实现LRU（最近最少使用）策略，
 * 提高远程桌面控制的性能和效率。
 * 
 * 包含两个队列：
 * 1. 不完整捕获队列：存储由zstd直接解压来的不完整capture
 * 2. 完整捕获队列：存储具有一个合并完整帧所有瓦片信息的capture
 */
export class CaptureCache {
  // 不完整捕获队列（由zstd直接解压来的不完整capture）
  private incompleteCache: Map<number, CacheEntry> = new Map();
  // 完整捕获队列（具有一个合并完整帧所有瓦片信息的capture）
  private completeCache: Map<number, CacheEntry> = new Map();
  
  private readonly maxSize: number;
  private readonly purgeSize: number;
  private hits: number = 0;

  /**
   * 构造函数
   * @param maxSize 缓存最大容量（每个队列）
   * @param purgeSize 缓存清理数量（每个队列）
   */
  constructor(maxSize: number = 50, purgeSize: number = 25) {
    this.maxSize = maxSize;
    this.purgeSize = purgeSize;
  }

  /**
   * 添加不完整的Capture到缓存
   * @param capture 要缓存的不完整Capture对象
   */
  addIncomplete(capture: Capture): void {
    if (this.incompleteCache.size >= this.maxSize) {
      this.purge(this.incompleteCache);
    }
    this.incompleteCache.set(capture.id, new CacheEntry(capture));
  }

  /**
   * 添加完整的Capture到缓存
   * @param capture 要缓存的完整Capture对象
   */
  addComplete(capture: Capture): void {
    if (this.completeCache.size >= this.maxSize) {
      this.purge(this.completeCache);
    }
    this.completeCache.set(capture.id, new CacheEntry(capture));
  }

  /**
   * 从缓存中获取Capture
   * @param id Capture的ID
   * @returns Capture对象，如果缓存中不存在则返回null
   */
  get(id: number): Capture | null {
    // 先从完整捕获队列中获取
    let entry = this.completeCache.get(id);
    if (entry) {
      entry.lastUsed = Date.now();
      this.hits++;
      return entry.capture;
    }
    
    // 再从不完整捕获队列中获取
    entry = this.incompleteCache.get(id);
    if (entry) {
      entry.lastUsed = Date.now();
      this.hits++;
      return entry.capture;
    }
    
    return null;
  }

  /**
   * 从缓存中获取完整的Capture
   * @param id Capture的ID
   * @returns 完整的Capture对象，如果缓存中不存在则返回null
   */
  getComplete(id: number): Capture | null {
    const entry = this.completeCache.get(id);
    if (entry) {
      entry.lastUsed = Date.now();
      this.hits++;
      return entry.capture;
    }
    return null;
  }

  /**
   * 从缓存中获取不完整的Capture
   * @param id Capture的ID
   * @returns 不完整的Capture对象，如果缓存中不存在则返回null
   */
  getIncomplete(id: number): Capture | null {
    const entry = this.incompleteCache.get(id);
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
    this.incompleteCache.delete(id);
    this.completeCache.delete(id);
  }

  /**
   * 清空缓存
   */
  clear(): void {
    this.incompleteCache.clear();
    this.completeCache.clear();
    this.hits = 0;
  }

  /**
   * 获取缓存大小
   * @returns 缓存中的Capture数量
   */
  size(): number {
    return this.incompleteCache.size + this.completeCache.size;
  }

  /**
   * 获取不完整捕获队列大小
   * @returns 不完整捕获队列中的Capture数量
   */
  incompleteSize(): number {
    return this.incompleteCache.size;
  }

  /**
   * 获取完整捕获队列大小
   * @returns 完整捕获队列中的Capture数量
   */
  completeSize(): number {
    return this.completeCache.size;
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
   * @param cache 要清理的缓存
   */
  private purge(cache: Map<number, CacheEntry>): void {
    const entries = Array.from(cache.values());
    entries.sort((a, b) => a.lastUsed - b.lastUsed);
    const toRemove = Math.min(this.purgeSize, entries.length);
    for (let i = 0; i < toRemove; i++) {
      cache.delete(entries[i].capture.id);
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
