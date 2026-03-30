# HarmonyOS 客户端实现指南

## 1. 服务端接口分析

根据服务端代码分析，服务端提供了以下主要接口：

### 1.1 文件操作接口
- **下载文件**: `/file/downloadFile` (GET)
- **快速上传文件检查**: `/file/quickUploadFile` (GET)
- **检查文件分片**: `/file/checkChunk` (GET)
- **上传文件分片**: `/file/uploadFileChunk` (POST)
- **删除文件**: `/file/deleteFile` (POST)

### 1.2 剪贴板操作接口
- **清空剪贴板**: `/clipboard/clear` (POST)
- **保存剪贴板内容**: `/clipboard/save` (POST)
- **获取剪贴板内容**: `/clipboard/get` (GET)

### 1.3 远程控制接口（基于 TCP）
- 屏幕捕获
- 鼠标控制
- 键盘控制
- 会话管理

## 2. HarmonyOS 客户端实现方案

### 2.1 网络通信层

#### 2.1.1 RESTful API 调用
使用 HarmonyOS 的 `http` 模块进行 RESTful API 调用：

```typescript
import http from '@ohos.net.http';

// 创建 HTTP 请求
let httpRequest = http.createHttp();

// 发送 GET 请求
httpRequest.request(
  "http://server-ip:port/file/downloadFile",
  {
    method: http.RequestMethod.GET,
    header: {
      'Content-Type': 'application/json'
    },
    params: {
      fileInfoId: 'file-id'
    }
  }
).then((response) => {
  // 处理响应
}).catch((error) => {
  // 处理错误
});
```

#### 2.1.2 TCP 连接
使用 HarmonyOS 的 `socket` 模块进行 TCP 连接，用于实时远程控制：

```typescript
import socket from '@ohos.net.socket';

// 创建 TCP 套接字
let tcpSocket = socket.constructTCPSocketInstance();

// 连接到服务端
tcpSocket.connect({
  address: {
    family: 1, // AF_INET
    address: 'server-ip',
    port: server-port
  }
}, (err) => {
  if (err) {
    console.error('Connection failed:', err);
    return;
  }
  console.log('Connected to server');
});

// 发送数据
tcpSocket.send({
  data: buffer
}, (err, bytesSent) => {
  if (err) {
    console.error('Send failed:', err);
    return;
  }
  console.log('Bytes sent:', bytesSent);
});

// 接收数据
tcpSocket.on('message', (data) => {
  console.log('Received data:', data);
});
```

### 2.2 功能模块实现

#### 2.2.1 文件操作模块

```typescript
class FileManager {
  private serverUrl: string;

  constructor(serverUrl: string) {
    this.serverUrl = serverUrl;
  }

  // 下载文件
  async downloadFile(fileInfoId: string): Promise<ArrayBuffer> {
    // 实现文件下载逻辑
  }

  // 上传文件（分片上传）
  async uploadFile(filePath: string): Promise<string> {
    // 实现文件分片上传逻辑
  }

  // 删除文件
  async deleteFile(fileInfoIds: string[]): Promise<void> {
    // 实现文件删除逻辑
  }
}
```

#### 2.2.2 剪贴板操作模块

```typescript
class ClipboardManager {
  private serverUrl: string;

  constructor(serverUrl: string) {
    this.serverUrl = serverUrl;
  }

  // 获取远程剪贴板
  async getRemoteClipboard(deviceCode: string): Promise<Array<any>> {
    // 实现获取远程剪贴板逻辑
  }

  // 发送本地剪贴板
  async sendLocalClipboard(clipboards: Array<any>): Promise<void> {
    // 实现发送本地剪贴板逻辑
  }

  // 清空远程剪贴板
  async clearRemoteClipboard(deviceCode: string): Promise<void> {
    // 实现清空远程剪贴板逻辑
  }
}
```

#### 2.2.3 远程控制模块

```typescript
class RemoteControl {
  private tcpSocket: any;
  private serverIp: string;
  private serverPort: number;

  constructor(serverIp: string, serverPort: number) {
    this.serverIp = serverIp;
    this.serverPort = serverPort;
  }

  // 连接到服务端
  connect(): Promise<void> {
    // 实现 TCP 连接逻辑
  }

  // 打开远程屏幕
  openRemoteScreen(deviceCode: string, password: string): void {
    // 发送打开远程屏幕命令
  }

  // 关闭远程屏幕
  closeRemoteScreen(): void {
    // 发送关闭远程屏幕命令
  }

  // 发送鼠标控制命令
  sendMouseControl(x: number, y: number, buttonState?: string, button?: number): void {
    // 发送鼠标控制命令
  }

  // 发送键盘控制命令
  sendKeyControl(keyCode: number, keyChar: string, keyState: string): void {
    // 发送键盘控制命令
  }

  // 处理服务端消息
  handleServerMessage(data: ArrayBuffer): void {
    // 处理服务端消息，如屏幕捕获数据
  }
}
```

### 2.3 界面实现

#### 2.3.1 主界面
- 设备列表
- 连接状态显示
- 控制按钮（连接、断开、设置等）

#### 2.3.2 远程控制界面
- 远程屏幕显示
- 鼠标和键盘事件处理
- 控制工具栏（剪贴板操作、屏幕设置等）

#### 2.3.3 文件传输界面
- 文件列表
- 上传/下载操作
- 传输进度显示

### 2.4 数据模型

#### 2.4.1 设备信息
```typescript
interface DeviceInfo {
  deviceCode: string;
  name: string;
  status: 'online' | 'offline';
  lastSeen: string;
}
```

#### 2.4.2 剪贴板数据
```typescript
interface Clipboard {
  id?: number;
  deviceCode: string;
  content: string;
  type: string;
  createTime?: string;
}
```

#### 2.4.3 文件信息
```typescript
interface FileInfo {
  fileInfoId: string;
  fileName: string;
  fileSize: number;
  md5: string;
  createTime: string;
}
```

## 3. 与 Java 客户端的对比

### 3.1 相似之处
- 都需要实现与服务端的网络通信
- 都需要处理远程控制、剪贴板操作和文件传输功能
- 都需要处理屏幕捕获和显示

### 3.2 差异之处
- **技术栈**: Java 客户端使用 Swing 进行界面开发，HarmonyOS 客户端使用 ArkTS
- **网络 API**: Java 客户端使用 Netty，HarmonyOS 客户端使用系统提供的 `socket` 和 `http` 模块
- **文件系统**: HarmonyOS 有不同的文件系统访问权限和 API
- **UI 组件**: HarmonyOS 使用声明式 UI，与 Swing 的命令式 UI 不同

## 4. 实现建议

### 4.1 网络层
- 使用 HarmonyOS 的 `http` 模块处理 RESTful API 调用
- 使用 `socket` 模块处理 TCP 连接，用于实时远程控制
- 实现连接状态管理和自动重连机制

### 4.2 性能优化
- 使用多线程处理网络通信和 UI 渲染
- 实现屏幕捕获数据的压缩和解压缩
- 使用缓存减少网络传输

### 4.3 安全性
- 实现设备认证机制
- 对敏感数据进行加密传输
- 实现权限管理，确保只有授权设备可以控制

### 4.4 用户体验
- 实现流畅的远程控制体验
- 提供清晰的错误提示
- 支持横竖屏切换
- 优化触摸操作，适配移动设备

## 5. 开发步骤

1. **环境搭建**: 配置 HarmonyOS 开发环境，创建项目
2. **网络层实现**: 实现 HTTP 和 TCP 通信
3. **核心功能实现**: 远程控制、剪贴板操作、文件传输
4. **界面开发**: 实现主界面、远程控制界面、文件传输界面
5. **测试与优化**: 测试功能，优化性能和用户体验
6. **部署与发布**: 构建应用，发布到 HarmonyOS 应用市场

## 6. 技术栈

- **开发语言**: TypeScript/ArkTS
- **网络库**: @ohos.net.http, @ohos.net.socket
- **UI 框架**: HarmonyOS ArkUI
- **状态管理**: @ohos.reactivedata
- **文件操作**: @ohos.file.fs
- **加密**: @ohos.security.crypto
