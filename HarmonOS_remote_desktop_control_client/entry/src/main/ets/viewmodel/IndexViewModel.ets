/**
 * Index 页面 ViewModel
 *
 * 解耦页面逻辑和业务逻辑
 * 页面只负责UI渲染，ViewModel负责业务逻辑
 */

import { IRemoteControlService } from '../services/interfaces/IRemoteControlService';
import { IAppStateManager } from '../state/IAppStateManager';
import { IClipboardService } from '../services/interfaces/IClipboardService';
import { ConfigCenter } from '../config/ConfigCenter';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001;
const TAG = 'IndexViewModel';

/**
 * Index 页面状态
 */
export interface IndexPageState {
  /** 用户ID */
  userId: string;
  /** 用户密码 */
  userPassword: string;
  /** 输入的设备ID */
  deviceIdInput: string;
  /** 输入的设备密码 */
  devicePasswordInput: string;
  /** 是否等待服务器信息 */
  waitingForServerInfo: boolean;
  /** 远程控制是否启用 */
  remoteControlEnabled: boolean;
  /** 是否正在连接 */
  isConnecting: boolean;
  /** 错误信息 */
  errorMessage: string;
  /** ⭐ 服务器IP地址输入 */
  serverIpInput: string;
}

/**
 * 设备验证结果
 */
export interface DeviceValidationResult {
  /** 是否有效 */
  valid: boolean;
  /** 错误信息 */
  message: string;
}

/**
 * ViewModel 依赖接口
 */
export interface IndexViewModelDependencies {
  remoteControlService: IRemoteControlService;
  appStateManager: IAppStateManager;
  clipboardService: IClipboardService;
}

/**
 * 导航回调参数接口
 */
interface NavigationParams {
  deviceId?: string;
  password?: string;
}

/**
 * Index 页面 ViewModel
 */
export class IndexViewModel {
  // 依赖注入
  private remoteControlService: IRemoteControlService;
  private appStateManager: IAppStateManager;
  private clipboardService: IClipboardService;

  // 状态
  private state: IndexPageState = {
    userId: '',
    userPassword: '',
    deviceIdInput: '',
    devicePasswordInput: '',
    waitingForServerInfo: true,
    remoteControlEnabled: true,
    isConnecting: false,
    errorMessage: '',
    serverIpInput: ''  // ⭐ 服务器IP输入
  };

  // 状态变更监听器
  private stateListeners: Set<(state: IndexPageState) => void> = new Set();

  // 导航回调
  private navigationCallback: ((url: string, params?: NavigationParams) => void) | null = null;

  // Toast 回调
  private toastCallback: ((message: string, duration?: number) => void) | null = null;

  constructor(dependencies: IndexViewModelDependencies) {
    this.remoteControlService = dependencies.remoteControlService;
    this.appStateManager = dependencies.appStateManager;
    this.clipboardService = dependencies.clipboardService;

    this.init();
  }

  /**
   * 初始化
   */
  private init(): void {
    hilog.info(DOMAIN, TAG, '=== IndexViewModel.init 开始 ===');
    
    // 设置设备信息回调
    this.remoteControlService.setDeviceInfoCallback((deviceCode: string, password: string) => {
      hilog.info(DOMAIN, TAG, '📥 收到设备信息回调 - deviceCode: %{public}s', deviceCode);

      // 保存到状态管理器
      this.appStateManager.setUserId(deviceCode);
      this.appStateManager.setUserPassword(password);
      
      hilog.info(DOMAIN, TAG, '✅ 已保存到 AppStateManager');

      // 更新状态
      this.updateState({
        userId: deviceCode,
        userPassword: password,
        waitingForServerInfo: false
      });
      
      hilog.info(DOMAIN, TAG, '✅ 已更新 ViewModel 状态');

      // 显示提示
      this.showToast('设备信息已获取', 2000);
    });

    // ⭐ 关键修复：先从 RemoteControlService 获取已保存的设备信息
    const localInfo = this.remoteControlService.getLocalDeviceInfo();
    hilog.info(DOMAIN, TAG, '📖 从 RemoteControlService 读取 - deviceCode: %{public}s', 
      localInfo.deviceCode ? '(有值)' : '(空)');
    
    // 如果已经有设备信息，直接使用
    if (localInfo.deviceCode && localInfo.deviceCode.length > 0) {
      hilog.info(DOMAIN, TAG, '✅ 使用已保存的设备信息');
      
      // 保存到 AppStateManager
      this.appStateManager.setUserId(localInfo.deviceCode);
      this.appStateManager.setUserPassword(localInfo.password);
      
      this.updateState({
        userId: localInfo.deviceCode,
        userPassword: localInfo.password,
        waitingForServerInfo: false
      });
    } else {
      // 否则从 AppStateManager 读取（持久化存储）
      const userId = this.appStateManager.getUserId();
      const userPassword = this.appStateManager.getUserPassword();
      
      hilog.info(DOMAIN, TAG, '📖 从 AppStateManager 读取 - userId: %{public}s', 
        userId ? '(有值)' : '(空)');

      this.updateState({
        userId: userId,
        userPassword: userPassword,
        waitingForServerInfo: !userId
      });
    }
    
    hilog.info(DOMAIN, TAG, '=== IndexViewModel.init 完成 ===');
  }

  /**
   * 初始化（供页面调用）
   */
  initialize(): void {
    // 初始化逻辑已在构造函数中完成
    // 此方法供页面在 aboutToAppear 中调用
    hilog.info(DOMAIN, TAG, 'Initialize called');
  }

  /**
   * 设置设备ID输入
   * @param value 设备ID
   */
  setDeviceIdInput(value: string): void {
    this.updateState({ deviceIdInput: value });
  }

  /**
   * 设置密码输入
   * @param value 密码
   */
  setPasswordInput(value: string): void {
    this.updateState({ devicePasswordInput: value });
  }

  /**
   * 连接到远程设备
   * @returns Promise<boolean> 是否连接成功
   */
  async connectToDevice(): Promise<boolean> {
    const deviceIdInput = this.state.deviceIdInput;
    const devicePasswordInput = this.state.devicePasswordInput;

    if (!deviceIdInput || !devicePasswordInput) {
      this.showToast('请输入设备ID和密码', 2000);
      return false;
    }

    // 防重复点击
    if (this.state.isConnecting) {
      return false;
    }

    try {
      this.updateState({ isConnecting: true, errorMessage: '' });
      this.showToast('正在验证设备信息...', 2000);

      // 验证设备
      const validationResult = await this.validateDevice(deviceIdInput, devicePasswordInput);

      if (!validationResult.valid) {
        this.updateState({ isConnecting: false });
        this.showToast(validationResult.message, 3000);
        return false;
      }

      // 设置设备信息
      this.remoteControlService.setDeviceInfo(deviceIdInput, devicePasswordInput);

      // 导航到控制页面
      if (this.navigationCallback) {
        this.navigationCallback('pages/Control', {
          deviceId: deviceIdInput,
          password: devicePasswordInput
        });
      }

      this.updateState({ isConnecting: false });
      return true;

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Connection failed: %{public}s', error instanceof Error ? error.message : String(error));
      this.updateState({
        isConnecting: false,
        errorMessage: String(error)
      });
      this.showToast('连接失败，请检查设备ID和密码', 3000);
      return false;
    }
  }

  /**
   * 验证设备
   * @param deviceId 设备ID
   * @param password 密码
   * @returns Promise<DeviceValidationResult>
   */
  private async validateDevice(deviceId: string, password: string): Promise<DeviceValidationResult> {
    try {
      const result = await this.remoteControlService.validateDevice(deviceId, password);
      return result;
    } catch (error) {
      return {
        valid: false,
        message: '验证失败: ' + String(error)
      };
    }
  }

  /**
   * 复制设备ID
   */
  copyDeviceId(): void {
    const userId = this.state.userId;
    if (!userId) {
      this.showToast('设备ID未获取', 2000);
      return;
    }

    this.clipboardService.copyToClipboard(userId);
    this.showToast('设备ID已复制', 2000);
  }

  /**
   * 复制密码
   */
  copyPassword(): void {
    const userPassword = this.state.userPassword;
    if (!userPassword) {
      this.showToast('密码未获取', 2000);
      return;
    }

    this.clipboardService.copyToClipboard(userPassword);
    this.showToast('密码已复制', 2000);
  }

  /**
   * 复制所有设备信息
   */
  copyAllDeviceInfo(): void {
    const userId = this.state.userId;
    const userPassword = this.state.userPassword;

    if (!userId || !userPassword) {
      this.showToast('设备信息未获取，无法复制', 2000);
      return;
    }

    const info = `设备ID: ${userId}\n连接密码: ${userPassword}`;
    this.clipboardService.copyToClipboard(info);
    this.showToast('设备信息已复制到剪贴板', 2000);
  }

  /**
   * 设置远程控制权限
   * @param enabled 是否启用
   */
  setRemoteControlEnabled(enabled: boolean): void {
    this.updateState({ remoteControlEnabled: enabled });
    this.remoteControlService.setRemoteControlPermission(enabled);
    this.showToast(enabled ? '远程控制已开启' : '远程控制已关闭', 2000);
  }

  /**
   * 设置导航回调
   * @param callback 回调函数
   */
  setNavigationCallback(callback: (url: string, params?: NavigationParams) => void): void {
    this.navigationCallback = callback;
  }

  /**
   * 设置 Toast 回调
   * @param callback 回调函数
   */
  setToastCallback(callback: (message: string, duration?: number) => void): void {
    this.toastCallback = callback;
  }

  /**
   * 复制状态对象
   */
  private copyState(state: IndexPageState): IndexPageState {
    return {
      userId: state.userId,
      userPassword: state.userPassword,
      deviceIdInput: state.deviceIdInput,
      devicePasswordInput: state.devicePasswordInput,
      waitingForServerInfo: state.waitingForServerInfo,
      remoteControlEnabled: state.remoteControlEnabled,
      isConnecting: state.isConnecting,
      errorMessage: state.errorMessage,
      serverIpInput: state.serverIpInput  // ⭐
    };
  }

  /**
   * 订阅状态变化
   * @param callback 回调函数
   * @returns 取消订阅函数
   */
  subscribe(callback: (state: IndexPageState) => void): () => void {
    this.stateListeners.add(callback);
    // 立即通知当前状态
    callback(this.copyState(this.state));

    return () => {
      this.stateListeners.delete(callback);
    };
  }

  /**
   * 显示 Toast
   * @param message 消息
   * @param duration 持续时间
   */
  private showToast(message: string, duration: number = 2000): void {
    if (this.toastCallback) {
      this.toastCallback(message, duration);
    }
  }

  /**
   * 获取当前状态
   */
  getState(): IndexPageState {
    return this.copyState(this.state);
  }

  /**
   * 更新状态
   */
  private updateState(partialState: Partial<IndexPageState>): void {
    const newState = this.copyState(this.state);
    if (partialState.userId !== undefined) newState.userId = partialState.userId;
    if (partialState.userPassword !== undefined) newState.userPassword = partialState.userPassword;
    if (partialState.deviceIdInput !== undefined) newState.deviceIdInput = partialState.deviceIdInput;
    if (partialState.devicePasswordInput !== undefined) newState.devicePasswordInput = partialState.devicePasswordInput;
    if (partialState.waitingForServerInfo !== undefined) newState.waitingForServerInfo = partialState.waitingForServerInfo;
    if (partialState.remoteControlEnabled !== undefined) newState.remoteControlEnabled = partialState.remoteControlEnabled;
    if (partialState.isConnecting !== undefined) newState.isConnecting = partialState.isConnecting;
    if (partialState.errorMessage !== undefined) newState.errorMessage = partialState.errorMessage;
    if (partialState.serverIpInput !== undefined) newState.serverIpInput = partialState.serverIpInput;  // ⭐
    this.state = newState;
    this.notifyStateChange();
  }

  /**
   * 通知状态变更
   */
  private notifyStateChange(): void {
    this.stateListeners.forEach((callback) => {
      try {
        callback(this.copyState(this.state));
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'State listener error: %{public}s', error instanceof Error ? error.message : String(error));
      }
    });
  }

  /**
   * ⭐ 更新服务器IP地址
   */
  updateServerIp(ip: string): void {
    hilog.info(DOMAIN, TAG, '更新服务器IP: %{public}s', ip);
    this.updateState({ serverIpInput: ip });
  }

  /**
   * ⭐ 使用新的服务器IP重新连接
   */
  async reconnectWithNewServerIp(): Promise<void> {
    const ip = this.state.serverIpInput.trim();
    
    if (!ip) {
      this.showToast('请输入服务器IP地址');
      return;
    }
    
    // 验证IP格式（简单验证）
    const ipRegex = /^(\d{1,3}\.){3}\d{1,3}$/;
    if (!ipRegex.test(ip)) {
      this.showToast('IP地址格式不正确');
      return;
    }
    
    hilog.info(DOMAIN, TAG, '开始重新连接，新服务器IP: %{public}s', ip);
    this.showToast('正在重新连接...');
    
    try {
      this.updateState({
        waitingForServerInfo: true,
        userId: '',
        userPassword: ''
      });
      
      const configCenter = ConfigCenter.getInstance();
      configCenter.updateServerHost(ip);
      hilog.info(DOMAIN, TAG, '已更新 ConfigCenter 服务器IP配置');
      
      const tcpPort = configCenter.getServerConfig().tcpPort;
      this.remoteControlService.updateConnectionTarget(ip, tcpPort);
      hilog.info(DOMAIN, TAG, '已更新 ConnectionManager 连接目标');
      
      await this.remoteControlService.disconnect();
      
      // 等待一下确保完全断开
      await new Promise<void>(resolve => setTimeout(resolve, 500));
      
      // 重新连接（会使用更新后的配置）
      await this.remoteControlService.connect(
        () => {
          hilog.info(DOMAIN, TAG, '重新连接成功');
          this.showToast('重新连接成功');
        },
        (error: string) => {
          hilog.error(DOMAIN, TAG, '重新连接失败: %{public}s', error);
          this.showToast('重新连接失败: ' + error);
        }
      );
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      hilog.error(DOMAIN, TAG, '重新连接异常: %{public}s', errorMessage);
      this.showToast('重新连接失败: ' + errorMessage);
    }
  }

  /**
   * 销毁（供页面调用）
   */
  dispose(): void {
    this.stateListeners.clear();
    this.navigationCallback = null;
    this.toastCallback = null;
    hilog.info(DOMAIN, TAG, 'Disposed');
  }
}
