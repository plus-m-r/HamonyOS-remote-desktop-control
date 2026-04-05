# Java 服务端协议实现确认文档

## 1. 确认的协议信息

### 1.1 Java 服务端发送视频流的完整流程

```
Java 被控端 (RemoteControlled)
    │
    ├─ captureEngine 捕获屏幕
    │
    ├─ compressorEngine 压缩 Capture 对象
    │
    ├─ onCompressed() 回调
    │     │
    │     └─ new CmdCapture(captureId, compressionMethod, config, compressed)
    │
    └─ fireCmd() → Netty Pipeline
          │
          └─ NettyEncoder.encode()
                │
                └─ 输出: Magic(1) + Type(1) + Length(4) + [CmdCapture.encode()]
```

**关键代码位置**: `client/src/main/java/io/github/springstudent/dekstop/client/core/RemoteControlled.java#L146-148`

```java
@Override
public void onCompressed(int captureId, CompressionMethod compressionMethod,
                          CompressorEngineConfiguration compressionConfiguration,
                          MemByteBuffer compressed) {
    fireCmd(new CmdCapture(captureId, compressionMethod, compressionConfiguration, compressed));
}
```

### 1.2 CmdCapture 命令线格式 (Wire Format)

**Java 源文件**: `common/src/main/java/io/github/springstudent/dekstop/common/command/CmdCapture.java`

#### CmdCapture.encode() 输出的数据格式 (不含协议头):

```
+-------------------+
| ID (4 bytes)      | big-endian int
+-------------------+
| Method (1 byte)   | CompressionMethod ordinal: 0=NONE, 1=ZIP, 2=XZ, 3=ZSTD
+-------------------+
| HasConfig (1 byte)| 0x01=有配置, 0x00=无配置
+-------------------+
| [Config] (10 bytes, optional) |
|   - ConfigMethod (1)         |
|   - UseCache (1)             |
|   - MaxSize (4)              |
|   - PurgeSize (4)            |
+-------------------+
| PayloadLength (4 bytes) | big-endian int
+-------------------+
| Payload (variable)   | 压缩后的 Capture 数据
+-------------------+
```

#### 带协议头的完整数据包:

```
+-------------------+
| Magic (1 byte)    | = 0x64 (100)
+-------------------+
| Type (1 byte)     | = 0x09 (CmdType.Capture ordinal)
+-------------------+
| Length (4 bytes)  | = wireSize = 10 [+ 10] + payload.size()
+-------------------+
| [CmdCapture 数据]  | 如上所述
+-------------------+
```

#### Java 代码验证:

```java
// CmdCapture.java
@Override
public int getWireSize() {
    if (compressionConfiguration == null) {
        return 10 + payload.size();  // 无配置: 10 + payload
    } else {
        return 10 + 10 + payload.size();  // 有配置: 20 + payload
    }
}

@Override
public void encode(ByteBuf out) throws IOException {
    out.writeInt(id);
    encodeEnum(out, compressionMethod);  // 1 byte
    out.writeByte(compressionConfiguration != null ? 1 : 0);
    if (compressionConfiguration != null) {
        new CmdCompressorConf(compressionConfiguration).encode(out);  // 10 bytes
    }
    out.writeInt(payload.size());
    out.writeBytes(payload.getInternal(), 0, payload.size());
}
```

### 1.3 压缩后的 Payload 内部格式

**Java 源文件**: `client/src/main/java/io/github/springstudent/dekstop/client/squeeze/Compressor.java`

#### Compressor.compress() 输出的格式:

```
+-------------------+
| ID (4 bytes)      | 帧序号
+-------------------+
| Reset (1 byte)    | 0x01 = 完整帧, 0x00 = 增量帧
+-------------------+
| Skipped (1 byte)  | 跳过的瓦片数
+-------------------+
| Merged (1 byte)   | 合并的帧数
+-------------------+
| Width (2 bytes)   | 屏幕宽度 (short)
+-------------------+
| Height (2 bytes)  | 屏幕高度 (short)
+-------------------+
| TileWidth (2 bytes) |
+-------------------+
| TileHeight (2 bytes)|
+-------------------+
| [Tiles Data]      | 可变长度，见下文
+-------------------+
```

#### Tile 数据编码:

```
+-------------------+
| MarkerCount (1 byte) | 正数=非空瓦片数, 负数=空瓦片数的相反数-1
+-------------------+
[对于每个非空瓦片:]
|   Value (2 bytes) |
|     - [0-255]    | 单级灰度值
|     - 256        | 缓存的瓦片 (后面跟 cacheId: 4 bytes)
|     - [-32768~-1]| 未缓存的彩色瓦片 (值为数据长度负数)
+-------------------+
[对于空瓦片:]
|   跳过相应数量
+-------------------+
```

### 1.4 Java 控制端接收流程

**Java 源文件**: `client/src/main/java/io/github/springstudent/dekstop/client/core/RemoteController.java`

```java
@Override
public void onCapture(int id, CompressionMethod method,
                      CompressorEngineConfiguration config,
                      MemByteBuffer payload) {
    // 使用指定的压缩方法和配置解压
    Capture capture = Compressor.get(method).decompress(cache, payload);
    // 处理帧...
}
```

---

## 2. 关键发现总结

### 2.1 确认的事实

| 项目 | 确认值 |
|------|--------|
| Magic Number | 0x64 (100) |
| CmdType.Capture ordinal | 9 |
| 压缩方法 ordinal | 0=NONE, 1=ZIP, 2=XZ, 3=ZSTD |
| 默认压缩方法 | ZSTD (3) |
| HasConfig 标志 | 0x01=有, 0x00=无 |
| Config 结构 | Method(1) + UseCache(1) + MaxSize(4) + PurgeSize(4) = 10 bytes |

### 2.2 Java 服务端发送的数据包示例

**无配置情况 (HasConfig=0):**
```
字节位置:  0     1     2-5    6     7     8-11   12-15       16+
值:       0x64  0x09  Length  ID    Method 0x00  PayloadLen  [Payload...]
```

**有配置情况 (HasConfig=1):**
```
字节位置:  0     1     2-5    6     7     8     9-12    13-16    17-20    21-24       25+
值:       0x64  0x09  Length  ID    Method 0x01  Config...  PayloadLen  [Payload...]
```

---

## 3. HarmonyOS 客户端需要修复的问题

### 3.1 问题 1: CmdCapture 命令被错误解析

**现状**: `ProtocolWorker.extractCommands()` 会将 CmdCapture 数据包当作普通命令解析，导致数据错位。

**原因**: 视频流数据以 `0x64 0x09 ...` 开头，会被 `extractCommands()` 识别为命令。

**修复方案**:
1. 让 `extractCommands()` 识别 `CmdType.Capture (ordinal=9)`
2. 将 `payload` (压缩数据) 和 `compressionMethod` 一起返回
3. 传递给 `onRawVideoData(payload, compressionMethod)`

### 3.2 问题 2: hasCompressionConfig 处理不一致

**现状**: `CmdCodec.decodeCaptureCmd()` 跳过 10 字节 config，但 payloadLength 读取位置依赖 HasConfig 标志。

**Java 代码**:
```java
// NettyDecoder.java 调用
CmdCapture.decode(byteBuf);  // byteBuf 已跳过 Magic + Type + Length

// CmdCapture.decode() 内部
final int id = in.readInt();  // 4 bytes
final CompressionMethod method = decodeEnum(in, CompressionMethod.class);  // 1 byte
if (in.readByte() == 1) {  // HasConfig
    compressionConfiguration = CmdCompressorConf.decode(in).getConfiguration();
}
final int len = in.readInt();  // PayloadLength
```

**修复**: 确保鸿蒙端的 `decodeCaptureCmd()` 与 Java 保持完全一致。

### 3.3 问题 3: compressionMethod 未从命令提取

**现状**: `RemoteControlService` 硬编码 `compressionMethodOrdinal: 3` (ZSTD)。

**修复**: 从解码出的 `CmdCapture` 命令中提取 `compressionMethod` 传递给 Worker。

---

## 4. 正确的处理流程

### 4.1 接收数据时

```
ConnectionManager.receive(data)
    ↓
ProtocolHandler.processData(data)
    ↓
ProtocolWorker.extractCommands(data)
    ↓
CmdCodec.decode(cmdBuffer)
    ├─ 如果是 CmdCapture (Type=9):
    │     └─ decodeCaptureCmd() → ConcreteCmd
    │
    └─ 其他命令 → ConcreteCmd
    ↓
ProtocolHandler.commandCallback (通过 processData 返回)
    ↓
RemoteControlService.processCommand(cmd)
    ├─ CmdType.Capture → handleCaptureData()
    │     ├─ 提取: imageData, compressionMethod
    │     └─ onRawVideoData(payload, compressionMethod)
    │
    └─ 其他命令 → 各专用处理器
```

### 4.2 处理视频流时

```
handleCaptureData(cmd)
    ├─ 提取 cmd.getData().imageData (压缩数据)
    ├─ 提取 cmd.getData().compressionMethod (压缩方法)
    └─ onRawVideoData(payload, compressionMethod)
    ↓
onRawVideoData(payload, compressionMethod)
    ↓
WorkerRepository.processImage({
    imageData: payload,  // 纯压缩数据
    compressionMethodOrdinal: method
})
    ↓
CaptureWorker:
    ├─ Compressor.get(method).decompress()
    ├─ Capture.drawToBuffer()
    └─ 返回 imageBuffer
    ↓
CaptureProcessor.processFrame()
    ↓
screenCallback(buffer)
```

---

## 5. 已完成的代码修改

### 5.1 RemoteControlService 修改

**文件**: `HarmonOS_remote_desktop_control_client/entry/src/main/ets/services/remote/RemoteControlService.ets`

**修改内容**:

1. 在 `processCommand()` 中添加 `CmdType.Capture` 处理:
```typescript
case CmdType.Capture:
  this.handleCaptureData(cmd);
  break;
```

2. 添加 `handleCaptureData()` 方法:
```typescript
private async handleCaptureData(cmd: ConcreteCmd): Promise<void> {
  const data = cmd.getData();
  const imageData = data.imageData;
  const compressionMethod = data.compressionMethod || 3; // 默认 ZSTD

  // 将 imageData 转换为 ArrayBuffer
  let payloadBuffer: ArrayBuffer;
  if (typeof imageData === 'string') {
    payloadBuffer = this.decodeImageData(imageData);
  } else {
    payloadBuffer = imageData as ArrayBuffer;
  }

  await this.onRawVideoData(payloadBuffer, compressionMethod);
}
```

3. 修改 `onRawVideoData()` 签名:
```typescript
private async onRawVideoData(
    data: ArrayBuffer,
    compressionMethod: number = 3
): Promise<void> {
    const imageTask: ImageProcessTask = {
        imageData: data,
        compressionMethodOrdinal: compressionMethod
    };
    // ...
}
```

### 5.2 架构说明

**解耦原则**:
- `ProtocolHandler`: 只负责解析命令，不处理视频流
- `RemoteControlService`: 负责业务编排，处理 `CmdCapture` 命令
- `CaptureProcessor`: 负责帧合并和缓冲区复用（在主线程）
- `CaptureWorker`: 负责解压和绘制（在 Worker 线程）

**数据流**:
1. `ConnectionManager` 收到数据
2. `ProtocolHandler` 解析出命令
3. `RemoteControlService.processCommand()` 根据命令类型分发
4. `CmdCapture` → `handleCaptureData()` → `onRawVideoData()`
5. `WorkerRepository` 发送到 Worker 处理
6. 处理结果通过 `CaptureProcessor` 帧合并
7. 最终通过 `screenCallback` 渲染

---

## 6. 附录: Java CmdType 枚举

**源文件**: `common/src/main/java/io/github/springstudent/dekstop/common/command/CmdType.java`

```java
public enum CmdType {
    ReqPing,          // 0
    ReqOpen,          // 1
    ReqCapture,       // 2
    ReqRemoteClipboard, // 3
    ResOpen,          // 4
    ResCliInfo,       // 5
    ResCapture,       // 6
    ResPong,          // 7
    ResRemoteClipboard, // 8
    Capture,          // 9  <-- 视频流命令
    CompressorConfig, // 10
    CaptureConfig,    // 11
    KeyControl,       // 12
    MouseControl,     // 13
    ClipboardText,    // 14
    ClipboardTransfer, // 15
    ReqCliInfo,       // 16
    SelectScreen,     // 17
    ChangePwd         // 18
}
```

---

## 7. 附录: CompressorEngineConfiguration 结构

**源文件**: `common/src/main/java/io/github/springstudent/dekstop/common/configuration/CompressorEngineConfiguration.java`

```java
public class CompressorEngineConfiguration {
    private CompressionMethod method;  // 压缩方法
    private boolean useCache;          // 是否使用瓦片缓存
    private int maxSize;              // 最大缓存大小
    private int purgeSize;            // 清理大小
}
```

**线格式 (10 bytes)**:
```
Method (1 byte) + UseCache (1 byte) + MaxSize (4 bytes) + PurgeSize (4 bytes)
```

---

*文档生成时间: 2026-04-03*
*基于 Java 服务端代码分析确认*
