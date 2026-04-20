/**
 * 依赖初始化器
 * 
 * 用于在应用启动时注册所有依赖项
 */
import { DependencyContainer, DependencyKeys } from './DependencyContainer';
import { CaptureCache } from '../squeeze/CaptureCache';
import hilog from '@ohos.hilog';
import { configCenter } from '../config/config';

const DOMAIN = 0xFF00;
const TAG = 'DependencyInitializer';

export class DependencyInitializer {
  /**
   * 初始化所有依赖项
   */
  public static initialize(): void {
    const container = DependencyContainer.getInstance();
    
    // 注册CaptureCache为单例，并支持生命周期管理
    container.register<CaptureCache>(
      DependencyKeys.CAPTURE_CACHE,
      () => {
        const runtimeConfig = configCenter.getCaptureCacheRuntimeConfig();
        const captureCache = new CaptureCache(runtimeConfig.maxSize, runtimeConfig.purgeSize, {
          queueMaxSize: runtimeConfig.queueMaxSize,
          queueMaxBytes: runtimeConfig.queueMaxBytes,
          queueLowWatermarkBytes: runtimeConfig.queueLowWatermarkBytes,
          queueHighWatermarkBytes: runtimeConfig.queueHighWatermarkBytes,
          pressureStartRatio: runtimeConfig.pressureStartRatio,
          pressureDropDirtyTileRatio: runtimeConfig.pressureDropDirtyTileRatio
        });
        hilog.info(DOMAIN, TAG, 'CaptureCache registered as singleton with lifecycle support');
        return captureCache;
      },
      true,
      true // 启用生命周期管理
    );
    
    hilog.info(DOMAIN, TAG, 'Dependencies initialized');
  }
}
