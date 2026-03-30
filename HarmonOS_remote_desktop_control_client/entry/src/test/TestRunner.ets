// TestRunner.ets - 单元测试运行器
// 统一运行所有单元测试

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';

// 导入所有测试类
import { runAllTests as runClipboardServiceTests } from './ClipboardService.test';
import { runAllTests as runCmdProtocolTests } from './CmdProtocol.test';
import { runAllTests as runCompressorTests } from './Compressor.test';
import { runAllTests as runFileServiceTests } from './FileService.test';
import { runAllTests as runListTests } from './List.test';
import { runAllTests as runLocalUnitTests } from './LocalUnit.test';
import { runAllTests as runRemoteControlServiceTests } from './RemoteControlService.test';
import { runAllTests as runIndexViewModelTests } from './viewmodel/IndexViewModel.test';
import { runControlViewModelTests } from './viewmodel/ControlViewModel.test';
import { runHeartbeatManagerTests } from './services/HeartbeatManager.test';

/**
 * 单元测试运行器
 * 使用 HarmonyOS Hypium 测试框架
 */
export default function testRunner() {
  describe('HarmonyOS远程桌面控制客户端单元测试套件', () => {
    let totalTests = 0;
    let passedTests = 0;
    let failedTests = 0;

    beforeAll(() => {
      console.info('========== 单元测试开始 ==========');
      console.info('测试框架: @ohos/hypium');
      console.info('测试时间: ' + new Date().toISOString());
    });

    afterAll(() => {
      console.info('========== 单元测试完成 ==========');
      console.info(`总计: ${totalTests} 个测试`);
      console.info(`通过: ${passedTests} 个`);
      console.info(`失败: ${failedTests} 个`);
      
      if (failedTests === 0) {
        console.info('✅ 所有测试通过！');
      } else {
        console.error(`❌ ${failedTests} 个测试失败`);
      }
    });

    // ClipboardService 测试
    describe('ClipboardService 测试', () => {
      it('ClipboardService 功能测试', 0, async () => {
        totalTests++;
        try {
          await runClipboardServiceTests();
          passedTests++;
          console.info('✅ ClipboardService 测试通过');
        } catch (error) {
          failedTests++;
          console.error('❌ ClipboardService 测试失败:', error);
          throw error;
        }
      });
    });

    // CmdProtocol 测试
    describe('CmdProtocol 测试', () => {
      it('CmdProtocol 功能测试', 0, async () => {
        totalTests++;
        try {
          await runCmdProtocolTests();
          passedTests++;
          console.info('✅ CmdProtocol 测试通过');
        } catch (error) {
          failedTests++;
          console.error('❌ CmdProtocol 测试失败:', error);
          throw error;
        }
      });
    });

    // Compressor 测试
    describe('Compressor 测试', () => {
      it('Compressor 功能测试', 0, async () => {
        totalTests++;
        try {
          await runCompressorTests();
          passedTests++;
          console.info('✅ Compressor 测试通过');
        } catch (error) {
          failedTests++;
          console.error('❌ Compressor 测试失败:', error);
          throw error;
        }
      });
    });

    // FileService 测试
    describe('FileService 测试', () => {
      it('FileService 功能测试', 0, async () => {
        totalTests++;
        try {
          await runFileServiceTests();
          passedTests++;
          console.info('✅ FileService 测试通过');
        } catch (error) {
          failedTests++;
          console.error('❌ FileService 测试失败:', error);
          throw error;
        }
      });
    });

    // List 测试
    describe('List 测试', () => {
      it('List 功能测试', 0, async () => {
        totalTests++;
        try {
          await runListTests();
          passedTests++;
          console.info('✅ List 测试通过');
        } catch (error) {
          failedTests++;
          console.error('❌ List 测试失败:', error);
          throw error;
        }
      });
    });

    // LocalUnit 测试
    describe('LocalUnit 测试', () => {
      it('LocalUnit 功能测试', 0, async () => {
        totalTests++;
        try {
          await runLocalUnitTests();
          passedTests++;
          console.info('✅ LocalUnit 测试通过');
        } catch (error) {
          failedTests++;
          console.error('❌ LocalUnit 测试失败:', error);
          throw error;
        }
      });
    });

    // RemoteControlService 测试
    describe('RemoteControlService 测试', () => {
      it('RemoteControlService 功能测试', 0, async () => {
        totalTests++;
        try {
          await runRemoteControlServiceTests();
          passedTests++;
          console.info('✅ RemoteControlService 测试通过');
        } catch (error) {
          failedTests++;
          console.error('❌ RemoteControlService 测试失败:', error);
          throw error;
        }
      });
    });

    // IndexViewModel 测试
    describe('IndexViewModel 测试', () => {
      it('IndexViewModel 功能测试', 0, async () => {
        totalTests++;
        try {
          await runIndexViewModelTests();
          passedTests++;
          console.info('✅ IndexViewModel 测试通过');
        } catch (error) {
          failedTests++;
          console.error('❌ IndexViewModel 测试失败:', error);
          throw error;
        }
      });
    });

    // ControlViewModel 测试
    describe('ControlViewModel 测试', () => {
      it('ControlViewModel 功能测试', 0, async () => {
        totalTests++;
        try {
          runControlViewModelTests();
          passedTests++;
          console.info('✅ ControlViewModel 测试通过');
        } catch (error) {
          failedTests++;
          console.error('❌ ControlViewModel 测试失败:', error);
          throw error;
        }
      });
    });

    // HeartbeatManager 测试
    describe('HeartbeatManager 测试', () => {
      it('HeartbeatManager 功能测试', 0, async () => {
        totalTests++;
        try {
          runHeartbeatManagerTests();
          passedTests++;
          console.info('✅ HeartbeatManager 测试通过');
        } catch (error) {
          failedTests++;
          console.error('❌ HeartbeatManager 测试失败:', error);
          throw error;
        }
      });
    });

    // 基础断言测试
    describe('基础断言测试', () => {
      it('assertEqual 测试', 0, () => {
        totalTests++;
        try {
          const a = 'test';
          const b = 'test';
          expect(a).assertEqual(b);
          passedTests++;
          console.info('✅ assertEqual 测试通过');
        } catch (error) {
          failedTests++;
          console.error('❌ assertEqual 测试失败:', error);
          throw error;
        }
      });

      it('assertContain 测试', 0, () => {
        totalTests++;
        try {
          const a = 'hello world';
          const b = 'world';
          expect(a).assertContain(b);
          passedTests++;
          console.info('✅ assertContain 测试通过');
        } catch (error) {
          failedTests++;
          console.error('❌ assertContain 测试失败:', error);
          throw error;
        }
      });

      it('assertTrue 测试', 0, () => {
        totalTests++;
        try {
          const condition = true;
          expect(condition).assertTrue();
          passedTests++;
          console.info('✅ assertTrue 测试通过');
        } catch (error) {
          failedTests++;
          console.error('❌ assertTrue 测试失败:', error);
          throw error;
        }
      });

      it('assertFalse 测试', 0, () => {
        totalTests++;
        try {
          const condition = false;
          expect(condition).assertFalse();
          passedTests++;
          console.info('✅ assertFalse 测试通过');
        } catch (error) {
          failedTests++;
          console.error('❌ assertFalse 测试失败:', error);
          throw error;
        }
      });
    });
  });
}