package io.github.springstudent.dekstop.common.compress;

/**
 * 压缩/解压异常
 * 
 * <p>封装压缩操作中的各种错误情况，提供详细的错误信息。</p>
 * 
 * @author 方寸控技术团队
 * @version 1.0
 * @since 2026-05-10
 */
public class CompressionException extends Exception {
    
    /**
     * 错误代码枚举
     */
    public enum ErrorCode {
        /** 输入数据无效 */
        INVALID_INPUT,
        
        /** 缓冲区溢出 */
        BUFFER_OVERFLOW,
        
        /** 算法内部错误 */
        ALGORITHM_ERROR,
        
        /** 配置错误 */
        CONFIG_ERROR,
        
        /** 资源耗尽 */
        RESOURCE_EXHAUSTED,
        
        /** 不支持的压缩方法 */
        UNSUPPORTED_METHOD,
        
        /** 流已关闭 */
        STREAM_CLOSED,
        
        /** 操作超时 */
        OPERATION_TIMEOUT
    }
    
    private final ErrorCode errorCode;
    private final CompressionMethod method;
    private final int compressionLevel;
    private final long inputSize;
    private final long outputSize;
    
    /**
     * 创建压缩异常（简单形式）
     * 
     * @param errorCode 错误代码
     * @param message 错误消息
     */
    public CompressionException(ErrorCode errorCode, String message) {
        super(message);
        this.errorCode = errorCode;
        this.method = null;
        this.compressionLevel = -1;
        this.inputSize = -1;
        this.outputSize = -1;
    }
    
    /**
     * 创建压缩异常（带原因）
     * 
     * @param errorCode 错误代码
     * @param message 错误消息
     * @param cause 原始异常
     */
    public CompressionException(ErrorCode errorCode, String message, Throwable cause) {
        super(message, cause);
        this.errorCode = errorCode;
        this.method = null;
        this.compressionLevel = -1;
        this.inputSize = -1;
        this.outputSize = -1;
    }
    
    /**
     * 创建压缩异常（完整信息）
     * 
     * @param errorCode 错误代码
     * @param message 错误消息
     * @param method 压缩方法
     * @param compressionLevel 压缩级别
     * @param inputSize 输入大小
     * @param outputSize 输出大小
     */
    public CompressionException(ErrorCode errorCode, String message, 
                                CompressionMethod method, int compressionLevel,
                                long inputSize, long outputSize) {
        super(message);
        this.errorCode = errorCode;
        this.method = method;
        this.compressionLevel = compressionLevel;
        this.inputSize = inputSize;
        this.outputSize = outputSize;
    }
    
    /**
     * 创建压缩异常（完整信息+原因）
     * 
     * @param errorCode 错误代码
     * @param message 错误消息
     * @param cause 原始异常
     * @param method 压缩方法
     * @param compressionLevel 压缩级别
     * @param inputSize 输入大小
     * @param outputSize 输出大小
     */
    public CompressionException(ErrorCode errorCode, String message, Throwable cause,
                                CompressionMethod method, int compressionLevel,
                                long inputSize, long outputSize) {
        super(message, cause);
        this.errorCode = errorCode;
        this.method = method;
        this.compressionLevel = compressionLevel;
        this.inputSize = inputSize;
        this.outputSize = outputSize;
    }
    
    /**
     * 获取错误代码
     * 
     * @return 错误代码
     */
    public ErrorCode getErrorCode() {
        return errorCode;
    }
    
    /**
     * 获取压缩方法
     * 
     * @return 压缩方法，可能为null
     */
    public CompressionMethod getMethod() {
        return method;
    }
    
    /**
     * 获取压缩级别
     * 
     * @return 压缩级别，-1表示未知
     */
    public int getCompressionLevel() {
        return compressionLevel;
    }
    
    /**
     * 获取输入大小
     * 
     * @return 输入大小（字节），-1表示未知
     */
    public long getInputSize() {
        return inputSize;
    }
    
    /**
     * 获取输出大小
     * 
     * @return 输出大小（字节），-1表示未知
     */
    public long getOutputSize() {
        return outputSize;
    }
    
    /**
     * 计算压缩率
     * 
     * @return 压缩率（outputSize/inputSize），0表示无法计算
     */
    public double getCompressionRatio() {
        if (inputSize <= 0 || outputSize <= 0) {
            return 0;
        }
        return (double) outputSize / inputSize;
    }
    
    @Override
    public String toString() {
        StringBuilder sb = new StringBuilder();
        sb.append("CompressionException{");
        sb.append("errorCode=").append(errorCode);
        
        if (method != null) {
            sb.append(", method=").append(method);
        }
        if (compressionLevel >= 0) {
            sb.append(", compressionLevel=").append(compressionLevel);
        }
        if (inputSize >= 0) {
            sb.append(", inputSize=").append(inputSize);
        }
        if (outputSize >= 0) {
            sb.append(", outputSize=").append(outputSize);
        }
        if (inputSize > 0 && outputSize > 0) {
            sb.append(String.format(", ratio=%.2f", getCompressionRatio()));
        }
        
        sb.append(", message='").append(getMessage()).append('\'');
        sb.append('}');
        
        return sb.toString();
    }
}
