// entry/src/main/ets/services/interfaces/IService.ets
import { DeviceInfo, ScreenImage, ConnectionState, RemoteControlEvent, Clipboard } from '../../models/DeviceInfo';

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
  openRemoteScreen(deviceCode: string, password: string): void;

  /**
   * 发送控制事件
   */
  sendControlEvent(event: RemoteControlEvent): void;

  /**
   * 获取连接状态
   */
  getConnectionState(): ConnectionState;

  /**
   * 设置屏幕回调
   */
  setScreenCallback(callback: (image: ScreenImage) => void): void;
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