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

export interface PrevBufferParams {
  buffer: ArrayBuffer | null;
  width: number;
  height: number;
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

    if (reset || this.prevWidth !== width || this.prevHeight !== height) {
      this.prevBuffer = new Uint8Array(bufferSize);
      this.prevWidth = width;
      this.prevHeight = height;
      hilog.info(DOMAIN, TAG, 'Keyframe or resolution changed, allocated new prevBuffer');
    }

    if (this.prevBuffer) {
      this.prevBuffer.set(imageBuffer);
    }

    this.frameCount++;

    return {
      buffer: imageBuffer,
      width,
      height,
      isKeyFrame: reset
    };
  }

  getPrevBufferParams(): PrevBufferParams {
    const localBuffer: ArrayBuffer | null = this.prevBuffer ? this.prevBuffer.buffer as ArrayBuffer : null;
    const localWidth: number = this.prevWidth;
    const localHeight: number = this.prevHeight;
    return {
      buffer: localBuffer,
      width: localWidth,
      height: localHeight
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
