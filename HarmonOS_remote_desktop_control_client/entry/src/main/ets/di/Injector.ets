// entry/src/main/ets/di/Injector.ets
// 依赖注入容器 - 完全解耦版本

import { hilog } from '@kit.PerformanceAnalysisKit';
import { IRemoteControlService } from '../services/interfaces/IRemoteControlService';
import { IFileService } from '../services/interfaces/IFileService';
import { IClipboardService } from '../services/interfaces/IClipboardService';
import { IConnectionManager } from '../services/connection/IConnectionManager';
import { IProtocolHandler } from '../services/protocol/IProtocolHandler';
import { IWorkerRepository } from '../repository/IWorkerRepository';
import { BaseService } from './BaseService';

const DOMAIN = 0x0001;
const TAG = 'Injector';

/**
 * 依赖注入容器
 * 实现服务的注册、解析和管理
 * 支持接口类型注册
 */
export class Injector {
  private static instance: Injector | null = null;
  private services: Map<string, BaseService> = new Map();
  private factories: Map<string, () => BaseService> = new Map();
  private isInitialized: boolean = false;

  private constructor() {}
  
  private static readonly DOMAIN = 0x0001;
  private static readonly TAG = 'Injector';

  /**
   * 获取依赖注入容器单例
   */
  static getInstance(): Injector {
    if (!Injector.instance) {
      Injector.instance = new Injector();
    }
    return Injector.instance;
  }

  /**
   * 注册服务
   * @param key 服务键
   * @param service 服务实例
   */
  register<T extends BaseService>(key: string, service: T): void {
    this.services.set(key, service);
  }

  /**
   * 注册服务工厂
   * @param key 服务键
   * @param factory 服务工厂函数
   */
  registerFactory<T extends BaseService>(key: string, factory: () => T): void {
    this.factories.set(key, factory);
  }

  /**
   * 解析服务
   * @param key 服务键
   * @returns 服务实例
   */
  resolve<T>(key: string): T {
    // 先从已注册的服务中查找
    if (this.services.has(key)) {
      const service = this.services.get(key);
      if (service !== undefined) {
        return service as T;
      }
    }

    // 如果有工厂函数，创建服务实例
    if (this.factories.has(key)) {
      const factory = this.factories.get(key);
      if (factory) {
        const service = factory();
        this.services.set(key, service);
        return service as T;
      }
    }

    throw new Error(`Service not found: ${key}`);
  }

  /**
   * 检查服务是否已注册
   * @param key 服务键
   * @returns 是否已注册
   */
  has(key: string): boolean {
    return this.services.has(key) || this.factories.has(key);
  }

  /**
   * 移除服务
   * @param key 服务键
   */
  remove(key: string): void {
    this.services.delete(key);
    this.factories.delete(key);
  }

  /**
   * 清理所有服务
   */
  clear(): void {
    // 调用所有服务的 cleanup 方法
    this.services.forEach(service => {
      if (service.cleanup) {
        service.cleanup();
      }
    });
    
    this.services.clear();
    this.factories.clear();
    this.isInitialized = false;
  }

  /**
   * 初始化容器
   */
  async initialize(): Promise<void> {
    if (this.isInitialized) {
      hilog.warn(DOMAIN, TAG, 'Already initialized');
      return;
    }

    // 初始化所有服务工厂
    await this.initializeFactories();

    this.isInitialized = true;
    hilog.info(DOMAIN, TAG, 'Initialized');
  }

  /**
   * 初始化服务工厂
   */
  private async initializeFactories(): Promise<void> {
    try {
      // 动态导入服务工厂
      const connectionManagerModule = await import('./factories/ConnectionManagerFactory');
      const protocolHandlerModule = await import('./factories/ProtocolHandlerFactory');
      const workerRepositoryModule = await import('./factories/WorkerRepositoryFactory');
      const remoteControlModule = await import('./factories/RemoteControlServiceFactory');
      const clipboardModule = await import('./factories/ClipboardServiceFactory');
      const fileModule = await import('./factories/FileServiceFactory');

      const ConnectionManagerFactory = connectionManagerModule.ConnectionManagerFactory;
      const ProtocolHandlerFactory = protocolHandlerModule.ProtocolHandlerFactory;
      const WorkerRepositoryFactory = workerRepositoryModule.WorkerRepositoryFactory;
      const RemoteControlServiceFactory = remoteControlModule.RemoteControlServiceFactory;
      const ClipboardServiceFactory = clipboardModule.ClipboardServiceFactory;
      const FileServiceFactory = fileModule.FileServiceFactory;

      // 注册服务工厂 - 返回接口类型
      // 注意：注册顺序很重要，因为其他服务依赖于 WorkerRepository
      this.registerFactory<IWorkerRepository>(ServiceKeys.WORKER_REPOSITORY,
        () => WorkerRepositoryFactory.create()
      );

      this.registerFactory<IConnectionManager>(ServiceKeys.CONNECTION_MANAGER,
        () => ConnectionManagerFactory.create()
      );

      this.registerFactory<IProtocolHandler>(ServiceKeys.PROTOCOL_HANDLER,
        () => ProtocolHandlerFactory.create()
      );

      this.registerFactory<IRemoteControlService>(ServiceKeys.REMOTE_CONTROL_SERVICE,
        () => RemoteControlServiceFactory.create()
      );

      this.registerFactory<IClipboardService>(ServiceKeys.CLIPBOARD_SERVICE,
        () => ClipboardServiceFactory.create()
      );

      this.registerFactory<IFileService>(ServiceKeys.FILE_SERVICE,
        () => FileServiceFactory.create()
      );

      hilog.info(DOMAIN, TAG, 'All service factories registered');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to initialize factories: %{public}s', error instanceof Error ? error.message : String(error));
      throw new Error(String(error));
    }
  }
}

/**
 * 服务键常量接口
 */
interface ServiceKeysType {
  REMOTE_CONTROL_SERVICE: string;
  CLIPBOARD_SERVICE: string;
  FILE_SERVICE: string;
  CONNECTION_MANAGER: string;
  PROTOCOL_HANDLER: string;
  WORKER_REPOSITORY: string;
}

/**
 * 服务键常量
 */
export const ServiceKeys: ServiceKeysType = {
  REMOTE_CONTROL_SERVICE: 'remoteControlService',
  CLIPBOARD_SERVICE: 'clipboardService',
  FILE_SERVICE: 'fileService',
  CONNECTION_MANAGER: 'connectionManager',
  PROTOCOL_HANDLER: 'protocolHandler',
  WORKER_REPOSITORY: 'workerRepository'
};
