
import { ILifecycleManager, LifecycleState, LifecycleEvent, ILifecycleAware, LifecycleCallback, LifecycleEventData } from './ILifecycleManager';

/**
 * 生命周期管理器实现
 * 
 * 负责管理应用和服务的生命周期，提供统一的生命周期事件触发和回调机制
 */
export class LifecycleManager implements ILifecycleManager {
  private static instance: LifecycleManager;
  
  private currentState: LifecycleState = LifecycleState.CREATED;
  private registeredObjects: Map<string, ILifecycleAware> = new Map();
  private callbacks: Map<string, LifecycleCallback> = new Map();
  private callbackIdCounter: number = 0;
  private isInitialized: boolean = false;
  
  private constructor() {}
  
  /**
   * 获取生命周期管理器单例
   */
  static getInstance(): LifecycleManager {
    if (!LifecycleManager.instance) {
      LifecycleManager.instance = new LifecycleManager();
    }
    return LifecycleManager.instance;
  }
  
  /**
   * 初始化生命周期管理器
   */
  init(): void {
    if (!this.isInitialized) {
      this.isInitialized = true;
      this.currentState = LifecycleState.CREATED;
    }
  }
  
  /**
   * 注册生命周期感知的对象
   * @param name 对象名称
   * @param target 目标对象
   */
  register(name: string, target: ILifecycleAware): void {
    this.registeredObjects.set(name, target);
  }
  
  /**
   * 注销生命周期感知的对象
   * @param name 对象名称
   */
  unregister(name: string): void {
    this.registeredObjects.delete(name);
  }
  
  /**
   * 触发创建事件
   * @param data 额外数据
   */
  async create(data?: LifecycleEventData): Promise<void> {
    const event: LifecycleEvent = {
      type: 'create',
      timestamp: Date.now(),
      data
    };
    
    await this.triggerEvent(event, (target) => target.onCreate());
    this.currentState = LifecycleState.CREATED;
  }
  
  /**
   * 触发启动事件
   * @param data 额外数据
   */
  async start(data?: LifecycleEventData): Promise<void> {
    const event: LifecycleEvent = {
      type: 'start',
      timestamp: Date.now(),
      data
    };
    
    await this.triggerEvent(event, (target) => target.onStart());
    this.currentState = LifecycleState.STARTED;
  }
  
  /**
   * 触发恢复事件
   * @param data 额外数据
   */
  async resume(data?: LifecycleEventData): Promise<void> {
    const event: LifecycleEvent = {
      type: 'resume',
      timestamp: Date.now(),
      data
    };
    
    await this.triggerEvent(event, (target) => target.onResume());
    this.currentState = LifecycleState.RESUMED;
  }
  
  /**
   * 触发暂停事件
   * @param data 额外数据
   */
  async pause(data?: LifecycleEventData): Promise<void> {
    const event: LifecycleEvent = {
      type: 'pause',
      timestamp: Date.now(),
      data
    };
    
    await this.triggerEvent(event, (target) => target.onPause());
    this.currentState = LifecycleState.PAUSED;
  }
  
  /**
   * 触发停止事件
   * @param data 额外数据
   */
  async stop(data?: LifecycleEventData): Promise<void> {
    const event: LifecycleEvent = {
      type: 'stop',
      timestamp: Date.now(),
      data
    };
    
    await this.triggerEvent(event, (target) => target.onStop());
    this.currentState = LifecycleState.STOPPED;
  }
  
  /**
   * 触发销毁事件
   * @param data 额外数据
   */
  async destroy(data?: LifecycleEventData): Promise<void> {
    const event: LifecycleEvent = {
      type: 'destroy',
      timestamp: Date.now(),
      data
    };
    
    await this.triggerEvent(event, (target) => target.onDestroy());
    this.currentState = LifecycleState.DESTROYED;
  }
  
  /**
   * 获取当前生命周期状态
   */
  getCurrentState(): LifecycleState {
    return this.currentState;
  }
  
  /**
   * 添加生命周期回调
   * @param callback 回调函数
   * @returns 回调ID
   */
  addCallback(callback: LifecycleCallback): string {
    const id = `callback_${++this.callbackIdCounter}`;
    this.callbacks.set(id, callback);
    return id;
  }
  
  /**
   * 移除生命周期回调
   * @param callbackId 回调ID
   */
  removeCallback(callbackId: string): void {
    this.callbacks.delete(callbackId);
  }
  
  /**
   * 获取已注册的对象列表
   */
  getRegisteredObjects(): string[] {
    return Array.from(this.registeredObjects.keys());
  }
  
  /**
   * 销毁生命周期管理器
   */
  dispose(): void {
    this.registeredObjects.clear();
    this.callbacks.clear();
    this.currentState = LifecycleState.DESTROYED;
    this.isInitialized = false;
  }
  
  /**
   * 触发事件
   * @param event 事件对象
   * @param action 执行的动作
   */
  private async triggerEvent(event: LifecycleEvent, action: (target: ILifecycleAware) => void | Promise<void>): Promise<void> {
    // 触发所有注册对象的生命周期方法
    const registeredEntries = Array.from(this.registeredObjects.entries());
    for (let i = 0; i < registeredEntries.length; i++) {
      const name = registeredEntries[i][0];
      const target = registeredEntries[i][1];
      try {
        const result = action(target);
        if (result instanceof Promise) {
          await result;
        }
      } catch (error) {
        console.error(`Error in lifecycle event for ${name}:`, error);
      }
    }
    
    // 触发所有回调
    const callbackEntries = Array.from(this.callbacks.entries());
    for (let i = 0; i < callbackEntries.length; i++) {
      const id = callbackEntries[i][0];
      const callback = callbackEntries[i][1];
      try {
        const result = callback(event);
        if (result instanceof Promise) {
          await result;
        }
      } catch (error) {
        console.error(`Error in lifecycle callback ${id}:`, error);
      }
    }
  }
}