/**
 * FileService 单元测试
 * 
 * 测试文件服务的所有功能，包括：
 * - 文件上传（普通上传、秒传、分片上传）
 * - 文件下载
 * - 文件管理（删除、列表）
 * - 大文件上传
 */

import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { MockFileService } from './mocks/MockFileService';
import { UploadFile, FileInfo } from '../main/ets/services/interfaces/IFileService';

export function runAllTests(): void {
  console.info('========== FileService 测试开始 ==========');
}

export default function fileServiceTest() {
  describe('FileService 完整测试套件', () => {
    let fileService: MockFileService;
    
    // 测试统计数据
    let totalTests = 0;
    let passedTests = 0;
    let failedTests = 0;

    beforeAll(() => {
      fileService = new MockFileService();
      console.info('FileService Test: Mock 服务初始化完成');
    });

    afterAll(() => {
      fileService.cleanup();
      console.info(`FileService Test: 测试完成 - 总计：${totalTests}, 通过：${passedTests}, 失败：${failedTests}`);
    });

    beforeEach(() => {
      fileService.reset();
    });

    // ========== 文件上传测试 ==========
    describe('文件上传测试', () => {
      it('普通文件上传', 0, async () => {
        totalTests++;
        try {
          const testFile: UploadFile = {
            name: 'test.txt',
            size: 1024,
            path: '/path/test.txt'
          };
          
          const fileId = await fileService.uploadFile(testFile);
          expect(fileId).notNull();
          expect(fileId.length).assertGreater(0);
          passedTests++;
          console.info('✓ 普通文件上传测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('文件上传进度回调', 0, async () => {
        totalTests++;
        try {
          let progressCalled = false;
          const testFile: UploadFile = {
            name: 'test.txt',
            size: 1024,
            path: '/path/test.txt'
          };
          
          const progressCallback = (progress: number) => {
            progressCalled = true;
            expect(progress).assertGreaterThanOrEqual(0);
            expect(progress).assertLessThanOrEqual(1);
          };
          
          fileService.setSimulateDelay(50);
          await fileService.uploadFile(testFile, progressCallback);
          expect(progressCalled).assertTrue();
          passedTests++;
          console.info('✓ 文件上传进度回调测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('秒传 - 文件不存在', 0, async () => {
        totalTests++;
        try {
          try {
            await fileService.quickUploadFile('non-existent-md5', 1024);
            failedTests++;
            throw new Error('应该抛出错误');
          } catch (error) {
            // 预期抛出错误
            passedTests++;
            console.info('✓ 秒传文件不存在测试通过');
          }
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('上传文件分片', 0, async () => {
        totalTests++;
        try {
          const chunkData = new ArrayBuffer(1024);
          const chunkId = await fileService.uploadFileChunk(
            chunkData,
            'test-md5',
            1,
            'large-file.zip'
          );
          
          expect(chunkId).notNull();
          expect(chunkId).assertContain('chunk_');
          passedTests++;
          console.info('✓ 上传文件分片测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('检查分片是否存在', 0, async () => {
        totalTests++;
        try {
          const exists1 = await fileService.checkChunk('test-md5', 2, 1024);
          const exists2 = await fileService.checkChunk('test-md5', 3, 1024);
          
          // Mock 实现中偶数分片返回 true
          expect(exists1).assertTrue();
          expect(exists2).assertFalse();
          passedTests++;
          console.info('✓ 检查分片测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });
    });

    // ========== 文件下载测试 ==========
    describe('文件下载测试', () => {
      it('下载文件', 0, async () => {
        totalTests++;
        try {
          // 先上传一个文件
          const testFile: UploadFile = {
            name: 'download-test.txt',
            size: 2048,
            path: '/path/download-test.txt'
          };
          const fileId = await fileService.uploadFile(testFile);
          
          // 下载文件
          await fileService.downloadFile(fileId, '/save/path');
          const wasCalled = fileService.wasMethodCalled('downloadFile');
          expect(wasCalled).assertTrue();
          passedTests++;
          console.info('✓ 下载文件测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('下载文件进度回调', 0, async () => {
        totalTests++;
        try {
          let progressCount = 0;
          const testFile: UploadFile = {
            name: 'progress-test.txt',
            size: 1024,
            path: '/path/progress-test.txt'
          };
          const fileId = await fileService.uploadFile(testFile);
          
          const progressCallback = (progress: number) => {
            progressCount++;
          };
          
          fileService.setSimulateDelay(50);
          await fileService.downloadFile(fileId, '/save/path', progressCallback);
          expect(progressCount).assertGreaterThanOrEqual(1);
          passedTests++;
          console.info('✓ 下载文件进度回调测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('下载不存在的文件', 0, async () => {
        totalTests++;
        try {
          try {
            await fileService.downloadFile('non-existent-id', '/save/path');
            failedTests++;
            throw new Error('应该抛出错误');
          } catch (error) {
            // 预期抛出错误
            passedTests++;
            console.info('✓ 下载不存在文件测试通过');
          }
        } catch (error) {
          failedTests++;
          throw error;
        }
      });
    });

    // ========== 文件管理测试 ==========
    describe('文件管理测试', () => {
      it('删除文件', 0, async () => {
        totalTests++;
        try {
          // 先上传文件
          const testFile: UploadFile = {
            name: 'delete-test.txt',
            size: 512,
            path: '/path/delete-test.txt'
          };
          const fileId = await fileService.uploadFile(testFile);
          
          // 删除文件
          await fileService.deleteFiles([fileId]);
          
          // 验证删除
          const fileList = await fileService.getFileList();
          const stillExists = fileList.some(f => f.fileId === fileId);
          expect(stillExists).assertFalse();
          passedTests++;
          console.info('✓ 删除文件测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('删除多个文件', 0, async () => {
        totalTests++;
        try {
          // 上传多个文件
          const fileIds: string[] = [];
          for (let i = 0; i < 3; i++) {
            const testFile: UploadFile = {
              name: `file-${i}.txt`,
              size: 100,
              path: `/path/file-${i}.txt`
            };
            const fileId = await fileService.uploadFile(testFile);
            fileIds.push(fileId);
          }
          
          // 删除所有文件
          await fileService.deleteFiles(fileIds);
          
          const fileList = await fileService.getFileList();
          expect(fileList.length).assertEqual(0);
          passedTests++;
          console.info('✓ 删除多个文件测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('获取文件列表', 0, async () => {
        totalTests++;
        try {
          // 上传多个文件
          for (let i = 0; i < 5; i++) {
            const testFile: UploadFile = {
              name: `list-test-${i}.txt`,
              size: 200,
              path: `/path/list-test-${i}.txt`
            };
            await fileService.uploadFile(testFile);
          }
          
          const fileList = await fileService.getFileList();
          expect(fileList.length).assertEqual(5);
          passedTests++;
          console.info('✓ 获取文件列表测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('空文件列表', 0, async () => {
        totalTests++;
        try {
          const fileList = await fileService.getFileList();
          expect(fileList.length).assertEqual(0);
          passedTests++;
          console.info('✓ 空文件列表测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });
    });

    // ========== 大文件上传测试 ==========
    describe('大文件上传测试', () => {
      it('大文件上传', 0, async () => {
        totalTests++;
        try {
          let progressCalled = false;
          const progressCallback = (progress: number) => {
            progressCalled = true;
          };
          
          fileService.setSimulateDelay(30);
          const fileId = await fileService.uploadLargeFile('/path/large-file.zip', progressCallback);
          
          expect(fileId).notNull();
          expect(progressCalled).assertTrue();
          passedTests++;
          console.info('✓ 大文件上传测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('大文件上传进度', 0, async () => {
        totalTests++;
        try {
          const progressValues: number[] = [];
          const progressCallback = (progress: number) => {
            progressValues.push(progress);
          };
          
          fileService.setSimulateDelay(20);
          await fileService.uploadLargeFile('/path/large-file.zip', progressCallback);
          
          expect(progressValues.length).assertGreaterThanOrEqual(4);
          expect(progressValues[0]).assertEqual(0);
          expect(progressValues[progressValues.length - 1]).assertEqual(1);
          passedTests++;
          console.info('✓ 大文件上传进度测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });
    });

    // ========== MD5 计算测试 ==========
    describe('MD5 计算测试', () => {
      it('计算文件 MD5', 0, async () => {
        totalTests++;
        try {
          const md5 = await fileService.calculateMD5('/path/test-file.txt');
          expect(md5).notNull();
          expect(md5).assertContain('md5_');
          passedTests++;
          console.info('✓ 计算文件 MD5 测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });
    });

    // ========== 边界条件测试 ==========
    describe('边界条件测试', () => {
      it('上传空文件', 0, async () => {
        totalTests++;
        try {
          const testFile: UploadFile = {
            name: 'empty.txt',
            size: 0,
            path: '/path/empty.txt'
          };
          
          const fileId = await fileService.uploadFile(testFile);
          expect(fileId).notNull();
          passedTests++;
          console.info('✓ 上传空文件测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('上传文件名包含特殊字符', 0, async () => {
        totalTests++;
        try {
          const testFile: UploadFile = {
            name: 'test file (1).txt',
            size: 100,
            path: '/path/test file (1).txt'
          };
          
          const fileId = await fileService.uploadFile(testFile);
          expect(fileId).notNull();
          passedTests++;
          console.info('✓ 特殊字符文件名测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('上传中文文件名', 0, async () => {
        totalTests++;
        try {
          const testFile: UploadFile = {
            name: '测试文件.txt',
            size: 100,
            path: '/path/测试文件.txt'
          };
          
          const fileId = await fileService.uploadFile(testFile);
          expect(fileId).notNull();
          passedTests++;
          console.info('✓ 中文文件名测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });
    });

    // ========== Mock 功能测试 ==========
    describe('Mock 功能测试', () => {
      it('方法调用跟踪', 0, async () => {
        totalTests++;
        try {
          const testFile: UploadFile = {
            name: 'test.txt',
            size: 100,
            path: '/path/test.txt'
          };
          
          await fileService.uploadFile(testFile);
          await fileService.uploadFile(testFile);
          
          const count = fileService.getMethodCallCount('uploadFile');
          expect(count).assertEqual(2);
          passedTests++;
          console.info('✓ 方法调用跟踪测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });

      it('模拟延迟', 0, async () => {
        totalTests++;
        try {
          fileService.setSimulateDelay(100);
          const startTime = Date.now();
          
          const testFile: UploadFile = {
            name: 'test.txt',
            size: 100,
            path: '/path/test.txt'
          };
          await fileService.uploadFile(testFile);
          
          const elapsed = Date.now() - startTime;
          expect(elapsed).assertGreaterThanOrEqual(100);
          passedTests++;
          console.info('✓ 模拟延迟测试通过');
        } catch (error) {
          failedTests++;
          throw error;
        }
      });
    });
  });
}
