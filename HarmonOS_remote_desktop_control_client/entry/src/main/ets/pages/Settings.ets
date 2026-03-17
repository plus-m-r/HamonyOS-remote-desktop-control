// 设置页面 - 配置文件传输和剪贴板同步选项
import { AppStateManager } from '../state/AppStateManager';
import prompt from '@ohos.promptAction';
import hilog from '@ohos.hilog';
import router from '@ohos.router';

const TAG = 'SettingsPage';
const DOMAIN = 0x0000;

interface SyncSettings {
  // 文件传输
  autoUploadFiles: boolean;      // 自动上传拖拽文件
  showFileProgress: boolean;     // 显示文件传输进度
  
  // 剪贴板同步
  autoSyncClipboard: boolean;    // 自动同步剪贴板
  syncInterval: number;          // 同步间隔（毫秒）
  syncTextOnly: boolean;         // 仅同步文本（不包含文件）
  
  // 通知设置
  showTransferNotifications: boolean;    // 显示传输通知
  showClipboardNotifications: boolean;   // 显示剪贴板通知
}

@Entry
@Component
struct Settings {
  @State syncSettings: SyncSettings = {
    autoUploadFiles: true,
    showFileProgress: true,
    autoSyncClipboard: true,
    syncInterval: 1000,
    syncTextOnly: false,
    showTransferNotifications: true,
    showClipboardNotifications: true
  };
  
  aboutToAppear() {
    hilog.info(DOMAIN, TAG, 'Settings页面开始加载');
    // 从AppStateManager加载设置
    this.loadSettings();
  }
  
  loadSettings() {
    // 从AppStateManager加载设置
    const savedSettings = AppStateManager.getSyncSettings();
    if (savedSettings) {
      this.syncSettings = { ...this.syncSettings, ...savedSettings };
    }
  }
  
  saveSettings() {
    // 保存设置到AppStateManager
    AppStateManager.setSyncSettings(this.syncSettings);
    
    prompt.showToast({
      message: '设置已保存',
      duration: 2000
    });
  }
  
  @Builder
  buildSettingItem(title: string, subtitle: string, content: () => void) {
    Column() {
      Row() {
        Column() {
          Text(title)
            .fontSize(16)
            .fontColor('#182431')
          
          if (subtitle) {
            Text(subtitle)
              .fontSize(12)
              .fontColor('#6B7280')
              .margin({ top: 4 })
          }
        }
        .flexGrow(1)
        
        content()
      }
      .width('100%')
      .padding(16)
    }
    .backgroundColor('#fff')
    .borderRadius(8)
    .margin({ bottom: 12 })
  }
  
  build() {
    Column() {
      // 顶部标题
      Row() {
        Button('返回')
          .onClick(() => router.back())
        
        Text('设置')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor('#182431')
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
      
      // 设置内容
      Scroll() {
        Column() {
          // 文件传输设置
          Text('文件传输设置')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#182431')
            .margin({ top: 24, bottom: 16, left: 16 })
          
          this.buildSettingItem(
            '自动上传拖拽文件',
            '当拖拽文件到远程屏幕时自动上传',
            () => (
              Toggle({ type: ToggleType.Switch })
                .isOn(this.syncSettings.autoUploadFiles)
                .onChange((value) => {
                  this.syncSettings.autoUploadFiles = value;
                  this.saveSettings();
                })
            )
          )
          
          this.buildSettingItem(
            '显示文件传输进度',
            '上传/下载文件时显示进度通知',
            () => (
              Toggle({ type: ToggleType.Switch })
                .isOn(this.syncSettings.showFileProgress)
                .onChange((value) => {
                  this.syncSettings.showFileProgress = value;
                  this.saveSettings();
                })
            )
          )
          
          // 剪贴板同步设置
          Text('剪贴板同步设置')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#182431')
            .margin({ top: 24, bottom: 16, left: 16 })
          
          this.buildSettingItem(
            '自动同步剪贴板',
            '连接建立后自动开始同步剪贴板',
            () => (
              Toggle({ type: ToggleType.Switch })
                .isOn(this.syncSettings.autoSyncClipboard)
                .onChange((value) => {
                  this.syncSettings.autoSyncClipboard = value;
                  this.saveSettings();
                })
            )
          )
          
          this.buildSettingItem(
            '仅同步文本',
            '只同步文本内容，不同步文件',
            () => (
              Toggle({ type: ToggleType.Switch })
                .isOn(this.syncSettings.syncTextOnly)
                .onChange((value) => {
                  this.syncSettings.syncTextOnly = value;
                  this.saveSettings();
                })
            )
          )
          
          this.buildSettingItem(
            '同步间隔',
            '剪贴板检查和同步的时间间隔（毫秒）',
            () => (
              TextInput({
                text: this.syncSettings.syncInterval.toString(),
                placeholder: '1000'
              })
              .width(100)
              .onChange((value) => {
                const interval = parseInt(value);
                if (!isNaN(interval) && interval > 0) {
                  this.syncSettings.syncInterval = interval;
                  this.saveSettings();
                }
              })
            )
          )
          
          // 通知设置
          Text('通知设置')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#182431')
            .margin({ top: 24, bottom: 16, left: 16 })
          
          this.buildSettingItem(
            '显示传输通知',
            '显示文件传输相关的通知',
            () => (
              Toggle({ type: ToggleType.Switch })
                .isOn(this.syncSettings.showTransferNotifications)
                .onChange((value) => {
                  this.syncSettings.showTransferNotifications = value;
                  this.saveSettings();
                })
            )
          )
          
          this.buildSettingItem(
            '显示剪贴板通知',
            '显示剪贴板同步相关的通知',
            () => (
              Toggle({ type: ToggleType.Switch })
                .isOn(this.syncSettings.showClipboardNotifications)
                .onChange((value) => {
                  this.syncSettings.showClipboardNotifications = value;
                  this.saveSettings();
                })
            )
          )
          
          // 保存按钮
          Button('保存设置')
            .width('80%')
            .height(48)
            .margin({ top: 32, bottom: 32 })
            .onClick(() => this.saveSettings())
        }
        .padding(16)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f8f8f8')
  }
}
