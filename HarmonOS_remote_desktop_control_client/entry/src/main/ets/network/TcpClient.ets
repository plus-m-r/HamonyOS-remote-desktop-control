
// entry/src/main/ets/network/TcpClient.ets
import socket from '@ohos.net.socket';
import { Cmd } from '../models/CmdProtocol';
import { CmdCodec } from './CmdCodec';

export class TcpClient {
  private tcpSocket: socket.TCPSocket;
  private serverIp: string;
  private serverPort: number;
  private messageHandler: (data: ArrayBuffer) => void;
  private isConnectedFlag: boolean = false;
  private reconnectTimer: number | undefined;
  private maxReconnectAttempts: number = 5;
  private reconnectAttempts: number = 0;
  private reconnectInterval: number = 5000; // 5秒
  private heartbeatTimer: number | undefined;
  private heartbeatInterval: number = 3000; // 3秒，与Java客户端保持一致
  private successCallback: (() => void) | undefined;
  private errorCallback: ((error: string) => void) | undefined;
  
  constructor(serverIp: string, serverPort: number, messageHandler: (data: ArrayBuffer) => void) {
    this.serverIp = serverIp;
    this.serverPort = serverPort;
    this.messageHandler = messageHandler;
    this.tcpSocket = socket.constructTCPSocketInstance();
    this.setupSocketListeners();
  }
  
  private setupSocketListeners(): void {
    // 设置错误回调
    this.tcpSocket.on('error', (error) => {
      console.error('TcpClient: Socket error:', error);
      this.isConnectedFlag = false;
      this.attemptReconnect();
    });
    
    // 设置关闭回调
    this.tcpSocket.on('close', () => {
      console.log('TcpClient: Socket closed');
      this.isConnectedFlag = false;
      this.attemptReconnect();
    });
  }
  
  public connect(successCallback: () => void, errorCallback: (error: string) => void): void {
    this.successCallback = successCallback;
    this.errorCallback = errorCallback;
    this.reconnectAttempts = 0;
    
    this.actualConnect();
  }
  
  private actualConnect(): void {
    this.tcpSocket.connect({
      address: {
        family: 1, // AF_INET
        address: this.serverIp,
        port: this.serverPort
      }
    }, (err) => {
      if (err) {
        console.error('TcpClient: Connection failed:', err);
        this.isConnectedFlag = false;
        this.attemptReconnect();
        return;
      }
      
      console.log('TcpClient: Connected to server');
      this.isConnectedFlag = true;
      this.reconnectAttempts = 0;
      
      // 设置消息接收回调
      this.tcpSocket.on('message', (data) => {
        this.messageHandler(data);
      });
      
      // 启动心跳定时器
      this.startHeartbeat();
      
      if (this.successCallback) {
        this.successCallback();
      }
    });
  }
  
  /**
   * 启动心跳定时器
   */
  private startHeartbeat(): void {
    // 清除之前的定时器
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
    }
    
    // 每3秒发送一次心跳
    this.heartbeatTimer = setInterval(() => {
      if (this.isConnectedFlag) {
        this.sendHeartbeat();
      }
    }, this.heartbeatInterval);
  }
  
  /**
   * 发送心跳请求
   */
  private sendHeartbeat(): void {
    try {
      // 创建心跳请求命令
      const pingCmd = CmdCodec.createPingCmd();
      // 发送心跳请求
      this.send(pingCmd);
      console.log('TcpClient: Sent heartbeat');
    } catch (error) {
      console.error('TcpClient: Failed to send heartbeat:', error);
      this.isConnectedFlag = false;
      this.attemptReconnect();
    }
  }
  
  private attemptReconnect(): void {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error('TcpClient: Max reconnect attempts reached');
      if (this.errorCallback) {
        this.errorCallback('Max reconnect attempts reached');
      }
      return;
    }
    
    this.reconnectAttempts++;
    console.log(`TcpClient: Attempting to reconnect (${this.reconnectAttempts}/${this.maxReconnectAttempts})`);
    
    // 清除之前的定时器
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
    }
    
    // 延迟重连
    this.reconnectTimer = setTimeout(() => {
      // 重新创建socket实例
      this.tcpSocket = socket.constructTCPSocketInstance();
      this.setupSocketListeners();
      this.actualConnect();
    }, this.reconnectInterval);
  }
  
  public send(data: any): void {
    if (!this.isConnectedFlag) {
      console.error('TcpClient: Not connected, cannot send data');
      return;
    }
    
    try {
      let buffer: ArrayBuffer;
      
      if (data instanceof ArrayBuffer) {
        // 如果已经是 ArrayBuffer，直接发送
        buffer = data;
      } else if (data instanceof Cmd) {
        // 如果是 Cmd 对象，使用 CmdCodec 编码
        buffer = CmdCodec.encode(data);
      } else {
        // 不支持其他类型的数据
        console.error('TcpClient: Unsupported data type');
        return;
      }
      
      this.tcpSocket.send({
        data: buffer
      }, (err, bytesSent) => {
        if (err) {
          console.error('TcpClient: Send failed:', err);
          this.isConnectedFlag = false;
          this.attemptReconnect();
        } else {
          console.log(`TcpClient: Sent ${bytesSent} bytes`);
        }
      });
    } catch (error) {
      console.error('TcpClient: Failed to send data:', error);
      this.isConnectedFlag = false;
      this.attemptReconnect();
    }
  }
  
  public disconnect(): void {
    // 清除重连定时器
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = undefined;
    }
    
    // 清除心跳定时器
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = undefined;
    }
    
    try {
      this.tcpSocket.close();
    } catch (error) {
      console.error('TcpClient: Failed to disconnect:', error);
    }
    
    this.isConnectedFlag = false;
  }
  
  public isConnected(): boolean {
    // 返回实际的连接状态
    return this.isConnectedFlag;
  }
}
