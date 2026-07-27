import { ClipboardService } from '../../services/clipboard/ClipboardService';
import { IClipboardService } from '../../services/interfaces/IClipboardService';
import { HttpRepositoryImpl } from '../../repository/HttpRepositoryImpl';
import { configCenter } from '../../config/config';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001;
const TAG = 'ClipboardServiceFactory';

export class ClipboardServiceFactory {
  static createWithSharedRepo(httpRepository: HttpRepositoryImpl): IClipboardService {
    const baseUrl = configCenter.getHttpUrl();
    const service = new ClipboardService(httpRepository, {
      baseUrl: baseUrl,
      syncInterval: 1000,
      maxTextLength: 10000
    });
    hilog.info(DOMAIN, TAG, 'Service created with shared repo');
    return service;
  }
}
