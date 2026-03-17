// entry/src/main/ets/di/factories/FileServiceFactory.ts
import { FileService } from '../../services/file/FileService';
import { SERVER_CONFIG } from '../../config/config';

/**
 * 文件服务工厂
 * 负责创建和配置FileService实例
 */
export class FileServiceFactory {
  /**
   * 创建文件服务实例
   * @returns FileService实例
   */
  static create(): FileService {
    // 构建基础URL
    const baseUrl = `http://${SERVER_CONFIG.host}:${SERVER_CONFIG.httpPort}${SERVER_CONFIG.contextPath}`;

    // 创建服务实例
    const service = new FileService(baseUrl);

    // 配置服务
    FileServiceFactory.configure(service);

    return service;
  }

  /**
   * 配置文件服务
   * @param service FileService实例
   */
  private static configure(service: FileService): void {
    // 可以在这里添加额外的配置
    console.info('FileServiceFactory: Service configured');
  }
}
