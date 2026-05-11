/**
 * 统一压缩器接口（异步流式 - HarmonyOS版本）
 * 
 * <p>设计原则：</p>
 * <ul>
 *   <li>只支持异步操作，避免阻塞UI线程</li>
 *   <li>只支持流式处理，适合大数据传输场景</li>
 *   <li>跨平台一致：与Java端使用相同的接口语义</li>
 *   <li>资源管理：实现类必须正确管理底层资源</li>
 * </ul>
 * 
 * <p>使用示例：</p>
 * <pre>{@code
 * // 创建压缩器
 * const compressor = CompressorFactory.createZstdCompressor(config);
 * 
 * // 异步压缩
 * try {
 *   await compressor.compress(inputStream, outputStream);
 *   console.log('压缩完成');
 * } catch (error) {
 *   console.error('压缩失败:', error);
 * }
 * 
 * // 使用后关闭
 * compressor.close();
 * }</pre>
 * 
 * @author 方寸控技术团队
 * @version 1.0
 * @since 2026-05-10
 */
export interface ICompressor {
  
  /**
   * 异步流式压缩
   * 
   * <p>从输入流读取数据，压缩后写入输出流。操作完全异步执行，
   * 返回Promise，不阻塞调用线程。</p>
   * 
   * @param inputStream 原始数据输入流（ArrayBuffer或Uint8Array）
   * @param outputStream 压缩数据输出回调函数
   * @returns Promise，压缩完成后resolve
   * @throws CompressionError 如果压缩失败
   */
  compress(
    inputStream: ArrayBuffer | Uint8Array,
    outputStream: (data: Uint8Array) => void
  ): Promise<void>;
  
  /**
   * 异步流式解压
   * 
   * <p>从输入流读取压缩数据，解压后写入输出流。操作完全异步执行，
   * 返回Promise，不阻塞调用线程。</p>
   * 
   * @param inputStream 压缩数据输入流（ArrayBuffer或Uint8Array）
   * @param outputStream 原始数据输出回调函数
   * @returns Promise，解压完成后resolve
   * @throws CompressionError 如果解压失败
   */
  decompress(
    inputStream: ArrayBuffer | Uint8Array,
    outputStream: (data: Uint8Array) => void
  ): Promise<void>;
  
  /**
   * 获取压缩方法标识
   * 
   * @returns 压缩方法枚举值
   */
  getMethod(): CompressionMethod;
  
  /**
   * 获取当前配置
   * 
   * @returns 压缩器配置对象
   */
  getConfig(): CompressorConfig;
  
  /**
   * 更新配置
   * 
   * <p>注意：配置更新可能影响正在进行的压缩/解压操作，
   * 建议在空闲时更新配置。</p>
   * 
   * @param config 新的配置对象
   * @throws CompressionError 如果配置无效
   */
  updateConfig(config: CompressorConfig): Promise<void>;
  
  /**
   * 关闭压缩器，释放所有资源
   * 
   * <p>关闭后不能再进行压缩或解压操作。
   * 应该在使用完毕后显式调用此方法。</p>
   */
  close(): void;
}
