/**
 * 图像解压器接口
 *
 * 抽象图像解压操作，便于：
 * 1. 单元测试时 Mock 解压行为
 * 2. 统一处理不同压缩格式
 * 3. 模拟解压错误场景
 */

import { CompressionMethod } from './Compressor';
import { Capture } from './Capture';

/**
 * 解压器配置
 */
export interface DecompressorConfig {
  /** 压缩方法 */
  compressionMethod: CompressionMethod;
  /** 是否启用瓦片缓存 */
  useTileCache: boolean;
}

/**
 * 图像解压结果
 */
export interface DecompressResult {
  /** 解压后的图像数据 */
  capture: Capture;
  /** 解压耗时（毫秒） */
  elapsedTime: number;
}

/**
 * 图像解压器接口
 */
export interface IImageDecompressor {
  /**
   * 初始化解压器
   * @param config 解压器配置
   */
  init(config: DecompressorConfig): void;

  /**
   * 解压图像数据
   * @param compressedData 压缩后的数据
   * @returns Promise<DecompressResult>
   */
  decompress(compressedData: ArrayBuffer): Promise<DecompressResult>;

  /**
   * 获取解压耗时统计
   * @returns 平均解压耗时（毫秒）
   */
  getAverageDecompressTime(): number;

  /**
   * 重置解压器状态
   */
  reset(): void;

  /**
   * 销毁解压器
   */
  destroy(): void;
}
