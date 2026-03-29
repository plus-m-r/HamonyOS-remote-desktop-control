/**
 * 图像处理流水线接口
 *
 * 将接收到的压缩图像数据转换为可渲染的像素数据
 * 完整链路：TCP接收 → 协议解析 → 图像解压 → 图像组装 → 图像渲染
 */

import { IImageDecompressor, DecompressResult } from './IImageDecompressor';
import { IImageAssembler, AssembleResult } from './IImageAssembler';
import { IImageRenderer, RenderResult, ImageFrame } from './IImageRenderer';

/**
 * 流水线配置
 */
export interface PipelineConfig {
  /** 目标帧率 */
  targetFps: number;
  /** 是否启用降帧 */
  enableFrameDropping: boolean;
  /** 最大待处理帧数 */
  maxPendingFrames: number;
}

/**
 * 流水线状态
 */
export enum PipelineState {
  IDLE = 'IDLE',
  PROCESSING = 'PROCESSING',
  PAUSED = 'PAUSED',
  ERROR = 'ERROR'
}

/**
 * 帧数据
 */
export interface PipelineFrame {
  /** 压缩后的数据 */
  compressedData: ArrayBuffer;
  /** 压缩方法 */
  compressionMethod: number;
  /** 时间戳 */
  timestamp: number;
  /** 帧序号 */
  sequenceNumber: number;
}

/**
 * 流水线进度回调
 */
export type PipelineProgressCallback = (progress: {
  /** 当前处理的帧序号 */
  currentFrame: number;
  /** 总帧数 */
  totalFrames: number;
  /** 当前阶段 */
  stage: 'decompress' | 'assemble' | 'render';
}) => void;

/**
 * 流水线错误回调
 */
export type PipelineErrorCallback = (error: Error, stage: 'decompress' | 'assemble' | 'render') => void;

/**
 * 流水线完成回调
 */
export type PipelineCompleteCallback = (result: {
  /** 成功处理的帧数 */
  successFrames: number;
  /** 失败的帧数 */
  failedFrames: number;
  /** 平均处理时间（毫秒） */
  averageProcessingTime: number;
}) => void;

/**
 * 图像处理流水线接口
 */
export interface IImageProcessingPipeline {
  /**
   * 初始化流水线
   * @param config 流水线配置
   * @param decompressor 图像解压器
   * @param assembler 图像组装器
   * @param renderer 图像渲染器
   */
  init(
    config: PipelineConfig,
    decompressor: IImageDecompressor,
    assembler: IImageAssembler,
    renderer: IImageRenderer
  ): void;

  /**
   * 启动流水线
   */
  start(): void;

  /**
   * 暂停流水线
   */
  pause(): void;

  /**
   * 恢复流水线
   */
  resume(): void;

  /**
   * 停止流水线
   */
  stop(): void;

  /**
   * 提交待处理的帧
   * @param frame 帧数据
   */
  submitFrame(frame: PipelineFrame): void;

  /**
   * 获取流水线状态
   */
  getState(): PipelineState;

  /**
   * 获取待处理帧数
   */
  getPendingFrameCount(): number;

  /**
   * 设置进度回调
   */
  setProgressCallback(callback: PipelineProgressCallback | null): void;

  /**
   * 设置错误回调
   */
  setErrorCallback(callback: PipelineErrorCallback | null): void;

  /**
   * 设置完成回调
   */
  setCompleteCallback(callback: PipelineCompleteCallback | null): void;

  /**
   * 获取统计信息
   */
  getStatistics(): {
    /** 已处理的总帧数 */
    totalProcessedFrames: number;
    /** 平均处理时间（毫秒） */
    averageProcessingTime: number;
    /** 解压平均耗时 */
    averageDecompressTime: number;
    /** 组装平均耗时 */
    averageAssembleTime: number;
    /** 渲染平均耗时 */
    averageRenderTime: number;
    /** 当前帧率 */
    currentFps: number;
  };

  /**
   * 重置流水线
   */
  reset(): void;

  /**
   * 销毁流水线
   */
  destroy(): void;
}
