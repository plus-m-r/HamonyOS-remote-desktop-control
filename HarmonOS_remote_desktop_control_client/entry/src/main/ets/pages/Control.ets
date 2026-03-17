// 远程控制页面 - 实现无感文件传输和剪贴板同步
import { ServiceProvider } from '../di/ServiceProvider';
import { AppStateManager } from '../state/AppStateManager';
import prompt from '@ohos.promptAction';
import hilog from '@ohos.hilog';
import router from '@ohos.router';
import { ConnectionState } from '../models/DeviceInfo';

const TAG = 'ControlPage';
const DOMAIN = 0x0000;

@Entry
@Component
struct Control {
  @State connectionState: ConnectionState = ConnectionState.DISCONNECTED;
  @State remoteDeviceId: string = '';
  @State remoteDevicePassword: string = '';
  @State isDragging: boolean = false;
  @State screenWidth: number = 0;
  @State screenHeight: number = 0;
  @State isToolbarVisible: boolean = true;
  
  private remoteControlService = ServiceProvider.getRemoteControlService();
  private fileService = ServiceProvider.getFileService();
  private clipboardService = ServiceProvider.getClipboardService();
  
  aboutToAppear() {
    hilog.info(DOMAIN, TAG, 'Control页面开始加载');
    
    // 获取路由参数
    const params = router.getParams();
    if (params) {
      this.remoteDeviceId = params.deviceId as string || '';
      this.remoteDevicePassword = params.password as string || '';
    }
    
    // 连接服务端
    this.connectToServer();
    
    // 监听连接状态
    this.remoteControlService.setConnectionCallback((state) => {
      this.connectionState = state;
    });
    
    // 设置屏幕回调
    this.remoteControlService.setScreenCallback((image) => {
      // 处理屏幕图像数据
      this.handleScreenImage(image);
    });
  }
  
  aboutToDisappear() {
    // 断开连接
    this.remoteControlService.disconnect();
  }
  
  async connectToServer() {
    try {
      await this.remoteControlService.connect(
        () => {
          hilog.info(DOMAIN, TAG, '连接成功');
          prompt.showToast({
            message: '连接成功',
            duration: 2000
          });
          
          // 如果有远程设备ID，打开远程屏幕
          if (this.remoteDeviceId) {
            this.openRemoteScreen();
          }
        },
        (error) => {
          hilog.error(DOMAIN, TAG, '连接失败: %{public}s', error);
          prompt.showToast({
            message: `连接失败: ${error}`,
            duration: 3000
          });
        }
      );
    } catch (error) {
      hilog.error(DOMAIN, TAG, '连接异常: %{public}s', JSON.stringify(error));
      prompt.showToast({
        message: '连接异常，请检查网络',
        duration: 3000
      });
    }
  }
  
  openRemoteScreen() {
    if (this.remoteDeviceId && this.remoteDevicePassword) {
      this.remoteControlService.openRemoteScreen(
        this.remoteDeviceId,
        this.remoteDevicePassword
      );
    } else {
      prompt.showToast({
        message: '请输入设备ID和密码',
        duration: 2000
      });
    }
  }
  
  handleScreenImage(image: any) {
    // 处理屏幕图像数据
    // 这里可以更新UI显示远程屏幕
    hilog.info(DOMAIN, TAG, '收到屏幕图像: %{public}d x %{public}d', image.width, image.height);
  }
  
  handleFileDrop(event: any) {
    const files = event.dataTransfer?.files;
    if (files && files.length > 0) {
      this.uploadFiles(Array.from(files));
    }
  }
  
  async uploadFiles(files: any[]) {
    for (const file of files) {
      try {
        // 显示上传进度通知
        prompt.showToast({
          message: `正在上传: ${file.name}`,
          duration: 1500
        });
        
        // 调用FileService进行上传
        await this.fileService.uploadFile(
          file,
          (progress) => {
            // 更新进度通知
            prompt.showToast({
              message: `${file.name}: ${Math.round(progress * 100)}%`,
              duration: 1000
            });
          }
        );
        
        // 上传完成通知
        prompt.showToast({
          message: `${file.name} 上传成功`,
          duration: 2000
        });
      } catch (error) {
        hilog.error(DOMAIN, TAG, '文件上传失败: %{public}s', JSON.stringify(error));
        prompt.showToast({
          message: `${file.name} 上传失败`,
          duration: 3000
        });
      }
    }
  }
  
  showDragHint() {
    this.isDragging = true;
    // 显示拖拽提示
  }
  
  hideDragHint() {
    this.isDragging = false;
  }
  
  toggleToolbar() {
    this.isToolbarVisible = !this.isToolbarVisible;
  }
  
  @Builder
  buildRemoteScreen() {
    Column() {
      // 远程屏幕显示区域
      Stack() {
        // 屏幕内容
        Text('远程屏幕')
          .fontSize(16)
          .fontColor('#666')
          .margin({ top: '40%' })
        
        // 拖拽提示
        if (this.isDragging) {
          Stack() {
            Text('拖放文件到这里上传')
              .fontSize(18)
              .fontColor('#fff')
          }
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 122, 255, 0.5)')
          .alignItems(HorizontalAlign.Center)
          .justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#f5f5f5')
      .onDragEnter(() => this.showDragHint())
      .onDragLeave(() => this.hideDragHint())
      .onDrop((event) => {
        this.hideDragHint();
        this.handleFileDrop(event);
      })
    }
  }
  
  @Builder
  buildControlToolbar() {
    Row() {
      // 控制按钮
      Button('断开连接')
        .onClick(() => {
          this.remoteControlService.disconnect();
          router.back();
        })
      
      Button('设置')
        .onClick(() => {
          router.push({ 
            uri: 'pages/Settings' 
          });
        })
      
      Button('最小化工具栏')
        .onClick(() => this.toggleToolbar())
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#fff')
    .shadow({
      radius: 8,
      color: '#10000000',
      offsetX: 0,
      offsetY: -2
    })
  }
  
  build() {
    Column() {
      // 顶部标题
      Row() {
        Text('远程控制')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor('#182431')
        
        Text(this.connectionState === ConnectionState.CONNECTED ? '已连接' : '未连接')
          .fontSize(14)
          .fontColor(this.connectionState === ConnectionState.CONNECTED ? '#34C759' : '#FF3B30')
          .margin({ left: 12 })
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#fff')
      .shadow({
        radius: 4,
        color: '#10000000',
        offsetX: 0,
        offsetY: 2
      })
      
      // 远程屏幕区域
      this.buildRemoteScreen()
      .layoutWeight(1)
      
      // 控制工具栏
      if (this.isToolbarVisible) {
        this.buildControlToolbar()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f8f8f8')
  }
}
