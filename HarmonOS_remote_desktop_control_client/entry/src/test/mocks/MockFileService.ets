// MockFileService.ets - 文件服务的 Mock 实现
// 用于单元测试，无需依赖真实的文件系统或网络

import { IFileService, UploadFile, FileInfo, UploadProgressCallback, DownloadProgressCallback } from '../main/ets/services/interfaces/IFileService';

/**
 * Mock 文件服务
 * 实现 IFileService 接口，用于测试
 */
export class MockFileService implements IFileService {
  // 模拟文件存储
  private files: Map&lt;string, FileInfo&gt; = new Map();
  private uploadedChunks: Map&lt;string, Set&lt;number&gt;&gt; = new Map();
  private fileContents: Map&lt;string, ArrayBuffer&gt; = new Map();
  
  // 调用记录
  public callHistory: Array&lt;{ method: string; args: unknown[] }&gt; = [];
  
  // 模拟延迟
  public simulateDelay: number = 0;

  constructor() {
    console.info('MockFileService: Created');
  }

  // ========== 文件上传 ==========

  async uploadFile(file: UploadFile, onProgress?: UploadProgressCallback): Promise&lt;string&gt; {
    this.recordCall('uploadFile', [file, onProgress]);
    
    await this.delay();
    
    const fileId = this.generateFileId();
    const fileInfo: FileInfo = {
      fileId,
      fileName: file.name || 'unnamed',
      fileSize: file.size || 0,
      fileType: this.getFileType(file.name || ''),
      uploadTime: new Date().toISOString()
    };
    
    this.files.set(fileId, fileInfo);
    
    // 模拟进度回调
    if (onProgress) {
      onProgress(0);
      setTimeout(() =&gt; onProgress(0.5), this.simulateDelay / 2);
      setTimeout(() =&gt; onProgress(1), this.simulateDelay);
    }
    
    return fileId;
  }

  async quickUploadFile(md5: string, fileSize: number): Promise&lt;string&gt; {
    this.recordCall('quickUploadFile', [md5, fileSize]);
    
    await this.delay();
    
    // 模拟秒传：如果 MD5 已存在，返回已有文件ID
    for (const [fileId, fileInfo] of this.files) {
      if (fileInfo.fileSize === fileSize) {
        return fileId; // 模拟找到相同文件
      }
    }
    
    // 文件不存在，抛出错误
    throw new Error('FILE_NOT_EXISTS');
  }

  async uploadFileChunk(
    chunkData: ArrayBuffer,
    md5: string,
    chunkNo: number,
    fileName: string
  ): Promise&lt;string&gt; {
    this.recordCall('uploadFileChunk', [chunkData, md5, chunkNo, fileName]);
    
    await this.delay();
    
    const chunkKey = `${md5}_${fileName}`;
    if (!this.uploadedChunks.has(chunkKey)) {
      this.uploadedChunks.set(chunkKey, new Set());
    }
    
    this.uploadedChunks.get(chunkKey)!.add(chunkNo);
    
    return `chunk_${md5}_${chunkNo}`;
  }

  async checkChunk(md5: string, chunkNo: number, chunkSize: number): Promise&lt;boolean&gt; {
    this.recordCall('checkChunk', [md5, chunkNo, chunkSize]);
    
    await this.delay();
    
    // 模拟检查：假设部分分片已上传
    return chunkNo % 2 === 0;
  }

  // ========== 文件下载 ==========

  async downloadFile(
    fileInfoId: string,
    savePath: string,
    onProgress?: DownloadProgressCallback
  ): Promise&lt;void&gt; {
    this.recordCall('downloadFile', [fileInfoId, savePath, onProgress]);
    
    await this.delay();
    
    if (!this.files.has(fileInfoId)) {
      throw new Error('File not found');
    }
    
    // 模拟进度回调
    if (onProgress) {
      onProgress(0);
      setTimeout(() =&gt; onProgress(0.5), this.simulateDelay / 2);
      setTimeout(() =&gt; onProgress(1), this.simulateDelay);
    }
  }

  // ========== 文件管理 ==========

  async deleteFiles(fileInfoIds: string[]): Promise&lt;void&gt; {
    this.recordCall('deleteFiles', [fileInfoIds]);
    
    await this.delay();
    
    for (const fileId of fileInfoIds) {
      this.files.delete(fileId);
      this.fileContents.delete(fileId);
    }
  }

  async getFileList(): Promise&lt;FileInfo[]&gt; {
    this.recordCall('getFileList', []);
    
    await this.delay();
    
    return Array.from(this.files.values());
  }

  async calculateMD5(filePath: string): Promise&lt;string&gt; {
    this.recordCall('calculateMD5', [filePath]);
    
    await this.delay();
    
    // 模拟 MD5 计算
    return `md5_${filePath}_${Date.now()}`;
  }

  // ========== 大文件上传 ==========

  async uploadLargeFile(filePath: string, onProgress?: UploadProgressCallback): Promise&lt;string&gt; {
    this.recordCall('uploadLargeFile', [filePath, onProgress]);
    
    await this.delay();
    
    // 模拟大文件上传过程
    if (onProgress) {
      onProgress(0);
      
      const totalChunks = 4;
      for (let i = 1; i &lt;= totalChunks; i++) {
        await this.delay();
        onProgress(i / totalChunks);
      }
    }
    
    const fileId = this.generateFileId();
    const fileInfo: FileInfo = {
      fileId,
      fileName: filePath.split('/').pop() || 'unnamed',
      fileSize: 1024 * 1024 * 10, // 模拟 10MB
      fileType: this.getFileType(filePath),
      uploadTime: new Date().toISOString()
    };
    
    this.files.set(fileId, fileInfo);
    
    return fileId;
  }

  // ========== 生命周期 ==========

  cleanup(): void {
    this.recordCall('cleanup', []);
    
    this.files.clear();
    this.uploadedChunks.clear();
    this.fileContents.clear();
  }

  // ========== Mock 专用方法 ==========

  /**
   * 记录方法调用
   */
  private recordCall(method: string, args: unknown[]): void {
    this.callHistory.push({ method, args });
  }

  /**
   * 模拟延迟
   */
  private async delay(): Promise&lt;void&gt; {
    if (this.simulateDelay &gt; 0) {
      return new Promise(resolve =&gt; setTimeout(resolve, this.simulateDelay));
    }
  }

  /**
   * 生成文件ID
   */
  private generateFileId(): string {
    return `file_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * 获取文件类型
   */
  private getFileType(fileName: string): string {
    const ext = fileName.split('.').pop()?.toLowerCase() || '';
    const typeMap: Record&lt;string, string&gt; = {
      'txt': 'text/plain',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    };
    return typeMap[ext] || 'application/octet-stream';
  }

  /**
   * 重置所有状态
   */
  reset(): void {
    this.files.clear();
    this.uploadedChunks.clear();
    this.fileContents.clear();
    this.callHistory = [];
  }

  /**
   * 添加模拟文件
   */
  addMockFile(fileInfo: FileInfo, content?: ArrayBuffer): void {
    this.files.set(fileInfo.fileId, fileInfo);
    if (content) {
      this.fileContents.set(fileInfo.fileId, content);
    }
  }

  /**
   * 获取模拟文件内容
   */
  getMockFileContent(fileId: string): ArrayBuffer | undefined {
    return this.fileContents.get(fileId);
  }

  /**
   * 获取调用历史
   */
  getCallHistory(): Array&lt;{ method: string; args: unknown[] }&gt; {
    return [...this.callHistory];
  }

  /**
   * 检查方法是否被调用
   */
  wasMethodCalled(method: string): boolean {
    return this.callHistory.some(call =&gt; call.method === method);
  }

  /**
   * 获取方法调用次数
   */
  getMethodCallCount(method: string): number {
    return this.callHistory.filter(call =&gt; call.method === method).length;
  }

  /**
   * 设置模拟延迟
   */
  setSimulateDelay(delay: number): void {
    this.simulateDelay = delay;
  }
}
