package io.github.springstudent.dekstop.common.compress;

import java.util.concurrent.ConcurrentHashMap;
import java.util.Map;

/**
 * 压缩器工厂类
 * 
 * <p>负责创建和管理ICompressor实例，支持配置化创建和缓存复用。</p>
 * 
 * <p>使用示例：</p>
 * <pre>{@code
 * // 方式1：根据配置创建
 * CompressorConfig config = CompressorConfig.builder(CompressionMethod.ZSTD)
 *     .compressionLevel(3)
 *     .bufferSize(64 * 1024)
 *     .build();
 * ICompressor compressor = CompressorFactory.createCompressor(config);
 * 
 * // 方式2：快速创建ZSTD压缩器
 * ICompressor zstd = CompressorFactory.createZstdCompressor(3);
 * 
 * // 方式3：获取默认压缩器
 * ICompressor defaultCompressor = CompressorFactory.getDefaultCompressor();
 * }</pre>
 * 
 * @author 方寸控技术团队
 * @version 1.0
 * @since 2026-05-10
 */
public class CompressorFactory {
    
    /** 默认压缩方法 */
    private static final CompressionMethod DEFAULT_METHOD = CompressionMethod.ZSTD;
    
    /** 默认压缩级别 */
    private static final int DEFAULT_COMPRESSION_LEVEL = 3;
    
    /** 默认缓冲区大小（64KB） */
    private static final int DEFAULT_BUFFER_SIZE = 64 * 1024;
    
    /** 压缩器缓存：key为配置hashCode，value为压缩器实例 */
    private static final Map<Integer, ICompressor> COMPRESSOR_CACHE = new ConcurrentHashMap<>();
    
    /**
     * 私有构造函数，防止实例化
     */
    private CompressorFactory() {
        throw new UnsupportedOperationException("Factory class cannot be instantiated");
    }
    
    /**
     * 根据配置创建压缩器
     * 
     * <p>如果相同配置的压缩器已存在，则返回缓存实例。</p>
     * 
     * @param config 压缩器配置
     * @return ICompressor实例
     * @throws CompressionException 如果创建失败
     */
    public static ICompressor createCompressor(CompressorConfig config) throws CompressionException {
        if (config == null) {
            throw new CompressionException(
                CompressionException.ErrorCode.CONFIG_ERROR,
                "Configuration cannot be null"
            );
        }
        
        // 尝试从缓存获取
        final int cacheKey = config.hashCode();
        ICompressor cached = COMPRESSOR_CACHE.get(cacheKey);
        if (cached != null) {
            return cached;
        }
        
        // 创建新的压缩器
        ICompressor compressor = createCompressorInternal(config);
        
        // 放入缓存
        COMPRESSOR_CACHE.put(cacheKey, compressor);
        
        return compressor;
    }
    
    /**
     * 内部方法：根据配置创建具体的压缩器实例
     * 
     * @param config 压缩器配置
     * @return ICompressor实例
     * @throws CompressionException 如果创建失败
     */
    private static ICompressor createCompressorInternal(CompressorConfig config) throws CompressionException {
        switch (config.getMethod()) {
            case ZSTD:
                return new ZstdCompressor(config);
            
            case LZ4:
                return new Lz4Compressor(config);
            
            case SNAPPY:
                return new SnappyCompressor(config);
            
            case NONE:
                return new NoneCompressor(config);
            
            default:
                throw new CompressionException(
                    CompressionException.ErrorCode.UNSUPPORTED_METHOD,
                    "Unsupported compression method: " + config.getMethod(),
                    config.getMethod(),
                    config.getCompressionLevel(),
                    -1,
                    -1
                );
        }
    }
    
    /**
     * 创建ZSTD压缩器（快捷方法）
     * 
     * @param compressionLevel 压缩级别（1-9）
     * @return ZSTD压缩器实例
     * @throws CompressionException 如果创建失败
     */
    public static ICompressor createZstdCompressor(int compressionLevel) throws CompressionException {
        CompressorConfig config = CompressorConfig.builder(CompressionMethod.ZSTD)
            .compressionLevel(compressionLevel)
            .bufferSize(DEFAULT_BUFFER_SIZE)
            .build();
        return createCompressor(config);
    }
    
    /**
     * 创建ZSTD压缩器（使用默认级别）
     * 
     * @return ZSTD压缩器实例
     * @throws CompressionException 如果创建失败
     */
    public static ICompressor createZstdCompressor() throws CompressionException {
        return createZstdCompressor(DEFAULT_COMPRESSION_LEVEL);
    }
    
    /**
     * 创建LZ4压缩器（快捷方法）
     * 
     * @return LZ4压缩器实例
     * @throws CompressionException 如果创建失败
     */
    public static ICompressor createLz4Compressor() throws CompressionException {
        CompressorConfig config = CompressorConfig.builder(CompressionMethod.LZ4)
            .bufferSize(DEFAULT_BUFFER_SIZE)
            .build();
        return createCompressor(config);
    }
    
    /**
     * 创建Snappy压缩器（快捷方法）
     * 
     * @return Snappy压缩器实例
     * @throws CompressionException 如果创建失败
     */
    public static ICompressor createSnappyCompressor() throws CompressionException {
        CompressorConfig config = CompressorConfig.builder(CompressionMethod.SNAPPY)
            .bufferSize(DEFAULT_BUFFER_SIZE)
            .build();
        return createCompressor(config);
    }
    
    /**
     * 创建无压缩器（用于测试）
     * 
     * @return 无压缩器实例
     * @throws CompressionException 如果创建失败
     */
    public static ICompressor createNoneCompressor() throws CompressionException {
        CompressorConfig config = CompressorConfig.builder(CompressionMethod.NONE)
            .build();
        return createCompressor(config);
    }
    
    /**
     * 获取默认压缩器（ZSTD，级别3）
     * 
     * @return 默认压缩器实例
     * @throws CompressionException 如果创建失败
     */
    public static ICompressor getDefaultCompressor() throws CompressionException {
        return createZstdCompressor(DEFAULT_COMPRESSION_LEVEL);
    }
    
    /**
     * 清除压缩器缓存
     * 
     * <p>注意：清除缓存后，已创建的压缩器实例仍然有效，
     * 但新创建的相同配置压缩器将是新实例。</p>
     */
    public static void clearCache() {
        COMPRESSOR_CACHE.clear();
    }
    
    /**
     * 获取缓存大小
     * 
     * @return 缓存中的压缩器数量
     */
    public static int getCacheSize() {
        return COMPRESSOR_CACHE.size();
    }
}
