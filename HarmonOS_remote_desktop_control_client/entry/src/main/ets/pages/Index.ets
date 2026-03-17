// 使用HarmonyOS Design System (HDS) 风格的远程桌面控制客户端
import { ServiceProvider } from '../di/ServiceProvider';
import { AppStateManager } from '../state/AppStateManager';
import prompt from '@ohos.promptAction';
import hilog from '@ohos.hilog';
import router from '@ohos.router';

const TAG = 'IndexPage';
const DOMAIN = 0x0000;

@Entry
@Component
struct Index {
  @State userId: string = '';
  @State userPassword: string = '';
  @State deviceIdInput: string = '';
  @State devicePasswordInput: string = '';
  @State waitingForServerInfo: boolean = true;
  
  async aboutToAppear() {
    hilog.info(DOMAIN, TAG, 'Index页面开始加载');
    
    // 初始化服务
    try {
      hilog.info(DOMAIN, TAG, '开始初始化服务...');
      await ServiceProvider.initialize();
      
      // 获取用户信息（初始为空，等待服务器分配）
      this.userId = AppStateManager.getUserId();
      this.userPassword = AppStateManager.getUserPassword();
      
      hilog.info(DOMAIN, TAG, '用户信息 - ID: %{public}s, 密码: %{public}s', 
        this.userId || '未分配', 
        this.userPassword || '未分配');
      
      // 如果用户ID为空，显示等待服务器分配状态
      if (!this.userId) {
        this.waitingForServerInfo = true;
        prompt.showToast({
          message: '正在等待服务器分配用户信息...',
          duration: 3000
        });
      } else {
        this.waitingForServerInfo = false;
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, '服务初始化失败: %{public}s', JSON.stringify(error));
      prompt.showToast({
        message: '服务初始化失败，请检查网络连接',
        duration: 3000
      });
    }
  }

  // 连接到远程设备
  async connectToDevice() {
    if (!this.deviceIdInput || !this.devicePasswordInput) {
      prompt.showToast({
        message: '请输入设备ID和密码',
        duration: 2000
      });
      return;
    }

    try {
      hilog.info(DOMAIN, TAG, '正在连接到设备: %{public}s', this.deviceIdInput);
      
      prompt.showToast({
        message: '正在连接...',
        duration: 2000
      });

      // 这里应该调用实际的连接逻辑
      // await RemoteControlService.connect(this.deviceIdInput, this.devicePasswordInput);
      
      prompt.showToast({
        message: '连接成功',
        duration: 2000
      });
      
      // 跳转到控制页面
      // router.pushUrl({ url: 'pages/Control' });
      
    } catch (error) {
      hilog.error(DOMAIN, TAG, '连接失败: %{public}s', JSON.stringify(error));
      prompt.showToast({ 
        message: '连接失败，请检查设备ID和密码', 
        duration: 3000 
      });
    }
  }

  // 复制设备ID到剪贴板
  copyDeviceId() {
    // 这里应该实现复制到剪贴板的逻辑
    prompt.showToast({
      message: '设备ID已复制',
      duration: 2000
    });
  }

  // 复制密码到剪贴板
  copyPassword() {
    // 这里应该实现复制到剪贴板的逻辑
    prompt.showToast({
      message: '密码已复制',
      duration: 2000
    });
  }
  // 鸿蒙风格卡片组件
  @Builder
  buildCard(title: string, subtitle: string, isFirstCard: boolean = false) {
    Column() {
      // 卡片标题区域
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
      
      // 使用@Builder装饰器来渲染内容
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
      // 顶部标题
      Text('远程桌面控制')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 40, bottom: 20 })
        .width('100%')
        .textAlign(TextAlign.Center);
      // 两个卡片容器
      Row() {
        // 第一个卡片：显示自己的设备信息
        this.buildCard('我的设备信息', '用于他人连接到此设备', true);

        // 第二个卡片：连接其他设备
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

  // 修复：将卡片内容抽离为独立@Builder方法
  @Builder
  buildMyDeviceContent() {
    Column() {
      if (this.waitingForServerInfo) {
        // 等待服务器分配信息
        Column() {
          LoadingProgress()
            .color('#007DFF')
            .margin({ bottom: 12 });
          
          Text('正在获取设备信息...')
            .fontSize(14)
            .fontColor('#6B7280')
            .textAlign(TextAlign.Center);
        }
        .width('100%')
        .height(100)
        .justifyContent(FlexAlign.Center);
      } else {
        // 设备ID显示
        Row() {
          Text('设备ID:')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#374151')
            .layoutWeight(1);
          
          Text(this.userId || '未分配')
            .fontSize(14)
            .fontColor('#182431')
            .layoutWeight(2)
            .textAlign(TextAlign.End)
            .margin({ right: 8 });
          
          Button('复制', { type: ButtonType.Capsule })
            .fontSize(12)
            .fontColor('#007DFF')
            .backgroundColor('#F0F9FF')
            .borderColor('#007DFF')
            .borderWidth(1)
            .padding({ left: 12, right: 12, top: 4, bottom: 4 })
            .onClick(() => this.copyDeviceId());
        }
        .width('100%')
        .margin({ bottom: 12 });

        // 分割线
        Divider()
          .strokeWidth(1)
          .color('#E5E7EB')
          .margin({ bottom: 12 });

        // 密码显示
        Row() {
          Text('连接密码:')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#374151')
            .layoutWeight(1);
          
          Text(this.userPassword || '未分配')
            .fontSize(14)
            .fontColor('#182431')
            .layoutWeight(2)
            .textAlign(TextAlign.End)
            .margin({ right: 8 });
          
          Button('复制', { type: ButtonType.Capsule })
            .fontSize(12)
            .fontColor('#007DFF')
            .backgroundColor('#F0F9FF')
            .borderColor('#007DFF')
            .borderWidth(1)
            .padding({ left: 12, right: 12, top: 4, bottom: 4 })
            .onClick(() => this.copyPassword());
        }
        .width('100%');
      }
    }
    .width('100%');
  }

  // 修复：连接设备卡片内容抽离为独立@Builder方法
  @Builder
  buildConnectDeviceContent() {
    Column() {
      // 设备ID输入
      Column() {
        Text('设备ID')
          .fontSize(12)
          .fontColor('#6B7280')
          .margin({ bottom: 4 })
          .alignSelf(ItemAlign.Start);
        
        TextInput({ placeholder: '请输入设备ID', text: this.deviceIdInput })
          .placeholderColor('#9CA3AF')
          .placeholderFont({ size: 14 })
          .fontSize(14)
          .fontColor('#182431')
          .backgroundColor('#F9FAFB')
          .borderRadius(8)
          .border({ width: 1, color: '#E5E7EB' })
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .onChange((value: string) => {
            this.deviceIdInput = value;
          });
      }
      .width('100%')
      .margin({ bottom: 16 });

      // 密码输入
      Column() {
        Text('连接密码')
          .fontSize(12)
          .fontColor('#6B7280')
          .margin({ bottom: 4 })
          .alignSelf(ItemAlign.Start);
        
        TextInput({ 
          placeholder: '请输入连接密码', 
          text: this.devicePasswordInput 
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
            this.devicePasswordInput = value;
          });
      }
      .width('100%')
      .margin({ bottom: 20 });

      // 连接按钮
      Button('连接设备', { type: ButtonType.Capsule })
        .fontSize(16)
        .fontColor(Color.White)
        .backgroundColor('#007DFF')
        .width('100%')
        .height(44)
        .onClick(() => this.connectToDevice());
    }
    .width('100%');
  }
}