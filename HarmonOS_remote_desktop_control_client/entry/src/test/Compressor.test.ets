import { describe, it, expect } from '@ohos/hypium';
import { Compressor, CompressionMethod } from '../main/ets/squeeze/Compressor';
import { MemByteBuffer } from '../main/ets/squeeze/MemByteBuffer';
import { NullTileCache } from '../main/ets/squeeze/TileCache';

export default function compressorTest() {
  describe('Compressor Test', () => {
    it('should handle buffer underflow gracefully', 0, () => {
      // 创建一个空的MemByteBuffer模拟缓冲区下溢
      const emptyBuffer = new MemByteBuffer();
      const cache = new NullTileCache();
      const compressor = Compressor.get(CompressionMethod.ZSTD);
      
      // 测试解压空缓冲区
      expect(() => {
        compressor.decompress(cache, emptyBuffer);
      }).toThrow('Decompression failed: data size too small');
    });
    
    it('should return valid Capture object', 0, () => {
      // 创建一个包含有效数据的MemByteBuffer
      const buffer = new MemByteBuffer();
      // 写入基本的捕获数据
      buffer.writeInt(1); // id
      buffer.writeByte(0); // reset
      buffer.writeByte(0); // skipped
      buffer.writeByte(0); // merged
      buffer.writeShort(100); // width
      buffer.writeShort(100); // height
      buffer.writeShort(32); // tileWidth
      buffer.writeShort(32); // tileHeight
      
      const cache = new NullTileCache();
      const compressor = Compressor.get(CompressionMethod.ZSTD);
      
      // 测试解压有效数据
      const capture = compressor.decompress(cache, buffer);
      expect(capture).not.toBeNull();
      expect(capture.id).toBe(1);
      expect(capture.width).toBe(100);
      expect(capture.height).toBe(100);
    });
  });
}
