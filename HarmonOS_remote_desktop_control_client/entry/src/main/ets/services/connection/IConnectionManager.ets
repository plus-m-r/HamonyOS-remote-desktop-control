import { ConnectionState } from '../../models/DeviceInfo';
import { TcpConnectionState } from '../../repository/ITcpRepository';

/**
 * 连接管理器接口
 * 负责管理 TCP 连接的生命周期
 */
export interface IConnectionManager {
  /**
   * 连接到服务端
   */
  connect(): Promise<void>;

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
  setConnectionCallback(callback: (connected: boolean) => void): void;

  /**
   * 设置消息接收回调
   */
  setMessageCallback(callback: (data: ArrayBuffer) => void): void;

  /**
   * 设置错误回调
   */
  setErrorCallback(callback: (error: Error) => void): void;

  /**
   * 发送数据
   */
  send(data: ArrayBuffer): Promise<void>;

  /**
   * 清理资源
   */
  cleanup(): void;
}
