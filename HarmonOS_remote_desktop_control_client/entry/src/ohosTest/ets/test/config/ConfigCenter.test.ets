import { describe, it, expect, beforeAll, beforeEach } from '@ohos/hypium';
import { ConfigCenter, configCenter } from '../../../../main/ets/config/ConfigCenter';

export default function ConfigCenterTest() {
  
  describe('ConfigCenterTest', 0, () => {
    
    it('获取ConfigCenter单例', () => {
      const instance1 = ConfigCenter.getInstance();
      const instance2 = ConfigCenter.getInstance();
      expect(instance1).not().assertNull();
      expect(instance1).assertEqual(instance2);
    });
    
    it('获取环境配置', () => {
      const instance = ConfigCenter.getInstance();
      const env = instance.getEnvironment();
      expect(env).not().assertNull();
    });
    
    it('设置环境配置', () => {
      const instance = ConfigCenter.getInstance();
      instance.setEnvironment('testing');
      expect(instance.getEnvironment()).assertEqual('testing');
    });
    
    it('获取完整配置', () => {
      const instance = ConfigCenter.getInstance();
      const config = instance.getConfig();
      expect(config).not().assertNull();
      expect(config.server).not().assertNull();
      expect(config.network).not().assertNull();
    });
    
    it('获取服务器配置', () => {
      const instance = ConfigCenter.getInstance();
      const serverConfig = instance.getServerConfig();
      expect(serverConfig).not().assertNull();
      expect(serverConfig.host).not().assertNull();
      expect(serverConfig.tcpPort).not().assertNull();
      expect(serverConfig.httpPort).not().assertNull();
    });
    
    it('获取网络配置', () => {
      const instance = ConfigCenter.getInstance();
      const networkConfig = instance.getNetworkConfig();
      expect(networkConfig).not().assertNull();
      expect(networkConfig.connectTimeout).not().assertNull();
      expect(networkConfig.readTimeout).not().assertNull();
    });
    
    it('获取屏幕捕获配置', () => {
      const instance = ConfigCenter.getInstance();
      const captureConfig = instance.getCaptureConfig();
      expect(captureConfig).not().assertNull();
      expect(captureConfig.maxFps).not().assertNull();
      expect(captureConfig.quality).not().assertNull();
    });
    
    it('获取文件传输配置', () => {
      const instance = ConfigCenter.getInstance();
      const fileConfig = instance.getFileTransferConfig();
      expect(fileConfig).not().assertNull();
      expect(fileConfig.chunkSize).not().assertNull();
      expect(fileConfig.maxConcurrentUploads).not().assertNull();
    });
    
    it('获取剪贴板配置', () => {
      const instance = ConfigCenter.getInstance();
      const clipboardConfig = instance.getClipboardConfig();
      expect(clipboardConfig).not().assertNull();
      expect(clipboardConfig.maxTextLength).not().assertNull();
      expect(clipboardConfig.autoSync).not().assertNull();
    });
    
    it('获取UI配置', () => {
      const instance = ConfigCenter.getInstance();
      const uiConfig = instance.getUIConfig();
      expect(uiConfig).not().assertNull();
      expect(uiConfig.defaultLanguage).not().assertNull();
      expect(uiConfig.theme).not().assertNull();
    });
    
    it('获取日志配置', () => {
      const instance = ConfigCenter.getInstance();
      const logConfig = instance.getLogConfig();
      expect(logConfig).not().assertNull();
      expect(logConfig.level).not().assertNull();
      expect(logConfig.enableConsole).not().assertNull();
    });
    
    it('获取Worker配置', () => {
      const instance = ConfigCenter.getInstance();
      const workerConfig = instance.getWorkerConfig();
      expect(workerConfig).not().assertNull();
      expect(workerConfig.captureWorkerCount).not().assertNull();
      expect(workerConfig.protocolWorkerCount).not().assertNull();
    });
    
    it('获取HTTP URL', () => {
      const instance = ConfigCenter.getInstance();
      const url = instance.getHttpUrl('/api/test');
      expect(url).not().assertNull();
      expect(url.length).assertLarger(0);
    });
    
    it('获取TCP地址', () => {
      const instance = ConfigCenter.getInstance();
      const tcpAddress = instance.getTcpAddress();
      expect(tcpAddress).not().assertNull();
      expect(tcpAddress.host).not().assertNull();
      expect(tcpAddress.port).not().assertNull();
    });
    
    it('测试全局configCenter实例', () => {
      expect(configCenter).not().assertNull();
      const serverConfig = configCenter.getServerConfig();
      expect(serverConfig).not().assertNull();
    });
    
    it('测试配置不可变性', () => {
      const instance = ConfigCenter.getInstance();
      const config1 = instance.getConfig();
      const config2 = instance.getConfig();
      
      config1.server.host = 'modified.test';
      
      const config3 = instance.getConfig();
      expect(config3.server.host).not().assertEqual('modified.test');
    });
    
    it('测试环境切换', () => {
      const instance = ConfigCenter.getInstance();
      
      instance.setEnvironment('development');
      const devConfig = instance.getConfig();
      
      instance.setEnvironment('testing');
      const testConfig = instance.getConfig();
      
      expect(devConfig.server.host).not().assertEqual(testConfig.server.host);
    });
  });
}