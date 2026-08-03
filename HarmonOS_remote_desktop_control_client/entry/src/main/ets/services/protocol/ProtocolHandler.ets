import { IProtocolHandler } from './IProtocolHandler';
import { ConcreteCmd } from '../../models/ConcreteCmd';
import { CmdCodec } from '../../network/CmdCodec';
import hilog from '@ohos.hilog';

const DOMAIN: number = 0xFF00;
const TAG: string = 'ProtocolHandler';

export class ProtocolHandler implements IProtocolHandler {
  private receiveBuffer: Uint8Array = new Uint8Array(0);
  private commandCallback: ((cmd: ConcreteCmd) => Promise<void>) | null = null;

  constructor() {
    hilog.info(DOMAIN, TAG, 'ProtocolHandler initialized (main thread)');
  }

  async processData(data: ArrayBuffer): Promise<ConcreteCmd[]> {
    try {
      const dataView = new Uint8Array(data);
      const oldLen = this.receiveBuffer.length;
      const newBuffer = new Uint8Array(oldLen + dataView.length);
      newBuffer.set(this.receiveBuffer, 0);
      newBuffer.set(dataView, oldLen);

      hilog.debug(DOMAIN, TAG, 'Merged buffer - existing: %{public}d, new: %{public}d, total: %{public}d',
        oldLen, dataView.length, newBuffer.length);

      const mergedData: ArrayBuffer = newBuffer.buffer as ArrayBuffer;
      const result = CmdCodec.extractCommands(mergedData);
      const remaining: ArrayBuffer = result.remainingBuffer;
      const commands: ConcreteCmd[] = result.commands;
      this.receiveBuffer = remaining.byteLength > 0 ? new Uint8Array(remaining) : new Uint8Array(0);

      hilog.debug(DOMAIN, TAG, 'Extracted %{public}d commands, remaining buffer: %{public}d bytes',
        commands.length, this.receiveBuffer.length);

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

  setCommandCallback(callback: (cmd: ConcreteCmd) => Promise<void>): void {
    this.commandCallback = callback;
  }

  getBufferSize(): number {
    return this.receiveBuffer.length;
  }

  reset(): void {
    this.receiveBuffer = new Uint8Array(0);
    hilog.info(DOMAIN, TAG, 'ProtocolHandler reset (callback preserved)');
  }

  cleanup(): void {
    this.commandCallback = null;
    this.receiveBuffer = new Uint8Array(0);
    hilog.info(DOMAIN, TAG, 'ProtocolHandler cleaned up');
  }
}
