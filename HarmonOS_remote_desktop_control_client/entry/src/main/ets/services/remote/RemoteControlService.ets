/**
 * 远程控制服务
 * 使用拆分类降低复杂度和耦合度：
 * - ConnectionManager: 管理连接
 * - ProtocolHandler: 处理协议
 * - HeartbeatManager: 管理心跳
 */

import { 
  IRemoteControlService, 
  DeviceCredentials, 
  ScreenCallback, 
  DeviceInfoCallback,
  RemoteControlServiceConfig
} from '../interfaces/IRemoteControlService';
import { 
  RemoteControlEvent, 
  ConnectionState, 
  DeviceValidationResult
} from '../../models/DeviceInfo';
import { 
  ClientInfoCallback, 
  ConnectionCallback, 
  ClipboardCallback
} from '../../models/CmdProtocol';
import { IConnectionManager } from '../connection/IConnectionManager';
import { IProtocolHandler } from '../protocol/IProtocolHandler';
import { IHeartbeatManager } from '../interfaces/IHeartbeatManager';
import { CmdCodec } from '../../network/CmdCodec';
import { ConcreteCmd } from '../../models/ConcreteCmd';
import { CmdType } from '../../models/CmdProtocol';
import { CmdUtils } from '../../models/CmdFactory';
import hilog from '@ohos.hilog';

const DOMAIN: number = 0xFF00;
const TAG: string = 'RemoteControlService';

/**
 * 远程控制服务
 * 使用拆分类降低复杂度和耦合度：
 * - ConnectionManager: 管理连接
 * - ProtocolHandler: 处理协议
 * - HeartbeatManager: 管理心跳
 */
export class RemoteControlService implements IRemoteControlService {
  // 配置
  private config: RemoteControlServiceConfig;

  // 依赖（通过构造函数注入）
  private connectionManager: IConnectionManager;
  private protocolHandler: IProtocolHandler;
  private heartbeatManager: IHeartbeatManager;

  // 设备信息
  private localDeviceCode: string = '';
  private localPassword: string = '';
  private remoteDeviceCode: string = '';
  private remotePassword: string = '';
  private remoteControlEnabled: boolean = false;
  private isValidating: boolean = false;

  // 回调
  private screenCallback: ScreenCallback | null = null;
  private clientInfoCallback: ClientInfoCallback | null = null;
  private connectionCallback: ConnectionCallback | null = null;
  private clipboardCallback: ClipboardCallback | null = null;
  private deviceInfoCallback: DeviceInfoCallback | null = null;
  private validationCallback: ((result: DeviceValidationResult) => void) | null = null;

  constructor(
    config: RemoteControlServiceConfig,
    connectionManager: IConnectionManager,
    protocolHandler: IProtocolHandler,
    heartbeatManager: IHeartbeatManager
  ) {
    // 合并默认配置
    this.config = {
      host: config.host,
      port: config.port,
      maxReconnectAttempts: config.maxReconnectAttempts !== undefined ? config.maxReconnectAttempts : 3,
      reconnectDelay: config.reconnectDelay !== undefined ? config.reconnectDelay : 2000,
      heartbeatInterval: config.heartbeatInterval !== undefined ? config.heartbeatInterval : 3000
    };

    // 注入依赖
    this.connectionManager = connectionManager;
    this.protocolHandler = protocolHandler;
    this.heartbeatManager = heartbeatManager;

    // 设置回调
    this.setupCallbacks();

    hilog.info(DOMAIN, TAG, 'Service initialized with injected dependencies');
  }

  /**
   * 设置回调
   */
  private setupCallbacks(): void {
    // 连接状态回调
    this.connectionManager.setConnectionCallback((connected: boolean) => {
      hilog.info(DOMAIN, TAG, 'Connection state changed: %{public}s', connected ? 'connected' : 'disconnected');
      
      if (connected) {
        this.sendClientInfo();
        this.startHeartbeat();
      } else {
        this.stopHeartbeat();
      }

      if (this.connectionCallback) {
        this.connectionCallback(connected);
      }
    });

    // 消息接收回调
    this.connectionManager.setMessageCallback((data: ArrayBuffer) => {
      this.protocolHandler.processData(data);
    });

    // 错误回调
    this.connectionManager.setErrorCallback((error: Error) => {
      hilog.error(DOMAIN, TAG, 'Connection error: %{public}s', error.message);
    });

    // 命令处理回调
    this.protocolHandler.setCommandCallback(async (cmd: ConcreteCmd) => {
      await this.processCommand(cmd);
    });

    // 心跳回调
    this.heartbeatManager.setHeartbeatCallback(() => {
      this.sendHeartbeat();
    });
  }

  // ========== IRemoteControlService 实现 ==========

  /**
   * 连接到服务端
   */
  async connect(onSuccess?: () => void, onError?: (error: string) => void): Promise<void> {
    try {
      await this.connectionManager.connect();
      if (onSuccess) {
        onSuccess();
      }
    } catch (error) {
      if (onError) {
        onError(String(error));
      }
    }
  }

  /**
   * 断开连接
   */
  async disconnect(): Promise<void> {
    this.stopHeartbeat();
    await this.connectionManager.disconnect();
    this.protocolHandler.cleanup();
    this.heartbeatManager.destroy();
  }

  /**
   * 获取连接状态
   */
  getConnectionState(): ConnectionState {
    return this.connectionManager.getConnectionState();
  }

  /**
   * 设置连接状态回调
   */
  setConnectionCallback(callback: ConnectionCallback): void {
    this.connectionCallback = callback;
  }

  /**
   * 打开远程屏幕
   */
  async openRemoteScreen(deviceCode: string, password: string): Promise<void> {
    this.remoteDeviceCode = deviceCode;
    this.remotePassword = password;
    this.isValidating = true;

    hilog.info(DOMAIN, TAG, 'Opening remote screen: %{public}s', deviceCode);
  }

  /**
   * 关闭远程屏幕
   */
  closeRemoteScreen(): void {
    this.remoteControlEnabled = false;
    this.remoteDeviceCode = '';
    this.remotePassword = '';
    hilog.info(DOMAIN, TAG, 'Remote screen closed');
  }

  /**
   * 设置屏幕数据回调
   */
  setScreenCallback(callback: ScreenCallback): void {
    this.screenCallback = callback;
  }

  /**
   * 发送控制事件
   */
  async sendControlEvent(event: RemoteControlEvent): Promise<void> {
    if (!this.remoteControlEnabled) {
      hilog.warn(DOMAIN, TAG, 'Remote control not enabled');
      return;
    }

    hilog.info(DOMAIN, TAG, 'Sending control event: %{public}s', event.type);
  }

  /**
   * 发送鼠标控制
   */
  async sendMouseControl(x: number, y: number, action: number, wheelDelta?: number): Promise<void> {
    if (!this.remoteControlEnabled) {
      hilog.warn(DOMAIN, TAG, 'Remote control not enabled');
      return;
    }

    hilog.info(DOMAIN, TAG, 'Sending mouse control: x=%{public}d, y=%{public}d, action=%{public}d', x, y, action);
  }

  /**
   * 发送键盘控制
   */
  async sendKeyControl(keyCode: number, pressed: boolean): Promise<void> {
    if (!this.remoteControlEnabled) {
      hilog.warn(DOMAIN, TAG, 'Remote control not enabled');
      return;
    }

    hilog.info(DOMAIN, TAG, 'Sending key control: keyCode=%{public}d, pressed=%{public}s', keyCode, String(pressed));
  }

  /**
   * 设置设备信息回调
   */
  setDeviceInfoCallback(callback: DeviceInfoCallback): void {
    this.deviceInfoCallback = callback;
  }

  /**
   * 设置设备信息
   */
  setDeviceInfo(deviceCode: string, password: string): void {
    this.remoteDeviceCode = deviceCode;
    this.remotePassword = password;
  }

  /**
   * 获取本地设备信息
   */
  getLocalDeviceInfo(): DeviceCredentials {
    return {
      deviceCode: this.localDeviceCode,
      password: this.localPassword
    };
  }

  /**
   * 获取远程设备信息
   */
  getRemoteDeviceInfo(): DeviceCredentials {
    return {
      deviceCode: this.remoteDeviceCode,
      password: this.remotePassword
    };
  }

  /**
   * 设置远程控制权限
   */
  setRemoteControlPermission(enabled: boolean): void {
    this.remoteControlEnabled = enabled;
    hilog.info(DOMAIN, TAG, 'Remote control permission: %{public}s', enabled ? 'enabled' : 'disabled');
  }

  /**
   * 验证设备
   */
  async validateDevice(deviceCode: string, password: string): Promise<DeviceValidationResult> {
    return {
      valid: deviceCode.length > 0 && password.length > 0,
      message: '验证成功'
    };
  }

  /**
   * 请求剪贴板内容
   */
  async requestClipboard(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Requesting clipboard content');
  }

  /**
   * 发送文本剪贴板
   */
  async sendClipboardText(text: string): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Sending clipboard text');
  }

  /**
   * 发送文件剪贴板
   */
  async sendClipboardFile(fileInfoId: string, fileName: string): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Sending clipboard file: %{public}s', fileName);
  }

  /**
   * 设置剪贴板回调
   */
  setClipboardCallback(callback: ClipboardCallback): void {
    this.clipboardCallback = callback;
  }

  /**
   * 修改密码
   */
  async changePassword(oldPassword: string, newPassword: string): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Changing password');
  }

  /**
   * 清理资源
   */
  cleanup(): void {
    this.stopHeartbeat();
    this.connectionManager.cleanup();
    this.protocolHandler.cleanup();
    this.heartbeatManager.destroy();
    hilog.info(DOMAIN, TAG, 'Service cleaned up');
  }

  // ========== 私有方法 ==========

  /**
   * 处理命令
   */
  private async processCommand(cmd: ConcreteCmd): Promise<void> {
    const cmdType = cmd.type;

    switch (cmdType) {
      case CmdType.ResCliInfo:
        await this.handleClientInfoCommand(cmd);
        break;
      case CmdType.Capture:
        await this.handleCaptureCommand(cmd);
        break;
      case CmdType.ResOpen:
        this.handleValidationResult(cmd);
        break;
      default:
        hilog.warn(DOMAIN, TAG, 'Unknown command type: %{public}d', cmdType);
    }
  }

  /**
   * 处理客户端信息命令
   */
  private async handleClientInfoCommand(cmd: ConcreteCmd): Promise<void> {
    const data = cmd.getData();
    const deviceCode = data.deviceCode;
    const password = data.password;

    this.localDeviceCode = deviceCode;
    this.localPassword = password;

    if (this.deviceInfoCallback) {
      this.deviceInfoCallback(deviceCode, password);
    }

    hilog.info(DOMAIN, TAG, 'Received device info: %{public}s', deviceCode);
  }

  /**
   * 处理捕获命令
   */
  private async handleCaptureCommand(cmd: ConcreteCmd): Promise<void> {
    try {
      hilog.info(DOMAIN, TAG, 'Processing capture command');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to process capture: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 处理验证结果
   */
  private handleValidationResult(cmd: ConcreteCmd): void {
    const data = cmd.getData();
    const status = data.status || 'FAILED';

    const result: DeviceValidationResult = {
      valid: status === 'SUCCESS',
      message: status === 'SUCCESS' ? '验证成功' : '验证失败'
    };

    this.isValidating = false;

    if (this.validationCallback) {
      this.validationCallback(result);
    }

    if (result.valid) {
      this.remoteControlEnabled = true;
    }

    hilog.info(DOMAIN, TAG, 'Validation result: %{public}s', status);
  }

  /**
   * 发送设备信息
   */
  private async sendClientInfo(): Promise<void> {
    if (this.getConnectionState() !== ConnectionState.CONNECTED) {
      return;
    }

    try {
      hilog.info(DOMAIN, TAG, 'Sending client info to server...');
      const reqCliInfoCmd = CmdUtils.createReqCliInfoCmd(1, 'HarmonyOS');
      const encoded = CmdCodec.encode(reqCliInfoCmd);
      await this.connectionManager.send(encoded);
      hilog.info(DOMAIN, TAG, 'Client info sent successfully');
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to send client info: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 发送心跳
   */
  private async sendHeartbeat(): Promise<void> {
    if (this.getConnectionState() !== ConnectionState.CONNECTED) {
      return;
    }

    try {
      const pingCmd = CmdCodec.createPingCmd();
      const encoded = CmdCodec.encode(pingCmd);
      await this.connectionManager.send(encoded);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to send heartbeat: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 启动心跳
   */
  private startHeartbeat(): void {
    this.heartbeatManager.init(this.config.heartbeatInterval);
    this.heartbeatManager.start();
  }

  /**
   * 停止心跳
   */
  private stopHeartbeat(): void {
    this.heartbeatManager.stop();
  }
}
