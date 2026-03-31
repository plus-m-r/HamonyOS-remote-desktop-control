/**
 * 模型类单元测试
 * 
 * 测试项目中的模型类，这些类是数据载体
 * 测试范围：
 * 1. CmdData - 命令数据类
 * 2. ClipboardData - 剪贴板数据类
 */

import { describe, it, expect } from '@ohos/hypium';
import { CmdData } from '../../../main/ets/models/CmdData';
import { CmdType, ClipboardData } from '../../../main/ets/models/CmdProtocol';

export default function modelsUnitTest() {
  describe('ModelsUnitTest', () => {
    
    // ========== CmdData 测试 ==========
    describe('CmdDataTest', () => {
      
      it('创建 CmdData 实例', 0, () => {
        const cmdData = new CmdData();
        expect(cmdData).notNull();
        expect(cmdData.type).assertEqual(CmdType.ReqPing);
        console.info('✓ 创建 CmdData 实例成功');
      });
      
      it('设置设备码', 0, () => {
        const cmdData = new CmdData();
        cmdData.deviceCode = 'TEST-DEVICE-001';
        expect(cmdData.deviceCode).assertEqual('TEST-DEVICE-001');
        console.info('✓ 设置设备码成功');
      });
      
      it('设置密码', 0, () => {
        const cmdData = new CmdData();
        cmdData.password = 'test_password_123';
        expect(cmdData.password).assertEqual('test_password_123');
        console.info('✓ 设置密码成功');
      });
      
      it('设置状态', 0, () => {
        const cmdData = new CmdData();
        cmdData.status = 'success';
        expect(cmdData.status).assertEqual('success');
        console.info('✓ 设置状态成功');
      });
      
      it('设置图像数据', 0, () => {
        const cmdData = new CmdData();
        const imageData = new ArrayBuffer(1024);
        cmdData.imageData = imageData;
        expect(cmdData.imageData).notNull();
        console.info('✓ 设置图像数据成功');
      });
      
      it('设置图像尺寸', 0, () => {
        const cmdData = new CmdData();
        cmdData.width = 1920;
        cmdData.height = 1080;
        expect(cmdData.width).assertEqual(1920);
        expect(cmdData.height).assertEqual(1080);
        console.info('✓ 设置图像尺寸成功');
      });
      
      it('设置坐标', 0, () => {
        const cmdData = new CmdData();
        cmdData.x = 100;
        cmdData.y = 200;
        expect(cmdData.x).assertEqual(100);
        expect(cmdData.y).assertEqual(200);
        console.info('✓ 设置坐标成功');
      });
      
      it('设置动作', 0, () => {
        const cmdData = new CmdData();
        cmdData.action = 1;
        expect(cmdData.action).assertEqual(1);
        console.info('✓ 设置动作成功');
      });
      
      it('设置滚轮增量', 0, () => {
        const cmdData = new CmdData();
        cmdData.wheelDelta = 120;
        expect(cmdData.wheelDelta).assertEqual(120);
        console.info('✓ 设置滚轮增量成功');
      });
      
      it('设置按键码', 0, () => {
        const cmdData = new CmdData();
        cmdData.keyCode = 65; // A 键
        expect(cmdData.keyCode).assertEqual(65);
        console.info('✓ 设置按键码成功');
      });
      
      it('设置按下状态', 0, () => {
        const cmdData = new CmdData();
        cmdData.pressed = true;
        expect(cmdData.pressed).assertTrue();
        console.info('✓ 设置按下状态成功');
      });
      
      it('设置 FPS 相关参数', 0, () => {
        const cmdData = new CmdData();
        cmdData.fps = 60;
        cmdData.captureFrequency = 30;
        cmdData.quality = 80;
        cmdData.maxFps = 120;
        
        expect(cmdData.fps).assertEqual(60);
        expect(cmdData.captureFrequency).assertEqual(30);
        expect(cmdData.quality).assertEqual(80);
        expect(cmdData.maxFps).assertEqual(120);
        console.info('✓ 设置 FPS 参数成功');
      });
      
      it('设置压缩参数', 0, () => {
        const cmdData = new CmdData();
        cmdData.compressionMethod = 1;
        cmdData.compressionLevel = 5;
        
        expect(cmdData.compressionMethod).assertEqual(1);
        expect(cmdData.compressionLevel).assertEqual(5);
        console.info('✓ 设置压缩参数成功');
      });
      
      it('设置屏幕参数', 0, () => {
        const cmdData = new CmdData();
        cmdData.screenIndex = 0;
        cmdData.captureOp = 1;
        cmdData.screenNum = 2;
        
        expect(cmdData.screenIndex).assertEqual(0);
        expect(cmdData.captureOp).assertEqual(1);
        expect(cmdData.screenNum).assertEqual(2);
        console.info('✓ 设置屏幕参数成功');
      });
      
      it('设置剪贴板数据', 0, () => {
        const cmdData = new CmdData();
        const clipboardData: ClipboardData = {
          id: 'clipboard-001',
          deviceCode: 'TEST-DEVICE',
          content: {
            type: 'text',
            content: '测试文本'
          },
          createTime: new Date().toISOString()
        };
        cmdData.clipboards = [clipboardData];
        expect(cmdData.clipboards.length).assertEqual(1);
        console.info('✓ 设置剪贴板数据成功');
      });
      
      it('设置文本', 0, () => {
        const cmdData = new CmdData();
        cmdData.text = 'Hello World';
        expect(cmdData.text).assertEqual('Hello World');
        console.info('✓ 设置文本成功');
      });
      
      it('设置文件信息', 0, () => {
        const cmdData = new CmdData();
        cmdData.fileInfoId = 'file-123';
        cmdData.fileName = 'test.txt';
        cmdData.filePid = 'pid-456';
        cmdData.isFile = 1;
        
        expect(cmdData.fileInfoId).assertEqual('file-123');
        expect(cmdData.fileName).assertEqual('test.txt');
        expect(cmdData.filePid).assertEqual('pid-456');
        expect(cmdData.isFile).assertEqual(1);
        console.info('✓ 设置文件信息成功');
      });
      
      it('设置密码修改', 0, () => {
        const cmdData = new CmdData();
        cmdData.oldPassword = 'old123';
        cmdData.newPassword = 'new456';
        
        expect(cmdData.oldPassword).assertEqual('old123');
        expect(cmdData.newPassword).assertEqual('new456');
        console.info('✓ 设置密码修改成功');
      });
      
      it('设置操作系统', 0, () => {
        const cmdData = new CmdData();
        cmdData.osName = 'HarmonyOS';
        expect(cmdData.osName).assertEqual('HarmonyOS');
        console.info('✓ 设置操作系统成功');
      });
      
      it('设置命令类型', 0, () => {
        const cmdData = new CmdData();
        cmdData.type = CmdType.ReqCliInfo;
        expect(cmdData.type).assertEqual(CmdType.ReqCliInfo);
        console.info('✓ 设置命令类型成功');
      });
      
      it('设置 ID', 0, () => {
        const cmdData = new CmdData();
        cmdData.id = 'cmd-uuid-12345';
        expect(cmdData.id).assertEqual('cmd-uuid-12345');
        console.info('✓ 设置 ID 成功');
      });
      
      it('完整对象初始化', 0, () => {
        const cmdData = new CmdData();
        cmdData.deviceCode = 'TEST-001';
        cmdData.type = CmdType.ReqRemoteControl;
        cmdData.width = 1920;
        cmdData.height = 1080;
        cmdData.fps = 60;
        
        expect(cmdData.deviceCode).assertEqual('TEST-001');
        expect(cmdData.type).assertEqual(CmdType.ReqRemoteControl);
        expect(cmdData.width).assertEqual(1920);
        expect(cmdData.height).assertEqual(1080);
        expect(cmdData.fps).assertEqual(60);
        
        console.info('✓ 完整对象初始化成功');
      });
    });
    
    // ========== ClipboardData 测试 ==========
    describe('ClipboardDataTest', () => {
      
      it('创建 ClipboardData 对象', 0, () => {
        const clipboard: ClipboardData = {
          id: 'test-001',
          deviceCode: 'DEVICE-001',
          content: {
            type: 'text',
            content: '测试内容'
          },
          createTime: '2024-01-01T00:00:00.000Z'
        };
        
        expect(clipboard).notNull();
        expect(clipboard.id).assertEqual('test-001');
        expect(clipboard.deviceCode).assertEqual('DEVICE-001');
        console.info('✓ 创建 ClipboardData 成功');
      });
      
      it('文件类型剪贴板', 0, () => {
        const clipboard: ClipboardData = {
          id: 'file-001',
          deviceCode: 'DEVICE-001',
          content: {
            type: 'file',
            content: 'file://path/to/file.txt',
            fileName: 'test.txt',
            fileSize: 1024
          },
          createTime: '2024-01-01T00:00:00.000Z'
        };
        
        expect(clipboard.content.type).assertEqual('file');
        expect(clipboard.content.fileName).assertEqual('test.txt');
        expect(clipboard.content.fileSize).assertEqual(1024);
        console.info('✓ 文件类型剪贴板测试通过');
      });
    });
    
    // ========== CmdType 枚举测试 ==========
    describe('CmdTypeEnumTest', () => {
      
      it('验证命令类型值', 0, () => {
        expect(CmdType.ReqPing).assertEqual(0);
        expect(CmdType.ReqCliInfo).assertEqual(1);
        expect(CmdType.ReqRemoteControl).assertEqual(2);
        console.info('✓ 命令类型枚举值验证通过');
      });
    });
    
  });
}
