# HarmonyOS 客户端压缩传输协议分析

## 1. 概述

HarmonyOS 客户端接收来自 Java 服务端（被控端）的屏幕数据，采用**分块压缩传输**机制，只传输变化的屏幕区域以节省带宽。

## 2. Capture 对象完整结构

### 2.1 Java 客户端 Capture 类

**文件位置**: `client/src/main/java/io/github/springstudent/dekstop/client/bean/Capture.java`

```java
public class Capture {
    private final int id;                      // 帧序号
    private final boolean reset;               // TRUE=完整帧，FALSE=增量帧
    private final AtomicInteger skipped;        // 跳过的瓦片数
    private final AtomicInteger merged;         // 合并的帧数
    private final Dimension captureDimension;  // 屏幕尺寸 (width x height)
    private final Dimension tileDimension;     // 瓦片尺寸 (通常 32x32)
    private final CaptureTile[] dirty;         // 变化的瓦片数组
}
```

### 2.2 HarmonyOS 客户端 Capture 类

**文件位置**: `HarmonOS_remote_desktop_control_client/entry/src/main/ets/squeeze/Capture.ets`

```typescript
export class Capture {
  readonly id: number;           // 帧序号
  readonly reset: boolean;        // TRUE=完整帧，FALSE=增量帧
  readonly skipped: number;       // 跳过的瓦片数
  readonly merged: number;         // 合并的帧数
  readonly width: number;         // 屏幕宽度
  readonly height: number;        // 屏幕高度
  readonly tileWidth: number;     // 瓦片宽度
  readonly tileHeight: number;    // 瓦片高度
  readonly dirtyTiles: (CaptureTile | null)[];  // 变化的瓦片数组
}
```

## 3. CaptureTile 对象结构

### 3.1 Java 客户端 CaptureTile 类

**文件位置**: `client/src/main/java/io/github/springstudent/dekstop/client/bean/CaptureTile.java`

```java
public class CaptureTile {
    private final long checksum;           // 校验和 (Adler32)
    private final Position position;       // 瓦片位置 (x, y)
    private final int width;               // 瓦片宽度
    private final int height;              // 瓦片高度
    private final MemByteBuffer capture;   // 压缩的像素数据
    private final byte singleLevel;        // 单级灰度值 (-1=多彩)
    private final boolean fromCache;        // 是否来自缓存
}
```

### 3.2 HarmonyOS 客户端 CaptureTile 类

**文件位置**: `HarmonOS_remote_desktop_control_client/entry/src/main/ets/squeeze/CaptureTile.ets`

```typescript
export class CaptureTile {
  readonly checksum: number;      // 校验和
  readonly x: number;             // 瓦片X坐标
  readonly y: number;             // 瓦片Y坐标
  readonly width: number;          // 瓦片宽度
  readonly height: number;         // 瓦片高度
  readonly capture: MemByteBuffer; // 压缩的像素数据
  readonly singleLevel: number;    // 单级灰度值 (-1=多彩)
  readonly fromCache: boolean;      // 是否来自缓存
}
```

## 4. 关键字段详解

### 4.1 reset 标志（最重要）

```typescript
readonly reset: boolean;
```

| 值 | 含义 | 处理方式 |
|----|------|----------|
| `true` | **完整帧** | 忽略前一帧，直接使用新数据创建图像 |
| `false` | **增量帧** | 将 dirty tiles 合并到前一帧 |

**代码位置**: `HarmonOS_remote_desktop_control_client/entry/src/main/ets/squeeze/Capture.ets#L9-L10`

```typescript
readonly id: number;
readonly reset: boolean;  // <-- 关键字段
```

### 4.2 屏幕和瓦片尺寸

```typescript
readonly width: number;      // 屏幕宽度 (如 1920)
readonly height: number;    // 屏幕高度 (如 1080)
readonly tileWidth: number;  // 瓦片宽度 (通常 32)
readonly tileHeight: number; // 瓦片高度 (通常 32)
```

### 4.3 dirtyTiles 数组

```typescript
readonly dirtyTiles: (CaptureTile | null)[];
```

**含义**: 只包含**发生变化**的瓦片，其他位置为 `null`

**处理逻辑**:
```
遍历 dirtyTiles:
  if tile !== null:
    将 tile 数据写入 buffer 的 (tile.x, tile.y) 位置
  else:
    跳过，使用 prevBuffer 中该位置的旧数据
```

### 4.4 单级灰度 (singleLevel)

```typescript
readonly singleLevel: number;  // -1=多彩图像，其他值=灰度值(0-255)
```

**判断逻辑**:
```typescript
const isGray = this.dirtyTiles.some(tile =>
  tile !== null && tile.capture.size() === tile.width * tile.height
);
```

| 值 | 含义 | 像素格式 |
|----|------|----------|
| `-1` | 多彩图像 | ARGB (4字节/像素) |
| `0-255` | 单级灰度 | 灰度 (1字节/像素) |

## 5. 数据合并算法

### 5.1 Java 客户端合并逻辑

**文件位置**: `client/src/main/java/io/github/springstudent/dekstop/client/bean/Capture.java#L129-L152`

```java
private void doMergeDirtyTiles(Capture older) {
    // 如果瓦片数量不同，说明是完整帧，保持最新
    if (dirty.length != older.getDirty().length) {
        return; // we're keeping the newest (FULL capture anyway)
    }

    CaptureTile[] olderDirty = older.getDirty();
    for (int idx = 0; idx < dirty.length; idx++) {
        // 合并规则:
        // this.x, this.y 都有 → 用 this.tile (当前帧)
        // 只有 older 有   → 用 older.tile (保持不变)
        // 只有 this 有   → 用 this.tile (新变化)
        if (olderDirty[idx] != null && dirty[idx] == null) {
            dirty[idx] = olderDirty[idx];
        }
    }
}
```

### 5.2 HarmonyOS 客户端图像组装

**文件位置**: `HarmonOS_remote_desktop_control_client/entry/src/main/ets/squeeze/Capture.ets#L41-L134`

```typescript
createImageBuffer(prevBuffer: Uint8Array | null, prevWidth: number, prevHeight: number): Uint8Array {
    const capWidth = this.width;
    const capHeight = this.height;

    // 检查是否需要创建新缓冲区
    if (prevBuffer !== null && capWidth === prevWidth && capHeight === prevHeight && prevBuffer.length === bufferSize) {
        buffer = prevBuffer;  // 复用前一帧缓冲区
    } else {
        buffer = bufferPool.acquireBuffer(bufferSize);  // 创建新缓冲区
    }

    // 遍历所有瓦片
    for (const tile of this.dirtyTiles) {
        if (tile === null || tile.capture === null) {
            continue;  // 跳过空瓦片，使用旧数据
        }

        // 计算目标位置
        let destPos = tile.y * capWidthByteSize + tile.x * 4;

        // 根据数据类型处理
        if (isGray) {
            this.processGrayData(buffer, src, tileWidth, tileHeight, destPos, capWidthByteSize, bufferSize);
        } else {
            this.processArgbData(buffer, src, tileWidth, tileHeight, destPos, capWidthByteSize, bufferSize);
        }
    }

    return buffer;
}
```

## 6. 压缩方法

### 6.1 压缩方法枚举

**Java 端**: `common/src/main/java/io/github/springstudent/dekstop/common/bean/CompressionMethod.java`

```java
public enum CompressionMethod {
    NONE(0),   // 无压缩
    ZIP(1),    // ZIP 压缩
    XZ(2),     // XZ 压缩
    ZSTD(3);   // ZSTD 压缩 (默认)
}
```

### 6.2 数据传输格式

**CmdCapture 命令完整数据包 (通过网络传输)**:
```
+-------------------+
| Magic (1 byte)    | = 0x64 (100)
+-------------------+
| Type (1 byte)     | = 0x09 (CmdCapture ordinal = 9)
+-------------------+
| Length (4 bytes)  | = wireSize = 10 [+ 10] + payload.size()
+-------------------+
| [数据体部分]        | 见下方详述
+-------------------+
```

**CmdCapture 数据体 (CmdCapture.encode() 输出)**:
```
+-------------------+
| ID (4 bytes)      | 帧序号 (big-endian)
+-------------------+
| Method (1 byte)   | 压缩方法 ordinal: 0=NONE, 1=ZIP, 2=XZ, 3=ZSTD
+-------------------+
| HasConfig (1 byte)| 0x01=有配置, 0x00=无配置
+-------------------+
| [Config] (10 bytes, optional) |
|   - Method (1)    | 配置压缩方法
|   - UseCache (1)  | 是否使用缓存
|   - MaxSize (4)   | 最大缓存大小
|   - PurgeSize (4) | 清理大小
+-------------------+
| PayloadLength (4) | 压缩数据长度 (big-endian)
+-------------------+
| Payload (variable)| 压缩后的 Capture 数据 (见 6.3)
+-------------------+

### 6.3 Payload 内部格式 (Capture 对象序列化)

**位置**: `client/src/main/java/io/github/springstudent/dekstop/client/squeeze/Compressor.java` - `compress()` 方法

```
+-------------------+
| ID (4 bytes)      | 帧序号
+-------------------+
| Reset (1 byte)    | 0x01=完整帧, 0x00=增量帧
+-------------------+
| Skipped (1 byte)  | 跳过的瓦片数
+-------------------+
| Merged (1 byte)   | 合并的帧数
+-------------------+
| Width (2 bytes)   | 屏幕宽度 (short)
+-------------------+
| Height (2 bytes)  | 屏幕高度 (short)
+-------------------+
| TileWidth (2 bytes)|
+-------------------+
| TileHeight (2 bytes)|
+-------------------+
| [Tiles Data]      | 可变长度，见下文
+-------------------+
```

**Tile 数据编码** (每组):
```
+-------------------+
| MarkerCount (1 byte) | 正数=非空瓦片数, 负数=(-N+1)空瓦片数
+-------------------+
[对于非空瓦片:]
|   Value (2 bytes) |
|     - [0-255]    | 单级灰度值
|     - 256        | 缓存的瓦片 (后面跟 cacheId: 4 bytes)
|     - [-32768~-1]| 未缓存的彩色瓦片 (值为数据长度负数)
+-------------------+
[对于空瓦片:]
|   跳过相应数量
+-------------------+
```

## 7. 处理流程

### 7.1 完整帧处理 (reset=true)

```
1. 接收压缩数据
2. 解压得到 Capture 对象
3. 检查 reset === true
4. 创建新缓冲区
5. 组装 dirty tiles 到缓冲区
6. 创建 PixelMap 显示
7. 保存当前 buffer 作为下一帧的 prevBuffer
```

### 7.2 增量帧处理 (reset=false)

```
1. 接收压缩数据
2. 解压得到 Capture 对象
3. 检查 reset === false
4. 获取保存的 prevBuffer
5. 遍历 dirty tiles:
   - 如果 tile !== null: 用新数据覆盖 prevBuffer
   - 如果 tile === null: 保持 prevBuffer 原有数据
6. 创建 PixelMap 显示
7. 保存更新后的 buffer 作为下一帧的 prevBuffer
```

## 8. 性能优化

### 8.1 缓冲区复用

**代码位置**: `HarmonOS_remote_desktop_control_client/entry/src/main/ets/squeeze/Capture.ets#L62-L73`

```typescript
// 优先复用前一帧缓冲区
if (prevBuffer !== null && capWidth === prevWidth && capHeight === prevHeight && prevBuffer.length === bufferSize) {
    buffer = prevBuffer;
} else {
    buffer = bufferPool.acquireBuffer(bufferSize);
}
```

### 8.2 安全检查

**代码位置**: `HarmonOS_remote_desktop_control_client/entry/src/main/ets/squeeze/Capture.ets#L48-L60`

```typescript
// 维度检查
if (capWidth <= 0 || capHeight <= 0 || capWidth > 10000 || capHeight > 10000) {
    return new Uint8Array(0);
}

// 缓冲区大小检查
if (bufferSize > 100000000) { // 100MB限制
    return new Uint8Array(0);
}
```

### 8.3 瓦片位置检查

**代码位置**: `HarmonOS_remote_desktop_control_client/entry/src/main/ets/squeeze/Capture.ets#L96-L108`

```typescript
// 检查瓦片位置是否在有效范围内
if (tile.x < 0 || tile.y < 0 || tile.x >= capWidth || tile.y >= capHeight) {
    continue;
}
```

## 9. 与 Java 客户端对比

| 特性 | Java 客户端 | HarmonyOS 客户端 |
|------|------------|------------------|
| 帧序号 | `int id` | `number id` |
| 重置标志 | `boolean reset` | `boolean reset` |
| 屏幕尺寸 | `Dimension captureDimension` | `width, height` |
| 瓦片尺寸 | `Dimension tileDimension` | `tileWidth, tileHeight` |
| 变化瓦片 | `CaptureTile[] dirty` | `dirtyTiles[]` |
| 校验和 | `Adler32 checksum` | `checksum` |
| 单级灰度 | `byte singleLevel` | `singleLevel` |

## 10. 总结

### 10.1 关键发现

1. **`reset` 标志** 是区分完整帧和增量帧的关键
2. **dirty tiles** 只包含变化的区域，不是完整屏幕
3. **单级灰度** 可以显著减少数据传输量
4. **缓冲区复用** 是性能优化的关键

### 10.2 实现要点

1. 解析压缩数据时，需要识别 `reset` 标志
2. 增量帧需要与前一帧合并
3. 完整帧需要创建新缓冲区
4. 需要正确处理灰度和彩色两种模式

### 10.3 代码位置汇总

| 功能 | Java 客户端 | HarmonyOS 客户端 |
|------|------------|------------------|
| Capture 类 | `client/.../bean/Capture.java` | `entry/.../squeeze/Capture.ets` |
| CaptureTile 类 | `client/.../bean/CaptureTile.java` | `entry/.../squeeze/CaptureTile.ets` |
| 图像组装 | `createBufferedImage()` | `createImageBuffer()` |
| 合并逻辑 | `doMergeDirtyTiles()` | 循环处理 dirtyTiles |
| 压缩方法 | `CompressionMethod.java` | `CmdType` 枚举 |
