import worker, { MessageEvent } from '@ohos.worker';
import { MemByteBuffer } from '../squeeze/MemByteBuffer';
import { Compressor, CompressionMethod } from '../squeeze/Compressor';
import { TileCache, NullTileCache } from '../squeeze/TileCache';
import { Capture } from '../squeeze/Capture';

const TAG = '[CaptureWorker]';

// 定义消息类型
interface CaptureTask {
  imageData: ArrayBuffer | string;
  compressionMethodOrdinal: number;
  prevBuffer: ArrayBuffer | null;
  prevWidth: number;
  prevHeight: number;
}

interface CaptureTaskMessage {
  type: 'processImage';
  task: CaptureTask;
  taskId: number;
}

interface ImageDataResult {
  imageBuffer: ArrayBuffer;
  width: number;
  height: number;
  frameId: number;
  isKeyFrame: boolean;
  tileCount: number;
}

interface ResultMessage {
  type: 'imageResult';
  taskId: number;
  success: boolean;
  data?: ImageDataResult;
  error?: string;
}

interface ResetCacheMessage {
  type: 'resetCache';
}

// 初始化 Worker
const workerPort = worker.workerPort;

// Worker 内部状态 - 只管理 TileCache（用于解压缩），不管理帧缓存
let tileCache: TileCache = new NullTileCache();

// 处理消息
workerPort.onmessage = (message: MessageEvent<CaptureTaskMessage | ResetCacheMessage>) => {
  const data = message.data;

  if (data.type === 'processImage') {
    const msg = data as CaptureTaskMessage;
    const taskId = msg.taskId;

    processCaptureTask(msg.task)
      .then(result => {
        const response: ResultMessage = {
          type: 'imageResult',
          taskId: taskId,
          success: true,
          data: result
        };
        workerPort.postMessage(response);
      })
      .catch((error: Error) => {
        const response: ResultMessage = {
          type: 'imageResult',
          taskId: taskId,
          success: false,
          error: error.message
        };
        workerPort.postMessage(response);
      });
  } else if (data.type === 'resetCache') {
    // 只重置 TileCache，不管理帧缓存
    tileCache = new NullTileCache();
    workerPort.postMessage({ type: 'cacheReset' });
  }
};

/**
 * 处理捕获任务
 * 在 Worker 线程中执行，负责：
 * 1. 解压数据得到 Capture 对象
 * 2. 复用 prevBuffer 或创建新缓冲区
 * 3. 将 dirty tiles 绘制到缓冲区
 *
 * 注意：帧缓存（prevBuffer）由主线程的 CaptureProcessor 管理并传递
 * 这样即使 Worker 重启，帧缓存也不会丢失
 */
async function processCaptureTask(task: CaptureTask): Promise<ImageDataResult> {
  const imageData = task.imageData;
  const compressionMethodOrdinal = task.compressionMethodOrdinal;
  const prevBuffer = task.prevBuffer;
  const prevWidth = task.prevWidth;
  const prevHeight = task.prevHeight;

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

  // 4. 决定是否复用 prevBuffer
  const width = capture.width;
  const height = capture.height;
  const bufferSize = width * height * 4;
  const reset = capture.reset;

  let imageBuffer: Uint8Array;

  if (!reset && prevBuffer !== null && prevWidth === width && prevHeight === height) {
    // 增量帧且尺寸匹配：复用 prevBuffer
    imageBuffer = new Uint8Array(prevBuffer);
  } else {
    // 完整帧或尺寸不匹配：创建新缓冲区
    imageBuffer = new Uint8Array(bufferSize);
  }

  // 5. 将 dirty tiles 绘制到缓冲区
  capture.drawToBuffer(imageBuffer);

  // 6. 通知缓存处理完成
  tileCache.onCaptureProcessed();

  // 统计处理的瓦片数
  const tileCount = capture.dirtyTiles.filter(t => t !== null).length;

  console.info(`${TAG} Processed frame ${capture.id}: ${width}x${height}, ${tileCount} tiles, reset=${reset}, reused=${!reset && prevBuffer !== null && prevWidth === width && prevHeight === height}`);

  return {
    imageBuffer: imageBuffer.buffer as ArrayBuffer,
    width: width,
    height: height,
    frameId: capture.id,
    isKeyFrame: reset,
    tileCount: tileCount
  };
}
