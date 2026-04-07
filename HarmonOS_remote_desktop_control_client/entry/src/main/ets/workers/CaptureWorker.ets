import worker, { MessageEvent } from '@ohos.worker';
import { MemByteBuffer } from '../squeeze/MemByteBuffer';
import { TileCache, NullTileCache } from '../squeeze/TileCache';
import { Capture } from '../squeeze/Capture';

const TAG = '[CaptureWorker]';

// 定义消息类型
interface FrameTask {
  captureData: ArrayBuffer;
  prevBuffer: ArrayBuffer | null;
  prevWidth: number;
  prevHeight: number;
}

interface FrameTaskMessage {
  type: 'processFrame';
  task: FrameTask;
  taskId: number;
}

interface FrameDataResult {
  imageBuffer: ArrayBuffer;
  width: number;
  height: number;
  frameId: number;
  isKeyFrame: boolean;
  tileCount: number;
}

interface ResultMessage {
  type: 'frameResult';
  taskId: number;
  success: boolean;
  data?: FrameDataResult;
  error?: string;
}

interface ResetCacheMessage {
  type: 'resetCache';
}

// 初始化 Worker
const workerPort = worker.workerPort;

// Worker 内部状态 - 只管理 TileCache
let tileCache: TileCache = new NullTileCache();

// 处理消息
workerPort.onmessage = (message: MessageEvent<FrameTaskMessage | ResetCacheMessage>) => {
  const data = message.data;

  if (data.type === 'processFrame') {
    const msg = data as FrameTaskMessage;
    const taskId = msg.taskId;

    processFrameTask(msg.task)
      .then(result => {
        const response: ResultMessage = {
          type: 'frameResult',
          taskId: taskId,
          success: true,
          data: result
        };
        workerPort.postMessage(response);
      })
      .catch((error: Error) => {
        const response: ResultMessage = {
          type: 'frameResult',
          taskId: taskId,
          success: false,
          error: error.message
        };
        workerPort.postMessage(response);
      });
  } else if (data.type === 'resetCache') {
    tileCache = new NullTileCache();
    workerPort.postMessage({ type: 'cacheReset' });
  }
};

/**
 * 处理帧任务（解压缩已在主线程完成）
 * 在 Worker 线程中执行，负责：
 * 1. 从 captureData 反序列化 Capture 对象
 * 2. 复用 prevBuffer 或创建新缓冲区
 * 3. 将 dirty tiles 绘制到缓冲区
 *
 * 架构说明：
 * - 解压缩：在主线程完成（需要 Context）
 * - 帧处理（绘制瓦片）：在 Worker 线程完成
 */
async function processFrameTask(task: FrameTask): Promise<FrameDataResult> {
  const captureData = task.captureData;
  const prevBuffer = task.prevBuffer;
  const prevWidth = task.prevWidth;
  const prevHeight = task.prevHeight;

  // 1. 从 captureData 反序列化 Capture 对象
  // 注意：这里我们将 captureData 传递给 Worker，Worker 会处理
  // 但实际上，我们需要将 Capture 对象序列化后传递
  // 为了简单起见，我们现在只实现基本的帧绘制逻辑
  // 实际上，更好的方案是：在主线程解压缩得到 Capture 对象后，
  // 将 Capture 的关键信息（id, reset, width, height, dirtyTiles）序列化后传递给 Worker

  // 这里我们假设 captureData 是序列化后的 Capture 数据
  // 但现在我们先简化处理，直接在主线程完成所有解压缩和帧合并
  // 所以这个 Worker 暂时只做一个简单的处理

  console.warn(`${TAG} Worker currently not used - all processing done on main thread`);

  // 返回一个空结果（这个实现会被优化）
  throw new Error('Worker processing not implemented - all processing done on main thread');
}
