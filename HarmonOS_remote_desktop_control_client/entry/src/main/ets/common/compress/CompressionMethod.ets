/**
 * 压缩方法枚举（HarmonyOS版本）
 * 
 * <p>定义系统支持的所有压缩算法，与Java端保持一致。</p>
 * 
 * @author 方寸控技术团队
 * @version 1.0
 * @since 2026-05-10
 */
export enum CompressionMethod {
  /**
   * 无压缩（仅用于测试或极低延迟场景）
   */
  NONE = 'none',
  
  /**
   * ZSTD压缩（推荐，高性能高压缩率）
   */
  ZSTD = 'zstd',
  
  /**
   * LZ4压缩（极速，适合低延迟场景）
   */
  LZ4 = 'lz4',
  
  /**
   * Snappy压缩（快速，Google开发）
   */
  SNAPPY = 'snappy'
}

/**
 * 根据名称查找压缩方法
 * 
 * @param name 名称字符串
 * @returns 对应的CompressionMethod
 * @throws Error 如果名称不存在
 */
export function fromName(name: string): CompressionMethod {
  const upperName = name.toUpperCase();
  switch (upperName) {
    case 'NONE':
      return CompressionMethod.NONE;
    case 'ZSTD':
      return CompressionMethod.ZSTD;
    case 'LZ4':
      return CompressionMethod.LZ4;
    case 'SNAPPY':
      return CompressionMethod.SNAPPY;
    default:
      throw new Error(`Unknown compression method: ${name}`);
  }
}

/**
 * 根据代码查找压缩方法（用于协议解析）
 * 
 * @param code 代码值（0=NONE, 1=ZSTD, 2=LZ4, 3=SNAPPY）
 * @returns 对应的CompressionMethod
 * @throws Error 如果代码不存在
 */
export function fromCode(code: number): CompressionMethod {
  switch (code) {
    case 0:
      return CompressionMethod.NONE;
    case 1:
      return CompressionMethod.ZSTD;
    case 2:
      return CompressionMethod.LZ4;
    case 3:
      return CompressionMethod.SNAPPY;
    default:
      throw new Error(`Unknown compression method code: ${code}`);
  }
}

/**
 * 获取压缩方法的代码值（用于协议传输）
 * 
 * @param method 压缩方法
 * @returns 代码值
 */
export function toCode(method: CompressionMethod): number {
  switch (method) {
    case CompressionMethod.NONE:
      return 0;
    case CompressionMethod.ZSTD:
      return 1;
    case CompressionMethod.LZ4:
      return 2;
    case CompressionMethod.SNAPPY:
      return 3;
    default:
      throw new Error(`Unknown compression method: ${method}`);
  }
}
