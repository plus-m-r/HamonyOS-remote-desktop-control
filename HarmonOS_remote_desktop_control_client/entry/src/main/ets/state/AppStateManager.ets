/**
 * 应用状态管理器（解耦版本）
 *
 * 改进点：
 * 1. 使用接口抽象状态存储，不直接依赖 AppStorage
 * 2. 通过构造函数注入状态存储实现，便于 Mock 测试
 * 3. 类型安全的状态访问
 * 4. 支持状态变更监听
 */

import { ScreenImage } from '../models/DeviceInfo';
import { IAppStateManager, DeviceInfo, ConnectionConfig } from './IAppStateManager';

// 同步设置键
const SYNC_SETTINGS_KEY = 'syncSettings';

/**
 * 同步设置接口
 */
export interface SyncSettings {
  // 文件传输
  autoUploadFiles: boolean;      // 自动上传拖拽文件
  showFileProgress: boolean;     // 显示文件传输进度
  
  // 剪贴板同步
  autoSyncClipboard: boolean;    // 自动同步剪贴板
  syncInterval: number;          // 同步间隔（毫秒）
  syncTextOnly: boolean;         // 仅同步文本（不包含文件）
  
  // 通知设置
  showTransferNotifications: boolean;    // 显示传输通知
  showClipboardNotifications: boolean;   // 显示剪贴板通知
}

/**
 * 状态存储接口
 */
export interface IStateStorage {
  get<T>(key: string): T | undefined;
  set<T>(key: string, value: T): void;
  remove(key: string): void;
  clear(): void;
}

/**
 * 状态数据类型
 */
export type StateData = string | number | boolean | ArrayBuffer | string[] | undefined;

/**
 * 状态变更监听器
 */
export type StateChangeListener = (newValue: StateData, oldValue: StateData | undefined) => void;

/**
 * 应用状态键
 */
export enum AppStateKey {
  USER_ID = 'userId',
  USER_PASSWORD = 'userPassword',
  REMOTE_DEVICE_ID = 'remoteDeviceId',
  REMOTE_DEVICE_PASSWORD = 'remoteDevicePassword',
  CONNECTION_STATUS = 'connectionStatus',
  SCREEN_DATA = 'screenData',
  SCREEN_WIDTH = 'screenWidth',
  SCREEN_HEIGHT = 'screenHeight',
  SCREEN_TIMESTAMP = 'screenTimestamp',
  CLIPBOARD_TEXT = 'clipboardText',
  CLIPBOARD_FILES = 'clipboardFiles'
}

/**
 * 连接状态
 */
export enum ConnectionStatus {
  DISCONNECTED = 'DISCONNECTED',
  CONNECTING = 'CONNECTING',
  CONNECTED = 'CONNECTED',
  ERROR = 'ERROR'
}

/**
 * 解耦的应用状态管理器
 */
export class AppStateManager implements IAppStateManager {
  protected storage: IStateStorage;
  private listeners: Map<string, Set<StateChangeListener>> = new Map();
  private stateSubscribers: Array<(state: number, data?: Record<string, StateData>) => void> = [];
  private currentState: number = 0; // DISCONNECTED

  constructor(storage: IStateStorage) {
    this.storage = storage;
    console.info('AppStateManager: Initialized with injected storage');
  }

  // ========== 用户相关状态 ==========

  /**
   * 获取用户ID
   */
  getUserId(): string {
    return this.storage.get<string>(AppStateKey.USER_ID) || '';
  }

  /**
   * 设置用户ID
   */
  setUserId(userId: string): void {
    const oldValue = this.getUserId();
    this.storage.set(AppStateKey.USER_ID, userId);
    this.notifyListeners(AppStateKey.USER_ID, userId as StateData, oldValue as StateData);
  }

  /**
   * 获取用户密码
   */
  getUserPassword(): string {
    return this.storage.get<string>(AppStateKey.USER_PASSWORD) || '';
  }

  /**
   * 设置用户密码
   */
  setUserPassword(password: string): void {
    const oldValue = this.getUserPassword();
    this.storage.set(AppStateKey.USER_PASSWORD, password);
    this.notifyListeners(AppStateKey.USER_PASSWORD, password as StateData, oldValue as StateData);
  }

  // ========== 远程设备相关状态 ==========

  /**
   * 获取远程设备ID
   */
  getRemoteDeviceId(): string {
    return this.storage.get<string>(AppStateKey.REMOTE_DEVICE_ID) || '';
  }

  /**
   * 设置远程设备ID
   */
  setRemoteDeviceId(deviceId: string): void {
    const oldValue = this.getRemoteDeviceId();
    this.storage.set(AppStateKey.REMOTE_DEVICE_ID, deviceId);
    this.notifyListeners(AppStateKey.REMOTE_DEVICE_ID, deviceId as StateData, oldValue as StateData);
  }

  /**
   * 获取远程设备密码
   */
  getRemoteDevicePassword(): string {
    return this.storage.get<string>(AppStateKey.REMOTE_DEVICE_PASSWORD) || '';
  }

  /**
   * 设置远程设备密码
   */
  setRemoteDevicePassword(password: string): void {
    const oldValue = this.getRemoteDevicePassword();
    this.storage.set(AppStateKey.REMOTE_DEVICE_PASSWORD, password);
    this.notifyListeners(AppStateKey.REMOTE_DEVICE_PASSWORD, password as StateData, oldValue as StateData);
  }

  // ========== 连接状态 ==========

  /**
   * 获取连接状态
   */
  getConnectionStatus(): ConnectionStatus {
    return this.storage.get<ConnectionStatus>(AppStateKey.CONNECTION_STATUS) || ConnectionStatus.DISCONNECTED;
  }

  /**
   * 设置连接状态
   */
  setConnectionStatus(status: ConnectionStatus): void {
    const oldValue = this.getConnectionStatus();
    this.storage.set(AppStateKey.CONNECTION_STATUS, status);
    this.notifyListeners(AppStateKey.CONNECTION_STATUS, status as StateData, oldValue as StateData);
  }

  // ========== 屏幕数据状态 ==========

  /**
   * 获取屏幕数据
   */
  getScreenData(): ScreenImage | null {
    const data = this.storage.get<ArrayBuffer>(AppStateKey.SCREEN_DATA);
    const width = this.storage.get<number>(AppStateKey.SCREEN_WIDTH) || 0;
    const height = this.storage.get<number>(AppStateKey.SCREEN_HEIGHT) || 0;
    const timestamp = this.storage.get<number>(AppStateKey.SCREEN_TIMESTAMP) || 0;

    if (!data) {
      return null;
    }

    return new ScreenImage(data, width, height, timestamp);
  }

  /**
   * 设置屏幕数据
   */
  setScreenData(data: ArrayBuffer, width: number, height: number, timestamp: number): void {
    this.storage.set(AppStateKey.SCREEN_DATA, data);
    this.storage.set(AppStateKey.SCREEN_WIDTH, width);
    this.storage.set(AppStateKey.SCREEN_HEIGHT, height);
    this.storage.set(AppStateKey.SCREEN_TIMESTAMP, timestamp);

    this.notifyListeners(AppStateKey.SCREEN_DATA, data as StateData, undefined);
  }

  /**
   * 清除屏幕数据
   */
  clearScreenData(): void {
    this.storage.remove(AppStateKey.SCREEN_DATA);
    this.storage.remove(AppStateKey.SCREEN_WIDTH);
    this.storage.remove(AppStateKey.SCREEN_HEIGHT);
    this.storage.remove(AppStateKey.SCREEN_TIMESTAMP);
  }

  // ========== 剪贴板状态 ==========

  /**
   * 获取剪贴板文本
   */
  getClipboardText(): string {
    return this.storage.get<string>(AppStateKey.CLIPBOARD_TEXT) || '';
  }

  /**
   * 设置剪贴板文本
   */
  setClipboardText(text: string): void {
    const oldValue = this.getClipboardText();
    this.storage.set(AppStateKey.CLIPBOARD_TEXT, text);
    this.notifyListeners(AppStateKey.CLIPBOARD_TEXT, text as StateData, oldValue as StateData);
  }

  /**
   * 获取剪贴板文件列表
   */
  getClipboardFiles(): string[] {
    return this.storage.get<string[]>(AppStateKey.CLIPBOARD_FILES) || [];
  }

  /**
   * 设置剪贴板文件列表
   */
  setClipboardFiles(files: string[]): void {
    const oldValue = this.getClipboardFiles();
    this.storage.set(AppStateKey.CLIPBOARD_FILES, files);
    this.notifyListeners(AppStateKey.CLIPBOARD_FILES, files as StateData, oldValue as StateData);
  }

  // ========== 监听器管理 ==========

  /**
   * 添加状态变更监听器
   * @param key 状态键
   * @param listener 监听器
   */
  addListener(key: string, listener: StateChangeListener): void {
    if (!this.listeners.has(key)) {
      this.listeners.set(key, new Set());
    }
    this.listeners.get(key)!.add(listener);
  }

  /**
   * 移除状态变更监听器
   * @param key 状态键
   * @param listener 监听器
   */
  removeListener(key: string, listener: StateChangeListener): void {
    const keyListeners = this.listeners.get(key);
    if (keyListeners) {
      keyListeners.delete(listener);
    }
  }

  /**
   * 通知监听器
   */
  private notifyListeners(key: string, newValue: StateData, oldValue: StateData | undefined): void {
    const keyListeners = this.listeners.get(key);
    if (keyListeners) {
      keyListeners.forEach(listener => {
        try {
          listener(newValue, oldValue);
        } catch (error) {
          console.error(`AppStateManager: Listener error for ${key}`, error);
        }
      });
    }
  }

  // ========== IAppStateManager 接口实现 ==========

  /**
   * 清除用户认证信息
   */
  clearUserAuth(): void {
    this.storage.remove(AppStateKey.USER_ID);
    this.storage.remove(AppStateKey.USER_PASSWORD);
    console.info('AppStateManager: User auth cleared');
  }

  /**
   * 获取设备信息
   */
  getDeviceInfo(): DeviceInfo | null {
    const deviceId = this.getUserId();
    if (!deviceId) {
      return null;
    }
    return {
      deviceId: deviceId,
      deviceName: 'Remote Device',
      deviceType: 'HarmonyOS'
    };
  }

  /**
   * 设置设备信息
   */
  setDeviceInfo(deviceInfo: DeviceInfo): void {
    this.setUserId(deviceInfo.deviceId);
    console.info('AppStateManager: Device info set');
  }

  /**
   * 是否启用远程控制
   */
  isRemoteControlEnabled(): boolean {
    return this.storage.get<boolean>('remoteControlEnabled') ?? true;
  }

  /**
   * 设置远程控制启用状态
   */
  setRemoteControlEnabled(enabled: boolean): void {
    this.storage.set('remoteControlEnabled', enabled);
    console.info('AppStateManager: Remote control enabled set to', enabled);
  }

  /**
   * 获取当前应用状态
   */
  getCurrentState(): number {
    return this.currentState;
  }

  /**
   * 设置当前应用状态
   */
  setCurrentState(state: number): void {
    this.currentState = state;
    this.notifyStateChange(state);
  }

  /**
   * 获取连接配置
   */
  getConnectionConfig(): ConnectionConfig {
    return this.storage.get<ConnectionConfig>('connectionConfig') || {
      serverUrl: 'localhost',
      port: 8080,
      autoReconnect: true,
      reconnectInterval: 5000
    };
  }

  /**
   * 设置连接配置
   */
  setConnectionConfig(config: Partial<ConnectionConfig>): void {
    const currentConfig = this.getConnectionConfig();
    const newConfig: ConnectionConfig = {
      serverUrl: config.serverUrl || currentConfig.serverUrl,
      port: config.port || currentConfig.port,
      autoReconnect: config.autoReconnect !== undefined ? config.autoReconnect : currentConfig.autoReconnect,
      reconnectInterval: config.reconnectInterval || currentConfig.reconnectInterval
    };
    this.storage.set('connectionConfig', newConfig);
    console.info('AppStateManager: Connection config updated');
  }

  /**
   * 订阅状态变化
   */
  subscribe(callback: (state: number, data?: Record<string, StateData>) => void): () => void {
    this.stateSubscribers.push(callback);
    return () => {
      const index = this.stateSubscribers.indexOf(callback);
      if (index > -1) {
        this.stateSubscribers.splice(index, 1);
      }
    };
  }

  /**
   * 通知状态变化
   */
  notifyStateChange(state: number, data?: Record<string, StateData>): void {
    this.stateSubscribers.forEach(callback => {
      try {
        callback(state, data);
      } catch (error) {
        console.error('AppStateManager: Error notifying subscriber', error);
      }
    });
  }

  // ========== 工具方法 ==========

  /**
   * 清除所有状态
   */
  clearAll(): void {
    this.storage.clear();
    console.info('AppStateManager: All states cleared');
  }

  /**
   * 获取所有状态（用于调试）
   */
  getAllStates(): Record<string, StateData> {
    const states: Record<string, StateData> = {};

    Object.values(AppStateKey).forEach(key => {
      states[key] = this.storage.get<StateData>(key);
    });

    return states;
  }

  /**
   * 获取同步设置
   */
  getSyncSettings(): SyncSettings | undefined {
    return this.storage.get<SyncSettings>(SYNC_SETTINGS_KEY);
  }

  /**
   * 设置同步设置
   */
  setSyncSettings(settings: SyncSettings): void {
    this.storage.set(SYNC_SETTINGS_KEY, settings);
  }
}

/**
 * AppStorage 实现（暂时注释，使用MemoryStorageImpl）
 */
/*
export class AppStorageImpl implements IStateStorage {
  get<T>(key: string): T | undefined {
    return AppStorageV2.get(key) as T | undefined;
  }

  set<T>(key: string, value: T): void {
    AppStorageV2.set(key, value);
  }

  remove(key: string): void {
    AppStorageV2.delete(key);
  }

  clear(): void {
    // AppStorageV2 不支持直接清空，需要逐个删除
    Object.values(AppStateKey).forEach(key => {
      AppStorageV2.delete(key);
    });
  }
}
*/

/**
 * 内存存储实现（用于测试环境）
 */
export class MemoryStorageImpl implements IStateStorage {
  private storage: Map<string, string | number | boolean | ArrayBuffer | undefined> = new Map();

  get<T>(key: string): T | undefined {
    return this.storage.get(key) as T | undefined;
  }

  set<T>(key: string, value: T): void {
    this.storage.set(key, value as string | number | boolean | ArrayBuffer | undefined);
  }

  remove(key: string): void {
    this.storage.delete(key);
  }

  clear(): void {
    this.storage.clear();
  }
}

// 应用状态枚举
export enum AppState {
  DISCONNECTED = 0,
  CONNECTING = 1,
  CONNECTED = 2,
  ERROR = 3
};

// 导出默认实例和静态方法
const appStateManager = new AppStateManager(new MemoryStorageImpl());

// 导出静态方法包装器
export function getSyncSettings(): SyncSettings | undefined {
  return appStateManager.getSyncSettings();
}

export function setSyncSettings(settings: SyncSettings): void {
  appStateManager.setSyncSettings(settings);
}

export function getAppStateManagerInstance(): AppStateManager {
  return appStateManager;
}

// 为了兼容Settings.ets中的调用，使用命名空间方式
export namespace AppStateManager {
  export function getSyncSettings(): SyncSettings | undefined {
    return appStateManager.getSyncSettings();
  }

  export function setSyncSettings(settings: SyncSettings): void {
    appStateManager.setSyncSettings(settings);
  }

  export function getInstance(): AppStateManager {
    return appStateManager;
  }
}

export { appStateManager };
