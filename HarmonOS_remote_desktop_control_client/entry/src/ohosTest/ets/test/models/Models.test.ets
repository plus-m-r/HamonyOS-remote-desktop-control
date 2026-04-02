import { describe, it, expect } from '@ohos/hypium';
import { CmdData } from '../../../../main/ets/models/CmdData';
import { CmdType, ClipboardData } from '../../../../main/ets/models/CmdProtocol';

export default function ModelsUnitTest() {
  describe('CmdDataTest', 0, () => {
    
    it('创建 CmdData 实例', () => {
      const cmdData = new CmdData();
      expect(cmdData).not().assertNull();
      expect(cmdData.type).assertEqual(CmdType.ReqPing);
    });
    
    it('设置设备码', () => {
      const cmdData = new CmdData();
      cmdData.deviceCode = 'TEST-DEVICE-001';
      expect(cmdData.deviceCode).assertEqual('TEST-DEVICE-001');
    });
    
    it('设置密码', () => {
      const cmdData = new CmdData();
      cmdData.password = 'test_password_123';
      expect(cmdData.password).assertEqual('test_password_123');
    });
    
    it('设置状态', () => {
      const cmdData = new CmdData();
      cmdData.status = 'success';
      expect(cmdData.status).assertEqual('success');
    });
    
    it('设置图像数据', () => {
      const cmdData = new CmdData();
      const imageData = new ArrayBuffer(1024);
      cmdData.imageData = imageData;
      expect(cmdData.imageData).not().assertNull();
    });
    
    it('设置图像尺寸', () => {
      const cmdData = new CmdData();
      cmdData.width = 1920;
      cmdData.height = 1080;
      expect(cmdData.width).assertEqual(1920);
      expect(cmdData.height).assertEqual(1080);
    });
    
    it('设置坐标', () => {
      const cmdData = new CmdData();
      cmdData.x = 100;
      cmdData.y = 200;
      expect(cmdData.x).assertEqual(100);
      expect(cmdData.y).assertEqual(200);
    });
    
    it('设置动作', () => {
      const cmdData = new CmdData();
      cmdData.action = 1;
      expect(cmdData.action).assertEqual(1);
    });
    
    it('设置滚轮增量', () => {
      const cmdData = new CmdData();
      cmdData.wheelDelta = 120;
      expect(cmdData.wheelDelta).assertEqual(120);
    });
    
    it('设置按键码', () => {
      const cmdData = new CmdData();
      cmdData.keyCode = 65;
      expect(cmdData.keyCode).assertEqual(65);
    });
    
    it('设置按下状态', () => {
      const cmdData = new CmdData();
      cmdData.pressed = true;
      expect(cmdData.pressed).assertTrue();
    });
    
    it('设置 FPS 相关参数', () => {
      const cmdData = new CmdData();
      cmdData.fps = 60;
      cmdData.captureFrequency = 30;
      cmdData.quality = 80;
      cmdData.maxFps = 120;
      
      expect(cmdData.fps).assertEqual(60);
      expect(cmdData.captureFrequency).assertEqual(30);
      expect(cmdData.quality).assertEqual(80);
      expect(cmdData.maxFps).assertEqual(120);
    });
    
    it('设置压缩参数', () => {
      const cmdData = new CmdData();
      cmdData.compressionMethod = 1;
      cmdData.compressionLevel = 5;
      
      expect(cmdData.compressionMethod).assertEqual(1);
      expect(cmdData.compressionLevel).assertEqual(5);
    });
    
    it('设置屏幕参数', () => {
      const cmdData = new CmdData();
      cmdData.screenIndex = 0;
      cmdData.captureOp = 1;
      cmdData.screenNum = 2;
      
      expect(cmdData.screenIndex).assertEqual(0);
      expect(cmdData.captureOp).assertEqual(1);
      expect(cmdData.screenNum).assertEqual(2);
    });
    
    it('设置剪贴板数据', () => {
      const cmdData = new CmdData();
      const clipboardData: ClipboardData = {
        id: 'clipboard-001',
        deviceCode: 'TEST-DEVICE',
        text: '测试文本'
      };
      cmdData.clipboards = [clipboardData];
      expect(cmdData.clipboards.length).assertEqual(1);
    });
    
    it('设置文本', () => {
      const cmdData = new CmdData();
      cmdData.text = 'Hello World';
      expect(cmdData.text).assertEqual('Hello World');
    });
    
    it('设置文件信息', () => {
      const cmdData = new CmdData();
      cmdData.fileInfoId = 'file-123';
      cmdData.fileName = 'test.txt';
      cmdData.filePid = 'pid-456';
      cmdData.isFile = 1;
      
      expect(cmdData.fileInfoId).assertEqual('file-123');
      expect(cmdData.fileName).assertEqual('test.txt');
      expect(cmdData.filePid).assertEqual('pid-456');
      expect(cmdData.isFile).assertEqual(1);
    });
    
    it('设置密码修改', () => {
      const cmdData = new CmdData();
      cmdData.oldPassword = 'old123';
      cmdData.newPassword = 'new456';
      
      expect(cmdData.oldPassword).assertEqual('old123');
      expect(cmdData.newPassword).assertEqual('new456');
    });
    
    it('设置操作系统', () => {
      const cmdData = new CmdData();
      cmdData.osName = 'HarmonyOS';
      expect(cmdData.osName).assertEqual('HarmonyOS');
    });
    
    it('设置命令类型', () => {
      const cmdData = new CmdData();
      cmdData.type = CmdType.ReqCliInfo;
      expect(cmdData.type).assertEqual(CmdType.ReqCliInfo);
    });
    
    it('设置 ID', () => {
      const cmdData = new CmdData();
      cmdData.id = 'cmd-uuid-12345';
      expect(cmdData.id).assertEqual('cmd-uuid-12345');
    });
    
    it('完整对象初始化', () => {
      const cmdData = new CmdData();
      cmdData.deviceCode = 'TEST-001';
      cmdData.type = CmdType.ReqOpen;
      cmdData.width = 1920;
      cmdData.height = 1080;
      cmdData.fps = 60;
      
      expect(cmdData.deviceCode).assertEqual('TEST-001');
      expect(cmdData.type).assertEqual(CmdType.ReqOpen);
      expect(cmdData.width).assertEqual(1920);
      expect(cmdData.height).assertEqual(1080);
      expect(cmdData.fps).assertEqual(60);
    });
  });
  
  describe('ClipboardDataTest', 0, () => {
    
    it('创建 ClipboardData 对象', () => {
      const clipboard: ClipboardData = {
        id: 'test-001',
        deviceCode: 'DEVICE-001',
        text: '测试内容'
      };
      
      expect(clipboard).not().assertNull();
      expect(clipboard.id).assertEqual('test-001');
      expect(clipboard.deviceCode).assertEqual('DEVICE-001');
    });
    
    it('文件类型剪贴板', () => {
      const clipboard: ClipboardData = {
        id: 'file-001',
        deviceCode: 'DEVICE-001',
        fileInfoId: 'file-123',
        fileName: 'test.txt',
        filePid: 'pid-456',
        isFile: 1
      };
      
      expect(clipboard.isFile).assertEqual(1);
      expect(clipboard.fileName).assertEqual('test.txt');
    });
  });
  
  describe('CmdTypeEnumTest', 0, () => {
    
    it('验证命令类型值', () => {
      expect(CmdType.ReqPing).assertEqual('ReqPing');
      expect(CmdType.ReqCliInfo).assertEqual('ReqCliInfo');
      expect(CmdType.ReqOpen).assertEqual('ReqOpen');
    });
  });
}