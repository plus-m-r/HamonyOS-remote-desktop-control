import worker from '@ohos.worker';

// 定义消息类型
interface FileTaskMessage {
  type: 'calculateMD5';
  filePath: string;
}

interface ResultMessage {
  type: 'result';
  success: boolean;
  data?: string;
  error?: string;
}

// 定义Worker消息接口
interface WorkerMessage {
  data: ResultMessage;
}

/**
 * FileWorker管理器，用于管理文件相关的后台任务
 */
export class FileWorkerManager {
  private worker: worker.ThreadWorker | null = null;

  /**
   * 初始化Worker
   */
  init(): void {
    try {
      this.worker = new worker.ThreadWorker('ets/utils/FileWorker.ets');
      this.worker.onmessage = (message: Object) => {
        this.handleWorkerMessage(message);
      };
      this.worker.onerror = (error: Object) => {
        console.error('FileWorkerManager: Worker error', error);
      };
    } catch (error) {
      console.error('FileWorkerManager: Failed to create worker', error);
    }
  }

  /**
   * 处理Worker消息
   * @param message 消息事件
   */
  private handleWorkerMessage(message: Object): void {
    const data = (message as WorkerMessage).data;

    if (data.type === 'result') {
      // 结果通过Promise返回，这里不需要额外处理
      console.log('FileWorkerManager: Received result', data.success);
    }
  }

  /**
   * 计算文件MD5
   * @param filePath 文件路径
   * @returns Promise<string> MD5值
   */
  async calculateMD5(filePath: string): Promise<string> {
    return new Promise((resolve, reject) => {
      if (!this.worker) {
        reject(new Error('Worker not initialized'));
        return;
      }

      const message: FileTaskMessage = {
        type: 'calculateMD5',
        filePath: filePath
      };

      // 设置一次性消息处理器
      const messageHandler = (msg: Object) => {
        const data = (msg as WorkerMessage).data;
        if (data.type === 'result') {
          this.worker?.off('message', messageHandler);
          if (data.success && data.data) {
            resolve(data.data);
          } else {
            reject(new Error(data.error || 'Worker processing failed'));
          }
        }
      };

      this.worker.onmessage = messageHandler;
      this.worker.postMessage(message);
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
  }
}
