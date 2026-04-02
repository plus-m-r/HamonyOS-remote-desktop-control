import { IConnectionManager } from './IConnectionManager';
import { ConnectionState } from '../../models/DeviceInfo';
import { ITcpRepository, TcpConnectionConfig, TcpConnectionState, TcpErrorCallback } from '../../repository/ITcpRepository';
import { BusinessError } from '@ohos.base';
import hilog from '@ohos.hilog';

const DOMAIN: number = 0xFF00;
const TAG: string = 'ConnectionManager';

/**
 * 连接管理器实现
 * 负责管理 TCP 连接的生命周期
 */
export class ConnectionManager implements IConnectionManager {
  private tcpRepository: ITcpRepository;
  private connectionState: ConnectionState = ConnectionState.DISCONNECTED;
  private reconnectAttempts: number = 0;
  private maxReconnectAttempts: number = 3;
  private reconnectDelay: number = 2000;

  // 配置
  private host: string;
  private port: number;

  // 回调
  private connectionCallback: ((connected: boolean) => void) | null = null;
  private messageCallback: ((data: ArrayBuffer) => void) | null = null;
  private errorCallback: ((error: Error) => void) | null = null;

  constructor(
    host: string,
    port: number,
    tcpRepository: ITcpRepository,
    maxReconnectAttempts: number = 3,
    reconnectDelay: number = 2000
  ) {
    this.host = host;
    this.port = port;
    this.tcpRepository = tcpRepository;
    this.maxReconnectAttempts = maxReconnectAttempts;
    this.reconnectDelay = reconnectDelay;

    this.setupTcpCallbacks();
    hilog.info(DOMAIN, TAG, 'ConnectionManager initialized');
  }

  /**
   * 设置 TCP 回调
   */
  private setupTcpCallbacks(): void {
    // 消息接收
    this.tcpRepository.onMessage((data: ArrayBuffer) => {
      if (this.messageCallback) {
        this.messageCallback(data);
      }
    });

    // 错误处理
    this.tcpRepository.onError((error: BusinessError) => {
      hilog.error(DOMAIN, TAG, 'TCP error: %{public}s', JSON.stringify(error));
      if (this.errorCallback) {
        this.errorCallback(new Error(error.message));
      }
      this.handleDisconnect();
    });

    // 状态变更
    this.tcpRepository.onStateChange((state: TcpConnectionState) => {
      hilog.info(DOMAIN, TAG, 'TCP state changed to %{public}s', state);

      switch (state) {
        case TcpConnectionState.CONNECTED:
          this.connectionState = ConnectionState.CONNECTED;
          this.reconnectAttempts = 0;
          break;
        case TcpConnectionState.DISCONNECTED:
          this.connectionState = ConnectionState.DISCONNECTED;
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

  /**
   * 连接到服务端
   */
  async connect(): Promise<void> {
    try {
      this.connectionState = ConnectionState.CONNECTING;

      const tcpConfig: TcpConnectionConfig = {
        host: this.host,
        port: this.port,
        connectTimeout: 10000,
        readTimeout: 30000,
        writeTimeout: 30000
      };

      await this.tcpRepository.connect(tcpConfig);
    } catch (error) {
      this.connectionState = ConnectionState.ERROR;
      this.handleReconnect();
      const err = error instanceof Error ? error : new Error(String(error));
      throw err;
    }
  }

  /**
   * 断开连接
   */
  async disconnect(): Promise<void> {
    this.reconnectAttempts = 0;
    await this.tcpRepository.disconnect();
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
  setConnectionCallback(callback: (connected: boolean) => void): void {
    this.connectionCallback = callback;
  }

  /**
   * 设置消息接收回调
   */
  setMessageCallback(callback: (data: ArrayBuffer) => void): void {
    this.messageCallback = callback;
  }

  /**
   * 设置错误回调
   */
  setErrorCallback(callback: (error: Error) => void): void {
    this.errorCallback = callback;
  }

  /**
   * 发送数据
   */
  async send(data: ArrayBuffer): Promise<void> {
    if (this.connectionState !== ConnectionState.CONNECTED) {
      throw new Error('Not connected to server');
    }
    await this.tcpRepository.send(data);
  }

  /**
   * 处理断开连接
   */
  private handleDisconnect(): void {
    this.handleReconnect();
  }

  /**
   * 处理重连
   */
  private handleReconnect(): void {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      hilog.error(DOMAIN, TAG, 'Max reconnection attempts reached');
      return;
    }

    this.reconnectAttempts++;
    hilog.info(DOMAIN, TAG, 'Reconnecting... attempt %{public}d', this.reconnectAttempts);

    setTimeout(() => {
      this.connect().catch((error: Error) => {
        hilog.error(DOMAIN, TAG, 'Reconnection failed: %{public}s', JSON.stringify(error));
      });
    }, this.reconnectDelay);
  }

  /**
   * 清理资源
   */
  cleanup(): void {
    this.connectionCallback = null;
    this.messageCallback = null;
    this.errorCallback = null;
    hilog.info(DOMAIN, TAG, 'ConnectionManager cleaned up');
  }
}
