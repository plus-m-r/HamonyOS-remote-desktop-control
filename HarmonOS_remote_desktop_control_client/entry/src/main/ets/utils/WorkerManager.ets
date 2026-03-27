
import worker from '@ohos.worker';
// 定义Worker捕获任务接口
interface WorkerCaptureTask {
  imageData: ArrayBuffer | string;
  compressionMethodOrdinal: number;
}

// 定义数据接口
interface ImageData {
  imageBuffer: ArrayBuffer;
  width: number;
  height: number;
}
// 定义消息类型
interface CaptureTaskMessage {
  type: 'capture';
  task: WorkerCaptureTask;
}

interface ResultMessage {
  type: 'result';
  success: boolean;
  data?: ImageData;
  error?: string;
}

// 定义Worker消息接口
interface WorkerMessage {
  data: ResultMessage;
}

/**
 * Worker管理器，用于管理Worker的创建、通信和销毁
 */
// 定义任务队列项接口
interface TaskQueueItem {
  task: WorkerCaptureTask;
  resolve: (result: ImageData) => void;
  reject: (error: Error) => void;
}

export class WorkerManager {
  private worker: worker.ThreadWorker | null = null;
  private taskQueue: Array<TaskQueueItem> = [];
  private isProcessing: boolean = false;

  /**
   * 初始化Worker
   */
  init(): void {
    try {
      this.worker = new worker.ThreadWorker('ets/utils/CaptureWorker.ets');
      this.worker.onmessage = (message: Object) => {
        this.handleWorkerMessage(message);
      };
      this.worker.onerror = (error: Object) => {
        console.error('WorkerManager: Worker error', error);
        this.processNextTask();
      };
    } catch (error) {
      console.error('WorkerManager: Failed to create worker', error);
    }
  }
  /**
   * 处理Worker消息
   * @param message 消息事件
   */
  private handleWorkerMessage(message: Object): void {
    const data = (message as WorkerMessage).data;
    
    if (data.type === 'result') {
      const task = this.taskQueue.shift();
      if (task) {
        if (data.success && data.data) {
          task.resolve(data.data);
        } else {
          task.reject(new Error(data.error || 'Worker processing failed'));
        }
      }
      this.processNextTask();
    }
  }

  /**
   * 处理下一个任务
   */
  private processNextTask(): void {
    if (this.taskQueue.length === 0) {
      this.isProcessing = false;
      return;
    }

    if (!this.worker) {
      this.isProcessing = false;
      const task = this.taskQueue.shift();
      if (task) {
        task.reject(new Error('Worker not initialized'));
      }
      return;
    }

    this.isProcessing = true;
    const task = this.taskQueue[0];
    const message: CaptureTaskMessage = {
      type: 'capture',
      task: task.task
    };
    this.worker.postMessage(message);
  }
  /**
   * 提交捕获任务
   * @param task 捕获任务
   * @returns Promise<ImageData>
   */
  async submitCaptureTask(task: WorkerCaptureTask): Promise<ImageData> {
    return new Promise((resolve, reject) => {
      const queueItem: TaskQueueItem = { task, resolve, reject };
      this.taskQueue.push(queueItem);
      if (!this.isProcessing) {
        this.processNextTask();
      }
    });
  }

  /**
   * 销毁Worker
   */
  destroy(): void {
    if (this.worker) {
      this.worker.terminate();
      this.worker = null;
    }
    this.taskQueue = [];
    this.isProcessing = false;
  }
}
