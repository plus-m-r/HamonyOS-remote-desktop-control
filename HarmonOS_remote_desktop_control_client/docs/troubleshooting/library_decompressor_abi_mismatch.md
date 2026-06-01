# library_decompressor ABI 不匹配问题报告

## 问题概述

在 x86_64 模拟器上部署时，安装失败，错误码 `9568347`。

## 错误信息

```
Install Failed: error: failed to install bundle.
code:9568347
error: install parse native so failed.
In the module named entry, the Abi type supported by the device does not match the Abi type configured in the C++ project.
```

## 环境信息

| 项目 | 值 |
|------|-----|
| 设备类型 | 模拟器 |
| 设备架构 | x86_64 |
| 连接地址 | 127.0.0.1:5555 |
| 依赖库 | library_decompressor@^1.0.1 |
| SDK 版本 | 6.0.2(22) |

## 根因分析

`library_decompressor` 是一个第三方 NAPI 原生库，用于在内存中执行 ZSTD/LZ4/Snappy 压缩解压。该库编译时仅产出了 `arm64-v8a` 架构的 `.so` 文件，未提供 `x86_64` 版本。

HarmonyOS 在安装 HAP 时会校验原生库的 ABI 与目标设备是否匹配。x86_64 模拟器无法加载 arm64 的原生库，因此安装被拒绝。

### 调用链

```
FrameDecoder.zstdDecompress()
  → library_decompressor.CompressorFactory.create('zstd')
    → libmemory_decompressor.so (arm64-v8a  only)
      → x86_64 设备无法加载 → 安装失败
```

### 历史背景

| 阶段 | 底层库 | 架构支持 | 方式 |
|------|--------|----------|------|
| 重构前 | @ohos/commons-compress（系统库） | arm64 + x86_64 | 文件 IO |
| 重构后 | library_decompressor（三方库） | arm64 only | 内存 |

重构将压缩底层从 HarmonyOS 系统库替换为第三方 NAPI 库，引入了 ABI 兼容性问题。

## 影响范围

- **x86_64 模拟器**：无法安装，完全阻塞
- **ARM64 真机/模拟器**：不受影响，正常运行

## 解决方案

### 方案一：使用 ARM64 设备（推荐）

将部署目标从 x86_64 模拟器切换为 ARM64 真机或 ARM64 模拟器。

### 方案二：让 library_decompressor 支持 x86_64

联系 `library_decompressor` 库作者，编译 x86_64 架构的 `.so` 文件并发布新版本。

### 方案三：双引擎回退（代码改动最小）

在 `FrameDecoder` 中增加架构检测，x86_64 时回退到 `@ohos/commons-compress`（文件 IO 方式），ARM64 时使用 `library_decompressor`（内存方式）。

需要：
1. 重新添加 `@ohos/commons-compress` 依赖
2. 在 `zstdDecompress()` 中增加架构判断逻辑
3. x86_64 路径保留文件 IO 方式

## 相关信息

- 依赖版本：`library_decompressor@^1.0.1`
- 依赖声明：`HarmonOS_remote_desktop_control_client/oh-package.json5`
- 调用位置：`entry/src/main/ets/squeeze/FrameDecoder.ets` → `zstdDecompress()`
- 设备参数：`uname -m` 输出 `x86_64`