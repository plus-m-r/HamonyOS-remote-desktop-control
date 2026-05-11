/**
 * 压缩模块统一导出
 * 
 * <p>提供统一的导入入口，简化使用。</p>
 * 
 * @author 方寸控技术团队
 * @version 1.0
 * @since 2026-05-10
 */

// 核心接口
export { ICompressor } from './ICompressor';

// 枚举和类型
export { CompressionMethod, fromName, fromCode, toCode } from './CompressionMethod';

// 配置
export { 
  CompressorConfig, 
  ConfigBuilderParams,
  createCompressorConfig,
  createDefaultConfig,
  configsEqual,
  cloneConfig,
  configToString
} from './CompressorConfig';

// 异常
export { CompressionError, CompressionErrorCode } from './CompressionError';
