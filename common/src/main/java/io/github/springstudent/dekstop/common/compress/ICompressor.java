package io.github.springstudent.dekstop.common.compress;

import java.io.IOException;
import java.util.concurrent.CompletableFuture;

/**
 * 统一压缩器接口（异步流式）
 * 
 * <p>设计原则：</p>
 * <ul>
 *   <li>只支持异步操作，避免阻塞调用线程</li>
 *   <li>只支持流式处理，适合大数据传输场景</li>
 *   <li>跨平台一致：Java和HarmonyOS使用相同的接口语义</li>
 *   <li>资源管理：实现类必须正确管理底层资源</li>
 * </ul>
 * 
 * <p>使用示例：</p>
 * <pre>{@code
 * // 创建压缩器
 * ICompressor compressor = CompressorFactory.createZstdCompressor(config);
 * 
 * // 异步压缩
 * CompletableFuture<Void> future = compressor.compress(inputStream, outputStream);
 * future.thenRun(() -> System.out.println("压缩完成"));
 * 
 * // 使用后关闭
 * compressor.close();
 * }</pre>
 * 
 * @author 方寸控技术团队
 * @version 1.0
 * @since 2026-05-10
 */
public interface ICompressor {
    
    /**
     * 异步流式压缩
     * 
     * <p>从输入流读取数据，压缩后写入输出流。操作完全异步执行，
     * 立即返回CompletableFuture，不阻塞调用线程。</p>
     * 
     * @param inputStream 原始数据输入流
     * @param outputStream 压缩数据输出流
     * @return CompletableFuture，压缩完成后complete
     * @throws IOException 如果流操作失败
     * @throws CompressionException 如果压缩算法执行失败
     */
    CompletableFuture<Void> compress(java.io.InputStream inputStream, 
                                     java.io.OutputStream outputStream) throws IOException;
    
    /**
     * 异步流式解压
     * 
     * <p>从输入流读取压缩数据，解压后写入输出流。操作完全异步执行，
     * 立即返回CompletableFuture，不阻塞调用线程。</p>
     * 
     * @param inputStream 压缩数据输入流
     * @param outputStream 原始数据输出流
     * @return CompletableFuture，解压完成后complete
     * @throws IOException 如果流操作失败
     * @throws CompressionException 如果解压算法执行失败
     */
    CompletableFuture<Void> decompress(java.io.InputStream inputStream, 
                                       java.io.OutputStream outputStream) throws IOException;
    
    /**
     * 获取压缩方法标识
     * 
     * @return 压缩方法枚举值
     */
    CompressionMethod getMethod();
    
    /**
     * 获取当前配置
     * 
     * @return 压缩器配置对象
     */
    CompressorConfig getConfig();
    
    /**
     * 更新配置
     * 
     * <p>注意：配置更新可能影响正在进行的压缩/解压操作，
     * 建议在空闲时更新配置。</p>
     * 
     * @param config 新的配置对象
     * @throws CompressionException 如果配置无效
     */
    void updateConfig(CompressorConfig config) throws CompressionException;
    
    /**
     * 关闭压缩器，释放所有资源
     * 
     * <p>关闭后不能再进行压缩或解压操作。
     * 应该在使用完毕后显式调用此方法。</p>
     */
    void close();
}
