/**
 * Netty 命令协议定义
 * 与服务端 io.github.springstudent.dekstop.server.core.protocol.cmd 包下的命令结构匹配
 */

// 命令类型枚举
export enum CmdType {
  // 客户端信息相关
  ResCliInfo = 'ResCliInfo',       // 服务器返回客户端信息
  ReqCliInfo = 'ReqCliInfo',       // 客户端请求发送客户端信息
  ChangePwd = 'ChangePwd',         // 客户端修改密码
  
  // 连接相关
  ReqPing = 'ReqPing',             // 客户端发送心跳
  ResPong = 'ResPong',             // 服务器返回心跳响应
  
  // 远程控制相关
  ReqOpen = 'ReqOpen',             // 请求打开远程连接
  ResOpen = 'ResOpen',             // 服务器返回打开连接结果
  ReqCapture = 'ReqCapture',       // 请求开始/停止屏幕捕获
  ResCapture = 'ResCapture',       // 服务器返回捕获结果
  Capture = 'Capture',             // 屏幕捕获数据
  SelectScreen = 'SelectScreen',   // 选择屏幕
  
  // 控制相关
  MouseControl = 'MouseControl',   // 鼠标控制
  KeyControl = 'KeyControl',       // 键盘控制
  CaptureConfig = 'CaptureConfig', // 捕获配置
  CompressorConfig = 'CompressorConfig', // 压缩配置
  
  // 剪贴板相关
  ReqRemoteClipboard = 'ReqRemoteClipboard', // 请求远程剪贴板
  ResRemoteClipboard = 'ResRemoteClipboard', // 服务器返回剪贴板内容
  ClipboardText = 'ClipboardText', // 文本剪贴板
  ClipboardTransfer = 'ClipboardTransfer' // 文件剪贴板传输
}

// 鼠标动作枚举
export enum MouseAction {
  MOVE = 1,        // 移动
  LEFT_CLICK = 2,  // 左键点击
  RIGHT_CLICK = 3, // 右键点击
  WHEEL = 4        // 滚轮
}

// 打开连接状态枚举
export type OpenStatus = 'OK' | 'OFFLINE' | 'CONTROL';

// 捕获状态枚举
export type CaptureStatus = 'OK' | 'OFFLINE' | 'PWDERROR' | 'CONTROL' | 'STOP';

// 压缩方法枚举
export enum CompressionMethod {
  ZSTD = 1,
  XZ = 2,
  ZIP = 3
}

// ==================== 基础命令接口 ====================

// 基础命令接口
export interface Cmd {
  type: CmdType;
  id: string;
}

// ==================== 客户端信息相关命令 ====================

// 服务器返回客户端信息
export interface CmdResCliInfo extends Cmd {
  type: CmdType.ResCliInfo;
  deviceCode: string;
  password: string;
}

// 客户端修改密码
export interface CmdChangePwd extends Cmd {
  type: CmdType.ChangePwd;
  password: string;
}

// ==================== 连接相关命令 ====================

// 心跳请求
export interface CmdReqPing extends Cmd {
  type: CmdType.ReqPing;
}

// 心跳响应
export interface CmdResPong extends Cmd {
  type: CmdType.ResPong;
}

// ==================== 远程控制相关命令 ====================

// 请求打开远程连接
export interface CmdReqOpen extends Cmd {
  type: CmdType.ReqOpen;
  deviceCode: string;
}

// 打开连接响应
export interface CmdResOpen extends Cmd {
  type: CmdType.ResOpen;
  status: OpenStatus;
}

// 请求屏幕捕获
export interface CmdReqCapture extends Cmd {
  type: CmdType.ReqCapture;
  deviceCode: string;
  password: string;
  caputureOp: 0 | 1;  // 0: 停止, 1: 开始
}

// 捕获响应
export interface CmdResCapture extends Cmd {
  type: CmdType.ResCapture;
  status: CaptureStatus;
}

// 屏幕捕获数据
export interface CmdCapture extends Cmd {
  type: CmdType.Capture;
  deviceCode: string;
  imageData: ArrayBuffer;
  width: number;
  height: number;
  x: number;
  y: number;
}

// 选择屏幕
export interface CmdSelectScreen extends Cmd {
  type: CmdType.SelectScreen;
  screenIndex: number;
}

// ==================== 控制相关命令 ====================

// 鼠标控制
export interface CmdMouseControl extends Cmd {
  type: CmdType.MouseControl;
  deviceCode: string;
  x: number;
  y: number;
  action: MouseAction;
  wheelDelta?: number;
}

// 键盘控制
export interface CmdKeyControl extends Cmd {
  type: CmdType.KeyControl;
  deviceCode: string;
  keyCode: number;
  pressed: boolean;
}

// 捕获配置
export interface CmdCaptureConfig extends Cmd {
  type: CmdType.CaptureConfig;
  deviceCode: string;
  fps: number;
  quality: number;
  width: number;
  height: number;
}

// 压缩配置
export interface CmdCompressorConfig extends Cmd {
  type: CmdType.CompressorConfig;
  deviceCode: string;
  compressionMethod: CompressionMethod;
  compressionLevel: number;
}

// ==================== 剪贴板相关命令 ====================

// 剪贴板数据结构
export interface ClipboardData {
  id?: string;
  deviceCode: string;
  fileInfoId?: string;
  fileName?: string;
  filePid?: string;
  isFile?: number;
}

// 请求远程剪贴板
export interface CmdReqRemoteClipboard extends Cmd {
  type: CmdType.ReqRemoteClipboard;
  deviceCode: string;
}

// 剪贴板响应
export interface CmdResRemoteClipboard extends Cmd {
  type: CmdType.ResRemoteClipboard;
  clipboards: ClipboardData[];
}

// 文本剪贴板
export interface CmdClipboardText extends Cmd {
  type: CmdType.ClipboardText;
  deviceCode: string;
  text: string;
}

// 文件剪贴板传输
export interface CmdClipboardTransfer extends Cmd {
  type: CmdType.ClipboardTransfer;
  deviceCode: string;
  fileInfoId: string;
  fileName: string;
}

// ==================== 客户端信息 ====================

// 客户端信息
export interface ClientInfo {
  deviceCode: string;
  password: string;
}

// ==================== 回调类型 ====================

// 屏幕数据回调
export type ScreenCallback = (capture: CmdCapture) => void;

// 客户端信息回调
export type ClientInfoCallback = (info: ClientInfo) => void;

// 连接状态回调
export type ConnectionCallback = (connected: boolean, error?: string) => void;

// 剪贴板回调
export type ClipboardCallback = (clipboards: ClipboardData[]) => void;