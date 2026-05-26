export { ICompressor } from './ICompressor';

export { CompressionMethod, fromName, fromCode, toCode } from './CompressionMethod';

export {
  CompressorConfig,
  ConfigBuilderParams,
  createCompressorConfig,
  createDefaultConfig,
  configsEqual,
  cloneConfig,
  configToString
} from './CompressorConfig';

export { CompressionError, CompressionErrorCode } from './CompressionError';

export { CompressorFactory } from './CompressorFactory';

export { ZstdStreamCompressor } from './ZstdStreamCompressor';
export { Lz4StreamCompressor } from './Lz4StreamCompressor';
export { SnappyStreamCompressor } from './SnappyStreamCompressor';
export { NoneStreamCompressor } from './NoneStreamCompressor';