import hilog from '@ohos.hilog';
import { MemByteBuffer } from './MemByteBuffer';
import { CaptureTile } from './CaptureTile';
import { Capture } from './Capture';
import { TileCache, NullTileCache, RegularTileCache } from './TileCache';
import { RunLengthEncoder, NullRunLengthEncoder, RegularRunLengthEncoder } from './RunLengthEncoder';
import { XYWH, getXYWH } from './XYWH';
import { CompressionMethod } from '../models/CmdProtocol';
import { CompressorFactory as LibraryFactory, ICompressor as LibraryICompressor } from 'library_decompressor';

const DOMAIN: number = 0xFF00;
const TAG: string = 'FrameDecoder';

export class FrameDecoder {
  private static readonly ZSTD_DECODER: FrameDecoder = new FrameDecoder(
    CompressionMethod.ZSTD,
    new NullRunLengthEncoder()
  );

  readonly method: CompressionMethod;
  private readonly rle: RunLengthEncoder;
  private tileCache: TileCache = new NullTileCache();
  private useTileCache: boolean = false;
  private tileCacheMaxSize: number = 1000;
  private tileCachePurgeSize: number = 500;

  private zstdInner: LibraryICompressor | null = null;

  private lastCaptureWidth: number = -1;
  private lastCaptureHeight: number = -1;
  private lastTileWidth: number = -1;
  private lastTileHeight: number = -1;
  private lastXywhArray: XYWH[] = [];

  private constructor(method: CompressionMethod, rle: RunLengthEncoder) {
    this.method = method;
    this.rle = rle;
  }

  static get(method: CompressionMethod): FrameDecoder {
    switch (method) {
      case CompressionMethod.ZSTD:
        return FrameDecoder.ZSTD_DECODER;
      default:
        throw new Error(`Unsupported compression method [${method}]! Only ZSTD is supported.`);
    }
  }

  setTileCacheConfig(useCache: boolean, cacheMaxSize: number, cachePurgeSize: number): void {
    const safeMaxSize = cacheMaxSize > 0 ? cacheMaxSize : 1000;
    const safePurgeSize = cachePurgeSize > 0 ? cachePurgeSize : 500;

    if (!useCache) {
      this.useTileCache = false;
      this.tileCache = new NullTileCache();
      this.tileCacheMaxSize = safeMaxSize;
      this.tileCachePurgeSize = safePurgeSize;
      return;
    }

    const needRecreate = !this.useTileCache ||
      this.tileCacheMaxSize !== safeMaxSize ||
      this.tileCachePurgeSize !== safePurgeSize;

    this.useTileCache = true;
    if (needRecreate) {
      this.tileCache = new RegularTileCache(safeMaxSize, safePurgeSize);
      this.tileCacheMaxSize = safeMaxSize;
      this.tileCachePurgeSize = safePurgeSize;
    }
  }

  async decompress(zipped: MemByteBuffer): Promise<Capture> {
    const tZstdStart = Date.now();
    const unzipped = await this.zstdDecompress(zipped);
    const tZstdEnd = Date.now();

    unzipped.reset();

    const cId = unzipped.readInt();
    const cReset = unzipped.readByte() === 1;

    if (cReset) {
      this.tileCache.clear();
    }

    const cSkipped = unzipped.readUnsignedByte();
    const cMerged = unzipped.readUnsignedByte();

    const captureWidth = unzipped.readShort();
    const captureHeight = unzipped.readShort();
    const tileWidth = unzipped.readShort();
    const tileHeight = unzipped.readShort();

    let xywhArray: XYWH[];
    if (captureWidth === this.lastCaptureWidth &&
        captureHeight === this.lastCaptureHeight &&
        tileWidth === this.lastTileWidth &&
        tileHeight === this.lastTileHeight) {
      xywhArray = this.lastXywhArray;
    } else {
      xywhArray = getXYWH(captureWidth, captureHeight, tileWidth, tileHeight);
      this.lastCaptureWidth = captureWidth;
      this.lastCaptureHeight = captureHeight;
      this.lastTileWidth = tileWidth;
      this.lastTileHeight = tileHeight;
      this.lastXywhArray = xywhArray;
    }
    const dirty: (CaptureTile | null)[] = new Array(xywhArray.length).fill(null);

    let idx = 0;
    let singleLevelCount = 0;
    let cacheCount = 0;
    let uncachedCount = 0;
    const tMarkerStart = Date.now();

    while (idx < dirty.length) {
      const markerCount = unzipped.readByte();

      if (markerCount > 0) {
        let processedCount = 0;
        for (let tidx = idx; tidx < idx + markerCount; tidx++) {
          if (tidx >= dirty.length) {
            break;
          }

          if (!xywhArray[tidx]) {
            hilog.warn(DOMAIN, TAG, 'xywhArray[tidx] is undefined: tidx=%{public}d, array length=%{public}d', tidx, xywhArray.length);
            continue;
          }

          const value = unzipped.readShort();

          if (value >= 0 && value < 256) {
            dirty[tidx] = CaptureTile.fromSingleLevel(xywhArray[tidx], value);
            singleLevelCount++;
          } else if (value === 256) {
            const cacheId = unzipped.readInt();
            const cachedTile = this.tileCache.get(cacheId);
            if (cachedTile === CaptureTile.MISSING) {
              dirty[tidx] = CaptureTile.fromSingleLevel(xywhArray[tidx], 0);
              hilog.warn(DOMAIN, TAG, 'Cache MISS at idx=%{public}d, cacheId=%{public}d, cacheSize=%{public}d, captureId=%{public}d', tidx, cacheId, this.tileCache.size(), cId);
            } else {
              dirty[tidx] = CaptureTile.fromCache(xywhArray[tidx], cachedTile);
            }
            cacheCount++;
          } else {
            this.processUncached(unzipped, xywhArray[tidx], dirty, tidx, value);
            uncachedCount++;
          }
          processedCount++;
        }
        idx += processedCount;
        if (idx >= dirty.length) {
          break;
        }
      } else {
        const skipCount = -markerCount + 1;
        for (let i = 0; i < skipCount && idx < dirty.length; i++) {
          dirty[idx++] = null;
        }
      }
    }

    const tMarkerEnd = Date.now();
    const isGrayFrame = dirty.some(tile =>
      tile !== null && tile.capture !== null &&
      tile.capture.size() === tile.width * tile.height
    );
    const capture = new Capture(cId, cReset, cSkipped, cMerged, captureWidth, captureHeight, tileWidth, tileHeight, dirty, isGrayFrame);

    this.tileCache.onCaptureProcessed();

    const tParseEnd = Date.now();
    let dirtyCount = 0;
    for (let i = 0; i < dirty.length; i++) {
      if (dirty[i] !== null) {
        dirtyCount++;
      }
    }
    if (this.timingLogCount % 30 === 0 || this.timingLogCount < 5) {
      hilog.info(DOMAIN, TAG, 'decompress timing: zstd=%{public}dms marker=%{public}dms post=%{public}dms total=%{public}dms dirty=%{public}d single=%{public}d cache=%{public}d uncached=%{public}d',
        tZstdEnd - tZstdStart, tMarkerEnd - tMarkerStart, tParseEnd - tMarkerEnd, tParseEnd - tZstdStart, dirtyCount, singleLevelCount, cacheCount, uncachedCount);
    }
    this.timingLogCount++;

    return capture;
  }

  private timingLogCount: number = 0;

  getTileCacheSize(): number {
    return this.tileCache.size();
  }

  getTileCacheHits(): number {
    return this.tileCache.getHits();
  }

  getTileCacheMisses(): number {
    return this.tileCache.getMisses();
  }

  getNegativeGetCount(): number {
    return this.tileCache.getNegativeGetCount();
  }

  getNormalizedAddCount(): number {
    return this.tileCache.getNormalizedAddCount();
  }

  private async zstdDecompress(zipped: MemByteBuffer): Promise<MemByteBuffer> {
    try {
      const zippedData = zipped.getInternal();
      const buffer = zippedData.buffer.slice(zippedData.byteOffset, zippedData.byteOffset + zippedData.length) as ArrayBuffer;
      const inner = this.getZstdInner();
      const result: ArrayBuffer = await inner.decompressAsync(buffer) as ArrayBuffer;
      // 零拷贝：直接包装原生解压结果，避免整帧再次拷贝进新 MemByteBuffer
      return MemByteBuffer.wrapArrayBuffer(result);
    } catch (e) {
      const errorMessage = e instanceof Error ? e.message : String(e);
      hilog.error(DOMAIN, TAG, 'ZSTD decompression failed: %{public}s', errorMessage);
      throw new Error(errorMessage);
    }
  }

  private getZstdInner(): LibraryICompressor {
    if (this.zstdInner === null) {
      this.zstdInner = LibraryFactory.create('zstd');
    }
    return this.zstdInner;
  }

  private processUncached(unzipped: MemByteBuffer, xywh: XYWH, dirty: (CaptureTile | null)[], tidx: number, value: number): void {
    const dataLength = -value;

    if (dataLength <= 0 || dataLength > 1024 * 1024) {
      hilog.error(DOMAIN, TAG, 'processUncached: invalid dataLength: %{public}d (value: %{public}d)', dataLength, value);
      return;
    }

    const available = unzipped.getWriteOffset() - unzipped.getReadOffset();
    if (available < dataLength) {
      hilog.warn(DOMAIN, TAG, 'processUncached: not enough data available: %{public}d, needed: %{public}d, using available data', available, dataLength);
      const tdata = unzipped.readBytes(available);

      if (!this.useTileCache) {
        // 缓存禁用 + NullRLE：零拷贝直通，跳过校验和
        dirty[tidx] = CaptureTile.fromCaptureSkipChecksum(xywh, MemByteBuffer.wrapUint8Array(tdata));
        return;
      }

      // NullRLE 下解码结果 == tdata，直接拷贝一次作为独立瓦片缓冲
      const out = MemByteBuffer.fromArray(tdata);

      dirty[tidx] = CaptureTile.fromCapture(xywh, out);
      this.tileCache.add(dirty[tidx] as CaptureTile);
      return;
    }

    const tdata = unzipped.readBytes(dataLength);

    if (!this.useTileCache) {
      // 缓存禁用 + NullRLE（ZSTD 默认）：零拷贝直通，跳过校验和与中间拷贝
      dirty[tidx] = CaptureTile.fromCaptureSkipChecksum(xywh, MemByteBuffer.wrapUint8Array(tdata));
      return;
    }

    // NullRLE 下解码结果 == tdata，直接拷贝一次作为独立瓦片缓冲（避免 fromArray + runLengthDecode 两次拷贝）
    const out = MemByteBuffer.fromArray(tdata);

    dirty[tidx] = CaptureTile.fromCapture(xywh, out);
    this.tileCache.add(dirty[tidx] as CaptureTile);
  }
}