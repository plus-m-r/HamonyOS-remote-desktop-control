
// entry/src/main/ets/network/TcpClient.ets
import socket from '@ohos.net.socket';
import { Cmd } from '../models/CmdProtocol';
import { CmdCodec } from './CmdCodec';

export class TcpClient {
  private tcpSocket: socket.TCPSocket;
  private serverIp: string;
  private serverPort: number;
  private messageHandler: (data: ArrayBuffer) => void;
  
  constructor(serverIp: string, serverPort: number, messageHandler: (data: ArrayBuffer) => void) {
    this.serverIp = serverIp;
    this.serverPort = serverPort;
    this.messageHandler = messageHandler;
    this.tcpSocket = socket.constructTCPSocketInstance();
  }
  
  public connect(successCallback: () => void, errorCallback: (error: string) => void): void {
    this.tcpSocket.connect({
      address: {
        family: 1, // AF_INET
        address: this.serverIp,
        port: this.serverPort
      }
    }, (err) => {
      if (err) {
        errorCallback(JSON.stringify(err));
        return;
      }
      
      // 设置消息接收回调
      this.tcpSocket.on('message', (data) => {
        this.messageHandler(data);
      });
      
      successCallback();
    });
  }
  
  public send(data: any): void {
    try {
      let buffer: ArrayBuffer;
      
      if (data instanceof ArrayBuffer) {
        // 如果已经是 ArrayBuffer，直接发送
        buffer = data;
      } else if (data instanceof Cmd) {
        // 如果是 Cmd 对象，使用 CmdCodec 编码
        buffer = CmdCodec.encode(data);
      } else {
        // 如果是普通对象，转换为 JSON 字符串
        const jsonStr = JSON.stringify(data);
        buffer = this.stringToBuffer(jsonStr);
      }
      
      this.tcpSocket.send({
        data: buffer
      }, (err, bytesSent) => {
        if (err) {
          console.error('TcpClient: Send failed:', err);
        } else {
          console.log(`TcpClient: Sent ${bytesSent} bytes`);
        }
      });
    } catch (error) {
      console.error('TcpClient: Failed to send data:', error);
    }
  }
  
  private stringToBuffer(str: string): ArrayBuffer {
    const len = str.length;
    const buffer = new ArrayBuffer(len * 2);
    const view = new Uint16Array(buffer);
    for (let i = 0; i < len; i++) {
      view[i] = str.charCodeAt(i);
    }
    return buffer;
  }
  
  public disconnect(): void {
    this.tcpSocket.close();
  }
  
  public isConnected(): boolean {
    // 检查连接状态
    return true; // 实际实现需要根据 HarmonyOS API 检查
  }
}
