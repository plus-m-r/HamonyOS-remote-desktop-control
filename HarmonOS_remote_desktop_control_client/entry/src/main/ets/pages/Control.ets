// 远程控制页面 - 实现无感文件传输和剪贴板同步
import { ServiceProvider } from '../di/ServiceProvider';
import { AppStateManager } from '../state/AppStateManager';
import { promptAction, router, GestureGroup, GestureMode, PanGesture, PinchGesture, GestureEvent, ImageFit, Alignment, DragEvent } from '@kit.ArkUI';
import hilog from '@ohos.hilog';
import { AppState } from '../state/AppStateManager';
import { ScreenImage, ConnectionState } from '../models/DeviceInfo';
import { UploadFile } from '../services/file/FileService';
import { image } from '@kit.ImageKit';

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

// 触摸点接口
interface TouchPoint {
  x: number;
  y: number;
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
  @State lastTouchX: number = 0;
  @State lastTouchY: number = 0;
  @State screenImage: image.PixelMap | null = null;
  @State scale: number = 1.0;
  @State lastScale: number = 1.0;

  private remoteControlService = ServiceProvider.remoteControlService;
  private fileService = ServiceProvider.fileService;
  private clipboardService = ServiceProvider.clipboardService;

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
      // 关闭远程屏幕控制，但保持与服务器的连接
      this.remoteControlService.closeRemoteScreen();
      
      const uiContext = this.getUIContext();
      const routerInstance = uiContext.getRouter();
      routerInstance.back();
    } catch (error) {
      hilog.error(DOMAIN, TAG, '返回失败: %{public}s', JSON.stringify(error));
    }
  }

  private routerPushUrl(url: string): void {
    try {
      const uiContext = this.getUIContext();
      const routerInstance = uiContext.getRouter();
      routerInstance.pushUrl({
        url: url
      }).catch((error: Error) => {
        hilog.error(DOMAIN, TAG, '跳转失败: %{public}s', JSON.stringify(error));
      });
    } catch (error) {
      hilog.error(DOMAIN, TAG, '跳转失败: %{public}s', JSON.stringify(error));
    }
  }

  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, 'Control页面开始加载');

    // 获取路由参数
    interface RouterParams {
      deviceId?: string;
      password?: string;
    }
    try {
      const uiContext = this.getUIContext();
      const routerInstance = uiContext.getRouter();
      const params = routerInstance.getParams() as RouterParams;
      if (params) {
        this.remoteDeviceId = params.deviceId || '';
        this.remoteDevicePassword = params.password || '';
        hilog.info(DOMAIN, TAG, '获取到路由参数 - deviceId: %{public}s, hasPassword: %{public}s', 
          this.remoteDeviceId, !!this.remoteDevicePassword);
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, '获取路由参数失败: %{public}s', JSON.stringify(error));
    }

    // 检查当前连接状态
    const currentState = this.remoteControlService.getConnectionState();
    hilog.info(DOMAIN, TAG, '当前RemoteControlService连接状态: %{public}s', currentState);
    if (currentState === ConnectionState.CONNECTED) {
      this.connectionState = AppState.CONNECTED;
      hilog.info(DOMAIN, TAG, '设置UI连接状态为已连接');
    }

    // 监听连接状态
    this.remoteControlService.setConnectionCallback((state: boolean) => {
      hilog.info(DOMAIN, TAG, '连接状态更新: %{public}s', state ? '已连接' : '未连接');
      this.connectionState = state ? AppState.CONNECTED : AppState.DISCONNECTED;
      
      // 如果连接已建立且有设备ID，打开远程屏幕
      if (state && this.remoteDeviceId && this.connectionState === AppState.CONNECTED) {
        hilog.info(DOMAIN, TAG, '连接已建立，准备打开远程屏幕');
        setTimeout(() => {
          this.openRemoteScreen();
        }, 500);
      }
    });
    // 设置屏幕回调
    this.remoteControlService.setScreenCallback((data: ArrayBuffer, width: number, height: number, timestamp: number) => {
      hilog.info(DOMAIN, TAG, '收到屏幕回调');
      const image = new ScreenImage(data, width, height, timestamp);
      this.handleScreenImage(image);
    });

    // 如果有远程设备ID，直接打开远程屏幕（无论连接状态如何）
    hilog.info(DOMAIN, TAG, '检查是否需要直接打开屏幕 - hasDeviceId: %{public}s, connectionState: %{public}s', 
      !!this.remoteDeviceId, this.connectionState);
    if (this.remoteDeviceId) {
      hilog.info(DOMAIN, TAG, '直接打开远程屏幕，等待连接建立');
      setTimeout(() => {
        this.openRemoteScreen();
      }, 1000);
    }
  }
  aboutToDisappear(): void {
    // 关闭远程屏幕控制，但保持与服务器的连接
    try {
      this.remoteControlService.closeRemoteScreen();
      hilog.info(DOMAIN, TAG, '已关闭远程屏幕控制');
    } catch (error) {
      hilog.error(DOMAIN, TAG, '关闭远程屏幕失败: %{public}s', JSON.stringify(error));
    }
  }
  openRemoteScreen(): void {
    hilog.info(DOMAIN, TAG, 'openRemoteScreen被调用 - deviceId: %{public}s, hasPassword: %{public}s, connectionState: %{public}s',
      this.remoteDeviceId, !!this.remoteDevicePassword, this.connectionState);
    
    // 1. 检查设备ID格式（只能包含字母和数字）
    const deviceIdRegex = /^[a-zA-Z0-9]+$/;
    if (!deviceIdRegex.test(this.remoteDeviceId)) {
      hilog.warn(DOMAIN, TAG, '设备ID格式错误');
      this.showToast('设备ID只能包含字母和数字', 3000);
      return;
    }
    
    // 2. 检查密码是否为空
    if (!this.remoteDevicePassword) {
      hilog.warn(DOMAIN, TAG, '密码为空');
      this.showToast('请输入密码', 2000);
      return;
    }
    
    // 3. 先设置设备信息，然后发送连接请求
    hilog.info(DOMAIN, TAG, '设置设备信息并启用远程控制权限');
    this.remoteControlService.setDeviceInfo(this.remoteDeviceId, this.remoteDevicePassword);
    // 启用远程控制权限
    this.remoteControlService.setRemoteControlPermission(true);
    
    // 4. 如果已连接，发送连接请求
    if (this.connectionState === AppState.CONNECTED) {
      hilog.info(DOMAIN, TAG, '已连接，发送打开远程屏幕请求');
      this.remoteControlService.openRemoteScreen(
        this.remoteDeviceId,
        this.remoteDevicePassword
      );
    } else {
      hilog.info(DOMAIN, TAG, '等待连接建立后再发送请求');
      // 在连接状态回调中会处理发送请求
    }
  }
  handleScreenImage(screenData: ScreenImage): void {
    // 处理屏幕图像数据
    // 更新屏幕图像和尺寸
    this.screenWidth = screenData.width;
    this.screenHeight = screenData.height;
    hilog.info(DOMAIN, TAG, '收到屏幕图像: %{public}d x %{public}d', screenData.width, screenData.height);
    this.createPixelMapFromRawData(screenData.data, screenData.width, screenData.height);
  }

  // 从原始像素数据创建PixelMap
  private createPixelMapFromRawData(buffer: ArrayBuffer, width: number, height: number): void {
    try {
      // 检查数据完整性
      const expectedSize = width * height * 4; // ARGB格式每个像素4字节
      if (buffer.byteLength !== expectedSize) {
        hilog.warn(DOMAIN, TAG, '图像数据大小不匹配: 期望 %{public}d, 实际 %{public}d', expectedSize, buffer.byteLength);
        // 不直接返回，尝试使用现有数据
      }
      // Java端使用大端序发送ARGB数据（AA,RR,GG,BB）
      // 鸿蒙ARGB_8888格式期望（AA,RR,GG,BB），正好匹配！
      const opts: image.InitializationOptions = {
        size: {
          height: height,
          width: width
        },
        pixelFormat: image.PixelMapFormat.ARGB_8888,
        editable: false,
        alphaType: image.AlphaType.OPAQUE
      };

      image.createPixelMap(buffer, opts).then((pixelMap: image.PixelMap) => {
        this.screenImage = pixelMap;
      }).catch((error: Error) => {
        hilog.error(DOMAIN, TAG, '创建PixelMap失败: %{public}s', JSON.stringify(error));
      });
    } catch (error) {
      hilog.error(DOMAIN, TAG, '处理图像失败: %{public}s', JSON.stringify(error));
    }
  }
  // 处理文件拖拽事件
  // 注意：ArkTS的DragEvent没有dataTransfer属性，不支持文件拖拽
  // 这里暂时留空，后续可以通过其他方式实现文件上传
  handleFileDrop(): void {
    console.log('File drop functionality is not supported in ArkTS drag events');
    // 可以在这里添加其他文件选择方式，如文件选择器
    this.showToast('文件拖拽功能暂不支持，请使用文件选择器上传', 3000);
  }

  async uploadFiles(files: UploadableFile[]) {
    for (const file of files) {
      try {
        // 显示上传进度通知
        this.showToast(`正在上传: ${file.name}`, 1500);

        // 将UploadableFile转换为UploadFile
        const uploadFile: UploadFile = {
          path: file.path,
          uri: file.uri
        };

        // 调用FileService进行上传
        try {
          await this.fileService.uploadFile(
            uploadFile,
            (progress: number) => {
              // 更新进度通知
              this.showToast(`${file.name}: ${Math.round(progress * 100)}%`, 1000);
            }
          );

          // 上传完成通知
          this.showToast(`${file.name} 上传成功`, 2000);
        } catch (uploadError) {
          hilog.error(DOMAIN, TAG, '文件上传失败: %{public}s', JSON.stringify(uploadError));
          this.showToast(`${file.name} 上传失败`, 3000);
        }
      } catch (error) {
        hilog.error(DOMAIN, TAG, '上传处理失败: %{public}s', JSON.stringify(error));
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
  handleTouchStart(event: GestureEvent): void {
    // 触摸开始，记录初始位置
    this.lastTouchX = event.offsetX;
    this.lastTouchY = event.offsetY;
  }

  handleTouchMove(event: GestureEvent): void {
    // 触摸移动，发送鼠标移动命令
    const deltaX = event.offsetX - this.lastTouchX;
    const deltaY = event.offsetY - this.lastTouchY;
    
    // 发送鼠标移动命令
    this.remoteControlService.sendMouseControl(
      event.offsetX,
      event.offsetY,
      0, // 0表示移动
      undefined
    );
    
    // 更新最后位置
    this.lastTouchX = event.offsetX;
    this.lastTouchY = event.offsetY;
  }

  handleTouchEnd(event: GestureEvent): void {
    // 触摸结束，发送鼠标点击命令
    // 发送鼠标点击命令（左键点击）
    this.remoteControlService.sendMouseControl(
      event.offsetX,
      event.offsetY,
      1, // 1表示左键点击
      undefined
    );
  }

  @Builder
  buildRemoteScreen() {
    Column() {
      // 远程屏幕显示区域
      Stack() {
        // 屏幕内容
        if (this.screenImage) {
          // 显示远程屏幕图像
          Image(this.screenImage)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
            .scale({ x: this.scale, y: this.scale })
        } else {
          // 显示默认提示
          Text('远程屏幕')
            .fontSize(16)
            .fontColor('#666')
            .margin({ top: '40%' })
        }

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
      .backgroundColor('#000000')
      .onDragEnter(() => this.showDragHint())
      .onDragLeave(() => this.hideDragHint())
      .onDrop((event?: DragEvent, extraParams?: string) => {
        this.hideDragHint();
        this.handleFileDrop();
      })
      .gesture(
        GestureGroup(GestureMode.Parallel,
          PanGesture({ distance: 1 })
            .onActionStart((event: GestureEvent) => {
              this.handleTouchStart(event);
            })
            .onActionUpdate((event: GestureEvent) => {
              this.handleTouchMove(event);
            })
            .onActionEnd((event: GestureEvent) => {
              this.handleTouchEnd(event);
            }),
          PinchGesture()
            .onActionStart(() => {
              this.lastScale = this.scale;
            })
            .onActionUpdate((event: GestureEvent) => {
              this.scale = this.lastScale * event.scale;
              // 限制缩放范围，防止过度缩放
              this.scale = Math.max(0.1, Math.min(5.0, this.scale));
            })
            .onActionEnd(() => {
              this.lastScale = this.scale;
            }),
          PanGesture({ distance: 1, fingers: 3 })
            .onActionEnd((event: GestureEvent) => {
              // 检测向上滑动
              if (event.offsetY < -50) {
                // 唤出设置界面
                this.routerPushUrl('pages/Settings');
              }
            })
        )
      )
    }
    .layoutWeight(1)  // 应用layoutWeight属性
  }
  
  @Builder
  buildControlToolbar() {
    Row() {
      // 控制按钮
      Button('断开连接')
        .onClick(() => {
          this.routerBack();
        })
      Button('设置')
        .onClick(() => {
          this.routerPushUrl('pages/Settings');
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
      // 远程屏幕区域（占满整个屏幕）
      this.buildRemoteScreen()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000')
  }
}
