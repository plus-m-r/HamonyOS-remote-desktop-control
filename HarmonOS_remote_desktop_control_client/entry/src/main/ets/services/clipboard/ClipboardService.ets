/**
 * 剪贴板服务（完全解耦版本）
 *
 * 改进点：
 * 1. 实现 IClipboardService 接口
 * 2. 依赖 IHttpRepository 接口而非具体 HTTP 实现
 * 3. 通过构造函数注入依赖，便于 Mock 测试
 * 4. 单一职责：只负责剪贴板业务逻辑
 * 5. 可测试性：HTTP 操作可 Mock
 */

import {
  IClipboardService,
  ClipboardContent,
  ClipboardData
} from '../interfaces/IClipboardService';
import { IHttpRepository } from '../../repository/IHttpRepository';
import { DeviceCodeRequest, SuccessResponse, DeviceCodeParams, ClipboardSyncRequest } from '../../models/CommonTypes';
import hilog from '@ohos.hilog';

const DOMAIN: number = 0xFF00;
const TAG: string = 'ClipboardService';

/**
 * 剪贴板服务配置
 */
export interface ClipboardServiceConfig {
  baseUrl: string;
  syncInterval?: number;
  maxTextLength?: number;
}

/**
 * 完全解耦的剪贴板服务
 * 实现 IClipboardService 接口
 */
export class ClipboardService implements IClipboardService {
  private httpRepository: IHttpRepository;
  private config: Required<ClipboardServiceConfig>;
  private syncTimer: number = -1;
  private lastClipboardContent: string = '';
  private clipboardHistory: ClipboardData[] = [];

  constructor(httpRepository: IHttpRepository, config: ClipboardServiceConfig) {
    this.httpRepository = httpRepository;
    this.config = {
      baseUrl: config.baseUrl,
      syncInterval: config.syncInterval !== undefined ? config.syncInterval : 1000,
      maxTextLength: config.maxTextLength !== undefined ? config.maxTextLength : 10000
    } as Required<ClipboardServiceConfig>;

    // 设置基础 URL
    this.httpRepository.setBaseUrl(this.config.baseUrl);

    hilog.info(DOMAIN, TAG, 'ClipboardService initialized with injected dependencies');
  }

  // ========== IClipboardService 实现 ==========

  /**
   * 清空剪贴板
   */
  async clearClipboard(deviceCode: string): Promise<void> {
    try {
      hilog.info(DOMAIN, TAG, 'Clearing clipboard for device: %{public}s', deviceCode);

      const path = `/api/clipboard/clear`;

      const requestBody: DeviceCodeRequest = {
        deviceCode: deviceCode
      };
      const response = await this.httpRepository.post<SuccessResponse>(path, requestBody);

      if (response.statusCode === 200 && response.data.success) {
        this.lastClipboardContent = '';
        hilog.info(DOMAIN, TAG, 'Clipboard cleared successfully');
      } else {
        throw new Error('清空剪贴板失败');
      }

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Clear clipboard failed: %{public}s', JSON.stringify(error));
      throw new Error(String(error));
    }
  }

  /**
   * 保存剪贴板内容
   */
  async saveClipboard(clipboards: ClipboardData[]): Promise<void> {
    try {
      hilog.info(DOMAIN, TAG, 'Saving clipboard data: %{public}d items', clipboards.length);

      // 添加到历史记录
      this.clipboardHistory = clipboards.concat(this.clipboardHistory);

      // 限制历史记录数量
      if (this.clipboardHistory.length > 100) {
        this.clipboardHistory = this.clipboardHistory.slice(0, 100);
      }

      hilog.info(DOMAIN, TAG, 'Clipboard data saved');

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Save clipboard failed: %{public}s', JSON.stringify(error));
      throw new Error(String(error));
    }
  }

  /**
   * 获取剪贴板内容
   */
  async getClipboard(deviceCode: string): Promise<ClipboardData[]> {
    try {
      hilog.info(DOMAIN, TAG, 'Getting clipboard for device: %{public}s', deviceCode);

      const path = `/api/clipboard/get`;

      const params: DeviceCodeParams = {
        deviceCode: deviceCode
      };
      const response = await this.httpRepository.getWithDeviceCode<ClipboardData[]>(path, params);

      if (response.statusCode === 200) {
        return response.data;
      } else {
        throw new Error(`获取剪贴板失败: ${response.statusCode}`);
      }

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Get clipboard failed: %{public}s', JSON.stringify(error));
      throw new Error(String(error));
    }
  }

  /**
   * 设置本地剪贴板内容
   */
  async setLocalClipboard(content: ClipboardContent): Promise<void> {
    try {
      hilog.info(DOMAIN, TAG, 'Setting local clipboard: %{public}s', content.type);

      // 检查文本长度
      if (content.type === 'text' && content.content.length > this.config.maxTextLength) {
        hilog.warn(DOMAIN, TAG, 'Text too long, truncating');
        content.content = content.content.substring(0, this.config.maxTextLength);
      }

      this.lastClipboardContent = content.content;

      // 添加到历史记录
      const clipboardData: ClipboardData = {
        id: this.generateId(),
        deviceCode: 'local',
        content: content,
        createTime: new Date().toISOString()
      };

      this.clipboardHistory.unshift(clipboardData);

      // 限制历史记录数量
      if (this.clipboardHistory.length > 100) {
        this.clipboardHistory = this.clipboardHistory.slice(0, 100);
      }

      hilog.info(DOMAIN, TAG, 'Local clipboard set successfully');

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Set local clipboard failed: %{public}s', JSON.stringify(error));
      throw new Error(String(error));
    }
  }

  /**
   * 获取本地剪贴板内容
   */
  async getLocalClipboard(): Promise<ClipboardContent | null> {
    try {
      if (!this.lastClipboardContent) {
        return null;
      }

      return {
        type: 'text',
        content: this.lastClipboardContent,
        timestamp: Date.now()
      };

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Get local clipboard failed: %{public}s', JSON.stringify(error));
      return null;
    }
  }

  /**
   * 复制文本到剪贴板（便捷方法）
   */
  copyToClipboard(text: string): void {
    try {
      hilog.info(DOMAIN, TAG, 'Copying text to clipboard');

      const content: ClipboardContent = {
        type: 'text',
        content: text,
        timestamp: Date.now()
      };

      // 检查文本长度
      if (content.content.length > this.config.maxTextLength) {
        hilog.warn(DOMAIN, TAG, 'Text too long, truncating');
        content.content = content.content.substring(0, this.config.maxTextLength);
      }

      this.lastClipboardContent = content.content;

      // 添加到历史记录
      const clipboardData: ClipboardData = {
        id: this.generateId(),
        deviceCode: 'local',
        content: content,
        createTime: new Date().toISOString()
      };

      this.clipboardHistory.unshift(clipboardData);

      // 限制历史记录数量
      if (this.clipboardHistory.length > 100) {
        this.clipboardHistory = this.clipboardHistory.slice(0, 100);
      }

      hilog.info(DOMAIN, TAG, 'Text copied to clipboard successfully');

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Copy to clipboard failed: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 同步剪贴板到远程设备
   */
  async syncToRemote(deviceCode: string, content: ClipboardContent): Promise<boolean> {
    try {
      hilog.info(DOMAIN, TAG, 'Syncing clipboard to remote device: %{public}s', deviceCode);

      const path = `/api/clipboard/sync`;

      const requestBody: ClipboardSyncRequest = {
        deviceCode: deviceCode,
        clipboardData: content as Object
      };
      const response = await this.httpRepository.post<SuccessResponse>(path, requestBody);

      return response.statusCode === 200 && response.data.success;

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Sync to remote failed: %{public}s', JSON.stringify(error));
      return false;
    }
  }

  /**
   * 从远程设备获取剪贴板
   */
  async syncFromRemote(deviceCode: string): Promise<ClipboardContent | null> {
    try {
      hilog.info(DOMAIN, TAG, 'Syncing clipboard from remote device: %{public}s', deviceCode);

      const clipboardData = await this.getClipboard(deviceCode);

      if (clipboardData.length > 0) {
        // 获取最新的剪贴板内容
        const latest = clipboardData[0];
        this.lastClipboardContent = latest.content.content;
        return latest.content;
      }

      return null;

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Sync from remote failed: %{public}s', JSON.stringify(error));
      return null;
    }
  }

  /**
   * 开始自动同步
   */
  startAutoSync(deviceCode: string, interval?: number): void {
    if (this.syncTimer !== -1) {
      hilog.warn(DOMAIN, TAG, 'Auto sync already started');
      return;
    }

    const syncInterval = interval || this.config.syncInterval;

    this.syncTimer = setInterval(async () => {
      try {
        const content = await this.syncFromRemote(deviceCode);

        if (content && content.content !== this.lastClipboardContent) {
          this.lastClipboardContent = content.content;
          hilog.info(DOMAIN, TAG, 'Clipboard updated from remote');
        }
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Auto sync error: %{public}s', JSON.stringify(error));
      }
    }, syncInterval);

    hilog.info(DOMAIN, TAG, 'Auto sync started with interval: %{public}d ms', syncInterval);
  }

  /**
   * 停止自动同步
   */
  stopAutoSync(): void {
    if (this.syncTimer !== -1) {
      clearInterval(this.syncTimer);
      this.syncTimer = -1;
      hilog.info(DOMAIN, TAG, 'Auto sync stopped');
    }
  }

  /**
   * 获取剪贴板历史记录
   */
  async getClipboardHistory(limit?: number): Promise<ClipboardData[]> {
    try {
      const historyLimit = limit || 50;
      return this.clipboardHistory.slice(0, historyLimit);

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Get clipboard history failed: %{public}s', JSON.stringify(error));
      return [];
    }
  }

  /**
   * 删除历史记录项
   */
  async deleteHistoryItem(id: string): Promise<void> {
    try {
      hilog.info(DOMAIN, TAG, 'Deleting history item: %{public}s', id);

      this.clipboardHistory = this.clipboardHistory.filter(item => item.id !== id);

      hilog.info(DOMAIN, TAG, 'History item deleted');

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Delete history item failed: %{public}s', JSON.stringify(error));
      throw new Error(String(error));
    }
  }

  /**
   * 清空历史记录
   */
  async clearHistory(): Promise<void> {
    try {
      hilog.info(DOMAIN, TAG, 'Clearing clipboard history');

      this.clipboardHistory = [];

      hilog.info(DOMAIN, TAG, 'Clipboard history cleared');

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Clear history failed: %{public}s', JSON.stringify(error));
      throw new Error(String(error));
    }
  }

  /**
   * 清理资源
   */
  cleanup(): void {
    this.stopAutoSync();
    this.httpRepository.destroy();
    hilog.info(DOMAIN, TAG, 'ClipboardService cleaned up');
  }

  // ========== 私有方法 ==========

  /**
   * 生成唯一ID
   */
  private generateId(): string {
    return Date.now().toString(36) + Math.random().toString(36).substr(2);
  }
}
