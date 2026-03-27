import worker from '@ohos.worker';
import { MemByteBuffer } from '../squeeze/MemByteBuffer';
import { Compressor, CompressionMethod } from '../squeeze/Compressor';
import { TileCache, NullTileCache } from '../squeeze/TileCache';
import { Capture } from '../squeeze/Capture';

// 定义消息类型
interface CaptureTaskMessage {
  type: 'capture';
  task: {
    imageData: ArrayBuffer | string;
    compressionMethodOrdinal: number;
  };
}

interface ResultMessage {
  type: 'result';
  success: boolean;
  data?: {
    imageBuffer: ArrayBuffer;
    width: number;
    height: number;
  };
  error?: string;
}

// 初始化Worker
const workerPort = worker.workerPort;

// 初始化tileCache
let tileCache: TileCache = new NullTileCache();

// 处理消息
workerPort.onmessage = (message: MessageEvent) => {
  const data = message.data as CaptureTaskMessage;
  
  if (data.type === 'capture') {
    processCaptureTask(data.task)
      .then(result => {
        const response: ResultMessage = {
          type: 'result',
          success: true,
          data: result
        };
        workerPort.postMessage(response);
      })
      .catch(error => {
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
 * 处理捕获任务
 * @param task 捕获任务
 * @returns Promise<{imageBuffer: ArrayBuffer, width: number, height: number}>
 */
async function processCaptureTask(task: {
  imageData: ArrayBuffer | string;
  compressionMethodOrdinal: number;
}): Promise<{imageBuffer: ArrayBuffer, width: number, height: number}> {
  const imageData = task.imageData;
  const compressionMethodOrdinal = task.compressionMethodOrdinal;
  
  const payloadBuffer = imageData instanceof ArrayBuffer ? imageData : new ArrayBuffer(0);
  
  if (payloadBuffer.byteLength === 0) {
    throw new Error('Empty payload buffer');
  }
  
  // 1. 将 payload 转换为 MemByteBuffer
  const zippedData = MemByteBuffer.fromArray(new Uint8Array(payloadBuffer));
  
  // 2. 映射压缩方法
  let squeezeMethod: CompressionMethod = CompressionMethod.NONE;
  switch (compressionMethodOrdinal) {
    case 1:
      squeezeMethod = CompressionMethod.ZIP;
      break;
    case 2:
      squeezeMethod = CompressionMethod.XZ;
      break;
    case 3:
      squeezeMethod = CompressionMethod.ZSTD;
      break;
  }
  
  // 3. 获取压缩器并解压
  const compressor = Compressor.get(squeezeMethod);
  const capture = await compressor.decompress(tileCache, zippedData);
  
  // 4. 组装成完整图像缓冲区
  const imageBuffer: Uint8Array = capture.createImageBuffer(null, 0, 0);
  
  // 5. 通知缓存处理完成
  tileCache.onCaptureProcessed();
  
  return {
    imageBuffer: imageBuffer.buffer as ArrayBuffer,
    width: capture.width,
    height: capture.height
  };
}
