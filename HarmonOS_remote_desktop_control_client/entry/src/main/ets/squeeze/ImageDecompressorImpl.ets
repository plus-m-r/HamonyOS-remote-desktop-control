/**
 * 图像解压器实现
 *
 * 实现 IImageDecompressor 接口
 */

import {
  IImageDecompressor,
  DecompressorConfig,
  DecompressResult
} from './IImageDecompressor';
import { Compressor, CompressionMethod } from './Compressor';
import { TileCache, NullTileCache } from './TileCache';
import { Capture } from './Capture';
import { MemByteBuffer } from './MemByteBuffer';

export class ImageDecompressorImpl implements IImageDecompressor {
  private config: DecompressorConfig | null = null;
  private tileCache: TileCache = new NullTileCache();
  private decompressTimes: number[] = [];
  private isInitialized = false;

  init(config: DecompressorConfig): void {
    this.config = config;
    this.tileCache = config.useTileCache ? new NullTileCache() : new NullTileCache();
    this.isInitialized = true;
    console.info('ImageDecompressorImpl: Initialized');
  }

  async decompress(compressedData: ArrayBuffer): Promise<DecompressResult> {
    if (!this.isInitialized || !this.config) {
      throw new Error('Decompressor not initialized');
    }

    const startTime = Date.now();

    try {
      // 转换为 MemByteBuffer
      const zippedData = MemByteBuffer.fromArray(new Uint8Array(compressedData));

      // 获取压缩器
      const compressor = Compressor.get(this.config.compressionMethod);

      // 解压
      const capture = await compressor.decompress(this.tileCache, zippedData);

      // 通知缓存处理完成
      this.tileCache.onCaptureProcessed();

      const elapsedTime = Date.now() - startTime;
      this.recordDecompressTime(elapsedTime);

      return {
        capture,
        elapsedTime
      };

    } catch (error) {
      console.error('ImageDecompressorImpl: Decompress failed', error);
      throw error;
    }
  }

  getAverageDecompressTime(): number {
    if (this.decompressTimes.length === 0) {
      return 0;
    }
    const sum = this.decompressTimes.reduce((a, b) => a + b, 0);
    return sum / this.decompressTimes.length;
  }

  reset(): void {
    this.decompressTimes = [];
    this.tileCache = this.config?.useTileCache ? new NullTileCache() : new NullTileCache();
    console.info('ImageDecompressorImpl: Reset');
  }

  destroy(): void {
    this.decompressTimes = [];
    this.config = null;
    this.isInitialized = false;
    console.info('ImageDecompressorImpl: Destroyed');
  }

  private recordDecompressTime(time: number): void {
    this.decompressTimes.push(time);
    // 只保留最近100次记录
    if (this.decompressTimes.length > 100) {
      this.decompressTimes.shift();
    }
  }
}
