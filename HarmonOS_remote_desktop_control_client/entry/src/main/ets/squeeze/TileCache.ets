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

interface LruEntry {
  cacheId: number;
  prev: LruEntry | null;
  next: LruEntry | null;
}

export class RegularTileCache implements TileCache {
  private tiles: Map<number, CaptureTile> = new Map();
  private entries: Map<number, LruEntry> = new Map();
  private head: LruEntry | null = null;
  private tail: LruEntry | null = null;
  private hits: number = 0;
  private readonly maxSize: number;
  private readonly purgeSize: number;

  constructor(maxSize: number, purgeSize: number) {
    this.maxSize = maxSize;
    this.purgeSize = purgeSize;
  }

  getCacheId(tile: CaptureTile): number {
    const cs = tile.checksum;
    if (cs < 0 || cs > 4294967295) {
      return Math.floor(cs & 0xFFFFFFFF);
    }
    return cs;
  }

  private moveToHead(entry: LruEntry): void {
    if (entry === this.head) {
      return;
    }
    if (entry.prev !== null) {
      entry.prev.next = entry.next;
    }
    if (entry.next !== null) {
      entry.next.prev = entry.prev;
    }
    if (entry === this.tail) {
      this.tail = entry.prev;
    }
    entry.prev = null;
    entry.next = this.head;
    if (this.head !== null) {
      this.head.prev = entry;
    }
    this.head = entry;
    if (this.tail === null) {
      this.tail = entry;
    }
  }

  private removeTail(): number {
    if (this.tail === null) {
      return -1;
    }
    const cacheId = this.tail.cacheId;
    if (this.tail.prev !== null) {
      this.tail.prev.next = null;
    } else {
      this.head = null;
    }
    const oldTail = this.tail;
    this.tail = this.tail.prev;
    this.entries.delete(cacheId);
    this.tiles.delete(cacheId);
    return cacheId;
  }

  private removeFromList(entry: LruEntry): void {
    if (entry.prev !== null) {
      entry.prev.next = entry.next;
    } else {
      this.head = entry.next;
    }
    if (entry.next !== null) {
      entry.next.prev = entry.prev;
    } else {
      this.tail = entry.prev;
    }
    entry.prev = null;
    entry.next = null;
  }

  add(tile: CaptureTile): void {
    const cacheId = this.getCacheId(tile);
    const existing = this.entries.get(cacheId);
    if (existing !== undefined) {
      this.removeFromList(existing);
      this.entries.delete(cacheId);
      this.tiles.delete(cacheId);
    }
    if (this.tiles.size < this.maxSize || existing !== undefined) {
      this.tiles.set(cacheId, tile);
      const entry: LruEntry = { cacheId: cacheId, prev: null, next: this.head };
      this.entries.set(cacheId, entry);
      if (this.head !== null) {
        this.head.prev = entry;
      }
      this.head = entry;
      if (this.tail === null) {
        this.tail = entry;
      }
    }
  }

  get(cachedId: number): CaptureTile {
    const tile = this.tiles.get(cachedId);
    if (tile !== undefined) {
      this.hits++;
      const entry = this.entries.get(cachedId);
      if (entry !== undefined) {
        this.moveToHead(entry);
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
    this.entries.clear();
    this.head = null;
    this.tail = null;
    this.hits = 0;
  }

  onCaptureProcessed(): void {
    if (this.tiles.size > 0 && this.tiles.size >= this.maxSize) {
      while (this.tiles.size > this.purgeSize && this.tail !== null) {
        this.removeTail();
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
