import { ConnectionState, RemoteControlEvent, DeviceValidationResult } from '../../models/DeviceInfo';
import { ClientInfoCallback, ConnectionCallback, ClipboardCallback } from '../../models/CmdProtocol';
import { UIContext } from '@kit.ArkUI';
import { PerformanceMonitor } from '../../utils/PerformanceMonitor';
import { TileRegion } from '@plusml/arkzero';

export interface RemoteControlServiceConfig {
  host: string;
  port: number;
  maxReconnectAttempts: number;
  reconnectDelay: number;
  heartbeatInterval: number;
}

export interface DeviceCredentials {
  deviceCode: string;
  password: string;
}

export type ScreenCallback = (data: ArrayBuffer, width: number, height: number, timestamp: number) => void;

export interface TileRenderData {
  tiles: TileRegion[];
  frameWidth: number;
  frameHeight: number;
  captureId: number;
  isReset: boolean;
}

export type TileScreenCallback = (data: TileRenderData) => void;

export type DeviceInfoCallback = (deviceCode: string, password: string) => void;

export interface IRemoteControlService {
  connect(onSuccess?: () => void, onError?: (error: string) => void): Promise<void>;
  disconnect(): Promise<void>;
  getConnectionState(): ConnectionState;
  setConnectionCallback(callback: ConnectionCallback): void;
  openRemoteScreen(deviceCode: string, password: string): Promise<void>;
  closeRemoteScreen(): void;
  setScreenCallback(callback: ScreenCallback): void;
  setTileScreenCallback(callback: TileScreenCallback): void;
  sendControlEvent(event: RemoteControlEvent): Promise<void>;
  sendMouseControl(x: number, y: number, action: number, wheelDelta?: number): Promise<void>;
  sendKeyControl(keyCode: number, pressed: boolean): Promise<void>;
  setDeviceInfoCallback(callback: DeviceInfoCallback): void;
  setDeviceInfo(deviceCode: string, password: string): void;
  getLocalDeviceInfo(): DeviceCredentials;
  getRemoteDeviceInfo(): DeviceCredentials;
  getPerformanceMonitor(): PerformanceMonitor;
  setRemoteControlPermission(enabled: boolean): void;
  validateDevice(deviceCode: string, password: string): Promise<DeviceValidationResult>;
  requestClipboard(): Promise<void>;
  sendClipboardText(text: string): Promise<void>;
  sendClipboardFile(fileInfoId: string, fileName: string): Promise<void>;
  setClipboardCallback(callback: ClipboardCallback): void;
  changePassword(oldPassword: string, newPassword: string): Promise<void>;
  updateConnectionTarget(host: string, port: number): void;
  cleanup(): void;
}
