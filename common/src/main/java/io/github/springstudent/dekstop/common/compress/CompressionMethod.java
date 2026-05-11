package io.github.springstudent.dekstop.common.compress;

/**
 * 压缩方法枚举
 * 
 * <p>定义系统支持的所有压缩算法。</p>
 * 
 * @author 方寸控技术团队
 * @version 1.0
 * @since 2026-05-10
 */
public enum CompressionMethod {
    
    /**
     * 无压缩（仅用于测试或极低延迟场景）
     */
    NONE("none", 0),
    
    /**
     * ZSTD压缩（推荐，高性能高压缩率）
     */
    ZSTD("zstd", 1),
    
    /**
     * LZ4压缩（极速，适合低延迟场景）
     */
    LZ4("lz4", 2),
    
    /**
     * Snappy压缩（快速，Google开发）
     */
    SNAPPY("snappy", 3);
    
    private final String name;
    private final int code;
    
    CompressionMethod(String name, int code) {
        this.name = name;
        this.code = code;
    }
    
    /**
     * 获取压缩方法名称
     * 
     * @return 名称字符串
     */
    public String getName() {
        return name;
    }
    
    /**
     * 获取压缩方法代码
     * 
     * @return 代码值
     */
    public int getCode() {
        return code;
    }
    
    /**
     * 根据名称查找压缩方法
     * 
     * @param name 名称字符串
     * @return 对应的CompressionMethod
     * @throws IllegalArgumentException 如果名称不存在
     */
    public static CompressionMethod fromName(String name) {
        for (CompressionMethod method : values()) {
            if (method.name.equalsIgnoreCase(name)) {
                return method;
            }
        }
        throw new IllegalArgumentException("Unknown compression method: " + name);
    }
    
    /**
     * 根据代码查找压缩方法
     * 
     * @param code 代码值
     * @return 对应的CompressionMethod
     * @throws IllegalArgumentException 如果代码不存在
     */
    public static CompressionMethod fromCode(int code) {
        for (CompressionMethod method : values()) {
            if (method.code == code) {
                return method;
            }
        }
        throw new IllegalArgumentException("Unknown compression method code: " + code);
    }
}
