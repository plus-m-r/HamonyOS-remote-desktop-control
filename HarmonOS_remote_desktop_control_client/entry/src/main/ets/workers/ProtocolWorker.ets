import worker, { MessageEvent } from '@ohos.worker';
import { CmdCodec } from '../network/CmdCodec';
import { ConcreteCmd } from '../models/ConcreteCmd';

// 定义消息类型
interface ProtocolTaskData {
  existingBuffer: ArrayBuffer;
  newData: ArrayBuffer;
}

interface ProtocolTaskMessage {
  type: 'parseProtocol';
  task: ProtocolTaskData;
  taskId: number;
}

interface ProcessMessageResult {
  remainingBuffer: ArrayBuffer;
  commands: Record<string, Object>[];
}

interface ResultMessage {
  type: 'protocolResult';
  taskId: number;
  success: boolean;
  data?: ProcessMessageResult;
  error?: string;
}

// Worker内部状态（复用，不随任务销毁）
let receiveBuffer: ArrayBuffer = new ArrayBuffer(0);

// 初始化Worker
const workerPort = worker.workerPort;

// 处理消息
workerPort.onmessage = (message: MessageEvent<ProtocolTaskMessage>) => {
  const data: ProtocolTaskMessage = message.data;
  const taskId = data.taskId;

  if (data.type === 'parseProtocol') {
    processMessage(data.task.existingBuffer, data.task.newData)
      .then(result => {
        const response: ResultMessage = {
          type: 'protocolResult',
          taskId: taskId,
          success: true,
          data: result
        };
        workerPort.postMessage(response);
      })
      .catch((error: Error) => {
        const response: ResultMessage = {
          type: 'protocolResult',
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
 * @returns Promise<{remainingBuffer: ArrayBuffer, commands: Record<string, Object>[]}>
 */
async function processMessage(existingBuffer: ArrayBuffer, newData: ArrayBuffer): Promise<ProcessMessageResult> {
  // 合并缓冲区
  const mergedBuffer = new ArrayBuffer(existingBuffer.byteLength + newData.byteLength);
  const mergedView = new Uint8Array(mergedBuffer);
  mergedView.set(new Uint8Array(existingBuffer), 0);
  mergedView.set(new Uint8Array(newData), existingBuffer.byteLength);

  console.info('ProtocolWorker: Merged buffer - existing: ' + existingBuffer.byteLength + ', new: ' + newData.byteLength + ', total: ' + mergedBuffer.byteLength);

  // 输出前16个字节的16进制值，用于调试
  if (mergedBuffer.byteLength > 0) {
    const firstBytes = new Uint8Array(mergedBuffer.slice(0, Math.min(16, mergedBuffer.byteLength)));
    const hexStr = Array.from(firstBytes).map(b => b.toString(16).padStart(2, '0')).join(' ');
    console.info('ProtocolWorker: First 16 bytes (hex): ' + hexStr);
    console.info('ProtocolWorker: First byte (decimal): ' + firstBytes[0] + ', expected 100 (0x64)');
  }

  // 提取命令
  const result = CmdCodec.extractCommands(mergedBuffer);

  console.info('ProtocolWorker: Extracted ' + result[1].length + ' commands, remaining: ' + result[0].byteLength);

  // 转换为纯对象数组
  const commandObjects: Record<string, Object>[] = [];
  for (let i = 0; i < result[1].length; i++) {
    const cmd = result[1][i];
    commandObjects.push(cmd.toJSON());
    console.info('ProtocolWorker: Command ' + i + ': type=' + cmd.type + ', id=' + cmd.id);
  }

  return {
    remainingBuffer: result[0],
    commands: commandObjects
  };
}