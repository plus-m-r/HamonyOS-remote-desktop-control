// ControlViewModel.ets - 控制页面的 ViewModel，解耦业务逻辑与 UI
// 遵循 MVVM 架构，所有业务逻辑都在这里，便于单元测试

import { IRemoteControlService } from '../services/interfaces/IRemoteControlService';
import { IFileService, UploadFile } from '../services/interfaces/IFileService';
import { IClipboardService } from '../services/interfaces/IClipboardService';
import { AppState } from '../state/AppStateManager';
import { ScreenImage, ConnectionState } from '../models/DeviceInfo';
import { image } from '@kit.ImageKit';
import hilog from '@ohos.hilog';

const TAG = 'ControlViewModel';
const DOMAIN = 0x0000;

/**
 * 控制页面状态接口
 */
export interface ControlPageState {
  connectionState: number;
  remoteDeviceId: string;
  remoteDevicePassword: string;
  isDragging: boolean;
  screenWidth: number;
  screenHeight: number;
  isToolbarVisible: boolean;
  lastTouchX: number;
  lastTouchY: number;
  screenImage: image.PixelMap | null;
  currentScale: number;
  lastScale: number;
  isLongPress: boolean;
  errorMessage: string;
}

/**
 * 可上传文件接口
 */
export interface UploadableFile {
  name: string;
  size: number;
  type: string;
  path?: string;
  uri?: string;
}

/**
 * ViewModel 依赖接口
 */
export interface ControlViewModelDependencies {
  remoteControlService: IRemoteControlService;
  fileService: IFileService;
  clipboardService: IClipboardService;
}

/**
 * Toast 回调类型
 */
export type ToastCallback = (message: string, duration?: number) => void;

/**
 * 导航回调类型
 */
export type NavigationCallback = (url: string) => void;

/**
 * 返回回调类型
 */
export type BackCallback = () => void;

/**
 * 屏幕图像回调类型
 */
export type ScreenImageCallback = (pixelMap: image.PixelMap | null, width: number, height: number) => void;

/**
 * 控制页面 ViewModel
 * 管理控制页面的所有业务逻辑，与 UI 完全解耦
 */
export class ControlViewModel {
  private dependencies: ControlViewModelDependencies;
  private state: ControlPageState;
  private stateSubscribers: Array<(state: ControlPageState) => void> = [];
  
  // 回调函数
  private toastCallback: ToastCallback | null = null;
  private navigationCallback: NavigationCallback | null = null;
  private backCallback: BackCallback | null = null;
  private screenImageCallback: ScreenImageCallback | null = null;
  
  // 定时器
  private longPressTimer: number | null = null;
  private readonly LONG_PRESS_DURATION = 500; // 长按判定时间（毫秒）
  
  // 缩放限制
  private readonly MIN_SCALE = 0.1;
  private readonly MAX_SCALE = 5.0;

  constructor(dependencies: ControlViewModelDependencies) {
    this.dependencies = dependencies;
    this.state = {
      connectionState: AppState.DISCONNECTED,
      remoteDeviceId: '',
      remoteDevicePassword: '',
      isDragging: false,
      screenWidth: 0,
      screenHeight: 0,
      isToolbarVisible: true,
      lastTouchX: 0,
      lastTouchY: 0,
      screenImage: null,
      currentScale: 1.0,
      lastScale: 1.0,
      isLongPress: false,
      errorMessage: ''
    };
  }

  /**
   * 设置 Toast 回调
   */
  setToastCallback(callback: ToastCallback): void {
    this.toastCallback = callback;
  }

  /**
   * 设置导航回调
   */
  setNavigationCallback(callback: NavigationCallback): void {
    this.navigationCallback = callback;
  }

  /**
   * 设置返回回调
   */
  setBackCallback(callback: BackCallback): void {
    this.backCallback = callback;
  }

  /**
   * 设置屏幕图像回调
   */
  setScreenImageCallback(callback: ScreenImageCallback): void {
    this.screenImageCallback = callback;
  }

  /**
   * 设置 XComponent 用于视频渲染
   */
  setXComponent(xComponent: Object): void {
    hilog.info(DOMAIN, TAG, 'XComponent set in ViewModel');
    this.dependencies.remoteControlService.setXComponent(xComponent);
  }

  /**
   * 显示 Toast
   */
  private showToast(message: string, duration: number = 2000): void {
    if (this.toastCallback) {
      this.toastCallback(message, duration);
    }
  }

  /**
   * 导航到指定页面
   */
  private navigateTo(url: string): void {
    if (this.navigationCallback) {
      this.navigationCallback(url);
    }
  }

  /**
   * 返回上一页
   */
  private goBack(): void {
    if (this.backCallback) {
      this.backCallback();
    }
  }

  /**
   * 订阅状态变化
   */
  subscribe(callback: (state: ControlPageState) => void): () => void {
    this.stateSubscribers.push(callback);
    // 立即通知当前状态
    callback(this.copyState(this.state));
    
    // 返回取消订阅函数
    return () => {
      const index = this.stateSubscribers.indexOf(callback);
      if (index > -1) {
        this.stateSubscribers.splice(index, 1);
      }
    };
  }

  /**
   * 通知所有订阅者状态变化
   */
  private notifyStateChange(): void {
    const stateCopy = this.copyState(this.state);
    this.stateSubscribers.forEach(callback => {
      try {
        callback(stateCopy);
      } catch (error) {
        hilog.error(DOMAIN, TAG, '状态订阅者回调失败: %{public}s', JSON.stringify(error));
      }
    });
  }

  /**
   * 复制状态对象
   */
  private copyState(state: ControlPageState): ControlPageState {
    return {
      connectionState: state.connectionState,
      remoteDeviceId: state.remoteDeviceId,
      remoteDevicePassword: state.remoteDevicePassword,
      isDragging: state.isDragging,
      screenWidth: state.screenWidth,
      screenHeight: state.screenHeight,
      isToolbarVisible: state.isToolbarVisible,
      lastTouchX: state.lastTouchX,
      lastTouchY: state.lastTouchY,
      screenImage: state.screenImage,
      currentScale: state.currentScale,
      lastScale: state.lastScale,
      isLongPress: state.isLongPress,
      errorMessage: state.errorMessage
    };
  }

  /**
   * 更新状态
   */
  private updateState(partialState: Partial<ControlPageState>): void {
    const newState = this.copyState(this.state);
    if (partialState.connectionState !== undefined) newState.connectionState = partialState.connectionState;
    if (partialState.remoteDeviceId !== undefined) newState.remoteDeviceId = partialState.remoteDeviceId;
    if (partialState.remoteDevicePassword !== undefined) newState.remoteDevicePassword = partialState.remoteDevicePassword;
    if (partialState.isDragging !== undefined) newState.isDragging = partialState.isDragging;
    if (partialState.screenWidth !== undefined) newState.screenWidth = partialState.screenWidth;
    if (partialState.screenHeight !== undefined) newState.screenHeight = partialState.screenHeight;
    if (partialState.isToolbarVisible !== undefined) newState.isToolbarVisible = partialState.isToolbarVisible;
    if (partialState.lastTouchX !== undefined) newState.lastTouchX = partialState.lastTouchX;
    if (partialState.lastTouchY !== undefined) newState.lastTouchY = partialState.lastTouchY;
    if (partialState.screenImage !== undefined) newState.screenImage = partialState.screenImage;
    if (partialState.currentScale !== undefined) newState.currentScale = partialState.currentScale;
    if (partialState.lastScale !== undefined) newState.lastScale = partialState.lastScale;
    if (partialState.isLongPress !== undefined) newState.isLongPress = partialState.isLongPress;
    if (partialState.errorMessage !== undefined) newState.errorMessage = partialState.errorMessage;
    this.state = newState;
    this.notifyStateChange();
  }

  /**
   * 初始化 ViewModel
   * @param deviceId 设备ID
   * @param password 密码
   */
  initialize(deviceId: string = '', password: string = ''): void {
    hilog.info(DOMAIN, TAG, 'ControlViewModel 初始化 - deviceId: %{public}s', deviceId);
    
    this.updateState({
      remoteDeviceId: deviceId,
      remoteDevicePassword: password
    });

    // 设置连接状态回调
    this.dependencies.remoteControlService.setConnectionCallback((connected: boolean) => {
      const newState = connected ? AppState.CONNECTED : AppState.DISCONNECTED;
      hilog.info(DOMAIN, TAG, '连接状态更新: %{public}s', connected ? '已连接' : '未连接');
      this.updateState({ connectionState: newState });
      
      // 如果连接已建立，自动打开远程屏幕
      if (connected && this.state.remoteDeviceId) {
        setTimeout(() => {
          this.openRemoteScreen();
        }, 500);
      }
    });

    // 设置屏幕数据回调
    this.dependencies.remoteControlService.setScreenCallback(
      (data: ArrayBuffer, width: number, height: number, timestamp: number) => {
        hilog.debug(DOMAIN, TAG, '收到屏幕数据: %{public}d x %{public}d', width, height);
        const screenImage = new ScreenImage(data, width, height, timestamp);
        this.handleScreenImage(screenImage);
      }
    );

    // 检查当前连接状态
    const currentState = this.dependencies.remoteControlService.getConnectionState();
    if (currentState === ConnectionState.CONNECTED) {
      this.updateState({ connectionState: AppState.CONNECTED });
    }

    // 如果有设备ID，延迟打开远程屏幕
    if (deviceId) {
      setTimeout(() => {
        this.openRemoteScreen();
      }, 1000);
    }
  }

  /**
   * 清理资源
   */
  dispose(): void {
    hilog.info(DOMAIN, TAG, 'ControlViewModel 清理资源');
    
    // 清除长按定时器
    if (this.longPressTimer) {
      clearTimeout(this.longPressTimer);
      this.longPressTimer = null;
    }

    // 关闭远程屏幕
    try {
      this.dependencies.remoteControlService.closeRemoteScreen();
    } catch (error) {
      hilog.error(DOMAIN, TAG, '关闭远程屏幕失败: %{public}s', JSON.stringify(error));
    }

    // 清空订阅者
    this.stateSubscribers = [];
  }

  /**
   * 打开远程屏幕
   */
  openRemoteScreen(): void {
    const remoteDeviceId = this.state.remoteDeviceId;
    const remoteDevicePassword = this.state.remoteDevicePassword;
    const connectionState = this.state.connectionState;
    
    hilog.info(DOMAIN, TAG, '打开远程屏幕 - deviceId: %{public}s, state: %{public}s',
      remoteDeviceId, connectionState);

    // 验证设备ID格式
    const deviceIdRegex = /^[a-zA-Z0-9]+$/;
    if (!deviceIdRegex.test(remoteDeviceId)) {
      hilog.warn(DOMAIN, TAG, '设备ID格式错误');
      this.showToast('设备ID只能包含字母和数字', 3000);
      return;
    }

    // 验证密码
    if (!remoteDevicePassword) {
      hilog.warn(DOMAIN, TAG, '密码为空');
      this.showToast('请输入密码', 2000);
      return;
    }

    // 设置设备信息
    this.dependencies.remoteControlService.setDeviceInfo(remoteDeviceId, remoteDevicePassword);
    this.dependencies.remoteControlService.setRemoteControlPermission(true);

    // 如果已连接，发送打开屏幕请求
    if (connectionState === AppState.CONNECTED) {
      hilog.info(DOMAIN, TAG, '已连接，发送打开远程屏幕请求');
      this.dependencies.remoteControlService.openRemoteScreen(
        remoteDeviceId,
        remoteDevicePassword
      );
    }
  }

  /**
   * 处理屏幕图像数据
   */
  private handleScreenImage(screenData: ScreenImage): void {
    this.updateState({
      screenWidth: screenData.width,
      screenHeight: screenData.height
    });
    
    this.createPixelMapFromRawData(screenData.data, screenData.width, screenData.height);
  }

  /**
   * 从原始像素数据创建 PixelMap
   */
  private createPixelMapFromRawData(buffer: ArrayBuffer, width: number, height: number): void {
    try {
      const expectedSize = width * height * 4; // ARGB 格式每个像素 4 字节
      if (buffer.byteLength !== expectedSize) {
        hilog.warn(DOMAIN, TAG, '图像数据大小不匹配: 期望 %{public}d, 实际 %{public}d',
          expectedSize, buffer.byteLength);
      }

      const opts: image.InitializationOptions = {
        size: { height, width },
        pixelFormat: image.PixelMapFormat.ARGB_8888,
        editable: false,
        alphaType: image.AlphaType.OPAQUE
      };

      image.createPixelMap(buffer, opts)
        .then((pixelMap: image.PixelMap) => {
          this.updateState({ screenImage: pixelMap });
          if (this.screenImageCallback) {
            this.screenImageCallback(pixelMap, width, height);
          }
        })
        .catch((error: Error) => {
          hilog.error(DOMAIN, TAG, '创建 PixelMap 失败: %{public}s', JSON.stringify(error));
          this.updateState({ screenImage: null });
          if (this.screenImageCallback) {
            this.screenImageCallback(null, width, height);
          }
        });
    } catch (error) {
      hilog.error(DOMAIN, TAG, '处理图像失败: %{public}s', JSON.stringify(error));
      this.updateState({ screenImage: null });
    }
  }

  /**
   * 返回上一页（关闭远程屏幕）
   */
  goBackAndCloseScreen(): void {
    try {
      this.dependencies.remoteControlService.closeRemoteScreen();
      hilog.info(DOMAIN, TAG, '已关闭远程屏幕控制');
    } catch (error) {
      hilog.error(DOMAIN, TAG, '关闭远程屏幕失败: %{public}s', JSON.stringify(error));
    }
    this.goBack();
  }

  /**
   * 处理触摸开始
   */
  handleTouchStart(x: number, y: number): void {
    this.updateState({
      lastTouchX: x,
      lastTouchY: y,
      isLongPress: false
    });

    // 设置长按定时器
    this.longPressTimer = setTimeout(() => {
      this.updateState({ isLongPress: true });
      // 发送鼠标右键点击
      this.sendMouseControl(x, y, 2); // 2 表示右键
    }, this.LONG_PRESS_DURATION);
  }

  /**
   * 处理触摸移动
   */
  handleTouchMove(x: number, y: number): void {
    // 清除长按定时器
    if (this.longPressTimer) {
      clearTimeout(this.longPressTimer);
      this.longPressTimer = null;
    }

    this.updateState({
      lastTouchX: x,
      lastTouchY: y
    });
  }

  /**
   * 处理触摸结束
   */
  handleTouchEnd(x: number, y: number): void {
    // 清除长按定时器
    if (this.longPressTimer) {
      clearTimeout(this.longPressTimer);
      this.longPressTimer = null;
    }

    // 如果不是长按，发送左键点击
    if (!this.state.isLongPress) {
      this.sendMouseControl(x, y, 1); // 1 表示左键
    }
  }

  /**
   * 发送鼠标控制命令
   */
  private sendMouseControl(x: number, y: number, button: number): void {
    try {
      this.dependencies.remoteControlService.sendMouseControl(x, y, button, undefined);
      hilog.debug(DOMAIN, TAG, '发送鼠标控制 - x: %{public}d, y: %{public}d, button: %{public}d', x, y, button);
    } catch (error) {
      hilog.error(DOMAIN, TAG, '发送鼠标控制失败: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 处理缩放开始
   */
  handlePinchStart(): void {
    this.updateState({ lastScale: this.state.currentScale });
  }

  /**
   * 处理缩放更新
   */
  handlePinchUpdate(scale: number): void {
    let newScale = this.state.lastScale * scale;
    // 限制缩放范围
    newScale = Math.max(this.MIN_SCALE, Math.min(this.MAX_SCALE, newScale));
    this.updateState({ currentScale: newScale });
  }

  /**
   * 处理缩放结束
   */
  handlePinchEnd(): void {
    this.updateState({ lastScale: this.state.currentScale });
  }

  /**
   * 处理三指滑动
   */
  handleThreeFingerPan(offsetY: number): void {
    // 向上滑动超过阈值，打开设置页面
    if (offsetY < -50) {
      this.navigateTo('pages/Settings');
    }
  }

  /**
   * 显示拖拽提示
   */
  showDragHint(): void {
    this.updateState({ isDragging: true });
  }

  /**
   * 隐藏拖拽提示
   */
  hideDragHint(): void {
    this.updateState({ isDragging: false });
  }

  /**
   * 处理文件拖放
   */
  handleFileDrop(): void {
    hilog.info(DOMAIN, TAG, '文件拖放功能暂不支持');
    this.showToast('文件拖拽功能暂不支持，请使用文件选择器上传', 3000);
  }

  /**
   * 上传文件
   */
  async uploadFiles(files: UploadableFile[]): Promise<void> {
    for (const file of files) {
      try {
        this.showToast(`正在上传: ${file.name}`, 1500);

        const uploadFile: UploadFile = {
          path: file.path,
          uri: file.uri
        };

        await this.dependencies.fileService.uploadFile(
          uploadFile,
          (progress: number) => {
            this.showToast(`${file.name}: ${Math.round(progress * 100)}%`, 1000);
          }
        );

        this.showToast(`${file.name} 上传成功`, 2000);
      } catch (error) {
        hilog.error(DOMAIN, TAG, '文件上传失败: %{public}s', JSON.stringify(error));
        this.showToast(`${file.name} 上传失败`, 3000);
      }
    }
  }

  /**
   * 切换工具栏显示状态
   */
  toggleToolbar(): void {
    this.updateState({ isToolbarVisible: !this.state.isToolbarVisible });
  }

  /**
   * 获取当前状态（用于测试）
   */
  getState(): ControlPageState {
    return this.copyState(this.state);
  }

  /**
   * 设置设备信息
   */
  setDeviceInfo(deviceId: string, password: string): void {
    this.updateState({
      remoteDeviceId: deviceId,
      remoteDevicePassword: password
    });
  }
}
