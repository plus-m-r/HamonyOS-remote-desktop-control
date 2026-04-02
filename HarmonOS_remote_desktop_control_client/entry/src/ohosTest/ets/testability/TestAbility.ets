import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

// 日志域标识，用于区分不同模块的日志输出
const DOMAIN = 0x0000;

/**
 * TestAbility - 测试模块的入口 Ability
 * 
 * 这是测试模块的入口类，继承自 HarmonyOS 的 UIAbility。
 * 用于运行测试套件和展示测试结果。
 */
export default class TestAbility extends UIAbility {

  /**
   * onCreate - Ability 创建时回调
   * 
   * 当 Ability 被系统创建时调用，是应用生命周期的起点。
   * 
   * @param want - 启动 Ability 的意图信息，包含启动参数
   * @param launchParam - 启动参数，包含启动原因等信息
   */
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'TestAbility onCreate');
  }

  /**
   * onWindowStageCreate - 窗口阶段创建时回调
   * 
   * 当 Ability 的窗口阶段创建时调用，用于加载测试页面。
   * 
   * @param windowStage - 窗口阶段对象
   */
  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'TestAbility onWindowStageCreate');

    // 加载测试页面
    windowStage.loadContent('pages/TestIndex', (err, data) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content. Data: %{public}s', JSON.stringify(data));
    });
  }

  /**
   * onWindowStageDestroy - 窗口阶段销毁时回调
   * 
   * 当 Ability 的窗口阶段销毁时调用。
   */
  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'TestAbility onWindowStageDestroy');
  }

  /**
   * onForeground - Ability 切换到前台时回调
   * 
   * 当 Ability 切换到前台时调用。
   */
  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'TestAbility onForeground');
  }

  /**
   * onBackground - Ability 切换到后台时回调
   * 
   * 当 Ability 切换到后台时调用。
   */
  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'TestAbility onBackground');
  }

  /**
   * onDestroy - Ability 销毁时回调
   * 
   * 当 Ability 被销毁时调用。
   */
  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'TestAbility onDestroy');
  }
}