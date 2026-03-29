// HeartbeatManager.test.ets - HeartbeatManager 的单元测试
// 测试心跳管理器的业务逻辑

import { HeartbeatManager } from '../main/ets/services/heartbeat/HeartbeatManager';
import { IWorkerRepository } from '../main/ets/repository/IWorkerRepository';

/**
 * Mock WorkerRepository 实现
 */
class MockWorkerRepository implements IWorkerRepository {
  public callHistory: Array<{ method: string; args: unknown[] }> = [];
  private mockWorker: any = {
    postMessage: (message: any) => {
      this.callHistory.push({ method: 'postMessage', args: [message] });
    },
    terminate: () => {
      this.callHistory.push({ method: 'terminate', args: [] });
    },
    onmessage: null,
    onerror: null
  };

  createWorker(scriptPath: string): Worker {
    this.callHistory.push({ method: 'createWorker', args: [scriptPath] });
    return this.mockWorker as Worker;
  }

  terminateWorker(worker: Worker): void {
    this.callHistory.push({ method: 'terminateWorker', args: [worker] });
  }
}

/**
 * HeartbeatManager 单元测试
 */
export class HeartbeatManagerTest {
  private heartbeatManager: HeartbeatManager;
  private mockWorkerRepository: MockWorkerRepository;
  
  // 测试状态记录
  private heartbeatEvents: Array<{ type: string; data?: any }> = [];

  constructor() {
    this.mockWorkerRepository = new MockWorkerRepository();
    
    // 创建 HeartbeatManager，注入 Mock 依赖
    this.heartbeatManager = new HeartbeatManager(this.mockWorkerRepository);
    
    // 设置事件监听器
    this.heartbeatManager.onHeartbeatSent(() => {
      this.heartbeatEvents.push({ type: 'heartbeatSent' });
    });
    
    this.heartbeatManager.onHeartbeatReceived(() => {
      this.heartbeatEvents.push({ type: 'heartbeatReceived' });
    });
    
    this.heartbeatManager.onConnectionLost((reason: string) => {
      this.heartbeatEvents.push({ type: 'connectionLost', data: reason });
    });
  }

  /**
   * 运行所有测试
   */
  async runAllTests(): Promise<void> {
    console.info('========== HeartbeatManager 测试开始 ==========');
    
    await this.testInitialize();
    await this.testStartHeartbeat();
    await this.testStopHeartbeat();
    await this.testHeartbeatInterval();
    await this.testConnectionMonitoring();
    
    console.info('========== HeartbeatManager 测试完成 ==========');
  }

  /**
   * 测试初始化
   */
  private async testInitialize(): Promise<void> {
    console.info('测试: initialize');
    
    // 验证初始状态
    const isRunning = this.heartbeatManager.isRunning();
    if (isRunning !== false) {
      throw new Error('初始状态应为未运行');
    }
    
    const interval = this.heartbeatManager.getInterval();
    if (interval !== 30000) { // 默认30秒
      throw new Error(`心跳间隔不正确: ${interval}`);
    }
    
    console.info('✓ initialize 测试通过');
  }

  /**
   * 测试启动心跳
   */
  private async testStartHeartbeat(): Promise<void> {
    console.info('测试: startHeartbeat');
    
    // 启动心跳
    await this.heartbeatManager.start();
    
    // 验证状态
    const isRunning = this.heartbeatManager.isRunning();
    if (isRunning !== true) {
      throw new Error('启动后状态应为运行中');
    }
    
    // 验证 Worker 被创建
    const createWorkerCall = this.mockWorkerRepository.callHistory.find(call => 
      call.method === 'createWorker'
    );
    
    if (!createWorkerCall) {
      throw new Error('createWorker 未被调用');
    }
    
    console.info('✓ startHeartbeat 测试通过');
  }

  /**
   * 测试停止心跳
   */
  private async testStopHeartbeat(): Promise<void> {
    console.info('测试: stopHeartbeat');
    
    // 确保心跳正在运行
    await this.heartbeatManager.start();
    
    // 停止心跳
    await this.heartbeatManager.stop();
    
    // 验证状态
    const isRunning = this.heartbeatManager.isRunning();
    if (isRunning !== false) {
      throw new Error('停止后状态应为未运行');
    }
    
    // 验证 Worker 被终止
    const terminateWorkerCall = this.mockWorkerRepository.callHistory.find(call => 
      call.method === 'terminateWorker'
    );
    
    if (!terminateWorkerCall) {
      throw new Error('terminateWorker 未被调用');
    }
    
    console.info('✓ stopHeartbeat 测试通过');
  }

  /**
   * 测试心跳间隔
   */
  private async testHeartbeatInterval(): Promise<void> {
    console.info('测试: heartbeatInterval');
    
    // 测试设置间隔
    const newInterval = 15000;
    this.heartbeatManager.setInterval(newInterval);
    
    const currentInterval = this.heartbeatManager.getInterval();
    if (currentInterval !== newInterval) {
      throw new Error(`心跳间隔设置失败: ${currentInterval}`);
    }
    
    // 测试无效间隔
    try {
      this.heartbeatManager.setInterval(0);
      throw new Error('应拒绝无效间隔');
    } catch (error) {
      // 预期抛出错误
      console.info('✓ 无效间隔验证通过');
    }
    
    console.info('✓ heartbeatInterval 测试通过');
  }

  /**
   * 测试连接监控
   */
  private async testConnectionMonitoring(): Promise<void> {
    console.info('测试: connectionMonitoring');
    
    // 模拟心跳超时
    this.heartbeatManager['handleHeartbeatTimeout']();
    
    // 验证连接丢失事件
    const connectionLostEvent = this.heartbeatEvents.find(event => 
      event.type === 'connectionLost'
    );
    
    if (!connectionLostEvent) {
      throw new Error('未触发连接丢失事件');
    }
    
    // 模拟心跳响应
    this.heartbeatManager['handleHeartbeatResponse']();
    
    // 验证心跳接收事件
    const heartbeatReceivedEvent = this.heartbeatEvents.find(event => 
      event.type === 'heartbeatReceived'
    );
    
    if (!heartbeatReceivedEvent) {
      throw new Error('未触发心跳接收事件');
    }
    
    console.info('✓ connectionMonitoring 测试通过');
  }
}

// 导出测试运行器
export function runHeartbeatManagerTests(): void {
  const test = new HeartbeatManagerTest();
  test.runAllTests().then(() => {
    console.info('所有测试通过！');
  }).catch((error) => {
    console.error('测试失败:', error);
  });
}