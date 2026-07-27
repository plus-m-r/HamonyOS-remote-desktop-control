import { CaptureTile } from './CaptureTile';
import { BufferPool, PooledBuffer } from '../utils/ObjectPool';
import { logManager } from '../utils/LogManager';
import { util } from '@kit.ArkTS';
import fs from '@ohos.file.fs';
import { Context } from '@kit.AbilityKit';
import { TileRegion } from '@plusml/arkzero';

const PERF_DOMAIN = 0xFF00;
const PERF_TAG = 'CapturePerf';

interface CaptureInfo {
  id: number;
  reset: boolean;
  width: number;
  height: number;
  tileWidth: number;
  tileHeight: number;
  dirtyTilesCount: number;
}

interface RenderStats {
  id: number;
  processedTiles: number;
  skippedTiles: number;
  renderTime: number;
  totalTiles: number;
}

interface ContextWithFilesDir {
  filesDir: string;
}

export interface CreateImageBufferResult {
  buffer: Uint8Array;
  pooledBuffer: PooledBuffer | null;
}

export class Capture {
  readonly id: number;
  readonly reset: boolean;
  readonly skipped: number;
  readonly merged: number;
  readonly width: number;
  readonly height: number;
  readonly tileWidth: number;
  readonly tileHeight: number;
  readonly dirtyTiles: (CaptureTile | null)[];
  readonly isGrayFrame: boolean;

  constructor(
    id: number,
    reset: boolean,
    skipped: number,
    merged: number,
    width: number,
    height: number,
    tileWidth: number,
    tileHeight: number,
    dirtyTiles: (CaptureTile | null)[],
    isGrayFrame: boolean = false
  ) {
    this.id = id;
    this.reset = reset;
    this.skipped = skipped;
    this.merged = merged;
    this.width = width;
    this.height = height;
    this.tileWidth = tileWidth;
    this.tileHeight = tileHeight;
    this.dirtyTiles = [...dirtyTiles];
    this.isGrayFrame = isGrayFrame;
  }

  createImageBuffer(prevBuffer: Uint8Array | null, prevWidth: number, prevHeight: number): CreateImageBufferResult {
    const capWidth = this.width;
    const capHeight = this.height;
    const bufferSize = capWidth * capHeight * 4;

    let buffer: Uint8Array;
    let pooledBuffer: PooledBuffer | null = null;
    const bufferPool = BufferPool.getInstance();

    if (prevBuffer !== null && capWidth === prevWidth && capHeight === prevHeight && prevBuffer.length === bufferSize) {
      buffer = prevBuffer;
      if (this.reset) {
        buffer.fill(0);
      }
    } else {
      pooledBuffer = bufferPool.acquireBuffer(bufferSize);
      buffer = pooledBuffer.data;
      if (this.reset) {
        buffer.fill(0);
      }
    }

    this.drawToBuffer(buffer);

    return { buffer: buffer, pooledBuffer: pooledBuffer };
  }

  drawToBuffer(buffer: Uint8Array): void {
    const capWidth = this.width;
    const capWidthByteSize = capWidth * 4;
    const isGray = this.isGrayFrame;

    for (let i = 0; i < this.dirtyTiles.length; i++) {
      const tile = this.dirtyTiles[i];

      if (tile === null || tile.capture === null) {
        continue;
      }

      const src = tile.capture.getInternal();
      const tileWidth = tile.width;
      const tileHeight = tile.height;
      const destPos = tile.y * capWidthByteSize + tile.x * 4;

      if (isGray) {
        this.processGrayDataOptimized(buffer, src, tileWidth, tileHeight, destPos, capWidthByteSize);
      } else {
        this.processArgbDataOptimized(buffer, src, tileWidth, tileHeight, destPos, capWidthByteSize);
      }
    }
  }

  toTileRegions(): TileRegion[] {
    const fw = this.width;
    const fh = this.height;
    const isGray = this.isGrayFrame;
    const regions: TileRegion[] = [];

    for (let i = 0; i < this.dirtyTiles.length; i++) {
      const tile = this.dirtyTiles[i];
      if (tile === null || tile.capture === null) {
        continue;
      }

      const src = tile.capture.getInternal();
      const tw = tile.width;
      const th = tile.height;
      let pixelData: ArrayBuffer;

      if (isGray) {
        const rgbaSize = tw * th * 4;
        const rgba = new Uint8Array(rgbaSize);
        const lut = Capture.GRAY_LUT;
        let srcPos = 0;
        for (let p = 0; p < tw * th; p++) {
          const rgbaOffset = p * 4;
          const val = lut[src[srcPos++]];
          rgba[rgbaOffset] = val & 0xFF;
          rgba[rgbaOffset + 1] = (val >> 8) & 0xFF;
          rgba[rgbaOffset + 2] = (val >> 16) & 0xFF;
          rgba[rgbaOffset + 3] = (val >> 24) & 0xFF;
        }
        const grayBuf: ArrayBuffer = rgba.buffer.slice(rgba.byteOffset, rgba.byteOffset + rgba.byteLength);
        pixelData = grayBuf;
      } else {
        const argbBuf: ArrayBuffer = src.buffer.slice(src.byteOffset, src.byteOffset + src.byteLength);
        pixelData = argbBuf;
      }

      const region: TileRegion = {
        ratioX: tile.x / fw,
        ratioY: tile.y / fh,
        tilePixelWidth: tw,
        tilePixelHeight: th,
        pixelData: pixelData
      };
      regions.push(region);
    }

    return regions;
  }

  private processArgbDataOptimized(
    buffer: Uint8Array,
    src: Uint8Array,
    tileWidth: number,
    tileHeight: number,
    destPos: number,
    capWidthByteSize: number
  ): void {
    const tileWidthByteSize = tileWidth * 4;

    for (let y = 0; y < tileHeight; y++) {
      const srcOffset = y * tileWidthByteSize;
      const destOffset = destPos + y * capWidthByteSize;
      buffer.set(src.subarray(srcOffset, srcOffset + tileWidthByteSize), destOffset);
    }
  }

  private static readonly GRAY_LUT: Uint32Array = Capture.buildGrayLUT();

  private static buildGrayLUT(): Uint32Array {
    const lut = new Uint32Array(256);
    for (let g = 0; g < 256; g++) {
      lut[g] = 0xFF000000 | (g << 16) | (g << 8) | g;
    }
    return lut;
  }

  private processGrayDataOptimized(
    buffer: Uint8Array,
    src: Uint8Array,
    tileWidth: number,
    tileHeight: number,
    destPos: number,
    capWidthByteSize: number
  ): void {
    const lut = Capture.GRAY_LUT;
    let srcPos = 0;

    for (let y = 0; y < tileHeight; y++) {
      const destRowOffset = destPos + y * capWidthByteSize;
      const dest32 = new Uint32Array(buffer.buffer, buffer.byteOffset + destRowOffset, tileWidth);
      for (let x = 0; x < tileWidth; x++) {
        dest32[x] = lut[src[srcPos++]];
      }
    }
  }
}
