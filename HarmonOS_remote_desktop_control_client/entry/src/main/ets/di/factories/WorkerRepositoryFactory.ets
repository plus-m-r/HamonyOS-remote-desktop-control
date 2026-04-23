// Worker仓库工厂 - 创建 IWorkerRepository 实例

import { WorkerRepositoryImpl } from '../../repository/WorkerRepositoryImpl';
import { IWorkerRepository } from '../../repository/IWorkerRepository';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001;
const TAG = 'WorkerRepositoryFactory';

/**
 * Worker仓库工厂
 * 负责创建 WorkerRepositoryImpl 的实例
 */
export class WorkerRepositoryFactory {
  /**
   * 创建Worker仓库实例
   * @returns IWorkerRepository 实例
   */
  static create(): IWorkerRepository {
    const repository = new WorkerRepositoryImpl();
    hilog.info(DOMAIN, TAG, 'WorkerRepository created');
    return repository;
  }
}
