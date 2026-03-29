/**
 * HTTP 仓库接口
 * 
 * 抽象 HTTP 操作，便于：
 * 1. 单元测试时 Mock HTTP 请求
 * 2. 统一处理请求/响应拦截
 * 3. 模拟网络错误场景
 */

import { DeviceCodeParams, CheckChunkParams } from '../models/CommonTypes';

/**
 * HTTP 请求配置（无查询参数版本）
 */
export interface HttpRequestConfigNoParams {
  /** 请求方法 */
  method: 'GET' | 'POST' | 'PUT' | 'DELETE';
  /** 请求路径 */
  path: string;
  /** 请求体数据 */
  body?: string | ArrayBuffer | object;
  /** 期望的响应数据类型 */
  responseType?: 'json' | 'text' | 'arraybuffer';
  /** 超时时间（毫秒） */
  timeout?: number;
}

/**
 * HTTP 请求配置（带设备代码查询参数版本）
 */
export interface HttpRequestConfigDeviceCode extends HttpRequestConfigNoParams {
  /** 查询参数 */
  params: DeviceCodeParams;
}

/**
 * HTTP 请求配置（带检查分片查询参数版本）
 */
export interface HttpRequestConfigCheckChunk extends HttpRequestConfigNoParams {
  /** 查询参数 */
  params: CheckChunkParams;
}

/**
 * HTTP 请求配置（联合类型）
 */
export type HttpRequestConfig = HttpRequestConfigNoParams | HttpRequestConfigDeviceCode | HttpRequestConfigCheckChunk;

/**
 * HTTP 响应
 */
export interface HttpResponse<T> {
  /** HTTP 状态码 */
  statusCode: number;
  /** 响应数据 */
  data: T;
}

/**
 * HTTP 进度回调
 */
export type HttpProgressCallback = (progress: number) => void;

/**
 * HTTP 仓库接口
 */
export interface IHttpRepository {
  /**
   * 发送 HTTP 请求
   * @param config 请求配置
   * @returns Promise<HttpResponse>
   */
  request<T>(config: HttpRequestConfig): Promise<HttpResponse<T>>;

  /**
   * GET 请求（无参数）
   * @param path 请求路径
   * @returns Promise<HttpResponse>
   */
  get<T>(path: string): Promise<HttpResponse<T>>;

  /**
   * GET 请求（带设备代码参数）
   * @param path 请求路径
   * @param params 查询参数
   * @returns Promise<HttpResponse>
   */
  getWithDeviceCode<T>(path: string, params: DeviceCodeParams): Promise<HttpResponse<T>>;

  /**
   * GET 请求（带检查分片参数）
   * @param path 请求路径
   * @param params 查询参数
   * @returns Promise<HttpResponse>
   */
  getWithCheckChunk<T>(path: string, params: CheckChunkParams): Promise<HttpResponse<T>>;

  /**
   * POST 请求
   * @param path 请求路径
   * @param body 请求体
   * @returns Promise<HttpResponse>
   */
  post<T>(path: string, body?: string | object): Promise<HttpResponse<T>>;

  /**
   * 上传文件
   * @param path 请求路径
   * @param fileData 文件数据
   * @param onProgress 进度回调
   * @returns Promise<HttpResponse>
   */
  upload<T>(
    path: string, 
    fileData: ArrayBuffer, 
    onProgress?: HttpProgressCallback
  ): Promise<HttpResponse<T>>;

  /**
   * 下载文件
   * @param path 请求路径
   * @param onProgress 进度回调
   * @returns Promise<ArrayBuffer>
   */
  download(
    path: string, 
    onProgress?: HttpProgressCallback
  ): Promise<ArrayBuffer>;

  /**
   * 设置基础 URL
   * @param baseUrl 基础 URL
   */
  setBaseUrl(baseUrl: string): void;

  /**
   * 设置默认 Content-Type 请求头
   * @param contentType Content-Type 值
   */
  setDefaultContentType(contentType: string): void;

  /**
   * 销毁资源
   */
  destroy(): void;
}
