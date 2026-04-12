import hilog from '@ohos.hilog';
import { MemByteBuffer } from './MemByteBuffer';
import { CaptureTile } from './CaptureTile';
import { Capture } from './Capture';

import { RunLengthEncoder, NullRunLengthEncoder, RegularRunLengthEncoder } from './RunLengthEncoder';
import { Zipper, ZstdZipper } from './Zipper';
import { XYWH, getXYWH } from './XYWH';

const DOMAIN: number = 0xFF00;
const TAG: string = 'Compressor';

export enum CompressionMethod {
  NONE = 0,
  ZIP = 1,
  XZ = 2,
  ZSTD = 3
}

export class Compressor {
  private static readonly ZSTD_COMPRESSOR: Compressor = new Compressor(
    CompressionMethod.ZSTD,
    new RegularRunLengthEncoder(),
    new ZstdZipper()
  );
  private static loggedDecompressData: boolean = false;

  readonly method: CompressionMethod;
  private readonly rle: RunLengthEncoder;
  private readonly zipper: Zipper;
  
  // 缓存上次的尺寸参数和XYWH数组，避免重复计算
  private lastCaptureWidth: number = -1;
  private lastCaptureHeight: number = -1;
  private lastTileWidth: number = -1;
  private lastTileHeight: number = -1;
  private lastXywhArray: XYWH[] = [];

  private constructor(method: CompressionMethod, rle: RunLengthEncoder, zipper: Zipper) {
    this.method = method;
    this.rle = rle;
    this.zipper = zipper;
  }

  static get(method: CompressionMethod): Compressor {
    switch (method) {
      case CompressionMethod.ZSTD:
        return Compressor.ZSTD_COMPRESSOR;
      default:
        throw new Error(`Unsupported compressor configuration [${method}]! Only ZSTD is supported.`);
    }
  }

  /**
   * 解压并处理压缩数据，将其转换为Capture对象
   * @param zipped 压缩的字节缓冲区
   * @returns 处理后的Capture对象
   */
  async decompress(zipped: MemByteBuffer): Promise<Capture> {
    // 1. 使用ZSTD算法解压数据
    const unzipped = await this.zipper.unzip(zipped);

    // 2. 重置读取指针到缓冲区开始位置
    unzipped.reset();

    // 3. 读取元数据
    const cId = unzipped.readInt(); // 捕获ID
    const cReset = unzipped.readByte() === 1; // 是否重置缓存

    const cSkipped = unzipped.readUnsignedByte(); // 跳过的帧数
    const cMerged = unzipped.readUnsignedByte(); // 合并的帧数
    
    // 保存当前位置以便调试
    const debugPos = unzipped.getReadOffset();
    
    // 读取捕获的尺寸信息
    const captureWidth = unzipped.readShort(); // 捕获宽度
    const captureHeight = unzipped.readShort(); // 捕获高度
    const tileWidth = unzipped.readShort(); // 瓦片宽度
    const tileHeight = unzipped.readShort(); // 瓦片高度
    
    // 打印尺寸信息，用于调试
    hilog.error(DOMAIN, TAG, 'captureWidth=%{public}d, captureHeight=%{public}d, tileWidth=%{public}d, tileHeight=%{public}d', captureWidth, captureHeight, tileWidth, tileHeight);
    hilog.error(DOMAIN, TAG, 'Read at offset=%{public}d', debugPos);

    // 4. 计算所有瓦片的位置和大小（使用缓存优化）
    let xywhArray: XYWH[];
    if (captureWidth === this.lastCaptureWidth && 
        captureHeight === this.lastCaptureHeight && 
        tileWidth === this.lastTileWidth && 
        tileHeight === this.lastTileHeight) {
      // 使用缓存的XYWH数组
      xywhArray = this.lastXywhArray;
    } else {
      // 计算新的XYWH数组
      xywhArray = getXYWH(captureWidth, captureHeight, tileWidth, tileHeight);
      // 更新缓存
      this.lastCaptureWidth = captureWidth;
      this.lastCaptureHeight = captureHeight;
      this.lastTileWidth = tileWidth;
      this.lastTileHeight = tileHeight;
      this.lastXywhArray = xywhArray;
    }
    // 初始化瓦片数组，用于存储处理后的瓦片数据
    const dirty: (CaptureTile | null)[] = new Array(xywhArray.length).fill(null);

    let idx = 0; // 当前处理的瓦片索引

    // 5. 循环处理每个瓦片
    while (idx < dirty.length) {
      // 读取markerCount，表示连续有效瓦片的数量（正数）或跳过瓦片的数量（负数）
      const markerCount = unzipped.readByte();

      if (markerCount > 0) {
        // 处理连续的有效瓦片
        for (let tidx = idx; tidx < idx + markerCount; tidx++) {
          if (tidx >= dirty.length) {
            break; // 防止越界
          }

          // 读取瓦片值，用于判断瓦片类型
          const value = unzipped.readShort();

          // 确保瓦片的位置和大小信息存在
          if (!xywhArray[tidx]) {
            hilog.error(DOMAIN, TAG, 'xywhArray[tidx] is undefined: tidx=%{public}d, array length=%{public}d', tidx, xywhArray.length);
            continue;
          }

          // 根据value值处理不同类型的瓦片
          if (value >= 0 && value < 256) {
            // 单级瓦片：value是颜色索引
            dirty[tidx] = CaptureTile.fromSingleLevel(xywhArray[tidx], value);
          } else if (value === 256) {
            // 缓存瓦片：由于移除了缓存，创建一个空瓦片
            unzipped.readInt(); // 跳过cacheId
            dirty[tidx] = null;
          } else if (value > 256) {
            // 非缓存的多级瓦片：value是正数，dataLength就是value
            this.processUncached(unzipped, xywhArray[tidx], dirty, tidx, -value);
          } else {
            // 其他情况：value是负数，dataLength是其绝对值
            this.processUncached(unzipped, xywhArray[tidx], dirty, tidx, value);
          }
        }
        // 更新瓦片索引
        idx += markerCount;
      } else {
        // 跳过瓦片：markerCount为负数，计算跳过的数量
        const skipCount = -markerCount + 1;
        for (let i = 0; i < skipCount && idx < dirty.length; i++) {
          dirty[idx++] = null; // 将跳过的瓦片设为null
        }
      }
    }

    // 6. 创建Capture对象，包含所有处理后的信息
    const capture = new Capture(cId, cReset, cSkipped, cMerged, captureWidth, captureHeight, tileWidth, tileHeight, dirty);
    
    // 7. 返回处理后的Capture对象
    return capture;
  }

  /**
   * 处理非缓存的瓦片数据
   * @param unzipped 解压后的字节缓冲区
   * @param xywh 瓦片的位置和大小信息
   * @param dirty 瓦片数组，用于存储处理后的瓦片
   * @param tidx 当前处理的瓦片索引
   * @param value 瓦片数据长度信息（负数）
   */
  private processUncached(unzipped: MemByteBuffer, xywh: XYWH, dirty: (CaptureTile | null)[], tidx: number, value: number): void {
    // 1. 计算瓦片数据长度（value是负数，取其绝对值）
    const dataLength = -value;
    
    // 2. 检查数据长度是否有效（> 0 且 <= 1MB）
    if (dataLength <= 0 || dataLength > 1024 * 1024) { // 添加上限检查，防止过大的数据
      // 数据长度无效，跳过处理
      hilog.error(DOMAIN, TAG, 'processUncached: invalid dataLength: %{public}d (value: %{public}d)', dataLength, value);
      return;
    }
    
    // 3. 检查缓冲区是否有足够的数据
    const available = unzipped.getWriteOffset() - unzipped.getReadOffset();
    if (available < dataLength) {
      // 数据不足，使用实际可用的数据
      hilog.warn(DOMAIN, TAG, 'processUncached: not enough data available: %{public}d, needed: %{public}d, using available data', available, dataLength);
      // 读取所有可用数据
      const tdata = unzipped.readBytes(available);
      
      // 4. 创建输出缓冲区并进行行程长度解码
      const out = new MemByteBuffer();
      this.rle.runLengthDecode(out, MemByteBuffer.fromArray(tdata));

      // 5. 创建瓦片
      dirty[tidx] = CaptureTile.fromCapture(xywh, out);
      return;
    }
    
    // 6. 数据充足，读取完整数据
    const tdata = unzipped.readBytes(dataLength);
    
    // 7. 创建输出缓冲区并进行行程长度解码
    const out = new MemByteBuffer();
    this.rle.runLengthDecode(out, MemByteBuffer.fromArray(tdata));

    // 8. 创建瓦片
    dirty[tidx] = CaptureTile.fromCapture(xywh, out);
  }
}
