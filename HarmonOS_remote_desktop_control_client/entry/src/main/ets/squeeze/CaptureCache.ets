import { Capture } from './Capture';
import { image } from '@kit.ImageKit';

/**
 * Capture缓存类
 * 
 * 用于缓存Capture对象和对应的PixelMap，实现LRU（最近最少使用）策略，
 * 提高远程桌面控制的性能和效率。
 */
export class CaptureCache {
  // 缓存队列，存储Capture和对应的PixelMap
  private cache: Map<number, CacheEntry> = new Map();
  // 预捕获对象，用于生成PixelMap
  private preCapture: Capture | null = null;
  
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
   * 设置预捕获对象
   * @param capture 预捕获的Capture对象
   */
  setPreCapture(capture: Capture): void {
    this.preCapture = capture;
  }

  /**
   * 获取预捕获对象
   * @returns Capture对象，如果不存在则返回null
   */
  getPreCapture(): Capture | null {
    return this.preCapture;
  }

  /**
   * 添加Capture到缓存
   * @param capture 要缓存的Capture对象
   */
  add(capture: Capture): void {
    if (this.cache.size >= this.maxSize) {
      this.purge();
    }
    this.cache.set(capture.id, new CacheEntry(capture, null));
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
   * 由预捕获对象直接生成PixelMap并存储到缓存
   * @returns Promise<image.PixelMap> 生成的PixelMap
   */
  async createAndCachePixelMap(): Promise<image.PixelMap> {
    // 检查预捕获对象是否存在
    if (!this.preCapture) {
      throw new Error('PreCapture is not set');
    }

    const capture = this.preCapture;

    // 检查缓存中是否已存在该capture的PixelMap
    const existingEntry = this.cache.get(capture.id);
    if (existingEntry && existingEntry.pixelMap) {
      existingEntry.lastUsed = Date.now();
      this.hits++;
      return existingEntry.pixelMap;
    }

    // 创建图像缓冲区
    const bufferSize = capture.width * capture.height * 4;
    const imageBuffer = new Uint8Array(bufferSize);
    
    // 初始化缓冲区为不透明的黑色背景
    for (let i = 0; i < bufferSize; i += 4) {
      imageBuffer[i] = 0x00;     // B 通道：黑色
      imageBuffer[i + 1] = 0x00; // G 通道：黑色
      imageBuffer[i + 2] = 0x00; // R 通道：黑色
      imageBuffer[i + 3] = 0xFF; // A 通道：完全不透明
    }

    // 将dirty tiles绘制到缓冲区
    capture.drawToBuffer(imageBuffer);

    // 创建ArrayBuffer
    const bufferData: ArrayBuffer = imageBuffer.buffer.slice(
      imageBuffer.byteOffset, 
      imageBuffer.byteOffset + imageBuffer.byteLength
    );

    // 创建PixelMap
    const opts: image.InitializationOptions = {
      editable: false,
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      size: { 
        width: capture.width, 
        height: capture.height 
      }
    };

    const pixelMap = await image.createPixelMap(bufferData, opts);

    // 存储到缓存
    if (this.cache.size >= this.maxSize) {
      this.purge();
    }
    this.cache.set(capture.id, new CacheEntry(capture, pixelMap));

    return pixelMap;
  }

  /**
   * 从缓存中获取PixelMap
   * @param id Capture的ID
   * @returns image.PixelMap对象，如果缓存中不存在则返回null
   */
  getPixelMap(id: number): image.PixelMap | null {
    const entry = this.cache.get(id);
    if (entry && entry.pixelMap) {
      entry.lastUsed = Date.now();
      this.hits++;
      return entry.pixelMap;
    }
    return null;
  }

  /**
   * 从缓存中移除Capture
   * @param id Capture的ID
   */
  remove(id: number): void {
    const entry = this.cache.get(id);
    if (entry && entry.pixelMap) {
      // 释放PixelMap资源
      try {
        entry.pixelMap.release();
      } catch (error) {
        // 忽略释放错误
      }
    }
    this.cache.delete(id);
  }

  /**
   * 清空缓存
   */
  clear(): void {
    // 释放所有PixelMap资源
    for (const entry of this.cache.values()) {
      if (entry.pixelMap) {
        try {
          entry.pixelMap.release();
        } catch (error) {
          // 忽略释放错误
        }
      }
    }
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
      const entry = entries[i];
      if (entry.pixelMap) {
        // 释放PixelMap资源
        try {
          entry.pixelMap.release();
        } catch (error) {
          // 忽略释放错误
        }
      }
      this.cache.delete(entry.capture.id);
    }
  }
}

/**
 * 缓存项类
 */
class CacheEntry {
  readonly capture: Capture;
  readonly pixelMap: image.PixelMap | null;
  lastUsed: number;

  /**
   * 构造函数
   * @param capture Capture对象
   * @param pixelMap 对应的PixelMap对象
   */
  constructor(capture: Capture, pixelMap: image.PixelMap | null) {
    this.capture = capture;
    this.pixelMap = pixelMap;
    this.lastUsed = Date.now();
  }
}
