import http from '@ohos.net.http';

export class HttpClient {
  public get<T>(url: string, successCallback: (data: T) => void, errorCallback: (error: string) => void, params?: Record<string, string>): void {
    const httpRequest = http.createHttp();
    let fullUrl = url;
    if (params && Object.keys(params).length > 0) {
      const queryString = Object.keys(params)
        .map(key => `${encodeURIComponent(key)}=${encodeURIComponent(params[key])}`)
        .join('&');
      fullUrl = `${url}?${queryString}`;
    }

    httpRequest.request(fullUrl, {
      method: http.RequestMethod.GET,
      header: {
        'Content-Type': 'application/json'
      }
    }, (err, response) => {
      httpRequest.destroy();
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

  public post<T>(url: string, data: Object, successCallback: (data: T) => void, errorCallback: (error: string) => void): void {
    const httpRequest = http.createHttp();
    httpRequest.request(url, {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json'
      },
      extraData: data
    }, (err, response) => {
      httpRequest.destroy();
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

  public uploadFile<T>(url: string, file: Object, successCallback: (data: T) => void, errorCallback: (error: string) => void, params?: Record<string, string>): void {
    successCallback('' as T);
  }

  public downloadFile(url: string, successCallback: (data: ArrayBuffer) => void, errorCallback: (error: string) => void, params?: Record<string, string>): void {
    successCallback(new ArrayBuffer(0));
  }
}
