import worker, { MessageEvent } from '@ohos.worker';

// 定义消息类型
interface HeartbeatTickMessage {
  type: 'tick';
  timestamp: number;
}

type WorkerMessage = HeartbeatTickMessage;

interface WorkerMessageData {
  data: WorkerMessage;
}

/**
 * 心跳 Worker 管理器
 * 
 * 职责：
 * 1. 管理心跳 Worker 的生命周期（创建、复用、销毁）
 * 2. 在独立线程中运行心跳定时器，避免主线程阻塞影响心跳
 * 3. 提供开始/停止心跳的接口
 * 
 * 设计特点：
 * - Worker 只创建一次，复用整个应用生命周期
 * - 心跳在 Worker 线程执行，通过消息回调通知主线程发送
 */
export class HeartbeatWorkerManager {
  private static instance: HeartbeatWorkerManager | null = null;
  private worker: worker.ThreadWorker | null = null;
  private heartbeatCallback: (() => void) | null = null;
  private isInitialized: boolean = false;
  private isRunning: boolean = false;

  /**
   * 获取单例实例
   */
  static getInstance(): HeartbeatWorkerManager {
    if (!HeartbeatWorkerManager.instance) {
      HeartbeatWorkerManager.instance = new HeartbeatWorkerManager();
    }
    return HeartbeatWorkerManager.instance;
  }

  private constructor() {}

  /**
   * 初始化心跳 Worker
   * 
   * 只创建一次 Worker，后续复用
   * @param interval 心跳间隔（毫秒），默认3000ms
   */
  init(interval: number = 3000): void {
    if (this.isInitialized) {
      console.log('HeartbeatWorkerManager: Already initialized');
      return;
    }

    try {
      // 创建 Worker（只创建一次）
      this.worker = new worker.ThreadWorker('entry/ets/workers/HeartbeatWorker');
      
      // 设置消息接收回调
      this.worker.onmessage = (message: MessageEvent<WorkerMessageData>) => {
        this.handleWorkerMessage(message);
      };

      // 设置错误处理
      this.worker.onerror = (error: Object) => {
        console.error('HeartbeatWorkerManager: Worker error', error);
      };

      // 配置心跳间隔
      this.worker.postMessage({
        type: 'config',
        interval: interval
      });

      this.isInitialized = true;
      console.log(`HeartbeatWorkerManager: Initialized with interval ${interval}ms`);
    } catch (error) {
      console.error('HeartbeatWorkerManager: Failed to initialize worker', error);
    }
  }

  /**
   * 处理 Worker 消息
   */
  private handleWorkerMessage(message: MessageEvent<WorkerMessageData>): void {
    const data = message.data.data;

    if (data.type === 'tick') {
      // Worker 发送的心跳 tick，通知主线程发送实际的心跳包
      if (this.heartbeatCallback) {
        this.heartbeatCallback();
      }
    }
  }

  /**
   * 设置心跳回调
   * @param callback 每次心跳时调用的回调函数
   */
  setHeartbeatCallback(callback: () => void): void {
    this.heartbeatCallback = callback;
  }

  /**
   * 开始心跳
   * 
   * 向 Worker 发送开始命令，Worker 开始在独立线程定时发送 tick
   */
  start(): void {
    if (!this.isInitialized) {
      console.error('HeartbeatWorkerManager: Not initialized, call init() first');
      return;
    }

    if (this.isRunning) {
      console.log('HeartbeatWorkerManager: Already running');
      return;
    }

    if (this.worker) {
      this.worker.postMessage({ type: 'start' });
      this.isRunning = true;
      console.log('HeartbeatWorkerManager: Heartbeat started');
    }
  }

  /**
   * 停止心跳
   * 
   * 向 Worker 发送停止命令，Worker 停止定时器但保持存活
   */
  stop(): void {
    if (!this.isInitialized || !this.isRunning) {
      return;
    }

    if (this.worker) {
      this.worker.postMessage({ type: 'stop' });
      this.isRunning = false;
      console.log('HeartbeatWorkerManager: Heartbeat stopped');
    }
  }

  /**
   * 更新心跳间隔
   * @param interval 新的心跳间隔（毫秒）
   */
  updateInterval(interval: number): void {
    if (!this.isInitialized) {
      console.error('HeartbeatWorkerManager: Not initialized');
      return;
    }

    if (this.worker) {
      this.worker.postMessage({
        type: 'config',
        interval: interval
      });
      console.log(`HeartbeatWorkerManager: Updated interval to ${interval}ms`);
    }
  }

  /**
   * 销毁心跳 Worker
   * 
   * 应用退出时调用，释放 Worker 资源
   */
  destroy(): void {
    this.stop();
    
    if (this.worker) {
      this.worker.terminate();
      this.worker = null;
    }
    
    this.heartbeatCallback = null;
    this.isInitialized = false;
    this.isRunning = false;
    
    console.log('HeartbeatWorkerManager: Destroyed');
  }

  /**
   * 检查是否正在运行
   */
  isHeartbeatRunning(): boolean {
    return this.isRunning;
  }
}
