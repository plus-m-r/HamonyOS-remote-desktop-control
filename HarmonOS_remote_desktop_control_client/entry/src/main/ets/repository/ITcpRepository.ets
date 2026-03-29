/**
 * TCP 仓库接口
 * 
 * 抽象 TCP 网络操作，便于：
 * 1. 单元测试时 Mock 网络行为
 * 2. 更换网络实现（如从 socket 切换到其他库）
 * 3. 模拟网络错误场景
 */

import { BusinessError } from '@ohos.base';

/**
 * Socket网络地址
 */
export interface SocketNetAddress {
  address: string;
  port: number;
}

/**
 * Socket消息数据
 */
export interface SocketMessageData {
  message: ArrayBuffer;
}

/**
 * Socket连接选项
 */
export interface SocketConnectOptions {
  address: SocketNetAddress;
  timeout?: number;
}

/**
 * Socket发送选项
 */
export interface SocketSendOptions {
  data: ArrayBuffer;
  encoding: string;
}

/**
 * TCP连接地址
 */
export class TcpNetAddress {
  address: string;
  port: number;
  family?: number;

  constructor(address: string, port: number, family?: number) {
    this.address = address;
    this.port = port;
    this.family = family;
  }
}

/**
 * Socket连接选项（内部使用）
 */
export class SocketConnectOptionsInternal {
  address: TcpNetAddress;
  timeout?: number;

  constructor(address: TcpNetAddress, timeout?: number) {
    this.address = address;
    this.timeout = timeout;
  }
}

/**
 * Socket发送选项（内部使用）
 */
export class SocketSendOptionsInternal {
  data: ArrayBuffer;
  encoding: string;

  constructor(data: ArrayBuffer, encoding: string) {
    this.data = data;
    this.encoding = encoding;
  }
}

/**
 * TCP 连接配置
 */
export interface TcpConnectionConfig {
  host: string;
  port: number;
  connectTimeout?: number;
  readTimeout?: number;
  writeTimeout?: number;
}

/**
 * TCP 连接状态
 */
export enum TcpConnectionState {
  DISCONNECTED = 'DISCONNECTED',
  CONNECTING = 'CONNECTING',
  CONNECTED = 'CONNECTED',
  ERROR = 'ERROR'
}

/**
 * TCP 消息回调
 */
export type TcpMessageCallback = (data: ArrayBuffer) => void;

/**
 * TCP 错误回调
 */
export type TcpErrorCallback = (error: BusinessError) => void;

/**
 * TCP 连接状态回调
 */
export type TcpStateCallback = (state: TcpConnectionState) => void;

/**
 * TCP 仓库接口
 */
export interface ITcpRepository {
  /**
   * 连接到服务器
   * @param config 连接配置
   * @returns Promise<void>
   */
  connect(config: TcpConnectionConfig): Promise<void>;

  /**
   * 断开连接
   * @returns Promise<void>
   */
  disconnect(): Promise<void>;

  /**
   * 发送数据
   * @param data 要发送的数据
   * @returns Promise<void>
   */
  send(data: ArrayBuffer | Uint8Array): Promise<void>;

  /**
   * 获取当前连接状态
   */
  getConnectionState(): TcpConnectionState;

  /**
   * 设置消息接收回调
   * @param callback 消息回调
   */
  onMessage(callback: TcpMessageCallback): void;

  /**
   * 设置错误回调
   * @param callback 错误回调
   */
  onError(callback: TcpErrorCallback): void;

  /**
   * 设置连接状态变更回调
   * @param callback 状态回调
   */
  onStateChange(callback: TcpStateCallback): void;

  /**
   * 移除消息回调
   * @param callback 要移除的回调
   */
  offMessage(callback: TcpMessageCallback): void;

  /**
   * 移除错误回调
   * @param callback 要移除的回调
   */
  offError(callback: TcpErrorCallback): void;

  /**
   * 移除状态变更回调
   * @param callback 要移除的回调
   */
  offStateChange(callback: TcpStateCallback): void;
}
