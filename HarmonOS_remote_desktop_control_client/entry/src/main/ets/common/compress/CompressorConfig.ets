import { CompressionMethod } from './CompressionMethod';

/**
 * 压缩器配置（HarmonyOS版本）
 * 
 * <p>使用工厂函数构建不可变配置对象。</p>
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
export interface CompressorConfig {
  /** 压缩方法 */
  readonly method: CompressionMethod;
  
  /** 压缩级别（1-9） */
  readonly compressionLevel: number;
  
  /** 缓冲区大小（字节） */
  readonly bufferSize: number;
  
  /** 是否使用字典 */
  readonly useDictionary: boolean;
  
  /** 字典数据 */
  readonly dictionary: Uint8Array | null;
}

/**
 * 配置构建器参数
 */
export interface ConfigBuilderParams {
  method: CompressionMethod;
  compressionLevel?: number;
  bufferSize?: number;
  useDictionary?: boolean;
  dictionary?: Uint8Array;
}

/**
 * 创建压缩器配置
 * 
 * @param params 配置参数
 * @returns 不可变的CompressorConfig对象
 * @throws Error 如果参数无效
 */
export function createCompressorConfig(params: ConfigBuilderParams): CompressorConfig {
  // 验证压缩级别
  const level = params.compressionLevel ?? 3;
  if (level < 1 || level > 9) {
    throw new Error('Compression level must be between 1 and 9');
  }
  
  // 验证缓冲区大小
  const size = params.bufferSize ?? (64 * 1024); // 默认64KB
  if (size < 1024) {
    throw new Error('Buffer size must be at least 1KB');
  }
  
  // 处理字典
  const dict = params.dictionary ?? null;
  const useDict = params.useDictionary ?? (dict !== null && dict.length > 0);
  
  // 返回不可变配置
  return {
    method: params.method,
    compressionLevel: level,
    bufferSize: size,
    useDictionary: useDict,
    dictionary: dict !== null ? new Uint8Array(dict) : null
  };
}

/**
 * 创建默认配置
 * 
 * @param method 压缩方法
 * @returns 默认配置对象
 */
export function createDefaultConfig(method: CompressionMethod): CompressorConfig {
  return createCompressorConfig({ method });
}

/**
 * 比较两个配置是否相等
 * 
 * @param config1 配置1
 * @param config2 配置2
 * @returns true表示相等
 */
export function configsEqual(config1: CompressorConfig, config2: CompressorConfig): boolean {
  if (config1.method !== config2.method) return false;
  if (config1.compressionLevel !== config2.compressionLevel) return false;
  if (config1.bufferSize !== config2.bufferSize) return false;
  if (config1.useDictionary !== config2.useDictionary) return false;
  
  // 比较字典
  if (config1.dictionary === null && config2.dictionary === null) return true;
  if (config1.dictionary === null || config2.dictionary === null) return false;
  if (config1.dictionary.length !== config2.dictionary.length) return false;
  
  for (let i = 0; i < config1.dictionary.length; i++) {
    if (config1.dictionary[i] !== config2.dictionary[i]) return false;
  }
  
  return true;
}

/**
 * 克隆配置对象
 * 
 * @param config 原配置
 * @returns 新的配置对象
 */
export function cloneConfig(config: CompressorConfig): CompressorConfig {
  return {
    method: config.method,
    compressionLevel: config.compressionLevel,
    bufferSize: config.bufferSize,
    useDictionary: config.useDictionary,
    dictionary: config.dictionary !== null ? new Uint8Array(config.dictionary) : null
  };
}

/**
 * 配置转字符串（用于日志）
 * 
 * @param config 配置对象
 * @returns 字符串表示
 */
export function configToString(config: CompressorConfig): string {
  return `CompressorConfig{method=${config.method}, level=${config.compressionLevel}, ` +
         `bufferSize=${config.bufferSize}, useDict=${config.useDictionary}}`;
}
