// entry/src/main/ets/services/interfaces/IService.ets
import { ScreenImage, ConnectionState, RemoteControlEvent, Clipboard } from '../../models/DeviceInfo';
import { ClientInfoCallback, ConnectionCallback, ClipboardCallback } from '../../models/CmdProtocol';

/**
 * 设备凭据接口
 */
export interface DeviceCredentials {
  deviceCode: string;
  password: string;
}

/**
 * 设备验证结果接口
 */
export interface DeviceValidationResult {
  valid: boolean;
  message: string;
}

/**
 * 远程控制服务接口
 */
export interface IRemoteControlService {
  /**
   * 连接到服务端
   */
  connect(onSuccess: () => void, onError: (error: string) => void): Promise<void>;

  /**
   * 断开连接
   */
  disconnect(): Promise<void>;

  /**
   * 打开远程屏幕
   */
  openRemoteScreen(deviceCode: string, password: string): Promise<void>;

  /**
   * 关闭远程屏幕
   */
  closeRemoteScreen(): Promise<void>;

  /**
   * 发送控制事件
   */
  sendControlEvent(event: RemoteControlEvent): Promise<void>;

  /**
   * 发送鼠标控制
   */
  sendMouseControl(x: number, y: number, action: number, wheelDelta?: number): Promise<void>;

  /**
   * 发送键盘控制
   */
  sendKeyControl(keyCode: number, pressed: boolean): Promise<void>;

  /**
   * 请求剪贴板内容
   */
  requestClipboard(): Promise<void>;

  /**
   * 发送文本剪贴板
   */
  sendClipboardText(text: string): Promise<void>;

  /**
   * 发送文件剪贴板
   */
  sendClipboardFile(fileInfoId: string, fileName: string): Promise<void>;

  /**
   * 获取连接状态
   */
  getConnectionState(): ConnectionState;

  /**
   * 设置屏幕回调
   */
  setScreenCallback(callback: (image: ScreenImage) => void): void;

  /**
   * 设置客户端信息回调
   */
  setClientInfoCallback(callback: ClientInfoCallback): void;

  /**
   * 设置连接状态回调
   */
  setConnectionCallback(callback: ConnectionCallback): void;

  /**
   * 设置剪贴板回调
   */
  setClipboardCallback(callback: ClipboardCallback): void;

  /**
   * 设置设备信息回调
   */
  setDeviceInfoCallback(callback: (deviceCode: string, password: string) => void): void;

  /**
   * 设置设备信息（用于控制远程设备）
   */
  setDeviceInfo(deviceCode: string, password: string): void;

  /**
   * 设置远程控制权限
   */
  setRemoteControlPermission(enabled: boolean): void;

  /**
   * 验证设备ID和密码
   */
  validateDevice(deviceCode: string, password: string): Promise<DeviceValidationResult>;

  /**
   * 修改密码
   */
  changePassword(oldPassword: string, newPassword: string): Promise<void>;

  /**
   * 获取本地设备信息
   */
  getLocalDeviceInfo(): DeviceCredentials;

  /**
   * 获取远程设备信息
   */
  getRemoteDeviceInfo(): DeviceCredentials;
}

/**
 * 剪贴板服务接口
 */
export interface IClipboardService {
  /**
   * 清空剪贴板
   */
  clearClipboard(deviceCode: string): Promise<void>;

  /**
   * 保存剪贴板内容
   */
  saveClipboard(clipboards: Clipboard[]): Promise<void>;

  /**
   * 获取剪贴板内容
   */
  getClipboard(deviceCode: string): Promise<Clipboard[]>;

  /**
   * 清理资源
   */
  cleanup(): void;
}

/**
 * 文件服务接口
 */
export interface IFileService {
  /**
   * 下载文件
   */
  downloadFile(
    fileInfoId: string,
    savePath: string,
    onProgress?: (progress: number) => void
  ): Promise<void>;

  /**
   * 快速上传文件
   */
  quickUploadFile(md5: string, fileSize: number): Promise<string>;

  /**
   * 检查分片是否存在
   */
  checkChunk(md5: string, chunkNo: number, chunkSize: number): Promise<boolean>;

  /**
   * 上传文件分片
   */
  uploadFileChunk(
    chunkData: ArrayBuffer,
    md5: string,
    chunkNo: number,
    fileName: string
  ): Promise<string>;

  /**
   * 计算文件 MD5
   */
  calculateMD5(filePath: string): Promise<string>;

  /**
   * 上传大文件
   */
  uploadLargeFile(
    filePath: string,
    onProgress?: (progress: number) => void
  ): Promise<string>;

  /**
   * 删除文件
   */
  deleteFiles(fileInfoIds: string[]): Promise<void>;

  /**
   * 清理资源
   */
  cleanup(): void;
}

/**
 * 服务状态
 */
export enum ServiceState {
  UNINITIALIZED = 'uninitialized',
  INITIALIZING = 'initializing',
  READY = 'ready',
  ERROR = 'error',
  DISPOSED = 'disposed'
}