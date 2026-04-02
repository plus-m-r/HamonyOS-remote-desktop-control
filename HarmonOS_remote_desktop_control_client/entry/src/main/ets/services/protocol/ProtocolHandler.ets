import { IProtocolHandler } from './IProtocolHandler';
import { ConcreteCmd } from '../../models/ConcreteCmd';
import { IWorkerRepository, ProtocolParseTask, ProtocolParseResult } from '../../repository/IWorkerRepository';
import hilog from '@ohos.hilog';

const DOMAIN: number = 0xFF00;
const TAG: string = 'ProtocolHandler';

/**
 * 协议处理器实现
 * 负责协议解析和命令处理
 */
export class ProtocolHandler implements IProtocolHandler {
  private workerRepository: IWorkerRepository;
  private receiveBuffer: ArrayBuffer = new ArrayBuffer(0);
  private commandCallback: ((cmd: ConcreteCmd) => Promise<void>) | null = null;

  constructor(workerRepository: IWorkerRepository) {
    this.workerRepository = workerRepository;
    this.workerRepository.init();
    hilog.info(DOMAIN, TAG, 'ProtocolHandler initialized');
  }

  /**
   * 处理接收到的数据
   */
  async processData(data: ArrayBuffer): Promise<void> {
    try {
      // 使用 Worker 解析协议
      const parseTask: ProtocolParseTask = {
        existingBuffer: this.receiveBuffer,
        newData: data
      };
      const result: ProtocolParseResult = await this.workerRepository.parseProtocol(parseTask);

      this.receiveBuffer = result.remainingBuffer;

      // 处理解析出的命令
      for (let i = 0; i < result.commands.length; i++) {
        const cmdObj = result.commands[i];
        const cmd = ConcreteCmd.fromObject(cmdObj);
        hilog.info(DOMAIN, TAG, 'Processing command: %{public}s', cmd.type);
        if (this.commandCallback) {
          await this.commandCallback(cmd);
        }
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to process data: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 设置命令回调
   */
  setCommandCallback(callback: (cmd: ConcreteCmd) => Promise<void>): void {
    this.commandCallback = callback;
  }

  /**
   * 清理资源
   */
  cleanup(): void {
    this.workerRepository.destroy();
    this.commandCallback = null;
    this.receiveBuffer = new ArrayBuffer(0);
    hilog.info(DOMAIN, TAG, 'ProtocolHandler cleaned up');
  }
}
