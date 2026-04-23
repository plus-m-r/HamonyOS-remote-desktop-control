import { ConcreteCmd } from '../models/ConcreteCmd';
import { BaseService } from '../di/BaseService';

/**
 * Worker 仓库接口
 *
 * 抽象 Worker 操作，便于：
 * 1. 单元测试时 Mock Worker 行为
 * 2. 控制 Worker 执行（同步/异步）
 * 3. 模拟 Worker 错误场景
 *
 * 架构说明：
 * - 解压缩：在主线程完成（需要 Context）
 * - 帧处理（绘制瓦片）：在 Worker 线程完成
 */

/**
 * 帧处理任务（解压缩已在主线程完成）
 */
export interface FrameProcessTask {
  captureData: ArrayBuffer;
  prevBuffer: ArrayBuffer | null;
  prevWidth: number;
  prevHeight: number;
}

/**
 * 单个瓦片数据
 */
export interface TileData {
  x: number;
  y: number;
  width: number;
  height: number;
  capture: Uint8Array;
  singleLevel: number;
}

/**
 * 帧处理结果（帧合并由主线程 CaptureCache 完成）
 */
export interface FrameProcessResult {
  imageBuffer: ArrayBuffer;
  width: number;
  height: number;
  frameId: number;
  isKeyFrame: boolean;
  tileCount: number;
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
export interface IWorkerRepository extends BaseService {
  /**
   * 初始化 Worker
   */
  init(): void;

  /**
   * 处理帧数据（解压缩已在主线程完成）
   * @param task 帧处理任务
   * @returns Promise<FrameProcessResult>
   */
  processFrame(task: FrameProcessTask): Promise<FrameProcessResult>;

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
