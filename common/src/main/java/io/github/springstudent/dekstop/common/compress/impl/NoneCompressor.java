package io.github.springstudent.dekstop.common.compress;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * 无压缩器实现（用于测试和基准对比）
 * 
 * <p>不执行任何压缩操作，直接复制数据。</p>
 * 
 * @author 方寸控技术团队
 * @version 1.0
 * @since 2026-05-10
 */
public class NoneCompressor implements ICompressor {
    
    /** 压缩器配置 */
    private volatile CompressorConfig config;
    
    /** 异步执行线程池 */
    private final ExecutorService executor;
    
    /**
     * 创建无压缩器
     * 
     * @param config 压缩器配置
     * @throws CompressionException 如果配置无效
     */
    public NoneCompressor(CompressorConfig config) throws CompressionException {
        if (config == null) {
            throw new CompressionException(
                CompressionException.ErrorCode.CONFIG_ERROR,
                "Configuration cannot be null"
            );
        }
        
        if (config.getMethod() != CompressionMethod.NONE) {
            throw new CompressionException(
                CompressionException.ErrorCode.CONFIG_ERROR,
                "Invalid compression method: " + config.getMethod() + ", expected NONE"
            );
        }
        
        this.config = config;
        this.executor = Executors.newSingleThreadExecutor(r -> {
            Thread t = new Thread(r, "NoneCompressor-Worker");
            t.setDaemon(true);
            return t;
        });
    }
    
    @Override
    public CompletableFuture<Void> compress(InputStream inputStream, OutputStream outputStream) throws IOException {
        if (inputStream == null || outputStream == null) {
            throw new IOException("Input and output streams cannot be null");
        }
        
        return CompletableFuture.runAsync(() -> {
            try {
                doCopy(inputStream, outputStream);
            } catch (IOException e) {
                throw new RuntimeException(new CompressionException(
                    CompressionException.ErrorCode.ALGORITHM_ERROR,
                    "Data copy failed",
                    e,
                    CompressionMethod.NONE,
                    -1,
                    -1,
                    -1
                ));
            }
        }, executor);
    }
    
    /**
     * 执行数据复制
     * 
     * @param inputStream 输入流
     * @param outputStream 输出流
     * @throws IOException 如果复制失败
     */
    private void doCopy(InputStream inputStream, OutputStream outputStream) throws IOException {
        byte[] buffer = new byte[config.getBufferSize()];
        int bytesRead;
        while ((bytesRead = inputStream.read(buffer)) != -1) {
            outputStream.write(buffer, 0, bytesRead);
        }
        outputStream.flush();
    }
    
    @Override
    public CompletableFuture<Void> decompress(InputStream inputStream, OutputStream outputStream) throws IOException {
        // 解压与压缩相同，都是直接复制
        return compress(inputStream, outputStream);
    }
    
    @Override
    public CompressionMethod getMethod() {
        return CompressionMethod.NONE;
    }
    
    @Override
    public CompressorConfig getConfig() {
        return config;
    }
    
    @Override
    public void updateConfig(CompressorConfig config) throws CompressionException {
        if (config == null) {
            throw new CompressionException(
                CompressionException.ErrorCode.CONFIG_ERROR,
                "Configuration cannot be null"
            );
        }
        
        if (config.getMethod() != CompressionMethod.NONE) {
            throw new CompressionException(
                CompressionException.ErrorCode.CONFIG_ERROR,
                "Invalid compression method: " + config.getMethod()
            );
        }
        
        this.config = config;
    }
    
    @Override
    public void close() {
        if (executor != null && !executor.isShutdown()) {
            executor.shutdown();
        }
    }
}
