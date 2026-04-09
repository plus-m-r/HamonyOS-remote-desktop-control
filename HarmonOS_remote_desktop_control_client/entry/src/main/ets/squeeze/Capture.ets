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
    const startTime = Date.now();

    logManager.consoleLog(`[图像组装] 开始, 尺寸: ${capWidth}x${capHeight}, tiles: ${this.dirtyTiles.length}`);

    // 安全检查：确保宽度和高度是合理的
    if (capWidth <= 0 || capHeight <= 0 || capWidth > 10000 || capHeight > 10000) {
      logManager.error(PERF_DOMAIN, PERF_TAG, 'Invalid dimensions: %{public}dx%{public}d', capWidth, capHeight);
      return new Uint8Array(0);
    }

    const bufferSize = capWidth * capHeight * 4;

    // 安全检查：确保bufferSize不会溢出
    if (bufferSize > 100000000) { // 100MB限制
      logManager.error(PERF_DOMAIN, PERF_TAG, 'Buffer size too large: %{public}d', bufferSize);
      return new Uint8Array(0);
    }

    let buffer: Uint8Array;
    const bufferPool = BufferPool.getInstance();

    // 优先使用对象池，其次复用前一帧缓冲区
    if (prevBuffer !== null && capWidth === prevWidth && capHeight === prevHeight && prevBuffer.length === bufferSize) {
      buffer = prevBuffer;
      logManager.consoleLog('[图像组装] 复用前一帧缓冲区');
      
      // 如果是重置操作，清空缓冲区
      if (this.reset) {
        buffer.fill(0);
        logManager.consoleLog('[图像组装] 重置操作，清空缓冲区');
      }
    } else {
      // 使用对象池获取缓冲区
      buffer = bufferPool.acquireBuffer(bufferSize);
      logManager.consoleLog(`[图像组装] 从对象池获取缓冲区, 大小: ${bufferSize}`);
      
      // 如果是重置操作，确保缓冲区为空
      if (this.reset) {
        buffer.fill(0);
        logManager.consoleLog('[图像组装] 重置操作，清空缓冲区');
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

    let processedTiles = 0;
    let skippedTiles = 0;
    const startTime = Date.now();

    // 保存渲染前图像
    const beforeBuffer = new Uint8Array(buffer);

    // 检查是否为灰度图像
    const isGray = this.dirtyTiles.some(tile =>
      tile !== null && tile !== undefined && tile.capture !== null &&
      tile.capture.size() === tile.width * tile.height
    );

    // 计算瓦片网格大小
    const tilesPerRow = Math.ceil(capWidth / this.tileWidth);
    const tilesPerCol = Math.ceil(capHeight / this.tileHeight);

    for (let i = 0; i < this.dirtyTiles.length; i++) {
      const tile = this.dirtyTiles[i];
      
      if (tile === null || tile === undefined || tile.capture === null) {
        // 非脏瓦片：保持之前的内容（已经在缓冲区中）
        // 从索引计算瓦片位置，确保缓冲区初始化正确
        const tileRow = Math.floor(i / tilesPerRow);
        const tileCol = i % tilesPerRow;
        const tileX = tileCol * this.tileWidth;
        const tileY = tileRow * this.tileHeight;
        
        // 验证瓦片位置是否有效
        if (tileX < 0 || tileY < 0 || tileX >= capWidth || tileY >= capHeight) {
          logManager.warn(PERF_DOMAIN, PERF_TAG, 'Non-dirty tile position out of bounds: (%{public}d, %{public}d)', tileX, tileY);
        }
        
        skippedTiles++;
        continue;
      }

      const src = tile.capture.getInternal();
      const tileWidth = tile.width;
      const tileHeight = tile.height;

      // 安全检查：确保tile位置在有效范围内
      if (tile.x < 0 || tile.y < 0 || tile.x >= capWidth || tile.y >= capHeight) {
        logManager.error(PERF_DOMAIN, PERF_TAG, 'Tile position out of bounds: (%{public}d, %{public}d)', tile.x, tile.y);
        continue;
      }

      let destPos = tile.y * capWidthByteSize + tile.x * 4;

      // 安全检查：确保destPos在有效范围内
      if (destPos < 0 || destPos >= bufferSize) {
        logManager.error(PERF_DOMAIN, PERF_TAG, 'Destination position out of bounds: %{public}d', destPos);
        continue;
      }

      // 安全检查：确保数据长度在合理范围内
      if (src.length === 0) {
        logManager.warn(PERF_DOMAIN, PERF_TAG, 'Empty data for tile');
        continue;
      }

      // 根据数据大小判断处理方式
      if (isGray) {
        this.processGrayData(buffer, src, tileWidth, tileHeight, destPos, capWidthByteSize, bufferSize);
      } else {
        this.processArgbData(buffer, src, tileWidth, tileHeight, destPos, capWidthByteSize, bufferSize);
      }
      processedTiles++;
    }

    const renderTime = Date.now() - startTime;
    logManager.consoleLog(`[drawToBuffer] 完成, tiles: ${processedTiles}/${skippedTiles}, 时间: ${renderTime}ms`);
    // 保存渲染前后图像
    this.saveRenderedImages(beforeBuffer, buffer).catch((error: Error) => {
      logManager.error(PERF_DOMAIN, PERF_TAG, 'Failed to save rendered images: %{public}s', error);
    });

    // 保存渲染统计信息
    this.saveRenderStats(processedTiles, skippedTiles, renderTime).catch((error: Error) => {
      logManager.error(PERF_DOMAIN, PERF_TAG, 'Failed to save render stats: %{public}s', error);
    });
  }

  /**
   * 处理8位灰度数据，转换为32位ARGB格式
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
        // 确保不会写入超出buffer范围的数据
        if (destPos + 3 >= bufferSize) {
          console.error(`Capture: Would write beyond buffer bounds at destPos: ${destPos}`);
          return;
        }
        
        // 确保不会读取超出src范围的数据
        if (srcPos >= src.length) {
          // 数据不足时，保持现有数据不变
          // 与Java客户端一致：不填充默认值
        } else {
          // 将8位灰度值转换为32位ARGB格式
          // 灰度值同时设置到R、G、B通道，A通道设为255（不透明）
          const grayValue = src[srcPos++];
          buffer[destPos] = 0xff;      // A (与Java客户端一致：设置为不透明)
          buffer[destPos + 1] = grayValue; // R
          buffer[destPos + 2] = grayValue; // G
          buffer[destPos + 3] = grayValue;     // B
        }
        
        destPos += 4;
      }
      destPos += capWidthByteSize - tileWidth * 4;
    }
  }

  /**
   * 处理32位ARGB数据 - 与Java客户端一致
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
      
      // 确保不会写入超出buffer范围的数据
      if (destPos + rowSize > bufferSize) {
        console.error(`Capture: Would write beyond buffer bounds at destPos: ${destPos}`);
        break;
      }
      
      // 直接批量复制ARGB数据（Alpha, Red, Green, Blue）
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


