import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { ServiceProvider } from '../di/ServiceProvider';
import { AppStateManager } from '../state/AppStateManager';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    
    // 初始化服务并建立连接
    this.initializeServices();
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
    
    // 断开连接
    this.disconnectServices();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
  
  // 初始化服务并建立连接
  private async initializeServices() {
    try {
      hilog.info(DOMAIN, 'testTag', '开始初始化服务...');
      await ServiceProvider.initialize();
      
      // 获取远程控制服务
      const remoteControlService = ServiceProvider.remoteControlService;
      
      // 设置设备信息回调，用于接收服务器分配的设备ID和密码
      remoteControlService.setDeviceInfoCallback((deviceCode: string, password: string) => {
        hilog.info(DOMAIN, 'testTag', '收到服务器分配的设备信息 - ID: %{public}s, 密码: %{public}s', deviceCode, password);
        
        // 保存到全局状态
        AppStateManager.setUserId(deviceCode);
        AppStateManager.setUserPassword(password);
      });
      
      // 连接到服务器以获取设备信息
      await remoteControlService.connect(
        () => {
          hilog.info(DOMAIN, 'testTag', '连接到服务器成功，等待设备信息...');
        },
        (error: string) => {
          hilog.error(DOMAIN, 'testTag', '连接到服务器失败: %{public}s', error);
        }
      );
      
      hilog.info(DOMAIN, 'testTag', '服务初始化完成');
    } catch (error) {
      hilog.error(DOMAIN, 'testTag', '服务初始化失败: %{public}s', JSON.stringify(error));
    }
  }
  
  // 断开连接
  private async disconnectServices() {
    try {
      const remoteControlService = ServiceProvider.remoteControlService;
      await remoteControlService.disconnect();
      hilog.info(DOMAIN, 'testTag', '服务已断开连接');
    } catch (error) {
      hilog.error(DOMAIN, 'testTag', '断开连接失败: %{public}s', JSON.stringify(error));
    }
  }
}