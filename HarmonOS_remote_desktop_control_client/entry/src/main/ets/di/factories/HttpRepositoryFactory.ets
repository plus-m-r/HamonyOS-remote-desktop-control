import { HttpRepositoryImpl } from '../../repository/HttpRepositoryImpl';
import { configCenter } from '../../config/config';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001;
const TAG = 'HttpRepositoryFactory';

export class HttpRepositoryFactory {
  private static instance: HttpRepositoryImpl | null = null;

  static create(): HttpRepositoryImpl {
    if (HttpRepositoryFactory.instance) {
      const baseUrl = configCenter.getHttpUrl();
      HttpRepositoryFactory.instance.setBaseUrl(baseUrl);
      return HttpRepositoryFactory.instance;
    }
    const baseUrl = configCenter.getHttpUrl();
    const httpRepository = new HttpRepositoryImpl();
    httpRepository.setBaseUrl(baseUrl);
    HttpRepositoryFactory.instance = httpRepository;
    hilog.info(DOMAIN, TAG, 'Shared HTTP repository created');
    return httpRepository;
  }
}
