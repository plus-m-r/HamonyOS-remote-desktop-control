/**
 * 文件服务（完全解耦版本）
 *
 * 改进点：
 * 1. 实现 IFileService 接口
 * 2. 依赖 IHttpRepository 接口而非具体 HTTP 实现
 * 3. 通过构造函数注入依赖，便于 Mock 测试
 * 4. 单一职责：只负责文件业务逻辑
 * 5. 可测试性：HTTP 操作可 Mock
 */

import {
  IFileService,
  UploadFile,
  FileInfo,
  UploadProgressCallback,
  DownloadProgressCallback
} from '../interfaces/IFileService';
import { IHttpRepository, HttpRequestConfig } from '../../repository/IHttpRepository';
import {
  FileIdResponse,
  OptionalFileIdResponse,
  ChunkCheckResponse,
  ChunkIdResponse,
  QuickUploadRequest,
  CheckChunkRequest,
  MergeChunksRequest,
  DeleteFilesRequest,
  SuccessResponse,
  CheckChunkParams
} from '../../models/CommonTypes';
import hilog from '@ohos.hilog';

const DOMAIN: number = 0xFF00;
const TAG: string = 'FileService';

/**
 * 文件服务配置
 */
interface FileServiceConfig {
  baseUrl: string;
  chunkSize: number;
  maxConcurrentUploads: number;
  maxFileSize: number;
}

/**
 * 文件服务实现
 */
export class FileService implements IFileService {
  private httpRepository: IHttpRepository;
  private config: FileServiceConfig;

  constructor(httpRepository: IHttpRepository, config: FileServiceConfig) {
    this.httpRepository = httpRepository;
    this.config = config;
    hilog.info(DOMAIN, TAG, 'FileService initialized');
  }

  /**
   * 上传文件
   */
  async uploadFile(file: UploadFile, onProgress?: UploadProgressCallback): Promise<string> {
    try {
      hilog.info(DOMAIN, TAG, 'Uploading file: %{public}s', file.path || file.uri || 'unknown');

      // 简化实现：直接上传
      const path = `/api/file/upload`;

      // 读取文件数据
      const fileData = await this.readFile(file);

      const response = await this.httpRepository.upload<FileIdResponse>(
        path,
        fileData,
        onProgress
      );

      if (response.statusCode === 200) {
        hilog.info(DOMAIN, TAG, 'File uploaded successfully: %{public}s', response.data.fileId);
        return response.data.fileId;
      } else {
        throw new Error(`上传失败: ${response.statusCode}`);
      }

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Upload failed: %{public}s', JSON.stringify(error));
      throw new Error(String(error));
    }
  }

  /**
   * 秒传检查
   */
  async quickUpload(md5: string, fileName: string, fileSize: number): Promise<string | null> {
    try {
      hilog.info(DOMAIN, TAG, 'Quick upload check: %{public}s', md5);

      const path = `/api/file/quick-upload`;

      const requestBody: QuickUploadRequest = {
        md5: md5,
        fileName: fileName,
        fileSize: fileSize
      };
      const response = await this.httpRepository.post<OptionalFileIdResponse>(
        path,
        requestBody
      );

      if (response.statusCode === 200 && response.data.exists) {
        hilog.info(DOMAIN, TAG, 'Quick upload successful: %{public}s', response.data.fileId);
        return response.data.fileId || null;
      }

      return null;

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Quick upload failed: %{public}s', JSON.stringify(error));
      throw new Error(String(error));
    }
  }

  /**
   * 上传文件分片
   */
  async uploadFileChunk(
    chunkData: ArrayBuffer,
    md5: string,
    chunkNo: number,
    fileName: string
  ): Promise<string> {
    try {
      hilog.info(DOMAIN, TAG, 'Uploading chunk %{public}d for file: %{public}s', chunkNo, fileName);

      const path = `/api/file/chunk?md5=${md5}&chunkNo=${chunkNo}&fileName=${encodeURIComponent(fileName)}`;

      const response = await this.httpRepository.upload<ChunkIdResponse>(
        path,
        chunkData
      );

      if (response.statusCode === 200) {
        return response.data.chunkId;
      } else {
        throw new Error(`分片上传失败: ${response.statusCode}`);
      }

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Chunk upload failed: %{public}s', JSON.stringify(error));
      throw new Error(String(error));
    }
  }

  /**
   * 检查分片是否存在
   */
  async checkChunk(md5: string, chunkNo: number, chunkSize: number): Promise<boolean> {
    try {
      const path = `/api/file/chunk/check`;

      const params: CheckChunkParams = {
        md5: md5,
        chunkNo: chunkNo,
        chunkSize: chunkSize
      };
      const response = await this.httpRepository.getWithCheckChunk<ChunkCheckResponse>(
        path,
        params
      );

      return response.statusCode === 200 && response.data.exists;

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Check chunk failed: %{public}s', JSON.stringify(error));
      return false;
    }
  }

  /**
   * 合并分片
   */
  async mergeChunks(md5: string, fileName: string, totalChunks: number): Promise<string> {
    try {
      hilog.info(DOMAIN, TAG, 'Merging chunks for file: %{public}s', fileName);

      const path = `/api/file/merge`;

      const requestBody: MergeChunksRequest = {
        md5: md5,
        fileName: fileName,
        totalChunks: totalChunks
      };
      const response = await this.httpRepository.post<FileIdResponse>(
        path,
        requestBody
      );

      if (response.statusCode === 200) {
        return response.data.fileId;
      } else {
        throw new Error(`合并分片失败: ${response.statusCode}`);
      }

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Merge chunks failed: %{public}s', JSON.stringify(error));
      throw new Error(String(error));
    }
  }

  /**
   * 下载文件
   */
  async downloadFile(fileInfoId: string, savePath: string, onProgress?: DownloadProgressCallback): Promise<void> {
    try {
      hilog.info(DOMAIN, TAG, 'Downloading file: %{public}s', fileInfoId);

      const path = `/api/file/download/${fileInfoId}`;

      // 使用download方法
      await this.httpRepository.download(path, onProgress);

      hilog.info(DOMAIN, TAG, 'File downloaded successfully');

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Download failed: %{public}s', JSON.stringify(error));
      throw new Error(String(error));
    }
  }

  /**
   * 删除文件
   */
  async deleteFiles(fileInfoIds: string[]): Promise<void> {
    try {
      hilog.info(DOMAIN, TAG, 'Deleting files: %{public}s', JSON.stringify(fileInfoIds));

      const path = `/api/file/delete`;

      const requestBody: DeleteFilesRequest = {
        fileInfoIds: fileInfoIds
      };

      const response = await this.httpRepository.request<SuccessResponse>({
        method: 'DELETE',
        path,
        body: requestBody
      });

      if (response.statusCode !== 200 || !response.data.success) {
        throw new Error('删除失败');
      }

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Delete files failed: %{public}s', JSON.stringify(error));
      throw new Error(String(error));
    }
  }

  /**
   * 获取文件列表
   */
  async getFileList(): Promise<FileInfo[]> {
    try {
      const path = `/api/file/list`;

      const response = await this.httpRepository.get<FileInfo[]>(path);

      if (response.statusCode === 200) {
        return response.data;
      } else {
        throw new Error(`获取文件列表失败: ${response.statusCode}`);
      }

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Get file list failed: %{public}s', JSON.stringify(error));
      throw new Error(String(error));
    }
  }

  /**
   * 计算文件MD5
   */
  async calculateFileMD5(file: UploadFile): Promise<string> {
    // 简化实现，实际应该读取文件内容计算MD5
    hilog.info(DOMAIN, TAG, 'Calculating MD5 for file: %{public}s', file.path || file.uri || 'unknown');
    return 'mock-md5-hash';
  }

  /**
   * 快速上传文件（通过MD5秒传）
   */
  async quickUploadFile(md5: string, fileSize: number): Promise<string> {
    // 调用现有的quickUpload方法，使用默认文件名
    const result = await this.quickUpload(md5, 'unknown', fileSize);
    if (result) {
      return result;
    }
    throw new Error('Quick upload failed');
  }

  /**
   * 计算文件MD5（文件路径版本）
   */
  async calculateMD5(filePath: string): Promise<string> {
    // 简化实现，实际应该读取文件内容计算MD5
    hilog.info(DOMAIN, TAG, 'Calculating MD5 for file path: %{public}s', filePath);
    return 'mock-md5-hash';
  }

  /**
   * 上传大文件（自动分片）
   */
  async uploadLargeFile(filePath: string, onProgress?: UploadProgressCallback): Promise<string> {
    hilog.info(DOMAIN, TAG, 'Uploading large file: %{public}s', filePath);
    
    // 简化实现，实际应该分片上传
    const mockFile: UploadFile = {
      path: filePath,
      name: filePath.split('/').pop() || 'unknown',
      size: 0
    };
    
    return this.uploadFile(mockFile, onProgress);
  }

  /**
   * 清理资源
   */
  cleanup(): void {
    hilog.info(DOMAIN, TAG, 'Cleaning up FileService');
    this.httpRepository.destroy();
  }

  /**
   * 读取文件数据
   */
  private async readFile(file: UploadFile): Promise<ArrayBuffer> {
    // 简化实现，实际应该使用文件API读取
    hilog.info(DOMAIN, TAG, 'Reading file: %{public}s', file.path || file.uri || 'unknown');
    return new ArrayBuffer(0);
  }
}
