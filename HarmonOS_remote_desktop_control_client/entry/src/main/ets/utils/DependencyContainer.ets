/**
 * 依赖注入容器
 * 
 * 用于管理系统中的依赖项，确保单例对象的唯一实例
 * 集成生命周期管理，支持服务的生命周期控制
 */
import { LifecycleManager } from '../lifecycle/LifecycleManager';
import { ILifecycleAware } from '../lifecycle/ILifecycleManager';

export class DependencyContainer {
  private static instance: DependencyContainer;
  private dependencies: Map<string, any> = new Map();
  private lifecycleManager: LifecycleManager;

  /**
   * 获取依赖注入容器实例
   * @returns DependencyContainer 单例实例
   */
  public static getInstance(): DependencyContainer {
    if (!DependencyContainer.instance) {
      DependencyContainer.instance = new DependencyContainer();
    }
    return DependencyContainer.instance;
  }

  /**
   * 私有构造函数
   */
  private constructor() {
    this.lifecycleManager = LifecycleManager.getInstance();
    this.lifecycleManager.init();
  }

  /**
   * 注册依赖项
   * @param key 依赖项的键
   * @param factory 依赖项的工厂函数
   * @param singleton 是否为单例，默认为true
   * @param lifecycleAware 是否为生命周期感知对象，默认为false
   */
  public register<T>(key: string, factory: () => T, singleton: boolean = true, lifecycleAware: boolean = false): void {
    if (singleton) {
      const instance = factory();
      this.dependencies.set(key, instance);
      
      // 如果是生命周期感知对象，注册到生命周期管理器
      if (lifecycleAware && this.isLifecycleAware(instance)) {
        this.lifecycleManager.register(key, instance as ILifecycleAware);
      }
    } else {
      this.dependencies.set(key, factory);
    }
  }

  /**
   * 获取依赖项
   * @param key 依赖项的键
   * @returns T 依赖项实例
   */
  public get<T>(key: string): T {
    const dependency = this.dependencies.get(key);
    if (typeof dependency === 'function') {
      const instance = dependency();
      // 如果是生命周期感知对象，注册到生命周期管理器
      if (this.isLifecycleAware(instance)) {
        this.lifecycleManager.register(key, instance as ILifecycleAware);
      }
      return instance;
    }
    return dependency;
  }

  /**
   * 检查依赖项是否存在
   * @param key 依赖项的键
   * @returns boolean 是否存在
   */
  public has(key: string): boolean {
    return this.dependencies.has(key);
  }

  /**
   * 移除依赖项
   * @param key 依赖项的键
   */
  public remove(key: string): void {
    this.dependencies.delete(key);
    this.lifecycleManager.unregister(key);
  }

  /**
   * 清空所有依赖项
   */
  public clear(): void {
    // 先注销所有生命周期感知对象
    for (const key of this.dependencies.keys()) {
      this.lifecycleManager.unregister(key);
    }
    this.dependencies.clear();
  }

  /**
   * 获取生命周期管理器
   * @returns LifecycleManager 生命周期管理器实例
   */
  public getLifecycleManager(): LifecycleManager {
    return this.lifecycleManager;
  }

  /**
   * 检查对象是否为生命周期感知对象
   * @param obj 要检查的对象
   * @returns boolean 是否为生命周期感知对象
   */
  private isLifecycleAware(obj: any): boolean {
    return obj && 
      typeof obj.onCreate === 'function' &&
      typeof obj.onStart === 'function' &&
      typeof obj.onResume === 'function' &&
      typeof obj.onPause === 'function' &&
      typeof obj.onStop === 'function' &&
      typeof obj.onDestroy === 'function';
  }
}

/**
 * 依赖项键常量
 */
export const DependencyKeys = {
  CAPTURE_CACHE: 'CaptureCache',
};
