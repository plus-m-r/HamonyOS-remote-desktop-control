/**
 * ClipboardService 单元测试
 * 
 * 测试剪贴板服务的所有功能，包括：
 * - 剪贴板基本操作（清空、保存、获取）
 * - 本地剪贴板操作
 * - 远程同步功能
 * - 历史记录管理
 * - 自动同步功能
 */

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { MockClipboardService } from './mocks/MockClipboardService';
import { ClipboardContent, ClipboardData } from '../main/ets/services/interfaces/IClipboardService';

export function runAllTests(): void {
  console.info('========== ClipboardService 测试开始 ==========');
}

export default function clipboardServiceTest() {
  describe('ClipboardService 完整测试套件', () => {
    let clipboardService: MockClipboardService;
    const testDeviceCode = 'TEST-DEVICE-001';
    
    // 测试统计数据
    let totalTests = 0;
    let passedTests = 0;
    let failedTests = 0;

    beforeAll(() => {
      clipboardService = new MockClipboardService();
      console.info('ClipboardService Test: Mock 服务初始化完成');
    });

    afterAll(() => {
      clipboardService.cleanup();
      console.info(`ClipboardService Test: 测试完成 - 总计：${totalTests}, 通过：${passedTests}, 失败：${failedTests}`);
    });

    beforeEach(() => {
      clipboardService.reset();
    });

    afterEach(() => {
      // 清理每个测试的状态
    });

    // ========== 基础功能测试 ==========
    describe('基础功能测试', () => {
      it('服务初始化测试', 0, () => {
        totalTests++;
        try {
          expect(clipboardService !== null && clipboardService !== undefined).assertTrue();
          passedTests++;
          console.info('✓ 服务初始化测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('清空剪贴板 - 正常流程', 0, async () => {
        totalTests++;
        try {
          await clipboardService.clearClipboard(testDeviceCode);
          const wasCalled = clipboardService.wasMethodCalled('clearClipboard');
          expect(wasCalled).assertTrue();
          passedTests++;
          console.info('✓ 清空剪贴板测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('保存剪贴板 - 文本类型', 0, async () => {
        totalTests++;
        try {
          const testClipboards: ClipboardData[] = [{
            id: 'test-clipboard-001',
            deviceCode: testDeviceCode,
            content: {
              type: 'text',
              content: '测试文本内容'
            },
            createTime: new Date().toISOString()
          }];

          await clipboardService.saveClipboard(testClipboards);
          const history = await clipboardService.getClipboardHistory();
          expect(history.length).assertEqual(1);
          passedTests++;
          console.info('✓ 保存文本剪贴板测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('保存剪贴板 - 文件类型', 0, async () => {
        totalTests++;
        try {
          const testClipboards: ClipboardData[] = [{
            id: 'test-clipboard-002',
            deviceCode: testDeviceCode,
            content: {
              type: 'file',
              content: 'file://test-document.txt',
              fileName: 'test-document.txt',
              fileSize: 1024
            },
            createTime: new Date().toISOString()
          }];

          await clipboardService.saveClipboard(testClipboards);
          const history = await clipboardService.getClipboardHistory();
          expect(history.length).assertEqual(1);
          passedTests++;
          console.info('✓ 保存文件剪贴板测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('获取剪贴板 - 正常流程', 0, async () => {
        totalTests++;
        try {
          // 先保存数据
          const testClipboards: ClipboardData[] = [{
            id: 'test-clipboard-003',
            deviceCode: testDeviceCode,
            content: {
              type: 'text',
              content: '测试内容'
            },
            createTime: new Date().toISOString()
          }];
          await clipboardService.saveClipboard(testClipboards);

          // 获取数据
          const result = await clipboardService.getClipboard(testDeviceCode);
          expect(result.length).assertEqual(1);
          expect(result[0].deviceCode).assertEqual(testDeviceCode);
          passedTests++;
          console.info('✓ 获取剪贴板测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });
    });

    // ========== 本地剪贴板测试 ==========
    describe('本地剪贴板测试', () => {
      it('设置本地剪贴板', 0, async () => {
        totalTests++;
        try {
          const content: ClipboardContent = {
            type: 'text',
            content: '本地剪贴板内容',
            timestamp: Date.now()
          };
          await clipboardService.setLocalClipboard(content);
          const local = await clipboardService.getLocalClipboard();
          expect(local).notNull();
          expect(local?.content).assertEqual('本地剪贴板内容');
          passedTests++;
          console.info('✓ 设置本地剪贴板测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('获取空本地剪贴板', 0, async () => {
        totalTests++;
        try {
          const local = await clipboardService.getLocalClipboard();
          expect(local).assertNull();
          passedTests++;
          console.info('✓ 获取空本地剪贴板测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('复制文本到剪贴板', 0, () => {
        totalTests++;
        try {
          clipboardService.copyToClipboard('快速复制文本');
          const local = clipboardService.getClipboardContent();
          expect(local).assertEqual('快速复制文本');
          passedTests++;
          console.info('✓ 复制文本到剪贴板测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });
    });

    // ========== 远程同步测试 ==========
    describe('远程同步测试', () => {
      it('同步到远程设备', 0, async () => {
        totalTests++;
        try {
          const content: ClipboardContent = {
            type: 'text',
            content: '同步内容',
            timestamp: Date.now()
          };
          const result = await clipboardService.syncToRemote(testDeviceCode, content);
          expect(result).assertTrue();
          passedTests++;
          console.info('✓ 同步到远程设备测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('从远程设备同步', 0, async () => {
        totalTests++;
        try {
          // 先添加模拟数据
          const mockContent: ClipboardContent = {
            type: 'text',
            content: '远程内容',
            timestamp: Date.now()
          };
          clipboardService.addMockClipboard(testDeviceCode, mockContent);

          // 从远程同步
          const result = await clipboardService.syncFromRemote(testDeviceCode);
          expect(result).notNull();
          expect(result?.content).assertEqual('远程内容');
          passedTests++;
          console.info('✓ 从远程设备同步测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('从空远程设备同步', 0, async () => {
        totalTests++;
        try {
          const result = await clipboardService.syncFromRemote('EMPTY-DEVICE');
          expect(result).assertNull();
          passedTests++;
          console.info('✓ 从空远程设备同步测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });
    });

    // ========== 自动同步测试 ==========
    describe('自动同步测试', () => {
      it('启动自动同步', 0, () => {
        totalTests++;
        try {
          clipboardService.startAutoSync(testDeviceCode, 1000);
          expect(clipboardService.isAutoSyncRunning()).assertTrue();
          expect(clipboardService.getAutoSyncDeviceCode()).assertEqual(testDeviceCode);
          clipboardService.stopAutoSync();
          passedTests++;
          console.info('✓ 启动自动同步测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('停止自动同步', 0, () => {
        totalTests++;
        try {
          clipboardService.startAutoSync(testDeviceCode, 1000);
          clipboardService.stopAutoSync();
          expect(clipboardService.isAutoSyncRunning()).assertFalse();
          passedTests++;
          console.info('✓ 停止自动同步测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('重复启动自动同步', 0, () => {
        totalTests++;
        try {
          clipboardService.startAutoSync(testDeviceCode, 1000);
          clipboardService.startAutoSync(testDeviceCode, 2000);
          expect(clipboardService.isAutoSyncRunning()).assertTrue();
          clipboardService.stopAutoSync();
          passedTests++;
          console.info('✓ 重复启动自动同步测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });
    });

    // ========== 历史记录测试 ==========
    describe('历史记录测试', () => {
      it('获取历史记录', 0, async () => {
        totalTests++;
        try {
          // 添加多条记录
          for (let i = 0; i < 5; i++) {
            const content: ClipboardContent = {
              type: 'text',
              content: `历史记录 ${i}`,
              timestamp: Date.now()
            };
            clipboardService.copyToClipboard(`历史记录 ${i}`);
          }

          const history = await clipboardService.getClipboardHistory();
          expect(history.length).assertEqual(5);
          passedTests++;
          console.info('✓ 获取历史记录测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('删除历史记录项', 0, async () => {
        totalTests++;
        try {
          clipboardService.copyToClipboard('待删除记录');
          const history = await clipboardService.getClipboardHistory();
          const idToDelete = history[0].id;

          await clipboardService.deleteHistoryItem(idToDelete);
          const newHistory = await clipboardService.getClipboardHistory();
          expect(newHistory.length).assertEqual(0);
          passedTests++;
          console.info('✓ 删除历史记录项测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('清空历史记录', 0, async () => {
        totalTests++;
        try {
          for (let i = 0; i < 3; i++) {
            clipboardService.copyToClipboard(`记录 ${i}`);
          }

          await clipboardService.clearHistory();
          const history = await clipboardService.getClipboardHistory();
          expect(history.length).assertEqual(0);
          passedTests++;
          console.info('✓ 清空历史记录测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('历史记录数量限制', 0, async () => {
        totalTests++;
        try {
          // 添加超过 100 条记录
          for (let i = 0; i < 110; i++) {
            clipboardService.copyToClipboard(`记录 ${i}`);
          }

          const history = await clipboardService.getClipboardHistory(100);
          expect(history.length).assertLessThanOrEqual(100);
          passedTests++;
          console.info('✓ 历史记录数量限制测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });
    });

    // ========== 边界条件测试 ==========
    describe('边界条件测试', () => {
      it('空设备码清空剪贴板', 0, async () => {
        totalTests++;
        try {
          await clipboardService.clearClipboard('');
          // 应该不抛出错误
          passedTests++;
          console.info('✓ 空设备码清空剪贴板测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('保存空数组', 0, async () => {
        totalTests++;
        try {
          await clipboardService.saveClipboard([]);
          const history = await clipboardService.getClipboardHistory();
          expect(history.length).assertEqual(0);
          passedTests++;
          console.info('✓ 保存空数组测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('特殊字符内容', 0, async () => {
        totalTests++;
        try {
          const content: ClipboardContent = {
            type: 'text',
            content: '特殊字符：!@#$%^&*()_+{}|:"<>?`~[]\\;\',./',
            timestamp: Date.now()
          };
          await clipboardService.setLocalClipboard(content);
          const local = await clipboardService.getLocalClipboard();
          expect(local?.content).assertEqual(content.content);
          passedTests++;
          console.info('✓ 特殊字符内容测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('中文内容', 0, async () => {
        totalTests++;
        try {
          const content: ClipboardContent = {
            type: 'text',
            content: '中文测试内容：你好世界',
            timestamp: Date.now()
          };
          await clipboardService.setLocalClipboard(content);
          const local = await clipboardService.getLocalClipboard();
          expect(local?.content).assertEqual(content.content);
          passedTests++;
          console.info('✓ 中文内容测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });
    });

    // ========== Mock 功能测试 ==========
    describe('Mock 功能测试', () => {
      it('模拟延迟', 0, async () => {
        totalTests++;
        try {
          clipboardService.setSimulateDelay(100);
          const startTime = Date.now();
          await clipboardService.clearClipboard(testDeviceCode);
          const elapsed = Date.now() - startTime;
          expect(elapsed).assertGreaterThanOrEqual(100);
          clipboardService.setSimulateDelay(0);
          passedTests++;
          console.info('✓ 模拟延迟测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('方法调用跟踪', 0, async () => {
        totalTests++;
        try {
          await clipboardService.clearClipboard(testDeviceCode);
          await clipboardService.clearClipboard(testDeviceCode);
          
          const count = clipboardService.getMethodCallCount('clearClipboard');
          expect(count).assertEqual(2);
          passedTests++;
          console.info('✓ 方法调用跟踪测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('调用历史重置', 0, async () => {
        totalTests++;
        try {
          await clipboardService.clearClipboard(testDeviceCode);
          clipboardService.reset();
          const count = clipboardService.getMethodCallCount('clearClipboard');
          expect(count).assertEqual(0);
          passedTests++;
          console.info('✓ 调用历史重置测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });
    });
  });
}
