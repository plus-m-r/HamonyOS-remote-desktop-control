// entry/src/main/ets/network/HttpClient.ts
import http from '@ohos.net.http';

export class HttpClient {
  private httpRequest: http.HttpRequest;
  
  constructor() {
    this.httpRequest = http.createHttp();
  }
  
  public get<T = unknown>(url: string, successCallback: (data: T) => void, errorCallback: (error: string) => void, params?: Record<string, string>): void {
    // 将 params 转换为查询字符串
    let fullUrl = url;
    if (params && Object.keys(params).length > 0) {
      const queryString = Object.keys(params)
        .map(key => `${encodeURIComponent(key)}=${encodeURIComponent(params[key])}`)
        .join('&');
      fullUrl = `${url}?${queryString}`;
    }
    
    this.httpRequest.request(fullUrl, {
      method: http.RequestMethod.GET,
      header: {
        'Content-Type': 'application/json'
      }
    }, (err, response) => {
      if (err) {
        errorCallback(JSON.stringify(err));
        return;
      }
      if (response.responseCode === 200) {
        successCallback(JSON.parse(response.result as string) as T);
      } else {
        errorCallback(`HTTP error: ${response.responseCode}`);
      }
    });
  }
  
  public post<T = unknown>(url: string, data: unknown, successCallback: (data: T) => void, errorCallback: (error: string) => void): void {
    this.httpRequest.request(url, {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json'
      },
      extraData: data
    }, (err, response) => {
      if (err) {
        errorCallback(JSON.stringify(err));
        return;
      }
      if (response.responseCode === 200) {
        successCallback(JSON.parse(response.result as string) as T);
      } else {
        errorCallback(`HTTP error: ${response.responseCode}`);
      }
    });
  }
  
  public uploadFile<T = unknown>(url: string, file: unknown, successCallback: (data: T) => void, errorCallback: (error: string) => void, params?: Record<string, string>): void {
    // 实现文件上传逻辑
    // 使用 FormData 或其他方式上传文件
    successCallback('' as T);
  }
  
  public downloadFile(url: string, successCallback: (data: ArrayBuffer) => void, errorCallback: (error: string) => void, params?: Record<string, string>): void {
    // 实现文件下载逻辑
    successCallback(new ArrayBuffer(0));
  }
  
  public cleanup(): void {
    // 释放资源
    this.httpRequest.destroy();
  }
}