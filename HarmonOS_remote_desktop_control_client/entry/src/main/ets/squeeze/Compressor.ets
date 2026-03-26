import { MemByteBuffer } from './MemByteBuffer';
import { CaptureTile } from './CaptureTile';
import { Capture } from './Capture';
import { TileCache, NullTileCache, RegularTileCache } from './TileCache';
import { RunLengthEncoder, NullRunLengthEncoder, RegularRunLengthEncoder } from './RunLengthEncoder';
import { Zipper, ZstdZipper } from './Zipper';
import { XYWH, getXYWH } from './XYWH';

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
    console.log(`[步骤4-数据解析] 开始解压缩, 输入数据大小: ${zipped.size()}字节`);
    const unzipped = await this.zipper.unzip(zipped);

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

    console.log(`[步骤4-数据解析] 头部信息 - ID: ${cId}, reset: ${cReset}, skipped: ${cSkipped}, merged: ${cMerged}`);
    console.log(`[步骤4-数据解析] 尺寸信息 - capture: ${captureWidth}x${captureHeight}, tile: ${tileWidth}x${tileHeight}`);
    console.log(`[步骤4-数据解析] 当前读取偏移: ${unzipped.getReadOffset()}, 剩余数据: ${unzipped.size() - unzipped.getReadOffset()}字节`);

    // 安全检查：确保尺寸有效
    if (captureWidth <= 0 || captureHeight <= 0 || tileWidth <= 0 || tileHeight <= 0) {
      throw new Error(`Invalid dimensions: ${captureWidth}x${captureHeight}, tile: ${tileWidth}x${tileHeight}`);
    }

    const xywhArray = getXYWH(captureWidth, captureHeight, tileWidth, tileHeight);
    const dirty: (CaptureTile | null)[] = new Array(xywhArray.length).fill(null);

    let idx = 0;

    try {
      while (idx < dirty.length) {
        // 检查是否有足够的字节读取markerCount
        if (unzipped.getReadOffset() + 1 > unzipped.size()) {
          console.warn(`Compressor: Buffer underflow when reading markerCount at idx=${idx}`);
          break;
        }

        const markerCount = unzipped.readByte();

        console.log(`[步骤4-数据解析] markerCount: ${markerCount}, 当前idx: ${idx}, 剩余数据: ${unzipped.size() - unzipped.getReadOffset()}字节`);

        if (markerCount > 0) {
          for (let tidx = idx; tidx < idx + markerCount; tidx++) {
            if (tidx >= dirty.length) {
              console.warn(`Compressor: Tile index out of bounds: ${tidx} >= ${dirty.length}`);
              break;
            }

            // 检查是否有足够的字节读取value
            if (unzipped.getReadOffset() + 2 > unzipped.size()) {
              console.warn(`Compressor: Buffer underflow when reading value at tidx=${tidx}`);
              dirty[tidx] = null;
              continue;
            }

            const value = unzipped.readShort();
            console.log(`[步骤4-数据解析] tidx: ${tidx}, value: ${value} (0x${(value & 0xFFFF).toString(16)}), 剩余数据: ${unzipped.size() - unzipped.getReadOffset()}字节`);

            if (value >= 0 && value < 256) {
              console.log(`[步骤4-数据解析] -> single-level tile, 灰度值: ${value}`);
              dirty[tidx] = CaptureTile.fromSingleLevel(xywhArray[tidx], value);
            } else if (value === 256) {
              // 检查是否有足够的字节读取cacheId
              if (unzipped.getReadOffset() + 4 > unzipped.size()) {
                console.warn(`Compressor: Buffer underflow when reading cacheId at tidx=${tidx}`);
                dirty[tidx] = null;
                continue;
              }
              const cacheId = unzipped.readInt();
              console.log(`[步骤4-数据解析] -> cached tile, cacheId: ${cacheId}`);
              dirty[tidx] = CaptureTile.fromCache(xywhArray[tidx], cache.get(cacheId));
            } else {
              console.log(`[步骤4-数据解析] -> uncached tile, 数据长度: ${-value}`);
              this.processUncached(cache, unzipped, xywhArray[tidx], dirty, tidx, value);
            }
          }
          idx += markerCount;
        } else {
          // 处理null tiles
          const skipCount = -markerCount + 1;
          for (let i = 0; i < skipCount && idx < dirty.length; i++) {
            dirty[idx++] = null;
          }
        }
      }
    } catch (error) {
      console.error(`Compressor: Error during decompression at idx=${idx}:`, error);
      // 继续返回已解压的部分数据
    }

    return new Capture(cId, cReset, cSkipped, cMerged, captureWidth, captureHeight, tileWidth, tileHeight, dirty);
  }

  private processUncached(cache: TileCache, unzipped: MemByteBuffer, xywh: XYWH, dirty: (CaptureTile | null)[], tidx: number, value: number): void {
    // value是负数，表示数据长度。使用Math.abs确保正确处理-32768的情况
    const dataLength = Math.abs(value);

    console.log(`[步骤5-处理Uncached] tidx: ${tidx}, value: ${value}, dataLength: ${dataLength}, xywh: (${xywh.x},${xywh.y},${xywh.w},${xywh.h})`);

    // 添加安全检查，防止过大的数据长度
    if (dataLength > 1000000) {
      console.error(`Compressor: Data length too large: ${dataLength}, value: ${value}`);
      dirty[tidx] = null;
      return;
    }

    // 检查缓冲区是否有足够的字节
    const availableBytes = unzipped.size() - unzipped.getReadOffset();
    console.log(`[步骤5-处理Uncached] 可用字节: ${availableBytes}, 需要字节: ${dataLength}`);
    
    if (dataLength > availableBytes) {
      // 参考Java客户端处理方式，当数据不足时直接返回null
      console.warn(`Compressor: Buffer underflow in processUncached. Need ${dataLength}, but only ${availableBytes} available`);
      dirty[tidx] = null;
      return;
    }

    const tdata = unzipped.readBytes(dataLength);
    console.log(`[步骤5-处理Uncached] 读取数据成功, 数据大小: ${tdata.length}字节, 前10字节: ${Array.from(tdata.slice(0, 10)).map(b => b.toString(16).padStart(2, '0')).join(' ')}`);

    const out = new MemByteBuffer();
    this.rle.runLengthDecode(out, MemByteBuffer.fromArray(tdata));
    console.log(`[步骤5-处理Uncached] RLE解码完成, 解码后数据大小: ${out.size()}字节`);

    dirty[tidx] = CaptureTile.fromCapture(xywh, out);
    cache.add(dirty[tidx]!);
    console.log(`[步骤5-处理Uncached] tile创建成功并加入缓存`);
  }
}
