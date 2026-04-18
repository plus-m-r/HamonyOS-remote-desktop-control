# 组件设计

## 1. 设计原则

- 单一职责：每个服务和模块只负责一类功能
- 松耦合：通过接口与事件总线降低模块依赖
- 可测试：所有业务逻辑应支持 Mock 测试
- 可维护：文档与代码同步更新

## 2. 核心组件

### 2.1 RemoteControlService

**职责**
- 管理远程连接生命周期
- 接收和解码远程视频数据
- 发送控制命令（鼠标、键盘、触控）
- 处理远程会话状态和错误恢复

**主要接口**
- `connect()`
- `openRemoteScreen(deviceCode, password)`
- `closeRemoteScreen()`
- `sendMouseControl(mouseEvent)`
- `sendKeyControl(keyEvent)`
- `disconnect()`

### 2.2 ClipboardService

**职责**
- 本地剪贴板读写
- 远程剪贴板同步
- 剪贴板数据格式转换

**主要接口**
- `clearClipboard()`
- `saveClipboard()`
- `syncClipboard()`
- `getClipboardData()`

### 2.3 FileService

**职责**
- 文件上传/下载
- 文件列表与目录管理
- 断点续传与文件校验

**主要接口**
- `uploadFile()`
- `downloadFile()`
- `listFiles()`
- `deleteFile()`

### 2.4 ConnectionManager

**职责**
- 管理 TCP/HTTP 连接
- 维护心跳与重连逻辑
- 报告连接状态给上层组件

**主要接口**
- `connectTcp()`
- `connectHttp()`
- `closeConnection()`
- `heartbeat()`
- `onConnectionStateChange()`

## 3. 页面与 UI 组件

### 3.1 Control 页面

- 负责远程桌面显示
- 展示连接状态、控制按钮、性能指标
- 与 `RemoteControlService` 和 `ClipboardService` 交互

### 3.2 Settings / Configuration 页面

- 负责服务端地址、端口、上下文路径配置
- 负责账号、密码与连接参数

## 4. 数据模型与接口

### 4.1 共享数据模型

- `CmdData` / `CmdProtocol`
- 剪贴板数据结构
- 文件列表项结构
- 会话状态与错误码

### 4.2 配置与常量

- HTTP 端口、TCP 端口、上下文路径
- 服务端地址与回退策略
- 连接重试次数、超时设置

## 5. 设计规范

- 所有业务逻辑放在服务层，不直接写在页面层
- 服务间通信采用明确接口和事件通知
- 异常处理集中在服务层，界面层只负责展示错误状态
- 配置与常量统一管理，避免硬编码地址和端口
