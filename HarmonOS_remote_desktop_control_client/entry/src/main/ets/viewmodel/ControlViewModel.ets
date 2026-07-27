import { IRemoteControlService, TileRenderData } from '../services/interfaces/IRemoteControlService';
import { IFileService, UploadFile } from '../services/interfaces/IFileService';
import { IClipboardService } from '../services/interfaces/IClipboardService';
import { AppState } from '../state/AppStateManager';
import { ConnectionState } from '../models/DeviceInfo';
import { ArkZeroRenderSession, RenderSessionConfig, TileRegion, PixelFormat } from '@plusml/arkzero';
import hilog from '@ohos.hilog';

const TAG = 'ControlViewModel';
const DOMAIN = 0x0000;

export interface ControlPageState {
  connectionState: number;
  remoteDeviceId: string;
  remoteDevicePassword: string;
  isDragging: boolean;
  screenWidth: number;
  screenHeight: number;
  isPanelVisible: boolean;
  lastTouchX: number;
  lastTouchY: number;
  currentScale: number;
  lastScale: number;
  isLongPress: boolean;
  errorMessage: string;
  isRendererReady: boolean;
}

export interface UploadableFile {
  name: string;
  size: number;
  type: string;
  path?: string;
  uri?: string;
}

export interface ControlViewModelDependencies {
  remoteControlService: IRemoteControlService;
  fileService: IFileService;
  clipboardService: IClipboardService;
}

interface CoordinatePoint {
  x: number;
  y: number;
}

export type ToastCallback = (message: string, duration?: number) => void;
export type NavigationCallback = (url: string) => void;
export type BackCallback = () => void;
export type ResolutionChangeCallback = (width: number, height: number) => void;

export class ControlViewModel {
  private dependencies: ControlViewModelDependencies;
  private state: ControlPageState;
  private stateSubscribers: Array<(state: ControlPageState) => void> = [];

  private toastCallback: ToastCallback | null = null;
  private navigationCallback: NavigationCallback | null = null;
  private backCallback: BackCallback | null = null;
  private resolutionChangeCallback: ResolutionChangeCallback | null = null;

  private renderSession: ArkZeroRenderSession | null = null;
  private pendingTileData: TileRenderData | null = null;

  private longPressTimer: number | null = null;
  private readonly LONG_PRESS_DURATION = 500;

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
      isPanelVisible: false,
      lastTouchX: 0,
      lastTouchY: 0,
      currentScale: 1.0,
      lastScale: 1.0,
      isLongPress: false,
      errorMessage: '',
      isRendererReady: false
    };
  }

  setToastCallback(callback: ToastCallback): void {
    this.toastCallback = callback;
  }

  setNavigationCallback(callback: NavigationCallback): void {
    this.navigationCallback = callback;
  }

  setBackCallback(callback: BackCallback): void {
    this.backCallback = callback;
  }

  setResolutionChangeCallback(callback: ResolutionChangeCallback): void {
    this.resolutionChangeCallback = callback;
  }

  setRenderSession(session: ArkZeroRenderSession): void {
    this.renderSession = session;

    if (session.ready && this.pendingTileData) {
      const pending = this.pendingTileData;
      this.pendingTileData = null;
      this.onTileRenderData(pending);
    }
  }

  private showToast(message: string, duration: number = 2000): void {
    if (this.toastCallback) {
      this.toastCallback(message, duration);
    }
  }

  private navigateTo(url: string): void {
    if (this.navigationCallback) {
      this.navigationCallback(url);
    }
  }

  private goBack(): void {
    if (this.backCallback) {
      this.backCallback();
    }
  }

  subscribe(callback: (state: ControlPageState) => void): () => void {
    this.stateSubscribers.push(callback);
    callback(this.copyState(this.state));
    return () => {
      const index = this.stateSubscribers.indexOf(callback);
      if (index > -1) {
        this.stateSubscribers.splice(index, 1);
      }
    };
  }

  private notifyStateChange(): void {
    const stateCopy = this.copyState(this.state);
    for (let i = 0; i < this.stateSubscribers.length; i++) {
      try {
        this.stateSubscribers[i](stateCopy);
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'State subscriber error: %{public}s', JSON.stringify(error));
      }
    }
  }

  private copyState(state: ControlPageState): ControlPageState {
    return {
      connectionState: state.connectionState,
      remoteDeviceId: state.remoteDeviceId,
      remoteDevicePassword: state.remoteDevicePassword,
      isDragging: state.isDragging,
      screenWidth: state.screenWidth,
      screenHeight: state.screenHeight,
      isPanelVisible: state.isPanelVisible,
      lastTouchX: state.lastTouchX,
      lastTouchY: state.lastTouchY,
      currentScale: state.currentScale,
      lastScale: state.lastScale,
      isLongPress: state.isLongPress,
      errorMessage: state.errorMessage,
      isRendererReady: state.isRendererReady
    };
  }

  private updateState(partialState: Partial<ControlPageState>): void {
    const newState = this.copyState(this.state);
    if (partialState.connectionState !== undefined) newState.connectionState = partialState.connectionState;
    if (partialState.remoteDeviceId !== undefined) newState.remoteDeviceId = partialState.remoteDeviceId;
    if (partialState.remoteDevicePassword !== undefined) newState.remoteDevicePassword = partialState.remoteDevicePassword;
    if (partialState.isDragging !== undefined) newState.isDragging = partialState.isDragging;
    if (partialState.screenWidth !== undefined) newState.screenWidth = partialState.screenWidth;
    if (partialState.screenHeight !== undefined) newState.screenHeight = partialState.screenHeight;
    if (partialState.isPanelVisible !== undefined) newState.isPanelVisible = partialState.isPanelVisible;
    if (partialState.lastTouchX !== undefined) newState.lastTouchX = partialState.lastTouchX;
    if (partialState.lastTouchY !== undefined) newState.lastTouchY = partialState.lastTouchY;
    if (partialState.currentScale !== undefined) newState.currentScale = partialState.currentScale;
    if (partialState.lastScale !== undefined) newState.lastScale = partialState.lastScale;
    if (partialState.isLongPress !== undefined) newState.isLongPress = partialState.isLongPress;
    if (partialState.errorMessage !== undefined) newState.errorMessage = partialState.errorMessage;
    if (partialState.isRendererReady !== undefined) newState.isRendererReady = partialState.isRendererReady;
    this.state = newState;
    this.notifyStateChange();
  }

  initialize(deviceId: string = '', password: string = ''): void {
    hilog.info(DOMAIN, TAG, 'ControlViewModel initialize - deviceId: %{public}s', deviceId);

    this.updateState({
      remoteDeviceId: deviceId,
      remoteDevicePassword: password
    });

    this.dependencies.remoteControlService.setConnectionCallback((connected: boolean) => {
      const newState = connected ? AppState.CONNECTED : AppState.DISCONNECTED;
      hilog.info(DOMAIN, TAG, 'Connection state: %{public}s', connected ? 'connected' : 'disconnected');
      this.updateState({ connectionState: newState });

      if (connected && this.state.remoteDeviceId) {
        setTimeout(() => {
          this.openRemoteScreen();
        }, 500);
      }
    });

    this.dependencies.remoteControlService.setTileScreenCallback(
      (data: TileRenderData) => {
        this.onTileRenderData(data);
      }
    );

    this.dependencies.remoteControlService.getPerformanceMonitor().start();

    const currentState = this.dependencies.remoteControlService.getConnectionState();
    if (currentState === ConnectionState.CONNECTED) {
      this.updateState({ connectionState: AppState.CONNECTED });
      if (deviceId) {
        this.openRemoteScreen();
      }
    }
  }

  private onTileRenderData(data: TileRenderData): void {
    if (!this.renderSession) {
      this.pendingTileData = data;
      return;
    }

    if (!this.renderSession.ready) {
      this.pendingTileData = data;
      hilog.info(DOMAIN, TAG, 'Buffering tile frame (session not ready), tiles=%{public}d', data.tiles.length);
      return;
    }

    if (this.pendingTileData) {
      this.pendingTileData = null;
    }

    const fw = data.frameWidth;
    const fh = data.frameHeight;

    if (this.state.screenWidth !== fw || this.state.screenHeight !== fh) {
      this.updateState({ screenWidth: fw, screenHeight: fh });

      this.renderSession.resize(fw, fh);

      if (this.resolutionChangeCallback) {
        this.resolutionChangeCallback(fw, fh);
      }
    }

    try {
      this.renderSession.renderTileRegions(data.tiles, fw, fh, true);

      if (!this.state.isRendererReady) {
        this.updateState({ isRendererReady: true });
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Render error: %{public}s', error instanceof Error ? error.message : String(error));
    }
  }

  dispose(): void {
    hilog.info(DOMAIN, TAG, 'ControlViewModel dispose');

    if (this.longPressTimer) {
      clearTimeout(this.longPressTimer);
      this.longPressTimer = null;
    }

    if (this.renderSession) {
      this.renderSession.detach();
      this.renderSession = null;
    }
    this.pendingTileData = null;

    try {
      this.dependencies.remoteControlService.closeRemoteScreen();
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'closeRemoteScreen failed: %{public}s', JSON.stringify(error));
    }

    this.stateSubscribers = [];
  }

  openRemoteScreen(): void {
    const remoteDeviceId = this.state.remoteDeviceId;
    const remoteDevicePassword = this.state.remoteDevicePassword;
    const connectionState = this.state.connectionState;

    hilog.info(DOMAIN, TAG, 'openRemoteScreen - deviceId: %{public}s, state: %{public}s',
      remoteDeviceId, connectionState);

    const deviceIdRegex = /^[a-zA-Z0-9]+$/;
    if (!deviceIdRegex.test(remoteDeviceId)) {
      hilog.warn(DOMAIN, TAG, 'Invalid device ID format');
      this.showToast('设备ID只能包含字母和数字', 3000);
      return;
    }

    if (!remoteDevicePassword) {
      hilog.warn(DOMAIN, TAG, 'Password is empty');
      this.showToast('请输入密码', 2000);
      return;
    }

    this.dependencies.remoteControlService.setDeviceInfo(remoteDeviceId, remoteDevicePassword);
    this.dependencies.remoteControlService.setRemoteControlPermission(true);

    if (connectionState === AppState.CONNECTED) {
      hilog.info(DOMAIN, TAG, 'Already connected, sending openRemoteScreen request');
      this.dependencies.remoteControlService.openRemoteScreen(
        remoteDeviceId,
        remoteDevicePassword
      );
    }
  }

  goBackAndCloseScreen(): void {
    try {
      this.dependencies.remoteControlService.closeRemoteScreen();
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'closeRemoteScreen failed: %{public}s', JSON.stringify(error));
    }
    this.goBack();
  }

  handleTouchStart(x: number, y: number): void {
    this.updateState({
      lastTouchX: x,
      lastTouchY: y,
      isLongPress: false
    });

    this.longPressTimer = setTimeout(() => {
      this.updateState({ isLongPress: true });
      this.sendMouseControl(x, y, 2);
    }, this.LONG_PRESS_DURATION);
  }

  handleTouchMove(x: number, y: number): void {
    if (this.longPressTimer) {
      clearTimeout(this.longPressTimer);
      this.longPressTimer = null;
    }

    this.updateState({
      lastTouchX: x,
      lastTouchY: y
    });
  }

  handleTouchEnd(x: number, y: number): void {
    if (this.longPressTimer) {
      clearTimeout(this.longPressTimer);
      this.longPressTimer = null;
    }

    if (!this.state.isLongPress) {
      this.sendMouseControl(x, y, 1);
    }
  }

  private sendMouseControl(x: number, y: number, button: number): void {
    try {
      const remotePoint = this.mapLocalToRemoteCoordinate(x, y);
      this.dependencies.remoteControlService.sendMouseControl(remotePoint.x, remotePoint.y, button, undefined);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'sendMouseControl failed: %{public}s', JSON.stringify(error));
    }
  }

  private mapLocalToRemoteCoordinate(localX: number, localY: number): CoordinatePoint {
    const remoteWidth = this.state.screenWidth > 0 ? this.state.screenWidth : Number.MAX_SAFE_INTEGER;
    const remoteHeight = this.state.screenHeight > 0 ? this.state.screenHeight : Number.MAX_SAFE_INTEGER;

    let remoteX = Math.round(localX);
    let remoteY = Math.round(localY);

    if (remoteWidth !== Number.MAX_SAFE_INTEGER) {
      remoteX = Math.max(0, Math.min(remoteWidth - 1, remoteX));
    }

    if (remoteHeight !== Number.MAX_SAFE_INTEGER) {
      remoteY = Math.max(0, Math.min(remoteHeight - 1, remoteY));
    }

    return { x: remoteX, y: remoteY };
  }

  handlePinchStart(): void {
    this.updateState({ lastScale: this.state.currentScale });
  }

  handlePinchUpdate(scale: number): void {
    let newScale = this.state.lastScale * scale;
    newScale = Math.max(this.MIN_SCALE, Math.min(this.MAX_SCALE, newScale));
    this.updateState({ currentScale: newScale });
  }

  handlePinchEnd(): void {
    this.updateState({ lastScale: this.state.currentScale });
  }

  handleThreeFingerPan(offsetY: number): void {
    const SWIPE_THRESHOLD = 50;
    if (Math.abs(offsetY) < SWIPE_THRESHOLD) return;

    if (offsetY > 0) {
      if (!this.state.isPanelVisible) {
        this.updateState({ isPanelVisible: true });
      }
    } else {
      if (this.state.isPanelVisible) {
        this.updateState({ isPanelVisible: false });
      }
    }
  }

  showPanel(): void {
    this.updateState({ isPanelVisible: true });
  }

  hidePanel(): void {
    this.updateState({ isPanelVisible: false });
  }

  resetZoom(): void {
    this.updateState({ currentScale: 1.0, lastScale: 1.0 });
  }

  showDragHint(): void {
    this.updateState({ isDragging: true });
  }

  hideDragHint(): void {
    this.updateState({ isDragging: false });
  }

  handleFileDrop(): void {
    this.showToast('文件拖拽功能暂不支持，请使用文件选择器上传', 3000);
  }

  async uploadFiles(files: UploadableFile[]): Promise<void> {
    for (let i = 0; i < files.length; i++) {
      const file = files[i];
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
        hilog.error(DOMAIN, TAG, 'upload failed: %{public}s', JSON.stringify(error));
        this.showToast(`${file.name} 上传失败`, 3000);
      }
    }
  }

  getState(): ControlPageState {
    return this.copyState(this.state);
  }

  setDeviceInfo(deviceId: string, password: string): void {
    this.updateState({
      remoteDeviceId: deviceId,
      remoteDevicePassword: password
    });
  }
}
