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
          } else if (value < 0) {
            // 只有 value < 0 才是 uncached tile
            this.processUncached(cache, unzipped, xywhArray[tidx], dirty, tidx, value);
          } else {
            // 不应该出现的情况：value > 256 但不是 256，也不是负数
            hilog.error(DOMAIN, TAG, 'decompress: WARNING - invalid tile value! value=%{public}d, tidx=%{public}d, skipping', value, tidx);
            // 为了避免读指针完全错位，这里我们只能继续，让后续逻辑自行恢复
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

    return new Capture(cId, cReset, cSkipped, cMerged, captureWidth, captureHeight, tileWidth, tileHeight, dirty);
  }

  private processUncached(cache: TileCache, unzipped: MemByteBuffer, xywh: XYWH, dirty: (CaptureTile | null)[], tidx: number, value: number): void {
    const dataLength = -value;
    const availableBytes = unzipped.size() - unzipped.getReadOffset();
    
    hilog.error(DOMAIN, TAG, 'processUncached: value=%{public}d, dataLength=%{public}d, available=%{public}d, unzipped.size=%{public}d, readOffset=%{public}d', value, dataLength, availableBytes, unzipped.size(), unzipped.getReadOffset());
    
    // 与 Java 客户端一致：不管数据够不够，尽力读取
    const tdata = new Uint8Array(dataLength);
    
    // 使用新的尽力读取方法
    const bytes = unzipped.readBytesBestEffort(dataLength);
    if (bytes.length > 0) {
      tdata.set(bytes, 0);
    }

    const out = new MemByteBuffer();
    this.rle.runLengthDecode(out, MemByteBuffer.fromArray(tdata));

    dirty[tidx] = CaptureTile.fromCapture(xywh, out);
    cache.add(dirty[tidx]!);
  }
}
