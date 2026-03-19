// 使用HarmonyOS Design System (HDS) 风格的远程桌面控制客户端
import { ServiceProvider } from '../di/ServiceProvider';
import { AppStateManager } from '../state/AppStateManager';
import prompt from '@ohos.promptAction';
import hilog from '@ohos.hilog';
import router from '@ohos.router';
import pasteboard from '@ohos.pasteboard';

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
  @State remoteControlEnabled: boolean = true;
  @State isConnecting: boolean = false;
  
  async aboutToAppear() {
    hilog.info(DOMAIN, TAG, 'Index页面开始加载');
    
    try {
      // 获取远程控制服务
      const remoteControlService = ServiceProvider.remoteControlService;
      
      // 设置设备信息回调，用于接收服务器分配的设备ID和密码
      remoteControlService.setDeviceInfoCallback((deviceCode: string, password: string) => {
        hilog.info(DOMAIN, TAG, '收到服务器分配的设备信息 - ID: %{public}s, 密码: %{public}s', deviceCode, password);
        
        // 保存到全局状态
        AppStateManager.setUserId(deviceCode);
        AppStateManager.setUserPassword(password);
        
        // 更新UI状态
        this.userId = deviceCode;
        this.userPassword = password;
        this.waitingForServerInfo = false;
        
        prompt.showToast({
          message: '设备信息已获取',
          duration: 2000
        });
      });
      
      // 获取用户信息
      this.userId = AppStateManager.getUserId();
      this.userPassword = AppStateManager.getUserPassword();
      
      // 获取远程控制权限状态
      this.remoteControlEnabled = AppStateManager.isRemoteControlEnabled();
      
      hilog.info(DOMAIN, TAG, '用户信息 - ID: %{public}s, 密码: %{public}s, 远程控制权限: %{public}s', 
        this.userId || '未分配', 
        this.userPassword || '未分配',
        this.remoteControlEnabled ? '已启用' : '已禁用');
      
      // 如果用户ID为空，显示等待服务器分配状态
      if (!this.userId) {
        this.waitingForServerInfo = true;
        prompt.showToast({
          message: '正在等待服务器分配设备信息...',
          duration: 3000
        });
      } else {
        this.waitingForServerInfo = false;
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, '页面初始化失败: %{public}s', JSON.stringify(error));
      prompt.showToast({
        message: '页面初始化失败，请检查网络连接',
        duration: 3000
      });
    }
  }

  // 页面销毁时不再断开连接，保持应用级连接
  aboutToDisappear(): void {
    hilog.info(DOMAIN, TAG, 'Index页面销毁');
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

    // 防重复点击
    if (this.isConnecting) {
      return;
    }

    try {
      this.isConnecting = true;
      hilog.info(DOMAIN, TAG, '正在验证设备: %{public}s', this.deviceIdInput);
      
      prompt.showToast({
        message: '正在验证设备信息...',
        duration: 2000
      });

      // 验证设备ID和密码
      const remoteControlService = ServiceProvider.remoteControlService;
      const validationResult = await remoteControlService.validateDevice(this.deviceIdInput, this.devicePasswordInput);
      
      if (!validationResult.valid) {
        hilog.error(DOMAIN, TAG, '设备验证失败: %{public}s', validationResult.message);
        prompt.showToast({ 
          message: validationResult.message,
          duration: 3000 
        });
        return;
      }

      // 验证成功，设置设备信息
      remoteControlService.setDeviceInfo(this.deviceIdInput, this.devicePasswordInput);
      
      // 跳转到控制页面
      router.pushUrl({ 
        url: 'pages/Control',
        params: {
          deviceId: this.deviceIdInput,
          password: this.devicePasswordInput
        }
      });
      
    } catch (error) {
      hilog.error(DOMAIN, TAG, '连接失败: %{public}s', JSON.stringify(error));
      prompt.showToast({ 
        message: '连接失败，请检查设备ID和密码', 
        duration: 3000 
      });
    } finally {
      this.isConnecting = false;
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

  // 一键复制设备ID和连接密码
  copyAllDeviceInfo() {
    if (!this.userId || !this.userPassword) {
      prompt.showToast({
        message: '设备信息未获取，无法复制',
        duration: 2000
      });
      return;
    }

    try {
      // 创建剪贴板数据
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, `设备ID: ${this.userId}\n连接密码: ${this.userPassword}`);
      
      // 获取系统剪贴板
      const systemPasteboard = pasteboard.getSystemPasteboard();
      
      // 写入剪贴板
      systemPasteboard.setData(pasteData, (err) => {
        if (err) {
          hilog.error(DOMAIN, TAG, '复制到剪贴板失败: %{public}s', JSON.stringify(err));
          prompt.showToast({
            message: '复制失败，请重试',
            duration: 2000
          });
        } else {
          hilog.info(DOMAIN, TAG, '设备信息已复制到剪贴板 - ID: %{public}s, 密码: %{public}s', this.userId, this.userPassword);
          prompt.showToast({
            message: '设备ID和密码已复制到剪贴板',
            duration: 2000
          });
        }
      });
    } catch (error) {
      hilog.error(DOMAIN, TAG, '复制设备信息失败: %{public}s', JSON.stringify(error));
      prompt.showToast({
        message: '复制失败，请检查权限',
        duration: 2000
      });
    }
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
            .padding({ top: 6, bottom: 6 });
        }
        .width('100%')
        .margin({ bottom: 13 });

        // 分割线
        Divider()
          .strokeWidth(1)
          .color('#E5E7EB')
          .margin({ bottom: 12 });

        // 密码显示 (始终隐藏)
        Row() {
          Text('连接密码:')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#374151')
            .layoutWeight(1);
          
          Text(this.userPassword ? '••••••••' : '未分配')
            .fontSize(14)
            .fontColor('#182431')
            .layoutWeight(2)
            .textAlign(TextAlign.End)
            .padding({ top: 6, bottom: 6 });
        }
        .width('100%')
        .margin({ bottom: 13 });

        // 分割线
        Divider()
          .strokeWidth(1)
          .color('#E5E7EB')
          .margin({ bottom: 12 });

        // 远程控制权限开关
        Row() {
          Text('远程控制权限:')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#374151')
            .layoutWeight(1);
          
          Toggle({ type: ToggleType.Switch, isOn: this.remoteControlEnabled })
            .selectedColor('#007DFF')
            .switchPointColor('#FFFFFF')
            .onChange((isOn: boolean) => {
              this.onRemoteControlToggleChange(isOn);
            })
            .width(45)  // 设置固定宽度，缩小开关大小
            .margin({ left: 8 });  // 添加左边距，避免太靠近文本
        }
        .width('100%')
        .margin({ bottom: 13 });

        // 分割线
        Divider()
          .strokeWidth(1)
          .color('#E5E7EB')
          .margin({ bottom: 12 });

        // 一键复制按钮 - 使用与连接设备按钮相同的样式
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

  // 远程控制权限开关变化处理
  onRemoteControlToggleChange(isOn: boolean): void {
    hilog.info(DOMAIN, TAG, '远程控制权限开关状态变化: %{public}s', isOn ? '开启' : '关闭');
    
    // 更新本地状态
    this.remoteControlEnabled = isOn;
    
    // 保存到全局状态管理器
    AppStateManager.setRemoteControlEnabled(isOn);
    
    // 显示提示
    prompt.showToast({
      message: isOn ? '远程控制权限已开启' : '远程控制权限已关闭',
      duration: 2000
    });
    
    // 通知远程控制服务权限状态变化
    try {
      ServiceProvider.remoteControlService.setRemoteControlPermission(isOn);
      hilog.info(DOMAIN, TAG, '已通知远程控制服务权限状态: %{public}s', isOn ? '已开启' : '已关闭');
    } catch (error) {
      hilog.error(DOMAIN, TAG, '通知远程控制服务权限状态失败: %{public}s', JSON.stringify(error));
    }
  }
}