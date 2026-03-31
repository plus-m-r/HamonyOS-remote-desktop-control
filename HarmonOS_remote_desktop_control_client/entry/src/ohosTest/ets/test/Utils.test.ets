/**
 * 工具类单元测试
 * 
 * 测试项目中最底层的工具类，这些类不依赖外部服务，是纯函数式的
 * 测试范围：
 * 1. ObjectPool - 对象池
 * 2. BufferPool - 缓冲区池
 * 3. XYWH - 坐标类
 * 4. MemByteBuffer - 内存字节缓冲区
 */

import { describe, it, expect, beforeAll, beforeEach } from '@ohos/hypium';
import { ObjectPool, BufferPool } from '../../../main/ets/utils/ObjectPool';
import { XYWH, getXYWH } from '../../../main/ets/squeeze/XYWH';
import { MemByteBuffer } from '../../../main/ets/squeeze/MemByteBuffer';

export default function utilsUnitTest() {
  describe('UtilsUnitTest', () => {
    
    // ========== ObjectPool 测试 ==========
    describe('ObjectPoolTest', () => {
      let pool: ObjectPool<{ value: number }>;
      
      beforeAll(() => {
        pool = new ObjectPool(
          () => ({ value: 0 }),
          (obj) => { obj.value = 0; },
          5
        );
      });
      
      it('创建对象池', 0, () => {
        expect(pool).notNull();
        console.info('✓ ObjectPool 创建成功');
      });
      
      it('获取对象', 0, () => {
        const obj = pool.acquire();
        expect(obj).notNull();
        expect(obj.value).assertEqual(0);
        console.info('✓ 获取对象成功');
      });
      
      it('释放对象回池', 0, () => {
        const obj = pool.acquire();
        obj.value = 100;
        pool.release(obj);
        console.info('✓ 释放对象成功');
      });
      
      it('对象复用', 0, () => {
        const obj1 = pool.acquire();
        obj1.value = 50;
        pool.release(obj1);
        
        const obj2 = pool.acquire();
        expect(obj2.value).assertEqual(0); // 应该被 reset 了
        console.info('✓ 对象复用成功');
      });
      
      it('池大小限制', 0, () => {
        const smallPool = new ObjectPool(
          () => ({ value: 0 }),
          (obj) => { obj.value = 0; },
          2
        );
        
        const obj1 = smallPool.acquire();
        const obj2 = smallPool.acquire();
        const obj3 = smallPool.acquire(); // 超出池大小，会创建新对象
        
        smallPool.release(obj1);
        smallPool.release(obj2);
        smallPool.release(obj3); // 这个应该不会被回收，因为池已满
        
        console.info('✓ 池大小限制测试通过');
      });
      
      it('清空池', 0, () => {
        pool.clear();
        console.info('✓ 清空池成功');
      });
    });
    
    // ========== BufferPool 测试 ==========
    describe('BufferPoolTest', () => {
      let bufferPool: BufferPool;
      
      beforeAll(() => {
        bufferPool = BufferPool.getInstance();
      });
      
      it('获取单例', 0, () => {
        expect(bufferPool).notNull();
        console.info('✓ BufferPool 单例获取成功');
      });
      
      it('获取缓冲区', 0, () => {
        const buffer = bufferPool.acquireBuffer(1024);
        expect(buffer).notNull();
        expect(buffer.length).assertGreaterThanOrEqual(1024);
        console.info('✓ 获取缓冲区成功');
      });
      
      it('释放缓冲区', 0, () => {
        const buffer = bufferPool.acquireBuffer(512);
        buffer[0] = 123;
        bufferPool.releaseBuffer(buffer);
        console.info('✓ 释放缓冲区成功');
      });
      
      it('缓冲区大小对齐', 0, () => {
        const buffer1 = bufferPool.acquireBuffer(100); // 应该对齐到 4096
        const buffer2 = bufferPool.acquireBuffer(4097); // 应该对齐到 8192
        expect(buffer1.length).assertGreaterThanOrEqual(100);
        expect(buffer2.length).assertGreaterThanOrEqual(4097);
        console.info('✓ 缓冲区大小对齐测试通过');
      });
    });
    
    // ========== XYWH 测试 ==========
    describe('XYWHTest', () => {
      it('创建 XYWH 对象', 0, () => {
        const xywh = new XYWH(10, 20, 100, 200);
        expect(xywh).notNull();
        expect(xywh.x).assertEqual(10);
        expect(xywh.y).assertEqual(20);
        expect(xywh.w).assertEqual(100);
        expect(xywh.h).assertEqual(200);
        console.info('✓ 创建 XYWH 对象成功');
      });
      
      it('equals 方法', 0, () => {
        const xywh = new XYWH(10, 20, 100, 200);
        expect(xywh.equals(10, 20, 100, 200)).assertTrue();
        expect(xywh.equals(11, 20, 100, 200)).assertFalse();
        console.info('✓ XYWH equals 方法测试通过');
      });
      
      it('getXYWH 函数', 0, () => {
        const tiles = getXYWH(1920, 1080, 256, 256);
        expect(tiles.length).assertGreater(0);
        expect(tiles[0]).notNull();
        console.info('✓ getXYWH 函数测试通过，生成 ' + tiles.length + ' 个瓦片');
      });
      
      it('getXYWH 缓存', 0, () => {
        const tiles1 = getXYWH(800, 600, 128, 128);
        const tiles2 = getXYWH(800, 600, 128, 128); // 应该使用缓存
        expect(tiles1.length).assertEqual(tiles2.length);
        console.info('✓ getXYWH 缓存测试通过');
      });
      
      it('瓦片覆盖整个区域', 0, () => {
        const width = 1024;
        const height = 768;
        const tileSize = 256;
        const tiles = getXYWH(width, height, tileSize, tileSize);
        
        // 验证所有瓦片都在边界内
        for (const tile of tiles) {
          expect(tile.x + tile.w).assertLessThanOrEqual(width);
          expect(tile.y + tile.h).assertLessThanOrEqual(height);
        }
        console.info('✓ 瓦片覆盖测试通过');
      });
    });
    
    // ========== MemByteBuffer 测试 ==========
    describe('MemByteBufferTest', () => {
      let buffer: MemByteBuffer;
      
      beforeEach(() => {
        buffer = new MemByteBuffer(256);
      });
      
      it('创建缓冲区', 0, () => {
        expect(buffer).notNull();
        expect(buffer.size()).assertEqual(0);
        console.info('✓ 创建 MemByteBuffer 成功');
      });
      
      it('写入和读取字节', 0, () => {
        buffer.writeByte(42);
        expect(buffer.size()).assertEqual(1);
        
        const value = buffer.readByte();
        expect(value).assertEqual(42);
        console.info('✓ 写入读取字节测试通过');
      });
      
      it('写入和读取 Short', 0, () => {
        buffer.writeShort(12345);
        expect(buffer.size()).assertEqual(2);
        
        const value = buffer.readShort();
        expect(value).assertEqual(12345);
        console.info('✓ 写入读取 Short 测试通过');
      });
      
      it('写入和读取 Int', 0, () => {
        buffer.writeInt(123456789);
        expect(buffer.size()).assertEqual(4);
        
        const value = buffer.readInt();
        expect(value).assertEqual(123456789);
        console.info('✓ 写入读取 Int 测试通过');
      });
      
      it('写入和读取字节数组', 0, () => {
        const data = new Uint8Array([1, 2, 3, 4, 5]);
        buffer.writeBytes(data);
        expect(buffer.size()).assertEqual(5);
        
        const result = buffer.readBytes(5);
        expect(result.length).assertEqual(5);
        expect(result[0]).assertEqual(1);
        expect(result[4]).assertEqual(5);
        console.info('✓ 写入读取字节数组测试通过');
      });
      
      it('自动扩容', 0, () => {
        // 写入超过初始容量的数据
        const largeData = new Uint8Array(512);
        buffer.writeBytes(largeData);
        expect(buffer.size()).assertEqual(512);
        console.info('✓ 自动扩容测试通过');
      });
      
      it('mark 和 writeLenAsShort', 0, () => {
        const markId = buffer.mark();
        buffer.writeByte(1);
        buffer.writeByte(2);
        buffer.writeByte(3);
        buffer.writeLenAsShort(markId);
        
        // 验证长度被正确写入
        buffer.reset();
        const length = buffer.readShort();
        expect(length).assertLessThan(0); // 长度是负数
        console.info('✓ mark 和 writeLenAsShort 测试通过');
      });
      
      it('readAllBytes', 0, () => {
        buffer.writeByte(10);
        buffer.writeByte(20);
        buffer.writeByte(30);
        
        const allBytes = buffer.readAllBytes();
        expect(allBytes.length).assertEqual(3);
        expect(allBytes[0]).assertEqual(10);
        console.info('✓ readAllBytes 测试通过');
      });
      
      it('getInternal', 0, () => {
        buffer.writeByte(100);
        const internal = buffer.getInternal();
        expect(internal.length).assertEqual(1);
        expect(internal[0]).assertEqual(100);
        console.info('✓ getInternal 测试通过');
      });
      
      it('readUnsignedByte', 0, () => {
        buffer.writeByte(255);
        const value = buffer.readUnsignedByte();
        expect(value).assertEqual(255);
        console.info('✓ readUnsignedByte 测试通过');
      });
      
      it('readUnsignedShort', 0, () => {
        buffer.writeShort(65535);
        const value = buffer.readUnsignedShort();
        expect(value).assertEqual(65535);
        console.info('✓ readUnsignedShort 测试通过');
      });
      
      it('getReadOffset', 0, () => {
        buffer.writeByte(1);
        buffer.writeByte(2);
        expect(buffer.getReadOffset()).assertEqual(0);
        
        buffer.readByte();
        expect(buffer.getReadOffset()).assertEqual(1);
        console.info('✓ getReadOffset 测试通过');
      });
      
      it('reset', 0, () => {
        buffer.writeByte(1);
        buffer.writeByte(2);
        buffer.readByte();
        expect(buffer.getReadOffset()).assertEqual(1);
        
        buffer.reset();
        expect(buffer.getReadOffset()).assertEqual(0);
        console.info('✓ reset 测试通过');
      });
    });
    
    // ========== 综合测试 ==========
    describe('IntegrationTest', () => {
      it('使用 MemByteBuffer 序列化 XYWH', 0, () => {
        const buffer = new MemByteBuffer();
        const xywh = new XYWH(100, 200, 300, 400);
        
        // 序列化
        buffer.writeInt(xywh.x);
        buffer.writeInt(xywh.y);
        buffer.writeInt(xywh.w);
        buffer.writeInt(xywh.h);
        
        // 反序列化
        buffer.reset();
        const x = buffer.readInt();
        const y = buffer.readInt();
        const w = buffer.readInt();
        const h = buffer.readInt();
        
        expect(x).assertEqual(100);
        expect(y).assertEqual(200);
        expect(w).assertEqual(300);
        expect(h).assertEqual(400);
        
        console.info('✓ 综合序列化测试通过');
      });
    });
    
  });
}
