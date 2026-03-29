/**
 * 图像组装器接口
 *
 * 抽象图像组装操作，便于：
 * 1. 单元测试时 Mock 组装行为
 * 2. 支持不同的组装策略
 * 3. 模拟组装错误场景
 */

import { Capture } from './Capture';

/**
 * 组装器配置
 */
export interface AssemblerConfig {
  /** 最大缓冲尺寸（字节） */
  maxBufferSize: number;
  /** 启用缓冲区复用 */
  enableBufferReuse: boolean;
}

/**
 * 图像组装结果
 */
export interface AssembleResult {
  /** 组装后的像素缓冲区 */
  pixelBuffer: Uint8Array;
  /** 图像宽度 */
  width: number;
  /** 图像高度 */
  height: number;
  /** 组装耗时（毫秒） */
  elapsedTime: number;
  /** 处理的瓦片数 */
  processedTiles: number;
}

/**
 * 图像组装器接口
 */
export interface IImageAssembler {
  /**
   * 初始化组装器
   * @param config 组装器配置
   */
  init(config: AssemblerConfig): void;

  /**
   * 组装图像数据
   * @param capture 图像数据
   * @param prevBuffer 前一帧缓冲区（可选）
   * @param prevWidth 前一帧宽度（可选）
   * @param prevHeight 前一帧高度（可选）
   * @returns Promise<AssembleResult>
   */
  assemble(
    capture: Capture,
    prevBuffer?: Uint8Array | null,
    prevWidth?: number,
    prevHeight?: number
  ): Promise<AssembleResult>;

  /**
   * 获取组装耗时统计
   * @returns 平均组装耗时（毫秒）
   */
  getAverageAssembleTime(): number;

  /**
   * 释放缓冲区
   * @param buffer 要释放的缓冲区
   */
  releaseBuffer(buffer: Uint8Array): void;

  /**
   * 重置组装器状态
   */
  reset(): void;

  /**
   * 销毁组装器
   */
  destroy(): void;
}
