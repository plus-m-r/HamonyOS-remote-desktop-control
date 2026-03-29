// IRemoteControlService.ets - 远程控制服务接口
// 定义远程控制服务的契约，便于解耦和测试

import { ConnectionState, RemoteControlEvent, DeviceValidationResult } from '../../models/DeviceInfo';
import { ClientInfoCallback, ConnectionCallback, ClipboardCallback } from '../../models/CmdProtocol';
import { ITcpRepository } from '../../repository/ITcpRepository';
import { IWorkerRepository } from '../../repository/IWorkerRepository';
import { IHeartbeatManager } from './IHeartbeatManager';

/**
 * 远程控制服务配置
 */
export interface RemoteControlServiceConfig {
  host: string;
  port: number;
  maxReconnectAttempts: number;
  reconnectDelay: number;
  heartbeatInterval: number;
}

/**
 * 远程控制服务依赖
 */
export interface RemoteControlServiceDependencies {
  tcpRepository: ITcpRepository;
  workerRepository: IWorkerRepository;
  heartbeatManager: IHeartbeatManager;
}

/**
 * 设备凭据接口
 */
export interface DeviceCredentials {
  deviceCode: string;
  password: string;
}

/**
 * 屏幕数据回调类型
 */
export type ScreenCallback = (data: ArrayBuffer, width: number, height: number, timestamp: number) => void;

/**
 * 设备信息回调类型
 */
export type DeviceInfoCallback = (deviceCode: string, password: string) => void;

/**
 * 远程控制服务接口
 * 定义远程控制服务的完整契约
 */
export interface IRemoteControlService {
  // ========== 连接管理 ==========

  /**
   * 连接到服务端
   * @param onSuccess 连接成功回调
   * @param onError 连接失败回调
   */
  connect(onSuccess?: () => void, onError?: (error: string) => void): Promise<void>;

  /**
   * 断开连接
   */
  disconnect(): Promise<void>;

  /**
   * 获取连接状态
   */
  getConnectionState(): ConnectionState;

  /**
   * 设置连接状态回调
   */
  setConnectionCallback(callback: ConnectionCallback): void;

  // ========== 远程屏幕控制 ==========

  /**
   * 打开远程屏幕
   * @param deviceCode 设备代码
   * @param password 密码
   */
  openRemoteScreen(deviceCode: string, password: string): Promise<void>;

  /**
   * 关闭远程屏幕
   */
  closeRemoteScreen(): void;

  /**
   * 设置屏幕数据回调
   */
  setScreenCallback(callback: ScreenCallback): void;

  // ========== 输入控制 ==========

  /**
   * 发送控制事件
   * @param event 控制事件
   */
  sendControlEvent(event: RemoteControlEvent): Promise<void>;

  /**
   * 发送鼠标控制
   * @param x X坐标
   * @param y Y坐标
   * @param action 动作类型
   * @param wheelDelta 滚轮增量（可选）
   */
  sendMouseControl(x: number, y: number, action: number, wheelDelta?: number): Promise<void>;

  /**
   * 发送键盘控制
   * @param keyCode 按键码
   * @param pressed 是否按下
   */
  sendKeyControl(keyCode: number, pressed: boolean): Promise<void>;

  // ========== 设备信息 ==========

  /**
   * 设置设备信息回调
   */
  setDeviceInfoCallback(callback: DeviceInfoCallback): void;

  /**
   * 设置设备信息
   * @param deviceCode 设备代码
   * @param password 密码
   */
  setDeviceInfo(deviceCode: string, password: string): void;

  /**
   * 获取本地设备信息
   */
  getLocalDeviceInfo(): DeviceCredentials;

  /**
   * 获取远程设备信息
   */
  getRemoteDeviceInfo(): DeviceCredentials;

  // ========== 权限控制 ==========

  /**
   * 设置远程控制权限
   * @param enabled 是否启用
   */
  setRemoteControlPermission(enabled: boolean): void;

  /**
   * 验证设备
   * @param deviceCode 设备代码
   * @param password 密码
   */
  validateDevice(deviceCode: string, password: string): Promise<DeviceValidationResult>;

  // ========== 剪贴板 ==========

  /**
   * 请求剪贴板内容
   */
  requestClipboard(): Promise<void>;

  /**
   * 发送文本剪贴板
   * @param text 文本内容
   */
  sendClipboardText(text: string): Promise<void>;

  /**
   * 发送文件剪贴板
   * @param fileInfoId 文件信息ID
   * @param fileName 文件名
   */
  sendClipboardFile(fileInfoId: string, fileName: string): Promise<void>;

  /**
   * 设置剪贴板回调
   */
  setClipboardCallback(callback: ClipboardCallback): void;

  // ========== 密码管理 ==========

  /**
   * 修改密码
   * @param oldPassword 旧密码
   * @param newPassword 新密码
   */
  changePassword(oldPassword: string, newPassword: string): Promise<void>;

  // ========== 生命周期 ==========

  /**
   * 清理资源
   */
  cleanup(): void;
}
