import { RemoteControlEvent, ScreenImage, ConnectionState } from '../../models/DeviceInfo';
import { IRemoteControlService } from '../interfaces/IService';
import socket from '@ohos.net.socket';
import { BusinessError } from '@ohos.base';
import { util } from '@kit.ArkTS';
import { CmdCodec } from '../../network/CmdCodec';
import { ConcreteCmd } from '../../models/ConcreteCmd';
import { 
  CmdType, 
  ScreenCallback,
  ClientInfoCallback,
  ConnectionCallback,
  ClipboardCallback,
  ClipboardData
} from '../../models/CmdProtocol';

// 命令数据JSON接口
interface CmdDataJSON {
  deviceCode?: string;
  password?: string;
  status?: string;
  imageData?: string | ArrayBuffer;
  width?: number;
  height?: number;
  x?: number;
  y?: number;
  action?: number;
  wheelDelta?: number;
  keyCode?: number;
  pressed?: boolean;
  fps?: number;
  captureFrequency?: number;
  quality?: number;
  maxFps?: number;
  compressionMethod?: number;
  compressionLevel?: number;
  screenIndex?: number;
  captureOp?: number;
  clipboards?: ClipboardData[];
  text?: string;
  fileInfoId?: string;
  fileName?: string;
  filePid?: string;
  isFile?: number;
  oldPassword?: string;
  newPassword?: string;
  type?: CmdType;
  id?: string;
}

export class RemoteControlService implements IRemoteControlService {
  private host: string;
  private port: number;
  private socket: socket.TCPSocket | null = null;
  private screenCallback: ((image: ScreenImage) => void) | null = null;
  private clientInfoCallback: ClientInfoCallback | null = null;
  private connectionCallback: ConnectionCallback | null = null;
  private clipboardCallback: ClipboardCallback | null = null;
  private deviceInfoCallback: ((deviceCode: string, password: string) => void) | null = null;
  private connectionState: ConnectionState = ConnectionState.DISCONNECTED;
  private reconnectAttempts: number = 0;
  private maxReconnectAttempts: number = 3;
  private reconnectDelay: number = 2000;
  private heartbeatInterval: number = 3000; // 3秒，与Java客户端保持一致
  private heartbeatTimer: number = -1;
  private receiveBuffer: ArrayBuffer = new ArrayBuffer(0);
  private deviceCode: string = '';
  private password: string = '';

  constructor(
    host: string, 
    port: number, 
    screenCallback: (image: ScreenImage) => void,
    clientInfoCallback?: ClientInfoCallback,
    connectionCallback?: ConnectionCallback,
    clipboardCallback?: ClipboardCallback,
    deviceInfoCallback?: (deviceCode: string, password: string) => void
  ) {
    this.host = host;
    this.port = port;
    this.screenCallback = screenCallback;
    this.clientInfoCallback = clientInfoCallback || null;
    this.connectionCallback = connectionCallback || null;
    this.clipboardCallback = clipboardCallback || null;
    this.deviceInfoCallback = deviceInfoCallback || null;
  }

  /**
   * 设置屏幕回调
   */
  setScreenCallback(callback: (image: ScreenImage) => void): void {
    this.screenCallback = callback;
  }

  /**
   * 设置客户端信息回调
   */
  setClientInfoCallback(callback: ClientInfoCallback): void {
    this.clientInfoCallback = callback;
  }

  /**
   * 设置连接状态回调
   */
  setConnectionCallback(callback: ConnectionCallback): void {
    this.connectionCallback = callback;
  }

  /**
   * 设置剪贴板回调
   */
  setClipboardCallback(callback: ClipboardCallback): void {
    this.clipboardCallback = callback;
  }

  /**
   * 设置设备信息回调
   */
  setDeviceInfoCallback(callback: (deviceCode: string, password: string) => void): void {
    this.deviceInfoCallback = callback;
  }

  /**
   * 设置设备信息
   */
  setDeviceInfo(deviceCode: string, password: string): void {
    this.deviceCode = deviceCode;
    this.password = password;
  }

  // 连接到服务端
  async connect(
    onSuccess: () => void,
    onError: (error: string) => void
  ): Promise<void> {
    try {
      this.connectionState = ConnectionState.CONNECTING;
      
      // 创建 TCP Socket
      this.socket = socket.constructTCPSocketInstance();
      
      // 绑定事件
      this.bindSocketEvents();
      
      // 连接服务器
      await this.socket.connect({
        address: {
          address: this.host,
          port: this.port,
          family: 1 // IPv4
        },
        timeout: 10000
      });
      
      this.connectionState = ConnectionState.CONNECTED;
      this.reconnectAttempts = 0;
      
      // 发送客户端信息请求（模拟Java客户端行为）
      await this.sendReqCliInfoCmd();
      
      // 启动心跳
      this.startHeartbeat();
      
      console.info('RemoteControlService: Connected successfully');
      onSuccess();
      
    } catch (error) {
      const err = error as BusinessError;
      console.error('RemoteControlService: Connection failed', err.message);
      this.connectionState = ConnectionState.ERROR;
      
      // 尝试重连
      if (this.reconnectAttempts < this.maxReconnectAttempts) {
        this.reconnectAttempts++;
        console.info(`RemoteControlService: Reconnecting (${this.reconnectAttempts}/${this.maxReconnectAttempts})...`);
        setTimeout(() => {
          this.connect(onSuccess, onError);
        }, this.reconnectDelay);
      } else {
        onError(`连接失败: ${err.message}`);
      }
    }
  }

  // 绑定 Socket 事件
  private bindSocketEvents(): void {
    if (!this.socket) return;

    this.socket.on('message', (value: socket.SocketMessageInfo) => {
      this.handleMessage(value.message);
    });

    this.socket.on('error', (err: BusinessError) => {
      console.error('RemoteControlService: Socket error', err);
      this.connectionState = ConnectionState.ERROR;
      this.handleDisconnect();
    });

    this.socket.on('close', () => {
      console.info('RemoteControlService: Socket closed');
      this.connectionState = ConnectionState.DISCONNECTED;
      this.handleDisconnect();
    });
  }

  // 处理接收到的消息
  private handleMessage(data: ArrayBuffer): void {
    try {
      // 合并缓冲区
      const newBuffer = new ArrayBuffer(this.receiveBuffer.byteLength + data.byteLength);
      const newView = new Uint8Array(newBuffer);
      newView.set(new Uint8Array(this.receiveBuffer), 0);
      newView.set(new Uint8Array(data), this.receiveBuffer.byteLength);
      this.receiveBuffer = newBuffer;

      // 使用 CmdCodec 提取命令
      const extractResult = CmdCodec.extractCommands(this.receiveBuffer);
      const remainingBuffer = extractResult[0];
      const commands = extractResult[1];
      this.receiveBuffer = remainingBuffer;

      // 处理每个命令
      for (const cmd of commands) {
        this.processCommand(cmd);
      }
    } catch (error) {
      console.error('RemoteControlService: Failed to handle message', error);
    }
  }

  // 处理命令
  private processCommand(cmd: ConcreteCmd): void {
    const cmdType = cmd.type;
    
    switch (cmdType) {
      case CmdType.Capture:
        this.handleCaptureCommand(cmd);
        break;
      case CmdType.ResCliInfo:
        this.handleClientInfoCommand(cmd);
        break;
      case CmdType.ResOpen:
        this.handleOpenResponseCommand(cmd);
        break;
      case CmdType.ResCapture:
        this.handleCaptureResponseCommand(cmd);
        break;
      case CmdType.ResRemoteClipboard:
        this.handleClipboardResponseCommand(cmd);
        break;
      case CmdType.ResPong:
        this.handlePongCommand(cmd);
        break;
      default:
        console.log(`RemoteControlService: Received command type: ${cmdType}`);
        break;
    }
  }

  // 处理屏幕捕获命令
  private handleCaptureCommand(cmd: ConcreteCmd): void {
    try {
      const cmdData = cmd.toJSON() as CmdDataJSON;
      const width = cmdData.width as number;
      const height = cmdData.height as number;
      const imageData = cmdData.imageData as ArrayBuffer | string;
      
      if (this.screenCallback && width && height) {
        // 注意：这里需要根据实际的数据格式处理 imageData
        // 假设 imageData 是 base64 编码的字符串或 ArrayBuffer
        const imageBuffer = imageData instanceof ArrayBuffer ? 
          imageData : new ArrayBuffer(0);
        
        this.screenCallback({
          data: imageBuffer,
          width: width,
          height: height,
          timestamp: Date.now()
        });
      }
    } catch (error) {
      console.error('RemoteControlService: Failed to handle capture command', error);
    }
  }

  // 处理客户端信息命令
  private handleClientInfoCommand(cmd: ConcreteCmd): void {
    try {
      const cmdData = cmd.toJSON() as CmdDataJSON;
      const deviceCode = cmdData.deviceCode as string;
      const password = cmdData.password as string;
      
      console.log(`RemoteControlService: Received client info from server - deviceCode: ${deviceCode}, password: ${password}`);
      
      // 保存设备信息
      this.deviceCode = deviceCode;
      this.password = password;
      
      // 调用设备信息回调（通知UI更新）
      if (this.deviceInfoCallback) {
        this.deviceInfoCallback(deviceCode, password);
      }
      
      // 调用客户端信息回调（保持向后兼容）
      if (this.clientInfoCallback) {
        this.clientInfoCallback({
          deviceCode: deviceCode,
          password: password
        });
      }
    } catch (error) {
      console.error('RemoteControlService: Failed to handle client info command', error);
    }
  }
  // 处理打开连接响应命令
  private handleOpenResponseCommand(cmd: ConcreteCmd): void {
    try {
      const cmdData = cmd.toJSON() as CmdDataJSON;
      const status = cmdData.status as string;
      
      console.log(`RemoteControlService: Open response - status: ${status}`);
      
      // 根据状态处理
      switch (status) {
        case 'OK':
          console.log('RemoteControlService: Connection opened successfully');
          break;
        case 'OFFLINE':
          console.error('RemoteControlService: Target device is offline');
          break;
        case 'CONTROL':
          console.error('RemoteControlService: Target device is being controlled by another client');
          break;
      }
    } catch (error) {
      console.error('RemoteControlService: Failed to handle open response command', error);
    }
  }
  // 处理捕获响应命令
  private handleCaptureResponseCommand(cmd: ConcreteCmd): void {
    try {
      const cmdData = cmd.toJSON() as CmdDataJSON;
      const status = cmdData.status as string;
      
      console.log(`RemoteControlService: Capture response - status: ${status}`);
      
      // 根据状态处理
      switch (status) {
        case 'OK':
          console.log('RemoteControlService: Screen capture started successfully');
          break;
        case 'OFFLINE':
          console.error('RemoteControlService: Target device is offline');
          break;
        case 'PWDERROR':
          console.error('RemoteControlService: Invalid password');
          break;
        case 'CONTROL':
          console.error('RemoteControlService: Target device is being controlled by another client');
          break;
        case 'STOP':
          console.log('RemoteControlService: Screen capture stopped');
          break;
      }
    } catch (error) {
      console.error('RemoteControlService: Failed to handle capture response command', error);
    }
  }
  // 处理剪贴板响应命令
  private handleClipboardResponseCommand(cmd: ConcreteCmd): void {
    try {
      const cmdData = cmd.toJSON() as CmdDataJSON;
      const clipboards = cmdData.clipboards as ClipboardData[];
      
      console.log(`RemoteControlService: Received clipboard data - items: ${clipboards?.length || 0}`);
      
      if (this.clipboardCallback && clipboards) {
        this.clipboardCallback(clipboards);
      }
    } catch (error) {
      console.error('RemoteControlService: Failed to handle clipboard response command', error);
    }
  }

  // 处理心跳响应命令
  private handlePongCommand(cmd: ConcreteCmd): void {
    console.log('RemoteControlService: Received pong response');
  }

  // 解析屏幕图像
  private parseScreenImage(data: ArrayBuffer): void {
    try {
      // 假设数据格式：width(4) + height(4) + timestamp(8) + image data
      const view = new DataView(data);
      const width = view.getInt32(0, false);
      const height = view.getInt32(4, false);
      const timestamp = view.getFloat64(8, false);
      const imageData = data.slice(16);

      if (this.screenCallback) {
        this.screenCallback({
          data: imageData,
          width: width,
          height: height,
          timestamp: timestamp
        });
      }
    } catch (error) {
      console.error('RemoteControlService: Failed to parse screen image', error);
    }
  }

  // 发送命令
  private async sendCmd(cmd: ConcreteCmd): Promise<void> {
    if (!this.socket || this.connectionState !== ConnectionState.CONNECTED) {
      console.error('RemoteControlService: Not connected');
      return;
    }

    try {
      // 编码命令
      const encodedData = CmdCodec.encode(cmd);
      
      await this.socket.send({
        data: encodedData
      });
      
      console.log(`RemoteControlService: Sent command type: ${cmd.type}, id: ${cmd.id}`);
    } catch (error) {
      console.error('RemoteControlService: Failed to send command', error);
    }
  }

  // 发送远程控制事件
  async sendControlEvent(event: RemoteControlEvent): Promise<void> {
    // 兼容旧接口，转换为新的命令格式
    if (event.type === 'mouse') {
      await this.sendMouseControl(event.x || 0, event.y || 0, event.action === 'down' ? 1 : 0);
    } else if (event.type === 'keyboard') {
      await this.sendKeyControl(event.keyCode || 0, event.action === 'press');
    }
  }

  // 打开远程屏幕
  async openRemoteScreen(deviceCode: string, password: string): Promise<void> {
    console.info(`RemoteControlService: Opening remote screen for device ${deviceCode}`);
    
    // 1. 发送打开连接请求
    const openCmd = CmdCodec.createOpenCmd(deviceCode);
    await this.sendCmd(openCmd);
    
    // 2. 发送屏幕捕获请求
    const captureCmd = CmdCodec.createCaptureCmd(deviceCode, password, true);
    await this.sendCmd(captureCmd);
  }

  // 关闭远程屏幕
  async closeRemoteScreen(): Promise<void> {
    if (!this.deviceCode || !this.password) {
      console.error('RemoteControlService: Device info not set');
      return;
    }
    
    console.info(`RemoteControlService: Closing remote screen for device ${this.deviceCode}`);
    
    // 发送停止捕获请求
    const captureCmd = CmdCodec.createCaptureCmd(this.deviceCode, this.password, false);
    await this.sendCmd(captureCmd);
  }

  // 发送鼠标控制
  async sendMouseControl(x: number, y: number, action: number, wheelDelta?: number): Promise<void> {
    if (!this.deviceCode) {
      console.error('RemoteControlService: Device code not set');
      return;
    }
    
    const mouseCmd = CmdCodec.createMouseControlCmd(this.deviceCode, x, y, action, wheelDelta);
    await this.sendCmd(mouseCmd);
  }

  // 发送键盘控制
  async sendKeyControl(keyCode: number, pressed: boolean): Promise<void> {
    if (!this.deviceCode) {
      console.error('RemoteControlService: Device code not set');
      return;
    }
    
    const keyCmd = CmdCodec.createKeyControlCmd(this.deviceCode, keyCode, pressed);
    await this.sendCmd(keyCmd);
  }

  // 请求剪贴板内容
  async requestClipboard(): Promise<void> {
    if (!this.deviceCode) {
      console.error('RemoteControlService: Device code not set');
      return;
    }
    
    const clipboardCmd = CmdCodec.createClipboardRequestCmd(this.deviceCode);
    await this.sendCmd(clipboardCmd);
  }

  // 发送文本剪贴板
  async sendClipboardText(text: string): Promise<void> {
    if (!this.deviceCode) {
      console.error('RemoteControlService: Device code not set');
      return;
    }
    
    const textCmd = CmdCodec.createClipboardTextCmd(this.deviceCode, text);
    await this.sendCmd(textCmd);
  }

  // 发送文件剪贴板
  async sendClipboardFile(fileInfoId: string, fileName: string): Promise<void> {
    if (!this.deviceCode) {
      console.error('RemoteControlService: Device code not set');
      return;
    }
    
    const fileCmd = CmdCodec.createClipboardTransferCmd(this.deviceCode, fileInfoId, fileName);
    await this.sendCmd(fileCmd);
  }

  // 发送客户端信息请求
  private async sendReqCliInfoCmd(): Promise<void> {
    if (!this.socket) return;
    
    try {
      // 模拟Java客户端行为：发送屏幕数量和操作系统信息
      // 在HarmonyOS中，我们发送默认值
      const reqCliInfoCmd = CmdCodec.createReqCliInfoCmd(1, 'HarmonyOS');
      await this.sendCmd(reqCliInfoCmd);
      console.info('RemoteControlService: Sent ReqCliInfo command');
    } catch (error) {
      console.error('RemoteControlService: Failed to send ReqCliInfo command', error);
    }
  }

  // 发送心跳
  private async sendHeartbeat(): Promise<void> {
    if (!this.socket) return;
    
    try {
      const heartbeatCmd = CmdCodec.createPingCmd();
      await this.sendCmd(heartbeatCmd);
    } catch (error) {
      console.error('RemoteControlService: Failed to send heartbeat', error);
    }
  }

  // 启动心跳
  private startHeartbeat(): void {
    this.stopHeartbeat();
    this.heartbeatTimer = setInterval(() => {
      if (this.connectionState === ConnectionState.CONNECTED) {
        // 发送心跳包
        this.sendHeartbeat();
      }
    }, this.heartbeatInterval);
  }

  // 停止心跳
  private stopHeartbeat(): void {
    if (this.heartbeatTimer !== -1) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = -1;
    }
  }

  // 处理断开连接
  private handleDisconnect(): void {
    this.stopHeartbeat();
    
    // 尝试重连
    if (this.reconnectAttempts < this.maxReconnectAttempts) {
      this.reconnectAttempts++;
      console.info(`RemoteControlService: Reconnecting (${this.reconnectAttempts}/${this.maxReconnectAttempts})...`);
      setTimeout(() => {
        this.connect(
          () => console.info('RemoteControlService: Reconnected successfully'),
          (error) => console.error('RemoteControlService: Reconnect failed', error)
        );
      }, this.reconnectDelay);
    }
  }

  // 断开连接
  async disconnect(): Promise<void> {
    try {
      this.stopHeartbeat();
      
      if (this.socket) {
        await this.socket.close();
        this.socket = null;
      }
      
      this.connectionState = ConnectionState.DISCONNECTED;
      console.info('RemoteControlService: Disconnected');
    } catch (error) {
      console.error('RemoteControlService: Failed to disconnect', error);
    }
  }

  // 获取连接状态
  getConnectionState(): ConnectionState {
    return this.connectionState;
  }

  // 修改密码
  async changePassword(oldPassword: string, newPassword: string): Promise<void> {
    if (!this.deviceCode) {
      console.error('RemoteControlService: Device code not set');
      throw new Error('设备信息未设置');
    }

    if (!this.socket || this.connectionState !== ConnectionState.CONNECTED) {
      console.error('RemoteControlService: Not connected');
      throw new Error('未连接到服务器');
    }

    try {
      // 创建修改密码命令
      const changePwdCmd = CmdCodec.createChangePwdCmd(this.deviceCode, oldPassword, newPassword);
      await this.sendCmd(changePwdCmd);
      
      // 更新本地密码
      this.password = newPassword;
      console.info('RemoteControlService: Password change request sent');
    } catch (error) {
      console.error('RemoteControlService: Failed to send password change command', error);
      throw new Error(error as string);
    }
  }
}