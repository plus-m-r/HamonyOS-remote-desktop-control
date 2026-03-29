/**
 * 远程控制服务（完全解耦版本）
 * 
 * 改进点：
 * 1. 实现 IRemoteControlService 接口
 * 2. 依赖抽象接口而非具体实现
 * 3. 通过构造函数注入依赖，便于 Mock 测试
 * 4. 单一职责：只负责业务逻辑
 * 5. 可测试性：所有外部依赖都可 Mock
 */

import { 
  IRemoteControlService, 
  DeviceCredentials, 
  ScreenCallback, 
  DeviceInfoCallback,
  RemoteControlServiceConfig,
  RemoteControlServiceDependencies
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
import { 
  ITcpRepository, 
  TcpConnectionConfig, 
  TcpConnectionState 
} from '../../repository/ITcpRepository';
import { IWorkerRepository, ProtocolParseTask, ProtocolParseResult } from '../../repository/IWorkerRepository';
import { IHeartbeatManager } from '../interfaces/IHeartbeatManager';
import { CmdCodec } from '../../network/CmdCodec';
import { ConcreteCmd } from '../../models/ConcreteCmd';
import { CmdType } from '../../models/CmdProtocol';
import { CmdData } from '../../models/CmdData';
import hilog from '@ohos.hilog';

const DOMAIN: number = 0xFF00;
const TAG: string = 'RemoteControlService';

/**
 * 完全解耦的远程控制服务
 * 实现 IRemoteControlService 接口
 */
export class RemoteControlService implements IRemoteControlService {
  // 配置
  private config: RemoteControlServiceConfig;
  
  // 依赖（通过构造函数注入）
  private tcpRepository: ITcpRepository;
  private workerRepository: IWorkerRepository;
  private heartbeatManager: IHeartbeatManager;

  // 状态
  private connectionState: ConnectionState = ConnectionState.DISCONNECTED;
  private reconnectAttempts: number = 0;
  private receiveBuffer: ArrayBuffer = new ArrayBuffer(0);
  
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
    dependencies: RemoteControlServiceDependencies
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
    this.tcpRepository = dependencies.tcpRepository;
    this.workerRepository = dependencies.workerRepository;
    this.heartbeatManager = dependencies.heartbeatManager;

    // 初始化 Worker
    this.workerRepository.init();

    // 设置 TCP 回调
    this.setupTcpCallbacks();

    // 设置心跳回调
    this.heartbeatManager.setHeartbeatCallback(() => {
      this.sendHeartbeat();
    });

    hilog.info(DOMAIN, TAG, 'Service initialized with injected dependencies');
  }

  /**
   * 设置 TCP 回调
   */
  private setupTcpCallbacks(): void {
    // 消息接收
    this.tcpRepository.onMessage((data: ArrayBuffer) => {
      this.handleMessage(data);
    });

    // 错误处理
    this.tcpRepository.onError((error) => {
      hilog.error(DOMAIN, TAG, 'TCP error: %{public}s', JSON.stringify(error));
      this.handleDisconnect();
    });

    // 状态变更
    this.tcpRepository.onStateChange((state) => {
      hilog.info(DOMAIN, TAG, 'TCP state changed to %{public}s', state);
      
      switch (state) {
        case TcpConnectionState.CONNECTED:
          this.connectionState = ConnectionState.CONNECTED;
          this.reconnectAttempts = 0;
          this.startHeartbeat();
          break;
        case TcpConnectionState.DISCONNECTED:
          this.connectionState = ConnectionState.DISCONNECTED;
          this.stopHeartbeat();
          break;
        case TcpConnectionState.ERROR:
          this.connectionState = ConnectionState.ERROR;
          this.handleDisconnect();
          break;
      }

      if (this.connectionCallback) {
        this.connectionCallback(state === TcpConnectionState.CONNECTED);
      }
    });
  }

  // ========== IRemoteControlService 实现 ==========

  /**
   * 连接到服务端
   */
  async connect(onSuccess?: () => void, onError?: (error: string) => void): Promise<void> {
    try {
      this.connectionState = ConnectionState.CONNECTING;

      const tcpConfig: TcpConnectionConfig = {
        host: this.config.host,
        port: this.config.port,
        connectTimeout: 10000,
        readTimeout: 30000,
        writeTimeout: 30000
      };

      await this.tcpRepository.connect(tcpConfig);

      if (onSuccess) {
        onSuccess();
      }
    } catch (error) {
      this.connectionState = ConnectionState.ERROR;
      
      if (onError) {
        onError(String(error));
      }

      // 尝试重连
      this.handleReconnect();
    }
  }

  /**
   * 断开连接
   */
  async disconnect(): Promise<void> {
    this.stopHeartbeat();
    await this.tcpRepository.disconnect();
    this.workerRepository.destroy();
    this.heartbeatManager.destroy();
  }

  /**
   * 获取连接状态
   */
  getConnectionState(): ConnectionState {
    return this.connectionState;
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

    // 发送验证请求
    hilog.info(DOMAIN, TAG, 'Opening remote screen: %{public}s', deviceCode);
    
    // 这里应该发送实际的验证命令
    // 简化实现
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
    // 实现控制事件发送
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
    // 实现鼠标控制发送
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
    // 实现键盘控制发送
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
    // 简化实现，实际应该发送验证命令到服务器
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
    // 实现剪贴板请求
  }

  /**
   * 发送文本剪贴板
   */
  async sendClipboardText(text: string): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Sending clipboard text');
    // 实现文本剪贴板发送
  }

  /**
   * 发送文件剪贴板
   */
  async sendClipboardFile(fileInfoId: string, fileName: string): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Sending clipboard file: %{public}s', fileName);
    // 实现文件剪贴板发送
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
    // 实现密码修改
  }

  /**
   * 清理资源
   */
  cleanup(): void {
    this.stopHeartbeat();
    this.workerRepository.destroy();
    this.heartbeatManager.destroy();
    hilog.info(DOMAIN, TAG, 'Service cleaned up');
  }

  // ========== 私有方法 ==========

  /**
   * 处理消息
   */
  private async handleMessage(data: ArrayBuffer): Promise<void> {
    try {
      // 使用 Worker 解析协议
      const parseTask: ProtocolParseTask = {
        existingBuffer: this.receiveBuffer,
        newData: data
      };
      const result: ProtocolParseResult = await this.workerRepository.parseProtocol(parseTask);

      this.receiveBuffer = result.remainingBuffer;

      // 处理解析出的命令
      for (let i = 0; i < result.commands.length; i++) {
        const cmdData = result.commands[i];
        // 注意：这里需要实际的解码逻辑，暂时简化
        const cmdDataObj = new CmdData();
        const cmd = new ConcreteCmd(CmdType.ResCliInfo, cmdDataObj);
        await this.processCommand(cmd);
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to process message: %{public}s', JSON.stringify(error));
    }
  }

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
      // 实现捕获命令处理
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
   * 发送心跳
   */
  private async sendHeartbeat(): Promise<void> {
    if (this.connectionState !== ConnectionState.CONNECTED) {
      return;
    }

    try {
      const pingCmd = CmdCodec.createPingCmd();
      const encoded = CmdCodec.encode(pingCmd);
      await this.tcpRepository.send(encoded);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to send heartbeat: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 启动心跳
   */
  private startHeartbeat(): void {
    this.heartbeatManager.start();
  }

  /**
   * 停止心跳
   */
  private stopHeartbeat(): void {
    this.heartbeatManager.stop();
  }

  /**
   * 处理断开连接
   */
  private handleDisconnect(): void {
    this.stopHeartbeat();
    this.handleReconnect();
  }

  /**
   * 处理重连
   */
  private handleReconnect(): void {
    if (this.reconnectAttempts >= this.config.maxReconnectAttempts) {
      hilog.error(DOMAIN, TAG, 'Max reconnection attempts reached');
      return;
    }

    this.reconnectAttempts++;
    hilog.info(DOMAIN, TAG, 'Reconnecting... attempt %{public}d', this.reconnectAttempts);

    setTimeout(() => {
      this.connect();
    }, this.config.reconnectDelay);
  }
}
