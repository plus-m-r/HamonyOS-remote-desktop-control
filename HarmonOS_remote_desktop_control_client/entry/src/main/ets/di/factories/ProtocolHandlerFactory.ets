import { ProtocolHandler } from '../../services/protocol/ProtocolHandler';
import { IProtocolHandler } from '../../services/protocol/IProtocolHandler';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001;
const TAG = 'ProtocolHandlerFactory';

export class ProtocolHandlerFactory {
  static create(): IProtocolHandler {
    const protocolHandler = new ProtocolHandler();
    hilog.info(DOMAIN, TAG, 'Created (main thread)');
    return protocolHandler;
  }
}
