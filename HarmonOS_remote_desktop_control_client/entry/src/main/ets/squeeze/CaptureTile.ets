import { MemByteBuffer } from './MemByteBuffer';
import { XYWH } from './XYWH';

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
    // BGRA格式：B, G, R, A
    for (let i = 0; i < data.length; i += 4) {
      data[i] = singleLevel;     // B
      data[i + 1] = singleLevel; // G
      data[i + 2] = singleLevel; // R
      data[i + 3] = 0xff;        // A (不透明)
    }
    const capture = MemByteBuffer.fromArray(data);
    return new CaptureTile(-1, xywh.x, xywh.y, xywh.w, xywh.h, capture, singleLevel, false);
  }

  static fromCapture(xywh: XYWH, capture: MemByteBuffer): CaptureTile {
    return new CaptureTile(-1, xywh.x, xywh.y, xywh.w, xywh.h, capture, -1, false);
  }

  static fromCache(xywh: XYWH, cached: CaptureTile): CaptureTile {
    let capture: MemByteBuffer | null;
    if (cached === CaptureTile.MISSING) {
      const data = new Uint8Array(xywh.w * xywh.h * 4);
      capture = MemByteBuffer.fromArray(data);
    } else {
      capture = cached.capture;
    }
    return new CaptureTile(-1, xywh.x, xywh.y, xywh.w, xywh.h, capture, -1, true);
  }
}
