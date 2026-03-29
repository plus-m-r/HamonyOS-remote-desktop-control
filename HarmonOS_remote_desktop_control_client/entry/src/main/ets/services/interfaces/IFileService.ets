// IFileService.ets - 文件服务接口
// 定义文件服务的契约，便于解耦和测试

/**
 * 上传文件接口
 */
export interface UploadFile {
  path?: string;
  uri?: string;
  name?: string;
  size?: number;
}

/**
 * 文件信息接口
 */
export interface FileInfo {
  fileId: string;
  fileName: string;
  fileSize: number;
  fileType: string;
  uploadTime: string;
}

/**
 * 上传进度回调类型
 */
export type UploadProgressCallback = (progress: number) => void;

/**
 * 下载进度回调类型
 */
export type DownloadProgressCallback = (progress: number) => void;

/**
 * 文件服务接口
 * 定义文件服务的完整契约
 */
export interface IFileService {
  // ========== 文件上传 ==========

  /**
   * 上传文件
   * @param file 上传文件信息
   * @param onProgress 进度回调
   */
  uploadFile(file: UploadFile, onProgress?: UploadProgressCallback): Promise<string>;

  /**
   * 快速上传文件（通过MD5秒传）
   * @param md5 文件MD5
   * @param fileSize 文件大小
   */
  quickUploadFile(md5: string, fileSize: number): Promise<string>;

  /**
   * 上传文件分片
   * @param chunkData 分片数据
   * @param md5 文件MD5
   * @param chunkNo 分片序号
   * @param fileName 文件名
   */
  uploadFileChunk(chunkData: ArrayBuffer, md5: string, chunkNo: number, fileName: string): Promise<string>;

  /**
   * 检查分片是否存在
   * @param md5 文件MD5
   * @param chunkNo 分片序号
   * @param chunkSize 分片大小
   */
  checkChunk(md5: string, chunkNo: number, chunkSize: number): Promise<boolean>;

  // ========== 文件下载 ==========

  /**
   * 下载文件
   * @param fileInfoId 文件信息ID
   * @param savePath 保存路径
   * @param onProgress 进度回调
   */
  downloadFile(fileInfoId: string, savePath: string, onProgress?: DownloadProgressCallback): Promise<void>;

  // ========== 文件管理 ==========

  /**
   * 删除文件
   * @param fileInfoIds 文件信息ID数组
   */
  deleteFiles(fileInfoIds: string[]): Promise<void>;

  /**
   * 获取文件列表
   */
  getFileList(): Promise<FileInfo[]>;

  /**
   * 计算文件MD5
   * @param filePath 文件路径
   */
  calculateMD5(filePath: string): Promise<string>;

  // ========== 大文件上传 ==========

  /**
   * 上传大文件（自动分片）
   * @param filePath 文件路径
   * @param onProgress 进度回调
   */
  uploadLargeFile(filePath: string, onProgress?: UploadProgressCallback): Promise<string>;

  // ========== 生命周期 ==========

  /**
   * 清理资源
   */
  cleanup(): void;
}
