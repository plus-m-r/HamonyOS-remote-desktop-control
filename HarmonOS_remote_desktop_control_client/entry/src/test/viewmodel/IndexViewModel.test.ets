// IndexViewModel.test.ets - IndexViewModel 的单元测试示例
// 展示如何使用 Mock 对象进行 ViewModel 测试

import { IndexViewModel, IndexPageState } from '../main/ets/viewmodel/IndexViewModel';
import { MockRemoteControlService } from '../mocks/MockRemoteControlService';
import { MockAppStateManager } from '../mocks/MockAppStateManager';
import { MockClipboardService } from '../mocks/MockClipboardService';
import { AppState } from '../main/ets/state/AppStateManager';

/**
 * IndexViewModel 单元测试
 */
export class IndexViewModelTest {
  private viewModel: IndexViewModel;
  private mockRemoteControlService: MockRemoteControlService;
  private mockAppStateManager: MockAppStateManager;
  private mockClipboardService: MockClipboardService;
  
  // 测试状态记录
  private lastState: IndexPageState | null = null;
  private toastMessages: Array&lt;{ message: string; duration?: number }&gt; = [];
  private navigationCalls: Array&lt;{ url: string; params?: Record&lt;string, string&gt; }&gt; = [];

  constructor() {
    // 创建 Mock 对象
    this.mockRemoteControlService = new MockRemoteControlService();
    this.mockAppStateManager = new MockAppStateManager();
    this.mockClipboardService = new MockClipboardService();
    
    // 创建 ViewModel，注入 Mock 依赖
    this.viewModel = new IndexViewModel({
      remoteControlService: this.mockRemoteControlService,
      appStateManager: this.mockAppStateManager,
      clipboardService: this.mockClipboardService
    });
    
    // 设置回调
    this.viewModel.subscribe((state: IndexPageState) =&gt; {
      this.lastState = state;
    });
    
    this.viewModel.setToastCallback((message: string, duration?: number) =&gt; {
      this.toastMessages.push({ message, duration });
    });
    
    this.viewModel.setNavigationCallback((url: string, params?: Record&lt;string, string&gt;) =&gt; {
      this.navigationCalls.push({ url, params });
    });
  }

  /**
   * 运行所有测试
   */
  async runAllTests(): Promise&lt;void&gt; {
    console.info('========== IndexViewModel 测试开始 ==========');
    
    await this.testInitialize();
    await this.testConnectToDevice();
    await this.testCopyDeviceInfo();
    await this.testRemoteControlToggle();
    await this.testInputHandling();
    
    console.info('========== IndexViewModel 测试完成 ==========');
  }

  /**
   * 测试初始化
   */
  private async testInitialize(): Promise&lt;void&gt; {
    console.info('测试: initialize');
    
    // 设置初始状态
    this.mockAppStateManager.setUserId('TEST123');
    this.mockAppStateManager.setUserPassword('pass456');
    this.mockAppStateManager.setRemoteControlEnabled(true);
    
    // 执行初始化
    this.viewModel.initialize();
    
    // 验证状态
    if (this.lastState?.userId !== 'TEST123') {
      throw new Error('用户ID未正确加载');
    }
    if (this.lastState?.userPassword !== 'pass456') {
      throw new Error('密码未正确加载');
    }
    if (this.lastState?.remoteControlEnabled !== true) {
      throw new Error('远程控制状态未正确加载');
    }
    if (this.lastState?.waitingForServerInfo !== false) {
      throw new Error('等待状态不正确');
    }
    
    console.info('✓ initialize 测试通过');
  }

  /**
   * 测试设备连接
   */
  private async testConnectToDevice(): Promise&lt;void&gt; {
    console.info('测试: connectToDevice');
    
    // 重置
    this.navigationCalls = [];
    this.mockRemoteControlService.reset();
    
    // 设置输入
    this.viewModel.setDeviceIdInput('DEVICE001');
    this.viewModel.setPasswordInput('password123');
    
    // 模拟验证成功
    this.mockRemoteControlService.setMockValidationResult({
      valid: true,
      message: '验证成功'
    });
    
    // 执行连接
    const result = await this.viewModel.connectToDevice();
    
    // 验证结果
    if (!result) {
      throw new Error('连接应该成功');
    }
    
    if (this.navigationCalls.length !== 1) {
      throw new Error('应该有一次导航调用');
    }
    
    if (this.navigationCalls[0].url !== 'pages/Control') {
      throw new Error('应该导航到 Control 页面');
    }
    
    if (this.navigationCalls[0].params?.deviceId !== 'DEVICE001') {
      throw new Error('设备ID参数不正确');
    }
    
    console.info('✓ connectToDevice 测试通过');
  }

  /**
   * 测试复制设备信息
   */
  private async testCopyDeviceInfo(): Promise&lt;void&gt; {
    console.info('测试: copyDeviceInfo / copyAllDeviceInfo');
    
    // 重置
    this.toastMessages = [];
    this.mockClipboardService.clearHistory();
    
    // 设置用户信息
    this.mockAppStateManager.setUserId('USER789');
    this.mockAppStateManager.setUserPassword('secret999');
    
    // 重新初始化以加载新状态
    this.viewModel.initialize();
    
    // 执行复制
    this.viewModel.copyAllDeviceInfo();
    
    // 验证剪贴板内容
    const clipboardContent = this.mockClipboardService.getClipboardContent();
    if (!clipboardContent.includes('USER789')) {
      throw new Error('剪贴板内容应包含设备ID');
    }
    if (!clipboardContent.includes('secret999')) {
      throw new Error('剪贴板内容应包含密码');
    }
    
    // 验证 Toast
    const successToast = this.toastMessages.find(t =&gt; t.message.includes('已复制'));
    if (!successToast) {
      throw new Error('应显示复制成功提示');
    }
    
    console.info('✓ copyDeviceInfo 测试通过');
  }

  /**
   * 测试远程控制开关
   */
  private async testRemoteControlToggle(): Promise&lt;void&gt; {
    console.info('测试: setRemoteControlEnabled');
    
    // 重置
    this.toastMessages = [];
    
    // 开启远程控制
    this.viewModel.setRemoteControlEnabled(true);
    
    if (this.lastState?.remoteControlEnabled !== true) {
      throw new Error('远程控制应已开启');
    }
    
    const enableToast = this.toastMessages.find(t =&gt; t.message.includes('已开启'));
    if (!enableToast) {
      throw new Error('应显示开启提示');
    }
    
    // 关闭远程控制
    this.viewModel.setRemoteControlEnabled(false);
    
    if (this.lastState?.remoteControlEnabled !== false) {
      throw new Error('远程控制应已关闭');
    }
    
    const disableToast = this.toastMessages.find(t =&gt; t.message.includes('已关闭'));
    if (!disableToast) {
      throw new Error('应显示关闭提示');
    }
    
    console.info('✓ setRemoteControlEnabled 测试通过');
  }

  /**
   * 测试输入处理
   */
  private async testInputHandling(): Promise&lt;void&gt; {
    console.info('测试: 输入处理');
    
    // 测试设备ID输入
    this.viewModel.setDeviceIdInput('ABC123');
    if (this.lastState?.deviceIdInput !== 'ABC123') {
      throw new Error('设备ID输入未正确更新');
    }
    
    // 测试密码输入
    this.viewModel.setPasswordInput('mypassword');
    if (this.lastState?.devicePasswordInput !== 'mypassword') {
      throw new Error('密码输入未正确更新');
    }
    
    console.info('✓ 输入处理测试通过');
  }
}

// 导出测试运行函数
export async function runIndexViewModelTests(): Promise&lt;void&gt; {
  const test = new IndexViewModelTest();
  await test.runAllTests();
}
