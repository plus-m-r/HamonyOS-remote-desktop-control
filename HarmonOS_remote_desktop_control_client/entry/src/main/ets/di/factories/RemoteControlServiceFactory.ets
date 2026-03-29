// entry/src/main/ets/di/factories/RemoteControlServiceFactory.ets
// 远程控制服务工厂 - 创建 IRemoteControlService 实例

import { RemoteControlService } from '../../services/remote/RemoteControlService';
import { 
  IRemoteControlService, 
  RemoteControlServiceConfig, 
  RemoteControlServiceDependencies 
} from '../../services/interfaces/IRemoteControlService';
import { configCenter } from '../../config/config';
import { TcpRepositoryImpl } from '../../repository/TcpRepositoryImpl';
import { WorkerRepositoryImpl } from '../../repository/WorkerRepositoryImpl';
import { HeartbeatManager } from '../../services/heartbeat/HeartbeatManager';

/**
 * 远程控制服务工厂
 * 负责创建和配置 RemoteControlService 实例
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

    // 创建依赖
    const tcpRepository = new TcpRepositoryImpl();
    const workerRepository = new WorkerRepositoryImpl();
    const heartbeatManager = new HeartbeatManager({
      interval: 30000, // 30秒心跳间隔
      timeout: 10000   // 10秒超时
    });

    // 创建服务实例
    const config: RemoteControlServiceConfig = {
      host: serverConfig.host,
      port: serverConfig.tcpPort,
      maxReconnectAttempts: 3,
      reconnectDelay: 2000,
      heartbeatInterval: 30000
    };

    const dependencies: RemoteControlServiceDependencies = {
      tcpRepository,
      workerRepository,
      heartbeatManager
    };

    const service = new RemoteControlService(config, dependencies);

    console.info('RemoteControlServiceFactory: Service created');
    
    return service;
  }
}
