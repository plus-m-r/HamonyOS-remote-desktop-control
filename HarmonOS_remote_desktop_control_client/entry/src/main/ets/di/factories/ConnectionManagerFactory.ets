import { ConnectionManager } from '../../services/connection/ConnectionManager';
import { IConnectionManager } from '../../services/connection/IConnectionManager';
import { configCenter } from '../../config/config';
import { TcpRepositoryImpl } from '../../repository/TcpRepositoryImpl';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001;
const TAG = 'ConnectionManagerFactory';

export class ConnectionManagerFactory {
  static create(): IConnectionManager {
    const serverConfig = configCenter.getServerConfig();
    const tcpRepository = new TcpRepositoryImpl();

    const connectionManager = new ConnectionManager(
      serverConfig.host,
      serverConfig.tcpPort,
      tcpRepository,
      3,
      2000
    );

    hilog.info(DOMAIN, TAG, 'Created');
    return connectionManager;
  }
}
