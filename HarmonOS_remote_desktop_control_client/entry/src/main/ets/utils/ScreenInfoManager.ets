import hilog from '@ohos.hilog';
import { display } from '@kit.ArkGraphics2D';
import { ContextManager } from './ContextManager';

const DOMAIN = 0xFF00;
const TAG = 'ScreenInfoManager';

export interface ScreenInfo {
  width: number;
  height: number;
  refreshRate: number;
  density: number;
  orientation: string;
}

export class ScreenInfoManager {
  private static instance: ScreenInfoManager | null = null;
  private screenInfo: ScreenInfo | null = null;

  private constructor() {}

  static getInstance(): ScreenInfoManager {
    if (!ScreenInfoManager.instance) {
      ScreenInfoManager.instance = new ScreenInfoManager();
    }
    return ScreenInfoManager.instance;
  }

  async getScreenInfo(): Promise<ScreenInfo> {
    if (this.screenInfo) {
      return this.screenInfo;
    }

    try {
      const ctx = ContextManager.getInstance().getContext();
      if (!ctx) {
        hilog.warn(DOMAIN, TAG, 'Context not available, using default screen info');
        return this.getDefaultScreenInfo();
      }

      const displayInfo = display.getDefaultDisplaySync();
      this.screenInfo = {
        width: displayInfo.width,
        height: displayInfo.height,
        refreshRate: displayInfo.refreshRate,
        density: displayInfo.density,
        orientation: displayInfo.orientation as string
      };

      hilog.info(DOMAIN, TAG, 'Screen info: %{public}d x %{public}d, refreshRate: %{public}d',
        this.screenInfo.width, this.screenInfo.height, this.screenInfo.refreshRate);

      return this.screenInfo;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to get screen info: %{public}s', JSON.stringify(error));
      return this.getDefaultScreenInfo();
    }
  }

  private getDefaultScreenInfo(): ScreenInfo {
    return {
      width: 1920,
      height: 1080,
      refreshRate: 60,
      density: 2.0,
      orientation: 'PORTRAIT'
    };
  }

  getCachedScreenInfo(): ScreenInfo | null {
    return this.screenInfo;
  }
}
