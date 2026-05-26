import { describe, it, expect, beforeAll, beforeEach } from '@ohos/hypium';
import { CompressionMethod, fromName, fromCode, toCode } from '../../../../main/ets/common/compress/CompressionMethod';
import { CompressorConfig, createCompressorConfig, createDefaultConfig, configsEqual, cloneConfig, ConfigBuilderParams } from '../../../../main/ets/common/compress/CompressorConfig';
import { NoneStreamCompressor } from '../../../../main/ets/common/compress/NoneStreamCompressor';
import { ZstdStreamCompressor } from '../../../../main/ets/common/compress/ZstdStreamCompressor';
import { Lz4StreamCompressor } from '../../../../main/ets/common/compress/Lz4StreamCompressor';
import { SnappyStreamCompressor } from '../../../../main/ets/common/compress/SnappyStreamCompressor';
import { CompressorFactory } from '../../../../main/ets/common/compress/CompressorFactory';
import { ICompressor } from '../../../../main/ets/common/compress/ICompressor';
import { CompressionError, CompressionErrorCode } from '../../../../main/ets/common/compress/CompressionError';

export default function CompressorTest() {

  // =========================================================================
  // 第一层：CompressionMethod 枚举测试
  // =========================================================================
  describe('CompressionMethodTest', () => {
    it('枚举值正确', () => {
      expect(CompressionMethod.NONE).assertEqual('none');
      expect(CompressionMethod.ZSTD).assertEqual('zstd');
      expect(CompressionMethod.LZ4).assertEqual('lz4');
      expect(CompressionMethod.SNAPPY).assertEqual('snappy');
    });

    it('fromName 映射正确', () => {
      expect(fromName('none')).assertEqual(CompressionMethod.NONE);
      expect(fromName('zstd')).assertEqual(CompressionMethod.ZSTD);
      expect(fromName('lz4')).assertEqual(CompressionMethod.LZ4);
      expect(fromName('snappy')).assertEqual(CompressionMethod.SNAPPY);
    });

    it('fromName 大小写不敏感', () => {
      expect(fromName('NONE')).assertEqual(CompressionMethod.NONE);
      expect(fromName('Zstd')).assertEqual(CompressionMethod.ZSTD);
    });

    it('fromName 无效名称抛异常', () => {
      let thrown = false;
      try {
        fromName('invalid');
      } catch (e) {
        thrown = true;
      }
      expect(thrown).assertTrue();
    });

    it('fromCode 映射正确', () => {
      expect(fromCode(0)).assertEqual(CompressionMethod.NONE);
      expect(fromCode(1)).assertEqual(CompressionMethod.ZSTD);
      expect(fromCode(2)).assertEqual(CompressionMethod.LZ4);
      expect(fromCode(3)).assertEqual(CompressionMethod.SNAPPY);
    });

    it('fromCode 无效代码抛异常', () => {
      let thrown = false;
      try {
        fromCode(99);
      } catch (e) {
        thrown = true;
      }
      expect(thrown).assertTrue();
    });

    it('toCode 映射正确', () => {
      expect(toCode(CompressionMethod.NONE)).assertEqual(0);
      expect(toCode(CompressionMethod.ZSTD)).assertEqual(1);
      expect(toCode(CompressionMethod.LZ4)).assertEqual(2);
      expect(toCode(CompressionMethod.SNAPPY)).assertEqual(3);
    });
  });

  // =========================================================================
  // 第二层：CompressorConfig 配置测试
  // =========================================================================
  describe('CompressorConfigTest', () => {
    it('创建完整配置', () => {
      const config = createCompressorConfig({
        method: CompressionMethod.ZSTD,
        compressionLevel: 5,
        bufferSize: 128 * 1024,
        useDictionary: false
      });
      expect(config.method).assertEqual(CompressionMethod.ZSTD);
      expect(config.compressionLevel).assertEqual(5);
      expect(config.bufferSize).assertEqual(128 * 1024);
      expect(config.useDictionary).assertFalse();
      expect(config.dictionary).assertNull();
    });

    it('创建默认配置', () => {
      const config = createDefaultConfig(CompressionMethod.ZSTD);
      expect(config.method).assertEqual(CompressionMethod.ZSTD);
      expect(config.compressionLevel).assertEqual(3);
      expect(config.bufferSize).assertEqual(64 * 1024);
      expect(config.useDictionary).assertFalse();
      expect(config.dictionary).assertNull();
    });

    it('压缩级别边界值校验', () => {
      let thrown = false;
      try {
        createCompressorConfig({ method: CompressionMethod.ZSTD, compressionLevel: 0 });
      } catch (e) {
        thrown = true;
      }
      expect(thrown).assertTrue();

      thrown = false;
      try {
        createCompressorConfig({ method: CompressionMethod.ZSTD, compressionLevel: 10 });
      } catch (e) {
        thrown = true;
      }
      expect(thrown).assertTrue();
    });

    it('缓冲区大小边界值校验', () => {
      let thrown = false;
      try {
        createCompressorConfig({ method: CompressionMethod.ZSTD, bufferSize: 512 });
      } catch (e) {
        thrown = true;
      }
      expect(thrown).assertTrue();
    });

    it('配置比较-相同配置', () => {
      const config1 = createCompressorConfig({ method: CompressionMethod.ZSTD, compressionLevel: 5 });
      const config2 = createCompressorConfig({ method: CompressionMethod.ZSTD, compressionLevel: 5 });
      expect(configsEqual(config1, config2)).assertTrue();
    });

    it('配置比较-不同方法', () => {
      const config1 = createCompressorConfig({ method: CompressionMethod.ZSTD });
      const config2 = createCompressorConfig({ method: CompressionMethod.LZ4 });
      expect(configsEqual(config1, config2)).assertFalse();
    });

    it('配置比较-不同级别', () => {
      const config1 = createCompressorConfig({ method: CompressionMethod.ZSTD, compressionLevel: 3 });
      const config2 = createCompressorConfig({ method: CompressionMethod.ZSTD, compressionLevel: 9 });
      expect(configsEqual(config1, config2)).assertFalse();
    });

    it('克隆配置独立于原配置', () => {
      const original = createCompressorConfig({ method: CompressionMethod.ZSTD, compressionLevel: 5 });
      const cloned = cloneConfig(original);
      expect(configsEqual(original, cloned)).assertTrue();

      const modified = createCompressorConfig({ method: CompressionMethod.ZSTD, compressionLevel: 9 });
      expect(configsEqual(cloned, modified)).assertFalse();
    });
  });

  // =========================================================================
  // 第三层：NoneStreamCompressor 接口契约测试（无原生依赖）
  // =========================================================================
  describe('NoneStreamCompressorContractTest', () => {
    let config: CompressorConfig;
    let compressor: NoneStreamCompressor;

    beforeEach(() => {
      config = createDefaultConfig(CompressionMethod.NONE);
      compressor = new NoneStreamCompressor(config);
    });

    it('compress 返回原始数据副本', async () => {
      const input = new Uint8Array([1, 2, 3, 4, 5]);
      let output: Uint8Array = new Uint8Array(0);

      await compressor.compress(input, (data) => {
        output = data;
      });

      expect(output.length).assertEqual(input.length);
      for (let i = 0; i < input.length; i++) {
        expect(output[i]).assertEqual(input[i]);
      }
    });

    it('decompress 返回原始数据副本', async () => {
      const input = new Uint8Array([10, 20, 30]);
      let output: Uint8Array = new Uint8Array(0);

      await compressor.decompress(input, (data) => {
        output = data;
      });

      expect(output.length).assertEqual(input.length);
      for (let i = 0; i < input.length; i++) {
        expect(output[i]).assertEqual(input[i]);
      }
    });

    it('compress 空数据', async () => {
      const input = new Uint8Array(0);
      let output: Uint8Array = new Uint8Array(1);

      await compressor.compress(input, (data) => {
        output = data;
      });

      expect(output.length).assertEqual(0);
    });

    it('decompress 空数据', async () => {
      const input = new Uint8Array(0);
      let output: Uint8Array = new Uint8Array(1);

      await compressor.decompress(input, (data) => {
        output = data;
      });

      expect(output.length).assertEqual(0);
    });

    it('compress 输出不可变', async () => {
      const input = new Uint8Array([1, 2, 3]);
      let output: Uint8Array = new Uint8Array(0);

      await compressor.compress(input, (data) => {
        output = data;
      });

      input[0] = 255;
      expect(output[0]).assertEqual(1);
    });

    it('ArrayBuffer 输入类型', async () => {
      const input = new ArrayBuffer(4);
      const view = new Uint8Array(input);
      view[0] = 0xAB;
      view[1] = 0xCD;

      let output: Uint8Array = new Uint8Array(0);
      await compressor.compress(input, (data) => {
        output = data;
      });

      expect(output.length).assertEqual(4);
      expect(output[0]).assertEqual(0xAB);
      expect(output[1]).assertEqual(0xCD);
    });

    it('关闭后 compress 抛异常', async () => {
      compressor.close();
      let thrown = false;

      try {
        await compressor.compress(new Uint8Array([1]), () => {});
      } catch (e) {
        if (e instanceof CompressionError) {
          expect(e.errorCode).assertEqual(CompressionErrorCode.STREAM_CLOSED);
        }
        thrown = true;
      }
      expect(thrown).assertTrue();
    });

    it('关闭后 decompress 抛异常', async () => {
      compressor.close();
      let thrown = false;

      try {
        await compressor.decompress(new Uint8Array([1]), () => {});
      } catch (e) {
        thrown = true;
      }
      expect(thrown).assertTrue();
    });

    it('多次关闭不抛异常', () => {
      compressor.close();
      compressor.close();
      compressor.close();
    });

    it('getMethod 返回 NONE', () => {
      expect(compressor.getMethod()).assertEqual(CompressionMethod.NONE);
    });

    it('getConfig 返回配置', () => {
      expect(compressor.getConfig()).not().assertNull();
      expect(compressor.getConfig().method).assertEqual(CompressionMethod.NONE);
    });

    it('updateConfig 抛 CONFIG_ERROR', async () => {
      let thrown = false;
      try {
        await compressor.updateConfig(config);
      } catch (e) {
        if (e instanceof CompressionError) {
          expect(e.errorCode).assertEqual(CompressionErrorCode.CONFIG_ERROR);
        }
        thrown = true;
      }
      expect(thrown).assertTrue();
    });
  });

  // =========================================================================
  // 第四层：CompressorFactory 测试
  // =========================================================================
  describe('CompressorFactoryTest', () => {
    it('createCompressor 创建 ZSTD 压缩器', () => {
      const config = createCompressorConfig({ method: CompressionMethod.ZSTD });
      const compressor = CompressorFactory.createCompressor(config);
      expect(compressor).not().assertNull();
      expect(compressor.getMethod()).assertEqual(CompressionMethod.ZSTD);
      compressor.close();
    });

    it('createCompressor 创建 LZ4 压缩器', () => {
      const config = createCompressorConfig({ method: CompressionMethod.LZ4 });
      const compressor = CompressorFactory.createCompressor(config);
      expect(compressor.getMethod()).assertEqual(CompressionMethod.LZ4);
      compressor.close();
    });

    it('createCompressor 创建 Snappy 压缩器', () => {
      const config = createCompressorConfig({ method: CompressionMethod.SNAPPY });
      const compressor = CompressorFactory.createCompressor(config);
      expect(compressor.getMethod()).assertEqual(CompressionMethod.SNAPPY);
      compressor.close();
    });

    it('createCompressor 创建 None 压缩器', () => {
      const config = createCompressorConfig({ method: CompressionMethod.NONE });
      const compressor = CompressorFactory.createCompressor(config);
      expect(compressor.getMethod()).assertEqual(CompressionMethod.NONE);
      compressor.close();
    });

    it('createZstdCompressor 快捷方法', () => {
      const compressor = CompressorFactory.createZstdCompressor(5);
      expect(compressor.getMethod()).assertEqual(CompressionMethod.ZSTD);
      expect(compressor.getConfig().compressionLevel).assertEqual(5);
      compressor.close();
    });

    it('createZstdCompressor 默认压缩级别', () => {
      const compressor = CompressorFactory.createZstdCompressor();
      expect(compressor.getConfig().compressionLevel).assertEqual(3);
      compressor.close();
    });

    it('createLz4Compressor 快捷方法', () => {
      const compressor = CompressorFactory.createLz4Compressor();
      expect(compressor.getMethod()).assertEqual(CompressionMethod.LZ4);
      compressor.close();
    });

    it('createSnappyCompressor 快捷方法', () => {
      const compressor = CompressorFactory.createSnappyCompressor();
      expect(compressor.getMethod()).assertEqual(CompressionMethod.SNAPPY);
      compressor.close();
    });

    it('getDefaultCompressor 返回 ZSTD', () => {
      const compressor = CompressorFactory.getDefaultCompressor();
      expect(compressor.getMethod()).assertEqual(CompressionMethod.ZSTD);
      expect(compressor.getConfig().compressionLevel).assertEqual(3);
      compressor.close();
    });

    it('无效压缩方法抛 UNSUPPORTED_METHOD', () => {
      let thrown = false;
      let errorCode = CompressionErrorCode.INVALID_INPUT;
      try {
        const config = createCompressorConfig({
          method: 'invalid' as CompressionMethod
        });
        CompressorFactory.createCompressor(config);
      } catch (e) {
        if (e instanceof CompressionError) {
          errorCode = e.errorCode;
        }
        thrown = true;
      }
      expect(thrown).assertTrue();
      expect(errorCode).assertEqual(CompressionErrorCode.UNSUPPORTED_METHOD);
    });
  });

  // =========================================================================
  // 第五层：ZstdStreamCompressor 基础功能测试
  // =========================================================================
  describe('ZstdStreamCompressorTest', () => {
    let config: CompressorConfig;
    let compressor: ZstdStreamCompressor;

    beforeEach(() => {
      config = createCompressorConfig({ method: CompressionMethod.ZSTD, compressionLevel: 3 });
      compressor = new ZstdStreamCompressor(config);
    });

    it('压缩再解压还原小数据', async () => {
      const input = new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      let compressed: Uint8Array = new Uint8Array(0);

      await compressor.compress(input, (data) => {
        compressed = data;
      });

      expect(compressed.length).assertLarger(0);

      let decompressed: Uint8Array = new Uint8Array(0);
      await compressor.decompress(compressed, (data) => {
        decompressed = data;
      });

      expect(decompressed.length).assertEqual(input.length);
      for (let i = 0; i < input.length; i++) {
        expect(decompressed[i]).assertEqual(input[i]);
      }
    });

    it('压缩再解压还原重复数据', async () => {
      const input = new Uint8Array(1024);
      for (let i = 0; i < input.length; i++) {
        input[i] = 0xAB;
      }

      let compressed: Uint8Array = new Uint8Array(0);
      await compressor.compress(input, (data) => {
        compressed = data;
      });

      expect(compressed.length).assertLarger(0);
      expect(compressed.length < input.length).assertTrue();

      let decompressed: Uint8Array = new Uint8Array(0);
      await compressor.decompress(compressed, (data) => {
        decompressed = data;
      });

      expect(decompressed.length).assertEqual(input.length);
      for (let i = 0; i < input.length; i++) {
        expect(decompressed[i]).assertEqual(input[i]);
      }
    });

    it('空数据压缩解压', async () => {
      const input = new Uint8Array(0);
      let compressed: Uint8Array = new Uint8Array(1);

      await compressor.compress(input, (data) => {
        compressed = data;
      });
      expect(compressed.length).assertEqual(0);

      let decompressed: Uint8Array = new Uint8Array(1);
      await compressor.decompress(compressed, (data) => {
        decompressed = data;
      });
      expect(decompressed.length).assertEqual(0);
    });

    it('关闭后 compress 抛异常', async () => {
      compressor.close();
      let thrown = false;
      try {
        await compressor.compress(new Uint8Array([1]), () => {});
      } catch (e) {
        thrown = true;
      }
      expect(thrown).assertTrue();
    });

    it('getMethod 返回 ZSTD', () => {
      expect(compressor.getMethod()).assertEqual(CompressionMethod.ZSTD);
    });
  });

  // =========================================================================
  // 第六层：Lz4StreamCompressor 基础功能测试
  // =========================================================================
  describe('Lz4StreamCompressorTest', () => {
    let config: CompressorConfig;
    let compressor: Lz4StreamCompressor;

    beforeEach(() => {
      config = createCompressorConfig({ method: CompressionMethod.LZ4, compressionLevel: 1 });
      compressor = new Lz4StreamCompressor(config);
    });

    it('压缩再解压还原数据', async () => {
      const input = new Uint8Array(512);
      for (let i = 0; i < input.length; i++) {
        input[i] = i & 0xFF;
      }

      let compressed: Uint8Array = new Uint8Array(0);
      await compressor.compress(input, (data) => {
        compressed = data;
      });

      expect(compressed.length).assertLarger(0);

      let decompressed: Uint8Array = new Uint8Array(0);
      await compressor.decompress(compressed, (data) => {
        decompressed = data;
      });

      expect(decompressed.length).assertEqual(input.length);
      for (let i = 0; i < input.length; i++) {
        expect(decompressed[i]).assertEqual(input[i]);
      }
    });

    it('空数据压缩解压', async () => {
      const input = new Uint8Array(0);
      let compressed: Uint8Array = new Uint8Array(1);

      await compressor.compress(input, (data) => {
        compressed = data;
      });
      expect(compressed.length).assertEqual(0);
    });

    it('getMethod 返回 LZ4', () => {
      expect(compressor.getMethod()).assertEqual(CompressionMethod.LZ4);
    });
  });

  // =========================================================================
  // 第七层：SnappyStreamCompressor 基础功能测试
  // =========================================================================
  describe('SnappyStreamCompressorTest', () => {
    let config: CompressorConfig;
    let compressor: SnappyStreamCompressor;

    beforeEach(() => {
      config = createDefaultConfig(CompressionMethod.SNAPPY);
      compressor = new SnappyStreamCompressor(config);
    });

    it('压缩再解压还原数据', async () => {
      const input = new Uint8Array(256);
      for (let i = 0; i < input.length; i++) {
        input[i] = i & 0xFF;
      }

      let compressed: Uint8Array = new Uint8Array(0);
      await compressor.compress(input, (data) => {
        compressed = data;
      });

      expect(compressed.length).assertLarger(0);

      let decompressed: Uint8Array = new Uint8Array(0);
      await compressor.decompress(compressed, (data) => {
        decompressed = data;
      });

      expect(decompressed.length).assertEqual(input.length);
      for (let i = 0; i < input.length; i++) {
        expect(decompressed[i]).assertEqual(input[i]);
      }
    });

    it('空数据压缩解压', async () => {
      const input = new Uint8Array(0);
      let compressed: Uint8Array = new Uint8Array(1);

      await compressor.compress(input, (data) => {
        compressed = data;
      });
      expect(compressed.length).assertEqual(0);
    });

    it('getMethod 返回 SNAPPY', () => {
      expect(compressor.getMethod()).assertEqual(CompressionMethod.SNAPPY);
    });
  });
}