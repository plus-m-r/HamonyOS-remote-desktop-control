import { CaptureTile } from './CaptureTile';

export interface TileCache {
  getCacheId(tile: CaptureTile): number;
  add(tile: CaptureTile): void;
  get(cachedId: number): CaptureTile;
  size(): number;
  clear(): void;
  onCaptureProcessed(): void;
  clearHits(): void;
  getHits(): number;
}

export class NullTileCache implements TileCache {
  getCacheId(tile: CaptureTile): number {
    return -1;
  }

  add(tile: CaptureTile): void {}

  get(cachedId: number): CaptureTile {
    return CaptureTile.MISSING;
  }

  size(): number {
    return 0;
  }

  clear(): void {}

  onCaptureProcessed(): void {}

  clearHits(): void {}

  getHits(): number {
    return 0;
  }
}

export class RegularTileCache implements TileCache {
  private tiles: Map<number, CaptureTile> = new Map();
  private lru: number[] = []; // LRU队列，头部是最久未使用的
  private hits: number = 0;
  private readonly maxSize: number;
  private readonly purgeSize: number;

  constructor(maxSize: number, purgeSize: number) {
    this.maxSize = maxSize;
    this.purgeSize = purgeSize;
  }

  getCacheId(tile: CaptureTile): number {
    // 与Java端一致：直接使用checksum作为cacheId
    const cs = tile.checksum;
    if (cs < 0 || cs > 4294967295) {
      // checksum超出int范围时截断（与Java端警告一致）
      return Math.floor(cs & 0xFFFFFFFF);
    }
    return cs;
  }

  add(tile: CaptureTile): void {
    // 与Java端一致：只有缓存未满时才添加
    if (this.tiles.size < this.maxSize) {
      const cacheId = this.getCacheId(tile);
      this.tiles.set(cacheId, tile);
      // 添加到LRU队列头部（最新使用）
      this.lru.unshift(cacheId);
    }
  }

  get(cachedId: number): CaptureTile {
    const tile = this.tiles.get(cachedId);
    if (tile !== undefined) {
      this.hits++;
      // 与Java端一致：命中时移动到LRU队列头部
      const index = this.lru.indexOf(cachedId);
      if (index !== -1) {
        this.lru.splice(index, 1);
        this.lru.unshift(cachedId);
      }
      return tile;
    }
    return CaptureTile.MISSING;
  }

  size(): number {
    return this.tiles.size;
  }

  clear(): void {
    this.tiles.clear();
    this.lru = [];
    this.hits = 0;
  }

  onCaptureProcessed(): void {
    // 与Java端完全一致的LRU清理逻辑
    if (this.tiles.size > 0 && this.tiles.size >= this.maxSize) {
      // 从LRU队列头部移除最久未使用的条目，直到缓存大小降至purgeSize
      while (this.tiles.size > this.purgeSize && this.lru.length > 0) {
        const oldestId = this.lru.shift(); // 移除并返回第一个元素
        if (oldestId !== undefined) {
          this.tiles.delete(oldestId);
        }
      }
    }
  }

  clearHits(): void {
    this.hits = 0;
  }

  getHits(): number {
    return this.hits;
  }
}
