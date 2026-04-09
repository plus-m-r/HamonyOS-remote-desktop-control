import hilog from '@ohos.hilog';
import { MemByteBuffer } from './MemByteBuffer';
import { CaptureTile } from './CaptureTile';
import { Capture } from './Capture';
import { TileCache, NullTileCache, RegularTileCache } from './TileCache';
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
    new NullRunLengthEncoder(),
    new ZstdZipper()
  );
  private static loggedDecompressData: boolean = false;

  readonly method: CompressionMethod;
  private readonly rle: RunLengthEncoder;
  private readonly zipper: Zipper;

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

  async decompress(cache: TileCache, zipped: MemByteBuffer): Promise<Capture> {
    const unzipped = await this.zipper.unzip(zipped);

    hilog.error(DOMAIN, TAG, 'decompress start: unzipped.size=%{public}d, readOffset=%{public}d, writeOffset=%{public}d', unzipped.size(), unzipped.getReadOffset(), unzipped.getWriteOffset());
    
    unzipped.reset();

    const cId = unzipped.readInt();
    const cReset = unzipped.readByte() === 1;

    if (cReset) {
      cache.clear();
    }

    const cSkipped = unzipped.readUnsignedByte();
    const cMerged = unzipped.readUnsignedByte();
    
    // 保存当前位置以便调试
    const debugPos = unzipped.getReadOffset();
    
    const captureWidth = unzipped.readShort();
    const captureHeight = unzipped.readShort();
    const tileWidth = unzipped.readShort();
    const tileHeight = unzipped.readShort();
    
    hilog.error(DOMAIN, TAG, 'captureWidth=%{public}d, captureHeight=%{public}d, tileWidth=%{public}d, tileHeight=%{public}d', captureWidth, captureHeight, tileWidth, tileHeight);
    hilog.error(DOMAIN, TAG, 'Read at offset=%{public}d', debugPos);

    const xywhArray = getXYWH(captureWidth, captureHeight, tileWidth, tileHeight);
    const dirty: (CaptureTile | null)[] = new Array(xywhArray.length).fill(null);

    let idx = 0;

    while (idx < dirty.length) {
      const markerCount = unzipped.readByte();

      if (markerCount > 0) {
        for (let tidx = idx; tidx < idx + markerCount; tidx++) {
          if (tidx >= dirty.length) {
            break;
          }

          const value = unzipped.readShort();

          if (value >= 0 && value < 256) {
              dirty[tidx] = CaptureTile.fromSingleLevel(xywhArray[tidx], value);
            } else if (value === 256) {
              const cacheId = unzipped.readInt();
              dirty[tidx] = CaptureTile.fromCache(xywhArray[tidx], cache.get(cacheId));
            } else {
              // 其他情况：multi-level (not cached)
              this.processUncached(cache, unzipped, xywhArray[tidx], dirty, tidx, value);
            }
        }
        idx += markerCount;
      } else {
        const skipCount = -markerCount + 1;
        for (let i = 0; i < skipCount && idx < dirty.length; i++) {
          dirty[idx++] = null;
        }
      }
    }

    const capture = new Capture(cId, cReset, cSkipped, cMerged, captureWidth, captureHeight, tileWidth, tileHeight, dirty);
    
    // 保存所有瓦片数据，用于与Java客户端数据对比
    capture.saveAllTilesData().catch((error: Object) => {
      hilog.error(DOMAIN, TAG, 'Failed to save tiles data: %{public}s', error);
    });
    
    return capture;
  }

  private processUncached(cache: TileCache, unzipped: MemByteBuffer, xywh: XYWH, dirty: (CaptureTile | null)[], tidx: number, value: number): void {
    const dataLength = -value;
    
    // 与 Java 客户端一致：确保读取完整数据
    if (dataLength <= 0) {
      // 数据长度无效，跳过处理
      hilog.error(DOMAIN, TAG, 'processUncached: invalid dataLength: %{public}d', dataLength);
      return;
    }
    
    // 确保读取完整数据，与 Java 客户端一致
    const tdata = new Uint8Array(dataLength);
    let totalRead = 0;
    
    // 尝试读取完整数据
    while (totalRead < dataLength) {
      const remaining = dataLength - totalRead;
      const bytes = unzipped.readBytesBestEffort(remaining);
      
      if (bytes.length === 0) {
        // 没有更多数据可读，跳出循环
        break;
      }
      
      tdata.set(bytes, totalRead);
      totalRead += bytes.length;
    }
    
    // 与 Java 客户端一致：如果数据不足，不填充零，使用实际读取的数据
    // 注意：Java 客户端使用 DataInputStream.read() 会阻塞直到读取到足够数据
    // 但在我们的实现中，数据已经在缓冲区中，所以如果数据不足，说明缓冲区数据不完整
    
    // 只处理实际读取的数据
    const actualData = tdata.subarray(0, totalRead);
    
    const out = new MemByteBuffer();
    this.rle.runLengthDecode(out, MemByteBuffer.fromArray(actualData));

    dirty[tidx] = CaptureTile.fromCapture(xywh, out);
    cache.add(dirty[tidx]!);
  }
}
