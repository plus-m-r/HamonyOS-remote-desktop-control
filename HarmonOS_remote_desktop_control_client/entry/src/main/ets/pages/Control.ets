// 远程控制页面 - 实现无感文件传输和剪贴板同步
import { ServiceProvider } from '../di/ServiceProvider';
import { AppStateManager } from '../state/AppStateManager';
import prompt from '@ohos.promptAction';
import hilog from '@ohos.hilog';
import router from '@ohos.router';
import { AppState } from '../state/AppStateManager';
import { ScreenImage } from '../models/DeviceInfo';
import { UploadFile } from '../services/file/FileService';

const TAG = 'ControlPage';
const DOMAIN = 0x0000;
// 文件接口
interface UploadableFile {
  name: string;
  size: number;
  type: string;
  path?: string;
  uri?: string;
}
@Entry
@Component
struct Control {
  @State connectionState: AppState = AppState.DISCONNECTED;
  @State remoteDeviceId: string = '';
  @State remoteDevicePassword: string = '';
  @State isDragging: boolean = false;
  @State screenWidth: number = 0;
  @State screenHeight: number = 0;
  @State isToolbarVisible: boolean = true;

  private remoteControlService = ServiceProvider.remoteControlService;
  private fileService = ServiceProvider.fileService;
  private clipboardService = ServiceProvider.clipboardService;
  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, 'Control页面开始加载');

    // 获取路由参数
    interface RouterParams {
      deviceId?: string;
      password?: string;
    }
    const params = router.getParams() as RouterParams;
    if (params) {
      this.remoteDeviceId = params.deviceId || '';
      this.remoteDevicePassword = params.password || '';
    }

    // 连接服务端
    this.connectToServer();
    // 监听连接状态
    this.remoteControlService.setConnectionCallback((state: boolean) => {
      this.connectionState = state ? AppState.CONNECTED : AppState.DISCONNECTED;
    });

    // 设置屏幕回调
    this.remoteControlService.setScreenCallback((image: ScreenImage) => {
      // 处理屏幕图像数据
      this.handleScreenImage(image);
    });
  }
  aboutToDisappear(): void {
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
  openRemoteScreen(): void {
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
  handleScreenImage(image: ScreenImage): void {
    // 处理屏幕图像数据
    // 这里可以更新UI显示远程屏幕
    hilog.info(DOMAIN, TAG, '收到屏幕图像: %{public}d x %{public}d', image.width, image.height);
  }
  // 处理文件拖拽事件
  // 注意：ArkTS的DragEvent没有dataTransfer属性，不支持文件拖拽
  // 这里暂时留空，后续可以通过其他方式实现文件上传
  handleFileDrop(): void {
    console.log('File drop functionality is not supported in ArkTS drag events');
    // 可以在这里添加其他文件选择方式，如文件选择器
    prompt.showToast({
      message: '文件拖拽功能暂不支持，请使用文件选择器上传',
      duration: 3000
    });
  }

  async uploadFiles(files: UploadableFile[]) {
    for (const file of files) {
      try {
        // 显示上传进度通知
        prompt.showToast({
          message: `正在上传: ${file.name}`,
          duration: 1500
        });

        // 将UploadableFile转换为UploadFile
        const uploadFile: UploadFile = {
          path: file.path,
          uri: file.uri
        };

        // 调用FileService进行上传
        await this.fileService.uploadFile(
          uploadFile,
          (progress: number) => {
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
  showDragHint(): void {
    this.isDragging = true;
    // 显示拖拽提示
  }
  hideDragHint(): void {
    this.isDragging = false;
  }
  toggleToolbar(): void {
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
          .alignContent(Alignment.Center)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#f5f5f5')
      .onDragEnter(() => this.showDragHint())
      .onDragLeave(() => this.hideDragHint())
      .onDrop((event?: DragEvent, extraParams?: string) => {
        this.hideDragHint();
        this.handleFileDrop();
      })
    }
    .layoutWeight(1)  // 应用layoutWeight属性
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
          router.pushUrl({ 
            url: 'pages/Settings' 
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
        Text(this.connectionState === AppState.CONNECTED ? '已连接' : '未连接')
          .fontSize(14)
          .fontColor(this.connectionState === AppState.CONNECTED ? '#34C759' : '#FF3B30')
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
