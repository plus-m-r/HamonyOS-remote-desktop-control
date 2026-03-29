/**
 * 图像渲染器接口
 *
 * 抽象图像渲染操作，便于：
 * 1. 单元测试时 Mock 渲染行为
 * 2. 支持不同的渲染策略
 * 3. 模拟渲染错误场景
 */

/**
 * 渲染器配置
 */
export interface RendererConfig {
  /** 启用双缓冲 */
  enableDoubleBuffer: boolean;
  /** 渲染质量 */
  renderQuality: 'low' | 'medium' | 'high';
  /** 缩放模式 */
  scaleMode: 'fit' | 'fill' | 'center';
}

/**
 * 渲染结果
 */
export interface RenderResult {
  /** 是否渲染成功 */
  success: boolean;
  /** 渲染耗时（毫秒） */
  elapsedTime: number;
  /** 渲染的帧序号 */
  frameNumber: number;
}

/**
 * 图像帧数据
 */
export interface ImageFrame {
  /** 像素数据 */
  pixelBuffer: Uint8Array;
  /** 图像宽度 */
  width: number;
  /** 图像高度 */
  height: number;
  /** 时间戳 */
  timestamp: number;
  /** 帧序号 */
  frameNumber: number;
}

/**
 * 图像渲染器接口
 */
export interface IImageRenderer {
  /**
   * 初始化渲染器
   * @param config 渲染器配置
   */
  init(config: RendererConfig): void;

  /**
   * 渲染图像帧
   * @param frame 图像帧数据
   * @returns Promise<RenderResult>
   */
  render(frame: ImageFrame): Promise<RenderResult>;

  /**
   * 清空渲染缓冲区
   */
  clear(): void;

  /**
   * 获取渲染统计信息
   */
  getStatistics(): {
    /** 已渲染的总帧数 */
    totalFrames: number;
    /** 平均渲染耗时（毫秒） */
    averageRenderTime: number;
    /** 最近的帧率 */
    recentFps: number;
  };

  /**
   * 重置渲染器状态
   */
  reset(): void;

  /**
   * 销毁渲染器
   */
  destroy(): void;
}
