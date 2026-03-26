import { MemByteBuffer } from './MemByteBuffer';
import fs from '@ohos.file.fs';
import { zstdDecompress } from '@ohos/commons-compress';
import { BusinessError } from '@ohos.base';
import { ContextManager } from '../utils/ContextManager';

export interface Zipper {
  zip(unzipped: MemByteBuffer): MemByteBuffer;
  unzip(zipped: MemByteBuffer): Promise<MemByteBuffer>;
}

export class ZstdZipper implements Zipper {
  zip(unzipped: MemByteBuffer): MemByteBuffer {
    throw new Error('ZSTD compression not implemented in HarmonyOS client');
  }

  async unzip(zipped: MemByteBuffer): Promise<MemByteBuffer> {
    try {
      const zippedData = zipped.getInternal();
      console.log(`[步骤3-ZSTD解压] 输入压缩数据大小: ${zippedData.length}字节`);
      const result = await this.decompressWithTempFiles(zippedData);
      console.log(`[步骤3-ZSTD解压] 解压完成, 输出数据大小: ${result.size()}字节, 压缩比: ${(zippedData.length / result.size() * 100).toFixed(2)}%`);
      return result;
    } catch (e) {
      const errorMessage = e instanceof Error ? e.message : String(e);
      console.error('ZstdZipper: ZSTD decompression failed:', errorMessage);
      throw new Error(errorMessage);
    }
  }

  private async decompressWithTempFiles(zippedData: Uint8Array): Promise<MemByteBuffer> {
    let tempInputPath: string | null = null;
    let tempOutputPath: string | null = null;
    
    try {
      const context = ContextManager.getInstance().getContext();
      if (!context) {
        throw new Error('Context not initialized');
      }
      
      // 使用应用的缓存目录
      const tempDir = context.cacheDir;
      console.info(`ZstdZipper: 使用缓存目录: ${tempDir}`);
      
      // 检查缓存目录是否存在，如果不存在则创建
      try {
        const dirStat = fs.statSync(tempDir);
        if (!dirStat.isDirectory()) {
          console.warn(`ZstdZipper: 缓存路径不是目录: ${tempDir}`);
          fs.mkdirSync(tempDir, true);
        }
      } catch (error) {
        // 目录不存在，创建它
        console.info(`ZstdZipper: 创建缓存目录: ${tempDir}`);
        fs.mkdirSync(tempDir, true);
      }
      
      // 验证缓存目录是否可访问
      try {
        fs.accessSync(tempDir);
        console.info(`ZstdZipper: 缓存目录可访问: ${tempDir}`);
      } catch (accessError) {
        const err = accessError as BusinessError;
        console.error(`ZstdZipper: 缓存目录不可访问: ${tempDir}, 错误: ${err.message}`);
        throw new Error(`缓存目录不可访问: ${err.message}`);
      }
      
      const timestamp = Date.now();
      tempInputPath = `${tempDir}/zstd_temp_input_${timestamp}.zst`;
      tempOutputPath = `${tempDir}/zstd_temp_output_${timestamp}.bin`;
      
      // 写入压缩数据
      this.writeTempFile(tempInputPath, zippedData);
      
      // 解压
      const decompressSuccess = await zstdDecompress(tempInputPath, tempOutputPath);
      
      if (!decompressSuccess) {
        throw new Error('Zstd decompression failed');
      }
      
      // 读取解压后的数据
      const decompressedData = this.readTempFile(tempOutputPath);
      const result = MemByteBuffer.fromArray(decompressedData);
      
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
      // 检查数据大小
      if (data.length === 0) {
        console.warn('ZstdZipper: 写入空数据到临时文件');
      }
      
      if (data.length > 100 * 1024 * 1024) { // 100MB限制
        console.error(`ZstdZipper: 数据过大: ${data.length} 字节`);
        throw new Error(`数据过大: ${data.length} 字节，超过100MB限制`);
      }
      
      console.info(`ZstdZipper: 准备写入临时文件: ${filePath}, 数据大小: ${data.length} 字节`);
      
      // 创建文件并写入数据
      const file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      
      // 将Uint8Array转换为ArrayBuffer进行写入
      const bytesWritten = fs.writeSync(file.fd, data.buffer);
      
      if (bytesWritten !== data.length) {
        console.warn(`ZstdZipper: 写入字节数不匹配: 期望 ${data.length}, 实际 ${bytesWritten}`);
      }
      
      console.info(`ZstdZipper: 写入临时文件成功，写入 ${bytesWritten} 字节`);
      fs.closeSync(file);
      
      // 验证文件写入成功
      try {
        const stat = fs.statSync(filePath);
        if (stat.size === 0) {
          console.warn(`ZstdZipper: 写入的文件大小为0: ${filePath}`);
        }
      } catch (statError) {
        console.warn(`ZstdZipper: 无法验证文件状态: ${filePath}`, statError);
      }
    } catch (error) {
      const err = error as BusinessError;
      console.error('ZstdZipper: 写入临时文件失败:', err.message, '错误码:', err.code, '文件路径:', filePath);
      throw new Error(`写入临时文件失败：${err.message}`);
    }
  }

  private readTempFile(filePath: string): Uint8Array {
    try {
      const stat = fs.statSync(filePath);
      const fileSize = stat.size;
      
      console.info(`ZstdZipper: 读取临时文件，文件大小 ${fileSize} 字节`);
      
      if (fileSize === 0) {
        throw new Error('Output file is empty');
      }
      
      const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
      const buffer = new ArrayBuffer(fileSize);
      const bytesRead = fs.readSync(file.fd, buffer);
      fs.closeSync(file);
      
      console.info(`ZstdZipper: 读取临时文件成功，读取 ${bytesRead} 字节`);
      
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
