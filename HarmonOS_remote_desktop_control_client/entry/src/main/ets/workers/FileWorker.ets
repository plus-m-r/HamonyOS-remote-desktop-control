import worker, { MessageEvent } from '@ohos.worker';
import fs from '@ohos.file.fs';
import cryptoFramework from '@ohos.security.cryptoFramework';
import { util } from '@kit.ArkTS';

// 定义消息类型
interface FileTaskMessage {
  type: 'calculateMD5';
  filePath: string;
}

interface ResultMessage {
  type: 'result';
  success: boolean;
  data?: string;
  error?: string;
}

// 初始化Worker
const workerPort = worker.workerPort;

// 处理消息
workerPort.onmessage = (message: MessageEvent<FileTaskMessage>) => {
  const data: FileTaskMessage = message.data;

  if (data.type === 'calculateMD5') {
    calculateMD5(data.filePath)
      .then(result => {
        const response: ResultMessage = {
          type: 'result',
          success: true,
          data: result
        };
        workerPort.postMessage(response);
      })
      .catch((error: Error) => {
        const response: ResultMessage = {
          type: 'result',
          success: false,
          error: error.message
        };
        workerPort.postMessage(response);
      });
  }
};

/**
 * 计算文件 MD5
 * @param filePath 文件路径
 * @returns Promise<string> MD5值
 */
async function calculateMD5(filePath: string): Promise<string> {
  const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
  const stat = fs.statSync(filePath);
  const fileSize = stat.size;

  const md = cryptoFramework.createMd('SHA256');
  const buffer = new ArrayBuffer(1024 * 1024); // 1MB buffer

  let offset = 0;
  while (offset < fileSize) {
    const readSize = Math.min(buffer.byteLength, fileSize - offset);
    const data = fs.readSync(file.fd, buffer, { offset: 0, length: readSize });
    if (data > 0) {
      await md.update({ data: new Uint8Array(buffer, 0, data) });
      offset += data;
    } else {
      break;
    }
  }

  fs.closeSync(file);
  const result = await md.digest();
  const base64Helper = new util.Base64Helper();
  return base64Helper.encodeToStringSync(result.data);
}