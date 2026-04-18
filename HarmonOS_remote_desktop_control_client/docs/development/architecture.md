# 系统架构

## 1. 项目概览

HarmonyOS 远程桌面控制客户端由以下几部分构成：

- `entry/`：HarmonyOS 客户端应用入口和 ArkTS 代码
- `client/`：Java 端客户端实现
- `server/`：Java 服务端实现
- `common/`：共有模块和工具类

## 2. 架构分层

### 2.1 客户端层（HarmonyOS）

- 页面与 UI：`entry/src/main/ets/pages/`
- 服务层：`entry/src/main/ets/services/`
- 网络与协议：`entry/src/main/ets/services/connection/`、`protocol/`
- 数据与状态：`entry/src/main/ets/viewmodel/`

### 2.2 服务端与后端

- Java Netty/TCP 服务（`server/`）
- HTTP 接口与文件服务
- 共享业务模型在 `common/` 中定义

## 3. 核心子系统

### 3.1 远程控制子系统

- `RemoteControlService.ets`
- 负责建立远程连接、接收视频帧、控制鼠标/键盘事件、管理会话状态

### 3.2 剪贴板子系统

- `ClipboardService`
- 负责本地与远程剪贴板同步，以及剪贴板数据读写

### 3.3 文件传输子系统

- `FileService`
- 负责文件上传下载、断点续传、文件列表管理

### 3.4 网络连接子系统

- `connection/` 模块
- 管理 TCP/HTTP 连接、重连策略、心跳机制、状态通知

## 4. 数据流与协议

### 4.1 远程控制数据流

1. 客户端发起远程连接请求
2. 服务端验证后建立 TCP 会话
3. 服务端发送压缩视频帧
4. 客户端解码并展示画面，发送控制事件回传

### 4.2 HTTP API 数据流

- HTTP 接口用于文件服务、剪贴板同步、账号验证等辅助操作
- 常见端点：`/remote-desktop-control` 或 `remote-desktop-control` 上下文路径

## 5. 关键技术与依赖

- HarmonyOS ArkTS / NAPI
- ZSTD 压缩
- Netty / TCP 连接
- HTTP 文件接口
- `hvigor` 构建系统和 `ohos` 模块管理

## 6. 参考代码位置

- `entry/src/main/ets/services/remote/RemoteControlService.ets`
- `entry/src/main/ets/services/clipboard/ClipboardService.ets`
- `entry/src/main/ets/services/file/FileService.ets`
- `entry/src/main/ets/services/connection/`
- `client/src/main/java/` 和 `server/src/main/java/`
