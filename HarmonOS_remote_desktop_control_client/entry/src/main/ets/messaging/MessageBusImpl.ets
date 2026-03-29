/**
 * 消息总线实现
 *
 * 基于 Worker 的消息总线实现
 */

import { IMessageBus, IMessage, MessageType, MessagePriority, MessageHandler, MessageFilter } from './IMessageBus';
import worker from '@ohos.worker';

interface Subscription {
  id: string;
  type: MessageType;
  handler: MessageHandler;
  filter?: MessageFilter;
}

export class MessageBusImpl implements IMessageBus {
  private threadId: string = '';
  private worker: worker.ThreadWorker | null = null;
  private isWorkerThread: boolean = false;
  private subscriptions: Map<string, Subscription> = new Map();
  private pendingMessages: IMessage[] = [];
  private errorHandler?: (error: Error, message: IMessage) => void;
  private isInitialized: boolean = false;
  private messageIdCounter: number = 0;

  /**
   * 初始化消息总线
   * @param threadId 当前线程ID
   */
  init(threadId: string): void {
    this.threadId = threadId;
    this.isInitialized = true;
    console.info(`MessageBusImpl: Initialized for thread ${threadId}`);
  }

  /**
   * 绑定 Worker（主线程调用）
   * @param worker Worker 实例
   */
  bindWorker(workerInstance: worker.ThreadWorker): void {
    this.worker = workerInstance;
    this.isWorkerThread = false;

    this.worker.onmessage = (event: MessageEvent) => {
      const message = event.data as IMessage;
      this.handleMessage(message);
    };

    this.worker.onerror = (error: ErrorEvent) => {
      console.error('MessageBusImpl: Worker error', error);
      if (this.errorHandler) {
        this.errorHandler(new Error(error.message), {} as IMessage);
      }
    };
  }

  /**
   * 绑定到 workerPort（Worker 线程调用）
   * @param workerPort Worker 端口
   */
  bindWorkerPort(workerPort: worker.ThreadWorker): void {
    this.worker = workerPort;
    this.isWorkerThread = true;

    this.worker.onmessage = (event: MessageEvent) => {
      const message = event.data as IMessage;
      this.handleMessage(message);
    };
  }

  send(message: IMessage): boolean {
    if (!this.isInitialized) {
      console.error('MessageBusImpl: Not initialized');
      return false;
    }

    // 添加源线程ID
    const enrichedMessage: IMessage = {
      ...message,
      sourceThreadId: this.threadId
    };

    if (this.worker) {
      this.worker.postMessage(enrichedMessage);
      return true;
    } else {
      // 如果没有绑定 Worker，加入待处理队列
      this.pendingMessages.push(enrichedMessage);
      return true;
    }
  }

  sendMessage(type: MessageType, payload?: any, priority: MessagePriority = MessagePriority.NORMAL): boolean {
    const message: IMessage = {
      type,
      id: this.generateMessageId(),
      timestamp: Date.now(),
      payload,
      priority
    };

    return this.send(message);
  }

  subscribe(type: MessageType, handler: MessageHandler, filter?: MessageFilter): string {
    const subscriptionId = this.generateSubscriptionId();
    const subscription: Subscription = {
      id: subscriptionId,
      type,
      handler,
      filter
    };

    this.subscriptions.set(subscriptionId, subscription);
    return subscriptionId;
  }

  unsubscribe(subscriptionId: string): void {
    this.subscriptions.delete(subscriptionId);
  }

  subscribeOnce(type: MessageType, handler: MessageHandler, timeout: number = 5000): Promise<void> {
    return new Promise((resolve, reject) => {
      const subscriptionId = this.subscribe(type, async (message) => {
        this.unsubscribe(subscriptionId);
        try {
          await handler(message);
          resolve();
        } catch (error) {
          reject(error);
        }
      });

      // 设置超时
      setTimeout(() => {
        this.unsubscribe(subscriptionId);
        reject(new Error(`SubscribeOnce timeout for message type ${type}`));
      }, timeout);
    });
  }

  broadcast(message: IMessage): void {
    // 广播给所有订阅者
    this.handleMessage(message);
  }

  request(request: IMessage, timeout: number = 5000): Promise<IMessage> {
    return new Promise((resolve, reject) => {
      const requestId = request.id;

      // 订阅响应
      const subscriptionId = this.subscribe(request.type, (response) => {
        if (response.payload?.requestId === requestId) {
          this.unsubscribe(subscriptionId);
          resolve(response);
        }
      });

      // 发送请求
      this.send(request);

      // 设置超时
      setTimeout(() => {
        this.unsubscribe(subscriptionId);
        reject(new Error(`Request timeout for message ${request.type}`));
      }, timeout);
    });
  }

  getPendingMessageCount(): number {
    return this.pendingMessages.length;
  }

  clearQueue(): void {
    this.pendingMessages = [];
  }

  setErrorHandler(handler: (error: Error, message: IMessage) => void): void {
    this.errorHandler = handler;
  }

  destroy(): void {
    this.subscriptions.clear();
    this.pendingMessages = [];
    this.errorHandler = undefined;

    if (this.worker) {
      // 不解绑 Worker，只清理引用
      this.worker = null;
    }

    this.isInitialized = false;
    console.info(`MessageBusImpl: Destroyed for thread ${this.threadId}`);
  }

  private handleMessage(message: IMessage): void {
    // 找到匹配的订阅者
    this.subscriptions.forEach((subscription) => {
      if (subscription.type === message.type) {
        // 检查过滤器
        if (subscription.filter && !subscription.filter(message)) {
          return;
        }

        // 异步处理消息
        Promise.resolve().then(async () => {
          try {
            await subscription.handler(message);
          } catch (error) {
            console.error('MessageBusImpl: Handler error', error);
            if (this.errorHandler) {
              this.errorHandler(error as Error, message);
            }
          }
        });
      }
    });
  }

  private generateMessageId(): string {
    return `msg_${this.threadId}_${Date.now()}_${++this.messageIdCounter}`;
  }

  private generateSubscriptionId(): string {
    return `sub_${this.threadId}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }
}
