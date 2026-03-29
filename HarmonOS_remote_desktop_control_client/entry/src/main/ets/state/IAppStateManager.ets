// IAppStateManager.ets - 应用状态管理器接口
// 定义应用状态管理的契约，便于解耦和测试

// AppState 类型定义
type AppStateType = number;

/**
 * 设备信息接口
 */
export interface DeviceInfo {
  deviceId: string;
  deviceName: string;
  deviceType: string;
}

/**
 * 连接配置接口
 */
export interface ConnectionConfig {
  serverUrl: string;
  port: number;
  autoReconnect: boolean;
  reconnectInterval: number;
}

/**
 * 应用状态管理器接口
 * 定义应用全局状态的管理契约
 */
export interface IAppStateManager {
  // ========== 用户认证状态 ==========
  
  /**
   * 获取用户ID
   */
  getUserId(): string;
  
  /**
   * 设置用户ID
   */
  setUserId(userId: string): void;
  
  /**
   * 获取用户密码
   */
  getUserPassword(): string;
  
  /**
   * 设置用户密码
   */
  setUserPassword(password: string): void;
  
  /**
   * 清除用户认证信息
   */
  clearUserAuth(): void;
  
  // ========== 设备信息 ==========
  
  /**
   * 获取设备信息
   */
  getDeviceInfo(): DeviceInfo | null;
  
  /**
   * 设置设备信息
   */
  setDeviceInfo(deviceInfo: DeviceInfo): void;
  
  // ========== 远程控制状态 ==========
  
  /**
   * 是否启用远程控制
   */
  isRemoteControlEnabled(): boolean;
  
  /**
   * 设置远程控制启用状态
   */
  setRemoteControlEnabled(enabled: boolean): void;
  
  /**
   * 获取当前应用状态
   */
  getCurrentState(): AppStateType;

  /**
   * 设置当前应用状态
   */
  setCurrentState(state: AppStateType): void;
  
  // ========== 连接配置 ==========
  
  /**
   * 获取连接配置
   */
  getConnectionConfig(): ConnectionConfig;
  
  /**
   * 设置连接配置
   */
  setConnectionConfig(config: Partial<ConnectionConfig>): void;
  
  // ========== 订阅模式 ==========
  
  /**
   * 订阅状态变化
   * @param callback 状态变化回调
   * @returns 取消订阅函数
   */
  subscribe(callback: (state: AppStateType, data?: Record<string, string | number | boolean | ArrayBuffer | string[] | undefined>) => void): () => void;

  /**
   * 通知状态变化
   */
  notifyStateChange(state: AppStateType, data?: Record<string, string | number | boolean | ArrayBuffer | string[] | undefined>): void;
}
