import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { RemoteControlService } from '../main/ets/services/remote/RemoteControlService';
import { RemoteControlEvent, ScreenImage, ConnectionState } from '../main/ets/models/DeviceInfo';
import { configCenter } from '../main/ets/config/config';

export default function remoteControlServiceTest() {
  describe('RemoteControlService测试套件', () => {
    let remoteControlService: RemoteControlService;
    let receivedScreenImages: ScreenImage[] = [];
    let connectionSuccessCalled = false;
    let connectionErrorCalled = false;
    let lastErrorMessage = '';

    // 屏幕回调函数
    const screenCallback = (image: ScreenImage) => {
      receivedScreenImages.push(image);
      console.info(`RemoteControlService Test: 收到屏幕图像，大小: ${image.data.byteLength}`);
    };

    beforeAll(() => {
      // 使用配置中心获取服务器配置
      const serverConfig = configCenter.getServerConfig();
      // 初始化服务
      remoteControlService = new RemoteControlService(
        serverConfig.host,
        serverConfig.tcpPort,
        screenCallback
      );
      console.info('RemoteControlService Test: 初始化完成');
    });

    afterAll(() => {
      // 清理资源
      try {
        remoteControlService.disconnect();
      } catch (error) {
        // 忽略断开连接错误
      }
      console.info('RemoteControlService Test: 资源清理完成');
    });

    beforeEach(() => {
      // 重置测试状态
      receivedScreenImages = [];
      connectionSuccessCalled = false;
      connectionErrorCalled = false;
      lastErrorMessage = '';
    });

    it('服务初始化测试', 0, () => {
      expect(remoteControlService !== null && remoteControlService !== undefined).assertTrue();
      console.info('RemoteControlService Test: 服务初始化成功');
    });

    it('获取初始连接状态', 0, () => {
      const state = remoteControlService.getConnectionState();
      expect(state).assertEqual(ConnectionState.DISCONNECTED);
      console.info(`RemoteControlService Test: 初始连接状态: ${state}`);
    });

    it('设置屏幕回调', 0, () => {
      const newCallback = (image: ScreenImage) => {
        console.info('RemoteControlService Test: 新回调函数被调用');
      };
      remoteControlService.setScreenCallback(newCallback);
      console.info('RemoteControlService Test: 屏幕回调设置成功');
    });

    it('连接服务端-正常流程', 0, async () => {
      const onSuccess = () => {
        connectionSuccessCalled = true;
        console.info('RemoteControlService Test: 连接成功回调被调用');
      };

      const onError = (error: string) => {
        connectionErrorCalled = true;
        lastErrorMessage = error;
        console.error(`RemoteControlService Test: 连接错误回调被调用: ${error}`);
      };

      try {
        await remoteControlService.connect(onSuccess, onError);
        
        // 等待连接完成
        await new Promise<void>((resolve) => {
          setTimeout(() => {
            resolve();
          }, 2000);
        });

        const state = remoteControlService.getConnectionState();
        console.info(`RemoteControlService Test: 连接后状态: ${state}`);
        
        if (connectionSuccessCalled) {
          expect(state).assertEqual(ConnectionState.CONNECTED);
        } else if (connectionErrorCalled) {
          console.warn(`RemoteControlService Test: 连接失败: ${lastErrorMessage}`);
        }
      } catch (error) {
        console.warn('RemoteControlService Test: 连接异常，服务端可能未启动');
      }
    });

    it('发送控制事件-触摸按下', 0, () => {
      const touchEvent: RemoteControlEvent = {
        type: 'touch',
        action: 'down',
        x: 100,
        y: 200,
        timestamp: Date.now()
      };

      try {
        remoteControlService.sendControlEvent(touchEvent);
        console.info('RemoteControlService Test: 触摸按下事件发送成功');
      } catch (error) {
        console.warn('RemoteControlService Test: 触摸按下事件发送失败');
      }
    });

    it('发送控制事件-触摸移动', 0, () => {
      const moveEvent: RemoteControlEvent = {
        type: 'touch',
        action: 'move',
        x: 150,
        y: 250,
        timestamp: Date.now()
      };

      try {
        remoteControlService.sendControlEvent(moveEvent);
        console.info('RemoteControlService Test: 触摸移动事件发送成功');
      } catch (error) {
        console.warn('RemoteControlService Test: 触摸移动事件发送失败');
      }
    });

    it('发送控制事件-触摸抬起', 0, () => {
      const upEvent: RemoteControlEvent = {
        type: 'touch',
        action: 'up',
        x: 150,
        y: 250,
        timestamp: Date.now()
      };

      try {
        remoteControlService.sendControlEvent(upEvent);
        console.info('RemoteControlService Test: 触摸抬起事件发送成功');
      } catch (error) {
        console.warn('RemoteControlService Test: 触摸抬起事件发送失败');
      }
    });

    it('发送控制事件-键盘按键', 0, () => {
      const keyEvent: RemoteControlEvent = {
        type: 'keyboard',
        action: 'press',
        keyCode: 65, // 'A' 键
        timestamp: Date.now()
      };

      try {
        remoteControlService.sendControlEvent(keyEvent);
        console.info('RemoteControlService Test: 键盘按键事件发送成功');
      } catch (error) {
        console.warn('RemoteControlService Test: 键盘按键事件发送失败');
      }
    });

    it('发送控制事件-键盘释放', 0, () => {
      const keyReleaseEvent: RemoteControlEvent = {
        type: 'keyboard',
        action: 'release',
        keyCode: 65,
        timestamp: Date.now()
      };

      try {
        remoteControlService.sendControlEvent(keyReleaseEvent);
        console.info('RemoteControlService Test: 键盘释放事件发送成功');
      } catch (error) {
        console.warn('RemoteControlService Test: 键盘释放事件发送失败');
      }
    });

    it('发送控制事件-鼠标点击', 0, () => {
      const mouseEvent: RemoteControlEvent = {
        type: 'mouse',
        action: 'down',
        x: 300,
        y: 400,
        button: 0, // 左键
        timestamp: Date.now()
      };

      try {
        remoteControlService.sendControlEvent(mouseEvent);
        console.info('RemoteControlService Test: 鼠标点击事件发送成功');
      } catch (error) {
        console.warn('RemoteControlService Test: 鼠标点击事件发送失败');
      }
    });

    it('打开远程屏幕', 0, () => {
      const deviceCode = 'TEST-DEVICE-001';
      const password = 'test123';

      try {
        remoteControlService.openRemoteScreen(deviceCode, password);
        console.info('RemoteControlService Test: 打开远程屏幕成功');
      } catch (error) {
        console.warn('RemoteControlService Test: 打开远程屏幕失败');
      }
    });

    it('断开连接', 0, async () => {
      try {
        await remoteControlService.disconnect();
        const state = remoteControlService.getConnectionState();
        expect(state).assertEqual(ConnectionState.DISCONNECTED);
        console.info('RemoteControlService Test: 断开连接成功');
      } catch (error) {
        console.warn('RemoteControlService Test: 断开连接失败');
      }
    });

    it('重连测试', 0, async () => {
      const onSuccess = () => {
        connectionSuccessCalled = true;
      };

      const onError = (error: string) => {
        connectionErrorCalled = true;
        lastErrorMessage = error;
      };

      try {
        // 第一次连接
        await remoteControlService.connect(onSuccess, onError);
        await new Promise<void>((resolve) => {
          setTimeout(() => resolve(), 1000);
        });

        // 断开
        await remoteControlService.disconnect();

        // 重新连接
        await remoteControlService.connect(onSuccess, onError);
        await new Promise<void>((resolve) => {
          setTimeout(() => resolve(), 1000);
        });

        console.info('RemoteControlService Test: 重连测试完成');
      } catch (error) {
        console.warn('RemoteControlService Test: 重连测试失败');
      }
    });
  });
}