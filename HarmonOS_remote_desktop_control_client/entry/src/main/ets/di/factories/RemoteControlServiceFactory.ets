// entry/src/main/ets/di/factories/RemoteControlServiceFactory.ts
import { RemoteControlService } from '../../services/remote/RemoteControlService';
import { SERVER_CONFIG } from '../../config/config';
import { AppStateManager } from '../../state/AppStateManager';

/**
 * 远程控制服务工厂
 * 负责创建和配置RemoteControlService实例
 */
export class RemoteControlServiceFactory {
  /**
   * 创建远程控制服务实例
   * @param screenCallback 屏幕回调函数
   * @returns RemoteControlService实例
   */
  static create(screenCallback?: (data: ArrayBuffer, width: number, height: number, timestamp: number) => void): RemoteControlService {
    // 如果没有提供屏幕回调，使用默认回调
    const defaultCallback = screenCallback || ((data: ArrayBuffer, width: number, height: number, timestamp: number) => {
      // 更新全局状态
      AppStateManager.setScreenData(data, width, height, timestamp);
    });

    // 创建服务实例
    const service = new RemoteControlService(
      SERVER_CONFIG.host,
      SERVER_CONFIG.tcpPort,
      defaultCallback
    );

    // 配置服务
    RemoteControlServiceFactory.configure(service);

    return service;
  }

  /**
   * 配置远程控制服务
   * @param service RemoteControlService实例
   */
  private static configure(service: RemoteControlService): void {
    // 可以在这里添加额外的配置
    console.info('RemoteControlServiceFactory: Service configured');
  }
}
