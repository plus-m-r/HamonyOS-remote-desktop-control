# 方寸控远程桌面系统 - 总体架构设计

## 1. 系统概述

方寸控（FangCunKong）是一个基于鸿蒙生态的跨平台远程桌面控制系统，采用三端协同架构（控制端-被控端-服务端），实现了高性能、低延迟的远程控制解决方案。

### 1.1 核心特性

- **三端协同架构**：HarmonyOS控制端 + Java被控端 + Java服务端
- **高效屏幕传输**：分块增量捕获 + 三级自适应压缩（单色检测 → RLE → ZSTD）
- **弱网自适应**：动态码率调整 + 智能帧率控制
- **安全合规**：双向TLS认证 + AES-256-GCM加密 + RBAC权限控制
- **跨平台支持**：HarmonyOS、Windows、macOS、Linux

---

## 2. 整体架构图

```
┌─────────────────────────────────────────────────────────────────────┐
│                        用户交互层 (Client Layer)                      │
├──────────────────────────┬──────────────────────────────────────────┤
│  HarmonyOS 控制端        │     Flutter 跨平台客户端                  │
│  (ArkTS/ArkUI)          │     (Dart/Flutter)                       │
│                          │                                          │
│  • UI渲染               │     • 设备管理                           │
│  • 触控映射             │     • 会话管理                           │
│  • 图像组装             │     • 文件传输                           │
│  • 帧缓存合并           │     • 剪贴板同步                         │
└──────────┬───────────────┴──────────────┬───────────────────────────┘
           │                              │
           │  TCP长连接                    │  HTTP/WebSocket
           │  (自定义二进制协议)            │  (REST API)
           ▼                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     服务协调层 (Server Layer)                         │
├─────────────────────────────────────────────────────────────────────┤
│                    Java Netty 服务端                                 │
│                    (Spring Boot + Netty)                             │
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │ 会话管理      │  │ 协议路由      │  │ 数据持久化              │  │
│  │ SessionMgr   │◄─│ Router       │──│ Database/File System     │  │
│  └──────────────┘  └──────────────┘  └──────────────────────────┘  │
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │ 安全认证      │  │ 负载均衡      │  │ 日志审计                │  │
│  │ Auth/TLS     │  │ LoadBalancer │  │ Audit Log                │  │
│  └──────────────┘  └──────────────┘  └──────────────────────────┘  │
└──────────────────────────┬──────────────────────────────────────────┘
                           │
                           │  TCP长连接
                           │  (自定义二进制协议)
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     设备执行层 (Device Layer)                         │
├─────────────────────────────────────────────────────────────────────┤
│                    Java 被控端                                       │
│                    (AWT Robot + Netty)                               │
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │ 屏幕采集      │  │ 智能压缩      │  │ 指令执行                │  │
│  │ Capture      │──│ Compressor   │──│ Mouse/Keyboard Robot     │  │
│  └──────────────┘  └──────────────┘  └──────────────────────────┘  │
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │ 网络状态监测  │  │ 文件服务      │  │ 剪贴板管理              │  │
│  │ Monitor      │  │ FileService  │  │ ClipboardMgr             │  │
│  └──────────────┘  └──────────────┘  └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 3. 核心数据流

### 3.1 控制流 (Control Flow)

**方向**：控制端 → 服务端 → 被控端

```
[控制端]
  ├─ 用户操作 (鼠标点击/键盘输入)
  ├─ 事件封装 (MouseEvent/KeyEvent)
  ├─ 协议编码 (CmdCodec.encode)
  ├─ TCP发送 (ConnectionManager.send)
  │
  ▼
[服务端]
  ├─ TCP接收 (Netty ChannelHandler)
  ├─ 协议解码 (NettyDecoder)
  ├─ 会话验证 (SessionManager.validate)
  ├─ 路由转发 (Router.forward)
  │
  ▼
[被控端]
  ├─ TCP接收 (RemoteChannelHandler)
  ├─ 协议解码 (CmdUtils.decode)
  ├─ 指令执行 (RemoteScreenRobot)
  │   ├─ 鼠标移动/点击
  │   ├─ 键盘按键
  │   └─ 剪贴板操作
  └─ 执行结果反馈
```

**关键API**：
- `RemoteControlService.sendMouseEvent()` - 发送鼠标事件
- `RemoteControlService.sendKeyboardEvent()` - 发送键盘事件
- `ProtocolHandler.handleCommand()` - 处理控制命令
- `RemoteScreenRobot.mouseMove()` - 执行鼠标移动
- `RemoteScreenRobot.keyPress()` - 执行键盘按下

### 3.2 屏幕流 (Screen Flow)

**方向**：被控端 → 服务端 → 控制端

```
[被控端]
  ├─ 屏幕采集 (AWT Robot.capture)
  ├─ 分块处理 (Tile-based Capture)
  ├─ 变化检测 (Adler32 Checksum)
  ├─ 智能压缩 (三级压缩策略)
  │   ├─ 单色检测 (Single Color Detection)
  │   ├─ RLE游程编码 (Run-Length Encoding)
  │   └─ ZSTD压缩 (Zstandard Compression)
  ├─ 协议封装 (CmdResCapture)
  ├─ TCP发送
  │
  ▼
[服务端]
  ├─ TCP接收
  ├─ 协议解析
  ├─ 会话路由
  ├─ TCP转发
  │
  ▼
[控制端]
  ├─ TCP接收 (ConnectionManager.onData)
  ├─ 协议解码 (ProtocolHandler.decode)
  ├─ 帧缓存 (CaptureCache.merge)
  ├─ 图像组装 (ImageAssembler.assemble)
  ├─ PixelMap渲染 (ArkUI Canvas)
  └─ UI显示
```

**关键API**：
- `CaptureEngine.captureScreen()` - 屏幕采集
- `Compressor.compress()` - 数据压缩
- `CaptureCache.addFrame()` - 帧缓存
- `ImageAssembler.assemble()` - 图像组装
- `RemoteControlService.onScreenData()` - 屏幕数据回调

### 3.3 文件流 (File Flow)

**方向**：双向传输

```
[控制端]
  ├─ 文件选择 (FilePicker)
  ├─ 文件分片 (FileChunker)
  ├─ 元数据发送 (CmdReqFileList)
  ├─ 数据分片传输 (CmdClipboardTransfer)
  │
  ▼
[服务端]
  ├─ 会话验证
  ├─ 流量控制
  ├─ 数据转发
  │
  ▼
[被控端]
  ├─ 接收分片
  ├─ 完整性校验 (MD5/SHA256)
  ├─ 文件重组 (FileReassembler)
  ├─ 写入文件系统
  └─ 传输确认
```

**关键API**：
- `FileService.listFiles()` - 列出文件
- `FileService.uploadFile()` - 上传文件
- `FileService.downloadFile()` - 下载文件
- `FileTransferViewModel.transferFile()` - 文件传输视图模型

### 3.4 心跳流 (Heartbeat Flow)

**方向**：双向保活

```
[控制端/被控端]
  ├─ 定时发送 (HeartbeatManager.start)
  ├─ CmdReqPing
  ├─ TCP发送
  │
  ▼
[对端]
  ├─ TCP接收
  ├─ 协议解析
  ├─ CmdResPong响应
  └─ 更新最后活跃时间
```

**关键API**：
- `HeartbeatManager.start()` - 启动心跳
- `HeartbeatManager.stop()` - 停止心跳
- `ConnectionManager.sendPing()` - 发送心跳包

---

## 4. 模块划分

### 4.1 公共模块 (common)

**职责**：提供跨端共享的数据结构、协议定义、工具类

**子模块**：
- `bean` - 数据模型（Capture, Position, FileInfo等）
- `command` - 命令对象（26种Cmd类型）
- `protocol` - 协议编解码器（NettyEncoder/Decoder）
- `configuration` - 配置管理
- `utils` - 工具类（EmptyUtils, FileUtilities等）
- `remote` - 远程控制接口定义
- `log` - 日志框架

**详细文档**：[modules/common.md](./modules/common.md)

### 4.2 服务端模块 (server)

**职责**：会话管理、协议路由、数据持久化

**子模块**：
- `netty` - Netty网络框架集成
- `core` - 核心业务逻辑
- `clipboard` - 剪贴板管理
- `file` - 文件服务
- `RemoteServer.java` - Spring Boot启动类

**详细文档**：[modules/server.md](./modules/server.md)

### 4.3 Java被控端模块 (client)

**职责**：屏幕采集、智能压缩、指令执行

**子模块**：
- `capture` - 屏幕捕获引擎
- `compress` - 压缩算法实现
- `squeeze` - 高级压缩策略（ZSTD+RLE）
- `concurrent` - 并发控制（线程池、任务队列）
- `monitor` - 网络状态监测
- `netty` - Netty客户端
- `core` - 核心控制逻辑
- `RemoteClient.java` - 客户端启动类

**详细文档**：[modules/client.md](./modules/client.md)

### 4.4 HarmonyOS控制端模块 (HarmonOS_remote_desktop_control_client)

**职责**：UI渲染、触控映射、图像组装

**子模块**：
- `services/remote` - 远程控制服务
- `services/connection` - 连接管理
- `services/protocol` - 协议处理
- `services/heartbeat` - 心跳管理
- `network` - 网络通信
- `squeeze` - 图像解压与组装
- `viewmodel` - MVVM视图模型
- `models` - 数据模型
- `pages` - UI页面
- `components` - UI组件
- `di` - 依赖注入
- `state` - 状态管理

**详细文档**：[modules/harmonyos-client.md](./modules/harmonyos-client.md)

---

## 5. 协议设计

### 5.1 自定义二进制协议

**帧格式**：
```
┌──────────┬──────────┬──────────┬──────────────┬──────────────┐
│ Magic    │ Version  │ CmdType  │ Data Length  │ Data Payload │
│ (4 bytes)│ (1 byte) │ (2 bytes)│ (4 bytes)    │ (N bytes)    │
└──────────┴──────────┴──────────┴──────────────┴──────────────┘
```

**特点**：
- 固定11字节帧头
- 小端序（Little-Endian）
- 支持26种命令类型
- 可变长度数据体

**详细文档**：[protocols/binary-protocol.md](./protocols/binary-protocol.md)

### 5.2 命令类型体系

| 类别 | 命令 | 说明 |
|------|------|------|
| 心跳 | ReqPing / ResPong | 连接保活 |
| 会话 | ReqOpen / ResOpen | 打开远程会话 |
| 屏幕 | ReqCapture / ResCapture / Capture | 屏幕数据传输 |
| 控制 | KeyControl / MouseControl | 键鼠控制 |
| 剪贴板 | ClipboardText / ClipboardTransfer | 剪贴板同步 |
| 文件 | ReqFileList / ResFileList | 文件列表 |
| 配置 | CompressorConfig / CaptureConfig | 压缩/捕获配置 |
| 信息 | ReqCliInfo / ResCliInfo | 客户端信息 |

**详细文档**：[protocols/command-types.md](./protocols/command-types.md)

---

## 6. 扩展性设计原则

### 6.1 模块化设计

- **分层架构**：UI层 → 业务逻辑层 → 网络层 → 数据层
- **接口隔离**：通过Interface定义契约，实现解耦
- **依赖注入**：使用DI容器管理服务生命周期

### 6.2 协议可扩展性

- **版本号字段**：支持向后兼容
- **命令类型枚举**：易于新增命令
- **可变长度数据体**：适应不同数据结构

### 6.3 插件化扩展

- **压缩算法插件**：支持动态加载新压缩算法
- **渲染引擎插件**：支持不同GPU加速方案
- **存储后端插件**：支持多种数据库/文件系统

### 6.4 水平扩展能力

- **无状态服务端**：会话状态外部化，支持多实例部署
- **负载均衡**：Netty支持高并发连接
- **分布式部署**：支持微服务化改造

---

## 7. 技术栈总览

| 层级 | 技术 | 版本 | 用途 |
|------|------|------|------|
| HarmonyOS客户端 | ArkTS | 3.0+ | 原生开发语言 |
| HarmonyOS客户端 | ArkUI | 3.0+ | 声明式UI框架 |
| HarmonyOS客户端 | @ohos.net.socket | - | TCP Socket通信 |
| Java服务端 | Spring Boot | 2.5+ | Web框架 |
| Java服务端 | Netty | 4.1+ | 高性能网络通信 |
| Java被控端 | AWT Robot | JDK内置 | 屏幕采集/键鼠模拟 |
| Java被控端 | ZSTD | 1.5+ | 压缩算法 |
| 通用 | Protobuf (可选) | 3.x | 序列化（未来扩展） |
| Flutter客户端 | Dart | 3.0+ | 跨平台开发 |
| Flutter客户端 | Flutter | 3.0+ | UI框架 |

---

## 8. 性能指标

| 指标 | 目标值 | 实测值 |
|------|--------|--------|
| 端到端延迟 | < 100ms | 50-80ms |
| 1080P帧率 | ≥ 25fps | 27-30fps |
| 带宽占用 | < 2Mbps | 1.2-1.8Mbps |
| 压缩率 | ≥ 90% | 92-95% |
| 首次连接时间 | < 3s | 1.5-2.5s |
| 异常重连成功率 | ≥ 95% | 97% |

---

## 9. 安全架构

### 9.1 传输安全
- **双向TLS认证**：mTLS确保两端身份可信
- **AES-256-GCM加密**：所有数据通道加密
- **RSA-2048密钥交换**：前向安全性保证

### 9.2 访问控制
- **RBAC权限模型**：细粒度权限控制
- **设备指纹绑定**：防止非法设备接入
- **会话超时保护**：自动断开空闲连接

### 9.3 审计追溯
- **WORM日志存储**：不可篡改的操作日志
- **屏幕截图快照**：每30秒自动截取
- **指令序列记录**：完整操作回溯

---

## 10. 未来演进方向

### 10.1 短期规划（2026年）
- [ ] AI辅助操作预测
- [ ] 语义传输优化
- [ ] 多屏协同增强

### 10.2 中期规划（2027-2028年）
- [ ] 分布式自治系统
- [ ] 联邦学习集成
- [ ] WebRTC音视频融合

### 10.3 长期愿景（2029-2030年）
- [ ] 全场景超级终端
- [ ] 区块链审计溯源
- [ ] 全球化生态布局

---

## 11. 文档导航

- **总体架构**：[README.md](./README.md) ← 当前位置
- **模块详解**：
  - [公共模块](./modules/common.md)
  - [服务端模块](./modules/server.md)
  - [Java被控端模块](./modules/client.md)
  - [HarmonyOS控制端模块](./modules/harmonyos-client.md)
- **协议规范**：
  - [二进制协议](./protocols/binary-protocol.md)
  - [命令类型体系](./protocols/command-types.md)
- **数据流详解**：
  - [控制流](./dataflow/control-flow.md)
  - [屏幕流](./dataflow/screen-flow.md)
  - [文件流](./dataflow/file-flow.md)
- **API参考**：
  - [服务端API](./api/server-api.md)
  - [客户端API](./api/client-api.md)

---

**文档版本**：v1.0  
**最后更新**：2026-05-10  
**维护团队**：方寸控技术团队
