import { ProtocolHandler } from '../../services/protocol/ProtocolHandler';
import { IProtocolHandler } from '../../services/protocol/IProtocolHandler';
import { IWorkerRepository } from '../../repository/IWorkerRepository';
import { Injector, ServiceKeys } from '../Injector';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001;
const TAG = 'ProtocolHandlerFactory';

export class ProtocolHandlerFactory {
  static create(): IProtocolHandler {
    const injector = Injector.getInstance();
    const workerRepository = injector.resolve<IWorkerRepository>(ServiceKeys.WORKER_REPOSITORY);
    const protocolHandler = new ProtocolHandler(workerRepository);

    hilog.info(DOMAIN, TAG, 'Created');
    return protocolHandler;
  }
}
