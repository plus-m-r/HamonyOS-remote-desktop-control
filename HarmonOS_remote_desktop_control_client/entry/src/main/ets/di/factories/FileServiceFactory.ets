import { FileService } from '../../services/file/FileService';
import { IFileService } from '../../services/interfaces/IFileService';
import { HttpRepositoryImpl } from '../../repository/HttpRepositoryImpl';
import { configCenter } from '../../config/config';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001;
const TAG = 'FileServiceFactory';

export class FileServiceFactory {
  static createWithSharedRepo(httpRepository: HttpRepositoryImpl): IFileService {
    const baseUrl = configCenter.getHttpUrl();
    const service = new FileService(httpRepository, {
      baseUrl: baseUrl,
      chunkSize: 1024 * 1024,
      maxConcurrentUploads: 3,
      maxFileSize: 1024 * 1024 * 1024
    });
    hilog.info(DOMAIN, TAG, 'Service created with shared repo');
    return service;
  }
}
