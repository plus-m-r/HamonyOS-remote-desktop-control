package io.github.springstudent.dekstop.common.compress.impl;

import io.github.springstudent.dekstop.common.compress.CompressionException;
import io.github.springstudent.dekstop.common.compress.CompressionMethod;
import io.github.springstudent.dekstop.common.compress.CompressorConfig;
import io.github.springstudent.dekstop.common.compress.ICompressor;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import net.jpountz.lz4.LZ4FrameInputStream;
import net.jpountz.lz4.LZ4FrameOutputStream;

/**
 * LZ4压缩器实现
 * 
 * <p>基于lz4-java库实现的异步流式压缩器。</p>
 * 
 * <p>特性：</p>
 * <ul>
 *   <li>异步操作：所有压缩/解压操作在独立线程池中执行</li>
 *   <li>流式处理：支持InputStream/OutputStream</li>
 *   <li>极速压缩：LZ4以速度著称，适合低延迟场景</li>
 *   <li>资源管理：自动管理底层LZ4流资源</li>
 * </ul>
 * 
 * @author 方寸控技术团队
 * @version 1.0
 * @since 2026-05-10
 */
public class Lz4Compressor implements ICompressor {
    
    /** 压缩器配置 */
    private volatile CompressorConfig config;
    
    /** 异步执行线程池 */
    private final ExecutorService executor;
    
    /**
     * 创建LZ4压缩器
     * 
     * @param config 压缩器配置
     * @throws CompressionException 如果配置无效
     */
    public Lz4Compressor(CompressorConfig config) throws CompressionException {
        if (config == null) {
            throw new CompressionException(
                CompressionException.ErrorCode.CONFIG_ERROR,
                "Configuration cannot be null"
            );
        }
        
        if (config.getMethod() != CompressionMethod.LZ4) {
            throw new CompressionException(
                CompressionException.ErrorCode.CONFIG_ERROR,
                "Invalid compression method: " + config.getMethod() + ", expected LZ4"
            );
        }
        
        this.config = config;
        this.executor = Executors.newSingleThreadExecutor(r -> {
            Thread t = new Thread(r, "Lz4Compressor-Worker");
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
                    "LZ4 compression failed",
                    e,
                    CompressionMethod.LZ4,
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
        // 使用LZ4FrameOutputStream进行压缩
        // LZ4FrameOutputStream会自动添加帧头，支持流式处理
        try (LZ4FrameOutputStream lz4Out = new LZ4FrameOutputStream(outputStream)) {
            // 读取输入并写入压缩流
            byte[] buffer = new byte[config.getBufferSize()];
            int bytesRead;
            while ((bytesRead = inputStream.read(buffer)) != -1) {
                lz4Out.write(buffer, 0, bytesRead);
            }
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
                    "LZ4 decompression failed",
                    e,
                    CompressionMethod.LZ4,
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
        // 使用LZ4FrameInputStream进行解压
        try (LZ4FrameInputStream lz4In = new LZ4FrameInputStream(inputStream)) {
            // 读取解压后的数据并写入输出流
            byte[] buffer = new byte[config.getBufferSize()];
            int bytesRead;
            while ((bytesRead = lz4In.read(buffer)) != -1) {
                outputStream.write(buffer, 0, bytesRead);
            }
            
            // 确保所有数据都被写入
            outputStream.flush();
        }
    }
    
    @Override
    public CompressionMethod getMethod() {
        return CompressionMethod.LZ4;
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
        
        if (config.getMethod() != CompressionMethod.LZ4) {
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
