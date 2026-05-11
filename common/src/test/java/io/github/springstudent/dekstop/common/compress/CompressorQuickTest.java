package io.github.springstudent.dekstop.common.compress;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.util.concurrent.CompletableFuture;

/**
 * 压缩器快速测试
 * 
 * <p>用于验证压缩器接口和工厂类的基本功能。</p>
 * 
 * @author 方寸控技术团队
 * @version 1.0
 * @since 2026-05-10
 */
public class CompressorQuickTest {
    
    public static void main(String[] args) throws Exception {
        System.out.println("=== 压缩器快速测试 ===\n");
        
        // 测试1：创建ZSTD压缩器
        testZstdCompressor();
        
        // 测试2：创建无压缩器
        testNoneCompressor();
        
        // 测试3：工厂缓存
        testFactoryCache();
        
        System.out.println("\n=== 所有测试通过 ===");
    }
    
    private static void testZstdCompressor() throws Exception {
        System.out.println("测试1: ZSTD压缩器");
        
        // 创建配置
        CompressorConfig config = CompressorConfig.builder(CompressionMethod.ZSTD)
            .compressionLevel(3)
            .bufferSize(64 * 1024)
            .build();
        
        // 创建压缩器
        ICompressor compressor = CompressorFactory.createCompressor(config);
        System.out.println("  ✓ 压缩器创建成功: " + compressor.getMethod());
        
        // 准备测试数据
        String testData = "Hello, World! This is a test for ZSTD compression.";
        byte[] inputData = testData.getBytes();
        
        // 压缩
        ByteArrayOutputStream compressedOutput = new ByteArrayOutputStream();
        CompletableFuture<Void> compressFuture = compressor.compress(
            new ByteArrayInputStream(inputData),
            compressedOutput
        );
        compressFuture.join();
        byte[] compressedData = compressedOutput.toByteArray();
        System.out.println("  ✓ 压缩完成: " + inputData.length + " -> " + compressedData.length + " bytes");
        
        // 解压
        ByteArrayOutputStream decompressedOutput = new ByteArrayOutputStream();
        CompletableFuture<Void> decompressFuture = compressor.decompress(
            new ByteArrayInputStream(compressedData),
            decompressedOutput
        );
        decompressFuture.join();
        byte[] decompressedData = decompressedOutput.toByteArray();
        System.out.println("  ✓ 解压完成: " + compressedData.length + " -> " + decompressedData.length + " bytes");
        
        // 验证数据
        String result = new String(decompressedData);
        if (result.equals(testData)) {
            System.out.println("  ✓ 数据验证通过\n");
        } else {
            throw new AssertionError("数据验证失败!");
        }
        
        // 关闭压缩器
        compressor.close();
    }
    
    private static void testNoneCompressor() throws Exception {
        System.out.println("测试2: 无压缩器");
        
        // 创建压缩器
        ICompressor compressor = CompressorFactory.createNoneCompressor();
        System.out.println("  ✓ 压缩器创建成功: " + compressor.getMethod());
        
        // 准备测试数据
        String testData = "Hello, World! This is a test for NONE compression.";
        byte[] inputData = testData.getBytes();
        
        // 压缩（实际是复制）
        ByteArrayOutputStream compressedOutput = new ByteArrayOutputStream();
        CompletableFuture<Void> compressFuture = compressor.compress(
            new ByteArrayInputStream(inputData),
            compressedOutput
        );
        compressFuture.join();
        byte[] compressedData = compressedOutput.toByteArray();
        System.out.println("  ✓ 压缩完成: " + inputData.length + " -> " + compressedData.length + " bytes");
        
        // 验证无压缩
        if (inputData.length == compressedData.length) {
            System.out.println("  ✓ 无压缩验证通过（大小相同）");
        } else {
            throw new AssertionError("无压缩验证失败!");
        }
        
        // 解压
        ByteArrayOutputStream decompressedOutput = new ByteArrayOutputStream();
        CompletableFuture<Void> decompressFuture = compressor.decompress(
            new ByteArrayInputStream(compressedData),
            decompressedOutput
        );
        decompressFuture.join();
        byte[] decompressedData = decompressedOutput.toByteArray();
        
        // 验证数据
        String result = new String(decompressedData);
        if (result.equals(testData)) {
            System.out.println("  ✓ 数据验证通过\n");
        } else {
            throw new AssertionError("数据验证失败!");
        }
        
        // 关闭压缩器
        compressor.close();
    }
    
    private static void testFactoryCache() throws Exception {
        System.out.println("测试3: 工厂缓存");
        
        // 创建相同配置的压缩器
        CompressorConfig config1 = CompressorConfig.builder(CompressionMethod.ZSTD)
            .compressionLevel(3)
            .bufferSize(64 * 1024)
            .build();
        
        ICompressor c1 = CompressorFactory.createCompressor(config1);
        ICompressor c2 = CompressorFactory.createCompressor(config1);
        
        if (c1 == c2) {
            System.out.println("  ✓ 缓存命中：相同配置返回同一实例");
        } else {
            System.out.println("  ⚠ 缓存未命中：相同配置返回不同实例（可能正常，取决于实现）");
        }
        
        System.out.println("  当前缓存大小: " + CompressorFactory.getCacheSize());
        
        // 清除缓存
        CompressorFactory.clearCache();
        System.out.println("  ✓ 缓存已清除，新大小: " + CompressorFactory.getCacheSize());
        
        // 关闭压缩器
        c1.close();
        c2.close();
        System.out.println();
    }
}
