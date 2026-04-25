// Control.ets - 解耦后的控制页面，通过 ViewModel 管理业务逻辑
// 遵循 MVVM 架构，页面只负责 UI 渲染和事件转发
import { ControlViewModel, ControlPageState, UploadableFile } from '../viewmodel/ControlViewModel';
import { ServiceProvider } from '../di/ServiceProvider';
import { promptAction, router } from '@kit.ArkUI';
import hilog from '@ohos.hilog';
import { image } from '@kit.ImageKit';

interface RouterParams {
  deviceId?: string;
  password?: string;
}

const TAG = 'ControlPage';
const DOMAIN = 0x0000;

@Entry
@Component
struct Control {
  // ViewModel 实例，通过依赖注入获取
  private viewModel!: ControlViewModel;

  // UI 状态，从 ViewModel 同步
  @State private state: ControlPageState = {
    connectionState: 0, // AppState.DISCONNECTED
    remoteDeviceId: '',
    remoteDevicePassword: '',
    isDragging: false,
    screenWidth: 0,
    screenHeight: 0,
    isToolbarVisible: true,
    lastTouchX: 0,
    lastTouchY: 0,
    currentScale: 1.0,
    lastScale: 1.0,
    isLongPress: false,
    errorMessage: ''
  };

  // 用于显示远程屏幕画面
  @State private screenPixelMap: image.PixelMap | undefined = undefined;

  constructor() {
    super();
    // 通过 ServiceProvider 获取依赖，注入到 ViewModel
    this.viewModel = new ControlViewModel({
      remoteControlService: ServiceProvider.remoteControlService,
      fileService: ServiceProvider.fileService,
      clipboardService: ServiceProvider.clipboardService
    });

    // 订阅 ViewModel 状态变化
    this.viewModel.subscribe((newState: ControlPageState) => {
      this.state = { ...newState };
    });

    // 设置 Toast 回调
    this.viewModel.setToastCallback((message: string, duration?: number) => {
      this.showToast(message, duration);
    });

    // 设置导航回调
    this.viewModel.setNavigationCallback((url: string) => {
      this.routerPushUrl(url);
    });

    // 设置返回回调
    this.viewModel.setBackCallback(() => {
      this.routerBack();
    });
  }

  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, 'Control页面开始加载');

    try {
      if (!this.viewModel) {
        hilog.error(DOMAIN, TAG, 'ViewModel未初始化，尝试重新初始化');
        try {
          this.viewModel = new ControlViewModel({
            remoteControlService: ServiceProvider.remoteControlService,
            fileService: ServiceProvider.fileService,
            clipboardService: ServiceProvider.clipboardService
          });
        } catch (initError) {
          hilog.error(DOMAIN, TAG, 'ViewModel初始化失败: %{public}s', JSON.stringify(initError));
          return;
        }
      }

      let deviceId = '';
      let password = '';

      try {
        const uiContext = this.getUIContext();
        const routerInstance = uiContext.getRouter();
        const params = routerInstance.getParams() as RouterParams;
        if (params) {
          deviceId = params.deviceId || '';
          password = params.password || '';
          hilog.info(DOMAIN, TAG, '获取到路由参数 - deviceId: %{public}s, hasPassword: %{public}s',
            deviceId, !!password);
        }
      } catch (error) {
        hilog.error(DOMAIN, TAG, '获取路由参数失败: %{public}s', JSON.stringify(error));
      }

      // ⭐ 设置屏幕像素数据回调
      this.viewModel.setScreenPixelMapCallback((pixelMap: image.PixelMap) => {
        const previous: image.PixelMap | undefined = this.screenPixelMap;
        
        hilog.debug(DOMAIN, TAG, 'UI 收到新 PixelMap');
        
        // ⭐⭐⭐ 关键：直接赋值新的 PixelMap，@State 会自动检测到引用变化
        this.screenPixelMap = pixelMap;
        
        hilog.debug(DOMAIN, TAG, '✅ UI 已绑定新 PixelMap');
        
        // 释放旧的 PixelMap
        if (previous) {
          try {
            previous.release();
            hilog.debug(DOMAIN, TAG, '旧PixelMap已释放');
          } catch (error) {
            hilog.error(DOMAIN, TAG, '释放旧PixelMap失败: %{public}s', JSON.stringify(error));
          }
        }
      });
      
      // 设置 UIContext 用于主线程渲染
      const uiContext = this.getUIContext();
      this.viewModel.setUIContext(uiContext);

      this.viewModel.initialize(deviceId, password);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Control页面初始化异常: %{public}s', JSON.stringify(error));
    }
  }

  aboutToDisappear(): void {
    hilog.info(DOMAIN, TAG, 'Control页面销毁');
    
    this.viewModel.dispose();
    if (this.screenPixelMap) {
      try {
        this.screenPixelMap.release();
      } catch (error) {
        hilog.warn(DOMAIN, TAG, '页面销毁释放PixelMap失败: %{public}s', JSON.stringify(error));
      }
      this.screenPixelMap = undefined;
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

  private routerBack(): void {
    try {
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

  // 触摸事件处理 - 委托给 ViewModel
  private handleTouchStart(event: GestureEvent): void {
    this.viewModel.handleTouchStart(event.offsetX, event.offsetY);
  }

  private handleTouchMove(event: GestureEvent): void {
    this.viewModel.handleTouchMove(event.offsetX, event.offsetY);
  }

  private handleTouchEnd(event: GestureEvent): void {
    this.viewModel.handleTouchEnd(event.offsetX, event.offsetY);
  }

  // 缩放手势处理 - 委托给 ViewModel
  private handlePinchStart(): void {
    this.viewModel.handlePinchStart();
  }

  private handlePinchUpdate(event: GestureEvent): void {
    this.viewModel.handlePinchUpdate(event.scale);
  }

  private handlePinchEnd(): void {
    this.viewModel.handlePinchEnd();
  }

  // 三指滑动处理 - 委托给 ViewModel
  private handleThreeFingerPan(event: GestureEvent): void {
    this.viewModel.handleThreeFingerPan(event.offsetY);
  }

  // 拖拽事件处理 - 委托给 ViewModel
  private showDragHint(): void {
    this.viewModel.showDragHint();
  }

  private hideDragHint(): void {
    this.viewModel.hideDragHint();
  }

  private handleFileDrop(): void {
    this.viewModel.handleFileDrop();
  }

  // 工具栏切换 - 委托给 ViewModel
  private toggleToolbar(): void {
    this.viewModel.toggleToolbar();
  }

  // 断开连接并返回 - 委托给 ViewModel
  private goBackAndCloseScreen(): void {
    this.viewModel.goBackAndCloseScreen();
  }

  @Builder
  buildRemoteScreen() {
    Column() {
      Stack() {
        // ⭐ 直接使用 screenPixelMap，@State 会自动检测引用变化
        if (this.screenPixelMap) {
          Image(this.screenPixelMap)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Contain)
        } else {
          // 占位背景
          Text('等待画面...')
            .width('100%')
            .height('100%')
            .textAlign(TextAlign.Center)
            .backgroundColor('#808080')
        }
        
        // 拖拽提示层（可选）
        if (this.state.isDragging) {
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
      .backgroundColor('#808080')
      // 手势、拖拽事件等保持不变
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
              this.handlePinchStart();
            })
            .onActionUpdate((event: GestureEvent) => {
              this.handlePinchUpdate(event);
            })
            .onActionEnd(() => {
              this.handlePinchEnd();
            }),
          PanGesture({ distance: 1, fingers: 3 })
            .onActionEnd((event: GestureEvent) => {
              this.handleThreeFingerPan(event);
            })
        )
      )
    }
    .layoutWeight(1)
  }

  @Builder
  buildControlToolbar() {
    Row() {
      Button('断开连接')
        .onClick(() => {
          this.goBackAndCloseScreen();
        })
      Button('设置')
        .onClick(() => {
          this.routerPushUrl('pages/Settings');
        })
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
      this.buildRemoteScreen()
      // 条件渲染工具栏
      if (this.state.isToolbarVisible) {
        this.buildControlToolbar()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#808080')
  }
}
