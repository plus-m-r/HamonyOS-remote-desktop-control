import { ConcreteCmd } from '../models/ConcreteCmd';

/**
 * Worker 仓库接口
 * 
 * 抽象 Worker 操作，便于：
 * 1. 单元测试时 Mock Worker 行为
 * 2. 控制 Worker 执行（同步/异步）
 * 3. 模拟 Worker 错误场景
 */

/**
 * 图像处理任务
 */
export interface ImageProcessTask {
  imageData: ArrayBuffer | string;
  compressionMethodOrdinal: number;
}

/**
 * 图像处理结果
 */
export interface ImageProcessResult {
  imageBuffer: ArrayBuffer;
  width: number;
  height: number;
}

/**
 * 协议解析任务
 */
export interface ProtocolParseTask {
  existingBuffer: ArrayBuffer;
  newData: ArrayBuffer;
}

/**
 * 协议解析结果
 */
export interface ProtocolParseResult {
  remainingBuffer: ArrayBuffer;
  commands: Record<string, Object>[];
}

/**
 * Worker 仓库接口
 */
export interface IWorkerRepository {
  /**
   * 初始化 Worker
   */
  init(): void;

  /**
   * 处理图像数据
   * @param task 图像处理任务
   * @returns Promise<ImageProcessResult>
   */
  processImage(task: ImageProcessTask): Promise<ImageProcessResult>;

  /**
   * 解析协议数据
   * @param task 协议解析任务
   * @returns Promise<ProtocolParseResult>
   */
  parseProtocol(task: ProtocolParseTask): Promise<ProtocolParseResult>;

  /**
   * 获取待处理任务数量
   */
  getPendingTaskCount(): number;

  /**
   * 获取正在处理的任务数量
   */
  getProcessingTaskCount(): number;

  /**
   * 销毁 Worker 资源
   */
  destroy(): void;
}
