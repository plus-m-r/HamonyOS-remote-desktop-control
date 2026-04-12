/**
 * 依赖初始化器
 * 
 * 用于在应用启动时注册所有依赖项
 */
import { DependencyContainer, DependencyKeys } from './DependencyContainer';
import { CaptureCache } from '../squeeze/CaptureCache';
import hilog from '@ohos.hilog';

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
        const captureCache = new CaptureCache(50, 25);
        hilog.info(DOMAIN, TAG, 'CaptureCache registered as singleton with lifecycle support');
        return captureCache;
      },
      true,
      true // 启用生命周期管理
    );
    
    hilog.info(DOMAIN, TAG, 'Dependencies initialized');
  }
}
