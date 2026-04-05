# 远程控制服务架构设计

## 1. 核心问题

当前架构存在以下问题：
1. ProtocolHandler 职责混乱（尝试解压视频流）
2. 压缩方法硬编码
3. 帧缓存管理分散
4. 两个代码路径造成混乱

## 2. 重新设计的架构

### 2.1 架构图

```
TCP 数据流
    ↓
TcpRepositoryImpl
    ↓
ProtocolHandler.parse()  ──────────────────────────────┐
    ↓                                              │
解析成功 → ConcreteCmd                              │
    ↓                                              │
RemoteControlService.processCommand()                │
    │                                              │
    ├── ResCapture → 启用视频流接收                │
    ├── ResPong → 心跳响应                        │
    └── ResCliInfo → 设备信息                      │
                                                      │
视频流数据 ──→ ConnectionManager ──→ RemoteControlService.onRawVideoData()
                                              │
                                              ↓
                                    CaptureProcessor
                                              │
                                              ↓
                                    WorkerRepository
                                              │
                                              ↓
                                    CaptureWorker (Worker线程)
                                              │
                                              ↓
                                    帧合并处理
                                              │
                                              ↓
                                    screenCallback (渲染)
```

### 2.2 职责划分

| 组件 | 职责 |
|------|------|
| **ProtocolHandler** | 只负责解析命令，不处理视频流 |
| **RemoteControlService** | 业务编排，命令处理，视频流触发 |
| **CaptureProcessor** | 帧合并逻辑，管理前一帧缓冲区 |
| **WorkerRepository** | 任务队列管理，发送任务到 Worker |
| **CaptureWorker** | 实际解压和图像组装（在 Worker 线程） |

## 3. 详细设计

### 3.1 ProtocolHandler（简化）

```typescript
// 只负责解析命令
export class ProtocolHandler implements IProtocolHandler {
  async processData(data: ArrayBuffer): Promise<ConcreteCmd[]> {
    // 使用 Worker 解析协议
    const result = await this.workerRepository.parseProtocol(parseTask);
    return result.commands.map(obj => ConcreteCmd.fromObject(obj));
  }
}
```

**移除**：`processDataAndCheckVideo` 方法

### 3.2 RemoteControlService

```typescript
export class RemoteControlService {
  // 视频流配置
  private videoConfig = {
    compressionMethod: CompressionMethod.ZSTD,
    enabled: false
  };

  // 处理命令
  private async processCommand(cmd: ConcreteCmd): Promise<void> {
    switch (cmd.type) {
      case CmdType.ResCapture:
        // 启用视频流接收
        this.videoConfig.enabled = true;
        break;
      case CmdType.ResCliInfo:
        // 处理设备信息
        break;
    }
  }

  // 处理原始视频数据
  async onRawVideoData(data: ArrayBuffer): Promise<void> {
    if (!this.videoConfig.enabled) {
      return;
    }

    // 发送到 Worker 处理
    const result = await this.workerRepository.processImage({
      imageData: data,
      compressionMethodOrdinal: this.videoConfig.compressionMethod.ordinal
    });

    // 帧合并
    const frameResult = this.captureProcessor.processFrame(result);

    // 渲染
    if (this.screenCallback) {
      this.screenCallback(frameResult.buffer, frameResult.width, frameResult.height, Date.now());
    }
  }
}
```

### 3.3 CaptureProcessor

```typescript
export class CaptureProcessor {
  private prevBuffer: Uint8Array | null = null;
  private prevWidth: number = 0;
  private prevHeight: number = 0;
  private lastFrameId: number = -1;

  processFrame(capture: {
    id: number;
    reset: boolean;
    width: number;
    height: number;
    tiles: TileData[];
  }): FrameResult {

    // 检查帧序号
    if (capture.id <= this.lastFrameId && this.lastFrameId !== -1) {
      // 乱序帧，尝试重新排序或丢弃
      console.warn(`Frame ${capture.id} out of order`);
    }

    let buffer: Uint8Array;
    const bufferSize = capture.width * capture.height * 4;

    if (capture.reset) {
      // 完整帧
      buffer = new Uint8Array(bufferSize);
    } else {
      // 增量帧，复用缓冲区
      if (this.prevBuffer && this.prevWidth === capture.width && this.prevHeight === capture.height) {
        buffer = this.prevBuffer;
      } else {
        buffer = new Uint8Array(bufferSize);
      }
    }

    // 绘制 tiles
    for (const tile of capture.tiles) {
      this.drawTile(buffer, tile, capture.width);
    }

    // 保存状态
    this.prevBuffer = buffer.slice();
    this.prevWidth = capture.width;
    this.prevHeight = capture.height;
    this.lastFrameId = capture.id;

    return {
      buffer,
      width: capture.width,
      height: capture.height,
      isKeyFrame: capture.reset
    };
  }

  reset(): void {
    this.prevBuffer = null;
    this.prevWidth = 0;
    this.prevHeight = 0;
    this.lastFrameId = -1;
  }
}
```

### 3.4 数据流

```
1. TCP 收到数据
       ↓
2. TcpRepositoryImpl.onSocketDataReceived(data)
       ↓
3. ProtocolHandler.processData(data)
       ↓
   ├─ 如果是命令 → 返回 ConcreteCmd[]
   └─ 如果不是命令 → 返回 []

4. RemoteControlService.processCommand(cmd) for each cmd
       ↓
5. 如果是 ResCapture → 设置 videoConfig.enabled = true

6. 如果视频流开启，ConnectionManager 收到原始数据
       ↓
7. RemoteControlService.onRawVideoData(data)
       ↓
8. CaptureProcessor.processFrame() + WorkerRepository.processImage()
       ↓
9. screenCallback(buffer, width, height)
       ↓
10. UI 渲染
```

## 4. 接口设计

### 4.1 IRemoteControlService

```typescript
interface IRemoteControlService {
  // 连接
  connect(): Promise<void>;
  disconnect(): void;

  // 事件回调
  setConnectionCallback(callback: ConnectionCallback): void;
  setScreenCallback(callback: ScreenCallback): void;
  setDeviceInfoCallback(callback: DeviceInfoCallback): void;

  // 输入控制
  sendControlEvent(event: RemoteControlEvent): Promise<void>;
  sendClipboard(text: string): Promise<void>;
}
```

### 4.2 IVideoStreamHandler

```typescript
interface IVideoStreamHandler {
  // 启用视频流
  enable(): void;

  // 禁用视频流
  disable(): void;

  // 处理原始数据
  processRawData(data: ArrayBuffer): Promise<void>;

  // 重置状态
  reset(): void;
}
```

## 5. 关键类图

```
IRemoteControlService
    │
    ├── RemoteControlService
    │       │
    │       ├── ConnectionManager (连接管理)
    │       ├── ProtocolHandler (命令解析)
    │       ├── CaptureProcessor (帧合并)
    │       │
    │       └── onRawVideoData(data) ──────────────────────┐
    │                                                       │
    │                                                       ↓
    │                               WorkerRepository ──→ CaptureWorker
    │                                                       ↑
    │                                                       │
    └───────────────────────────────────────────────────────┘
```

## 6. 实现要点

1. **ProtocolHandler 不处理视频流** - 只负责命令解析
2. **RemoteControlService 编排业务** - 决定何时启用视频流
3. **CaptureProcessor 帧合并** - 在主线程完成，使用前一帧缓冲区
4. **Worker 线程解压** - 不阻塞主线程
5. **压缩方法可配置** - 默认 ZSTD，可从配置读取
