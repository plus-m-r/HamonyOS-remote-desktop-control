import { MemByteBuffer } from './MemByteBuffer';
import { 
  CompressorStreamFactory, 
  InputStream, 
  IOUtils, 
  CompressorInputStream 
} from '@ohos/commons-compress';

export interface Zipper {
  zip(unzipped: MemByteBuffer): MemByteBuffer;
  unzip(zipped: MemByteBuffer): MemByteBuffer;
}

export class NullZipper implements Zipper {
  zip(unzipped: MemByteBuffer): MemByteBuffer {
    const result = new MemByteBuffer(unzipped.size());
    result.writeBytes(unzipped.getInternal());
    return result;
  }

  unzip(zipped: MemByteBuffer): MemByteBuffer {
    const result = new MemByteBuffer(zipped.size());
    result.writeBytes(zipped.getInternal());
    return result;
  }
}

export class ZstdZipper implements Zipper {
  zip(unzipped: MemByteBuffer): MemByteBuffer {
    throw new Error('ZSTD compression not implemented in HarmonyOS client');
  }

  unzip(zipped: MemByteBuffer): MemByteBuffer {
    try {
      const zippedData = zipped.getInternal();
      const result = this.decompressInMemory(zippedData);
      return result;
    } catch (e) {
      console.error('ZstdZipper: ZSTD decompression failed:', e);
      const result = new MemByteBuffer(zipped.size());
      result.writeBytes(zipped.getInternal());
      return result;
    }
  }

  private decompressInMemory(zippedData: Uint8Array): MemByteBuffer {
    try {
      const inputStream = new InputStream();
      inputStream.setBuffer(zippedData.buffer);

      const factory = new CompressorStreamFactory(false);
      const zstdIn: CompressorInputStream = factory.createCompressorInputStream(
        "zstd",
        inputStream
      );

      const decompressedBuffer = IOUtils.toBuffer(zstdIn);

      zstdIn.close();
      inputStream.close();

      const result = new MemByteBuffer(decompressedBuffer.byteLength);
      result.writeBytes(new Uint8Array(decompressedBuffer));
      
      return result;
    } catch (err) {
      console.error("ZstdZipper: 内存解压失败:", err);
      throw err;
    }
  }
}
