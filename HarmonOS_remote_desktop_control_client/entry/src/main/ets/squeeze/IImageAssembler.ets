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
   * @returns Promise<AssembleResult>
   */
  assemble(capture: Capture): Promise<AssembleResult>;

  /**
   * 判断当前组装器是否已经持有可复用的上一帧缓冲区
   */
  hasReusableBuffer(width: number, height: number): boolean;

  /**
   * 重置组装器状态
   */
  reset(): void;

  /**
   * 销毁组装器
   */
  destroy(): void;
}
