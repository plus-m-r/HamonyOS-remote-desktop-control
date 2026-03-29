// IClipboardService.ets - 剪贴板服务接口
// 定义剪贴板服务的契约，便于解耦和测试

/**
 * 剪贴板内容类型
 */
export type ClipboardContentType = 'text' | 'file' | 'image';

/**
 * 剪贴板内容接口
 */
export interface ClipboardContent {
  type: ClipboardContentType;
  content: string;
  fileName?: string;
  fileSize?: number;
  timestamp?: number;
}

/**
 * 剪贴板数据接口（用于历史记录）
 */
export interface ClipboardData {
  id: string;
  deviceCode: string;
  content: ClipboardContent;
  createTime: string;
}

/**
 * 剪贴板服务接口
 * 定义剪贴板服务的完整契约
 */
export interface IClipboardService {
  // ========== 剪贴板操作 ==========

  /**
   * 清空剪贴板
   * @param deviceCode 设备代码
   */
  clearClipboard(deviceCode: string): Promise<void>;

  /**
   * 保存剪贴板内容
   * @param clipboards 剪贴板数据数组
   */
  saveClipboard(clipboards: ClipboardData[]): Promise<void>;

  /**
   * 获取剪贴板内容
   * @param deviceCode 设备代码
   */
  getClipboard(deviceCode: string): Promise<ClipboardData[]>;

  /**
   * 设置本地剪贴板内容
   * @param content 剪贴板内容
   */
  setLocalClipboard(content: ClipboardContent): Promise<void>;

  /**
   * 获取本地剪贴板内容
   */
  getLocalClipboard(): Promise<ClipboardContent | null>;

  /**
   * 复制文本到剪贴板（便捷方法）
   * @param text 文本内容
   */
  copyToClipboard(text: string): void;

  // ========== 同步功能 ==========

  /**
   * 同步剪贴板到远程设备
   * @param deviceCode 目标设备代码
   * @param content 剪贴板内容
   */
  syncToRemote(deviceCode: string, content: ClipboardContent): Promise<boolean>;

  /**
   * 从远程设备获取剪贴板
   * @param deviceCode 源设备代码
   */
  syncFromRemote(deviceCode: string): Promise<ClipboardContent | null>;

  /**
   * 开始自动同步
   * @param deviceCode 设备代码
   * @param interval 同步间隔（毫秒）
   */
  startAutoSync(deviceCode: string, interval?: number): void;

  /**
   * 停止自动同步
   */
  stopAutoSync(): void;

  // ========== 历史记录 ==========

  /**
   * 获取剪贴板历史记录
   * @param limit 限制数量
   */
  getClipboardHistory(limit?: number): Promise<ClipboardData[]>;

  /**
   * 删除历史记录项
   * @param id 记录ID
   */
  deleteHistoryItem(id: string): Promise<void>;

  /**
   * 清空历史记录
   */
  clearHistory(): Promise<void>;

  // ========== 生命周期 ==========

  /**
   * 清理资源
   */
  cleanup(): void;
}
