// entry/src/main/ets/di/factories/FileServiceFactory.ets
// 文件服务工厂 - 创建 IFileService 实例

import { FileService } from '../../services/file/FileService';
import { IFileService } from '../../services/interfaces/IFileService';
import { configCenter } from '../../config/config';
import { HttpRepositoryImpl } from '../../repository/HttpRepositoryImpl';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001;
const TAG = 'FileServiceFactory';

/**
 * 文件服务工厂
 * 负责创建和配置 FileService 实例
 * 返回 IFileService 接口类型
 */
export class FileServiceFactory {
  /**
   * 创建文件服务实例
   * @returns IFileService 实例
   */
  static create(): IFileService {
    // 从配置中心获取基础 URL
    const baseUrl = configCenter.getHttpUrl();

    // 创建 HTTP 仓库
    const httpRepository = new HttpRepositoryImpl();
    httpRepository.setBaseUrl(baseUrl);

    // 创建服务实例
    const service = new FileService(httpRepository, {
      baseUrl,
      chunkSize: 1024 * 1024, // 1MB
      maxConcurrentUploads: 3,
      maxFileSize: 1024 * 1024 * 1024 // 1GB
    });

    hilog.info(DOMAIN, TAG, 'Service created');

    return service;
  }
}
