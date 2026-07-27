/**
 * 工具类单元测试
 * 
 * 测试项目中最底层的工具类，这些类不依赖外部服务，是纯函数式的
 * 测试范围：
 * 1. ObjectPool - 对象池
 * 2. BufferPool - 缓冲区池
 * 3. XYWH - 坐标类
 * 4. MemByteBuffer - 内存字节缓冲区
 * 5. LogManager - 日志管理器
 */

import { describe, it, expect, beforeAll, beforeEach } from '@ohos/hypium';
import { ObjectPool, BufferPool, PooledBuffer } from '../../../../main/ets/utils/ObjectPool';
import { XYWH, getXYWH } from '../../../../main/ets/squeeze/XYWH';
import { MemByteBuffer } from '../../../../main/ets/squeeze/MemByteBuffer';
import { LogManager, LogLevel } from '../../../../main/ets/utils/LogManager';

interface TestObject {
  value: number;
}

export default function UtilsUnitTest() {
  
  // ========== ObjectPool 测试 ==========
  describe('ObjectPoolTest', 0, () => {
    let pool: ObjectPool<TestObject>;
    
    beforeAll(() => {
      pool = new ObjectPool(
        (): TestObject => ({ value: 0 }),
        (obj: TestObject) => { obj.value = 0; },
        5
      );
    });
    
    it('创建对象池', () => {
      expect(pool).not().assertNull();
    });
    
    it('获取对象', () => {
      const obj = pool.acquire();
      expect(obj).not().assertNull();
      expect(obj.value).assertEqual(0);
    });
    
    it('释放对象回池', () => {
      const obj = pool.acquire();
      obj.value = 100;
      pool.release(obj);
    });
    
    it('对象复用', () => {
      const obj1 = pool.acquire();
      obj1.value = 50;
      pool.release(obj1);
      
      const obj2 = pool.acquire();
      expect(obj2.value).assertEqual(0);
    });
    
    it('池大小限制', () => {
      const smallPool = new ObjectPool<TestObject>(
        (): TestObject => ({ value: 0 }),
        (obj: TestObject) => { obj.value = 0; },
        2
      );
      
      const obj1 = smallPool.acquire();
      const obj2 = smallPool.acquire();
      const obj3 = smallPool.acquire();
      
      smallPool.release(obj1);
      smallPool.release(obj2);
      smallPool.release(obj3);
    });
    
    it('清空池', () => {
      pool.clear();
    });
  });
  
  // ========== BufferPool 测试 ==========
  describe('BufferPoolTest', 0, () => {
    let bufferPool: BufferPool;
    
    beforeAll(() => {
      bufferPool = BufferPool.getInstance();
    });
    
    it('获取单例', () => {
      expect(bufferPool).not().assertNull();
    });
    
    it('获取缓冲区', () => {
      const pooled: PooledBuffer = bufferPool.acquireBuffer(1024);
      expect(pooled).not().assertNull();
      expect(pooled.data.length).assertLargerOrEqual(1024);
    });
    
    it('释放缓冲区', () => {
      const pooled: PooledBuffer = bufferPool.acquireBuffer(512);
      pooled.data[0] = 123;
      bufferPool.releaseBuffer(pooled);
    });
    
    it('缓冲区大小对齐', () => {
      const pooled1: PooledBuffer = bufferPool.acquireBuffer(100);
      const pooled2: PooledBuffer = bufferPool.acquireBuffer(4097);
      expect(pooled1.data.length).assertLargerOrEqual(100);
      expect(pooled2.data.length).assertLargerOrEqual(4097);
    });
  });
  
  // ========== XYWH 测试 ==========
  describe('XYWHTest', 0, () => {
    it('创建 XYWH 对象', () => {
      const xywh = new XYWH(10, 20, 100, 200);
      expect(xywh.x).assertEqual(10);
      expect(xywh.y).assertEqual(20);
      expect(xywh.w).assertEqual(100);
      expect(xywh.h).assertEqual(200);
    });
    
    it('equals 方法', () => {
      const xywh = new XYWH(10, 20, 100, 200);
      expect(xywh.equals(10, 20, 100, 200)).assertTrue();
      expect(xywh.equals(11, 20, 100, 200)).assertFalse();
    });
    
    it('getXYWH 函数', () => {
      const tiles = getXYWH(1920, 1080, 256, 256);
      expect(tiles.length).assertLarger(0);
      expect(tiles[0]).not().assertNull();
    });
    
    it('getXYWH 缓存', () => {
      const tiles1 = getXYWH(800, 600, 128, 128);
      const tiles2 = getXYWH(800, 600, 128, 128);
      expect(tiles1.length).assertEqual(tiles2.length);
    });
    
    it('瓦片覆盖整个区域', () => {
      const width = 1024;
      const height = 768;
      const tileSize = 256;
      const tiles = getXYWH(width, height, tileSize, tileSize);
      
      for (const tile of tiles) {
        expect(tile.x + tile.w).assertLessOrEqual(width);
        expect(tile.y + tile.h).assertLessOrEqual(height);
      }
    });
  });
  
  // ========== MemByteBuffer 测试 ==========
  describe('MemByteBufferTest', 0, () => {
    let buffer: MemByteBuffer;
    
    beforeEach(() => {
      buffer = new MemByteBuffer(256);
    });
    
    it('创建缓冲区', () => {
      expect(buffer).not().assertNull();
      expect(buffer.size()).assertEqual(0);
    });
    
    it('写入和读取字节', () => {
      buffer.writeByte(42);
      expect(buffer.size()).assertEqual(1);
      
      const value = buffer.readByte();
      expect(value).assertEqual(42);
    });
    
    it('写入和读取 Short', () => {
      buffer.writeShort(12345);
      expect(buffer.size()).assertEqual(2);
      
      const value = buffer.readShort();
      expect(value).assertEqual(12345);
    });
    
    it('写入和读取 Int', () => {
      buffer.writeInt(123456789);
      expect(buffer.size()).assertEqual(4);
      
      const value = buffer.readInt();
      expect(value).assertEqual(123456789);
    });
    
    it('写入和读取字节数组', () => {
      const data = new Uint8Array([1, 2, 3, 4, 5]);
      buffer.writeBytes(data);
      expect(buffer.size()).assertEqual(5);
      
      const result = buffer.readBytes(5);
      expect(result.length).assertEqual(5);
      expect(result[0]).assertEqual(1);
      expect(result[4]).assertEqual(5);
    });
    
    it('自动扩容', () => {
      const largeData = new Uint8Array(512);
      buffer.writeBytes(largeData);
      expect(buffer.size()).assertEqual(512);
    });
    
    it('mark 和 writeLenAsShort', () => {
      const markId = buffer.mark();
      buffer.writeByte(1);
      buffer.writeByte(2);
      buffer.writeByte(3);
      buffer.writeLenAsShort(markId);
      
      buffer.reset();
      const length = buffer.readShort();
      expect(length).assertLess(0);
    });
    
    it('readAllBytes', () => {
      buffer.writeByte(10);
      buffer.writeByte(20);
      buffer.writeByte(30);
      
      const allBytes = buffer.readAllBytes();
      expect(allBytes.length).assertEqual(3);
      expect(allBytes[0]).assertEqual(10);
    });
    
    it('getInternal', () => {
      buffer.writeByte(100);
      const internal = buffer.getInternal();
      expect(internal.length).assertEqual(1);
      expect(internal[0]).assertEqual(100);
    });
    
    it('readUnsignedByte', () => {
      buffer.writeByte(255);
      const value = buffer.readUnsignedByte();
      expect(value).assertEqual(255);
    });
    
    it('readUnsignedShort', () => {
      buffer.writeShort(65535);
      const value = buffer.readUnsignedShort();
      expect(value).assertEqual(65535);
    });
    
    it('getReadOffset', () => {
      buffer.writeByte(1);
      buffer.writeByte(2);
      expect(buffer.getReadOffset()).assertEqual(0);
      
      buffer.readByte();
      expect(buffer.getReadOffset()).assertEqual(1);
    });
    
    it('getWriteOffset', () => {
      expect(buffer.getWriteOffset()).assertEqual(0);
      
      buffer.writeByte(1);
      expect(buffer.getWriteOffset()).assertEqual(1);
      
      buffer.writeShort(2);
      expect(buffer.getWriteOffset()).assertEqual(3);
    });
    
    it('reset', () => {
      buffer.writeByte(1);
      buffer.writeByte(2);
      buffer.readByte();
      expect(buffer.getReadOffset()).assertEqual(1);
      
      buffer.reset();
      expect(buffer.getReadOffset()).assertEqual(0);
    });
    
    it('fill 方法', () => {
      buffer.fill(5, 0xAA);
      expect(buffer.size()).assertEqual(5);
      
      buffer.reset();
      for (let i = 0; i < 5; i++) {
        expect(buffer.readByte()).assertEqual(0xAA);
      }
    });
    
    it('fill 方法多次调用', () => {
      buffer.fill(2, 0x11);
      buffer.fill(3, 0x22);
      expect(buffer.size()).assertEqual(5);
      
      buffer.reset();
      expect(buffer.readByte()).assertEqual(0x11);
      expect(buffer.readByte()).assertEqual(0x11);
      expect(buffer.readByte()).assertEqual(0x22);
      expect(buffer.readByte()).assertEqual(0x22);
      expect(buffer.readByte()).assertEqual(0x22);
    });
    
    it('readShort 负数读取', () => {
      buffer.writeShort(-12345);
      expect(buffer.size()).assertEqual(2);
      
      buffer.reset();
      const value = buffer.readShort();
      expect(value).assertEqual(-12345);
    });
    
    it('readShort 最小值 -32768', () => {
      buffer.writeShort(-32768);
      expect(buffer.size()).assertEqual(2);
      
      buffer.reset();
      const value = buffer.readShort();
      expect(value).assertEqual(-32768);
    });
    
    it('readShort 最大值 32767', () => {
      buffer.writeShort(32767);
      expect(buffer.size()).assertEqual(2);
      
      buffer.reset();
      const value = buffer.readShort();
      expect(value).assertEqual(32767);
    });
  });
  
  // ========== 综合测试 ==========
  describe('IntegrationTest', 0, () => {
    it('使用 MemByteBuffer 序列化 XYWH', () => {
      const buffer = new MemByteBuffer();
      const xywh = new XYWH(100, 200, 300, 400);
      
      buffer.writeInt(xywh.x);
      buffer.writeInt(xywh.y);
      buffer.writeInt(xywh.w);
      buffer.writeInt(xywh.h);
      
      buffer.reset();
      const x = buffer.readInt();
      const y = buffer.readInt();
      const w = buffer.readInt();
      const h = buffer.readInt();
      
      expect(x).assertEqual(100);
      expect(y).assertEqual(200);
      expect(w).assertEqual(300);
      expect(h).assertEqual(400);
    });
  });
  
  // ========== LogManager 测试 ==========
  describe('LogManagerTest', 0, () => {
    let logManager: LogManager;
    
    beforeAll(() => {
      logManager = LogManager.getInstance();
    });
    
    it('获取LogManager单例', () => {
      expect(logManager).not().assertNull();
      const anotherManager = LogManager.getInstance();
      expect(anotherManager).assertEqual(logManager);
    });
    
    it('设置日志级别', () => {
      logManager.setLogLevel(LogLevel.DEBUG);
    });
    
    it('启用调试模式', () => {
      logManager.enableDebugMode();
      expect(logManager.isDebug()).assertTrue();
    });
    
    it('禁用调试模式', () => {
      logManager.disableDebugMode();
      expect(logManager.isDebug()).assertFalse();
    });
    
    it('测试DEBUG日志级别', () => {
      logManager.setLogLevel(LogLevel.DEBUG);
      logManager.debug(0x0000, 'test', 'Test debug log');
    });
    
    it('测试INFO日志级别', () => {
      logManager.setLogLevel(LogLevel.INFO);
      logManager.info(0x0000, 'test', 'Test info log');
    });
    
    it('测试WARN日志级别', () => {
      logManager.setLogLevel(LogLevel.WARN);
      logManager.warn(0x0000, 'test', 'Test warn log');
    });
    
    it('测试ERROR日志级别', () => {
      logManager.setLogLevel(LogLevel.ERROR);
      logManager.error(0x0000, 'test', 'Test error log');
    });
    
    it('测试控制台日志', () => {
      logManager.enableDebugMode();
      logManager.consoleLog('Test console log');
      logManager.consoleError('Test console error');
      logManager.disableDebugMode();
    });
  });
}