/**
 * 对象池 - 用于复用频繁创建的对象，减少GC压力
 */
export class ObjectPool<T> {
  private pool: T[] = [];
  private maxSize: number;
  private factory: () => T;
  private reset: (obj: T) => void;

  constructor(factory: () => T, reset: (obj: T) => void, maxSize: number = 10) {
    this.factory = factory;
    this.reset = reset;
    this.maxSize = maxSize;
  }

  /**
   * 获取对象
   */
  acquire(): T {
    if (this.pool.length > 0) {
      return this.pool.pop()!;
    }
    return this.factory();
  }

  /**
   * 释放对象回池
   */
  release(obj: T): void {
    if (this.pool.length < this.maxSize) {
      this.reset(obj);
      this.pool.push(obj);
    }
  }

  /**
   * 清空池
   */
  clear(): void {
    this.pool = [];
  }
}

/**
 * 缓冲区池 - 专门用于Uint8Array的复用
 */
export class BufferPool {
  private static instance: BufferPool;
  private pools: Map<number, ObjectPool<Uint8Array>> = new Map();
  private maxPoolSize: number = 5;

  static getInstance(): BufferPool {
    if (!BufferPool.instance) {
      BufferPool.instance = new BufferPool();
    }
    return BufferPool.instance;
  }

  /**
   * 获取缓冲区
   */
  acquireBuffer(size: number): Uint8Array {
    // 对齐到4KB边界，减少池的大小
    const alignedSize = Math.ceil(size / 4096) * 4096;
    
    let pool = this.pools.get(alignedSize);
    if (!pool) {
      pool = new ObjectPool<Uint8Array>(
        () => new Uint8Array(alignedSize),
        (buf) => buf.fill(0),
        this.maxPoolSize
      );
      this.pools.set(alignedSize, pool);
    }

    const buffer = pool.acquire();
    // 返回精确大小的视图
    return size === alignedSize ? buffer : new Uint8Array(buffer.buffer, 0, size);
  }

  /**
   * 释放缓冲区
   */
  releaseBuffer(buffer: Uint8Array): void {
    const alignedSize = Math.ceil(buffer.length / 4096) * 4096;
    const pool = this.pools.get(alignedSize);
    if (pool) {
      pool.release(buffer);
    }
  }

  /**
   * 清空所有池
   */
  clear(): void {
    this.pools.forEach(pool => pool.clear());
    this.pools.clear();
  }
}
