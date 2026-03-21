import { MemByteBuffer } from './MemByteBuffer';
import fs from '@ohos.file.fs';
import { zstdDecompress } from '@ohos/commons-compress';
import { BusinessError } from '@ohos.base';
import { ContextManager } from '../utils/ContextManager';

export interface Zipper {
  zip(unzipped: MemByteBuffer): MemByteBuffer;
  unzip(zipped: MemByteBuffer): MemByteBuffer;
}

export class ZstdZipper implements Zipper {
  zip(unzipped: MemByteBuffer): MemByteBuffer {
    throw new Error('ZSTD compression not implemented in HarmonyOS client');
  }

  unzip(zipped: MemByteBuffer): MemByteBuffer {
    try {
      const zippedData = zipped.getInternal();
      const result = this.decompressWithTempFiles(zippedData);
      return result;
    } catch (e) {
      const errorMessage = e instanceof Error ? e.message : String(e);
      console.error('ZstdZipper: ZSTD decompression failed:', errorMessage);
      throw new Error(errorMessage);
    }
  }

  private decompressWithTempFiles(zippedData: Uint8Array): MemByteBuffer {
    let tempInputPath: string | null = null;
    let tempOutputPath: string | null = null;
    
    try {
      const tempDir = ContextManager.getInstance().getTempDir();
      console.log('ZstdZipper: 临时目录:', tempDir);
      
      const timestamp = Date.now();
      tempInputPath = `${tempDir}/zstd_temp_input_${timestamp}.zst`;
      tempOutputPath = `${tempDir}/zstd_temp_output_${timestamp}.bin`;
      
      console.log('ZstdZipper: 写入输入文件:', tempInputPath, '大小:', zippedData.length);
      this.writeTempFile(tempInputPath, zippedData);
      console.log('ZstdZipper: 输入文件写入完成');
      
      console.log('ZstdZipper: 开始 ZSTD 解压');
      const decompressSuccess = zstdDecompress(tempInputPath, tempOutputPath);
      console.log('ZstdZipper: ZSTD 解压结果:', decompressSuccess);
      
      if (!decompressSuccess) {
        throw new Error('Zstd decompression failed');
      }
      
      console.log('ZstdZipper: 读取输出文件:', tempOutputPath);
      const decompressedData = this.readTempFile(tempOutputPath);
      console.log('ZstdZipper: 输出文件读取完成，大小:', decompressedData.length);
      
      const result = new MemByteBuffer(decompressedData.length);
      result.writeBytes(decompressedData);
      
      return result;
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : String(err);
      console.error("ZstdZipper: 临时文件解压失败:", errorMsg);
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
      console.log('ZstdZipper: 打开文件写入:', filePath);
      const file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      console.log('ZstdZipper: 文件打开成功，开始写入');
      
      let bytesWritten = 0;
      const chunkSize = 4096;
      while (bytesWritten < data.length) {
        const end = Math.min(bytesWritten + chunkSize, data.length);
        const chunk = data.subarray(bytesWritten, end);
        const written = fs.writeSync(file.fd, chunk);
        bytesWritten += written;
      }
      
      console.log('ZstdZipper: 文件写入完成，共写入', bytesWritten, '字节');
      fs.closeSync(file);
    } catch (error) {
      const err = error as BusinessError;
      console.error('ZstdZipper: 写入临时文件失败:', err.message, '错误码:', err.code);
      throw new Error(`写入临时文件失败：${err.message}`);
    }
  }

  private readTempFile(filePath: string): Uint8Array {
    try {
      console.log('ZstdZipper: 获取文件信息:', filePath);
      const stat = fs.statSync(filePath);
      const fileSize = stat.size;
      console.log('ZstdZipper: 文件大小:', fileSize);
      
      if (fileSize === 0) {
        throw new Error('Output file is empty');
      }
      
      console.log('ZstdZipper: 打开文件读取');
      const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
      const buffer = new ArrayBuffer(fileSize);
      
      console.log('ZstdZipper: 开始读取文件');
      const bytesRead = fs.readSync(file.fd, buffer);
      console.log('ZstdZipper: 读取了', bytesRead, '字节');
      
      fs.closeSync(file);
      
      return new Uint8Array(buffer, 0, bytesRead);
    } catch (error) {
      const err = error as BusinessError;
      console.error('ZstdZipper: 读取临时文件失败:', err.message, '错误码:', err.code);
      throw new Error(`读取临时文件失败：${err.message}`);
    }
  }

  private deleteTempFile(filePath: string): void {
    try {
      fs.unlinkSync(filePath);
    } catch (error) {
      const err = error as BusinessError;
      console.warn('ZstdZipper: 删除临时文件失败:', err.message);
    }
  }
}
