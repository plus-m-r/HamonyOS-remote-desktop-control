import worker from '@ohos.worker';
import { ConcreteCmd } from '../models/ConcreteCmd';

// 定义消息类型
interface ProtocolTaskMessage {
  type: 'processMessage';
  existingBuffer: ArrayBuffer;
  newData: ArrayBuffer;
}
interface ResultData {
  remainingBuffer: ArrayBuffer;
  commands: ConcreteCmd[];
}

interface ResultMessage {
  type: 'result';
  success: boolean;
  data?: ResultData;
  error?: string;
}

// 定义Worker消息接口
interface WorkerMessage {
  data: ResultMessage;
}

/**
 * ProtocolWorker管理器，用于管理协议解析相关的后台任务
 */
export class ProtocolWorkerManager {
  private worker: worker.ThreadWorker | null = null;

  /**
   * 初始化Worker
   */
  init(): void {
    try {
      this.worker = new worker.ThreadWorker('ets/utils/ProtocolWorker.ets');
      this.worker.onmessage = (message: Object) => {
        this.handleWorkerMessage(message);
      };
      this.worker.onerror = (error: Object) => {
        console.error('ProtocolWorkerManager: Worker error', error);
      };
    } catch (error) {
      console.error('ProtocolWorkerManager: Failed to create worker', error);
    }
  }

  /**
   * 处理Worker消息
   * @param message 消息事件
   */
  private handleWorkerMessage(message: Object): void {
    const data = (message as WorkerMessage).data;

    if (data.type === 'result') {
      console.log('ProtocolWorkerManager: Received result', data.success);
    }
  }

  /**
   * 处理消息：在后台线程合并缓冲区并提取命令
   * @param existingBuffer 现有缓冲区
   * @param newData 新接收的数据
   * @returns Promise<{remainingBuffer: ArrayBuffer, commands: ConcreteCmd[]}>
   */
  async processMessage(existingBuffer: ArrayBuffer, newData: ArrayBuffer): Promise<ResultData> {
    return new Promise((resolve, reject) => {
      if (!this.worker) {
        reject(new Error('Worker not initialized'));
        return;
      }

      const message: ProtocolTaskMessage = {
        type: 'processMessage',
        existingBuffer: existingBuffer,
        newData: newData
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
