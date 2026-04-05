import hilog from '@ohos.hilog';

const DOMAIN = 0xFF00;
const TAG = 'CaptureProcessor';

export interface FrameProcessResult {
  buffer: Uint8Array;
  width: number;
  height: number;
  isKeyFrame: boolean;
}

export interface FrameInfo {
  id: number;
  reset: boolean;
  width: number;
  height: number;
}

export interface FrameStats {
  frameCount: number;
  lastFrameId: number;
  bufferSize: number;
}

export class CaptureProcessor {
  private prevBuffer: Uint8Array | null = null;
  private prevWidth: number = 0;
  private prevHeight: number = 0;
  private frameCount: number = 0;
  private lastFrameId: number = -1;

  processFrame(
    imageBuffer: Uint8Array,
    frameInfo: FrameInfo
  ): FrameProcessResult {
    const id = frameInfo.id;
    const reset = frameInfo.reset;
    const width = frameInfo.width;
    const height = frameInfo.height;
    const bufferSize = width * height * 4;

    if (id <= this.lastFrameId && this.lastFrameId !== -1) {
      hilog.warn(DOMAIN, TAG, 'Frame ID not increasing: %{public}d -> %{public}d', this.lastFrameId, id);
    }
    this.lastFrameId = id;

    hilog.info(DOMAIN, TAG, 'Processing frame: id=%{public}d, reset=%{public}s, size=%{public}d x %{public}d',
      id, reset.toString(), width, height);

    let buffer: Uint8Array;

    if (reset) {
      hilog.info(DOMAIN, TAG, 'Key frame detected, creating new buffer');
      buffer = new Uint8Array(bufferSize);
    } else {
      if (this.prevBuffer !== null &&
          this.prevWidth === width &&
          this.prevHeight === height &&
          this.prevBuffer.length === bufferSize) {
        buffer = this.prevBuffer;
        hilog.info(DOMAIN, TAG, 'Incremental frame, reusing previous buffer');
      } else {
        hilog.warn(DOMAIN, TAG, 'Cannot reuse buffer: prev=%{public}d x %{public}d, current=%{public}d x %{public}d',
          this.prevWidth, this.prevHeight, width, height);
        buffer = new Uint8Array(bufferSize);
      }
    }

    const srcView = new Uint8Array(imageBuffer.buffer, imageBuffer.byteOffset, Math.min(bufferSize, imageBuffer.length));
    buffer.set(srcView);

    if (buffer !== this.prevBuffer) {
      this.prevBuffer = buffer.slice();
    }
    this.prevWidth = width;
    this.prevHeight = height;

    this.frameCount++;

    return {
      buffer,
      width,
      height,
      isKeyFrame: reset
    };
  }

  getStats(): FrameStats {
    return {
      frameCount: this.frameCount,
      lastFrameId: this.lastFrameId,
      bufferSize: this.prevBuffer ? this.prevBuffer.length : 0
    };
  }

  reset(): void {
    this.prevBuffer = null;
    this.prevWidth = 0;
    this.prevHeight = 0;
    this.frameCount = 0;
    this.lastFrameId = -1;
    hilog.info(DOMAIN, TAG, 'CaptureProcessor reset');
  }
}
