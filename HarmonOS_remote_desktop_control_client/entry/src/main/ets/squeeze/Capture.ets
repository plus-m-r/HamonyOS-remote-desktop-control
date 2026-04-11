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
   * 与Java客户端一致：保持灰度值，A通道设为255（不透明）
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
          // 灰度值同时设置到R、G、B通道，A通道设为255（不透明）
          const grayValue = src[srcPos++];
          buffer[destPos] = grayValue;     // R
          buffer[destPos + 1] = grayValue; // G
          buffer[destPos + 2] = grayValue; // B
          buffer[destPos + 3] = 0xff;      // A (与Java客户端一致：设置为不透明)
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

  /**
   * 保存所有瓦片数据到文件中，用于与Java客户端数据对比
   */
  async saveAllTilesData(): Promise<void> {
    try {
      // 确保数据目录存在
      const dataDir: string = 'data';
      
      try {
        fs.accessSync(dataDir);
      } catch {
        fs.mkdirSync(dataDir, true);
      }

      // 保存捕获信息
      const info: CaptureInfo = {
        id: this.id,
        reset: this.reset,
        width: this.width,
        height: this.height,
        tileWidth: this.tileWidth,
        tileHeight: this.tileHeight,
        dirtyTilesCount: this.dirtyTiles.length
      };
      const infoFile: string = dataDir + `/harmony_capture_${this.id}_info.txt`;
      const file = fs.openSync(infoFile, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      fs.writeSync(file.fd, JSON.stringify(info, null, 2));
      fs.closeSync(file);
      logManager.consoleLog(`[数据保存] 保存捕获信息到 ${infoFile}`);

      // 保存每个瓦片数据
      let tileIndex: number = 0;
      for (const tile of this.dirtyTiles) {
        if (tile !== null && tile !== undefined && tile.capture !== null) {
          const tileData: Uint8Array = tile.capture.getInternal();
          const tileFile: string = dataDir + `/harmony_tile_${this.id}_${tileIndex}.bin`;
          const file = fs.openSync(tileFile, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
          fs.writeSync(file.fd, tileData.buffer);
          fs.closeSync(file);
          logManager.consoleLog(`[数据保存] 保存瓦片 ${tileIndex} 到 ${tileFile}`);
        }
        tileIndex++;
      }

      logManager.consoleLog(`[数据保存] 完成保存 ${this.dirtyTiles.length} 个瓦片`);
    } catch (error) {
      logManager.error(PERF_DOMAIN, PERF_TAG, 'Failed to save tiles data: %{public}s', error);
    }
  }

  /**
   * 保存渲染前后的完整图像数据
   */
  async saveRenderedImages(beforeBuffer: Uint8Array, afterBuffer: Uint8Array): Promise<void> {
    try {
      // 确保数据目录存在
      const dataDir: string = 'data';
      
      try {
        fs.accessSync(dataDir);
      } catch {
        fs.mkdirSync(dataDir, true);
      }

      // 保存渲染前图像
      if (beforeBuffer.length > 0) {
        const beforeFile: string = dataDir + `/harmony_before_draw_${this.id}.raw`;
        const file = fs.openSync(beforeFile, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
        fs.writeSync(file.fd, beforeBuffer.buffer);
        fs.closeSync(file);
        logManager.consoleLog(`[数据保存] 保存渲染前图像到 ${beforeFile}`);
      }

      // 保存渲染后图像
      if (afterBuffer.length > 0) {
        const afterFile: string = dataDir + `/harmony_after_draw_${this.id}.raw`;
        const file = fs.openSync(afterFile, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
        fs.writeSync(file.fd, afterBuffer.buffer);
        fs.closeSync(file);
        logManager.consoleLog(`[数据保存] 保存渲染后图像到 ${afterFile}`);
      }
    } catch (error) {
      logManager.error(PERF_DOMAIN, PERF_TAG, 'Failed to save rendered images: %{public}s', error);
    }
  }

  /**
   * 保存渲染统计信息
   */
  async saveRenderStats(processedTiles: number, skippedTiles: number, renderTime: number): Promise<void> {
    try {
      // 确保数据目录存在
      const dataDir: string = 'data';
      
      try {
        fs.accessSync(dataDir);
      } catch {
        fs.mkdirSync(dataDir, true);
      }

      // 保存渲染统计信息
      const stats: RenderStats = {
        id: this.id,
        processedTiles: processedTiles,
        skippedTiles: skippedTiles,
        renderTime: renderTime,
        totalTiles: this.dirtyTiles.length
      };
      const statsFile: string = dataDir + `/harmony_render_stats_${this.id}.json`;
      const file = fs.openSync(statsFile, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      fs.writeSync(file.fd, JSON.stringify(stats, null, 2));
      fs.closeSync(file);
      logManager.consoleLog(`[数据保存] 保存渲染统计信息到 ${statsFile}`);
    } catch (error) {
      logManager.error(PERF_DOMAIN, PERF_TAG, 'Failed to save render stats: %{public}s', error);
    }
  }
}


