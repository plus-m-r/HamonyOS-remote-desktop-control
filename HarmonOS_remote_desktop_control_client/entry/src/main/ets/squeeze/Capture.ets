import { CaptureTile } from './CaptureTile';
import { BufferPool } from '../utils/ObjectPool';
import { logManager } from '../utils/LogManager';
import { util } from '@kit.ArkTS';
import fs from '@ohos.file.fs';
import { Context } from '@kit.AbilityKit';

const PERF_DOMAIN = 0xFF00;
const PERF_TAG = 'CapturePerf';

// 接口定义
interface CaptureInfo {
  id: number;
  reset: boolean;
  width: number;
  height: number;
  tileWidth: number;
  tileHeight: number;
  dirtyTilesCount: number;
}

interface RenderStats {
  id: number;
  processedTiles: number;
  skippedTiles: number;
  renderTime: number;
  totalTiles: number;
}

interface ContextWithFilesDir {
  filesDir: string;
}



export class Capture {
  readonly id: number;
  readonly reset: boolean;
  readonly skipped: number;
  readonly merged: number;
  readonly width: number;
  readonly height: number;
  readonly tileWidth: number;
  readonly tileHeight: number;
  readonly dirtyTiles: (CaptureTile | null)[];
  readonly isGrayFrame: boolean;

  constructor(
    id: number,
    reset: boolean,
    skipped: number,
    merged: number,
    width: number,
    height: number,
    tileWidth: number,
    tileHeight: number,
    dirtyTiles: (CaptureTile | null)[],
    isGrayFrame: boolean = false
  ) {
    this.id = id;
    this.reset = reset;
    this.skipped = skipped;
    this.merged = merged;
    this.width = width;
    this.height = height;
    this.tileWidth = tileWidth;
    this.tileHeight = tileHeight;
    this.dirtyTiles = [...dirtyTiles];
    this.isGrayFrame = isGrayFrame;
  }

  createImageBuffer(prevBuffer: Uint8Array | null, prevWidth: number, prevHeight: number): Uint8Array {
    const capWidth = this.width;
    const capHeight = this.height;
    const bufferSize = capWidth * capHeight * 4;

    let buffer: Uint8Array;
    const bufferPool = BufferPool.getInstance();

    // 优先使用对象池，其次复用前一帧缓冲区
    if (prevBuffer !== null && capWidth === prevWidth && capHeight === prevHeight && prevBuffer.length === bufferSize) {
      buffer = prevBuffer;
      
      // 如果是重置操作，清空缓冲区
      if (this.reset) {
        buffer.fill(0);
      }
    } else {
      // 使用对象池获取缓冲区
      buffer = bufferPool.acquireBuffer(bufferSize);
      
      // 如果是重置操作，确保缓冲区为空
      if (this.reset) {
        buffer.fill(0);
      }
    }

    // 绘制到缓冲区
    this.drawToBuffer(buffer);

    return buffer;
  }

  /**
   * 绘制 dirty tiles 到给定缓冲区
   * @param buffer 目标缓冲区
   */
  drawToBuffer(buffer: Uint8Array): void {
    const capWidth = this.width;
    const capHeight = this.height;
    const capWidthByteSize = capWidth * 4;

    // 使用预计算的isGrayFrame标志，避免运行时遍历所有tile判断灰度
    const isGray = this.isGrayFrame;
    
    // 标记Tile处理开始
    const tileProcessingStart = Date.now();
    let processedTileCount = 0;

    for (let i = 0; i < this.dirtyTiles.length; i++) {
      const tile = this.dirtyTiles[i];
      
      if (tile === null || tile.capture === null) {
        continue;
      }

      const src = tile.capture.getInternal();
      const tileWidth = tile.width;
      const tileHeight = tile.height;
      const destPos = tile.y * capWidthByteSize + tile.x * 4;

      if (isGray) {
        this.processGrayDataOptimized(buffer, src, tileWidth, tileHeight, destPos, capWidthByteSize);
      } else {
        this.processArgbDataOptimized(buffer, src, tileWidth, tileHeight, destPos, capWidthByteSize);
      }
      
      processedTileCount++;
    }
    
    // 记录Tile处理完成（可以通过全局PerformanceMonitor记录）
    // 注意：这里不直接调用PerformanceMonitor，避免循环依赖
    // 可以在上层ImageAssembler中记录
  }

  /**
   * 优化版：处理32位ARGB数据 - 使用批量拷贝
   */
  private processArgbDataOptimized(
    buffer: Uint8Array,
    src: Uint8Array,
    tileWidth: number,
    tileHeight: number,
    destPos: number,
    capWidthByteSize: number
  ): void {
    const tileWidthByteSize = tileWidth * 4;
    
    // 逐行批量拷贝，使用Uint8Array.set（类似Java的System.arraycopy）
    for (let y = 0; y < tileHeight; y++) {
      const srcOffset = y * tileWidthByteSize;
      const destOffset = destPos + y * capWidthByteSize;
      
      // 批量拷贝整行数据
      buffer.set(src.subarray(srcOffset, srcOffset + tileWidthByteSize), destOffset);
    }
  }

  /**
   * 优化版：处理8位灰度数据，转换为32位RGBA格式
   */
  private processGrayDataOptimized(
    buffer: Uint8Array,
    src: Uint8Array,
    tileWidth: number,
    tileHeight: number,
    destPos: number,
    capWidthByteSize: number
  ): void {
    let srcPos = 0;
    
    for (let y = 0; y < tileHeight; y++) {
      const destRowOffset = destPos + y * capWidthByteSize;
      
      // 展开内层循环，减少索引计算开销
      for (let x = 0; x < tileWidth; x++) {
        const grayValue = src[srcPos++];
        const offset = destRowOffset + x * 4;
        
        // 一次性设置RGBA四个通道
        buffer[offset] = grayValue;
        buffer[offset + 1] = grayValue;
        buffer[offset + 2] = grayValue;
        buffer[offset + 3] = 255;
      }
    }
  }
}


