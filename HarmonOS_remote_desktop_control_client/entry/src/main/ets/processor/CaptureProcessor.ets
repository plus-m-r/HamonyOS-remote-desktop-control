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

    if (id <= this.lastFrameId && this.lastFrameId !== -1) {
      hilog.warn(DOMAIN, TAG, 'Frame ID not increasing: %{public}d -> %{public}d', this.lastFrameId, id);
    }
    this.lastFrameId = id;

    hilog.debug(DOMAIN, TAG, 'Processing frame: id=%{public}d, reset=%{public}s, size=%{public}d x %{public}d',
      id, reset.toString(), width, height);

    if (reset || this.prevWidth !== width || this.prevHeight !== height) {
      this.prevWidth = width;
      this.prevHeight = height;
      hilog.debug(DOMAIN, TAG, 'Keyframe or resolution changed');
    }

    this.frameCount++;

    return {
      buffer: imageBuffer,
      width,
      height,
      isKeyFrame: reset
    };
  }

  getStats(): FrameStats {
    return {
      frameCount: this.frameCount,
      lastFrameId: this.lastFrameId,
      bufferSize: 0
    };
  }

  reset(): void {
    this.prevWidth = 0;
    this.prevHeight = 0;
    this.frameCount = 0;
    this.lastFrameId = -1;
    hilog.info(DOMAIN, TAG, 'CaptureProcessor reset');
  }
}
