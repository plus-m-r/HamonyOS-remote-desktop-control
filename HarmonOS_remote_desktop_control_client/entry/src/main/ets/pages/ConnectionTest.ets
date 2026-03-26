// 连接测试页面
import { ServiceProvider } from '../di/ServiceProvider';
import { AppStateManager } from '../state/AppStateManager';
import { promptAction, router } from '@kit.ArkUI';
import hilog from '@ohos.hilog';
import { SERVER_CONFIG } from '../config/config';
import http from '@ohos.net.http';
import { BusinessError } from '@ohos.base';

const TAG = 'ConnectionTestPage';
const DOMAIN = 0x0000;

@Entry
@Component
struct ConnectionTest {
  @State connectionStatus: string = '未连接';
  @State serverInfo: string = '';
  @State testResult: string = '';
  @State isTesting: boolean = false;

  private showToast(message: string, duration: number = 2000): void {
    try {
      const uiContext = this.getUIContext();
      const promptActionInstance = uiContext.getPromptAction();
      promptActionInstance.showToast({
        message: message,
        duration: duration
      });
    } catch (error) {
      hilog.error(DOMAIN, TAG, '显示Toast失败: %{public}s', JSON.stringify(error));
    }
  }

  private routerBack(): void {
    try {
      const uiContext = this.getUIContext();
      const routerInstance = uiContext.getRouter();
      routerInstance.back();
    } catch (error) {
      hilog.error(DOMAIN, TAG, '返回失败: %{public}s', JSON.stringify(error));
    }
  }

  aboutToAppear() {
    this.updateServerInfo();
  }

  private updateServerInfo() {
    this.serverInfo = `服务器地址: ${SERVER_CONFIG.host}:${SERVER_CONFIG.tcpPort}\nHTTP端口: ${SERVER_CONFIG.httpPort}\n上下文路径: ${SERVER_CONFIG.contextPath}`;
  }

  private async testHttpConnection() {
    this.isTesting = true;
    this.testResult = '正在测试HTTP连接...';
    
    try {
      const httpRequest = http.createHttp();
      const url = `http://${SERVER_CONFIG.host}:${SERVER_CONFIG.httpPort}${SERVER_CONFIG.contextPath}`;
      
      console.info(`${TAG}: Testing HTTP connection to ${url}`);
      
      httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Content-Type': 'application/json'
        },
        connectTimeout: 5000,
        readTimeout: 5000
      }, (err: BusinessError, response: http.HttpResponse) => {
        if (err) {
          this.testResult = `HTTP连接失败: ${JSON.stringify(err)}`;
          console.error(`${TAG}: HTTP connection failed`, err);
        } else if (response.responseCode === 200) {
          this.testResult = `HTTP连接成功! 状态码: ${response.responseCode}`;
          console.info(`${TAG}: HTTP connection successful, status: ${response.responseCode}`);
        } else {
          this.testResult = `HTTP连接异常: 状态码 ${response.responseCode}`;
          console.warn(`${TAG}: HTTP connection returned status: ${response.responseCode}`);
        }
        this.isTesting = false;
      });
    } catch (error) {
      this.testResult = `HTTP连接异常: ${error}`;
      console.error(`${TAG}: HTTP connection exception`, error);
      this.isTesting = false;
    }
  }

  private async testTcpConnection() {
    this.isTesting = true;
    this.testResult = '正在测试TCP连接并获取设备信息...';
    
    try {
      // 初始化服务
      await ServiceProvider.initialize();
      
      const remoteControlService = ServiceProvider.remoteControlService;
      let deviceCodeReceived = '';
      let passwordReceived = '';
      let connectionEstablished = false;
      
      // 设置设备信息回调
      remoteControlService.setDeviceInfoCallback((deviceCode: string, password: string) => {
        deviceCodeReceived = deviceCode;
        passwordReceived = password;
        hilog.info(DOMAIN, TAG, '成功接收到设备信息 - ID: %{public}s, 密码: %{public}s', deviceCode, password);
        this.testResult = `✅ TCP连接成功！收到服务器分配的设备信息:
📱 设备ID: ${deviceCode}
🔑 密码: ${password}

✅ 设备信息已保存到应用状态`;
        
        // 保存到全局状态
        AppStateManager.setUserId(deviceCode);
        AppStateManager.setUserPassword(password);
        
        this.showToast('✅ 设备信息已获取并保存', 3000);
        
        // 3秒后自动返回主页
        setTimeout(() => {
          this.routerBack();
        }, 3000);
      });
      
      // 设置连接状态回调
      remoteControlService.setConnectionCallback((connected: boolean) => {
        this.connectionStatus = connected ? '已连接' : '已断开';
        if (connected) {
          connectionEstablished = true;
          hilog.info(DOMAIN, TAG, 'TCP连接已建立');
          this.testResult = '✅ TCP连接已建立，等待接收设备信息...';
        } else {
          hilog.info(DOMAIN, TAG, 'TCP连接已断开');
        }
      });
      
      // 尝试连接
      await remoteControlService.connect(
        () => {
          hilog.info(DOMAIN, TAG, 'TCP连接回调成功');
          this.testResult = '✅ TCP连接成功，等待接收设备信息...';
        },
        (error: string) => {
          this.testResult = `❌ TCP连接失败: ${error}`;
          console.error(`${TAG}: TCP connection failed`, error);
          this.showToast(`连接失败: ${error}`, 3000);
          this.isTesting = false;
        }
      );
      
      // 等待10秒接收设备信息
      setTimeout(() => {
        if (!deviceCodeReceived) {
          if (connectionEstablished) {
            this.testResult = '⚠️ TCP连接成功，但未收到设备信息（10秒超时）\n\n可能的原因：\n1. 服务器未发送ResCliInfo命令\n2. 服务器配置不正确\n3. 网络延迟较高\n\n建议：\n1. 检查服务器是否正常运行\n2. 确认服务器IP和端口配置正确\n3. 查看服务器日志确认是否发送了设备信息';
            hilog.warn(DOMAIN, TAG, '连接成功但未收到设备信息，可能服务器未发送ResCliInfo命令');
          } else {
            this.testResult = '❌ TCP连接失败或超时\n\n可能的原因：\n1. 服务器未启动\n2. 防火墙阻止连接\n3. IP地址或端口错误\n4. 服务器配置不正确\n\n建议：\n1. 确认服务器已启动\n2. 检查防火墙设置\n3. 验证IP地址和端口配置';
          }
          
          this.showToast('未收到设备信息，请检查服务器', 3000);
        }
        
        // 断开连接
        try {
          remoteControlService.disconnect();
          hilog.info(DOMAIN, TAG, 'TCP测试完成，已断开连接');
        } catch (error) {
          console.error(`${TAG}: TCP disconnect failed`, error);
        }
        
        this.isTesting = false;
      }, 10000);
      
    } catch (error) {
      this.testResult = `❌ TCP连接异常: ${error}`;
      console.error(`${TAG}: TCP connection exception`, error);
      this.showToast(`连接异常: ${error}`, 3000);
      this.isTesting = false;
    }
  }

  private async testFullConnection() {
    this.isTesting = true;
    this.testResult = '正在测试完整连接流程...';
    
    try {
      // 测试HTTP连接
      await this.testHttpConnection();
      // 等待HTTP测试完成
      await new Promise<void>(resolve => setTimeout(resolve, 2000));
      
      // 测试TCP连接
      await this.testTcpConnection();
      
    } catch (error) {
      this.testResult = `完整连接测试异常: ${error}`;
      console.error(`${TAG}: Full connection test exception`, error);
      this.isTesting = false;
    }
  }

  build() {
    Column() {
      // 标题
      Text('连接测试')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#0052cc')
        .margin({ top: 20, bottom: 20 })

      // 服务器信息
      Text('服务器配置信息:')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 10 })
        .width('100%')
        .textAlign(TextAlign.Start)

      Text(this.serverInfo)
        .fontSize(14)
        .fontColor(Color.Gray)
        .margin({ bottom: 30 })
        .width('100%')
        .textAlign(TextAlign.Start)
        .padding(10)
        .backgroundColor('#f8f9fa')
        .borderRadius(8)

      // 连接状态
      Text('连接状态:')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 10 })
        .width('100%')
        .textAlign(TextAlign.Start)

      Text(this.connectionStatus)
        .fontSize(18)
        .fontColor(this.connectionStatus === '已连接' ? '#28a745' : '#dc3545')
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 30 })

      // 测试结果
      Text('测试结果:')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 10 })
        .width('100%')
        .textAlign(TextAlign.Start)

      Text(this.testResult)
        .fontSize(14)
        .fontColor('#6c757d')
        .margin({ bottom: 30 })
        .width('100%')
        .textAlign(TextAlign.Start)
        .padding(10)
        .backgroundColor('#f8f9fa')
        .borderRadius(8)

      // 测试按钮
      Column() {
        Button('测试HTTP连接 (端口12345)')
          .width('90%')
          .height(50)
          .backgroundColor('#007bff')
          .fontColor(Color.White)
          .fontSize(16)
          .margin({ bottom: 15 })
          .enabled(!this.isTesting)
          .onClick(() => {
            this.testHttpConnection();
          })

        Button('测试TCP连接 (端口54321)')
          .width('90%')
          .height(50)
          .backgroundColor('#28a745')
          .fontColor(Color.White)
          .fontSize(16)
          .margin({ bottom: 15 })
          .enabled(!this.isTesting)
          .onClick(() => {
            this.testTcpConnection();
          })

        Button('测试完整连接流程')
          .width('90%')
          .height(50)
          .backgroundColor('#6f42c1')
          .fontColor(Color.White)
          .fontSize(16)
          .margin({ bottom: 15 })
          .enabled(!this.isTesting)
          .onClick(() => {
            this.testFullConnection();
          })

        if (this.isTesting) {
          LoadingProgress()
            .color('#007bff')
            .width(30)
            .height(30)
            .margin({ top: 20 })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      // 返回按钮
      Button('返回主页面')
        .width('90%')
        .height(50)
        .backgroundColor('#6c757d')
        .fontColor(Color.White)
        .fontSize(16)
        .margin({ top: 30 })
        .onClick(() => {
          this.routerBack();
        })
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#f5f5f5')
  }
}
