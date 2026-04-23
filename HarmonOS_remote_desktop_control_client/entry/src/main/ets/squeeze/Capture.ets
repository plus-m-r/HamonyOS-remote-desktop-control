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

  constructor(
    id: number,
    reset: boolean,
    skipped: number,
    merged: number,
    width: number,
    height: number,
    tileWidth: number,
    tileHeight: number,
    dirtyTiles: (CaptureTile | null)[]
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
    const bufferSize = capWidth * capHeight * 4;

    // 检查是否为灰度图像
    const isGray = this.dirtyTiles.some(tile =>
      tile !== null && tile.capture !== null &&
      tile.capture.size() === tile.width * tile.height
    );

    for (let i = 0; i < this.dirtyTiles.length; i++) {
      const tile = this.dirtyTiles[i];
      
      if (tile === null || tile.capture === null) {
        // 非脏瓦片：保持之前的内容
        continue;
      }

      const src = tile.capture.getInternal();
      const tileWidth = tile.width;
      const tileHeight = tile.height;

      let destPos = tile.y * capWidthByteSize + tile.x * 4;

      // 根据数据大小判断处理方式
      if (isGray) {
        this.processGrayData(buffer, src, tileWidth, tileHeight, destPos, capWidthByteSize, bufferSize);
      } else {
        this.processArgbData(buffer, src, tileWidth, tileHeight, destPos, capWidthByteSize, bufferSize);
      }
    }
  }

  /**
   * 处理8位灰度数据，转换为32位RGBA格式
   * 与Java端一致：灰度值扩展到R、G、B通道，A通道设为255（不透明）
   */
  private processGrayData(
    buffer: Uint8Array,
    src: Uint8Array,
    tileWidth: number,
    tileHeight: number,
    destPos: number,
    capWidthByteSize: number,
    bufferSize: number
  ): void {
    let srcPos = 0;
    
    for (let y = 0; y < tileHeight; y++) {
      for (let x = 0; x < tileWidth; x++) {
        if (srcPos < src.length) {
          // 将8位灰度值转换为32位RGBA格式
          const grayValue = src[srcPos++];
          buffer[destPos] = grayValue;     // R
          buffer[destPos + 1] = grayValue; // G
          buffer[destPos + 2] = grayValue; // B
          buffer[destPos + 3] = 255;       // A (不透明)
        }
        
        destPos += 4;
      }
      destPos += capWidthByteSize - tileWidth * 4;
    }
  }

  /**
   * 处理32位BGRA数据 - 与Java客户端一致
   */
  private processArgbData(
    buffer: Uint8Array,
    src: Uint8Array,
    tileWidth: number,
    tileHeight: number,
    destPos: number,
    capWidthByteSize: number,
    bufferSize: number
  ): void {
    const tileWidthByteSize = tileWidth * 4;
    
    for (let y = 0; y < tileHeight; y++) {
      const srcPos = y * tileWidthByteSize;
      const rowSize = Math.min(tileWidthByteSize, src.length - srcPos);
      
      // 直接批量复制BGRA数据（Blue, Green, Red, Alpha）
      // 与Java客户端一致：保持原始数据，不修改透明度
      buffer.set(src.subarray(srcPos, srcPos + rowSize), destPos);
      destPos += capWidthByteSize;
    }
  }
}


