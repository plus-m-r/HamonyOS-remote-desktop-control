import { describe, it, expect, beforeAll } from '@ohos/hypium';
import { 
  AppStateManager, 
  MemoryStorageImpl, 
  IStateStorage,
  AppStateKey,
  ConnectionStatus,
  AppState,
  SyncSettings
} from '../../../../main/ets/state/AppStateManager';
import { DeviceInfo, ConnectionConfig } from '../../../../main/ets/state/IAppStateManager';

export default function AppStateManagerTest() {
  
  describe('MemoryStorageImplTest', () => {
    let storage: IStateStorage;
    
    beforeAll(() => {
      storage = new MemoryStorageImpl();
    });
    
    it('设置和获取值', () => {
      storage.set('testKey', 'testValue');
      expect(storage.get<string>('testKey')).assertEqual('testValue');
    });
    
    it('获取不存在的键', () => {
      expect(storage.get<string>('nonExistentKey')).assertNull();
    });
    
    it('删除键', () => {
      storage.set('toDelete', 'value');
      expect(storage.get<string>('toDelete')).assertEqual('value');
      
      storage.remove('toDelete');
      expect(storage.get<string>('toDelete')).assertNull();
    });
    
    it('清空所有值', () => {
      storage.set('key1', 'value1');
      storage.set('key2', 'value2');
      
      storage.clear();
      
      expect(storage.get<string>('key1')).assertNull();
      expect(storage.get<string>('key2')).assertNull();
    });
    
    it('存储数值类型', () => {
      storage.set('numberKey', 123);
      expect(storage.get<number>('numberKey')).assertEqual(123);
    });
    
    it('存储布尔类型', () => {
      storage.set('boolKey', true);
      expect(storage.get<boolean>('boolKey')).assertTrue();
    });
  });
  
  describe('AppStateManagerCoreTest', () => {
    let manager: AppStateManager;
    let storage: IStateStorage;
    
    beforeAll(() => {
      storage = new MemoryStorageImpl();
      manager = new AppStateManager(storage);
    });
    
    it('设置和获取用户ID', () => {
      manager.setUserId('user-001');
      expect(manager.getUserId()).assertEqual('user-001');
    });
    
    it('设置和获取用户密码', () => {
      manager.setUserPassword('password123');
      expect(manager.getUserPassword()).assertEqual('password123');
    });
    
    it('清除用户认证信息', () => {
      manager.setUserId('user-002');
      manager.setUserPassword('pass456');
      
      manager.clearUserAuth();
      
      expect(manager.getUserId()).assertEqual('');
      expect(manager.getUserPassword()).assertEqual('');
    });
    
    it('设置和获取远程设备ID', () => {
      manager.setRemoteDeviceId('remote-001');
      expect(manager.getRemoteDeviceId()).assertEqual('remote-001');
    });
    
    it('设置和获取远程设备密码', () => {
      manager.setRemoteDevicePassword('remote-pass');
      expect(manager.getRemoteDevicePassword()).assertEqual('remote-pass');
    });
    
    it('设置和获取连接状态', () => {
      manager.setConnectionStatus(ConnectionStatus.CONNECTING);
      expect(manager.getConnectionStatus()).assertEqual(ConnectionStatus.CONNECTING);
      
      manager.setConnectionStatus(ConnectionStatus.CONNECTED);
      expect(manager.getConnectionStatus()).assertEqual(ConnectionStatus.CONNECTED);
    });
    
    it('设置和获取剪贴板文本', () => {
      manager.setClipboardText('测试剪贴板文本');
      expect(manager.getClipboardText()).assertEqual('测试剪贴板文本');
    });
    
    it('设置和获取剪贴板文件', () => {
      const files = ['file1.txt', 'file2.txt'];
      manager.setClipboardFiles(files);
      expect(manager.getClipboardFiles().length).assertEqual(2);
      expect(manager.getClipboardFiles()[0]).assertEqual('file1.txt');
    });
    
    it('设置和获取远程控制启用状态', () => {
      manager.setRemoteControlEnabled(false);
      expect(manager.isRemoteControlEnabled()).assertFalse();
      
      manager.setRemoteControlEnabled(true);
      expect(manager.isRemoteControlEnabled()).assertTrue();
    });
    
    it('设置和获取应用状态', () => {
      manager.setCurrentState(AppState.CONNECTING);
      expect(manager.getCurrentState()).assertEqual(AppState.CONNECTING);
      
      manager.setCurrentState(AppState.CONNECTED);
      expect(manager.getCurrentState()).assertEqual(AppState.CONNECTED);
    });
    
    it('设置和获取设备信息', () => {
      const deviceInfo: DeviceInfo = {
        deviceId: 'device-001',
        deviceName: '测试设备',
        deviceType: 'HarmonyOS'
      };
      
      manager.setDeviceInfo(deviceInfo);
      const retrievedInfo = manager.getDeviceInfo();
      
      expect(retrievedInfo).not().assertNull();
      expect(retrievedInfo!.deviceId).assertEqual('device-001');
    });
    
    it('设置和获取连接配置', () => {
      const config: ConnectionConfig = {
        serverUrl: 'test.server.com',
        port: 12345,
        autoReconnect: false,
        reconnectInterval: 10000
      };
      
      manager.setConnectionConfig(config);
      const retrievedConfig = manager.getConnectionConfig();
      
      expect(retrievedConfig.serverUrl).assertEqual('test.server.com');
      expect(retrievedConfig.port).assertEqual(12345);
      expect(retrievedConfig.autoReconnect).assertFalse();
    });
    
    it('设置和获取同步设置', () => {
      const settings: SyncSettings = {
        autoUploadFiles: true,
        showFileProgress: true,
        autoSyncClipboard: true,
        syncInterval: 2000,
        syncTextOnly: false,
        showTransferNotifications: true,
        showClipboardNotifications: true
      };
      
      manager.setSyncSettings(settings);
      const retrievedSettings = manager.getSyncSettings();
      
      expect(retrievedSettings).not().assertNull();
      expect(retrievedSettings!.autoUploadFiles).assertTrue();
      expect(retrievedSettings!.syncInterval).assertEqual(2000);
    });
  });
  
  describe('AppStateKeyTest', () => {
    
    it('验证状态键枚举值', () => {
      expect(AppStateKey.USER_ID).assertEqual('userId');
      expect(AppStateKey.USER_PASSWORD).assertEqual('userPassword');
      expect(AppStateKey.CONNECTION_STATUS).assertEqual('connectionStatus');
    });
  });
  
  describe('ConnectionStatusTest', () => {
    
    it('验证连接状态枚举值', () => {
      expect(ConnectionStatus.DISCONNECTED).assertEqual('DISCONNECTED');
      expect(ConnectionStatus.CONNECTING).assertEqual('CONNECTING');
      expect(ConnectionStatus.CONNECTED).assertEqual('CONNECTED');
      expect(ConnectionStatus.ERROR).assertEqual('ERROR');
    });
  });
  
  describe('AppStateEnumTest', () => {
    
    it('验证应用状态枚举值', () => {
      expect(AppState.DISCONNECTED).assertEqual(0);
      expect(AppState.CONNECTING).assertEqual(1);
      expect(AppState.CONNECTED).assertEqual(2);
      expect(AppState.ERROR).assertEqual(3);
    });
  });
}