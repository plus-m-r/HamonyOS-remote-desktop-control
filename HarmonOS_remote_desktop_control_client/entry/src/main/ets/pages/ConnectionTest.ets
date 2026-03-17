// 连接测试页面
import { ServiceProvider } from '../di/ServiceProvider';
import { AppStateManager } from '../state/AppStateManager';
import prompt from '@ohos.promptAction';
import Logger from '@ohos.hilog';
import { SERVER_CONFIG } from '../config/config';
import http from '@ohos.net.http';
import router from '@ohos.router';
import { BusinessError } from '@ohos.base';

const TAG = 'ConnectionTestPage';

@Entry
@Component
struct ConnectionTest {
  @State connectionStatus: string = '未连接';
  @State serverInfo: string = '';
  @State testResult: string = '';
  @State isTesting: boolean = false;

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
    this.testResult = '正在测试TCP连接...';
    
    try {
      // 初始化服务
      await ServiceProvider.initialize();
      
      const onSuccess = () => {
        this.testResult = 'TCP连接成功!';
        this.connectionStatus = '已连接';
        console.info(`${TAG}: TCP connection successful`);
        this.isTesting = false;
        
        // 断开连接
        setTimeout((): void => {
          ServiceProvider.remoteControlService.disconnect();
          this.connectionStatus = '已断开';
        }, 3000);
      };
      
      const onError = (error: string) => {
        this.testResult = `TCP连接失败: ${error}`;
        console.error(`${TAG}: TCP connection failed`, error);
        this.isTesting = false;
      };
      
      // 尝试连接
      await ServiceProvider.remoteControlService.connect(onSuccess, onError);
      
    } catch (error) {
      this.testResult = `TCP连接异常: ${error}`;
      console.error(`${TAG}: TCP connection exception`, error);
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
          router.back();
        })
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#f5f5f5')
  }
}