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
    
    console.log(`[步骤7-图像组装] 开始组装图像, 尺寸: ${capWidth}x${capHeight}, dirty tiles数量: ${this.dirtyTiles.length}`);
    
    // 安全检查：确保宽度和高度是合理的
    if (capWidth <= 0 || capHeight <= 0 || capWidth > 10000 || capHeight > 10000) {
      console.error(`Capture: Invalid dimensions: ${capWidth}x${capHeight}`);
      return new Uint8Array(0);
    }
    
    const bufferSize = capWidth * capHeight * 4;
    
    // 安全检查：确保bufferSize不会溢出
    if (bufferSize > 100000000) { // 100MB限制
      console.error(`Capture: Buffer size too large: ${bufferSize}`);
      return new Uint8Array(0);
    }
    
    console.log(`[步骤7-图像组装] 缓冲区大小: ${bufferSize}字节 (${bufferSize / 4}像素)`);
    
    let buffer: Uint8Array;
    if (prevBuffer !== null && capWidth === prevWidth && capHeight === prevHeight && prevBuffer.length === bufferSize) {
      buffer = prevBuffer;
      console.log(`[步骤7-图像组装] 复用前一帧缓冲区`);
    } else {
      buffer = new Uint8Array(bufferSize);
      console.log(`[步骤7-图像组装] 创建新缓冲区`);
    }

    const capWidthByteSize = capWidth * 4;
    
    let processedTiles = 0;
    let skippedTiles = 0;
    
    // 检查是否为灰度图像
    const isGray = this.dirtyTiles.some(tile => 
      tile !== null && tile !== undefined && tile.capture !== null && 
      tile.capture.size() === tile.width * tile.height
    );
    console.log(`[步骤7-图像组装] 图像格式: ${isGray ? '灰度' : 'ARGB彩色'}`);
    
    for (const tile of this.dirtyTiles) {
      if (tile === null || tile === undefined || tile.capture === null) {
        skippedTiles++;
        continue;
      }

      const src = tile.capture.getInternal();
      const tileWidth = tile.width;
      const tileHeight = tile.height;
      
      // 安全检查：确保tile位置在有效范围内
      if (tile.x < 0 || tile.y < 0 || tile.x >= capWidth || tile.y >= capHeight) {
        console.error(`Capture: Tile position out of bounds: (${tile.x}, ${tile.y})`);
        continue;
      }
      
      let destPos = tile.y * capWidthByteSize + tile.x * 4;
      
      // 安全检查：确保destPos在有效范围内
      if (destPos < 0 || destPos >= bufferSize) {
        console.error(`Capture: Destination position out of bounds: ${destPos}`);
        continue;
      }
      
      // 安全检查：确保数据长度在合理范围内
      if (src.length === 0) {
        console.warn(`Capture: Empty data for tile`);
        continue;
      }
      
      console.log(`[步骤7-图像组装] 处理tile ${processedTiles}, 位置: (${tile.x},${tile.y}), 尺寸: ${tileWidth}x${tileHeight}, 数据大小: ${src.length}字节`);
      
      // 根据数据大小判断处理方式
      if (isGray) {
        this.processGrayData(buffer, src, tileWidth, tileHeight, destPos, capWidthByteSize, bufferSize);
      } else {
        this.processArgbData(buffer, src, tileWidth, tileHeight, destPos, capWidthByteSize, bufferSize);
      }
      processedTiles++;
    }

    console.log(`[步骤7-图像组装] 组装完成, 处理tiles: ${processedTiles}, 跳过tiles: ${skippedTiles}`);
    return buffer;
  }

  /**
   * 处理8位灰度数据，转换为32位ARGB格式
   */
  private processGrayData(
    buffer: Uint8Array,
    src: Uint8Array,
    tileWidth: number,
    tileHeight: number,
    destPos: number,
    capWidthByteSize: number,
    bufferSize: number
  ): void {
    console.log(`[步骤8-灰度转换] 开始转换, tile尺寸: ${tileWidth}x${tileHeight}, 源数据大小: ${src.length}字节, 预期大小: ${tileWidth * tileHeight}字节`);
    
    let srcPos = 0;
    let underflowCount = 0;
    let processedPixels = 0;
    
    for (let y = 0; y < tileHeight; y++) {
      for (let x = 0; x < tileWidth; x++) {
        // 确保不会写入超出buffer范围的数据
        if (destPos + 3 >= bufferSize) {
          console.error(`Capture: Would write beyond buffer bounds at destPos: ${destPos}`);
          return;
        }
        
        // 确保不会读取超出src范围的数据
        if (srcPos >= src.length) {
          // 数据不足时，使用默认值（黑色）
          buffer[destPos] = 0xff;      // A
          buffer[destPos + 1] = 0; // R
          buffer[destPos + 2] = 0; // G
          buffer[destPos + 3] = 0;     // B
          underflowCount++;
        } else {
          // 将8位灰度值转换为32位ARGB格式
          // 灰度值同时设置到R、G、B通道，A通道设为255（不透明）
          const grayValue = src[srcPos++];
          buffer[destPos] = 0xff;      // A
          buffer[destPos + 1] = grayValue; // R
          buffer[destPos + 2] = grayValue; // G
          buffer[destPos + 3] = grayValue;     // B
          processedPixels++;
        }
        
        destPos += 4;
      }
      destPos += capWidthByteSize - tileWidth * 4;
    }
    
    console.log(`[步骤8-灰度转换] 转换完成, 处理像素: ${processedPixels}, 数据不足像素: ${underflowCount}`);
  }

  /**
   * 处理32位ARGB数据
   */
  private processArgbData(
    buffer: Uint8Array,
    src: Uint8Array,
    tileWidth: number,
    tileHeight: number,
    destPos: number,
    capWidthByteSize: number,
    bufferSize: number
  ): void {
    const tileWidthByteSize = tileWidth * 4;
    const srcSize = tileWidthByteSize * tileHeight;
    
    for (let y = 0; y < tileHeight; y++) {
      for (let x = 0; x < tileWidth; x++) {
        const srcPos = (y * tileWidth + x) * 4;
        
        // 确保不会写入超出buffer范围的数据
        if (destPos + 3 >= bufferSize || srcPos + 3 >= src.length) {
          console.error(`Capture: Would write beyond buffer bounds at destPos: ${destPos} or srcPos: ${srcPos}`);
          break;
        }
        
        // 直接使用ARGB格式数据（Alpha, Red, Green, Blue）
        buffer[destPos] = src[srcPos];     // A
        buffer[destPos + 1] = src[srcPos + 1]; // R
        buffer[destPos + 2] = src[srcPos + 2]; // G
        buffer[destPos + 3] = src[srcPos + 3]; // B
        
        destPos += 4;
      }
      destPos += capWidthByteSize - tileWidth * 4;
    }
  }
}
