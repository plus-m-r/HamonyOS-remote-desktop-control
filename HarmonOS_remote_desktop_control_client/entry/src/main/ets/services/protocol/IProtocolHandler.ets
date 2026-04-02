import { ConcreteCmd } from '../../models/ConcreteCmd';

/**
 * 协议处理器接口
 * 负责协议解析，不处理视频流
 */
export interface IProtocolHandler {
  /**
   * 处理接收到的数据
   */
  processData(data: ArrayBuffer): Promise<void>;

  /**
   * 处理数据并检查是否有视频流
   * @param data 收到的数据
   * @param onVideoStream 视频流回调（当无法解析为命令时触发）
   */
  processDataAndCheckVideo(data: ArrayBuffer, onVideoStream: (data: ArrayBuffer) => void): Promise<void>;

  /**
   * 设置命令回调
   */
  setCommandCallback(callback: (cmd: ConcreteCmd) => Promise<void>): void;

  /**
   * 清理资源
   */
  cleanup(): void;
}
