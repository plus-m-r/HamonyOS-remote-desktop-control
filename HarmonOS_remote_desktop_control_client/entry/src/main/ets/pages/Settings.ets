// 设置页面 - 配置文件传输和剪贴板同步选项
import { AppStateManager, getSyncSettings, setSyncSettings, SyncSettings } from '../state/AppStateManager';
import { promptAction, router } from '@kit.ArkUI';
import hilog from '@ohos.hilog';

const TAG = 'SettingsPage';
const DOMAIN = 0x0000;

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

  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, 'Settings页面开始加载');
    // 从AppStateManager加载设置
    this.loadSettings();
  }

  loadSettings(): void {
    // 从AppStateManager加载设置
    const savedSettings: SyncSettings | undefined = getSyncSettings();
    if (savedSettings) {
      // 手动合并设置
      this.syncSettings.autoUploadFiles = savedSettings.autoUploadFiles;
      this.syncSettings.showFileProgress = savedSettings.showFileProgress;
      this.syncSettings.autoSyncClipboard = savedSettings.autoSyncClipboard;
      this.syncSettings.syncInterval = savedSettings.syncInterval;
      this.syncSettings.syncTextOnly = savedSettings.syncTextOnly;
      this.syncSettings.showTransferNotifications = savedSettings.showTransferNotifications;
      this.syncSettings.showClipboardNotifications = savedSettings.showClipboardNotifications;
    }
  }

  saveSettings(): void {
    // 保存设置到AppStateManager
    setSyncSettings(this.syncSettings);

    this.showToast('设置已保存', 2000);
  }

  @Builder
  SettingItem(title: string, subtitle: string) {
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
      }
      .width('100%')
      .padding(16)
    }
    .backgroundColor('#fff')
    .borderRadius(8)
    .margin({ bottom: 12 })
  }

  @Builder
  ToggleSettingItem(title: string, subtitle: string, isOn: boolean, onChange: (value: boolean) => void) {
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
        Column() {
          Toggle({ type: ToggleType.Switch, isOn: isOn })
            .onChange(onChange)
        }
      }
      .width('100%')
      .padding(16)
    }
    .backgroundColor('#fff')
    .borderRadius(8)
    .margin({ bottom: 12 })
  }

  @Builder
  InputSettingItem(title: string, subtitle: string, value: string, onChange: (value: string) => void) {
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
        Column() {
          TextInput({ placeholder: '1000', text: value })
            .width(100)
            .onChange(onChange)
        }
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
          .onClick((): void => this.routerBack())
        
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
          this.ToggleSettingItem(
            '自动上传拖拽文件',
            '当拖拽文件到远程屏幕时自动上传',
            this.syncSettings.autoUploadFiles,
            (value: boolean) => {
              this.syncSettings.autoUploadFiles = value;
              this.saveSettings();
            }
          )
          this.ToggleSettingItem(
            '显示文件传输进度',
            '上传/下载文件时显示进度通知',
            this.syncSettings.showFileProgress,
            (value: boolean) => {
              this.syncSettings.showFileProgress = value;
              this.saveSettings();
            }
          )
          
          // 剪贴板同步设置
          Text('剪贴板同步设置')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#182431')
            .margin({ top: 24, bottom: 16, left: 16 })
          this.ToggleSettingItem(
            '自动同步剪贴板',
            '连接建立后自动开始同步剪贴板',
            this.syncSettings.autoSyncClipboard,
            (value: boolean) => {
              this.syncSettings.autoSyncClipboard = value;
              this.saveSettings();
            }
          )
          this.ToggleSettingItem(
            '仅同步文本',
            '只同步文本内容，不同步文件',
            this.syncSettings.syncTextOnly,
            (value: boolean) => {
              this.syncSettings.syncTextOnly = value;
              this.saveSettings();
            }
          )
          this.InputSettingItem(
            '同步间隔',
            '剪贴板检查和同步的时间间隔（毫秒）',
            this.syncSettings.syncInterval.toString(),
            (value: string) => {
              const interval = parseInt(value);
              if (!isNaN(interval) && interval > 0) {
                this.syncSettings.syncInterval = interval;
                this.saveSettings();
              }
            }
          )
          
          // 通知设置
          Text('通知设置')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#182431')
            .margin({ top: 24, bottom: 16, left: 16 })
          this.ToggleSettingItem(
            '显示传输通知',
            '显示文件传输相关的通知',
            this.syncSettings.showTransferNotifications,
            (value: boolean) => {
              this.syncSettings.showTransferNotifications = value;
              this.saveSettings();
            }
          )
          this.ToggleSettingItem(
            '显示剪贴板通知',
            '显示剪贴板同步相关的通知',
            this.syncSettings.showClipboardNotifications,
            (value: boolean) => {
              this.syncSettings.showClipboardNotifications = value;
              this.saveSettings();
            }
          )
          // 保存按钮
          Button('保存设置')
            .width('80%')
            .height(48)
            .margin({ top: 32, bottom: 32 })
            .onClick((): void => this.saveSettings())
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
