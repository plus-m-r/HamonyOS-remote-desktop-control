import http from '@ohos.net.http';
import { Clipboard } from '../../models/DeviceInfo';
import { BusinessError } from '@ohos.base';
import { IClipboardService } from '../interfaces/IService';

export class ClipboardService implements IClipboardService {
  private baseUrl: string;
  private httpModule: http.HttpRequest;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
    this.httpModule = http.createHttp();
  }

  // 清空剪贴板
  async clearClipboard(deviceCode: string): Promise<void> {
    try {
      const response = await this.httpModule.request(
        `${this.baseUrl}/clipboard/clear?deviceCode=${encodeURIComponent(deviceCode)}`,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json'
          }
        }
      );

      if (response.responseCode !== 200) {
        throw new Error(`清空剪贴板失败: ${response.responseCode}`);
      }

      console.info('ClipboardService: Clipboard cleared successfully');
    } catch (error) {
      const err = error as BusinessError;
      console.error('ClipboardService: Failed to clear clipboard', err.message);
      throw new Error(err.message);
    }
  }

  // 保存剪贴板内容
  async saveClipboard(clipboards: Clipboard[]): Promise<void> {
    try {
      const response = await this.httpModule.request(
        `${this.baseUrl}/clipboard/save`,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json'
          },
          extraData: JSON.stringify(clipboards)
        }
      );

      if (response.responseCode !== 200) {
        throw new Error(`保存剪贴板失败: ${response.responseCode}`);
      }

      console.info('ClipboardService: Clipboard saved successfully');
    } catch (error) {
      const err = error as BusinessError;
      console.error('ClipboardService: Failed to save clipboard', err.message);
      throw new Error(err.message);
    }
  }

  // 获取剪贴板内容
  async getClipboard(deviceCode: string): Promise<Clipboard[]> {
    try {
      const response = await this.httpModule.request(
        `${this.baseUrl}/clipboard/get?deviceCode=${encodeURIComponent(deviceCode)}`,
        {
          method: http.RequestMethod.GET,
          header: {
            'Content-Type': 'application/json'
          }
        }
      );

      if (response.responseCode !== 200) {
        throw new Error(`获取剪贴板失败: ${response.responseCode}`);
      }

      const result = JSON.parse(response.result as string) as Clipboard[];
      console.info('ClipboardService: Clipboard retrieved successfully');
      return result;
    } catch (error) {
      const err = error as BusinessError;
      console.error('ClipboardService: Failed to get clipboard', err.message);
      throw new Error(err.message);
    }
  }

  // 清理资源
  cleanup(): void {
    this.httpModule.destroy();
  }
}