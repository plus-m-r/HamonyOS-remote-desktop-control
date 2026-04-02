import { describe, it, expect } from '@ohos/hypium';
import { 
  ScreenImage, 
  ConnectionState, 
  DeviceInfo, 
  Clipboard, 
  FileInfo, 
  RemoteControlEvent, 
  UserInfo, 
  SessionInfo, 
  DeviceValidationResult, 
  DeviceInfoResult 
} from '../../../../main/ets/models/DeviceInfo';

export default function ModelsExtendedTest() {
  
  describe('ScreenImageTest', () => {
    
    it('创建ScreenImage对象', () => {
      const data = new ArrayBuffer(1024);
      const screenImage = new ScreenImage(data, 1920, 1080, Date.now());
      expect(screenImage).not().assertNull();
      expect(screenImage.width).assertEqual(1920);
      expect(screenImage.height).assertEqual(1080);
    });
    
    it('ScreenImage属性验证', () => {
      const data = new ArrayBuffer(2048);
      const timestamp = 123456789;
      const screenImage = new ScreenImage(data, 800, 600, timestamp);
      
      expect(screenImage.data).assertEqual(data);
      expect(screenImage.width).assertEqual(800);
      expect(screenImage.height).assertEqual(600);
      expect(screenImage.timestamp).assertEqual(timestamp);
    });
  });
  
  describe('ConnectionStateTest', () => {
    
    it('验证连接状态枚举值', () => {
      expect(ConnectionState.DISCONNECTED).assertEqual('disconnected');
      expect(ConnectionState.CONNECTING).assertEqual('connecting');
      expect(ConnectionState.CONNECTED).assertEqual('connected');
      expect(ConnectionState.ERROR).assertEqual('error');
    });
    
    it('测试连接状态转换', () => {
      let state: ConnectionState = ConnectionState.DISCONNECTED;
      expect(state).assertEqual('disconnected');
      
      state = ConnectionState.CONNECTING;
      expect(state).assertEqual('connecting');
      
      state = ConnectionState.CONNECTED;
      expect(state).assertEqual('connected');
      
      state = ConnectionState.ERROR;
      expect(state).assertEqual('error');
    });
  });
  
  describe('InterfaceTest', () => {
    
    it('测试DeviceInfo接口', () => {
      const deviceInfo: DeviceInfo = {
        deviceCode: 'TEST-001',
        name: '测试设备',
        status: 'online',
        lastSeen: '2024-01-01T00:00:00.000Z',
        ipAddress: '192.168.1.100',
        remoteControlEnabled: true
      };
      
      expect(deviceInfo.deviceCode).assertEqual('TEST-001');
      expect(deviceInfo.name).assertEqual('测试设备');
      expect(deviceInfo.status).assertEqual('online');
      expect(deviceInfo.remoteControlEnabled).assertTrue();
    });
    
    it('测试Clipboard接口', () => {
      const clipboard: Clipboard = {
        deviceCode: 'TEST-001',
        content: '测试文本',
        type: 'text',
        id: 'clip-001',
        createTime: '2024-01-01T00:00:00.000Z'
      };
      
      expect(clipboard.deviceCode).assertEqual('TEST-001');
      expect(clipboard.content).assertEqual('测试文本');
      expect(clipboard.type).assertEqual('text');
    });
    
    it('测试FileInfo接口', () => {
      const fileInfo: FileInfo = {
        fileInfoId: 'file-001',
        fileName: 'test.txt',
        fileSize: 1024,
        md5: 'd41d8cd98f00b204e9800998ecf8427e',
        uploadTime: '2024-01-01T00:00:00.000Z'
      };
      
      expect(fileInfo.fileInfoId).assertEqual('file-001');
      expect(fileInfo.fileName).assertEqual('test.txt');
      expect(fileInfo.fileSize).assertEqual(1024);
    });
    
    it('测试RemoteControlEvent接口', () => {
      const event: RemoteControlEvent = {
        type: 'touch',
        action: 'down',
        x: 100,
        y: 200,
        timestamp: Date.now()
      };
      
      expect(event.type).assertEqual('touch');
      expect(event.action).assertEqual('down');
      expect(event.x).assertEqual(100);
      expect(event.y).assertEqual(200);
    });
    
    it('测试UserInfo接口', () => {
      const userInfo: UserInfo = {
        id: 'user-001',
        name: '测试用户',
        email: 'test@example.com',
        avatar: 'https://example.com/avatar.png',
        licenseType: 'free'
      };
      
      expect(userInfo.id).assertEqual('user-001');
      expect(userInfo.name).assertEqual('测试用户');
      expect(userInfo.licenseType).assertEqual('free');
    });
    
    it('测试SessionInfo接口', () => {
      const sessionInfo: SessionInfo = {
        sessionId: 'session-001',
        localDeviceId: 'local-001',
        remoteDeviceId: 'remote-001',
        startTime: Date.now(),
        status: 'active'
      };
      
      expect(sessionInfo.sessionId).assertEqual('session-001');
      expect(sessionInfo.status).assertEqual('active');
    });
    
    it('测试DeviceValidationResult接口', () => {
      const result: DeviceValidationResult = {
        valid: true,
        message: '验证成功'
      };
      
      expect(result.valid).assertTrue();
      expect(result.message).assertEqual('验证成功');
    });
    
    it('测试DeviceInfoResult接口', () => {
      const result: DeviceInfoResult = {
        deviceCode: 'TEST-001',
        password: 'password123'
      };
      
      expect(result.deviceCode).assertEqual('TEST-001');
      expect(result.password).assertEqual('password123');
    });
  });
}