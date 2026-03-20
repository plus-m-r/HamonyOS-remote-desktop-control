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

class CacheEntry {
  readonly tile: CaptureTile;
  readonly id: number;
  lastUsed: number;

  constructor(tile: CaptureTile, id: number) {
    this.tile = tile;
    this.id = id;
    this.lastUsed = Date.now();
  }
}

export class RegularTileCache implements TileCache {
  private cache: Map<number, CacheEntry> = new Map();
  private nextId: number = 0;
  private hits: number = 0;
  private readonly maxSize: number;
  private readonly purgeSize: number;

  constructor(maxSize: number, purgeSize: number) {
    this.maxSize = maxSize;
    this.purgeSize = purgeSize;
  }

  getCacheId(tile: CaptureTile): number {
    const entries = Array.from(this.cache.entries());
    for (let i = 0; i < entries.length; i++) {
      const id = entries[i][0];
      const entry = entries[i][1];
      if (entry.tile.checksum === tile.checksum) {
        entry.lastUsed = Date.now();
        return id;
      }
    }
    return -1;
  }

  add(tile: CaptureTile): void {
    if (this.cache.size >= this.maxSize) {
      this.purge();
    }
    const id = this.nextId++;
    this.cache.set(id, new CacheEntry(tile, id));
  }

  get(cachedId: number): CaptureTile {
    const entry = this.cache.get(cachedId);
    if (entry !== undefined) {
      entry.lastUsed = Date.now();
      this.hits++;
      return entry.tile;
    }
    return CaptureTile.MISSING;
  }

  size(): number {
    return this.cache.size;
  }

  clear(): void {
    this.cache.clear();
    this.hits = 0;
  }

  onCaptureProcessed(): void {}

  clearHits(): void {
    this.hits = 0;
  }

  getHits(): number {
    return this.hits;
  }

  private purge(): void {
    const entries = Array.from(this.cache.values());
    entries.sort((a, b) => a.lastUsed - b.lastUsed);
    const toRemove = Math.min(this.purgeSize, entries.length);
    for (let i = 0; i < toRemove; i++) {
      this.cache.delete(entries[i].id);
    }
  }
}
