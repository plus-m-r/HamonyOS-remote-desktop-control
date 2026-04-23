// entry/src/main/ets/di/ServiceProvider.ets
// 服务提供者 - 完全解耦版本
// 使用接口而非具体实现，便于测试和替换

import { Injector, ServiceKeys } from './Injector';
import { IRemoteControlService } from '../services/interfaces/IRemoteControlService';
import { IFileService } from '../services/interfaces/IFileService';
import { IClipboardService } from '../services/interfaces/IClipboardService';
import { IAppStateManager } from '../state/IAppStateManager';
import { AppStateManager, MemoryStorageImpl } from '../state/AppStateManager';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001;
const TAG = 'ServiceProvider';

/**
 * 服务提供者
 * 提供便捷的服务访问方法，使用依赖注入框架
 * 返回接口类型而非具体实现，实现完全解耦
 */
export class ServiceProvider {
  private static _appStateManager: IAppStateManager;
  private static _injectorInitialized: boolean = false;

  /**
   * 初始化服务提供者
   */
  static async initialize(): Promise<void> {
    if (ServiceProvider._injectorInitialized) {
      hilog.info(DOMAIN, TAG, 'Already initialized');
      return;
    }

    const injector = Injector.getInstance();
    await injector.initialize();
    
    // 初始化应用状态管理器
    ServiceProvider._appStateManager = new AppStateManager(new MemoryStorageImpl());
    
    ServiceProvider._injectorInitialized = true;
    hilog.info(DOMAIN, TAG, 'Initialized');
  }

  /**
   * 获取远程控制服务（接口类型）
   */
  static get remoteControlService(): IRemoteControlService {
    if (!ServiceProvider._injectorInitialized) {
      throw new Error('ServiceProvider not initialized. Call initialize() first.');
    }
    return Injector.getInstance().resolve<IRemoteControlService>(ServiceKeys.REMOTE_CONTROL_SERVICE);
  }

  /**
   * 获取剪贴板服务（接口类型）
   */
  static get clipboardService(): IClipboardService {
    if (!ServiceProvider._injectorInitialized) {
      throw new Error('ServiceProvider not initialized. Call initialize() first.');
    }
    return Injector.getInstance().resolve<IClipboardService>(ServiceKeys.CLIPBOARD_SERVICE);
  }

  /**
   * 获取文件服务（接口类型）
   */
  static get fileService(): IFileService {
    if (!ServiceProvider._injectorInitialized) {
      throw new Error('ServiceProvider not initialized. Call initialize() first.');
    }
    return Injector.getInstance().resolve<IFileService>(ServiceKeys.FILE_SERVICE);
  }

  /**
   * 获取应用状态管理器（接口类型）
   */
  static get appStateManager(): IAppStateManager {
    if (!ServiceProvider._appStateManager) {
      ServiceProvider._appStateManager = new AppStateManager(new MemoryStorageImpl());
    }
    return ServiceProvider._appStateManager;
  }

  /**
   * 设置应用状态管理器（用于测试时注入 Mock）
   */
  static setAppStateManager(appStateManager: IAppStateManager): void {
    ServiceProvider._appStateManager = appStateManager;
  }

  /**
   * 清理所有服务
   */
  static async cleanup(): Promise<void> {
    try {
      // 清理远程控制服务
      await ServiceProvider.remoteControlService.disconnect();
      
      // 清理文件服务
      ServiceProvider.fileService.cleanup();
      
      // 清理剪贴板服务
      ServiceProvider.clipboardService.cleanup();
      
      // 清理依赖注入容器
      Injector.getInstance().clear();
      
      ServiceProvider._injectorInitialized = false;
      
      hilog.info(DOMAIN, TAG, 'Cleanup completed');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Cleanup failed: %{public}s', error instanceof Error ? error.message : String(error));
    }
  }

  /**
   * 检查是否已初始化
   */
  static isInitialized(): boolean {
    return ServiceProvider._injectorInitialized;
  }
}
