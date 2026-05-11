package io.github.springstudent.dekstop.common.compress.impl;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import com.github.luben.zstd.ZstdInputStream;
import com.github.luben.zstd.ZstdOutputStream;

import io.github.springstudent.dekstop.common.compress.CompressionException;
import io.github.springstudent.dekstop.common.compress.CompressionMethod;
import io.github.springstudent.dekstop.common.compress.CompressorConfig;
import io.github.springstudent.dekstop.common.compress.ICompressor;

/**
 * ZSTD压缩器实现
 * 
 * <p>基于zstd-jni库实现的异步流式压缩器。</p>
 * 
 * <p>特性：</p>
 * <ul>
 *   <li>异步操作：所有压缩/解压操作在独立线程池中执行</li>
 *   <li>流式处理：支持InputStream/OutputStream</li>
 *   <li>可配置：支持压缩级别和缓冲区大小配置</li>
 *   <li>资源管理：自动管理底层Zstd流资源</li>
 * </ul>
 * 
 * @author 方寸控技术团队
 * @version 1.0
 * @since 2026-05-10
 */
public class ZstdCompressor implements ICompressor {
    
    /** 压缩器配置 */
    private volatile CompressorConfig config;
    
    /** 异步执行线程池 */
    private final ExecutorService executor;
    
    /**
     * 创建ZSTD压缩器
     * 
     * @param config 压缩器配置
     * @throws CompressionException 如果配置无效
     */
    public ZstdCompressor(CompressorConfig config) throws CompressionException {
        if (config == null) {
            throw new CompressionException(
                CompressionException.ErrorCode.CONFIG_ERROR,
                "Configuration cannot be null"
            );
        }
        
        if (config.getMethod() != CompressionMethod.ZSTD) {
            throw new CompressionException(
                CompressionException.ErrorCode.CONFIG_ERROR,
                "Invalid compression method: " + config.getMethod() + ", expected ZSTD"
            );
        }
        
        this.config = config;
        // 创建单线程池用于异步操作
        this.executor = Executors.newSingleThreadExecutor(r -> {
            Thread t = new Thread(r, "ZstdCompressor-Worker");
            t.setDaemon(true);
            return t;
        });
    }
    
    @Override
    public CompletableFuture<Void> compress(InputStream inputStream, OutputStream outputStream) throws IOException {
        if (inputStream == null || outputStream == null) {
            throw new IOException("Input and output streams cannot be null");
        }
        
        // 异步执行压缩操作
        return CompletableFuture.runAsync(() -> {
            try {
                doCompress(inputStream, outputStream);
            } catch (IOException e) {
                throw new RuntimeException(new CompressionException(
                    CompressionException.ErrorCode.ALGORITHM_ERROR,
                    "ZSTD compression failed",
                    e,
                    CompressionMethod.ZSTD,
                    config.getCompressionLevel(),
                    -1,
                    -1
                ));
            }
        }, executor);
    }
    
    /**
     * 执行实际的压缩操作
     * 
     * @param inputStream 输入流
     * @param outputStream 输出流
     * @throws IOException 如果压缩失败
     */
    private void doCompress(InputStream inputStream, OutputStream outputStream) throws IOException {
        // 使用ZstdOutputStream进行压缩
        try (ZstdOutputStream zstdOut = new ZstdOutputStream(outputStream)) {
            // 设置压缩级别
            zstdOut.setLevel(config.getCompressionLevel());
            
            // 读取输入并写入压缩流
            byte[] buffer = new byte[config.getBufferSize()];
            int bytesRead;
            while ((bytesRead = inputStream.read(buffer)) != -1) {
                zstdOut.write(buffer, 0, bytesRead);
            }
            
            // 确保所有数据都被压缩和刷新
            zstdOut.flush();
        }
    }
    
    @Override
    public CompletableFuture<Void> decompress(InputStream inputStream, OutputStream outputStream) throws IOException {
        if (inputStream == null || outputStream == null) {
            throw new IOException("Input and output streams cannot be null");
        }
        
        // 异步执行解压操作
        return CompletableFuture.runAsync(() -> {
            try {
                doDecompress(inputStream, outputStream);
            } catch (IOException e) {
                throw new RuntimeException(new CompressionException(
                    CompressionException.ErrorCode.ALGORITHM_ERROR,
                    "ZSTD decompression failed",
                    e,
                    CompressionMethod.ZSTD,
                    config.getCompressionLevel(),
                    -1,
                    -1
                ));
            }
        }, executor);
    }
    
    /**
     * 执行实际的解压操作
     * 
     * @param inputStream 输入流
     * @param outputStream 输出流
     * @throws IOException 如果解压失败
     */
    private void doDecompress(InputStream inputStream, OutputStream outputStream) throws IOException {
        // 使用ZstdInputStream进行解压
        try (ZstdInputStream zstdIn = new ZstdInputStream(inputStream)) {
            // 读取解压后的数据并写入输出流
            byte[] buffer = new byte[config.getBufferSize()];
            int bytesRead;
            while ((bytesRead = zstdIn.read(buffer)) != -1) {
                outputStream.write(buffer, 0, bytesRead);
            }
            
            // 确保所有数据都被写入
            outputStream.flush();
        }
    }
    
    @Override
    public CompressionMethod getMethod() {
        return CompressionMethod.ZSTD;
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
        
        if (config.getMethod() != CompressionMethod.ZSTD) {
            throw new CompressionException(
                CompressionException.ErrorCode.CONFIG_ERROR,
                "Invalid compression method: " + config.getMethod()
            );
        }
        
        // 原子性更新配置
        this.config = config;
    }
    
    @Override
    public void close() {
        // 关闭线程池
        if (executor != null && !executor.isShutdown()) {
            executor.shutdown();
        }
    }
}
