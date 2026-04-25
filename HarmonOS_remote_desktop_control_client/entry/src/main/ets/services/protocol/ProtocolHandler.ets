import { IProtocolHandler } from './IProtocolHandler';
import { ConcreteCmd } from '../../models/ConcreteCmd';
import { CmdCodec } from '../../network/CmdCodec';
import hilog from '@ohos.hilog';

const DOMAIN: number = 0xFF00;
const TAG: string = 'ProtocolHandler';

/**
 * 协议处理器实现
 * 职责：只负责解析命令，不处理视频流
 * 
 * 架构说明：
 * - 所有协议解析在主线程完成（无需 Worker）
 * - 使用 CmdCodec.extractCommands 进行命令提取
 */
export class ProtocolHandler implements IProtocolHandler {
  private receiveBuffer: ArrayBuffer = new ArrayBuffer(0);
  private commandCallback: ((cmd: ConcreteCmd) => Promise<void>) | null = null;

  constructor() {
    hilog.info(DOMAIN, TAG, 'ProtocolHandler initialized (main thread)');
  }

  /**
   * 处理接收到的数据，只解析命令
   * @param data 接收到的数据
   * @returns 解析出的命令数组
   */
  async processData(data: ArrayBuffer): Promise<ConcreteCmd[]> {
    try {
      // 合并缓冲区
      const mergedBuffer = new ArrayBuffer(this.receiveBuffer.byteLength + data.byteLength);
      const mergedView = new Uint8Array(mergedBuffer);
      mergedView.set(new Uint8Array(this.receiveBuffer), 0);
      mergedView.set(new Uint8Array(data), this.receiveBuffer.byteLength);

      hilog.debug(DOMAIN, TAG, 'Merged buffer - existing: %{public}d, new: %{public}d, total: %{public}d',
        this.receiveBuffer.byteLength, data.byteLength, mergedBuffer.byteLength);

      // 提取命令
      const result = CmdCodec.extractCommands(mergedBuffer);
      this.receiveBuffer = result[0];
      const commands = result[1];

      hilog.debug(DOMAIN, TAG, 'Extracted %{public}d commands, remaining buffer: %{public}d bytes',
        commands.length, this.receiveBuffer.byteLength);

      // 调用回调处理每个命令
      for (let i = 0; i < commands.length; i++) {
        const cmd = commands[i];
        hilog.info(DOMAIN, TAG, 'Parsed command: %{public}s, id=%{public}d', cmd.type, cmd.id);

        if (this.commandCallback) {
          await this.commandCallback(cmd);
        }
      }

      return commands;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to process data: %{public}s', JSON.stringify(error));
      return [];
    }
  }

  /**
   * 设置命令回调
   */
  setCommandCallback(callback: (cmd: ConcreteCmd) => Promise<void>): void {
    this.commandCallback = callback;
  }

  /**
   * 获取累积的缓冲区大小（用于调试）
   */
  getBufferSize(): number {
    return this.receiveBuffer.byteLength;
  }

  /**
   * 清理资源
   */
  cleanup(): void {
    this.commandCallback = null;
    this.receiveBuffer = new ArrayBuffer(0);
    hilog.info(DOMAIN, TAG, 'ProtocolHandler cleaned up');
  }
}
