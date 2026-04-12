/**
 * 依赖注入容器
 * 
 * 用于管理系统中的依赖项，确保单例对象的唯一实例
 */
export class DependencyContainer {
  private static instance: DependencyContainer;
  private dependencies: Map<string, any> = new Map();

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
   * 注册依赖项
   * @param key 依赖项的键
   * @param factory 依赖项的工厂函数
   * @param singleton 是否为单例，默认为true
   */
  public register<T>(key: string, factory: () => T, singleton: boolean = true): void {
    if (singleton) {
      const instance = factory();
      this.dependencies.set(key, instance);
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
      return dependency();
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
  }

  /**
   * 清空所有依赖项
   */
  public clear(): void {
    this.dependencies.clear();
  }
}

/**
 * 依赖项键常量
 */
export const DependencyKeys = {
  CAPTURE_CACHE: 'CaptureCache',
};
