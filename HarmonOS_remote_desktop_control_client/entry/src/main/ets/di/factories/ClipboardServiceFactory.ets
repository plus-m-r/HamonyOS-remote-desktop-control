// entry/src/main/ets/di/factories/ClipboardServiceFactory.ets
// 剪贴板服务工厂 - 创建 IClipboardService 实例

import { ClipboardService } from '../../services/clipboard/ClipboardService';
import { IClipboardService } from '../../services/interfaces/IClipboardService';
import { configCenter } from '../../config/config';
import { HttpRepositoryImpl } from '../../repository/HttpRepositoryImpl';

/**
 * 剪贴板服务工厂
 * 负责创建和配置 ClipboardService 实例
 * 返回 IClipboardService 接口类型
 */
export class ClipboardServiceFactory {
  /**
   * 创建剪贴板服务实例
   * @returns IClipboardService 实例
   */
  static create(): IClipboardService {
    // 从配置中心获取基础 URL
    const baseUrl = configCenter.getHttpUrl();

    // 创建 HTTP 仓库
    const httpRepository = new HttpRepositoryImpl();
    httpRepository.setBaseUrl(baseUrl);

    // 创建服务实例
    const service = new ClipboardService(httpRepository, {
      baseUrl,
      syncInterval: 1000,
      maxTextLength: 10000
    });

    console.info('ClipboardServiceFactory: Service created');

    return service;
  }
}
