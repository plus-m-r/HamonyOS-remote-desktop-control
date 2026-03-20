import { MemByteBuffer } from './MemByteBuffer';
import { CaptureTile } from './CaptureTile';
import { Capture } from './Capture';
import { TileCache, NullTileCache, RegularTileCache } from './TileCache';
import { RunLengthEncoder, NullRunLengthEncoder, RegularRunLengthEncoder } from './RunLengthEncoder';
import { Zipper, NullZipper, ZstdZipper } from './Zipper';
import { XYWH, getXYWH } from './XYWH';

export enum CompressionMethod {
  NONE = 0,
  ZIP = 1,
  XZ = 2,
  ZSTD = 3
}

export class Compressor {
  private static readonly NULL_COMPRESSOR: Compressor = new Compressor(
    CompressionMethod.NONE,
    new NullRunLengthEncoder(),
    new NullZipper()
  );

  private static readonly ZSTD_COMPRESSOR: Compressor = new Compressor(
    CompressionMethod.ZSTD,
    new RegularRunLengthEncoder(),
    new ZstdZipper()
  );

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
      case CompressionMethod.NONE:
        return Compressor.NULL_COMPRESSOR;
      default:
        throw new Error(`Unsupported compressor configuration [${method}]!`);
    }
  }

  decompress(cache: TileCache, zipped: MemByteBuffer): Capture {
    const unzipped = this.zipper.unzip(zipped);
    
    if (unzipped.size() < 20) {
      throw new Error('Decompression failed: data size too small');
    }
    
    unzipped.reset();
    
    const cId = unzipped.readInt();
    const cReset = unzipped.readByte() === 1;
    
    if (cReset) {
      cache.clear();
    }
    
    const cSkipped = unzipped.readUnsignedByte();
    const cMerged = unzipped.readUnsignedByte();
    const captureWidth = unzipped.readShort() & 0xFFFF;
    const captureHeight = unzipped.readShort() & 0xFFFF;
    const tileWidth = unzipped.readShort() & 0xFFFF;
    const tileHeight = unzipped.readShort() & 0xFFFF;
    
    const xywhArray = getXYWH(captureWidth, captureHeight, tileWidth, tileHeight);
    const dirty: (CaptureTile | null)[] = new Array(xywhArray.length);
    
    let idx = 0;
    while (idx < dirty.length) {
      const markerCount = unzipped.readByte();
      
      if (markerCount > 0) {
        for (let tidx = idx; tidx < idx + markerCount; tidx++) {
          const value = unzipped.readShort();
          
          if (value >= 0 && value < 256) {
            dirty[tidx] = CaptureTile.fromSingleLevel(xywhArray[tidx], value);
          } else if (value === 256) {
            const cacheId = unzipped.readInt();
            dirty[tidx] = CaptureTile.fromCache(xywhArray[tidx], cache.get(cacheId));
          } else {
            this.processUncached(cache, unzipped, xywhArray[tidx], dirty, tidx, value);
          }
        }
        idx += markerCount;
      } else {
        idx += (-markerCount + 1);
      }
    }
    
    return new Capture(cId, cReset, cSkipped, cMerged, captureWidth, captureHeight, tileWidth, tileHeight, dirty);
  }

  private processUncached(cache: TileCache, unzipped: MemByteBuffer, xywh: XYWH, dirty: (CaptureTile | null)[], tidx: number, value: number): void {
    const tdata = new Uint8Array(-value);
    
    for (let i = 0; i < tdata.length; i++) {
      tdata[i] = unzipped.readByte();
    }
    
    const out = new MemByteBuffer();
    this.rle.runLengthDecode(out, MemByteBuffer.fromArray(tdata));
    
    dirty[tidx] = CaptureTile.fromCapture(xywh, out);
    cache.add(dirty[tidx]!);
  }
}
