export class XYWH {
  readonly x: number;
  readonly y: number;
  readonly w: number;
  readonly h: number;

  constructor(x: number, y: number, w: number, h: number) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
  }

  equals(x: number, y: number, w: number, h: number): boolean {
    return x === this.x && y === this.y && w === this.w && h === this.h;
  }
}

class XYWHConfiguration {
  readonly captureWidth: number;
  readonly captureHeight: number;
  readonly tileWidth: number;
  readonly tileHeight: number;

  constructor(captureWidth: number, captureHeight: number, tileWidth: number, tileHeight: number) {
    this.captureWidth = captureWidth;
    this.captureHeight = captureHeight;
    this.tileWidth = tileWidth;
    this.tileHeight = tileHeight;
  }

  equals(captureWidth: number, captureHeight: number, tileWidth: number, tileHeight: number): boolean {
    return captureHeight === this.captureHeight && captureWidth === this.captureWidth && tileWidth === this.tileWidth && tileHeight === this.tileHeight;
  }
}

class XYWHCache {
  readonly configuration: XYWHConfiguration;
  readonly xywh: XYWH[];

  constructor(configuration: XYWHConfiguration, xywh: XYWH[]) {
    this.configuration = configuration;
    this.xywh = xywh;
  }
}

let cachedXYWH: XYWHCache | null = null;

export function getXYWH(captureWidth: number, captureHeight: number, tileWidth: number, tileHeight: number): XYWH[] {
  if (cachedXYWH === null || !cachedXYWH.configuration.equals(captureWidth, captureHeight, tileWidth, tileHeight)) {
    cachedXYWH = computeXYWH(captureWidth, captureHeight, tileWidth, tileHeight);
  }
  return [...cachedXYWH.xywh];
}

function computeXYWH(captureWidth: number, captureHeight: number, tileWidth: number, tileHeight: number): XYWHCache {
  const xCount = Math.ceil(captureWidth / tileWidth);
  const yCount = Math.ceil(captureHeight / tileHeight);
  const xywh: XYWH[] = new Array(xCount * yCount);
  let tileId = 0;
  for (let ty = 0; ty < captureHeight; ty += tileHeight) {
    const th = Math.min(captureHeight - ty, tileHeight);
    for (let tx = 0; tx < captureWidth; tx += tileWidth) {
      const tw = Math.min(captureWidth - tx, tileWidth);
      xywh[tileId++] = new XYWH(tx, ty, tw, th);
    }
  }
  return new XYWHCache(new XYWHConfiguration(captureWidth, captureHeight, tileWidth, tileHeight), xywh);
}
