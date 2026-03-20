import { CaptureTile } from './CaptureTile';

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

  constructor(
    id: number,
    reset: boolean,
    skipped: number,
    merged: number,
    width: number,
    height: number,
    tileWidth: number,
    tileHeight: number,
    dirtyTiles: (CaptureTile | null)[]
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
  }

  createImageBuffer(prevBuffer: Uint8Array | null, prevWidth: number, prevHeight: number): Uint8Array {
    const capWidth = this.width;
    const capHeight = this.height;
    const bufferSize = capWidth * capHeight * 4;
    
    let buffer: Uint8Array;
    if (prevBuffer !== null && capWidth === prevWidth && capHeight === prevHeight && prevBuffer.length === bufferSize) {
      buffer = prevBuffer;
    } else {
      buffer = new Uint8Array(bufferSize);
    }

    const capWidthByteSize = capWidth * 4;

    for (const tile of this.dirtyTiles) {
      if (tile === null || tile.capture === null) {
        continue;
      }

      const src = tile.capture.getInternal();
      const tileWidthByteSize = tile.width * 4;
      const srcSize = tileWidthByteSize * tile.height;
      let destPos = tile.y * capWidthByteSize + tile.x * 4;

      for (let srcPos = 0; srcPos + tileWidthByteSize <= srcSize; srcPos += tileWidthByteSize) {
        for (let i = 0; i < tileWidthByteSize; i++) {
          buffer[destPos + i] = src[srcPos + i];
        }
        destPos += capWidthByteSize;
      }
    }

    return buffer;
  }
}
