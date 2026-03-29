/**
 * HTTP 仓库实现
 *
 * 实现 IHttpRepository 接口，使用 HarmonyOS http 模块
 */

import {
  IHttpRepository,
  HttpRequestConfig,
  HttpRequestConfigNoParams,
  HttpRequestConfigDeviceCode,
  HttpRequestConfigCheckChunk,
  HttpResponse,
  HttpProgressCallback
} from './IHttpRepository';
import { DeviceCodeParams, CheckChunkParams, DefaultHttpHeaders } from '../models/CommonTypes';
import http from '@ohos.net.http';
import { BusinessError } from '@ohos.base';

export class HttpRepositoryImpl implements IHttpRepository {
  private baseUrl: string = '';
  private defaultContentType: string = 'application/json';

  setBaseUrl(baseUrl: string): void {
    this.baseUrl = baseUrl;
  }

  setDefaultContentType(contentType: string): void {
    this.defaultContentType = contentType;
  }

  async request<T>(config: HttpRequestConfig): Promise<HttpResponse<T>> {
    const httpRequest = http.createHttp();

    try {
      let url = `${this.baseUrl}${config.path}`;
      
      // 使用类型检查方法
      if (this.hasParams(config)) {
        const configWithParams = config as HttpRequestConfigDeviceCode | HttpRequestConfigCheckChunk;
        const params = configWithParams.params;
        
        // 检查DeviceCodeParams类型
        if (this.isDeviceCodeParams(params)) {
          const deviceParams = params as DeviceCodeParams;
          url += `?deviceCode=${encodeURIComponent(deviceParams.deviceCode)}`;
        } 
        // 检查CheckChunkParams类型
        else if (this.isCheckChunkParams(params)) {
          const chunkParams = params as CheckChunkParams;
          url += `?md5=${encodeURIComponent(chunkParams.md5)}&chunkNo=${chunkParams.chunkNo}&chunkSize=${chunkParams.chunkSize}`;
        }
      }

      const headers: DefaultHttpHeaders = {
        'Content-Type': this.defaultContentType
      };

      let extraData: string | undefined;
      if (config.body) {
        extraData = typeof config.body === 'string' ? config.body : JSON.stringify(config.body);
      }

      let expectDataType = http.HttpDataType.STRING;
      if (config.responseType === 'arraybuffer') {
        expectDataType = http.HttpDataType.ARRAY_BUFFER;
      }

      const response = await httpRequest.request(url, {
        method: config.method as http.RequestMethod,
        header: headers,
        extraData: extraData,
        expectDataType: expectDataType,
        connectTimeout: config.timeout || 30000,
        readTimeout: config.timeout || 30000
      });

      let data: T;
      if (config.responseType === 'json' && typeof response.result === 'string') {
        data = JSON.parse(response.result) as T;
      } else {
        data = response.result as T;
      }

      return {
        statusCode: response.responseCode,
        data: data
      };

    } catch (error) {
      const err = error as BusinessError;
      console.error('HttpRepositoryImpl: Request failed', err.message);
      throw new Error(err.message);
    } finally {
      httpRequest.destroy();
    }
  }

  async get<T>(path: string): Promise<HttpResponse<T>> {
    return this.request<T>({
      method: 'GET',
      path,
      responseType: 'json'
    });
  }

  async getWithDeviceCode<T>(path: string, params: DeviceCodeParams): Promise<HttpResponse<T>> {
    return this.request<T>({
      method: 'GET',
      path,
      params,
      responseType: 'json'
    });
  }

  async getWithCheckChunk<T>(path: string, params: CheckChunkParams): Promise<HttpResponse<T>> {
    return this.request<T>({
      method: 'GET',
      path,
      params,
      responseType: 'json'
    });
  }

  async post<T>(path: string, body?: string | object): Promise<HttpResponse<T>> {
    return this.request<T>({
      method: 'POST',
      path,
      body,
      responseType: 'json'
    });
  }

  async upload<T>(
    path: string,
    fileData: ArrayBuffer,
    onProgress?: HttpProgressCallback
  ): Promise<HttpResponse<T>> {
    const httpRequest = http.createHttp();

    try {
      const url = `${this.baseUrl}${path}`;

      const headers: DefaultHttpHeaders = {
        'Content-Type': 'application/octet-stream'
      };

      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: fileData
      });

      return {
        statusCode: response.responseCode,
        data: response.result as T
      };

    } catch (error) {
      const err = error as BusinessError;
      console.error('HttpRepositoryImpl: Upload failed', err.message);
      throw new Error(err.message);
    } finally {
      httpRequest.destroy();
    }
  }

  async download(
    path: string,
    onProgress?: HttpProgressCallback
  ): Promise<ArrayBuffer> {
    const response = await this.request<ArrayBuffer>({
      method: 'GET',
      path,
      responseType: 'arraybuffer'
    });

    if (response.statusCode !== 200) {
      throw new Error(`Download failed: ${response.statusCode}`);
    }

    return response.data;
  }
  destroy(): void {
    this.baseUrl = '';
    this.defaultContentType = 'application/json';
  }
  // 类型检查方法
  private hasParams(config: HttpRequestConfig): boolean {
    return (config as HttpRequestConfigDeviceCode | HttpRequestConfigCheckChunk).params !== undefined;
  }

  private isDeviceCodeParams(params: DeviceCodeParams | CheckChunkParams): boolean {
    return (params as DeviceCodeParams).deviceCode !== undefined;
  }

  private isCheckChunkParams(params: DeviceCodeParams | CheckChunkParams): boolean {
    const chunkParams = params as CheckChunkParams;
    return chunkParams.md5 !== undefined && chunkParams.chunkNo !== undefined && chunkParams.chunkSize !== undefined;
  }
}
