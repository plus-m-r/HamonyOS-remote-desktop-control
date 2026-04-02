// entry/src/main/ets/di/factories/RemoteControlServiceFactory.ets
// 远程控制服务工厂 - 创建 IRemoteControlService 实例

import { RemoteControlService } from '../../services/remote/RemoteControlService';
import { 
  IRemoteControlService, 
  RemoteControlServiceConfig
} from '../../services/interfaces/IRemoteControlService';
import { IConnectionManager } from '../../services/connection/IConnectionManager';
import { IProtocolHandler } from '../../services/protocol/IProtocolHandler';
import { IHeartbeatManager } from '../../services/interfaces/IHeartbeatManager';
import { configCenter } from '../../config/config';
import { Injector, ServiceKeys } from '../Injector';
import { HeartbeatManager } from '../../services/heartbeat/HeartbeatManager';

/**
 * 远程控制服务工厂
 * 负责创建和配置 RemoteControlServiceRefactored 实例
 * 返回 IRemoteControlService 接口类型
 */
export class RemoteControlServiceFactory {
  /**
   * 创建远程控制服务实例
   * @returns IRemoteControlService 实例
   */
  static create(): IRemoteControlService {
    // 从配置中心获取服务器配置
    const serverConfig = configCenter.getServerConfig();

    // 从 DI 容器获取依赖
    const injector = Injector.getInstance();
    const connectionManager = injector.resolve<IConnectionManager>(ServiceKeys.CONNECTION_MANAGER);
    const protocolHandler = injector.resolve<IProtocolHandler>(ServiceKeys.PROTOCOL_HANDLER);
    const heartbeatManager = new HeartbeatManager({
      interval: 3000,
      timeout: 5000
    });

    // 创建服务配置
    const config: RemoteControlServiceConfig = {
      host: serverConfig.host,
      port: serverConfig.tcpPort,
      maxReconnectAttempts: 3,
      reconnectDelay: 2000,
      heartbeatInterval: 3000
    };

    // 创建服务实例
    const service = new RemoteControlService(
      config,
      connectionManager,
      protocolHandler,
      heartbeatManager
    );

    console.info('RemoteControlServiceFactory: Service created');
    
    return service;
  }
}
