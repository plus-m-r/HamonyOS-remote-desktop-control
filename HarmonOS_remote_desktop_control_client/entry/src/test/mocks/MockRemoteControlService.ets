// MockRemoteControlService.ets - 远程控制服务的 Mock 实现
// 用于单元测试，无需依赖真实的网络连接

import { IRemoteControlService, DeviceCredentials, ScreenCallback, DeviceInfoCallback } from '../main/ets/services/interfaces/IRemoteControlService';
import { ConnectionState, RemoteControlEvent, DeviceValidationResult } from '../main/ets/models/DeviceInfo';
import { ClientInfoCallback, ConnectionCallback, ClipboardCallback } from '../main/ets/models/CmdProtocol';

/**
 * Mock 远程控制服务
 * 实现 IRemoteControlService 接口，用于测试
 */
export class MockRemoteControlService implements IRemoteControlService {
  private connectionState: ConnectionState = ConnectionState.DISCONNECTED;
  private localDeviceInfo: DeviceCredentials = { deviceCode: '', password: '' };
  private remoteDeviceInfo: DeviceCredentials = { deviceCode: '', password: '' };
  private remoteControlEnabled: boolean = false;
  
  // 回调
  private screenCallback: ScreenCallback | null = null;
  private deviceInfoCallback: DeviceInfoCallback | null = null;
  private connectionCallback: ConnectionCallback | null = null;
  private clipboardCallback: ClipboardCallback | null = null;
  
  // 调用记录（用于测试验证）
  public callHistory: Array&lt;{ method: string; args: unknown[] }&gt; = [];
  
  // Mock 验证结果
  private mockValidationResult: DeviceValidationResult = { valid: true, message: '' };

  constructor() {
    console.info('MockRemoteControlService: Created');
  }

  // ========== 连接管理 ==========

  async connect(onSuccess?: () =&gt; void, onError?: (error: string) =&gt; void): Promise&lt;void&gt; {
    this.recordCall('connect', [onSuccess, onError]);
    
    // 模拟连接成功
    this.connectionState = ConnectionState.CONNECTED;
    
    if (onSuccess) {
      onSuccess();
    }
    
    if (this.connectionCallback) {
      this.connectionCallback(true);
    }
  }

  async disconnect(): Promise&lt;void&gt; {
    this.recordCall('disconnect', []);
    
    this.connectionState = ConnectionState.DISCONNECTED;
    
    if (this.connectionCallback) {
      this.connectionCallback(false);
    }
  }

  getConnectionState(): ConnectionState {
    this.recordCall('getConnectionState', []);
    return this.connectionState;
  }

  setConnectionCallback(callback: ConnectionCallback): void {
    this.recordCall('setConnectionCallback', [callback]);
    this.connectionCallback = callback;
  }

  // ========== 远程屏幕控制 ==========

  async openRemoteScreen(deviceCode: string, password: string): Promise&lt;void&gt; {
    this.recordCall('openRemoteScreen', [deviceCode, password]);
    
    this.remoteDeviceInfo = { deviceCode, password };
    this.remoteControlEnabled = true;
    
    // 模拟发送屏幕数据
    if (this.screenCallback) {
      setTimeout(() =&gt; {
        // 发送模拟屏幕数据
        const mockData = new ArrayBuffer(100);
        this.screenCallback!(mockData, 1920, 1080, Date.now());
      }, 100);
    }
  }

  closeRemoteScreen(): void {
    this.recordCall('closeRemoteScreen', []);
    
    this.remoteControlEnabled = false;
    this.remoteDeviceInfo = { deviceCode: '', password: '' };
  }

  setScreenCallback(callback: ScreenCallback): void {
    this.recordCall('setScreenCallback', [callback]);
    this.screenCallback = callback;
  }

  // ========== 输入控制 ==========

  async sendControlEvent(event: RemoteControlEvent): Promise&lt;void&gt; {
    this.recordCall('sendControlEvent', [event]);
    // Mock 实现，仅记录调用
  }

  async sendMouseControl(x: number, y: number, action: number, wheelDelta?: number): Promise&lt;void&gt; {
    this.recordCall('sendMouseControl', [x, y, action, wheelDelta]);
    // Mock 实现，仅记录调用
  }

  async sendKeyControl(keyCode: number, pressed: boolean): Promise&lt;void&gt; {
    this.recordCall('sendKeyControl', [keyCode, pressed]);
    // Mock 实现，仅记录调用
  }

  // ========== 设备信息 ==========

  setDeviceInfoCallback(callback: DeviceInfoCallback): void {
    this.recordCall('setDeviceInfoCallback', [callback]);
    this.deviceInfoCallback = callback;
  }

  setDeviceInfo(deviceCode: string, password: string): void {
    this.recordCall('setDeviceInfo', [deviceCode, password]);
    this.remoteDeviceInfo = { deviceCode, password };
  }

  getLocalDeviceInfo(): DeviceCredentials {
    this.recordCall('getLocalDeviceInfo', []);
    return { ...this.localDeviceInfo };
  }

  getRemoteDeviceInfo(): DeviceCredentials {
    this.recordCall('getRemoteDeviceInfo', []);
    return { ...this.remoteDeviceInfo };
  }

  // ========== 权限控制 ==========

  setRemoteControlPermission(enabled: boolean): void {
    this.recordCall('setRemoteControlPermission', [enabled]);
    this.remoteControlEnabled = enabled;
  }

  async validateDevice(deviceCode: string, password: string): Promise&lt;DeviceValidationResult&gt; {
    this.recordCall('validateDevice', [deviceCode, password]);
    return { ...this.mockValidationResult };
  }

  // ========== 剪贴板 ==========

  async requestClipboard(): Promise&lt;void&gt; {
    this.recordCall('requestClipboard', []);
    // Mock 实现
  }

  async sendClipboardText(text: string): Promise&lt;void&gt; {
    this.recordCall('sendClipboardText', [text]);
    // Mock 实现
  }

  async sendClipboardFile(fileInfoId: string, fileName: string): Promise&lt;void&gt; {
    this.recordCall('sendClipboardFile', [fileInfoId, fileName]);
    // Mock 实现
  }

  setClipboardCallback(callback: ClipboardCallback): void {
    this.recordCall('setClipboardCallback', [callback]);
    this.clipboardCallback = callback;
  }

  // ========== 密码管理 ==========

  async changePassword(oldPassword: string, newPassword: string): Promise&lt;void&gt; {
    this.recordCall('changePassword', [oldPassword, newPassword]);
    
    // Mock 实现，更新本地密码
    if (oldPassword === this.localDeviceInfo.password) {
      this.localDeviceInfo.password = newPassword;
    }
  }

  // ========== 生命周期 ==========

  cleanup(): void {
    this.recordCall('cleanup', []);
    
    // 清理回调
    this.screenCallback = null;
    this.deviceInfoCallback = null;
    this.connectionCallback = null;
    this.clipboardCallback = null;
  }

  // ========== Mock 专用方法 ==========

  /**
   * 记录方法调用
   */
  private recordCall(method: string, args: unknown[]): void {
    this.callHistory.push({ method, args });
  }

  /**
   * 重置所有状态
   */
  reset(): void {
    this.connectionState = ConnectionState.DISCONNECTED;
    this.localDeviceInfo = { deviceCode: '', password: '' };
    this.remoteDeviceInfo = { deviceCode: '', password: '' };
    this.remoteControlEnabled = false;
    this.callHistory = [];
  }

  /**
   * 设置 Mock 验证结果
   */
  setMockValidationResult(result: DeviceValidationResult): void {
    this.mockValidationResult = result;
  }

  /**
   * 模拟接收设备信息
   */
  simulateDeviceInfo(deviceCode: string, password: string): void {
    this.localDeviceInfo = { deviceCode, password };
    
    if (this.deviceInfoCallback) {
      this.deviceInfoCallback(deviceCode, password);
    }
  }

  /**
   * 模拟连接状态变化
   */
  simulateConnectionState(connected: boolean): void {
    this.connectionState = connected ? ConnectionState.CONNECTED : ConnectionState.DISCONNECTED;
    
    if (this.connectionCallback) {
      this.connectionCallback(connected);
    }
  }

  /**
   * 模拟接收屏幕数据
   */
  simulateScreenData(data: ArrayBuffer, width: number, height: number): void {
    if (this.screenCallback) {
      this.screenCallback(data, width, height, Date.now());
    }
  }

  /**
   * 获取调用历史
   */
  getCallHistory(): Array&lt;{ method: string; args: unknown[] }&gt; {
    return [...this.callHistory];
  }

  /**
   * 检查方法是否被调用
   */
  wasMethodCalled(method: string): boolean {
    return this.callHistory.some(call =&gt; call.method === method);
  }

  /**
   * 获取方法调用次数
   */
  getMethodCallCount(method: string): number {
    return this.callHistory.filter(call =&gt; call.method === method).length;
  }
}
