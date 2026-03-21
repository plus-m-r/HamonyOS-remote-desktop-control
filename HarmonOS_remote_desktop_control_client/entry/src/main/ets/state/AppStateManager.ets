// entry/src/main/ets/state/AppStateManager.ets
import { DeviceInfo } from '../models/DeviceInfo';
import { SyncSettings } from '../pages/Settings';

/**
 * 状态键接口
 */
export interface StateKeys {
  CONNECTION_STATE: string;
  IS_CONNECTED: string;
  CURRENT_DEVICE: string;
  DEVICE_LIST: string;
  SELECTED_DEVICE_CODE: string;
  SYNC_SETTINGS: string;
  USER_ID: string;
  USER_PASSWORD: string;
  DEVICE_ID_INPUT: string;
  SCREEN_DATA: string;
  SCREEN_WIDTH: string;
  SCREEN_HEIGHT: string;
  SCREEN_TIMESTAMP: string;
  ACTIVE_NAV_ITEM: string;
  IS_LOADING: string;
  UPLOAD_PROGRESS: string;
  DOWNLOAD_PROGRESS: string;
  ERROR_MESSAGE: string;
  REMOTE_CONTROL_ENABLED: string;
}

/**
 * 状态键类
 */
export class StateKeysImpl implements StateKeys {
  CONNECTION_STATE: string = 'connectionState';
  IS_CONNECTED: string = 'isConnected';
  CURRENT_DEVICE: string = 'currentDevice';
  DEVICE_LIST: string = 'deviceList';
  SELECTED_DEVICE_CODE: string = 'selectedDeviceCode';
  USER_ID: string = 'userId';
  USER_PASSWORD: string = 'userPassword';
  DEVICE_ID_INPUT: string = 'deviceIdInput';
  SCREEN_DATA: string = 'screenData';
  SCREEN_WIDTH: string = 'screenWidth';
  SCREEN_HEIGHT: string = 'screenHeight';
  SCREEN_TIMESTAMP: string = 'screenTimestamp';
  ACTIVE_NAV_ITEM: string = 'activeNavItem';
  IS_LOADING: string = 'isLoading';
  UPLOAD_PROGRESS: string = 'uploadProgress';
  DOWNLOAD_PROGRESS: string = 'downloadProgress';
  ERROR_MESSAGE: string = 'errorMessage';
  SYNC_SETTINGS: string = 'syncSettings';
  REMOTE_CONTROL_ENABLED: string = 'remoteControlEnabled';
}

/**
 * 全局状态键实例
 */
export const STATE_KEYS: StateKeys = new StateKeysImpl();

/**
 * 应用状态枚举
 */
export enum AppState {
  DISCONNECTED = 'disconnected',
  CONNECTING = 'connecting',
  CONNECTED = 'connected',
  RECONNECTING = 'reconnecting',
  ERROR = 'error'
}

/**
 * 全局状态管理器
 * 使用 AppStorage 实现跨组件状态共享
 */
export class AppStateManager {
  /**
   * 初始化全局状态
   */
  static initialize(): void {
    // 连接状态
    AppStorage.setOrCreate<AppState>(STATE_KEYS.CONNECTION_STATE, AppState.DISCONNECTED);
    AppStorage.setOrCreate<boolean>(STATE_KEYS.IS_CONNECTED, false);
    AppStorage.setOrCreate<DeviceInfo | null>(STATE_KEYS.CURRENT_DEVICE, null);
    
    // 设备列表
    AppStorage.setOrCreate<Array<DeviceInfo>>(STATE_KEYS.DEVICE_LIST, []);
    AppStorage.setOrCreate<string>(STATE_KEYS.SELECTED_DEVICE_CODE, '');
    
    // 用户信息（初始为空，等待服务器分配）
    AppStorage.setOrCreate<string>(STATE_KEYS.USER_ID, '');
    AppStorage.setOrCreate<string>(STATE_KEYS.USER_PASSWORD, '');
    AppStorage.setOrCreate<string>(STATE_KEYS.DEVICE_ID_INPUT, '');
    
    // 屏幕数据 - 单独存储每个字段，避免结构类型问题
    AppStorage.setOrCreate<ArrayBuffer | null>(STATE_KEYS.SCREEN_DATA, null);
    AppStorage.setOrCreate<number>(STATE_KEYS.SCREEN_WIDTH, 0);
    AppStorage.setOrCreate<number>(STATE_KEYS.SCREEN_HEIGHT, 0);
    AppStorage.setOrCreate<number>(STATE_KEYS.SCREEN_TIMESTAMP, 0);
    
    // UI 状态
    AppStorage.setOrCreate<string>(STATE_KEYS.ACTIVE_NAV_ITEM, 'home');
    AppStorage.setOrCreate<boolean>(STATE_KEYS.IS_LOADING, false);
    
    // 文件传输
    AppStorage.setOrCreate<number>(STATE_KEYS.UPLOAD_PROGRESS, 0);
    AppStorage.setOrCreate<number>(STATE_KEYS.DOWNLOAD_PROGRESS, 0);
    
    // 错误信息
    AppStorage.setOrCreate<string>(STATE_KEYS.ERROR_MESSAGE, '');
    
    // 远程控制权限（默认允许，用户可关闭）
    AppStorage.setOrCreate<boolean>(STATE_KEYS.REMOTE_CONTROL_ENABLED, true);
    
    console.info('AppStateManager: Global state initialized');
  }

  // ============ 连接状态管理 ============

  static setConnectionState(state: AppState): void {
    AppStorage.set(STATE_KEYS.CONNECTION_STATE, state);
    AppStorage.set(STATE_KEYS.IS_CONNECTED, state === AppState.CONNECTED);
  }

  static getConnectionState(): AppState {
    return AppStorage.get(STATE_KEYS.CONNECTION_STATE) as AppState;
  }

  static isConnected(): boolean {
    return AppStorage.get(STATE_KEYS.IS_CONNECTED) as boolean;
  }

  // ============ 设备管理 ============

  static setDeviceList(devices: Array<DeviceInfo>): void {
    AppStorage.set(STATE_KEYS.DEVICE_LIST, devices);
  }

  static getDeviceList(): Array<DeviceInfo> {
    return AppStorage.get(STATE_KEYS.DEVICE_LIST) as Array<DeviceInfo>;
  }

  static selectDevice(deviceCode: string): void {
    AppStorage.set(STATE_KEYS.SELECTED_DEVICE_CODE, deviceCode);
    const devices = AppStateManager.getDeviceList();
    const device = devices.find(d => d.deviceCode === deviceCode);
    if (device) {
      AppStorage.set(STATE_KEYS.CURRENT_DEVICE, device);
    }
  }

  static getSelectedDeviceCode(): string {
    return AppStorage.get(STATE_KEYS.SELECTED_DEVICE_CODE) as string;
  }

  static getCurrentDevice(): DeviceInfo | null {
    return AppStorage.get(STATE_KEYS.CURRENT_DEVICE) as DeviceInfo | null;
  }

  // ============ 用户信息管理 ============

  static setUserId(userId: string): void {
    AppStorage.set(STATE_KEYS.USER_ID, userId);
  }

  static getUserId(): string {
    return AppStorage.get(STATE_KEYS.USER_ID) as string;
  }

  static setUserPassword(password: string): void {
    AppStorage.set(STATE_KEYS.USER_PASSWORD, password);
  }

  static getUserPassword(): string {
    return AppStorage.get(STATE_KEYS.USER_PASSWORD) as string;
  }

  static setDeviceIdInput(input: string): void {
    AppStorage.set(STATE_KEYS.DEVICE_ID_INPUT, input);
  }

  static getDeviceIdInput(): string {
    return AppStorage.get(STATE_KEYS.DEVICE_ID_INPUT) as string;
  }

  // ============ 屏幕数据管理 ============

  static setScreenData(data: ArrayBuffer, width: number, height: number, timestamp: number): void {
    AppStorage.set(STATE_KEYS.SCREEN_DATA, data);
    AppStorage.set(STATE_KEYS.SCREEN_WIDTH, width);
    AppStorage.set(STATE_KEYS.SCREEN_HEIGHT, height);
    AppStorage.set(STATE_KEYS.SCREEN_TIMESTAMP, timestamp);
  }

  static getScreenData(): ArrayBuffer | null {
    return AppStorage.get(STATE_KEYS.SCREEN_DATA) as ArrayBuffer | null;
  }

  static getScreenWidth(): number {
    return AppStorage.get(STATE_KEYS.SCREEN_WIDTH) as number;
  }

  static getScreenHeight(): number {
    return AppStorage.get(STATE_KEYS.SCREEN_HEIGHT) as number;
  }

  static getScreenTimestamp(): number {
    return AppStorage.get(STATE_KEYS.SCREEN_TIMESTAMP) as number;
  }

  // ============ UI 状态管理 ============

  static setActiveNavItem(item: string): void {
    AppStorage.set(STATE_KEYS.ACTIVE_NAV_ITEM, item);
  }

  static getActiveNavItem(): string {
    return AppStorage.get(STATE_KEYS.ACTIVE_NAV_ITEM) as string;
  }

  static setScreenWidth(width: number): void {
    AppStorage.set(STATE_KEYS.SCREEN_WIDTH, width);
  }
  static setLoading(loading: boolean): void {
    AppStorage.set(STATE_KEYS.IS_LOADING, loading);
  }

  static isLoading(): boolean {
    return AppStorage.get(STATE_KEYS.IS_LOADING) as boolean;
  }

  // ============ 文件传输进度管理 ============

  static setUploadProgress(progress: number): void {
    AppStorage.set(STATE_KEYS.UPLOAD_PROGRESS, progress);
  }

  static getUploadProgress(): number {
    return AppStorage.get(STATE_KEYS.UPLOAD_PROGRESS) as number;
  }

  static setDownloadProgress(progress: number): void {
    AppStorage.set(STATE_KEYS.DOWNLOAD_PROGRESS, progress);
  }

  static getDownloadProgress(): number {
    return AppStorage.get(STATE_KEYS.DOWNLOAD_PROGRESS) as number;
  }

  // ============ 错误处理 ============

  static setErrorMessage(message: string): void {
    AppStorage.set(STATE_KEYS.ERROR_MESSAGE, message);
  }

  static getErrorMessage(): string {
    return AppStorage.get(STATE_KEYS.ERROR_MESSAGE) as string;
  }

  static clearError(): void {
    AppStorage.set(STATE_KEYS.ERROR_MESSAGE, '');
  }

  // ============ 远程控制权限管理 ============

  static setRemoteControlEnabled(enabled: boolean): void {
    AppStorage.set(STATE_KEYS.REMOTE_CONTROL_ENABLED, enabled);
    console.info(`AppStateManager: Remote control permission ${enabled ? 'enabled' : 'disabled'}`);
  }

  static isRemoteControlEnabled(): boolean {
    return AppStorage.get(STATE_KEYS.REMOTE_CONTROL_ENABLED) as boolean;
  }

  // ============ 同步设置管理 ============
  static setSyncSettings(settings: SyncSettings): void {
    AppStorage.set(STATE_KEYS.SYNC_SETTINGS, settings);
  }
  static getSyncSettings(): SyncSettings | null {
    const settings: SyncSettings | undefined = AppStorage.get<SyncSettings>(STATE_KEYS.SYNC_SETTINGS);
    return settings ?? null;
  }
}

/**
 * 设置服务器分配的设备信息
 */
export function setDeviceInfoFromServer(deviceCode: string, password: string): void {
  AppStorage.set(STATE_KEYS.USER_ID, deviceCode);
  AppStorage.set(STATE_KEYS.USER_PASSWORD, password);
  console.info(`AppStateManager: Device info set from server - ID: ${deviceCode}, Password: ${password}`);
}

/**
 * 更新用户密码（用户修改）
 */
export function updateUserPassword(newPassword: string): void {
  AppStorage.set(STATE_KEYS.USER_PASSWORD, newPassword);
  console.info('AppStateManager: Password updated by user');
}

/**
 * 状态观察者接口
 */
export interface StateObserver {
  onStateChanged(key: string, newValue: Object | null, oldValue: Object | null): void;
}