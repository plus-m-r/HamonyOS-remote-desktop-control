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
  private dependencies: Map<string, object | (() => object)> = new Map();
  private singletonCache: Map<string, object> = new Map();
  private transientKeys: Set<string> = new Set();
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
  public register<T extends object>(key: string, factory: () => T, singleton: boolean = true, lifecycleAware: boolean = false): void {
    this.dependencies.set(key, factory as () => object);
    if (!singleton) {
      this.transientKeys.add(key);
    }
  }

  /**
   * 获取依赖项
   * @param key 依赖项的键
   * @returns T 依赖项实例
   */

  public get<T extends object>(key: string): T {
    if (!this.transientKeys.has(key)) {
      const cached = this.singletonCache.get(key);
      if (cached !== undefined) {
        return cached as T;
      }
    }
    const dependency = this.dependencies.get(key);
    if (typeof dependency === 'function') {
      const instance = (dependency as () => object)();
      if (!this.transientKeys.has(key)) {
        this.singletonCache.set(key, instance);
      }
      if (this.isLifecycleAware(instance)) {
        this.lifecycleManager.register(key, instance as ILifecycleAware);
      }
      return instance as T;
    }
    return dependency as T;
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
    this.singletonCache.delete(key);
    this.transientKeys.delete(key);
    this.lifecycleManager.unregister(key);
  }

  /**
   * 清空所有依赖项
   */
  public clear(): void {
    for (const key of this.dependencies.keys()) {
      this.lifecycleManager.unregister(key);
    }
    this.dependencies.clear();
    this.singletonCache.clear();
    this.transientKeys.clear();
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
  private isLifecycleAware(obj: object): boolean {
    const lifecycleObj = obj as ILifecycleAware;
    return obj !== null && typeof obj === 'object' &&
      typeof lifecycleObj.onCreate === 'function' &&
      typeof lifecycleObj.onStart === 'function' &&
      typeof lifecycleObj.onResume === 'function' &&
      typeof lifecycleObj.onPause === 'function' &&
      typeof lifecycleObj.onStop === 'function' &&
      typeof lifecycleObj.onDestroy === 'function';
  }
}

/**
 * 依赖项键接口
 */
export interface DependencyKeysInterface {
  CAPTURE_CACHE: string;
}

/**
 * 依赖项键常量
 */
export const DependencyKeys: DependencyKeysInterface = {
  CAPTURE_CACHE: 'CaptureCache',
};
