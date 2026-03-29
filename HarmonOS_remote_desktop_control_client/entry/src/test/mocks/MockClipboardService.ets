// MockClipboardService.ets - 剪贴板服务的 Mock 实现
// 用于单元测试，无需依赖真实的剪贴板或网络

import { IClipboardService, ClipboardContent, ClipboardData } from '../main/ets/services/interfaces/IClipboardService';

/**
 * Mock 剪贴板服务
 * 实现 IClipboardService 接口，用于测试
 */
export class MockClipboardService implements IClipboardService {
  // 剪贴板存储
  private clipboards: Map&lt;string, ClipboardData[]&gt; = new Map();
  private localClipboard: ClipboardContent | null = null;
  private clipboardHistory: ClipboardData[] = [];
  
  // 同步状态
  private autoSyncTimer: number = -1;
  private autoSyncDeviceCode: string = '';
  
  // 调用记录
  public callHistory: Array&lt;{ method: string; args: unknown[] }&gt; = [];
  
  // 模拟延迟
  public simulateDelay: number = 0;

  constructor() {
    console.info('MockClipboardService: Created');
  }

  // ========== 剪贴板操作 ==========

  async clearClipboard(deviceCode: string): Promise&lt;void&gt; {
    this.recordCall('clearClipboard', [deviceCode]);
    
    await this.delay();
    
    this.clipboards.delete(deviceCode);
    
    if (this.localClipboard) {
      this.localClipboard = null;
    }
  }

  async saveClipboard(clipboards: ClipboardData[]): Promise&lt;void&gt; {
    this.recordCall('saveClipboard', [clipboards]);
    
    await this.delay();
    
    // 添加到历史记录
    this.clipboardHistory = [...clipboards, ...this.clipboardHistory];
    
    // 限制历史记录数量
    if (this.clipboardHistory.length &gt; 100) {
      this.clipboardHistory = this.clipboardHistory.slice(0, 100);
    }
    
    // 按设备保存
    for (const clipboard of clipboards) {
      if (!this.clipboards.has(clipboard.deviceCode)) {
        this.clipboards.set(clipboard.deviceCode, []);
      }
      this.clipboards.get(clipboard.deviceCode)!.push(clipboard);
    }
  }

  async getClipboard(deviceCode: string): Promise&lt;ClipboardData[]&gt; {
    this.recordCall('getClipboard', [deviceCode]);
    
    await this.delay();
    
    return this.clipboards.get(deviceCode) || [];
  }

  async setLocalClipboard(content: ClipboardContent): Promise&lt;void&gt; {
    this.recordCall('setLocalClipboard', [content]);
    
    await this.delay();
    
    this.localClipboard = content;
    
    // 添加到历史记录
    const clipboardData: ClipboardData = {
      id: this.generateId(),
      deviceCode: 'local',
      content: content,
      createTime: new Date().toISOString()
    };
    
    this.clipboardHistory.unshift(clipboardData);
    
    // 限制历史记录数量
    if (this.clipboardHistory.length &gt; 100) {
      this.clipboardHistory = this.clipboardHistory.slice(0, 100);
    }
  }

  async getLocalClipboard(): Promise&lt;ClipboardContent | null&gt; {
    this.recordCall('getLocalClipboard', []);
    
    await this.delay();
    
    return this.localClipboard;
  }

  /**
   * 复制文本到剪贴板（便捷方法）
   */
  copyToClipboard(text: string): void {
    this.recordCall('copyToClipboard', [text]);
    
    const content: ClipboardContent = {
      type: 'text',
      content: text,
      timestamp: Date.now()
    };
    
    this.localClipboard = content;
    
    // 添加到历史记录
    const clipboardData: ClipboardData = {
      id: this.generateId(),
      deviceCode: 'local',
      content: content,
      createTime: new Date().toISOString()
    };
    
    this.clipboardHistory.unshift(clipboardData);
    
    // 限制历史记录数量
    if (this.clipboardHistory.length &gt; 100) {
      this.clipboardHistory = this.clipboardHistory.slice(0, 100);
    }
  }

  // ========== 同步功能 ==========

  async syncToRemote(deviceCode: string, content: ClipboardContent): Promise&lt;boolean&gt; {
    this.recordCall('syncToRemote', [deviceCode, content]);
    
    await this.delay();
    
    // 模拟同步成功
    const clipboardData: ClipboardData = {
      id: this.generateId(),
      deviceCode,
      content,
      createTime: new Date().toISOString()
    };
    
    if (!this.clipboards.has(deviceCode)) {
      this.clipboards.set(deviceCode, []);
    }
    
    this.clipboards.get(deviceCode)!.unshift(clipboardData);
    
    return true;
  }

  async syncFromRemote(deviceCode: string): Promise&lt;ClipboardContent | null&gt; {
    this.recordCall('syncFromRemote', [deviceCode]);
    
    await this.delay();
    
    const deviceClipboards = this.clipboards.get(deviceCode);
    
    if (deviceClipboards &amp;&amp; deviceClipboards.length &gt; 0) {
      // 获取最新的剪贴板内容
      const latest = deviceClipboards[0];
      this.localClipboard = latest.content;
      return latest.content;
    }
    
    return null;
  }

  startAutoSync(deviceCode: string, interval?: number): void {
    this.recordCall('startAutoSync', [deviceCode, interval]);
    
    // 停止现有的自动同步
    this.stopAutoSync();
    
    this.autoSyncDeviceCode = deviceCode;
    const syncInterval = interval || 1000;
    
    this.autoSyncTimer = setInterval(async () =&gt; {
      try {
        const content = await this.syncFromRemote(deviceCode);
        if (content) {
          console.info('MockClipboardService: Auto sync updated clipboard');
        }
      } catch (error) {
        console.error('MockClipboardService: Auto sync error', error);
      }
    }, syncInterval);
  }

  stopAutoSync(): void {
    this.recordCall('stopAutoSync', []);
    
    if (this.autoSyncTimer !== -1) {
      clearInterval(this.autoSyncTimer);
      this.autoSyncTimer = -1;
      this.autoSyncDeviceCode = '';
    }
  }

  // ========== 历史记录 ==========

  async getClipboardHistory(limit?: number): Promise&lt;ClipboardData[]&gt; {
    this.recordCall('getClipboardHistory', [limit]);
    
    await this.delay();
    
    const historyLimit = limit || 50;
    return this.clipboardHistory.slice(0, historyLimit);
  }

  async deleteHistoryItem(id: string): Promise&lt;void&gt; {
    this.recordCall('deleteHistoryItem', [id]);
    
    await this.delay();
    
    this.clipboardHistory = this.clipboardHistory.filter(item =&gt; item.id !== id);
  }

  async clearHistory(): Promise&lt;void&gt; {
    this.recordCall('clearHistory', []);
    
    await this.delay();
    
    this.clipboardHistory = [];
  }

  // ========== 生命周期 ==========

  cleanup(): void {
    this.recordCall('cleanup', []);
    
    this.stopAutoSync();
    this.clipboards.clear();
    this.localClipboard = null;
    this.clipboardHistory = [];
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
   * 生成唯一ID
   */
  private generateId(): string {
    return `clip_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * 重置所有状态
   */
  reset(): void {
    this.clipboards.clear();
    this.localClipboard = null;
    this.clipboardHistory = [];
    this.autoSyncTimer = -1;
    this.autoSyncDeviceCode = '';
    this.callHistory = [];
  }

  /**
   * 添加模拟剪贴板数据
   */
  addMockClipboard(deviceCode: string, content: ClipboardContent): void {
    const clipboardData: ClipboardData = {
      id: this.generateId(),
      deviceCode,
      content,
      createTime: new Date().toISOString()
    };
    
    if (!this.clipboards.has(deviceCode)) {
      this.clipboards.set(deviceCode, []);
    }
    
    this.clipboards.get(deviceCode)!.push(clipboardData);
    this.clipboardHistory.push(clipboardData);
  }

  /**
   * 设置本地剪贴板（直接设置，不触发回调）
   */
  setMockLocalClipboard(content: ClipboardContent | null): void {
    this.localClipboard = content;
  }

  /**
   * 获取剪贴板内容（用于测试）
   */
  getClipboardContent(): string {
    if (this.localClipboard &amp;&amp; this.localClipboard.type === 'text') {
      return this.localClipboard.data;
    }
    return '';
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

  /**
   * 获取当前自动同步的设备代码
   */
  getAutoSyncDeviceCode(): string {
    return this.autoSyncDeviceCode;
  }

  /**
   * 检查是否正在自动同步
   */
  isAutoSyncRunning(): boolean {
    return this.autoSyncTimer !== -1;
  }
}
