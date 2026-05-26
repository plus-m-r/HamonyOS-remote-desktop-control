import { ICompressor } from './ICompressor';
import { CompressionMethod } from './CompressionMethod';
import { CompressorConfig } from './CompressorConfig';
import { CompressionError, CompressionErrorCode } from './CompressionError';

/**
 * 无压缩流式压缩器（HarmonyOS版本）
 *
 * <p>不执行任何压缩/解压操作，直接将输入数据复制一份传给输出回调。</p>
 *
 * <p>使用场景：</p>
 * <ul>
 *   <li>单元测试：验证 ICompressor 接口契约的正确性</li>
 *   <li>降级策略：在 CPU 资源紧张或无需压缩时以零开销透传数据</li>
 *   <li>基准对比：作为性能测试的基线（对比压缩算法的 CPU 开销增量）</li>
 * </ul>
 *
 * <p>与其他压缩器的区别：</p>
 * <ul>
 *   <li>不依赖 library_decompressor，纯 ArkTS 实现</li>
 *   <li>compress = decompress = 创建数据副本</li>
 *   <li>updateConfig 始终抛出 CONFIG_ERROR（无参可配）</li>
 * </ul>
 *
 * @author 方寸控技术团队
 * @version 1.0
 * @since 2026-05-10
 */
export class NoneStreamCompressor implements ICompressor {
  /**
   * 压缩器配置（构造时注入，仅用于满足接口签名）
   */
  private readonly config: CompressorConfig;

  /**
   * 关闭标记
   *
   * true 表示 compress / decompress 已被禁止。
   * 初始为 false，由 close() 方法置为 true 后不可逆转。
   */
  private closed: boolean = false;

  constructor(config: CompressorConfig) {
    this.config = config;
  }

  /**
   * 异步流式"压缩"
   *
   * 不压缩，直接将输入数据的副本传给输出回调：
   *   ① 检查 closed → 抛 STREAM_CLOSED
   *   ② 空短路 → callback(空Uint8Array)
   *   ③ 数据复制 → new Uint8Array(input) 创建独立副本
   *   ④ 输出 → callback(副本)
   *
   * @param inputStream 原始数据（ArrayBuffer 或 Uint8Array）
   * @param outputStream 数据副本回调函数
   * @throws CompressionError(STREAM_CLOSED) 压缩器已关闭
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
    const data = inputStream instanceof Uint8Array
      ? new Uint8Array(inputStream)
      : new Uint8Array(inputStream);
    outputStream(data);
  }

  /**
   * 异步流式"解压"
   *
   * 与 compress 完全一致——输入数据原样输出。
   *
   * @param inputStream "压缩"数据
   * @param outputStream 数据副本回调函数
   * @throws CompressionError(STREAM_CLOSED) 压缩器已关闭
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
    const data = inputStream instanceof Uint8Array
      ? new Uint8Array(inputStream)
      : new Uint8Array(inputStream);
    outputStream(data);
  }

  getMethod(): CompressionMethod {
    return CompressionMethod.NONE;
  }

  getConfig(): CompressorConfig {
    return this.config;
  }

  /**
   * 运行时更新配置
   *
   * None 压缩器没有可配置的参数，始终抛出异常。
   *
   * @throws CompressionError(CONFIG_ERROR) 始终抛出
   */
  async updateConfig(config: CompressorConfig): Promise<void> {
    throw new CompressionError(
      CompressionErrorCode.CONFIG_ERROR,
      'NoneStreamCompressor does not support runtime config update'
    );
  }

  /**
   * 关闭压缩器
   *
   * 关闭后 compress / decompress 会立即抛出 STREAM_CLOSED 异常。
   * 多次关闭是幂等的。无底层资源需要释放。
   * getMethod / getConfig 在关闭后仍可正常调用。
   */
  close(): void {
    this.closed = true;
  }
}