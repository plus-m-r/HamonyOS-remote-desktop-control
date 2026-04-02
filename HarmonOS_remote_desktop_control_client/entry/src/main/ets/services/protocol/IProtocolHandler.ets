import { ConcreteCmd } from '../../models/ConcreteCmd';

/**
 * 协议处理器接口
 * 负责协议解析和命令处理
 */
export interface IProtocolHandler {
  /**
   * 处理接收到的数据
   */
  processData(data: ArrayBuffer): Promise<void>;

  /**
   * 设置命令回调
   */
  setCommandCallback(callback: (cmd: ConcreteCmd) => Promise<void>): void;

  /**
   * 清理资源
   */
  cleanup(): void;
}
