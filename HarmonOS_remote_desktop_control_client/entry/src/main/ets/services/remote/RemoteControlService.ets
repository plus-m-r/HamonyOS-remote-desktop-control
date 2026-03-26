
import { RemoteControlEvent, ConnectionState } from '../../models/DeviceInfo';
import { IRemoteControlService, DeviceValidationResult, DeviceCredentials } from '../interfaces/IService';
import socket from '@ohos.net.socket';
import { BusinessError } from '@ohos.base';
import { util } from '@kit.ArkTS';
import { CmdCodec } from '../../network/CmdCodec';
import { ConcreteCmd } from '../../models/ConcreteCmd';
import hilog from '@ohos.hilog';
import { 
  CmdType, 
  ScreenCallback,
  ClientInfoCallback,
  ConnectionCallback,
  ClipboardCallback,
  ClipboardData
} from '../../models/CmdProtocol';
import { Compressor, CompressionMethod as SqueezeCompressionMethod } from '../../squeeze/Compressor';
import { Capture } from '../../squeeze/Capture';
import { MemByteBuffer } from '../../squeeze/MemByteBuffer';
import { TileCache, NullTileCache } from '../../squeeze/TileCache';

// 日志相关常量
const DOMAIN: number = 0xFF00;
const TAG: string = 'RemoteControlService';

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

// 捕获任务接口
interface CaptureTask {
  cmd: ConcreteCmd;
  imageData: ArrayBuffer | string;
  compressionMethodOrdinal: number;
}

export class RemoteControlService implements IRemoteControlService {
  private host: string;
  private port: number;
  private socket: socket.TCPSocket | null = null;
  private screenCallback: ScreenCallback | null = null;
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
  private localDeviceCode: string = '';
  private localPassword: string = '';
  private remoteDeviceCode: string = '';
  private remotePassword: string = '';
  private remoteControlEnabled: boolean = false;
  private validationCallback: ((result: DeviceValidationResult) => void) | null = null;
  private isValidating: boolean = false;
  
  private tileCache: TileCache = new NullTileCache();
  private prevImageBuffer: Uint8Array | null = null;
  private prevImageWidth: number = 0;
  private prevImageHeight: number = 0;
  private loggedCaptureData: boolean = false;

  constructor(
    host: string, 
    port: number,
    screenCallback: ScreenCallback,
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
  setScreenCallback(callback: ScreenCallback): void {
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


  setDeviceInfo(deviceCode: string, password: string): void {
    // 设置用于控制远程设备的信息，不影响本地设备信息
    this.remoteDeviceCode = deviceCode;
    this.remotePassword = password;
  }

  // 获取本地设备信息
  getLocalDeviceInfo(): DeviceCredentials {
    return {
      deviceCode: this.localDeviceCode,
      password: this.localPassword
    };
  }

  // 获取远程设备信息
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
    hilog.info(DOMAIN, TAG, '远程控制权限设置: %{public}s', enabled ? '已启用' : '已禁用');
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
      
      // 通知UI连接状态更新
      if (this.connectionCallback) {
        console.info('RemoteControlService: 通知UI连接已建立');
        this.connectionCallback(true);
      }
      
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
      console.log('RemoteControlService: Socket message received');
      this.handleMessage(value.message).catch((error: Error) => {
        console.error('RemoteControlService: Error handling socket message', error);
      });
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
  private async handleMessage(data: ArrayBuffer): Promise<void> {
    try {
      console.log('RemoteControlService: handleMessage called, data size:', data.byteLength);
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
      
      console.log('RemoteControlService: Extracted', commands.length, 'commands');

      // 处理每个命令
      for (const cmd of commands) {
        console.log('RemoteControlService: Processing command, type:', cmd.type);
        await this.processCommand(cmd);
      }
    } catch (error) {
      console.error('RemoteControlService: Failed to handle message', error);
    }
  }

  // 处理命令
  private async processCommand(cmd: ConcreteCmd): Promise<void> {
    const cmdType = cmd.type;
    
    switch (cmdType) {
      case CmdType.Capture:
        await this.handleCaptureCommand(cmd);
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
      case CmdType.ClipboardText:
        this.handleClipboardTextCommand(cmd);
        break;
      case CmdType.ClipboardTransfer:
        this.handleClipboardTransferCommand(cmd);
        break;
      case CmdType.KeyControl:
        this.handleKeyControlCommand(cmd);
        break;
      case CmdType.MouseControl:
        this.handleMouseControlCommand(cmd);
        break;
      case CmdType.CaptureConfig:
        this.handleCaptureConfigCommand(cmd);
        break;
      case CmdType.CompressorConfig:
        this.handleCompressorConfigCommand(cmd);
        break;
      case CmdType.SelectScreen:
        this.handleSelectScreenCommand(cmd);
        break;
      case CmdType.ChangePwd:
        this.handleChangePwdCommand(cmd);
        break;
      default:
        console.log(`RemoteControlService: Received command type: ${cmdType}`);
        break;
    }
  }

  // 处理屏幕捕获命令
  private async handleCaptureCommand(cmd: ConcreteCmd): Promise<void> {
    try {
      const cmdData = cmd.toJSON() as CmdDataJSON;
      const imageData = cmdData.imageData as ArrayBuffer | string;
      const compressionMethodOrdinal = cmdData.compressionMethod as number || 0;
      
      console.log(`[步骤1-数据接收] imageData类型: ${typeof imageData}, 大小: ${imageData instanceof ArrayBuffer ? imageData.byteLength : (imageData as string).length}字节, 压缩方法: ${compressionMethodOrdinal}`);
      
      if (this.screenCallback && imageData) {
        // 限制队列大小，防止内存溢出
        if (this.decompressQueue.length > 10) {
          console.warn('RemoteControlService: Queue size exceeds limit, dropping oldest task');
          this.decompressQueue.shift(); // 移除最旧的任务
        }
        
        // 异步处理捕获命令
        this.decompressQueue.push({ cmd, imageData, compressionMethodOrdinal });
        console.log(`[步骤1-数据接收] 加入解压队列，当前队列长度: ${this.decompressQueue.length}`);
        if (!this.isProcessing) {
          this.processNext();
        }
      }
    } catch (error) {
      console.error('RemoteControlService: Failed to handle capture command', error);
    }
  }
  // 异步处理队列
  private decompressQueue: Array<CaptureTask> = [];
  private isProcessing: boolean = false;
  
  // 处理队列中的下一个任务
  private async processNext(): Promise<void> {
    if (this.decompressQueue.length === 0) {
      this.isProcessing = false;
      return;
    }
    
    this.isProcessing = true;
    const task = this.decompressQueue.shift();
    if (!task) {
      this.isProcessing = false;
      return;
    }
    
    try {
      await this.processCaptureTask(task);
    } catch (error) {
      console.error('RemoteControlService: Failed to process capture task', error);
    } finally {
      // 使用setTimeout避免递归调用导致堆栈溢出
      setTimeout(() => {
        this.processNext();
      }, 0);
    }
  }
  // 处理单个捕获任务
  private async processCaptureTask(task: CaptureTask): Promise<void> {
    const startTime = Date.now();
    try {
      const imageData = task.imageData;
      const compressionMethodOrdinal = task.compressionMethodOrdinal;
      
      const payloadBuffer = imageData instanceof ArrayBuffer ? imageData : new ArrayBuffer(0);
      
      console.log(`[步骤2-任务处理] payloadBuffer大小: ${payloadBuffer.byteLength}字节, 压缩方法序号: ${compressionMethodOrdinal}`);
      
      if (payloadBuffer.byteLength === 0) {
        console.warn('RemoteControlService: Empty payload buffer, skipping processing');
        return;
      }
      
      // 1. 将 payload 转换为 MemByteBuffer
      const zippedData = MemByteBuffer.fromArray(new Uint8Array(payloadBuffer));
      console.log(`[步骤2-任务处理] 创建MemByteBuffer, 大小: ${zippedData.size()}字节`);
      
      // 2. 映射压缩方法
      let squeezeMethod: SqueezeCompressionMethod = SqueezeCompressionMethod.NONE;
      switch (compressionMethodOrdinal) {
        case 1:
          squeezeMethod = SqueezeCompressionMethod.ZIP;
          break;
        case 2:
          squeezeMethod = SqueezeCompressionMethod.XZ;
          break;
        case 3:
          squeezeMethod = SqueezeCompressionMethod.ZSTD;
          break;
      }
      console.log(`[步骤2-任务处理] 映射压缩方法: ${compressionMethodOrdinal} -> ${squeezeMethod}`);
      
      // 3. 获取压缩器并解压
      const compressor = Compressor.get(squeezeMethod);
      console.log(`[步骤2-任务处理] 开始解压缩...`);
      const capture = await compressor.decompress(this.tileCache, zippedData);
      console.log(`[步骤2-任务处理] 解压缩完成, capture尺寸: ${capture.width}x${capture.height}, tile尺寸: ${capture.tileWidth}x${capture.tileHeight}, dirty tiles数量: ${capture.dirtyTiles.length}`);
      
      // 4. 组装成完整图像缓冲区
      const imageBuffer: Uint8Array = capture.createImageBuffer(
        capture.reset ? null : this.prevImageBuffer,
        capture.reset ? 0 : this.prevImageWidth,
        capture.reset ? 0 : this.prevImageHeight
      );
      
      console.log(`[步骤2-任务处理] 图像缓冲区创建完成, 大小: ${imageBuffer.length}字节 (${imageBuffer.length / 4}像素)`);
      
      // 安全检查：确保图像缓冲区有效
      if (imageBuffer.length === 0) {
        console.warn('RemoteControlService: Empty image buffer, skipping UI update');
        return;
      }
      
      // 5. 保存前一帧信息
      this.prevImageBuffer = imageBuffer;
      this.prevImageWidth = capture.width;
      this.prevImageHeight = capture.height;
      
      // 6. 传递给 UI
      if (this.screenCallback) {
        // 正确地将 Uint8Array 转换为 ArrayBuffer
        const slicedBuffer = imageBuffer.slice();
        const dataBuffer = slicedBuffer.buffer as ArrayBuffer;
        this.screenCallback(
          dataBuffer,
          capture.width,
          capture.height,
          Date.now()
        );
      }
      
      // 7. 通知缓存处理完成
      this.tileCache.onCaptureProcessed();
      
      const processingTime = Date.now() - startTime;
      if (processingTime > 100) {
        console.warn(`RemoteControlService: Processing time high: ${processingTime}ms`);
      }
    } catch (error) {
      console.error('RemoteControlService: Failed to process capture task', error);
    }
  }

  // 处理客户端信息命令
  private handleClientInfoCommand(cmd: ConcreteCmd): void {
    try {
      const cmdData = cmd.toJSON() as CmdDataJSON;
      const deviceCode = cmdData.deviceCode as string;
      const password = cmdData.password as string;
      
      console.log(`RemoteControlService: Received client info from server - deviceCode: ${deviceCode}, password: ${password}`);
      
      // 每次收到服务器分配的设备信息都更新，确保与服务器保持同步
      // 保存本地设备信息（服务器分配的）
      this.localDeviceCode = deviceCode;
      this.localPassword = password;
      
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
      
      // 如果正在验证，处理验证结果
      if (this.isValidating && this.validationCallback) {
        switch (status) {
          case 'OK':
            console.log('RemoteControlService: Device is online, validation passed');
            this.validationCallback({ valid: true, message: '设备验证成功' });
            break;
          case 'OFFLINE':
            console.error('RemoteControlService: Target device is offline');
            this.validationCallback({ valid: false, message: '目标设备离线' });
            break;
          case 'CONTROL':
            console.error('RemoteControlService: Target device is being controlled by another client');
            this.validationCallback({ valid: false, message: '目标设备正在被其他客户端控制' });
            break;
          default:
            console.error('RemoteControlService: Unknown open response status:', status);
            this.validationCallback({ valid: false, message: '验证失败，请检查设备ID' });
            break;
        }
        return;
      }
      
      // 正常处理
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
      
      // 如果正在验证，处理验证结果
      if (this.isValidating && this.validationCallback) {
        switch (status) {
          case 'OK':
            console.log('RemoteControlService: Screen capture started successfully');
            this.validationCallback({ valid: true, message: '设备验证成功' });
            break;
          case 'OFFLINE':
            console.error('RemoteControlService: Target device is offline');
            this.validationCallback({ valid: false, message: '目标设备离线' });
            break;
          case 'PWDERROR':
            console.error('RemoteControlService: Invalid password');
            this.validationCallback({ valid: false, message: '密码错误，请检查输入' });
            break;
          case 'CONTROL':
            console.error('RemoteControlService: Target device is being controlled by another client');
            this.validationCallback({ valid: false, message: '目标设备正在被其他客户端控制' });
            break;
          case 'STOP':
            console.log('RemoteControlService: Screen capture stopped');
            break;
          default:
            console.error('RemoteControlService: Unknown capture response status:', status);
            this.validationCallback({ valid: false, message: '验证失败，请检查设备ID和密码' });
            break;
        }
        return;
      }
      
      // 正常处理
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

  // 处理文本剪贴板命令
  private handleClipboardTextCommand(cmd: ConcreteCmd): void {
    try {
      const cmdData = cmd.toJSON() as CmdDataJSON;
      const text = cmdData.text as string;
      const deviceCode = cmdData.deviceCode as string;
      
      console.log(`RemoteControlService: Received clipboard text from device ${deviceCode}`);
      
      if (this.clipboardCallback) {
        this.clipboardCallback([{
          deviceCode: deviceCode,
          text: text
        }]);
      }
    } catch (error) {
      console.error('RemoteControlService: Failed to handle clipboard text command', error);
    }
  }

  // 处理文件剪贴板命令
  private handleClipboardTransferCommand(cmd: ConcreteCmd): void {
    try {
      const cmdData = cmd.toJSON() as CmdDataJSON;
      const fileInfoId = cmdData.fileInfoId as string;
      const fileName = cmdData.fileName as string;
      const deviceCode = cmdData.deviceCode as string;
      
      console.log(`RemoteControlService: Received clipboard transfer from device ${deviceCode}: ${fileName}`);
      
      if (this.clipboardCallback) {
        this.clipboardCallback([{
          deviceCode: deviceCode,
          fileInfoId: fileInfoId,
          fileName: fileName,
          isFile: 1
        }]);
      }
    } catch (error) {
      console.error('RemoteControlService: Failed to handle clipboard transfer command', error);
    }
  }

  // 处理键盘控制命令
  private handleKeyControlCommand(cmd: ConcreteCmd): void {
    try {
      const cmdData = cmd.toJSON() as CmdDataJSON;
      const keyCode = cmdData.keyCode as number;
      const pressed = cmdData.pressed as boolean;
      const deviceCode = cmdData.deviceCode as string;
      
      console.log(`RemoteControlService: Received key control from device ${deviceCode}: keyCode=${keyCode}, pressed=${pressed}`);
      
      // 这里可以添加键盘控制的处理逻辑
    } catch (error) {
      console.error('RemoteControlService: Failed to handle key control command', error);
    }
  }

  // 处理鼠标控制命令
  private handleMouseControlCommand(cmd: ConcreteCmd): void {
    try {
      const cmdData = cmd.toJSON() as CmdDataJSON;
      const x = cmdData.x as number;
      const y = cmdData.y as number;
      const action = cmdData.action as number;
      const wheelDelta = cmdData.wheelDelta as number;
      const deviceCode = cmdData.deviceCode as string;
      
      console.log(`RemoteControlService: Received mouse control from device ${deviceCode}: x=${x}, y=${y}, action=${action}`);
      
      // 这里可以添加鼠标控制的处理逻辑
    } catch (error) {
      console.error('RemoteControlService: Failed to handle mouse control command', error);
    }
  }

  // 处理屏幕捕获配置命令
  private handleCaptureConfigCommand(cmd: ConcreteCmd): void {
    try {
      const cmdData = cmd.toJSON() as CmdDataJSON;
      const fps = cmdData.fps as number;
      const quality = cmdData.quality as number;
      const width = cmdData.width as number;
      const height = cmdData.height as number;
      
      console.log(`RemoteControlService: Received capture config: fps=${fps}, quality=${quality}, width=${width}, height=${height}`);
      
      // 这里可以添加捕获配置的处理逻辑
    } catch (error) {
      console.error('RemoteControlService: Failed to handle capture config command', error);
    }
  }

  // 处理压缩配置命令
  private handleCompressorConfigCommand(cmd: ConcreteCmd): void {
    try {
      const cmdData = cmd.toJSON() as CmdDataJSON;
      const compressionMethod = cmdData.compressionMethod as number;
      const compressionLevel = cmdData.compressionLevel as number;
      
      console.log(`RemoteControlService: Received compressor config: method=${compressionMethod}, level=${compressionLevel}`);
      
      // 这里可以添加压缩配置的处理逻辑
    } catch (error) {
      console.error('RemoteControlService: Failed to handle compressor config command', error);
    }
  }

  // 处理选择屏幕命令
  private handleSelectScreenCommand(cmd: ConcreteCmd): void {
    try {
      const cmdData = cmd.toJSON() as CmdDataJSON;
      const screenIndex = cmdData.screenIndex as number;
      
      console.log(`RemoteControlService: Received select screen command: screenIndex=${screenIndex}`);
      
      // 这里可以添加选择屏幕的处理逻辑
    } catch (error) {
      console.error('RemoteControlService: Failed to handle select screen command', error);
    }
  }

  // 处理修改密码命令
  private handleChangePwdCommand(cmd: ConcreteCmd): void {
    try {
      const cmdData = cmd.toJSON() as CmdDataJSON;
      const password = cmdData.password as string;
      
      console.log('RemoteControlService: Received change password command');
      
      // 这里可以添加修改密码的处理逻辑
    } catch (error) {
      console.error('RemoteControlService: Failed to handle change password command', error);
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
    // 检查远程控制权限
    if (!this.remoteControlEnabled) {
      hilog.warn(DOMAIN, TAG, '远程控制权限未启用，忽略控制事件: %{public}s', event.type);
      return;
    }
    
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
    
    // 更新远程设备信息和控制权限
    this.remoteDeviceCode = deviceCode;
    this.remotePassword = password;
    this.remoteControlEnabled = true;
    hilog.info(DOMAIN, TAG, '远程控制权限设置: 已启用');
    
    // 只发送屏幕捕获请求 (START_CAPTURE = 0x00)
    // ReqOpen 已经在 validateDevice 中发送过了，不需要重复发送
    const captureCmd = CmdCodec.createCaptureCmd(deviceCode, password, 0);
    await this.sendCmd(captureCmd);
  }

  // 关闭远程屏幕
  async closeRemoteScreen(): Promise<void> {
    if (!this.remoteDeviceCode || !this.remotePassword) {
      console.error('RemoteControlService: Remote device info not set');
      return;
    }
    
    console.info(`RemoteControlService: Closing remote screen for device ${this.remoteDeviceCode}`);
    
    // 发送停止捕获请求 (STOP_CAPTURE = 0x01)
    const captureCmd = CmdCodec.createCaptureCmd(this.remoteDeviceCode, this.remotePassword, 1);
    await this.sendCmd(captureCmd);
  }

  // 发送鼠标控制
  async sendMouseControl(x: number, y: number, action: number, wheelDelta?: number): Promise<void> {
    if (!this.remoteDeviceCode) {
      console.error('RemoteControlService: Remote device code not set');
      return;
    }

    // 检查远程控制权限
    if (!this.remoteControlEnabled) {
      console.warn('RemoteControlService: Remote control permission denied');
      return;
    }
    
    const mouseCmd = CmdCodec.createMouseControlCmd(this.remoteDeviceCode, x, y, action, wheelDelta);
    await this.sendCmd(mouseCmd);
  }

  // 发送键盘控制
  async sendKeyControl(keyCode: number, pressed: boolean): Promise<void> {
    if (!this.remoteDeviceCode) {
      console.error('RemoteControlService: Remote device code not set');
      return;
    }

    // 检查远程控制权限
    if (!this.remoteControlEnabled) {
      console.warn('RemoteControlService: Remote control permission denied');
      return;
    }
    
    const keyCmd = CmdCodec.createKeyControlCmd(this.remoteDeviceCode, keyCode, pressed);
    await this.sendCmd(keyCmd);
  }

  // 请求剪贴板内容
  async requestClipboard(): Promise<void> {
    if (!this.remoteDeviceCode) {
      console.error('RemoteControlService: Remote device code not set');
      return;
    }
    
    const clipboardCmd = CmdCodec.createClipboardRequestCmd(this.remoteDeviceCode);
    await this.sendCmd(clipboardCmd);
  }

  // 发送文本剪贴板
  async sendClipboardText(text: string): Promise<void> {
    if (!this.remoteDeviceCode) {
      console.error('RemoteControlService: Remote device code not set');
      return;
    }
    
    const textCmd = CmdCodec.createClipboardTextCmd(this.remoteDeviceCode, text);
    await this.sendCmd(textCmd);
  }

  // 发送文件剪贴板
  async sendClipboardFile(fileInfoId: string, fileName: string): Promise<void> {
    if (!this.remoteDeviceCode) {
      console.error('RemoteControlService: Remote device code not set');
      return;
    }
    
    const fileCmd = CmdCodec.createClipboardTransferCmd(this.remoteDeviceCode, fileInfoId, fileName);
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
    
    // 通知UI连接状态更新
    if (this.connectionCallback) {
      console.info('RemoteControlService: 通知UI连接已断开');
      this.connectionCallback(false);
    }
    
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
    if (!this.localDeviceCode) {
      console.error('RemoteControlService: Local device code not set');
      throw new Error('设备信息未设置');
    }

    if (!this.socket || this.connectionState !== ConnectionState.CONNECTED) {
      console.error('RemoteControlService: Not connected');
      throw new Error('未连接到服务器');
    }

    try {
      // 创建修改密码命令
      const changePwdCmd = CmdCodec.createChangePwdCmd(this.localDeviceCode, oldPassword, newPassword);
      await this.sendCmd(changePwdCmd);
      
      // 更新本地密码
      this.localPassword = newPassword;
      console.info('RemoteControlService: Password change request sent');
    } catch (error) {
      console.error('RemoteControlService: Failed to send password change command', error);
      throw new Error(String(error));
    }
  }
  // 验证设备ID和密码
  async validateDevice(deviceCode: string, password: string): Promise<DeviceValidationResult> {
    if (!this.socket || this.connectionState !== ConnectionState.CONNECTED) {
      console.error('RemoteControlService: Not connected');
      return { valid: false, message: '未连接到服务器' };
    }

    // 防止并发验证
    if (this.isValidating) {
      console.warn('RemoteControlService: Validation already in progress');
      return { valid: false, message: '验证正在进行中，请稍后再试' };
    }

    return new Promise<DeviceValidationResult>((resolve) => {
      this.isValidating = true;
      this.validationCallback = (result: DeviceValidationResult) => {
        this.isValidating = false;
        this.validationCallback = null;
        resolve(result);
      };

      // 只发送 ReqOpen 命令验证设备是否在线
      (async () => {
        try {
          const openCmd = CmdCodec.createOpenCmd(deviceCode);
          console.log('RemoteControlService: Sending ReqOpen command for validation', deviceCode);
          await this.sendCmd(openCmd);
          console.log('RemoteControlService: Sent ReqOpen command for validation');
        } catch (error) {
          console.error('RemoteControlService: Failed to send validation command', error);
          this.isValidating = false;
          this.validationCallback = null;
          resolve({ valid: false, message: '验证失败，请检查网络连接' });
        }
      })();

      // 超时处理
      setTimeout(() => {
        if (this.isValidating) {
          this.isValidating = false;
          this.validationCallback = null;
          resolve({ valid: false, message: '验证超时，请检查网络连接' });
        }
      }, 5000);
    });
  }
}