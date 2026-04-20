/**
 * 图像组装器实现
 *
 * 实现 IImageAssembler 接口
 */

import { IImageAssembler, AssemblerConfig, AssembleResult } from './IImageAssembler';
import { Capture } from './Capture';

export class ImageAssemblerImpl implements IImageAssembler {
  private config: AssemblerConfig | null = null;
  private assembleTimes: number[] = [];
  private prevBuffer: Uint8Array | null = null;
  private prevWidth: number = 0;
  private prevHeight: number = 0;
  private isInitialized = false;

  init(config: AssemblerConfig): void {
    this.config = config;
    this.isInitialized = true;
    console.debug('ImageAssemblerImpl: Initialized');
  }

  async assemble(
    capture: Capture,
    prevBuffer?: Uint8Array | null,
    prevWidth?: number,
    prevHeight?: number
  ): Promise<AssembleResult> {
    if (!this.isInitialized || !this.config) {
      throw new Error('Assembler not initialized');
    }

    const startTime = Date.now();

    try {
      let bufferToUse: Uint8Array | null = null;
      let widthToUse: number = 0;
      let heightToUse: number = 0;

      // 优先使用传入的前一帧，其次使用内部缓存的前一帧
      if (this.config.enableBufferReuse) {
        if (prevBuffer && prevWidth === capture.width && prevHeight === capture.height) {
          bufferToUse = prevBuffer;
          widthToUse = prevWidth;
          heightToUse = prevHeight;
        } else if (this.prevBuffer && this.prevWidth === capture.width && this.prevHeight === capture.height) {
          bufferToUse = this.prevBuffer;
          widthToUse = this.prevWidth;
          heightToUse = this.prevHeight;
        }
      }

      // 使用 Capture.createImageBuffer 组装
      const pixelBuffer = capture.createImageBuffer(
        bufferToUse,
        widthToUse,
        heightToUse
      );

      // 缓存当前帧用于下一帧复用
      this.prevBuffer = pixelBuffer;
      this.prevWidth = capture.width;
      this.prevHeight = capture.height;

      const elapsedTime = Date.now() - startTime;
      this.recordAssembleTime(elapsedTime);

      return {
        pixelBuffer,
        width: capture.width,
        height: capture.height,
        elapsedTime,
        processedTiles: capture.dirtyTiles.filter(t => t !== null).length
      };

    } catch (error) {
      console.error('ImageAssemblerImpl: Assemble failed', error);
      throw new Error(error instanceof Error ? error.message : String(error));
    }
  }

  hasReusableBuffer(width: number, height: number): boolean {
    return this.config !== null &&
      this.config.enableBufferReuse &&
      this.prevBuffer !== null &&
      this.prevWidth === width &&
      this.prevHeight === height;
  }

  getAverageAssembleTime(): number {
    if (this.assembleTimes.length === 0) {
      return 0;
    }
    const sum = this.assembleTimes.reduce((a, b) => a + b, 0);
    return sum / this.assembleTimes.length;
  }

  releaseBuffer(buffer: Uint8Array): void {
    // 这里可以实现缓冲区池逻辑
    // 暂时直接忽略，依赖 GC 清理
  }

  reset(): void {
    this.assembleTimes = [];
    this.prevBuffer = null;
    this.prevWidth = 0;
    this.prevHeight = 0;
    console.debug('ImageAssemblerImpl: Reset');
  }

  destroy(): void {
    this.assembleTimes = [];
    this.prevBuffer = null;
    this.prevWidth = 0;
    this.prevHeight = 0;
    this.config = null;
    this.isInitialized = false;
    console.debug('ImageAssemblerImpl: Destroyed');
  }

  private recordAssembleTime(time: number): void {
    this.assembleTimes.push(time);
    if (this.assembleTimes.length > 100) {
      this.assembleTimes.shift();
    }
  }
}
