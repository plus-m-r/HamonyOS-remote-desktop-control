/**
 * 生命周期管理器接口
 *
 * 抽象应用生命周期管理，便于：
 * 1. 单元测试时模拟生命周期
 * 2. 统一管理服务和资源的生命周期
 * 3. 支持不同的生命周期策略
 */

/**
 * 生命周期状态
 */
export enum LifecycleState {
  CREATED = 'CREATED',
  STARTED = 'STARTED',
  RESUMED = 'RESUMED',
  PAUSED = 'PAUSED',
  STOPPED = 'STOPPED',
  DESTROYED = 'DESTROYED'
}

/**
 * 生命周期事件
 */
export interface LifecycleEvent {
  /** 事件类型 */
  type: 'create' | 'start' | 'resume' | 'pause' | 'stop' | 'destroy';
  /** 时间戳 */
  timestamp: number;
  /** 额外数据 */
  data?: any;
}

/**
 * 生命周期回调
 */
export type LifecycleCallback = (event: LifecycleEvent) => void | Promise<void>;

/**
 * 可生命周期管理的对象
 */
export interface ILifecycleAware {
  /**
   * 创建时调用
   */
  onCreate(): void | Promise<void>;

  /**
   * 启动时调用
   */
  onStart(): void | Promise<void>;

  /**
   * 恢复时调用
   */
  onResume(): void | Promise<void>;

  /**
   * 暂停时调用
   */
  onPause(): void | Promise<void>;

  /**
   * 停止时调用
   */
  onStop(): void | Promise<void>;

  /**
   * 销毁时调用
   */
  onDestroy(): void | Promise<void>;
}

/**
 * 生命周期管理器接口
 */
export interface ILifecycleManager {
  /**
   * 初始化生命周期管理器
   */
  init(): void;

  /**
   * 注册生命周期感知的对象
   * @param name 对象名称
   * @param target 目标对象
   */
  register(name: string, target: ILifecycleAware): void;

  /**
   * 注销生命周期感知的对象
   * @param name 对象名称
   */
  unregister(name: string): void;

  /**
   * 触发创建事件
   * @param data 额外数据
   */
  create(data?: any): Promise<void>;

  /**
   * 触发启动事件
   * @param data 额外数据
   */
  start(data?: any): Promise<void>;

  /**
   * 触发恢复事件
   * @param data 额外数据
   */
  resume(data?: any): Promise<void>;

  /**
   * 触发暂停事件
   * @param data 额外数据
   */
  pause(data?: any): Promise<void>;

  /**
   * 触发停止事件
   * @param data 额外数据
   */
  stop(data?: any): Promise<void>;

  /**
   * 触发销毁事件
   * @param data 额外数据
   */
  destroy(data?: any): Promise<void>;

  /**
   * 获取当前生命周期状态
   */
  getCurrentState(): LifecycleState;

  /**
   * 添加生命周期回调
   * @param callback 回调函数
   * @returns 回调ID
   */
  addCallback(callback: LifecycleCallback): string;

  /**
   * 移除生命周期回调
   * @param callbackId 回调ID
   */
  removeCallback(callbackId: string): void;

  /**
   * 获取已注册的对象列表
   */
  getRegisteredObjects(): string[];

  /**
   * 销毁生命周期管理器
   */
  dispose(): void;
}
