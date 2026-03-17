
// entry/src/main/ets/di/ServiceProvider.ets
import { Injector, ServiceKeys } from './Injector';
import { RemoteControlService } from '../services/remote/RemoteControlService';
import { ClipboardService } from '../services/clipboard/ClipboardService';
import { FileService } from '../services/file/FileService';

/**
 * 服务提供者
 * 提供便捷的服务访问方法，使用依赖注入框架
 */
export class ServiceProvider {
  /**
   * 初始化服务提供者
   */
  static async initialize(): Promise<void> {
    const injector = Injector.getInstance();
    await injector.initialize();
    console.info('ServiceProvider: Initialized');
  }

  /**
   * 获取远程控制服务
   */
  static get remoteControlService(): RemoteControlService {
    return Injector.getInstance().resolve<RemoteControlService>(ServiceKeys.REMOTE_CONTROL_SERVICE);
  }

  /**
   * 获取剪贴板服务
   */
  static get clipboardService(): ClipboardService {
    return Injector.getInstance().resolve<ClipboardService>(ServiceKeys.CLIPBOARD_SERVICE);
  }

  /**
   * 获取文件服务
   */
  static get fileService(): FileService {
    return Injector.getInstance().resolve<FileService>(ServiceKeys.FILE_SERVICE);
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
      
      // 清理依赖注入容器
      Injector.getInstance().clear();
      
      console.info('ServiceProvider: Cleanup completed');
    } catch (error) {
      console.error('ServiceProvider: Cleanup failed', error);
    }
  }
}
