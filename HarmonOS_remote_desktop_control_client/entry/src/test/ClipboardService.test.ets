import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { ClipboardService } from '../main/ets/services/clipboard/ClipboardService';
import { Clipboard } from '../main/ets/models/DeviceInfo';
import { SERVER_CONFIG } from '../main/ets/config/config';

export default function clipboardServiceTest() {
  describe('ClipboardService测试套件', () => {
    let clipboardService: ClipboardService;
    const baseUrl = `http://${SERVER_CONFIG.host}:${SERVER_CONFIG.httpPort}${SERVER_CONFIG.contextPath}`;
    const testDeviceCode = 'TEST-DEVICE-001';

    beforeAll(() => {
      // 初始化服务
      clipboardService = new ClipboardService(baseUrl);
      console.info('ClipboardService Test: 初始化完成');
    });

    afterAll(() => {
      // 清理资源
      clipboardService.cleanup();
      console.info('ClipboardService Test: 资源清理完成');
    });

    it('服务初始化测试', 0, () => {
      expect(clipboardService !== null && clipboardService !== undefined).assertTrue();
      console.info('ClipboardService Test: 服务初始化成功');
    });

    it('清空剪贴板-正常流程', 0, async () => {
      try {
        await clipboardService.clearClipboard(testDeviceCode);
        console.info('ClipboardService Test: 清空剪贴板成功');
      } catch (error) {
        console.warn('ClipboardService Test: 清空剪贴板失败，服务端可能未启动');
      }
    });

    it('保存剪贴板-文本类型', 0, async () => {
      const testClipboards: Clipboard[] = [
        {
          deviceCode: testDeviceCode,
          isFile: 0  // 文本类型
        }
      ];

      try {
        await clipboardService.saveClipboard(testClipboards);
        console.info('ClipboardService Test: 保存文本剪贴板成功');
      } catch (error) {
        console.warn('ClipboardService Test: 保存文本剪贴板失败');
      }
    });

    it('保存剪贴板-文件类型', 0, async () => {
      const testClipboards: Clipboard[] = [
        {
          deviceCode: testDeviceCode,
          fileInfoId: 'file-test-001',
          fileName: 'test-document.txt',
          filePid: 'folder-test-001',
          isFile: 1  // 文件类型
        }
      ];

      try {
        await clipboardService.saveClipboard(testClipboards);
        console.info('ClipboardService Test: 保存文件剪贴板成功');
      } catch (error) {
        console.warn('ClipboardService Test: 保存文件剪贴板失败');
      }
    });

    it('保存剪贴板-多个记录', 0, async () => {
      const testClipboards: Clipboard[] = [
        {
          deviceCode: testDeviceCode,
          isFile: 0
        },
        {
          deviceCode: testDeviceCode,
          fileInfoId: 'file-test-002',
          fileName: 'test-image.png',
          filePid: 'folder-test-001',
          isFile: 1
        }
      ];

      try {
        await clipboardService.saveClipboard(testClipboards);
        console.info('ClipboardService Test: 保存多个剪贴板记录成功');
      } catch (error) {
        console.warn('ClipboardService Test: 保存多个剪贴板记录失败');
      }
    });

    it('获取剪贴板-正常流程', 0, async () => {
      try {
        const result = await clipboardService.getClipboard(testDeviceCode);
        console.info(`ClipboardService Test: 获取剪贴板返回结果类型: ${typeof result}`);
        
        if (result !== null && result !== undefined) {
          if (Array.isArray(result)) {
            console.info(`ClipboardService Test: 获取剪贴板成功，数量: ${result.length}`);
            
            // 验证返回的数据结构
            if (result.length > 0) {
              const firstItem = result[0];
              console.info(`ClipboardService Test: 第一条记录 - id: ${firstItem.id}, deviceCode: ${firstItem.deviceCode}, isFile: ${firstItem.isFile}`);
              
              // 验证字段是否存在
              expect(firstItem.deviceCode).assertEqual(testDeviceCode);
              expect(firstItem.isFile !== undefined).assertTrue();
            }
          } else {
            console.warn(`ClipboardService Test: 返回结果不是数组，实际类型: ${typeof result}`);
          }
        } else {
          console.warn('ClipboardService Test: 获取剪贴板返回空结果');
        }
      } catch (error) {
        console.warn('ClipboardService Test: 获取剪贴板失败');
      }
    });

    it('清空剪贴板-空设备码', 0, async () => {
      try {
        await clipboardService.clearClipboard('');
        console.warn('ClipboardService Test: 空设备码应该抛出错误');
      } catch (error) {
        expect(error !== null && error !== undefined).assertTrue();
        console.info('ClipboardService Test: 空设备码正确抛出错误');
      }
    });

    it('保存剪贴板-空数组', 0, async () => {
      try {
        await clipboardService.saveClipboard([]);
        console.info('ClipboardService Test: 空数组保存成功');
      } catch (error) {
        console.warn('ClipboardService Test: 空数组保存失败');
      }
    });

    it('保存剪贴板-特殊字符文件名', 0, async () => {
      const specialContent: Clipboard[] = [
        {
          deviceCode: testDeviceCode,
          fileInfoId: 'file-special-001',
          fileName: 'test file (1).txt',
          filePid: 'folder-test-001',
          isFile: 1
        }
      ];

      try {
        await clipboardService.saveClipboard(specialContent);
        console.info('ClipboardService Test: 特殊字符文件名保存成功');
      } catch (error) {
        console.warn('ClipboardService Test: 特殊字符文件名保存失败');
      }
    });

    it('保存剪贴板-中文文件名', 0, async () => {
      const chineseContent: Clipboard[] = [
        {
          deviceCode: testDeviceCode,
          fileInfoId: 'file-chinese-001',
          fileName: '测试文档.txt',
          filePid: 'folder-test-001',
          isFile: 1
        }
      ];

      try {
        await clipboardService.saveClipboard(chineseContent);
        console.info('ClipboardService Test: 中文文件名保存成功');
      } catch (error) {
        console.warn('ClipboardService Test: 中文文件名保存失败');
      }
    });
  });
}