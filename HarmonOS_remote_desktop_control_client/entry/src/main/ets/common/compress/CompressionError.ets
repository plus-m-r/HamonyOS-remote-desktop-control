import { CompressionMethod } from './CompressionMethod';

/**
 * 错误代码枚举
 */
export enum CompressionErrorCode {
  /** 输入数据无效 */
  INVALID_INPUT = 'INVALID_INPUT',
  
  /** 缓冲区溢出 */
  BUFFER_OVERFLOW = 'BUFFER_OVERFLOW',
  
  /** 算法内部错误 */
  ALGORITHM_ERROR = 'ALGORITHM_ERROR',
  
  /** 配置错误 */
  CONFIG_ERROR = 'CONFIG_ERROR',
  
  /** 资源耗尽 */
  RESOURCE_EXHAUSTED = 'RESOURCE_EXHAUSTED',
  
  /** 不支持的压缩方法 */
  UNSUPPORTED_METHOD = 'UNSUPPORTED_METHOD',
  
  /** 流已关闭 */
  STREAM_CLOSED = 'STREAM_CLOSED',
  
  /** 操作超时 */
  OPERATION_TIMEOUT = 'OPERATION_TIMEOUT'
}

/**
 * 压缩/解压异常（HarmonyOS版本）
 * 
 * <p>封装压缩操作中的各种错误情况，提供详细的错误信息。</p>
 * 
 * @author 方寸控技术团队
 * @version 1.0
 * @since 2026-05-10
 */
export class CompressionError extends Error {
  readonly errorCode: CompressionErrorCode;
  readonly method: CompressionMethod | null;
  readonly compressionLevel: number;
  readonly inputSize: number;
  readonly outputSize: number;
  
  /**
   * 创建压缩异常（简单形式）
   * 
   * @param errorCode 错误代码
   * @param message 错误消息
   */
  constructor(errorCode: CompressionErrorCode, message: string) {
    super(message);
    this.name = 'CompressionError';
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
  static withDetails(
    errorCode: CompressionErrorCode,
    message: string,
    method: CompressionMethod,
    compressionLevel: number,
    inputSize: number,
    outputSize: number
  ): CompressionError {
    const error = new CompressionError(errorCode, message);
    error.method = method;
    error.compressionLevel = compressionLevel;
    error.inputSize = inputSize;
    error.outputSize = outputSize;
    return error;
  }
  
  /**
   * 计算压缩率
   * 
   * @returns 压缩率（outputSize/inputSize），0表示无法计算
   */
  getCompressionRatio(): number {
    if (this.inputSize <= 0 || this.outputSize <= 0) {
      return 0;
    }
    return this.outputSize / this.inputSize;
  }
  
  /**
   * 获取错误信息字符串
   * 
   * @returns 格式化的错误信息
   */
  getDetailedMessage(): string {
    let msg = `CompressionError{errorCode=${this.errorCode}`;
    
    if (this.method !== null) {
      msg += `, method=${this.method}`;
    }
    if (this.compressionLevel >= 0) {
      msg += `, level=${this.compressionLevel}`;
    }
    if (this.inputSize >= 0) {
      msg += `, inputSize=${this.inputSize}`;
    }
    if (this.outputSize >= 0) {
      msg += `, outputSize=${this.outputSize}`;
    }
    if (this.inputSize > 0 && this.outputSize > 0) {
      msg += `, ratio=${this.getCompressionRatio().toFixed(2)}`;
    }
    
    msg += `, message='${this.message}'}`;
    return msg;
  }
  
  /**
   * 转换为字符串
   * 
   * @returns 字符串表示
   */
  toString(): string {
    return this.getDetailedMessage();
  }
}
