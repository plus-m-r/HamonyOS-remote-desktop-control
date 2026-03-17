// entry/src/main/ets/di/factories/ClipboardServiceFactory.ts
import { ClipboardService } from '../../services/clipboard/ClipboardService';
import { SERVER_CONFIG } from '../../config/config';

/**
 * 剪贴板服务工厂
 * 负责创建和配置ClipboardService实例
 */
export class ClipboardServiceFactory {
  /**
   * 创建剪贴板服务实例
   * @returns ClipboardService实例
   */
  static create(): ClipboardService {
    // 构建基础URL
    const baseUrl = `http://${SERVER_CONFIG.host}:${SERVER_CONFIG.httpPort}${SERVER_CONFIG.contextPath}`;

    // 创建服务实例
    const service = new ClipboardService(baseUrl);

    // 配置服务
    ClipboardServiceFactory.configure(service);

    return service;
  }

  /**
   * 配置剪贴板服务
   * @param service ClipboardService实例
   */
  private static configure(service: ClipboardService): void {
    // 可以在这里添加额外的配置
    console.info('ClipboardServiceFactory: Service configured');
  }
}
