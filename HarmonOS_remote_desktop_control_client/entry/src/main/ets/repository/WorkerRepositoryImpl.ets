/**
 * Worker 仓库实现
 *
 * 实现 IWorkerRepository 接口，使用 Worker 进行后台处理
 *
 * 架构说明：
 * - 解压缩：在主线程完成（需要 Context）
 * - 帧处理（绘制瓦片）：在 Worker 线程完成
 */

import {
  IWorkerRepository,
  FrameProcessTask,
  FrameProcessResult,
  ProtocolParseTask,
  ProtocolParseResult
} from './IWorkerRepository';
import worker from '@ohos.worker';
import { CmdCodec } from '../network/CmdCodec';
import { ConcreteCmd } from '../models/ConcreteCmd';
import {
  ImageProcessTaskItem,
  ProtocolParseTaskItem,
  WorkerMessage,
  ImageTaskMessage,
  ProtocolTaskMessage,
  WorkerMessageData,
  WorkerErrorData
} from '../models/CommonTypes';

interface WorkerFrameDataResult {
  imageBuffer: ArrayBuffer;
  width: number;
  height: number;
  frameId: number;
  isKeyFrame: boolean;
  tileCount: number;
}

interface WorkerProtocolParseResult {
  remainingBuffer: ArrayBuffer;
  commands: Record<string, Object>[];
}

export class WorkerRepositoryImpl implements IWorkerRepository {
  private imageWorker: worker.ThreadWorker | null = null;
  private protocolWorker: worker.ThreadWorker | null = null;
  private pendingFrameTasks: Map<number, ImageProcessTaskItem> = new Map();
  private pendingProtocolTasks: Map<number, ProtocolParseTaskItem> = new Map();
  private taskIdCounter: number = 0;
  private isInitialized: boolean = false;

  init(): void {
    if (this.isInitialized) {
      return;
    }

    try {
      // 创建图像处理 Worker
      this.imageWorker = new worker.ThreadWorker('entry/ets/workers/CaptureWorker');
      this.imageWorker.onmessage = (message: WorkerMessageData) => {
        this.handleWorkerMessage(message.data);
      };
      this.imageWorker.onerror = (error: WorkerErrorData) => {
        console.error('WorkerRepositoryImpl: Image worker error', error.message);
      };

      // 创建协议解析 Worker
      this.protocolWorker = new worker.ThreadWorker('entry/ets/workers/ProtocolWorker');
      this.protocolWorker.onmessage = (message: WorkerMessageData) => {
        this.handleWorkerMessage(message.data);
      };
      this.protocolWorker.onerror = (error: WorkerErrorData) => {
        console.error('WorkerRepositoryImpl: Protocol worker error', error.message);
      };

      this.isInitialized = true;
      console.info('WorkerRepositoryImpl: Initialized');
    } catch (error) {
      console.error('WorkerRepositoryImpl: Failed to initialize', error);
      throw new Error(String(error));
    }
  }

  async processFrame(task: FrameProcessTask): Promise<FrameProcessResult> {
    if (!this.isInitialized) {
      throw new Error('Worker repository not initialized');
    }

    if (!this.imageWorker) {
      throw new Error('Image worker not available');
    }

    return new Promise((resolve, reject) => {
      const taskId = ++this.taskIdCounter;
      this.pendingFrameTasks.set(taskId, { resolve, reject });

      const message: ImageTaskMessage = {
        type: 'processFrame',
        taskId,
        task
      };

      this.imageWorker!.postMessage(message);
    });
  }

  async parseProtocol(task: ProtocolParseTask): Promise<ProtocolParseResult> {
    if (!this.isInitialized) {
      throw new Error('Worker repository not initialized');
    }

    if (!this.protocolWorker) {
      throw new Error('Protocol worker not available');
    }

    return new Promise((resolve, reject) => {
      const taskId = ++this.taskIdCounter;
      this.pendingProtocolTasks.set(taskId, { resolve, reject });

      const message: ProtocolTaskMessage = {
        type: 'parseProtocol',
        taskId,
        task
      };

      this.protocolWorker!.postMessage(message);
    });
  }

  getPendingTaskCount(): number {
    return this.pendingFrameTasks.size + this.pendingProtocolTasks.size;
  }

  getProcessingTaskCount(): number {
    // 简化实现，实际应该跟踪正在处理的任务
    return this.pendingFrameTasks.size + this.pendingProtocolTasks.size;
  }

  destroy(): void {
    // 拒绝所有待处理的任务
    this.pendingFrameTasks.forEach((task) => {
      task.reject(new Error('Worker repository destroyed'));
    });
    this.pendingProtocolTasks.forEach((task) => {
      task.reject(new Error('Worker repository destroyed'));
    });
    this.pendingFrameTasks.clear();
    this.pendingProtocolTasks.clear();

    // 终止 Worker
    if (this.imageWorker) {
      this.imageWorker.terminate();
      this.imageWorker = null;
    }

    if (this.protocolWorker) {
      this.protocolWorker.terminate();
      this.protocolWorker = null;
    }

    this.isInitialized = false;
    console.info('WorkerRepositoryImpl: Destroyed');
  }

  private convertToFrameProcessResult(data: WorkerFrameDataResult): FrameProcessResult {
    return {
      imageBuffer: data.imageBuffer,
      width: data.width,
      height: data.height,
      frameId: data.frameId,
      isKeyFrame: data.isKeyFrame,
      tileCount: data.tileCount
    };
  }

  private convertToProtocolParseResult(data: WorkerProtocolParseResult): ProtocolParseResult {
    return {
      remainingBuffer: data.remainingBuffer,
      commands: data.commands
    };
  }

  private handleWorkerMessage(message: WorkerMessage): void {
    const taskId = message.taskId;
    const type = message.type;
    const data = message.data;
    const error = message.error;

    if (type === 'frameResult' || type === 'error') {
      const frameTask = this.pendingFrameTasks.get(taskId);
      if (frameTask) {
        this.pendingFrameTasks.delete(taskId);
        if (type === 'error') {
          frameTask.reject(new Error(error || 'Worker processing error'));
        } else if (data) {
          const workerData = data as WorkerFrameDataResult;
          frameTask.resolve(this.convertToFrameProcessResult(workerData));
        } else {
          frameTask.reject(new Error('Invalid worker response'));
        }
      } else {
        console.warn('WorkerRepositoryImpl: Unknown frame task ID', taskId);
      }
    }

    if (type === 'protocolResult' || type === 'error') {
      const protocolTask = this.pendingProtocolTasks.get(taskId);
      if (protocolTask) {
        this.pendingProtocolTasks.delete(taskId);
        if (type === 'error') {
          protocolTask.reject(new Error(error || 'Worker processing error'));
        } else if (data) {
          const workerData = data as WorkerProtocolParseResult;
          protocolTask.resolve(this.convertToProtocolParseResult(workerData));
        } else {
          protocolTask.reject(new Error('Invalid worker response'));
        }
      } else if (type === 'protocolResult') {
        console.warn('WorkerRepositoryImpl: Unknown protocol task ID', taskId);
      }
    }
  }
}
