import { describe, it, expect, beforeAll } from '@ohos/hypium';
import { 
  ServiceState, 
  DeviceCredentials, 
  DeviceValidationResult 
} from '../../../../main/ets/services/interfaces/IService';

export default function ServicesInterfacesTest() {
  
  describe('ServiceStateTest', () => {
    
    it('验证服务状态枚举值', () => {
      expect(ServiceState.UNINITIALIZED).assertEqual('uninitialized');
      expect(ServiceState.INITIALIZING).assertEqual('initializing');
      expect(ServiceState.READY).assertEqual('ready');
      expect(ServiceState.ERROR).assertEqual('error');
      expect(ServiceState.DISPOSED).assertEqual('disposed');
    });
    
    it('测试服务状态转换', () => {
      let state: ServiceState = ServiceState.UNINITIALIZED;
      expect(state).assertEqual('uninitialized');
      
      state = ServiceState.INITIALIZING;
      expect(state).assertEqual('initializing');
      
      state = ServiceState.READY;
      expect(state).assertEqual('ready');
      
      state = ServiceState.ERROR;
      expect(state).assertEqual('error');
      
      state = ServiceState.DISPOSED;
      expect(state).assertEqual('disposed');
    });
  });
  
  describe('DeviceCredentialsTest', () => {
    
    it('测试DeviceCredentials接口', () => {
      const credentials: DeviceCredentials = {
        deviceCode: 'TEST-DEVICE-001',
        password: 'password123'
      };
      
      expect(credentials.deviceCode).assertEqual('TEST-DEVICE-001');
      expect(credentials.password).assertEqual('password123');
    });
  });
  
  describe('DeviceValidationResultTest', () => {
    
    it('测试成功验证结果', () => {
      const result: DeviceValidationResult = {
        valid: true,
        message: '验证成功'
      };
      
      expect(result.valid).assertTrue();
      expect(result.message).assertEqual('验证成功');
    });
    
    it('测试失败验证结果', () => {
      const result: DeviceValidationResult = {
        valid: false,
        message: '验证失败：密码错误'
      };
      
      expect(result.valid).assertFalse();
      expect(result.message).assertEqual('验证失败：密码错误');
    });
  });
}