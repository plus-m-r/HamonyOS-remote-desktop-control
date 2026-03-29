/**
 * 项目通用类型定义
 * 
 * 根据HarmonyOS官方标准，避免使用any和unknown，
 * 为所有数据结构显式定义接口
 */

import {
  ImageProcessResult,
  ProtocolParseResult
} from '../repository/IWorkerRepository';

/**
 * HTTP请求成功响应
 */
export interface SuccessResponse {
  success: boolean;
}

/**
 * 包含文件ID的响应
 */
export interface FileIdResponse extends SuccessResponse {
  fileId: string;
}

/**
 * 包含文件ID且可能为可选的响应
 */
export interface OptionalFileIdResponse extends SuccessResponse {
  fileId?: string;
  exists: boolean;
}

/**
 * 包含分片ID的响应
 */
export interface ChunkIdResponse {
  chunkId: string;
}

/**
 * 检查分片是否存在的响应
 */
export interface ChunkCheckResponse {
  exists: boolean;
}

/**
 * 秒传检查响应
 */
export interface QuickUploadResponse {
  exists: boolean;
  fileId?: string;
}

/**
 * Worker任务回调类型
 */
export type WorkerTaskResolve<T> = (value: T) => void;
export type WorkerTaskReject = (reason?: Error) => void;

/**
 * Worker任务项
 */
export interface WorkerTaskItem<T> {
  resolve: WorkerTaskResolve<T>;
  reject: WorkerTaskReject;
}

/**
 * 图像处理Worker任务项
 */
export interface ImageProcessTaskItem {
  resolve: (value: ImageProcessResult) => void;
  reject: (reason?: Error) => void;
}

/**
 * 协议解析Worker任务项
 */
export interface ProtocolParseTaskItem {
  resolve: (value: ProtocolParseResult) => void;
  reject: (reason?: Error) => void;
}

/**
 * Worker消息
 */
export interface WorkerMessage {
  type: 'imageResult' | 'protocolResult' | 'error';
  taskId: number;
  data?: Object;
  error?: string;
}

/**
 * 图像处理任务消息
 */
export interface ImageTaskMessage {
  type: 'processImage';
  taskId: number;
  task: Object;
}

/**
 * 协议解析任务消息
 */
export interface ProtocolTaskMessage {
  type: 'parseProtocol';
  taskId: number;
  task: Object;
}

/**
 * Worker消息数据
 */
export interface WorkerMessageData {
  data: WorkerMessage;
}

/**
 * Worker错误数据
 */
export interface WorkerErrorData {
  message: string;
}

/**
 * 设备代码请求
 */
export interface DeviceCodeRequest {
  deviceCode: string;
}

/**
 * 设备代码查询参数
 */
export interface DeviceCodeParams {
  deviceCode: string;
}

/**
 * 检查分片查询参数
 */
export interface CheckChunkParams {
  md5: string;
  chunkNo: number;
  chunkSize: number;
}

/**
 * 默认 HTTP 请求头
 */
export interface DefaultHttpHeaders {
  'Content-Type': string;
}

/**
 * 剪贴板同步请求
 */
export interface ClipboardSyncRequest {
  deviceCode: string;
  clipboardData: Object;
}

/**
 * 秒传检查请求
 */
export interface QuickUploadRequest {
  md5: string;
  fileName: string;
  fileSize: number;
}

/**
 * 检查分片请求
 */
export interface CheckChunkRequest {
  md5: string;
  chunkNo: number;
  chunkSize: number;
}

/**
 * 合并分片请求
 */
export interface MergeChunksRequest {
  md5: string;
  fileName: string;
  totalChunks: number;
}

/**
 * 删除文件请求
 */
export interface DeleteFilesRequest {
  fileInfoIds: string[];
}
