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

export class PooledBuffer {
  readonly data: Uint8Array;
  readonly requestedSize: number;
  readonly alignedSize: number;

  constructor(data: Uint8Array, requestedSize: number, alignedSize: number) {
    this.data = data;
    this.requestedSize = requestedSize;
    this.alignedSize = alignedSize;
  }
}

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

  acquireBuffer(size: number): PooledBuffer {
    const alignedSize = Math.ceil(size / 4096) * 4096;

    let pool = this.pools.get(alignedSize);
    if (!pool) {
      pool = new ObjectPool<Uint8Array>(
        () => {
          const buffer = new Uint8Array(alignedSize);
          for (let i = 0; i < alignedSize; i += 4) {
            buffer[i] = 0xFF;
          }
          return buffer;
        },
        (buf) => {},
        this.maxPoolSize
      );
      this.pools.set(alignedSize, pool);
    }

    const buffer = pool.acquire();
    const view = size === alignedSize ? buffer : new Uint8Array(buffer.buffer, 0, size);
    return new PooledBuffer(view, size, alignedSize);
  }

  releaseBuffer(pooled: PooledBuffer): void {
    const pool = this.pools.get(pooled.alignedSize);
    if (pool) {
      if (pooled.data.length === pooled.alignedSize) {
        pool.release(pooled.data);
      } else {
        const fullBuffer = new Uint8Array(pooled.data.buffer, 0, pooled.alignedSize);
        pool.release(fullBuffer);
      }
    }
  }

  clear(): void {
    this.pools.forEach(pool => pool.clear());
    this.pools.clear();
  }
}
