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

  /**
   * 单级瓦片像素缓冲共享池：相同(尺寸,级别)的瓦片内容一致，共享同一份缓冲，避免每瓦片 16KB 分配
   */
  private static readonly singleLevelBuffers: Map<number, MemByteBuffer> = new Map();

  static fromSingleLevel(xywh: XYWH, singleLevel: number): CaptureTile {
    const pixelCount = xywh.w * xywh.h;
    const key = pixelCount * 256 + singleLevel;
    let capture = CaptureTile.singleLevelBuffers.get(key);
    if (capture === undefined) {
      // 字节序 [B,G,R,A] = [level, level, level, 255]，用 Uint32Array.fill 一次原生填充
      const pixels = new Uint32Array(pixelCount);
      const packed = (255 << 24) | (singleLevel << 16) | (singleLevel << 8) | singleLevel;
      pixels.fill(packed);
      const bytes = new Uint8Array(pixels.buffer);
      capture = MemByteBuffer.wrapUint8Array(bytes);
      CaptureTile.singleLevelBuffers.set(key, capture);
    }
    return new CaptureTile(-1, xywh.x, xywh.y, xywh.w, xywh.h, capture, singleLevel, false);
  }

  static fromCapture(xywh: XYWH, capture: MemByteBuffer): CaptureTile {
    const data = capture.getInternal();
    const checksum = CaptureTile.computeChecksum(data);
    return new CaptureTile(checksum, xywh.x, xywh.y, xywh.w, xywh.h, capture, -1, false);
  }

  /**
   * 跳过校验和创建瓦片（缓存禁用时避免无谓的 Adler32 计算）
   */
  static fromCaptureSkipChecksum(xywh: XYWH, capture: MemByteBuffer): CaptureTile {
    return new CaptureTile(-1, xywh.x, xywh.y, xywh.w, xywh.h, capture, -1, false);
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
