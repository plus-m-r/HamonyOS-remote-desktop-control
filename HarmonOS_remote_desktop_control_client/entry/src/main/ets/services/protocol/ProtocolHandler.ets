import { IProtocolHandler } from './IProtocolHandler';
import { ConcreteCmd } from '../../models/ConcreteCmd';
import { IWorkerRepository, ProtocolParseTask, ProtocolParseResult } from '../../repository/IWorkerRepository';
import hilog from '@ohos.hilog';

const DOMAIN: number = 0xFF00;
const TAG: string = 'ProtocolHandler';

/**
 * 协议解析结果
 */
export interface ProtocolParseResultData {
  commands: ConcreteCmd[];
  remainingBuffer: ArrayBuffer;
}

/**
 * 协议处理器实现
 * 负责协议解析，不处理视频流
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
      const parseTask: ProtocolParseTask = {
        existingBuffer: this.receiveBuffer,
        newData: data
      };
      const result: ProtocolParseResult = await this.workerRepository.parseProtocol(parseTask);

      this.receiveBuffer = result.remainingBuffer;

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
   * 获取视频流数据（无法解析为命令的数据）
   * 返回 null 表示没有视频流数据
   */
  async processDataAndCheckVideo(data: ArrayBuffer, frameCallback: (data: ArrayBuffer) => void): Promise<void> {
    try {
      const parseTask: ProtocolParseTask = {
        existingBuffer: this.receiveBuffer,
        newData: data
      };
      const result: ProtocolParseResult = await this.workerRepository.parseProtocol(parseTask);

      this.receiveBuffer = result.remainingBuffer;

      if (result.commands.length > 0) {
        for (let i = 0; i < result.commands.length; i++) {
          const cmdObj = result.commands[i];
          const cmd = ConcreteCmd.fromObject(cmdObj);
          hilog.info(DOMAIN, TAG, 'Processing command: %{public}s', cmd.type);
          if (this.commandCallback) {
            await this.commandCallback(cmd);
          }
        }
      } else {
        hilog.info(DOMAIN, TAG, 'ProtocolHandler: Received video stream data, length: %{public}d', data.byteLength);
        frameCallback(data);
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
