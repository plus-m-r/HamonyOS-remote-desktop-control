package io.github.springstudent.dekstop.common.compress.impl;

import io.github.springstudent.dekstop.common.compress.CompressionException;
import io.github.springstudent.dekstop.common.compress.CompressionMethod;
import io.github.springstudent.dekstop.common.compress.CompressorConfig;
import io.github.springstudent.dekstop.common.compress.ICompressor;
import org.xerial.snappy.SnappyInputStream;
import org.xerial.snappy.SnappyOutputStream;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Snappy压缩器实现
 * 
 * <p>基于snappy-java库实现的异步流式压缩器。</p>
 * 
 * <p>特性：</p>
 * <ul>
 *   <li>异步操作：所有压缩/解压操作在独立线程池中执行</li>
 *   <li>流式处理：支持InputStream/OutputStream</li>
 *   <li>快速压缩：Snappy由Google开发，平衡速度和压缩率</li>
 *   <li>资源管理：自动管理底层Snappy流资源</li>
 * </ul>
 * 
 * @author 方寸控技术团队
 * @version 1.0
 * @since 2026-05-10
 */
public class SnappyCompressor implements ICompressor {
    
    /** 压缩器配置 */
    private volatile CompressorConfig config;
    
    /** 异步执行线程池 */
    private final ExecutorService executor;
    
    /**
     * 创建Snappy压缩器
     * 
     * @param config 压缩器配置
     * @throws CompressionException 如果配置无效
     */
    public SnappyCompressor(CompressorConfig config) throws CompressionException {
        if (config == null) {
            throw new CompressionException(
                CompressionException.ErrorCode.CONFIG_ERROR,
                "Configuration cannot be null"
            );
        }
        
        if (config.getMethod() != CompressionMethod.SNAPPY) {
            throw new CompressionException(
                CompressionException.ErrorCode.CONFIG_ERROR,
                "Invalid compression method: " + config.getMethod() + ", expected SNAPPY"
            );
        }
        
        this.config = config;
        this.executor = Executors.newSingleThreadExecutor(r -> {
            Thread t = new Thread(r, "SnappyCompressor-Worker");
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
                    "Snappy compression failed",
                    e,
                    CompressionMethod.SNAPPY,
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
        // 使用SnappyOutputStream进行压缩
        try (SnappyOutputStream snappyOut = new SnappyOutputStream(outputStream)) {
            // 读取输入并写入压缩流
            byte[] buffer = new byte[config.getBufferSize()];
            int bytesRead;
            while ((bytesRead = inputStream.read(buffer)) != -1) {
                snappyOut.write(buffer, 0, bytesRead);
            }
            
            // 确保所有数据都被压缩和刷新
            snappyOut.flush();
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
                    "Snappy decompression failed",
                    e,
                    CompressionMethod.SNAPPY,
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
        // 使用SnappyInputStream进行解压
        try (SnappyInputStream snappyIn = new SnappyInputStream(inputStream)) {
            // 读取解压后的数据并写入输出流
            byte[] buffer = new byte[config.getBufferSize()];
            int bytesRead;
            while ((bytesRead = snappyIn.read(buffer)) != -1) {
                outputStream.write(buffer, 0, bytesRead);
            }
            
            // 确保所有数据都被写入
            outputStream.flush();
        }
    }
    
    @Override
    public CompressionMethod getMethod() {
        return CompressionMethod.SNAPPY;
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
        
        if (config.getMethod() != CompressionMethod.SNAPPY) {
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
