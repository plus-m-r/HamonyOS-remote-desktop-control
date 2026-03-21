// entry/src/main/ets/state/ServiceLocator.ets
import { RemoteControlService } from '../services/remote/RemoteControlService';
import { ClipboardService } from '../services/clipboard/ClipboardService';
import { FileService } from '../services/file/FileService';
import { AppStateManager } from './AppStateManager';
import { ScreenImage } from '../models/DeviceInfo';
import { SERVER_CONFIG } from '../config/config';

/**
 * 服务定位器
 * 实现服务单例管理和依赖注入
 */
export class ServiceLocator {
  private static instance: ServiceLocator | null = null;
  
  // 服务实例
  private remoteControlService: RemoteControlService | null = null;
  private clipboardService: ClipboardService | null = null;
  private fileService: FileService | null = null;
  
  // 初始化标志
  private initialized: boolean = false;

  private constructor() {}

  /**
   * 获取服务定位器单例
   */
  static getInstance(): ServiceLocator {
    if (!ServiceLocator.instance) {
      ServiceLocator.instance = new ServiceLocator();
    }
    return ServiceLocator.instance;
  }

  /**
   * 初始化所有服务
   * 在应用启动时调用
   */
  initialize(): void {
    if (this.initialized) {
      console.warn('ServiceLocator: Already initialized');
      return;
    }

    // 初始化全局状态
    AppStateManager.initialize();

    // 创建服务实例
    this.createServices();

    this.initialized = true;
    console.info('ServiceLocator: All services initialized');
  }

  /**
   * 创建服务实例
   */
  private createServices(): void {
    const baseUrl = `http://${SERVER_CONFIG.host}:${SERVER_CONFIG.httpPort}${SERVER_CONFIG.contextPath}`;

    // 创建剪贴板服务
    this.clipboardService = new ClipboardService(baseUrl);

    // 创建文件服务
    this.fileService = new FileService(baseUrl);

    // 创建远程控制服务（带屏幕回调）
    this.remoteControlService = new RemoteControlService(
      SERVER_CONFIG.host,
      SERVER_CONFIG.tcpPort,
      (data: ArrayBuffer, width: number, height: number, timestamp: number) => {
        // 屏幕数据回调 - 更新全局状态
        AppStateManager.setScreenData(data, width, height, timestamp);
      }
    );

    console.info('ServiceLocator: Services created');
  }

  /**
   * 获取远程控制服务
   */
  getRemoteControlService(): RemoteControlService {
    if (!this.remoteControlService) {
      throw new Error('RemoteControlService not initialized. Call initialize() first.');
    }
    return this.remoteControlService;
  }

  /**
   * 获取剪贴板服务
   */
  getClipboardService(): ClipboardService {
    if (!this.clipboardService) {
      throw new Error('ClipboardService not initialized. Call initialize() first.');
    }
    return this.clipboardService;
  }

  /**
   * 获取文件服务
   */
  getFileService(): FileService {
    if (!this.fileService) {
      throw new Error('FileService not initialized. Call initialize() first.');
    }
    return this.fileService;
  }

  /**
   * 检查是否已初始化
   */
  isInitialized(): boolean {
    return this.initialized;
  }

  /**
   * 清理所有服务资源
   * 在应用退出时调用
   */
  async cleanup(): Promise<void> {
    console.info('ServiceLocator: Cleaning up services');

    // 断开远程控制连接
    if (this.remoteControlService) {
      try {
        await this.remoteControlService.disconnect();
      } catch (error) {
        console.error('ServiceLocator: Failed to disconnect remote control', error);
      }
    }

    // 清理文件服务
    if (this.fileService) {
      this.fileService.cleanup();
    }

    // 重置状态
    this.initialized = false;
    this.remoteControlService = null;
    this.clipboardService = null;
    this.fileService = null;

    console.info('ServiceLocator: Cleanup completed');
  }

  /**
   * 重置单例（仅用于测试）
   */
  static reset(): void {
    if (ServiceLocator.instance) {
      ServiceLocator.instance.cleanup();
    }
    ServiceLocator.instance = null;
  }
}

/**
 * 全局服务访问器
 * 提供便捷的服务访问方法
 */
export class Services {
  /**
   * 获取远程控制服务
   */
  static get remote(): RemoteControlService {
    return ServiceLocator.getInstance().getRemoteControlService();
  }

  /**
   * 获取剪贴板服务
   */
  static get clipboard(): ClipboardService {
    return ServiceLocator.getInstance().getClipboardService();
  }

  /**
   * 获取文件服务
   */
  static get file(): FileService {
    return ServiceLocator.getInstance().getFileService();
  }

  /**
   * 初始化服务
   */
  static initialize(): void {
    ServiceLocator.getInstance().initialize();
  }

  /**
   * 清理服务
   */
  static async cleanup(): Promise<void> {
    await ServiceLocator.getInstance().cleanup();
  }
}