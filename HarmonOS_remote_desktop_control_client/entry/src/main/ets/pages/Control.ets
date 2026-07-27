import { ControlViewModel, ControlPageState } from '../viewmodel/ControlViewModel';
import { ServiceProvider } from '../di/ServiceProvider';
import hilog from '@ohos.hilog';
import {
  ArkZeroSurfaceView,
  SurfaceViewConfig,
  NormalizedTouchEvent,
  TouchPoint,
  ArkZeroRenderSession,
  RenderSessionConfig,
  PixelFormat
} from '@plusml/arkzero';

interface RouterParams {
  deviceId?: string;
  password?: string;
}

const TAG = 'ControlPage';
const DOMAIN = 0x0000;
const PANEL_WIDTH = 280;

let _viewModel: ControlViewModel | null = null;
let _renderSession: ArkZeroRenderSession | null = null;

@Entry
@Component
struct Control {
  private viewModel!: ControlViewModel;

  @State private state: ControlPageState = {
    connectionState: 0,
    remoteDeviceId: '',
    remoteDevicePassword: '',
    isDragging: false,
    screenWidth: 0,
    screenHeight: 0,
    isPanelVisible: false,
    lastTouchX: 0,
    lastTouchY: 0,
    currentScale: 1.0,
    lastScale: 1.0,
    isLongPress: false,
    errorMessage: '',
    isRendererReady: false
  };

  @State private surfaceViewConfig: SurfaceViewConfig = {
    renderWidth: 640,
    renderHeight: 480,
    format: PixelFormat.RGBA,
    originRatioX: 0.0,
    originRatioY: 0.0,
    sizeRatioX: 1.0,
    enableTouch: true,
    xComponentId: 'arkzero_remote_surface'
  };

  @State private panelTranslateX: number = PANEL_WIDTH;

  private renderSession: ArkZeroRenderSession | null = null;
  private touchHandlerFn: ((event: NormalizedTouchEvent) => void) | null = null;
  private surfaceLoadedFn: ((surfaceId: string) => void) | null = null;

  constructor() {
    super()
    _viewModel = new ControlViewModel({
      remoteControlService: ServiceProvider.remoteControlService,
      fileService: ServiceProvider.fileService,
      clipboardService: ServiceProvider.clipboardService
    });
    this.viewModel = _viewModel;

    _viewModel.subscribe((newState: ControlPageState) => {
      this.state = newState;
      this.panelTranslateX = newState.isPanelVisible ? 0 : PANEL_WIDTH;
    });

    _viewModel.setToastCallback((message: string, duration?: number) => {
      this.showToast(message, duration);
    });

    _viewModel.setNavigationCallback((url: string) => {
      this.routerPushUrl(url);
    });

    _viewModel.setBackCallback(() => {
      this.routerBack();
    });
  }

  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, 'Control page loading');

    try {
      const sessionConfig: RenderSessionConfig = {
        width: this.surfaceViewConfig.renderWidth,
        height: this.surfaceViewConfig.renderHeight,
        format: PixelFormat.RGBA,
        onError: (errorMsg: string) => {
          hilog.error(DOMAIN, TAG, 'RenderSession error: %{public}s', errorMsg);
        }
      };
      _renderSession = new ArkZeroRenderSession(sessionConfig);
      this.renderSession = _renderSession;
      _viewModel!.setRenderSession(_renderSession);

      const vm: ControlViewModel = _viewModel!;
      const session: ArkZeroRenderSession = _renderSession;

      this.touchHandlerFn = (event: NormalizedTouchEvent) => {
        if (event.touches.length === 0) {
          return;
        }
        const touch: TouchPoint = event.touches[0];
        const x: number = touch.pixelX;
        const y: number = touch.pixelY;

        if (event.type === TouchType.Down) {
          vm.handleTouchStart(x, y);
        } else if (event.type === TouchType.Move) {
          vm.handleTouchMove(x, y);
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          vm.handleTouchEnd(x, y);
        }
      };

      this.surfaceLoadedFn = (surfaceId: string) => {
        hilog.info(DOMAIN, TAG, 'Surface loaded: %{public}s', surfaceId);
        session.attach(surfaceId).then(() => {
          hilog.info(DOMAIN, TAG, 'RenderSession attached');
          session.setVSync(true);
          vm.setRenderSession(session);
        }).catch((error: Error) => {
          hilog.error(DOMAIN, TAG, 'RenderSession attach failed: %{public}s', error.message);
        });
      };

      _viewModel!.setResolutionChangeCallback((width: number, height: number) => {
        this.surfaceViewConfig = {
          renderWidth: width,
          renderHeight: height,
          format: PixelFormat.RGBA,
          originRatioX: 0.0,
          originRatioY: 0.0,
          sizeRatioX: 1.0,
          enableTouch: true,
          xComponentId: 'arkzero_remote_surface'
        };
      });

      let deviceId = '';
      let password = '';

      try {
        const uiContext = this.getUIContext();
        const routerInstance = uiContext.getRouter();
        const params = routerInstance.getParams() as RouterParams;
        if (params) {
          deviceId = params.deviceId || '';
          password = params.password || '';
        }
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Failed to get router params: %{public}s', JSON.stringify(error));
      }

      _viewModel!.initialize(deviceId, password);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Control page init error: %{public}s', JSON.stringify(error));
    }
  }

  aboutToDisappear(): void {
    hilog.info(DOMAIN, TAG, 'Control page destroying');
    if (_viewModel) {
      _viewModel.dispose();
      _viewModel = null;
    }
    if (_renderSession) {
      _renderSession = null;
    }
    this.renderSession = null;
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
      hilog.error(DOMAIN, TAG, 'showToast failed: %{public}s', JSON.stringify(error));
    }
  }

  private routerBack(): void {
    try {
      const uiContext = this.getUIContext();
      const routerInstance = uiContext.getRouter();
      routerInstance.back();
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'routerBack failed: %{public}s', JSON.stringify(error));
    }
  }

  private routerPushUrl(url: string): void {
    try {
      const uiContext = this.getUIContext();
      const routerInstance = uiContext.getRouter();
      routerInstance.pushUrl({
        url: url
      }).catch((error: Error) => {
        hilog.error(DOMAIN, TAG, 'routerPush failed: %{public}s', JSON.stringify(error));
      });
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'routerPush failed: %{public}s', JSON.stringify(error));
    }
  }

  private handlePinchStart(): void {
    if (_viewModel) _viewModel.handlePinchStart();
  }

  private handlePinchUpdate(event: GestureEvent): void {
    if (_viewModel) _viewModel.handlePinchUpdate(event.scale);
  }

  private handlePinchEnd(): void {
    if (_viewModel) _viewModel.handlePinchEnd();
  }

  private handleThreeFingerPan(event: GestureEvent): void {
    if (_viewModel) _viewModel.handleThreeFingerPan(event.offsetY);
  }

  private showDragHint(): void {
    if (_viewModel) _viewModel.showDragHint();
  }

  private hideDragHint(): void {
    if (_viewModel) _viewModel.hideDragHint();
  }

  private handleFileDrop(): void {
    if (_viewModel) _viewModel.handleFileDrop();
  }

  private goBackAndCloseScreen(): void {
    if (_viewModel) _viewModel.goBackAndCloseScreen();
  }

  @Builder
  buildSidePanel() {
    Column() {
      Row() {
        Text('\u00d7')
          .fontSize(28)
          .fontColor('#ccc')
          .margin({ right: 16, top: 16 })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .onClick(() => {
        if (_viewModel) _viewModel.hidePanel();
      })

      Column({ space: 12 }) {
        Button('断开连接')
          .width('100%')
          .height(44)
          .fontSize(16)
          .backgroundColor('#cc3333')
          .fontColor('#fff')
          .onClick(() => {
            if (_viewModel) _viewModel.goBackAndCloseScreen();
          })

        Button('重置缩放')
          .width('100%')
          .height(44)
          .fontSize(16)
          .backgroundColor('#555555')
          .fontColor('#fff')
          .onClick(() => {
            if (_viewModel) _viewModel.resetZoom();
          })

        Button('设置')
          .width('100%')
          .height(44)
          .fontSize(16)
          .backgroundColor('#555555')
          .fontColor('#fff')
          .onClick(() => {
            this.routerPushUrl('pages/Settings');
          })
      }
      .padding({ left: 16, right: 16, top: 24 })

      Blank()
    }
    .width(PANEL_WIDTH)
    .height('100%')
    .backgroundColor('rgba(0, 0, 0, 0.88)')
    .position({ x: '100%', y: 0 })
    .translate({ x: -this.panelTranslateX })
  }

  build() {
    Stack() {
      ArkZeroSurfaceView({
        config: this.surfaceViewConfig,
        touchHandler: this.touchHandlerFn!,
        onSurfaceLoaded: this.surfaceLoadedFn!
      })

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

      if (this.state.isPanelVisible) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.3)')
          .hitTestBehavior(HitTestMode.Block)
          .onClick(() => {
            if (_viewModel) _viewModel.hidePanel();
          })

        this.buildSidePanel()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .onDragEnter(() => this.showDragHint())
    .onDragLeave(() => this.hideDragHint())
    .onDrop((event?: DragEvent, extraParams?: string) => {
      this.hideDragHint();
      this.handleFileDrop();
    })
    .gesture(
      GestureGroup(GestureMode.Parallel,
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
}
