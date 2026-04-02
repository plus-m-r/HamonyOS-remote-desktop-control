import { ProtocolHandler } from '../../services/protocol/ProtocolHandler';
import { IProtocolHandler } from '../../services/protocol/IProtocolHandler';
import { WorkerRepositoryImpl } from '../../repository/WorkerRepositoryImpl';

export class ProtocolHandlerFactory {
  static create(): IProtocolHandler {
    const workerRepository = new WorkerRepositoryImpl();
    const protocolHandler = new ProtocolHandler(workerRepository);

    console.info('ProtocolHandlerFactory: Created');
    return protocolHandler;
  }
}
