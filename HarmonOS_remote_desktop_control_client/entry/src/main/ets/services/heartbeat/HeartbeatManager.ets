import { IHeartbeatManager, HeartbeatCallback, HeartbeatConfig } from '../interfaces/IHeartbeatManager';

/**
 * 心跳管理器实现
 */
export class HeartbeatManager implements IHeartbeatManager {
  private interval: number;
  private timeout: number;
  private timerId: number | undefined;
  private running: boolean = false;
  private heartbeatCallback: HeartbeatCallback | undefined;

  constructor(config: HeartbeatConfig) {
    this.interval = config.interval;
    this.timeout = config.timeout;
  }

  init(interval: number): void {
    this.interval = interval;
    console.info('HeartbeatManager: Initialized with interval', interval);
  }

  setHeartbeatCallback(callback: HeartbeatCallback): void {
    this.heartbeatCallback = callback;
  }

  start(): void {
    if (this.running) {
      console.warn('HeartbeatManager: Already running');
      return;
    }

    this.running = true;
    console.info('HeartbeatManager: Starting heartbeat with interval', this.interval);
    
    // 简单的心跳实现
    this.timerId = setInterval(() => {
      this.sendHeartbeat();
    }, this.interval) as number;
  }

  stop(): void {
    if (!this.running) {
      console.warn('HeartbeatManager: Not running');
      return;
    }

    this.running = false;
    if (this.timerId) {
      clearInterval(this.timerId);
      this.timerId = undefined;
    }
    console.info('HeartbeatManager: Stopped');
  }

  updateInterval(interval: number): void {
    this.interval = interval;
    console.info('HeartbeatManager: Updated interval to', interval);
    
    // 如果正在运行，重启定时器
    if (this.running && this.timerId) {
      clearInterval(this.timerId);
      this.timerId = setInterval(() => {
        this.sendHeartbeat();
      }, this.interval) as number;
    }
  }

  destroy(): void {
    this.stop();
    this.heartbeatCallback = undefined;
    console.info('HeartbeatManager: Destroyed');
  }

  isRunning(): boolean {
    return this.running;
  }

  private sendHeartbeat(): void {
    console.info('HeartbeatManager: Sending heartbeat');
    // 调用心跳回调
    if (this.heartbeatCallback) {
      this.heartbeatCallback();
    }
  }
}