import http from '@ohos.net.http';
import { FileInfo } from '../../models/DeviceInfo';
import { BusinessError } from '@ohos.base';
import fs from '@ohos.file.fs';
import { IFileService } from '../interfaces/IService';
import { FileWorkerManager } from '../../utils/FileWorkerManager';

// 文件上传接口
export interface UploadFile {
  path?: string;
  uri?: string;
}

export class FileService implements IFileService {
  private baseUrl: string;
  private httpModule: http.HttpRequest;
  private chunkSize: number = 5 * 1024 * 1024; // 5MB per chunk
  private fileWorkerManager: FileWorkerManager = new FileWorkerManager();

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
    this.httpModule = http.createHttp();
    this.fileWorkerManager.init();
  }

  // 下载文件
  async downloadFile(fileInfoId: string, savePath: string, onProgress?: (progress: number) => void): Promise<void> {
    try {
      const response = await this.httpModule.request(
        `${this.baseUrl}/file/downloadFile?fileInfoId=${encodeURIComponent(fileInfoId)}`,
        {
          method: http.RequestMethod.GET,
          expectDataType: http.HttpDataType.ARRAY_BUFFER
        }
      );

      if (response.responseCode !== 200) {
        throw new Error(`下载文件失败: ${response.responseCode}`);
      }

      // 保存文件
      const file = fs.openSync(savePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
      fs.writeSync(file.fd, response.result as ArrayBuffer);
      fs.closeSync(file);

      console.info('FileService: File downloaded successfully');
      if (onProgress) {
        onProgress(100);
      }
    } catch (error) {
      const err = error as BusinessError;
      console.error('FileService: Failed to download file', err.message);
      throw new Error(err.message);
    }
  }

  // 快速上传文件（检查文件是否已存在）
  async quickUploadFile(md5: string, fileSize: number): Promise<string> {
    try {
      const response = await this.httpModule.request(
        `${this.baseUrl}/file/quickUploadFile?md5=${encodeURIComponent(md5)}&fileSize=${fileSize}`,
        {
          method: http.RequestMethod.GET
        }
      );

      if (response.responseCode !== 200) {
        throw new Error(`快速上传检查失败: ${response.responseCode}`);
      }

      const fileInfoId = response.result as string;
      console.info('FileService: Quick upload check completed');
      return fileInfoId;
    } catch (error) {
      const err = error as BusinessError;
      console.error('FileService: Failed to quick upload file', err.message);
      throw new Error(err.message);
    }
  }

  // 检查文件分片是否已上传
  async checkChunk(md5: string, chunkNo: number, chunkSize: number): Promise<boolean> {
    try {
      const response = await this.httpModule.request(
        `${this.baseUrl}/file/checkChunk?md5=${encodeURIComponent(md5)}&chunkNo=${chunkNo}&chunkSize=${chunkSize}`,
        {
          method: http.RequestMethod.GET
        }
      );

      if (response.responseCode !== 200) {
        throw new Error(`检查分片失败: ${response.responseCode}`);
      }

      const exists = response.result === 'true' || response.result === true;
      return exists;
    } catch (error) {
      const err = error as BusinessError;
      console.error('FileService: Failed to check chunk', err.message);
      throw new Error(err.message);
    }
  }

  // 上传文件分片
  async uploadFileChunk(
    chunkData: ArrayBuffer,
    md5: string,
    chunkNo: number,
    fileName: string
  ): Promise<string> {
    try {
      const boundary = '----WebKitFormBoundary' + Date.now();
      const header = 
        `--${boundary}\r\n` +
        `Content-Disposition: form-data; name="file"; filename="${fileName}"\r\n` +
        `Content-Type: application/octet-stream\r\n\r\n`;
      
      const footer = `\r\n--${boundary}--\r\n`;
      
      const encoder = new util.TextEncoder();
      const headerArray = encoder.encodeInto(header);
      const footerArray = encoder.encodeInto(footer);
      
      const totalLength = headerArray.byteLength + chunkData.byteLength + footerArray.byteLength;
      const multipartData = new ArrayBuffer(totalLength);
      const view = new Uint8Array(multipartData);
      
      view.set(headerArray, 0);
      view.set(new Uint8Array(chunkData), headerArray.byteLength);
      view.set(footerArray, headerArray.byteLength + chunkData.byteLength);

      const response = await this.httpModule.request(
        `${this.baseUrl}/file/uploadFileChunk?md5=${encodeURIComponent(md5)}&chunkNo=${chunkNo}&fileName=${encodeURIComponent(fileName)}`,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': `multipart/form-data; boundary=${boundary}`
          },
          extraData: multipartData
        }
      );

      if (response.responseCode !== 200) {
        throw new Error(`上传分片失败: ${response.responseCode}`);
      }

      const fileInfoId = response.result as string;
      console.info(`FileService: Chunk ${chunkNo} uploaded successfully`);
      return fileInfoId;
    } catch (error) {
      const err = error as BusinessError;
      console.error('FileService: Failed to upload chunk', err.message);
      throw new Error(err.message);
    }
  }

  // 删除文件
  async deleteFiles(fileInfoIds: string[]): Promise<void> {
    try {
      const response = await this.httpModule.request(
        `${this.baseUrl}/file/deleteFile`,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json'
          },
          extraData: JSON.stringify(fileInfoIds)
        }
      );

      if (response.responseCode !== 200) {
        throw new Error(`删除文件失败: ${response.responseCode}`);
      }

      console.info('FileService: Files deleted successfully');
    } catch (error) {
      const err = error as BusinessError;
      console.error('FileService: Failed to delete files', err.message);
      throw new Error(err.message);
    }
  }

  // 计算文件 MD5（使用Worker在后台线程执行）
  async calculateMD5(filePath: string): Promise<string> {
    try {
      return await this.fileWorkerManager.calculateMD5(filePath);
    } catch (error) {
      const err = error as BusinessError;
      console.error('FileService: Failed to calculate MD5', err.message);
      throw new Error(err.message);
    }
  }

  // 上传大文件（分片上传）
  async uploadLargeFile(
    filePath: string,
    onProgress?: (progress: number) => void
  ): Promise<string> {
    try {
      // 计算文件 MD5
      const md5 = await this.calculateMD5(filePath);
      
      // 获取文件大小
      const stat = fs.statSync(filePath);
      const fileSize = stat.size;
      
      // 快速上传检查
      const quickResult = await this.quickUploadFile(md5, fileSize);
      if (quickResult && quickResult !== 'false') {
        console.info('FileService: File already exists, skip upload');
        if (onProgress) onProgress(100);
        return quickResult;
      }
      
      // 分片上传
      const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
      const totalChunks = Math.ceil(fileSize / this.chunkSize);
      let fileInfoId = '';
      
      for (let chunkNo = 0; chunkNo < totalChunks; chunkNo++) {
        // 检查分片是否已上传
        const chunkExists = await this.checkChunk(md5, chunkNo, this.chunkSize);
        
        if (!chunkExists) {
          // 读取分片数据
          const offset = chunkNo * this.chunkSize;
          const chunkLength = Math.min(this.chunkSize, fileSize - offset);
          const chunkData = new ArrayBuffer(chunkLength);
          fs.readSync(file.fd, chunkData, { offset: 0, length: chunkLength });
          
          // 上传分片
          const fileName = filePath.substring(filePath.lastIndexOf('/') + 1);
          fileInfoId = await this.uploadFileChunk(chunkData, md5, chunkNo, fileName);
        }
        
        // 更新进度
        if (onProgress) {
          const progress = ((chunkNo + 1) / totalChunks) * 100;
          onProgress(progress);
        }
      }
      
      fs.closeSync(file);
      console.info('FileService: Large file uploaded successfully');
      return fileInfoId;
    } catch (error) {
      const err = error as BusinessError;
      console.error('FileService: Failed to upload large file', err.message);
      throw new Error(err.message);
    }
  }

  // 上传文件（支持拖拽文件上传）
  async uploadFile(file: UploadFile, onProgress?: (progress: number) => void): Promise<string> {
    try {
      // 这里需要根据HarmonyOS的文件API获取文件路径
      // 假设file对象包含path属性
      const filePath = file.path || file.uri;
      
      if (!filePath) {
        throw new Error('文件路径不存在');
      }
      
      // 调用分片上传方法
      return await this.uploadLargeFile(filePath, onProgress);
    } catch (error) {
      const err = error as BusinessError;
      console.error('FileService: Failed to upload file', err.message);
      throw new Error(err.message);
    }
  }

  // 清理资源
  cleanup(): void {
    this.httpModule.destroy();
  }
}