import { MemByteBuffer } from './MemByteBuffer';
import { XYWH } from './XYWH';
import { ChecksumUtils } from '../utils/ChecksumUtils';

export class CaptureTile {
  static readonly MISSING: CaptureTile = new CaptureTile(-1, -1, -1, -1, -1, null, -1, false);

  readonly checksum: number;
  readonly x: number;
  readonly y: number;
  readonly width: number;
  readonly height: number;
  readonly capture: MemByteBuffer | null;
  readonly singleLevel: number;
  readonly fromCache: boolean;

  private constructor(
    checksum: number,
    x: number,
    y: number,
    width: number,
    height: number,
    capture: MemByteBuffer | null,
    singleLevel: number,
    fromCache: boolean
  ) {
    this.checksum = checksum;
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
    this.capture = capture;
    this.singleLevel = singleLevel;
    this.fromCache = fromCache;
  }

  static fromSingleLevel(xywh: XYWH, singleLevel: number): CaptureTile {
    const data = new Uint8Array(xywh.w * xywh.h * 4);
    // RGBA格式：R=G=B=singleLevel, A=255（不透明）
    for (let i = 0; i < data.length; i += 4) {
      data[i] = singleLevel;     // R
      data[i + 1] = singleLevel; // G
      data[i + 2] = singleLevel; // B
      data[i + 3] = 255;         // A (必须不透明)
    }
    const capture = MemByteBuffer.fromArray(data);
    // 与Java端一致：单级瓦片的checksum为-1
    return new CaptureTile(-1, xywh.x, xywh.y, xywh.w, xywh.h, capture, singleLevel, false);
  }

  static fromCapture(xywh: XYWH, capture: MemByteBuffer): CaptureTile {
    const data = capture.getInternal();
    const checksum = CaptureTile.computeChecksum(data);
    return new CaptureTile(checksum, xywh.x, xywh.y, xywh.w, xywh.h, capture, -1, false);
  }

  static fromCache(xywh: XYWH, cached: CaptureTile): CaptureTile {
    // 此时cached一定不是MISSING（Compressor中已处理）
    const capture = cached.capture;
    // 与Java端一致：fromCache的checksum为-1
    return new CaptureTile(-1, xywh.x, xywh.y, xywh.w, xywh.h, capture, -1, true);
  }

  /**
   * 计算Adler32校验和
   * 与Java客户端保持一致
   */
  private static computeChecksum(data: Uint8Array): number {
    return ChecksumUtils.computeAdler32(data);
  }
}
