// Index.ets - 解耦后的首页，通过 ViewModel 管理业务逻辑
// 遵循 MVVM 架构，页面只负责 UI 渲染和事件转发

import { IndexViewModel, IndexPageState } from '../viewmodel/IndexViewModel';
import { ServiceProvider } from '../di/ServiceProvider';
import { promptAction, router } from '@kit.ArkUI';
import hilog from '@ohos.hilog';

interface RouterParams {
  deviceId?: string;
  password?: string;
}

const TAG = 'IndexPage';
const DOMAIN = 0x0000;

@Entry
@Component
struct Index {
  // ViewModel 实例，通过依赖注入获取
  private viewModel!: IndexViewModel;
  
  // UI 状态，从 ViewModel 同步
  @State private state: IndexPageState = {
    userId: '',
    userPassword: '',
    deviceIdInput: '',
    devicePasswordInput: '',
    waitingForServerInfo: true,
    remoteControlEnabled: true,
    isConnecting: false,
    errorMessage: '',
    serverIpInput: ''  // ⭐ 服务器IP输入
  };

  constructor() {
    super();
  }

  aboutToAppear() {
    hilog.info(DOMAIN, TAG, 'Index页面开始加载');
    this.initializeViewModel();
  }

  private async initializeViewModel(): Promise<void> {
    try {
      // 初始化 ServiceProvider
      await ServiceProvider.initialize();
      
      // 通过 ServiceProvider 获取依赖，注入到 ViewModel
      const remoteControlService = ServiceProvider.remoteControlService;
      const appStateManager = ServiceProvider.appStateManager;
      const clipboardService = ServiceProvider.clipboardService;
      
      this.viewModel = new IndexViewModel({
        remoteControlService,
        appStateManager,
        clipboardService
      });

      // 订阅 ViewModel 状态变化
      this.viewModel.subscribe((newState: IndexPageState) => {
        hilog.info(DOMAIN, TAG, '收到状态更新 - userId: %{public}s, waitingForServerInfo: %{public}s', 
          newState.userId, newState.waitingForServerInfo);
        
        // 使用展开运算符触发 @State 更新
        this.state = {
          userId: newState.userId,
          userPassword: newState.userPassword,
          deviceIdInput: newState.deviceIdInput,
          devicePasswordInput: newState.devicePasswordInput,
          waitingForServerInfo: newState.waitingForServerInfo,
          remoteControlEnabled: newState.remoteControlEnabled,
          isConnecting: newState.isConnecting,
          errorMessage: newState.errorMessage,
          serverIpInput: newState.serverIpInput  // ⭐
        };
        
        hilog.info(DOMAIN, TAG, 'UI 状态已更新');
      });

      // 设置导航回调
      this.viewModel.setNavigationCallback((url: string, params?: RouterParams) => {
        this.routerPushUrl(url, params);
      });

      // 设置 Toast 回调
      this.viewModel.setToastCallback((message: string, duration?: number) => {
        this.showToast(message, duration);
      });

      // 初始化 ViewModel
      this.viewModel.initialize();
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      const errorStack = error instanceof Error ? error.stack : '';
      hilog.error(DOMAIN, TAG, '初始化ViewModel失败: %{public}s, stack: %{public}s', errorMessage, errorStack);
    }
  }

  aboutToDisappear(): void {
    hilog.info(DOMAIN, TAG, 'Index页面销毁');
    if (this.viewModel) {
      this.viewModel.dispose();
    }
  }

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

  private routerPushUrl(url: string, params?: RouterParams): void {
    try {
      const uiContext = this.getUIContext();
      const routerInstance = uiContext.getRouter();
      routerInstance.pushUrl({
        url: url,
        params: params
      }).catch((error: Error) => {
        hilog.error(DOMAIN, TAG, '跳转失败: %{public}s', JSON.stringify(error));
      });
    } catch (error) {
      hilog.error(DOMAIN, TAG, '跳转失败: %{public}s', JSON.stringify(error));
    }
  }

  // 连接到远程设备 - 委托给 ViewModel
  private async connectToDevice(): Promise<void> {
    await this.viewModel.connectToDevice();
  }

  // 复制设备ID - 委托给 ViewModel
  private copyDeviceId(): void {
    this.viewModel.copyDeviceId();
  }

  // 复制密码 - 委托给 ViewModel
  private copyPassword(): void {
    this.viewModel.copyPassword();
  }

  // 一键复制设备信息 - 委托给 ViewModel
  private copyAllDeviceInfo(): void {
    this.viewModel.copyAllDeviceInfo();
  }

  // ⭐ 更新服务器IP
  private updateServerIp(ip: string): void {
    this.viewModel.updateServerIp(ip);
  }

  // ⭐ 重新连接
  private async reconnectWithNewServerIp(): Promise<void> {
    await this.viewModel.reconnectWithNewServerIp();
  }

  // 远程控制权限开关变化 - 委托给 ViewModel
  private onRemoteControlToggleChange(isOn: boolean): void {
    this.viewModel.setRemoteControlEnabled(isOn);
  }

  // 设备ID输入变化 - 委托给 ViewModel
  private onDeviceIdChange(value: string): void {
    this.viewModel.setDeviceIdInput(value);
  }

  // 密码输入变化 - 委托给 ViewModel
  private onPasswordChange(value: string): void {
    this.viewModel.setPasswordInput(value);
  }

  // 鸿蒙风格卡片组件
  @Builder
  buildCard(title: string, subtitle: string, isFirstCard: boolean = false) {
    Column() {
      if (title) {
        Column() {
          Text(title)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#182431')
            .margin({ bottom: 4 });

          if (subtitle) {
            Text(subtitle)
              .fontSize(12)
              .fontColor('#6B7280');
          }
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ bottom: 16 });
      }

      if (title === '我的设备信息') {
        this.buildMyDeviceContent();
      } else if (title === '连接其他设备') {
        this.buildConnectDeviceContent();
      }
    }
    .backgroundColor(Color.White)
    .borderRadius(12)
    .padding(16)
    .shadow({
      radius: 8,
      color: '#10000000',
      offsetX: 0,
      offsetY: 2
    })
    .width('100%')
    .margin(isFirstCard ? { right: 12 } : { left: 12 })
    .layoutWeight(1);
  }

  build() {
    Column() {
      Text('远程桌面控制')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 40, bottom: 20 })
        .width('100%')
        .textAlign(TextAlign.Center);

      Row() {
        this.buildCard('我的设备信息', '用于他人连接到此设备', true);
        this.buildCard('连接其他设备', '输入设备信息进行连接', false);
      }
      .width('100%')
      .height('100%')
      .padding(20)
      .justifyContent(FlexAlign.Center);
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5');
  }

  @Builder
  buildMyDeviceContent() {
    Column() {
      if (this.state.waitingForServerInfo) {
        Column() {
          LoadingProgress()
            .color('#007DFF')
            .margin({ bottom: 12 });

          Text('正在获取设备信息...')
            .fontSize(14)
            .fontColor('#6B7280')
            .textAlign(TextAlign.Center);
          
          // ⭐ 新增：服务器 IP 输入框
          this.buildServerIpInput();
        }
        .width('100%')
        .height(100)
        .justifyContent(FlexAlign.Center);
      } else {
        Row() {
          Text('设备ID:')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#374151')
            .layoutWeight(1);

          Text(this.state.userId || '未分配')
            .fontSize(14)
            .fontColor('#182431')
            .layoutWeight(2)
            .textAlign(TextAlign.End)
            .padding({ top: 6, bottom: 6 });
        }
        .width('100%')
        .margin({ bottom: 13 });

        Divider()
          .strokeWidth(1)
          .color('#E5E7EB')
          .margin({ bottom: 12 });

        Row() {
          Text('连接密码:')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#374151')
            .layoutWeight(1);

          Text(this.state.userPassword ? '••••••••' : '未分配')
            .fontSize(14)
            .fontColor('#182431')
            .layoutWeight(2)
            .textAlign(TextAlign.End)
            .padding({ top: 6, bottom: 6 });
        }
        .width('100%')
        .margin({ bottom: 13 });

        Divider()
          .strokeWidth(1)
          .color('#E5E7EB')
          .margin({ bottom: 12 });

        Row() {
          Text('远程控制权限:')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#374151')
            .layoutWeight(1);

          Toggle({ type: ToggleType.Switch, isOn: this.state.remoteControlEnabled })
            .selectedColor('#007DFF')
            .switchPointColor('#FFFFFF')
            .onChange((isOn: boolean) => {
              this.onRemoteControlToggleChange(isOn);
            })
            .width(45)
            .margin({ left: 8 });
        }
        .width('100%')
        .margin({ bottom: 13 });

        Divider()
          .strokeWidth(1)
          .color('#E5E7EB')
          .margin({ bottom: 12 });

        Button('一键复制', { type: ButtonType.Capsule })
          .fontSize(16)
          .fontColor(Color.White)
          .backgroundColor('#007DFF')
          .width('100%')
          .height(44)
          .margin({ top: -1 })
          .onClick(() => this.copyAllDeviceInfo());
      }
    }
    .width('100%');
  }

  @Builder
  buildConnectDeviceContent() {
    Column() {
      Column() {
        Text('设备ID')
          .fontSize(12)
          .fontColor('#6B7280')
          .margin({ bottom: 4 })
          .alignSelf(ItemAlign.Start);

        TextInput({ placeholder: '请输入设备ID', text: this.state.deviceIdInput })
          .placeholderColor('#9CA3AF')
          .placeholderFont({ size: 14 })
          .fontSize(14)
          .fontColor('#182431')
          .backgroundColor('#F9FAFB')
          .borderRadius(8)
          .border({ width: 1, color: '#E5E7EB' })
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .onChange((value: string) => {
            this.onDeviceIdChange(value);
          });
      }
      .width('100%')
      .margin({ bottom: 16 });

      Column() {
        Text('连接密码')
          .fontSize(12)
          .fontColor('#6B7280')
          .margin({ bottom: 4 })
          .alignSelf(ItemAlign.Start);

        TextInput({
          placeholder: '请输入连接密码',
          text: this.state.devicePasswordInput
        })
          .type(InputType.Password)
          .placeholderColor('#9CA3AF')
          .placeholderFont({ size: 14 })
          .fontSize(14)
          .fontColor('#182431')
          .backgroundColor('#F9FAFB')
          .borderRadius(8)
          .border({ width: 1, color: '#E5E7EB' })
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .onChange((value: string) => {
            this.onPasswordChange(value);
          });
      }
      .width('100%')
      .margin({ bottom: 20 });

      Button('连接设备', { type: ButtonType.Capsule })
        .fontSize(16)
        .fontColor(Color.White)
        .backgroundColor('#007DFF')
        .width('100%')
        .height(44)
        .enabled(!this.state.isConnecting)
        .onClick(() => this.connectToDevice());
    }
    .width('100%');
  }

  // ⭐⭐⭐ 新增：服务器IP输入框
  @Builder
  buildServerIpInput() {
    Column() {
      Text('服务器IP地址')
        .fontSize(12)
        .fontColor('#6B7280')
        .margin({ top: 16, bottom: 4 })
        .alignSelf(ItemAlign.Start);

      Row() {
        TextInput({
          placeholder: '例如: 192.168.1.100',
          text: this.state.serverIpInput
        })
          .type(InputType.Normal)
          .placeholderColor('#9CA3AF')
          .placeholderFont({ size: 12 })
          .fontSize(12)
          .fontColor('#182431')
          .backgroundColor('#F9FAFB')
          .borderRadius(6)
          .border({ width: 1, color: '#E5E7EB' })
          .padding({ left: 10, right: 10, top: 8, bottom: 8 })
          .layoutWeight(1)
          .onChange((value: string) => {
            this.updateServerIp(value);
          });

        Button('重新连接')
          .fontSize(12)
          .fontColor(Color.White)
          .backgroundColor('#10B981')
          .borderRadius(6)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .margin({ left: 8 })
          .onClick(() => this.reconnectWithNewServerIp());
      }
      .width('100%');
    }
    .width('100%')
    .padding({ left: 16, right: 16 });
  }
}
