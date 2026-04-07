import { ProtocolHandler } from '../../services/protocol/ProtocolHandler';
import { IProtocolHandler } from '../../services/protocol/IProtocolHandler';
import { IWorkerRepository } from '../../repository/IWorkerRepository';
import { Injector, ServiceKeys } from '../Injector';

export class ProtocolHandlerFactory {
  static create(): IProtocolHandler {
    const injector = Injector.getInstance();
    const workerRepository = injector.resolve<IWorkerRepository>(ServiceKeys.WORKER_REPOSITORY);
    const protocolHandler = new ProtocolHandler(workerRepository);

    console.info('ProtocolHandlerFactory: Created');
    return protocolHandler;
  }
}
