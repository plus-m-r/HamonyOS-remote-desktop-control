import { ConcreteCmd } from '../../models/ConcreteCmd';

/**
 * 协议处理器接口
 * 职责：只负责解析命令，不处理视频流
 */
export interface IProtocolHandler {
  /**
   * 处理接收到的数据，只解析命令
   * @param data 接收到的数据
   * @returns 解析出的命令数组
   */
  processData(data: ArrayBuffer): Promise<ConcreteCmd[]>;

  /**
   * 设置命令回调
   */
  setCommandCallback(callback: (cmd: ConcreteCmd) => Promise<void>): void;

  /**
   * 获取累积的缓冲区大小（用于调试）
   */
  getBufferSize(): number;

  /**
   * 清理资源
   */
  cleanup(): void;
}
