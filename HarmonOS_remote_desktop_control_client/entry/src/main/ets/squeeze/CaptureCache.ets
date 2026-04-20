import { Capture } from './Capture';
import { CaptureTile } from './CaptureTile';
import { image } from '@kit.ImageKit';
import { RegularRunLengthEncoder } from './RunLengthEncoder';
import { MemByteBuffer } from './MemByteBuffer';
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
 * 用于缓存Capture对象和对应的PixelMap，实现LRU（最近最少使用）策略，
 * 提高远程桌面控制的性能和效率。
 */
export class CaptureCache implements ILifecycleAware {
  // 缓存队列，存储Capture和对应的PixelMap
  private cache: Map<number, CacheEntry> = new Map();
  // 预捕获对象，用于生成PixelMap
  private preCapture: Capture | null = null;
  // PixelMap队列，存储待显示的PixelMap及其内存估算
  private pixelMapQueue: PixelMapQueueEntry[] = [];
  // PixelMap队列当前累计内存估算（字节）
  private queuedPixelMapBytes: number = 0;
  
  private readonly maxSize: number;
  private readonly purgeSize: number;
  private readonly maxPixelMapQueueSize: number;
  private readonly maxPixelMapQueueBytes: number;
  private readonly pixelMapQueueHighWatermarkBytes: number;
  private readonly pixelMapQueueLowWatermarkBytes: number;
  private readonly pressureStartRatio: number;
  private readonly pressureDropDirtyTileRatio: number;
  private hits: number = 0;

  /**
   * 构造函数
   * @param maxSize 缓存最大容量
   * @param purgeSize 缓存清理数量
   * @param queuePolicy PixelMap队列预算与压力策略
   */
  constructor(
    maxSize: number = 50,
    purgeSize: number = 25,
    queuePolicy?: CaptureQueuePolicy
  ) {
    this.maxSize = maxSize;
    this.purgeSize = purgeSize;
    this.maxPixelMapQueueSize = queuePolicy && queuePolicy.queueMaxSize > 0 ? queuePolicy.queueMaxSize : 3;
    this.maxPixelMapQueueBytes = queuePolicy && queuePolicy.queueMaxBytes > 0 ? queuePolicy.queueMaxBytes : 64 * 1024 * 1024;
    const safeLow = queuePolicy && queuePolicy.queueLowWatermarkBytes > 0
      ? queuePolicy.queueLowWatermarkBytes
      : 32 * 1024 * 1024;
    const safeHigh = queuePolicy && queuePolicy.queueHighWatermarkBytes > 0
      ? queuePolicy.queueHighWatermarkBytes
      : Math.floor(this.maxPixelMapQueueBytes * 0.85);
    this.pressureStartRatio = queuePolicy
      ? Math.max(0.1, Math.min(0.95, queuePolicy.pressureStartRatio))
      : 0.8;
    this.pressureDropDirtyTileRatio = queuePolicy
      ? Math.max(0.01, Math.min(0.9, queuePolicy.pressureDropDirtyTileRatio))
      : 0.15;
    this.pixelMapQueueLowWatermarkBytes = Math.min(safeLow, this.maxPixelMapQueueBytes);
    this.pixelMapQueueHighWatermarkBytes = Math.max(
      this.pixelMapQueueLowWatermarkBytes,
      Math.min(safeHigh, this.maxPixelMapQueueBytes)
    );
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
   * 自动处理不完整的capture，将其瓦片信息覆盖到preCapture中
   * 循环从缓存中提取不完整的capture，将其所具有的瓦片信息高效覆盖preCapture中对应位置的瓦片信息
   * 处理完成后，将已利用的不完整capture从缓存中移除
   * 在后台线程中执行，避免阻塞主线程
   * @param maxCaptures 最大处理不完整capture数量，默认为2
   * @returns Promise<image.PixelMap | null> 生成的PixelMap，如果未生成则返回null
   */
  async processIncompleteCaptures(maxCaptures: number = 2): Promise<image.PixelMap | null> {
    // 检查preCapture是否存在
    if (!this.preCapture) {
      return null;
    }

    // 在后台线程中执行处理逻辑
    return new Promise<image.PixelMap | null>((resolve) => {
      // 收集需要移除的capture ID和需要处理的瓦片信息
      const toRemove: number[] = [];
      const tileUpdates: Map<number, CaptureTile> = new Map();

      // 遍历缓存中的所有capture，最多处理maxCaptures个
      let processedCount = 0;
      for (const entry of this.cache.values()) {
        if (processedCount >= maxCaptures) {
          break;
        }
        
        const capture = entry.capture;
        
        // 确保capture与preCapture的尺寸相同
        if (capture.width === this.preCapture!.width && 
            capture.height === this.preCapture!.height && 
            capture.tileWidth === this.preCapture!.tileWidth && 
            capture.tileHeight === this.preCapture!.tileHeight) {
          
          // 标记为需要移除
          toRemove.push(capture.id);
          processedCount++;
          
          // 收集瓦片信息
          for (let i = 0; i < capture.dirtyTiles.length; i++) {
            const tile = capture.dirtyTiles[i];
            if (tile !== null && tile.capture !== null) {
              tileUpdates.set(i, tile);
            }
          }
        }
      }

      // 应用瓦片更新
      const entries = Array.from(tileUpdates.entries());
      for (let i = 0; i < entries.length; i++) {
        const index = entries[i][0];
        const tile = entries[i][1];
        this.preCapture!.dirtyTiles[index] = tile;
      }

      // 移除已处理的不完整capture
      for (const id of toRemove) {
        this.remove(id);
      }

      // 检查preCapture中所有的位置瓦片是否非空
      const allTilesNonEmpty = this.checkAllTilesNonEmpty();
      
      // 如果处理了至少一个capture且所有瓦片都非空，则生成PixelMap
      if (processedCount > 0 && allTilesNonEmpty) {
        if (!this.shouldEnqueueCapture(this.preCapture!)) {
          resolve(null);
          return;
        }

        this.createAndCachePixelMap().then(pixelMap => {
          // 将生成的PixelMap添加到队列中，队列超限时释放最旧项
          const estimatedBytes = this.estimatePixelMapBytes(this.preCapture!);
          this.enqueuePixelMap(pixelMap, estimatedBytes);
          resolve(pixelMap);
        }).catch(() => {
          resolve(null);
        });
      } else {
        resolve(null);
      }
    });
  }

  /**
   * 检查preCapture中所有的位置瓦片是否非空
   * 使用哈希表来高效检验
   * @returns boolean 如果所有瓦片都非空则返回true，否则返回false
   */
  private checkAllTilesNonEmpty(): boolean {
    if (!this.preCapture) {
      return false;
    }

    // 使用哈希表来跟踪非空瓦片的位置
    const nonEmptyTiles = new Set<number>();
    
    // 遍历preCapture的所有瓦片
    for (let i = 0; i < this.preCapture.dirtyTiles.length; i++) {
      const tile = this.preCapture.dirtyTiles[i];
      if (tile !== null && tile.capture !== null) {
        nonEmptyTiles.add(i);
      }
    }
    
    // 检查非空瓦片的数量是否等于总瓦片数量
    return nonEmptyTiles.size === this.preCapture.dirtyTiles.length;
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
   * 解压capture中的游程编码数据
   * 注意：实际的游程编码解码已经在Compressor类中处理
   * 此方法保留用于处理可能需要的额外解压逻辑
   * @param capture 要解压的Capture对象
   * @param preCapture 上一帧的Capture对象，用于依赖解压
   */
  private decompressRunLengthEncoding(capture: Capture, preCapture: Capture | null): void {
    // 游程编码解码已经在Compressor类中处理
    // 这里可以添加额外的解压逻辑，如果需要
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

    // 游程编码数据已经在Compressor类中解压，这里不需要再次解压

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
    // 清空PixelMap队列
    this.clearPixelMapQueue();
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
   * 从PixelMap队列中取出一个PixelMap用于显示
   * @returns image.PixelMap | null 队列中的第一个PixelMap，如果队列为空则返回null
   */
  dequeuePixelMap(): image.PixelMap | null {
    if (this.pixelMapQueue.length > 0) {
      const entry = this.pixelMapQueue.shift();
      if (entry) {
        this.queuedPixelMapBytes = Math.max(0, this.queuedPixelMapBytes - entry.estimatedBytes);
        return entry.pixelMap;
      }
    }
    return null;
  }

  /**
   * 向PixelMap队列入队，超限时丢弃最旧项并释放资源
   * @param pixelMap 要入队的PixelMap
   * @param estimatedBytes PixelMap内存估算（字节）
   */
  private enqueuePixelMap(pixelMap: image.PixelMap, estimatedBytes: number): void {
    const normalizedBytes = estimatedBytes > 0 ? estimatedBytes : 0;

    // 单帧超过总预算时直接丢弃，防止队列失控
    if (normalizedBytes > this.maxPixelMapQueueBytes) {
      try {
        pixelMap.release();
      } catch (error) {
        // 忽略释放错误
      }
      return;
    }

    // 高水位触发后，优先回落到低水位，减少抖动
    if (this.queuedPixelMapBytes >= this.pixelMapQueueHighWatermarkBytes) {
      while (
        this.pixelMapQueue.length > 0 &&
        this.queuedPixelMapBytes > this.pixelMapQueueLowWatermarkBytes
      ) {
        this.dropOldestPixelMap();
      }
    }

    // 保证入队后不超过条数和字节预算
    while (
      this.pixelMapQueue.length > 0 &&
      (
        this.pixelMapQueue.length >= this.maxPixelMapQueueSize ||
        this.queuedPixelMapBytes + normalizedBytes > this.maxPixelMapQueueBytes
      )
    ) {
      this.dropOldestPixelMap();
    }

    // latest-wins：若仍无法满足预算，丢弃当前帧
    if (this.queuedPixelMapBytes + normalizedBytes > this.maxPixelMapQueueBytes) {
      try {
        pixelMap.release();
      } catch (error) {
        // 忽略释放错误
      }
      return;
    }

    this.pixelMapQueue.push(new PixelMapQueueEntry(pixelMap, normalizedBytes));
    this.queuedPixelMapBytes += normalizedBytes;
  }

  /**
   * 丢弃队首PixelMap并释放资源
   */
  private dropOldestPixelMap(): void {
    const dropped = this.pixelMapQueue.shift();
    if (!dropped) {
      return;
    }

    this.queuedPixelMapBytes = Math.max(0, this.queuedPixelMapBytes - dropped.estimatedBytes);
    try {
      dropped.pixelMap.release();
    } catch (error) {
      // 忽略释放错误
    }
  }

  /**
   * 是否允许当前Capture进入显示队列
   * 在高压力场景下，丢弃低价值增量帧，优先保留关键帧/变化较大的帧
   */
  private shouldEnqueueCapture(capture: Capture): boolean {
    // keyframe始终保留
    if (capture.reset) {
      return true;
    }

    const pressureRatio = this.maxPixelMapQueueBytes > 0
      ? this.queuedPixelMapBytes / this.maxPixelMapQueueBytes
      : 0;
    if (pressureRatio < this.pressureStartRatio) {
      return true;
    }

    const totalTiles = capture.dirtyTiles.length;
    if (totalTiles <= 0) {
      return false;
    }

    let dirtyCount = 0;
    for (let i = 0; i < totalTiles; i++) {
      const tile = capture.dirtyTiles[i];
      if (tile !== null && tile.capture !== null) {
        dirtyCount++;
      }
    }

    const dirtyRatio = dirtyCount / totalTiles;

    // skipped/merged大于0通常表示中间态增量帧，在高压力且改动小的场景可优先丢弃
    const lowValueIncremental = (capture.skipped > 0 || capture.merged > 0) &&
      dirtyRatio < this.pressureDropDirtyTileRatio;

    return !lowValueIncremental;
  }

  /**
   * 估算PixelMap内存占用（按RGBA_8888）
   */
  private estimatePixelMapBytes(capture: Capture): number {
    const base = capture.width * capture.height * 4;

    // 低脏块增量帧设置更小的估算权重，提升关键帧保留概率
    if (capture.reset) {
      return base;
    }

    const totalTiles = capture.dirtyTiles.length;
    if (totalTiles <= 0) {
      return Math.floor(base * 0.5);
    }

    let dirtyCount = 0;
    for (let i = 0; i < totalTiles; i++) {
      const tile = capture.dirtyTiles[i];
      if (tile !== null && tile.capture !== null) {
        dirtyCount++;
      }
    }

    const dirtyRatio = dirtyCount / totalTiles;
    const dynamicWeight = 0.5 + Math.min(0.5, dirtyRatio);
    return Math.floor(base * dynamicWeight);
  }

  /**
   * 获取PixelMap队列的大小
   * @returns number 队列中的PixelMap数量
   */
  getPixelMapQueueSize(): number {
    return this.pixelMapQueue.length;
  }

  /**
   * 清空PixelMap队列
   */
  clearPixelMapQueue(): void {
    // 释放队列中所有PixelMap资源
    for (const entry of this.pixelMapQueue) {
      try {
        entry.pixelMap.release();
      } catch (error) {
        // 忽略释放错误
      }
    }
    this.pixelMapQueue = [];
    this.queuedPixelMapBytes = 0;
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

  /**
   * 创建时调用
   */
  onCreate(): void {
    console.log('CaptureCache onCreate');
    // 初始化缓存
    this.cache = new Map();
    this.pixelMapQueue = [];
    this.queuedPixelMapBytes = 0;
  }

  /**
   * 启动时调用
   */
  onStart(): void {
    console.log('CaptureCache onStart');
    // 启动时的初始化操作
  }

  /**
   * 恢复时调用
   */
  onResume(): void {
    console.log('CaptureCache onResume');
    // 恢复时的操作
  }

  /**
   * 暂停时调用
   */
  onPause(): void {
    console.log('CaptureCache onPause');
    // 暂停时的操作
  }

  /**
   * 停止时调用
   */
  onStop(): void {
    console.log('CaptureCache onStop');
    // 停止时的操作
  }

  /**
   * 销毁时调用
   */
  onDestroy(): void {
    console.log('CaptureCache onDestroy');
    // 清理资源
    this.clear();
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

/**
 * PixelMap队列项
 */
class PixelMapQueueEntry {
  readonly pixelMap: image.PixelMap;
  readonly estimatedBytes: number;

  constructor(pixelMap: image.PixelMap, estimatedBytes: number) {
    this.pixelMap = pixelMap;
    this.estimatedBytes = estimatedBytes;
  }
}
