# Java 客户端颜色编码分析

## 1. 彩色模式 (ARGB32)
- **格式**: ARGB (Alpha-Red-Green-Blue)
- **位深**: 32位 (每个像素4字节)
- **存储方式**: `int[]` 数组，每个 int 包含一个像素的 ARGB 值
- **字节序**: 大端序 (Big Endian)
- **代码位置**: [ScreenUtilities.java#L99-L104](file:///c:/learn/HamonyOS-remote-desktop-control/client/src/main/java/io/github/springstudent/dekstop/client/utils/ScreenUtilities.java#L99-L104)

```java
public static byte[] captureColors() {
    final int[] ints = captureRGB(sharedScreenSize);
    ByteBuffer bb = ByteBuffer.allocate(4 * ints.length);
    bb.asIntBuffer().put(ints);
    return bb.array();
}
```

## 2. 灰度模式 (Gray8)
- **格式**: 8位灰度
- **位深**: 8位 (每个像素1字节)
- **量化级别**: 支持 7 种量化级别 ([Gray8Bits.java](file:///c:/learn/HamonyOS-remote-desktop-control/common/src/main/java/io/github/springstudent/dekstop/common/bean/Gray8Bits.java))
  - `X_256` (256级)
  - `X_128` (128级)
  - `X_64` (64级)
  - `X_32` (32级)
  - `X_16` (16级)
  - `X_8` (8级)
  - `X_4` (4级)

## 3. RGB 转灰度算法
使用标准 ITU-R BT.709 系数 ([ScreenUtilities.java#L161-172](file:///c:/learn/HamonyOS-remote-desktop-control/client/src/main/java/io/github/springstudent/dekstop/client/utils/ScreenUtilities.java#L161-L172))：

```java
// 红色系数: 0.212671
// 绿色系数: 0.715160
// 蓝色系数: 0.072169
gray = (0.212671 * R) + (0.715160 * G) + (0.072169 * B)
```

## 4. 捕获方式
- **默认捕获**: 使用 AWT `Robot.createScreenCapture()` 获取屏幕
- **锁屏捕获** (Windows): 使用 JNI 调用 `WinDesktop` 获取屏幕图像，然后通过 `ImageIO` 解析

## 5. 图像分块
- **分块大小**: 32x32 像素 ([CaptureEngine.java#L21](file:///c:/learn/HamonyOS-remote-desktop-control/client/src/main/java/io/github/springstudent/dekstop/client/capture/CaptureEngine.java#L21))
- **传输单位**: 只传输变化的分块 (dirty tiles)，使用校验和检测变化

## 6. 与 HarmonyOS 客户端的兼容性

### 6.1 数据格式转换
- **ARGB32 到 HarmonyOS 颜色**: 需要将 Java 的 ARGB 格式转换为 HarmonyOS 的颜色表示
- **灰度数据处理**: HarmonyOS 客户端需要支持 8位灰度数据的显示

### 6.2 性能优化建议
- **分块处理**: 保持与 Java 客户端相同的 32x32 分块大小，便于数据处理
- **压缩传输**: 对灰度数据使用适当的压缩算法，减少网络传输量
- **色彩空间转换**: 在 HarmonyOS 端实现高效的颜色空间转换

## 7. 实现参考

### 7.1 HarmonyOS 端颜色处理
```typescript
// 处理 ARGB32 数据
function processArgbData(data: Uint8Array, width: number, height: number): ImagePixelMap {
  // 实现 ARGB 数据到 HarmonyOS 图像的转换
}

// 处理灰度数据
function processGrayData(data: Uint8Array, width: number, height: number, quantization: number): ImagePixelMap {
  // 实现灰度数据到 HarmonyOS 图像的转换
}
```

### 7.2 分块处理
```typescript
// 处理分块数据
function processTiles(tiles: Tile[], width: number, height: number): ImagePixelMap {
  // 实现分块数据的重组和显示
}
```

## 8. 技术要点

- **颜色空间一致性**: 确保 Java 客户端和 HarmonyOS 客户端使用相同的颜色空间和编码方式
- **性能考虑**: 在移动设备上处理图像数据时，需要考虑内存和处理能力的限制
- **网络传输**: 优化数据传输格式，减少带宽使用

## 9. 结论

Java 客户端采用了标准的 ARGB32 彩色模式和 8位灰度模式，使用 ITU-R BT.709 标准进行灰度转换，并通过分块传输优化网络性能。HarmonyOS 客户端在实现时应保持与 Java 客户端的颜色编码一致性，同时针对移动设备的特点进行适当的优化。