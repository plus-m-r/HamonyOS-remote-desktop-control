// MockAppStateManager.ets - 应用状态管理器的 Mock 实现
// 用于单元测试，无需依赖真实的状态管理

import { IAppStateManager, DeviceInfo, ConnectionConfig } from '../main/ets/state/IAppStateManager';
import { AppState } from '../main/ets/state/AppStateManager';

/**
 * Mock 应用状态管理器
 * 实现 IAppStateManager 接口，用于测试
 */
export class MockAppStateManager implements IAppStateManager {
  private userId: string = '';
  private userPassword: string = '';
  private deviceInfo: DeviceInfo | null = null;
  private remoteControlEnabled: boolean = true;
  private currentState: AppState = AppState.DISCONNECTED;
  private connectionConfig: ConnectionConfig = {
    serverUrl: 'ws://localhost:8080',
    port: 8080,
    autoReconnect: true,
    reconnectInterval: 5000
  };
  
  private subscribers: Array&lt;(state: AppState, data?: Record&lt;string, unknown&gt;) =&gt; void&gt; = [];
  
  // ========== 用户认证状态 ==========
  
  getUserId(): string {
    return this.userId;
  }
  
  setUserId(userId: string): void {
    this.userId = userId;
  }
  
  getUserPassword(): string {
    return this.userPassword;
  }
  
  setUserPassword(password: string): void {
    this.userPassword = password;
  }
  
  clearUserAuth(): void {
    this.userId = '';
    this.userPassword = '';
  }
  
  // ========== 设备信息 ==========
  
  getDeviceInfo(): DeviceInfo | null {
    return this.deviceInfo;
  }
  
  setDeviceInfo(deviceInfo: DeviceInfo): void {
    this.deviceInfo = deviceInfo;
  }
  
  // ========== 远程控制状态 ==========
  
  isRemoteControlEnabled(): boolean {
    return this.remoteControlEnabled;
  }
  
  setRemoteControlEnabled(enabled: boolean): void {
    this.remoteControlEnabled = enabled;
  }
  
  getCurrentState(): AppState {
    return this.currentState;
  }
  
  setCurrentState(state: AppState): void {
    this.currentState = state;
    this.notifyStateChange(state);
  }
  
  // ========== 连接配置 ==========
  
  getConnectionConfig(): ConnectionConfig {
    return { ...this.connectionConfig };
  }
  
  setConnectionConfig(config: Partial&lt;ConnectionConfig&gt;): void {
    this.connectionConfig = { ...this.connectionConfig, ...config };
  }
  
  // ========== 订阅模式 ==========
  
  subscribe(callback: (state: AppState, data?: Record&lt;string, unknown&gt;) =&gt; void): () =&gt; void {
    this.subscribers.push(callback);
    
    // 返回取消订阅函数
    return () =&gt; {
      const index = this.subscribers.indexOf(callback);
      if (index &gt; -1) {
        this.subscribers.splice(index, 1);
      }
    };
  }
  
  notifyStateChange(state: AppState, data?: Record&lt;string, unknown&gt;): void {
    this.subscribers.forEach(callback =&gt; {
      try {
        callback(state, data);
      } catch (error) {
        console.error('MockAppStateManager: 订阅者回调失败', error);
      }
    });
  }
  
  // ========== Mock 专用方法 ==========
  
  /**
   * 重置所有状态
   */
  reset(): void {
    this.userId = '';
    this.userPassword = '';
    this.deviceInfo = null;
    this.remoteControlEnabled = true;
    this.currentState = AppState.DISCONNECTED;
    this.connectionConfig = {
      serverUrl: 'ws://localhost:8080',
      port: 8080,
      autoReconnect: true,
      reconnectInterval: 5000
    };
    this.subscribers = [];
  }
  
  /**
   * 设置模拟的设备信息
   */
  mockDeviceInfo(deviceId: string, deviceName: string = 'Mock Device', deviceType: string = 'Phone'): void {
    this.deviceInfo = {
      deviceId,
      deviceName,
      deviceType
    };
  }
  
  /**
   * 模拟状态变化
   */
  simulateStateChange(state: AppState, data?: Record&lt;string, unknown&gt;): void {
    this.currentState = state;
    this.notifyStateChange(state, data);
  }
}
