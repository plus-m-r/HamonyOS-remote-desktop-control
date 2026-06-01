import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { ServiceProvider } from '../di/ServiceProvider';
import { appStateManager } from '../state/AppStateManager';
import { ContextManager } from '../utils/ContextManager';
import { GlobalContext } from '../utils/GlobalContext';
import { DependencyInitializer } from '../utils/DependencyInitializer';
import { DependencyContainer } from '../utils/DependencyContainer';

// 日志域标识，用于区分不同模块的日志输出
const DOMAIN = 0x0000;

/**
 * EntryAbility - 应用入口 Ability
 * 
 * 这是远程桌面控制应用的入口类，继承自 HarmonyOS 的 UIAbility。
 * Ability 是 HarmonyOS 应用的基本组成单元，类似于 Android 的 Activity。
 * 该类负责管理应用的生命周期、初始化核心服务、建立服务器连接等。
 */
export default class EntryAbility extends UIAbility {

  /**
   * onCreate - Ability 创建时回调
   * 
   * 当 Ability 被系统创建时调用，是应用生命周期的起点。
   * 在此方法中完成应用的初始化工作：
   * 1. 设置应用颜色模式（跟随系统）
   * 2. 初始化上下文管理器
   * 3. 初始化远程控制服务并连接服务器
   * 
   * @param want - 启动 Ability 的意图信息，包含启动参数
   * @param launchParam - 启动参数，包含启动原因等信息
   */
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 设置应用颜色模式为跟随系统，不强制指定浅色或深色模式
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    
    // 配置全局 Context
    GlobalContext.getContext().setObject("context", this.context);
    
    // 初始化 ContextManager，保存应用上下文供全局使用
    // ContextManager 是一个单例类，用于在应用各处获取 Ability 上下文
    ContextManager.getInstance().setContext(this.context);
    
    // 初始化依赖注入容器
    DependencyInitializer.initialize();
    
    // 触发生命周期管理器的创建事件
    const container = DependencyContainer.getInstance();
    const lifecycleManager = container.getLifecycleManager();
    lifecycleManager.create();
    
    // 初始化远程控制服务并建立与远程桌面服务器的连接
    this.initializeServices();
  }

  /**
   * onDestroy - Ability 销毁时回调
   * 
   * 当 Ability 被系统销毁时调用，是应用生命周期的终点。
   * 在此方法中完成资源的清理工作：
   * 1. 断开与远程桌面服务器的连接
   * 2. 释放网络资源
   * 3. 清理其他占用的系统资源
   * 
   * 注意：此方法在应用被完全关闭时调用，应确保所有资源都被正确释放
   */
  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
    
    // 断开与远程桌面服务器的连接，释放网络资源
    this.disconnectServices();
    
    // 触发生命周期管理器的销毁事件
    const container = DependencyContainer.getInstance();
    const lifecycleManager = container.getLifecycleManager();
    lifecycleManager.destroy();
  }

  /**
   * onWindowStageCreate - 窗口舞台创建时回调
   * 
   * 当 Ability 的窗口舞台（WindowStage）被创建时调用。
   * 窗口舞台是 HarmonyOS 中管理窗口的容器，一个 Ability 对应一个 WindowStage。
   * 在此方法中完成 UI 的加载：
   * 1. 加载主页面内容（pages/Index）
   * 2. 设置窗口相关属性
   * 
   * @param windowStage - 窗口舞台实例，用于管理应用窗口
   */
  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // 加载主页面内容，'pages/Index' 对应 entry/src/main/ets/pages/Index.ets
    // 这是用户打开应用后看到的第一个页面
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  /**
   * onWindowStageDestroy - 窗口舞台销毁时回调
   * 
   * 当 Ability 的窗口舞台被销毁时调用。
   * 通常发生在应用切换到后台且系统资源紧张时，或者应用被关闭时。
   * 在此方法中释放与 UI 相关的资源。
   */
  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  /**
   * onForeground - Ability 进入前台时回调
   * 
   * 当 Ability 从后台切换到前台时调用。
   * 此时应用对用户可见，可以恢复一些暂停的操作。
   * 例如：恢复网络连接、恢复屏幕刷新等。
   */
  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
    
    // 触发生命周期管理器的恢复事件
    const container = DependencyContainer.getInstance();
    const lifecycleManager = container.getLifecycleManager();
    lifecycleManager.resume();
  }

  /**
   * onBackground - Ability 进入后台时回调
   * 
   * 当 Ability 从前台切换到后台时调用。
   * 此时应用对用户不可见，应暂停一些不必要的操作以节省资源。
   * 例如：暂停屏幕捕获、降低网络请求频率等。
   */
  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
    
    // 触发生命周期管理器的暂停事件
    const container = DependencyContainer.getInstance();
    const lifecycleManager = container.getLifecycleManager();
    lifecycleManager.pause();
  }
  
  /**
   * initializeServices - 初始化远程控制服务
   * 
   * 这是一个私有方法，负责初始化应用的核心服务：
   * 1. 通过 ServiceProvider 初始化所有服务（单例模式）
   * 2. 设置设备信息回调，用于接收服务器分配的设备ID和密码
   * 3. 建立与远程桌面服务器的 TCP 连接
   * 
   * 工作流程：
   * - 应用启动时，服务器会为当前设备分配唯一的设备ID和密码
   * - 其他设备可以使用这个ID和密码来连接控制当前设备
   * - 设备信息通过回调函数传递给 UI 层显示
   * 
   * 异常处理：
   * - 如果初始化失败，会记录错误日志，但不会影响应用启动
   * - 用户可以在界面上手动重试连接
   */
  private async initializeServices() {
    try {
      hilog.info(DOMAIN, 'testTag', '开始初始化服务...');
      
      // 初始化 ServiceProvider，它会创建并配置所有需要的服务的单例实例
      // 包括：RemoteControlService、ClipboardService、FileService 等
      await ServiceProvider.initialize();
      
      // 获取远程控制服务的单例实例
      const remoteControlService = ServiceProvider.remoteControlService;
      
      // 设置设备信息回调函数
      // 当服务器分配设备ID和密码后，会调用此回调通知 UI 更新显示
      remoteControlService.setDeviceInfoCallback((deviceCode: string, password: string) => {
        hilog.info(DOMAIN, 'testTag', '收到服务器分配的设备信息 - ID: %{public}s, 密码: %{public}s', deviceCode, password);
        
        // 将设备信息保存到全局状态管理器
        // 这样应用的其他页面和组件都可以访问到这些信息
        appStateManager.setUserId(deviceCode);
        appStateManager.setUserPassword(password);
      });
      
      // 建立与远程桌面服务器的 TCP 连接
      // 连接成功后，服务器会分配设备ID和密码
      await remoteControlService.connect(
        () => {
          // 连接成功回调
          hilog.info(DOMAIN, 'testTag', '连接到服务器成功，等待设备信息...');
        },
        (error: string) => {
          // 连接失败回调
          hilog.error(DOMAIN, 'testTag', '连接到服务器失败: %{public}s', error);
        }
      );
      
      hilog.info(DOMAIN, 'testTag', '服务初始化完成');
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      const errorStack = error instanceof Error ? error.stack : '';
      hilog.error(DOMAIN, 'testTag', '服务初始化失败: %{public}s, stack: %{public}s', errorMessage, errorStack);
    }
  }
  
  /**
   * disconnectServices - 断开服务连接
   * 
   * 这是一个私有方法，负责在应用关闭时清理资源：
   * 1. 获取远程控制服务实例
   * 2. 调用 disconnect 方法关闭 TCP 连接
   * 3. 释放网络资源
   * 
   * 调用时机：
   * - 在 onDestroy 方法中被调用
   * - 确保应用退出时优雅地关闭连接，避免资源泄漏
   * 
   * 异常处理：
   * - 即使断开连接失败，也不会抛出异常，确保应用能正常退出
   */
  private async disconnectServices() {
    try {
      // 获取远程控制服务实例
      const remoteControlService = ServiceProvider.remoteControlService;
      
      // 断开与远程桌面服务器的连接
      // 这会关闭 TCP 套接字，停止心跳检测，清理相关资源
      await remoteControlService.disconnect();
      
      hilog.info(DOMAIN, 'testTag', '服务已断开连接');
    } catch (error) {
      // 记录断开连接过程中的错误，但不影响应用退出
      hilog.error(DOMAIN, 'testTag', '断开连接失败: %{public}s', JSON.stringify(error));
    }
  }
}
