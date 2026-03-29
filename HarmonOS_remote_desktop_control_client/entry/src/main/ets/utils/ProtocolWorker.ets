import worker from '@ohos.worker';
import { CmdCodec } from '../network/CmdCodec';
import { ConcreteCmd } from '../models/ConcreteCmd';

// 定义消息类型
interface ProtocolTaskMessage {
  type: 'processMessage';
  existingBuffer: ArrayBuffer;
  newData: ArrayBuffer;
  taskId: number;
}

interface ResultMessage {
  type: 'result';
  taskId: number;
  success: boolean;
  data?: {
    remainingBuffer: ArrayBuffer;
    commands: ConcreteCmd[];
  };
  error?: string;
}

// Worker内部状态（复用，不随任务销毁）
let receiveBuffer: ArrayBuffer = new ArrayBuffer(0);

// 初始化Worker
const workerPort = worker.workerPort;

// 处理消息
workerPort.onmessage = (message: MessageEvent) => {
  const data = message.data as ProtocolTaskMessage;
  const taskId = data.taskId;

  if (data.type === 'processMessage') {
    processMessage(data.existingBuffer, data.newData)
      .then(result => {
        const response: ResultMessage = {
          type: 'result',
          taskId: taskId,
          success: true,
          data: result
        };
        workerPort.postMessage(response);
      })
      .catch(error => {
        const response: ResultMessage = {
          type: 'result',
          taskId: taskId,
          success: false,
          error: error.message
        };
        workerPort.postMessage(response);
      });
  }
};

/**
 * 处理消息：合并缓冲区并提取命令
 * @param existingBuffer 现有缓冲区
 * @param newData 新接收的数据
 * @returns Promise<{remainingBuffer: ArrayBuffer, commands: ConcreteCmd[]}>
 */
async function processMessage(existingBuffer: ArrayBuffer, newData: ArrayBuffer): Promise<{ remainingBuffer: ArrayBuffer; commands: ConcreteCmd[] }> {
  // 合并缓冲区
  const newBuffer = new ArrayBuffer(existingBuffer.byteLength + newData.byteLength);
  const newView = new Uint8Array(newBuffer);
  newView.set(new Uint8Array(existingBuffer), 0);
  newView.set(new Uint8Array(newData), existingBuffer.byteLength);

  // 提取命令
  const result = CmdCodec.extractCommands(newBuffer);
  
  return {
    remainingBuffer: result[0],
    commands: result[1]
  };
}
