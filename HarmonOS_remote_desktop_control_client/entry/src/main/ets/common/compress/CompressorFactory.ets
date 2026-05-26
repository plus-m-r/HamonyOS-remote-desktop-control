import { ICompressor } from './ICompressor';
import { CompressionMethod } from './CompressionMethod';
import { CompressorConfig, createCompressorConfig } from './CompressorConfig';
import { CompressionError, CompressionErrorCode } from './CompressionError';
import { ZstdStreamCompressor } from './ZstdStreamCompressor';
import { Lz4StreamCompressor } from './Lz4StreamCompressor';
import { SnappyStreamCompressor } from './SnappyStreamCompressor';
import { NoneStreamCompressor } from './NoneStreamCompressor';

/**
 * 压缩器工厂（HarmonyOS版本）
 *
 * <p>统一压缩器创建入口。调用方通过此工厂获取 ICompressor 实例，
 * 不需要直接引用具体的实现类。</p>
 *
 * <p>使用示例：</p>
 * <pre>{@code
 * // 通过配置创建（推荐）
 * const config = createCompressorConfig({ method: CompressionMethod.ZSTD, compressionLevel: 5 });
 * const compressor = CompressorFactory.createCompressor(config);
 *
 * // 通过快捷方法创建
 * const compressor = CompressorFactory.createZstdCompressor(5);
 * const compressor = CompressorFactory.getDefaultCompressor();
 * }
 *
 * <p>工厂职责：</p>
 * <ul>
 *   <li>根据 CompressionMethod 路由到对应的实现类</li>
 *   <li>封装配置构建逻辑（快捷方法内部调用 createCompressorConfig）</li>
 *   <li>集中处理创建过程中的错误（null 配置、不支持的算法）</li>
 * </ul>
 *
 * @author 方寸控技术团队
 * @version 1.0
 * @since 2026-05-10
 */
export class CompressorFactory {
  /**
   * 默认压缩级别（ZSTD 推荐中等级别，兼顾速度与压缩率）
   */
  private static readonly DEFAULT_COMPRESSION_LEVEL: number = 3;

  /**
   * 私有构造函数，禁止实例化工厂类
   */
  private constructor() {
    throw new UnsupportedOperationError('Factory class cannot be instantiated');
  }

  /**
   * 通用创建入口：根据 config.method 自动选择实现类
   *
   * 路由规则：
   *   ZSTD   → ZstdStreamCompressor   高压缩率，推荐用于网络传输
   *   LZ4    → Lz4StreamCompressor     极速压缩，适合低延迟场景
   *   SNAPPY → SnappyStreamCompressor  均衡方案，Google 标准
   *   NONE   → NoneStreamCompressor    透传，不压缩（测试/降级）
   *
   * @param config 压缩配置（包含 method、compressionLevel 等）
   * @returns 匹配的 ICompressor 实例
   * @throws CompressionError(config == null → CONFIG_ERROR)
   * @throws CompressionError(未知 method → UNSUPPORTED_METHOD)
   */
  static createCompressor(config: CompressorConfig): ICompressor {
    if (config == null) {
      throw new CompressionError(
        CompressionErrorCode.CONFIG_ERROR,
        'Configuration cannot be null'
      );
    }

    return CompressorFactory.createCompressorInternal(config);
  }

  /**
   * 内部路由方法，按 method 分发到具体实现类的构造函数
   *
   * 拆分为独立方法的原因：
   *   保持 createCompressor 的 null 校验逻辑与路由逻辑分离，
   *   让快捷方法（如 createZstdCompressor）也能复用路由逻辑。
   *
   * @param config 经过 null 校验的合法配置
   * @returns ICompressor 实例
   */
  private static createCompressorInternal(config: CompressorConfig): ICompressor {
    switch (config.method) {
      case CompressionMethod.ZSTD:
        return new ZstdStreamCompressor(config);

      case CompressionMethod.LZ4:
        return new Lz4StreamCompressor(config);

      case CompressionMethod.SNAPPY:
        return new SnappyStreamCompressor(config);

      case CompressionMethod.NONE:
        return new NoneStreamCompressor(config);

      default:
        throw new CompressionError(
          CompressionErrorCode.UNSUPPORTED_METHOD,
          `Unsupported compression method: ${config.method}`,
        );
    }
  }

  /**
   * 创建 ZSTD 压缩器（快捷方法）
   *
   * ZSTD 是系统默认推荐算法：
   * - 默认 level=3，在速度和压缩率之间取得良好平衡
   * - 与 Java 端 ZstdCompressor 使用相同的底层算法（zstd-jni ↔ library_decompressor）
   * - 支持 compressionLevel 1-9，越高压缩率越好但越慢
   *
   * @param compressionLevel 压缩级别（1-9），不传则默认 3
   * @returns ZstdStreamCompressor 实例
   */
  static createZstdCompressor(compressionLevel?: number): ICompressor {
    const level = compressionLevel ?? CompressorFactory.DEFAULT_COMPRESSION_LEVEL;
    const config = createCompressorConfig({
      method: CompressionMethod.ZSTD,
      compressionLevel: level
    });
    return CompressorFactory.createCompressor(config);
  }

  /**
   * 创建 LZ4 压缩器（快捷方法）
   *
   * LZ4 以极致的压缩/解压速度著称：
   * - 默认 level=1，追求最低延迟
   * - LZ4 的压缩率不如 ZSTD，但压缩解压速度更快
   * - 适合内网低延迟场景或 CPU 敏感环境
   *
   * @param compressionLevel 压缩级别，不传则默认 1
   * @returns Lz4StreamCompressor 实例
   */
  static createLz4Compressor(compressionLevel?: number): ICompressor {
    const config = createCompressorConfig({
      method: CompressionMethod.LZ4,
      compressionLevel: compressionLevel ?? 1
    });
    return CompressorFactory.createCompressor(config);
  }

  /**
   * 创建 Snappy 压缩器（快捷方法）
   *
   * Snappy 特点：
   * - Google 开发的压缩算法，追求高速而非高压缩率
   * - 不支持压缩级别参数（底层库忽略 level）
   * - 与 Hadoop、Cassandra 等生态兼容
   *
   * @returns SnappyStreamCompressor 实例
   */
  static createSnappyCompressor(): ICompressor {
    const config = createCompressorConfig({ method: CompressionMethod.SNAPPY });
    return CompressorFactory.createCompressor(config);
  }

  /**
   * 获取系统默认压缩器
   *
   * 返回 ZSTD(level=3)，与 Java 端 CompressorFactory.getDefaultCompressor() 保持一致。
   * 在不确定用什么算法时，选 ZSTD 就是最稳妥的选择。
   *
   * @returns 默认压缩器
   */
  static getDefaultCompressor(): ICompressor {
    return CompressorFactory.createZstdCompressor(CompressorFactory.DEFAULT_COMPRESSION_LEVEL);
  }
}

/**
 * 不支持的操作异常（内部使用）
 *
 * 用于工厂类的私有构造方法，防止通过反射或内部调用意外实例化工厂。
 * 不对外暴露，调用方不会捕获到此异常。
 */
class UnsupportedOperationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'UnsupportedOperationError';
  }
}