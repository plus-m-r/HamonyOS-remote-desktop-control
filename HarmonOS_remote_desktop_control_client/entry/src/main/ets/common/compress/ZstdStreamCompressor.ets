import { CompressorFactory as LibraryFactory, ICompressor as LibraryICompressor } from 'library_decompressor';
import { ICompressor } from './ICompressor';
import { CompressionMethod } from './CompressionMethod';
import { CompressorConfig } from './CompressorConfig';
import { CompressionError, CompressionErrorCode } from './CompressionError';

/**
 * ZSTD 流式压缩器（HarmonyOS版本）
 *
 * <p>基于 library_decompressor 的 ZSTD 算法实现。</p>
 *
 * <p>实现说明：</p>
 * <ul>
 *   <li>底层调用：library_decompressor 的 compressAsync / decompressAsync</li>
 *   <li>线程模型：底层库在 NAPI 线程池中执行，不阻塞 JS 主线程</li>
 *   <li>输出方式：通过回调函数流式返回 Uint8Array 数据块</li>
 *   <li>资源管理：底层库为 one-shot 模式，无需显式释放</li>
 * </ul>
 *
 * @author 方寸控技术团队
 * @version 1.0
 * @since 2026-05-10
 */
export class ZstdStreamCompressor implements ICompressor {
  /**
   * 压缩器配置（构造时注入，运行时不修改）
   */
  private readonly config: CompressorConfig;

  /**
   * library_decompressor 的原生压缩器实例
   *
   * 通过 LibraryFactory.create('zstd') 创建，提供 compressAsync / decompressAsync 能力。
   * 该实例是 one-shot 模式，每个异步调用独立在 NAPI 线程池中执行。
   */
  private readonly inner: LibraryICompressor;

  /**
   * 关闭标记
   *
   * true 表示 compress / decompress 已被禁止。
   * 初始为 false，由 close() 方法置为 true 后不可逆转。
   */
  private closed: boolean = false;

  /**
   * 构造 ZSTD 流式压缩器
   *
   * 构造过程中会尝试创建底层库实例。如果底层库不可用（如未正确集成 HAR 包），
   * 会抛出 ALGORITHM_ERROR 异常，调用方可在构造阶段捕获。
   *
   * @param config 压缩器配置（method 必须是 ZSTD）
   * @throws CompressionError(ALGORITHM_ERROR) 底层库创建失败
   */
  constructor(config: CompressorConfig) {
    this.config = config;
    try {
      this.inner = LibraryFactory.create('zstd');
    } catch (e) {
      throw new CompressionError(
        CompressionErrorCode.ALGORITHM_ERROR,
        `Failed to create ZSTD stream compressor: ${e instanceof Error ? e.message : String(e)}`
      );
    }
  }

  /**
   * 异步流式压缩
   *
   * 处理流程：
   *   ① 检查 closed 标记 → 已关闭则抛 STREAM_CLOSED
   *   ② 检查空数据 → byteLength===0 则直接 callback(空Uint8Array)，跳过库调用
   *   ③ 类型适配 → Uint8Array 提取正确段落的 ArrayBuffer
   *   ④ 委托库调用 → inner.compressAsync(buffer, level)
   *   ⑤ 输出转换 → 返回的 ArrayBuffer 包装为 Uint8Array 传给 callback
   *   ⑥ 异常包装 → 库异常包装为 CompressionError(ALGORITHM_ERROR)
   *
   * @param inputStream 原始数据（ArrayBuffer 或 Uint8Array）
   * @param outputStream 压缩结果回调函数
   * @throws CompressionError(STREAM_CLOSED) 压缩器已关闭
   * @throws CompressionError(ALGORITHM_ERROR) 底层压缩失败
   */
  async compress(
    inputStream: ArrayBuffer | Uint8Array,
    outputStream: (data: Uint8Array) => void
  ): Promise<void> {
    if (this.closed) {
      throw new CompressionError(CompressionErrorCode.STREAM_CLOSED, 'Compressor is closed');
    }
    if (inputStream.byteLength === 0) {
      outputStream(new Uint8Array(0));
      return;
    }
    try {
      const buffer = inputStream instanceof Uint8Array
        ? inputStream.buffer.slice(inputStream.byteOffset, inputStream.byteOffset + inputStream.byteLength) as ArrayBuffer
        : inputStream;
      const result = await this.inner.compressAsync(buffer, this.config.compressionLevel);
      outputStream(new Uint8Array(result));
    } catch (e) {
      throw new CompressionError(
        CompressionErrorCode.ALGORITHM_ERROR,
        `ZSTD stream compression failed: ${e instanceof Error ? e.message : String(e)}`
      );
    }
  }

  /**
   * 异步流式解压
   *
   * 与 compress 对称：
   *   ① 检查 closed → 抛 STREAM_CLOSED
   *   ② 空短路 → 直接 callback(空Uint8Array)
   *   ③ 类型适配 → Uint8Array→ArrayBuffer
   *   ④ 委托 → inner.decompressAsync(buffer)
   *   ⑤ 输出 → 结果包装为 Uint8Array
   *
   * @param inputStream 压缩数据（ArrayBuffer 或 Uint8Array）
   * @param outputStream 解压结果回调函数
   * @throws CompressionError(STREAM_CLOSED) 压缩器已关闭
   * @throws CompressionError(ALGORITHM_ERROR) 底层解压失败
   */
  async decompress(
    inputStream: ArrayBuffer | Uint8Array,
    outputStream: (data: Uint8Array) => void
  ): Promise<void> {
    if (this.closed) {
      throw new CompressionError(CompressionErrorCode.STREAM_CLOSED, 'Compressor is closed');
    }
    if (inputStream.byteLength === 0) {
      outputStream(new Uint8Array(0));
      return;
    }
    try {
      const buffer = inputStream instanceof Uint8Array
        ? inputStream.buffer.slice(inputStream.byteOffset, inputStream.byteOffset + inputStream.byteLength) as ArrayBuffer
        : inputStream;
      const result = await this.inner.decompressAsync(buffer);
      outputStream(new Uint8Array(result));
    } catch (e) {
      throw new CompressionError(
        CompressionErrorCode.ALGORITHM_ERROR,
        `ZSTD stream decompression failed: ${e instanceof Error ? e.message : String(e)}`
      );
    }
  }

  getMethod(): CompressionMethod {
    return CompressionMethod.ZSTD;
  }

  getConfig(): CompressorConfig {
    return this.config;
  }

  /**
   * 运行时更新配置
   *
   * ZSTD 压缩器不支持运行时更新配置。
   * 如需更改压缩级别或参数，应创建新的压缩器实例。
   *
   * @throws CompressionError(CONFIG_ERROR) 始终抛出
   */
  async updateConfig(config: CompressorConfig): Promise<void> {
    throw new CompressionError(
      CompressionErrorCode.CONFIG_ERROR,
      'ZstdStreamCompressor does not support runtime config update, create a new instance instead'
    );
  }

  /**
   * 关闭压缩器
   *
   * 关闭后 compress / decompress 会立即抛出 STREAM_CLOSED 异常。
   * 多次关闭是幂等的——第二次调用起不产生任何效果。
   * 底层库为 one-shot 模式，不持有跨调用资源，无需向 native 层传递关闭信号。
   * getMethod / getConfig 在关闭后仍可正常调用（只读查询）。
   */
  close(): void {
    this.closed = true;
  }
}