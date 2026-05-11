package io.github.springstudent.dekstop.common.compress;

/**
 * 压缩器配置
 * 
 * <p>使用Builder模式构建不可变配置对象。</p>
 * 
 * <p>配置项说明：</p>
 * <ul>
 *   <li>compressionLevel: 压缩级别（1-9），越高压缩率越好但速度越慢</li>
 *   <li>bufferSize: 缓冲区大小，影响内存使用和性能</li>
 *   <li>useDictionary: 是否使用字典压缩，适合重复数据场景</li>
 *   <li>dictionary: 自定义字典数据</li>
 * </ul>
 * 
 * @author 方寸控技术团队
 * @version 1.0
 * @since 2026-05-10
 */
public class CompressorConfig {
    
    private final CompressionMethod method;
    private final int compressionLevel;
    private final int bufferSize;
    private final boolean useDictionary;
    private final byte[] dictionary;
    
    private CompressorConfig(Builder builder) {
        this.method = builder.method;
        this.compressionLevel = builder.compressionLevel;
        this.bufferSize = builder.bufferSize;
        this.useDictionary = builder.useDictionary;
        this.dictionary = builder.dictionary != null ? builder.dictionary.clone() : null;
    }
    
    /**
     * 创建配置Builder
     * 
     * @param method 压缩方法
     * @return Builder实例
     */
    public static Builder builder(CompressionMethod method) {
        return new Builder(method);
    }
    
    /**
     * 获取压缩方法
     * 
     * @return 压缩方法枚举
     */
    public CompressionMethod getMethod() {
        return method;
    }
    
    /**
     * 获取压缩级别
     * 
     * @return 压缩级别（1-9）
     */
    public int getCompressionLevel() {
        return compressionLevel;
    }
    
    /**
     * 获取缓冲区大小
     * 
     * @return 缓冲区大小（字节）
     */
    public int getBufferSize() {
        return bufferSize;
    }
    
    /**
     * 是否使用字典
     * 
     * @return true表示使用字典
     */
    public boolean isUseDictionary() {
        return useDictionary;
    }
    
    /**
     * 获取字典数据
     * 
     * @return 字典数据副本
     */
    public byte[] getDictionary() {
        return dictionary != null ? dictionary.clone() : null;
    }
    
    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        
        CompressorConfig that = (CompressorConfig) o;
        
        if (compressionLevel != that.compressionLevel) return false;
        if (bufferSize != that.bufferSize) return false;
        if (useDictionary != that.useDictionary) return false;
        if (method != that.method) return false;
        
        if (dictionary != null) {
            if (that.dictionary == null) return false;
            if (dictionary.length != that.dictionary.length) return false;
            for (int i = 0; i < dictionary.length; i++) {
                if (dictionary[i] != that.dictionary[i]) return false;
            }
        } else if (that.dictionary != null) {
            return false;
        }
        
        return true;
    }
    
    @Override
    public int hashCode() {
        int result = method.hashCode();
        result = 31 * result + compressionLevel;
        result = 31 * result + bufferSize;
        result = 31 * result + (useDictionary ? 1 : 0);
        result = 31 * result + (dictionary != null ? java.util.Arrays.hashCode(dictionary) : 0);
        return result;
    }
    
    @Override
    public String toString() {
        return "CompressorConfig{" +
                "method=" + method +
                ", compressionLevel=" + compressionLevel +
                ", bufferSize=" + bufferSize +
                ", useDictionary=" + useDictionary +
                '}';
    }
    
    /**
     * 配置Builder
     */
    public static class Builder {
        private final CompressionMethod method;
        private int compressionLevel = 3;  // 默认中等压缩级别
        private int bufferSize = 64 * 1024; // 默认64KB
        private boolean useDictionary = false;
        private byte[] dictionary = null;
        
        private Builder(CompressionMethod method) {
            this.method = method;
        }
        
        /**
         * 设置压缩级别
         * 
         * @param level 压缩级别（1-9）
         * @return Builder实例
         * @throws IllegalArgumentException 如果级别不在1-9范围内
         */
        public Builder compressionLevel(int level) {
            if (level < 1 || level > 9) {
                throw new IllegalArgumentException("Compression level must be between 1 and 9");
            }
            this.compressionLevel = level;
            return this;
        }
        
        /**
         * 设置缓冲区大小
         * 
         * @param size 缓冲区大小（字节）
         * @return Builder实例
         * @throws IllegalArgumentException 如果大小小于1KB
         */
        public Builder bufferSize(int size) {
            if (size < 1024) {
                throw new IllegalArgumentException("Buffer size must be at least 1KB");
            }
            this.bufferSize = size;
            return this;
        }
        
        /**
         * 设置是否使用字典
         * 
         * @param use true表示使用字典
         * @return Builder实例
         */
        public Builder useDictionary(boolean use) {
            this.useDictionary = use;
            return this;
        }
        
        /**
         * 设置字典数据
         * 
         * @param dict 字典数据
         * @return Builder实例
         */
        public Builder dictionary(byte[] dict) {
            this.dictionary = dict != null ? dict.clone() : null;
            this.useDictionary = dict != null && dict.length > 0;
            return this;
        }
        
        /**
         * 构建配置对象
         * 
         * @return 不可变的CompressorConfig实例
         */
        public CompressorConfig build() {
            return new CompressorConfig(this);
        }
    }
}
