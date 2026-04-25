import hilog from '@ohos.hilog';
import { MemByteBuffer } from './MemByteBuffer';
import { fileIo as fs } from '@kit.CoreFileKit';
import { zstdDecompress } from '@ohos/commons-compress';
import { BusinessError } from '@kit.BasicServicesKit';
import { ContextManager } from '../utils/ContextManager';

const DOMAIN: number = 0xFF00;
const TAG: string = 'ZstdZipper';

export interface Zipper {
  zip(unzipped: MemByteBuffer): MemByteBuffer;
  unzip(zipped: MemByteBuffer): Promise<MemByteBuffer>;
}

export class ZstdZipper implements Zipper {
  private fileCounter: number = 0;
  
  zip(unzipped: MemByteBuffer): MemByteBuffer {
    throw new Error('ZSTD compression not implemented in HarmonyOS client');
  }

  async unzip(zipped: MemByteBuffer): Promise<MemByteBuffer> {
    try {
      const zippedData = zipped.getInternal();
      const result = await this.decompressWithTempFiles(zippedData);
      return result;
    } catch (e) {
      const errorMessage = e instanceof Error ? e.message : String(e);
      hilog.error(DOMAIN, TAG, 'ZSTD decompression failed: %{public}s', errorMessage);
      throw new Error(errorMessage);
    }
  }

  private async decompressWithTempFiles(zippedData: Uint8Array): Promise<MemByteBuffer> {
    let tempInputPath: string | null = null;
    let tempOutputPath: string | null = null;
    
    try {
      const tempDir = ContextManager.getInstance().getTempDir();
      
      // 使用计数器代替时间戳，减少字符串操作
      this.fileCounter++;
      tempInputPath = `${tempDir}/zstd_in_${this.fileCounter}.zst`;
      tempOutputPath = `${tempDir}/zstd_out_${this.fileCounter}.bin`;
      
      this.writeTempFile(tempInputPath, zippedData);
      
      const decompressSuccess = await zstdDecompress(tempInputPath, tempOutputPath);
      
      if (!decompressSuccess) {
        throw new Error('Zstd decompression failed');
      }
      
      const decompressedData = this.readTempFile(tempOutputPath);
      
      const result = MemByteBuffer.fromArray(decompressedData);
      
      return result;
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      hilog.error(DOMAIN, TAG, '临时文件解压失败: %{public}s', errorMsg);
      throw new Error(`Zstd解压失败：${errorMsg}`);
    } finally {
      if (tempInputPath) {
        this.deleteTempFile(tempInputPath);
      }
      if (tempOutputPath) {
        this.deleteTempFile(tempOutputPath);
      }
    }
  }

  private writeTempFile(filePath: string, data: Uint8Array): void {
    try {
      const file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      // 只写入实际的数据部分，而不是整个ArrayBuffer
      const actualData = data.buffer.slice(data.byteOffset, data.byteOffset + data.length);
      fs.writeSync(file.fd, actualData);
      // 移除fsync以提升性能，临时文件不需要立即刷新到磁盘
      fs.closeSync(file);
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, TAG, '写入临时文件失败: %{public}s', err.message);
      throw new Error(`写入临时文件失败：${err.message}`);
    }
  }

  private readTempFile(filePath: string): Uint8Array {
    try {
      const stat = fs.statSync(filePath);
      const fileSize = stat.size;
      
      if (fileSize === 0) {
        throw new Error('Output file is empty');
      }
      
      const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
      const buffer = new ArrayBuffer(fileSize);
      const bytesRead = fs.readSync(file.fd, buffer);
      fs.closeSync(file);
      
      return new Uint8Array(buffer, 0, bytesRead);
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, TAG, '读取临时文件失败: %{public}s', err.message);
      throw new Error(`读取临时文件失败：${err.message}`);
    }
  }

  private deleteTempFile(filePath: string): void {
    try {
      fs.unlinkSync(filePath);
    } catch (error) {
      const err = error as BusinessError;
      hilog.warn(DOMAIN, TAG, '删除临时文件失败: %{public}s', err.message);
    }
  }
}
