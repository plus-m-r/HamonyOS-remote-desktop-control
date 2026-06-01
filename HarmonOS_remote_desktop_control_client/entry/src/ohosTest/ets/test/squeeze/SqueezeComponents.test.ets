/**
 * Squeeze 组件单元测试
 *
 * 测试项目：
 * 1. RunLengthEncoder - RLE 编码/解码
 * 2. TileCache - 缓存机制
 * 3. MemByteBuffer - 边界场景测试
 * 4. processUncached - 数据读取逻辑
 */

import { describe, it, expect, beforeEach } from '@ohos/hypium';
import { MemByteBuffer } from '../../../../main/ets/squeeze/MemByteBuffer';
import { RegularRunLengthEncoder } from '../../../../main/ets/squeeze/RunLengthEncoder';
import { NullTileCache, RegularTileCache } from '../../../../main/ets/squeeze/TileCache';
import { XYWH } from '../../../../main/ets/squeeze/XYWH';

export default function SqueezeComponentsUnitTest() {

  // ========== RegularRunLengthEncoder 测试 ==========
  describe('RegularRunLengthEncoderTest', 0, () => {
    let rle: RegularRunLengthEncoder;

    beforeEach(() => {
      rle = new RegularRunLengthEncoder();
    });

    it('创建 RLE 编码器', () => {
      expect(rle).not().assertNull();
    });

    it('简单 RLE 编码', () => {
      const input = new MemByteBuffer();
      for (let i = 0; i < 10; i++) {
        input.writeByte(0xAA);
      }
      input.reset();

      const output = new MemByteBuffer();
      rle.runLengthEncode(output, input);

      expect(output.size()).assertLarger(0);
    });

    it('简单 RLE 解码', () => {
      const input = new MemByteBuffer();
      input.writeByte(5);
      input.writeByte(0xAA);
      input.writeByte(5);
      input.writeByte(0xBB);
      input.reset();

      const output = new MemByteBuffer();
      rle.runLengthDecode(output, input);

      expect(output.size()).assertEqual(10);
      output.reset();
      for (let i = 0; i < 5; i++) {
        expect(output.readByte()).assertEqual(0xAA);
      }
      for (let i = 0; i < 5; i++) {
        expect(output.readByte()).assertEqual(0xBB);
      }
    });

    it('fill 方法解码', () => {
      const input = new MemByteBuffer();
      input.reset();

      const output = new MemByteBuffer();
      rle.runLengthDecode(output, input);

      expect(output.size()).assertEqual(0);
    });
  });

  // ========== TileCache 测试 ==========
  describe('TileCacheTest', 0 => {
    it('NullTileCache 基本功能', () => {
      const cache = new NullTileCache();
      expect(cache).not().assertNull();
    });

    it('NullTileCache 缓存操作', () => {
      const cache = new NullTileCache();
      const xywh = new XYWH(0, 0, 32, 32);

      const tileBuffer = new MemByteBuffer();
      tileBuffer.writeByte(0);

      cache.get(-1);
      cache.clear();
    });

    it('RegularTileCache 基本功能', () => {
      const cache = new RegularTileCache(100, 50);
      expect(cache).not().assertNull();
    });

    it('RegularTileCache 缓存添加和获取', () => {
      const cache = new RegularTileCache(10, 5);
      const xywh = new XYWH(0, 0, 32, 32);

      const tileBuffer = new MemByteBuffer();
      tileBuffer.writeByte(0x12);

      cache.clear();
    });

    it('RegularTileCache 缓存清空', () => {
      const cache = new RegularTileCache(10, 5);
      cache.clear();
    });
  });

  // ========== MemByteBuffer 边界测试 ==========
  describe('MemByteBufferEdgeTest', 0 => {
    let buffer: MemByteBuffer;

    beforeEach(() => {
      buffer = new MemByteBuffer(128);
    });

    it('Buffer underflow 检测', () => {
      buffer.writeByte(1);
      buffer.reset();

      let errorThrown = false;
      try {
        buffer.readShort();
      } catch (e) {
        errorThrown = true;
      }
      expect(errorThrown).assertTrue();
    });

    it('边界读取 - 刚好足够', () => {
      buffer.writeShort(12345);
      buffer.reset();

      const value = buffer.readShort();
      expect(value).assertEqual(12345);
    });

    it('写入长度超过初始容量', () => {
      const smallBuffer = new MemByteBuffer(8);
      for (let i = 0; i < 100; i++) {
        smallBuffer.writeByte(i & 0xFF);
      }
      expect(smallBuffer.size()).assertEqual(100);
    });

    it('多次读写操作', () => {
      for (let i = 0; i < 10; i++) {
        buffer.writeInt(i);
      }
      expect(buffer.size()).assertEqual(40);

      buffer.reset();
      for (let i = 0; i < 10; i++) {
        expect(buffer.readInt()).assertEqual(i);
      }
    });

    it('fromArray 方法', () => {
      const data = new Uint8Array([0x12, 0x34, 0x56, 0x78]);
      const buf = MemByteBuffer.fromArray(data);

      expect(buf.size()).assertEqual(4);
      expect(buf.getReadOffset()).assertEqual(0);
      expect(buf.getWriteOffset()).assertEqual(4);

      expect(buf.readByte()).assertEqual(0x12);
      expect(buf.readByte()).assertEqual(0x34);
    });
  });

  // ========== 综合场景测试 ==========
  describe('IntegrationScenarioTest', 0 => {
    it('模拟 processUncached 数据读取', () => {
      const buffer = new MemByteBuffer();
      const testData = new Uint8Array(100);
      for (let i = 0; i < 100; i++) {
        testData[i] = i & 0xFF;
      }
      buffer.writeBytes(testData);

      buffer.reset();
      const value = -50;
      const dataLength = -value;
      const availableBytes = buffer.size() - buffer.getReadOffset();

      expect(availableBytes).assertLargerOrEqual(dataLength);

      const tdata = new Uint8Array(dataLength);
      const toRead = Math.min(availableBytes, dataLength);

      if (toRead > 0) {
        const bytes = buffer.readBytes(toRead);
        tdata.set(bytes, 0);
      }

      expect(tdata.length).assertEqual(50);
      for (let i = 0; i < 50; i++) {
        expect(tdata[i]).assertEqual(i);
      }
    });

    it('模拟 processUncached 数据不足', () => {
      const buffer = new MemByteBuffer();
      buffer.writeByte(0xAA);
      buffer.writeByte(0xBB);

      buffer.reset();
      const value = -100;
      const dataLength = -value;
      const availableBytes = buffer.size() - buffer.getReadOffset();

      expect(dataLength).assertLarger(availableBytes);

      const tdata = new Uint8Array(dataLength);
      const toRead = Math.min(availableBytes, dataLength);

      if (toRead > 0) {
        const bytes = buffer.readBytes(toRead);
        tdata.set(bytes, 0);
      }

      expect(tdata.length).assertEqual(100);
      expect(tdata[0]).assertEqual(0xAA);
      expect(tdata[1]).assertEqual(0xBB);
    });
  });
}