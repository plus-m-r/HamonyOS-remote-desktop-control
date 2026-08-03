/**
 * TCP 仓库实现
 *
 * 实现 ITcpRepository 接口，使用 HarmonyOS socket 模块
 */

import {
  ITcpRepository,
  TcpConnectionConfig,
  TcpConnectionState,
  TcpMessageCallback,
  TcpErrorCallback,
  TcpStateCallback,
  SocketNetAddress,
  SocketMessageData,
  SocketConnectOptions,
  SocketSendOptions,
  SocketConnectOptionsInternal,
  SocketSendOptionsInternal,
  TcpNetAddress
} from './ITcpRepository';
import { socket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';

export class TcpRepositoryImpl implements ITcpRepository {
  private tcpSocket: socket.TCPSocket | null = null;
  private state: TcpConnectionState = TcpConnectionState.DISCONNECTED;
  private messageCallbacks: Set<TcpMessageCallback> = new Set();
  private errorCallbacks: Set<TcpErrorCallback> = new Set();
  private stateCallbacks: Set<TcpStateCallback> = new Set();

  async connect(config: TcpConnectionConfig): Promise<void> {
    return new Promise(async (resolve, reject) => {
      try {
        // 重连前彻底清理旧 socket，避免旧连接残留事件（close/error）干扰新连接状态
        if (this.tcpSocket) {
          try {
            this.tcpSocket.off('connect');
            this.tcpSocket.off('message');
            this.tcpSocket.off('error');
            this.tcpSocket.off('close');
            this.tcpSocket.close();
          } catch (e) {
            console.warn('TcpRepositoryImpl: cleanup old socket failed', e);
          }
          this.tcpSocket = null;
        }

        this.setState(TcpConnectionState.CONNECTING);

        // 创建 TCP Socket
        this.tcpSocket = socket.constructTCPSocketInstance();

        // 绑定本地地址
        const bindAddress: socket.NetAddress = {
          address: '0.0.0.0',
          port: 0 // 让系统自动分配端口
        };
        await this.tcpSocket.bind(bindAddress);

        // 设置连接回调
        this.tcpSocket.on('connect', () => {
          console.info('TcpRepositoryImpl: Connected to server');
          this.setState(TcpConnectionState.CONNECTED);
          resolve();
        });

        // 设置消息接收回调
        this.tcpSocket.on('message', (data: SocketMessageData) => {
          console.info('TcpRepositoryImpl: Received message', data.message.byteLength);
          this.notifyMessage(data.message);
        });

        // 设置错误回调
        this.tcpSocket.on('error', (error: BusinessError) => {
          console.error('TcpRepositoryImpl: Socket error', error);
          this.notifyError(error);
          this.setState(TcpConnectionState.ERROR);
          reject(error);
        });

        // 设置关闭回调
        this.tcpSocket.on('close', () => {
          console.info('TcpRepositoryImpl: Socket closed');
          this.setState(TcpConnectionState.DISCONNECTED);
        });

        // 连接到服务器
        const serverAddress = new TcpNetAddress(
          config.host,
          config.port
        );

        const connectOptions = new SocketConnectOptionsInternal(
          serverAddress,
          config.connectTimeout || 10000
        );

        await this.tcpSocket.connect(connectOptions);

      } catch (error) {
        console.error('TcpRepositoryImpl: Failed to connect', error);
        this.setState(TcpConnectionState.ERROR);
        reject(error);
      }
    });
  }

  async disconnect(): Promise<void> {
    if (this.tcpSocket) {
      try {
        await this.tcpSocket.close();
      } catch (error) {
        console.error('TcpRepositoryImpl: Error closing socket', error);
      }
      this.tcpSocket = null;
    }
    this.setState(TcpConnectionState.DISCONNECTED);
  }

  async send(data: ArrayBuffer | Uint8Array): Promise<void> {
    if (!this.tcpSocket) {
      throw new Error('Socket not connected');
    }

    if (this.state !== TcpConnectionState.CONNECTED) {
      throw new Error('Not connected');
    }

    try {
      const buffer = data instanceof Uint8Array ? data.buffer : data;
      const sendOptions: socket.TCPSendOptions = {
        data: buffer,
        encoding: 'buffer'
      };
      console.info(`TcpRepositoryImpl: Sending ${buffer.byteLength} bytes`);
      const sent = await this.tcpSocket.send(sendOptions);
      console.info(`TcpRepositoryImpl: Send ok, result=${String(sent)}`);
    } catch (error) {
      console.error('TcpRepositoryImpl: Failed to send data', error);
      throw new Error(String(error));
    }
  }

  getConnectionState(): TcpConnectionState {
    return this.state;
  }

  onMessage(callback: TcpMessageCallback): void {
    this.messageCallbacks.add(callback);
  }

  onError(callback: TcpErrorCallback): void {
    this.errorCallbacks.add(callback);
  }

  onStateChange(callback: TcpStateCallback): void {
    this.stateCallbacks.add(callback);
  }

  offMessage(callback: TcpMessageCallback): void {
    this.messageCallbacks.delete(callback);
  }

  offError(callback: TcpErrorCallback): void {
    this.errorCallbacks.delete(callback);
  }

  offStateChange(callback: TcpStateCallback): void {
    this.stateCallbacks.delete(callback);
  }

  private setState(state: TcpConnectionState): void {
    this.state = state;
    this.notifyStateChange(state);
  }

  private notifyMessage(data: ArrayBuffer): void {
    this.messageCallbacks.forEach(callback => {
      try {
        callback(data);
      } catch (error) {
        console.error('TcpRepositoryImpl: Message callback error', error);
      }
    });
  }

  private notifyError(error: BusinessError): void {
    this.errorCallbacks.forEach(callback => {
      try {
        callback(error);
      } catch (e) {
        console.error('TcpRepositoryImpl: Error callback error', e);
      }
    });
  }

  private notifyStateChange(state: TcpConnectionState): void {
    this.stateCallbacks.forEach(callback => {
      try {
        callback(state);
      } catch (error) {
        console.error('TcpRepositoryImpl: State callback error', error);
      }
    });
  }
}
