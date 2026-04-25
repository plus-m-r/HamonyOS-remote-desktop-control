/**
 * 图像组装器实现
 *
 * 实现 IImageAssembler 接口
 */

import { IImageAssembler, AssemblerConfig, AssembleResult } from './IImageAssembler';
import { Capture } from './Capture';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001;
const TAG = 'ImageAssemblerImpl';

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
    hilog.debug(DOMAIN, TAG, 'Initialized');
  }

  async assemble(capture: Capture): Promise<AssembleResult> {
    if (!this.isInitialized || !this.config) {
      throw new Error('Assembler not initialized');
    }

    const startTime = Date.now();

    try {
      // 标记Tile处理开始
      const tileProcessingStart = Date.now();
      
      let bufferToUse: Uint8Array | null = null;
      let widthToUse: number = 0;
      let heightToUse: number = 0;

      // 使用内部缓存的前一帧缓冲区
      if (this.config.enableBufferReuse && 
          this.prevBuffer && 
          this.prevWidth === capture.width && 
          this.prevHeight === capture.height) {
        bufferToUse = this.prevBuffer;
        widthToUse = this.prevWidth;
        heightToUse = this.prevHeight;
      }

      // 使用 Capture.createImageBuffer 组装（内部会调用drawToBuffer）
      const pixelBuffer = capture.createImageBuffer(
        bufferToUse,
        widthToUse,
        heightToUse
      );
      
      // 计算Tile处理时间
      const tileProcessingTime = Date.now() - tileProcessingStart;

      // 缓存当前帧用于下一帧复用
      this.prevBuffer = pixelBuffer;
      this.prevWidth = capture.width;
      this.prevHeight = capture.height;

      const elapsedTime = Date.now() - startTime;
      this.recordAssembleTime(elapsedTime);
      
      // 统计处理的tile数量
      const processedTiles = capture.dirtyTiles.filter(t => t !== null).length;

      return {
        pixelBuffer,
        width: capture.width,
        height: capture.height,
        elapsedTime,
        processedTiles
      };

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Assemble failed: %{public}s', error instanceof Error ? error.message : String(error));
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

  reset(): void {
    this.assembleTimes = [];
    this.prevBuffer = null;
    this.prevWidth = 0;
    this.prevHeight = 0;
    hilog.debug(DOMAIN, TAG, 'Reset');
  }

  destroy(): void {
    this.assembleTimes = [];
    this.config = null;
    this.isInitialized = false;
    hilog.debug(DOMAIN, TAG, 'Destroyed');
  }

  private recordAssembleTime(time: number): void {
    this.assembleTimes.push(time);
    if (this.assembleTimes.length > 100) {
      this.assembleTimes.shift();
    }
  }
}
