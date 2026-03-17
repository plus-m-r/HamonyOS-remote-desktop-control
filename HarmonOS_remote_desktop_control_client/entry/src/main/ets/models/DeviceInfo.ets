// 设备信息模型
export interface DeviceInfo {
  deviceCode: string;
  name: string;
  status: 'online' | 'offline';
  lastSeen: string;
  ipAddress?: string;
}

// 剪贴板数据模型
export interface Clipboard {
  id?: string;              // 剪贴板记录ID
  deviceCode: string;       // 设备代码
  fileInfoId?: string;      // 文件信息ID（仅文件剪贴板有效）
  fileName?: string;        // 文件名（仅文件剪贴板有效）
  filePid?: string;         // 文件父ID（仅文件剪贴板有效）
  isFile?: number;          // 是否为文件剪贴板（0: 文本, 1: 文件）
  content?: string;         // 文本内容（仅文本剪贴板有效，客户端本地使用）
  type?: string;            // 类型标识（客户端本地使用）
  createTime?: string;      // 创建时间（客户端本地使用）
}

// 文件信息模型
export interface FileInfo {
  fileInfoId: string;
  fileName: string;
  fileSize: number;
  md5: string;
  uploadTime?: string;
}

// 远程控制事件
export interface RemoteControlEvent {
  type: 'touch' | 'keyboard' | 'mouse';
  action: 'down' | 'move' | 'up' | 'press' | 'release';
  x?: number;
  y?: number;
  keyCode?: number;
  button?: number;
  timestamp: number;
}

// 屏幕图像数据
export interface ScreenImage {
  data: ArrayBuffer;
  width: number;
  height: number;
  timestamp: number;
}

// 连接状态
export enum ConnectionState {
  DISCONNECTED = 'disconnected',
  CONNECTING = 'connecting',
  CONNECTED = 'connected',
  ERROR = 'error'
}

// 用户信息
export interface UserInfo {
  id: string;
  name: string;
  email?: string;
  avatar?: string;
  licenseType: 'free' | 'paid';
}

// 会话信息
export interface SessionInfo {
  sessionId: string;
  localDeviceId: string;
  remoteDeviceId: string;
  startTime: number;
  status: 'active' | 'paused' | 'ended';
}