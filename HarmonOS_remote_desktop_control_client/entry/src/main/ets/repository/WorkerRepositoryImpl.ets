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
  ProtocolParseTask,
  ProtocolParseResult
} from './IWorkerRepository';
import worker from '@ohos.worker';
import {
  ProtocolParseTaskItem,
  WorkerMessage,
  ProtocolTaskMessage,
  WorkerMessageData,
  WorkerErrorData
} from '../models/CommonTypes';

interface WorkerProtocolParseResult {
  remainingBuffer: ArrayBuffer;
  commands: Record<string, Object>[];
}

export class WorkerRepositoryImpl implements IWorkerRepository {
  private protocolWorker: worker.ThreadWorker | null = null;
  private pendingProtocolTasks: Map<number, ProtocolParseTaskItem> = new Map();
  private taskIdCounter: number = 0;
  private isInitialized: boolean = false;

  init(): void {
    if (this.isInitialized) {
      return;
    }

    try {
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
    throw new Error('Frame processing not supported - all processing done on main thread');
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
    return this.pendingProtocolTasks.size;
  }

  getProcessingTaskCount(): number {
    // 简化实现，实际应该跟踪正在处理的任务
    return this.pendingProtocolTasks.size;
  }

  destroy(): void {
    // 拒绝所有待处理的任务
    this.pendingProtocolTasks.forEach((task) => {
      task.reject(new Error('Worker repository destroyed'));
    });
    this.pendingProtocolTasks.clear();

    // 终止 Worker
    if (this.protocolWorker) {
      this.protocolWorker.terminate();
      this.protocolWorker = null;
    }

    this.isInitialized = false;
    console.info('WorkerRepositoryImpl: Destroyed');
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
