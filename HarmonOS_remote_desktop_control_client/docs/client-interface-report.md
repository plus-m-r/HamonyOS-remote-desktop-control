# 客户端接口详细报告

## 1. Netty 命令接口

### 1.1 命令类型枚举 (CmdType)

| 命令类型 | 描述 | 方向 |
|---------|------|------|
| ChangePwd | 修改密码 | 客户端 → 服务端 |
| ReqCliInfo | 请求客户端信息 | 客户端 → 服务端 |
| ReqPing | 心跳请求 | 客户端 → 服务端 |
| ReqOpen | 请求打开连接 | 客户端 → 服务端 |
| ReqCapture | 请求屏幕捕获 | 客户端 → 服务端 |
| Capture | 屏幕捕获数据 | 服务端 → 客户端 |
| ResRemoteClipboard | 远程剪贴板响应 | 服务端 → 客户端 |
| CaptureConfig | 屏幕捕获配置 | 客户端 → 服务端 |
| CompressorConfig | 压缩配置 | 客户端 → 服务端 |
| KeyControl | 键盘控制 | 客户端 → 服务端 |
| MouseControl | 鼠标控制 | 客户端 → 服务端 |
| ReqRemoteClipboard | 请求远程剪贴板 | 客户端 → 服务端 |
| SelectScreen | 选择屏幕 | 客户端 → 服务端 |
| ClipboardText | 剪贴板文本 | 客户端 ↔ 服务端 |
| ClipboardTransfer | 剪贴板传输 | 客户端 ↔ 服务端 |
| ResCliInfo | 客户端信息响应 | 服务端 → 客户端 |
| ResPong | 心跳响应 | 服务端 → 客户端 |
| ResOpen | 打开连接响应 | 服务端 → 客户端 |
| ResCapture | 屏幕捕获响应 | 服务端 → 客户端 |

### 1.2 详细命令接口

#### 1.2.1 ChangePwd (修改密码)
- **方向**: 客户端 → 服务端
- **输入参数**:
  - `password` (String): 新密码
- **输出响应**: 无
- **功能**: 修改客户端密码

#### 1.2.2 ReqCliInfo (请求客户端信息)
- **方向**: 客户端 → 服务端
- **输入参数**:
  - 客户端信息对象 (包含设备信息)
- **输出响应**: 无
- **功能**: 更新客户端信息

#### 1.2.3 ReqPing (心跳请求)
- **方向**: 客户端 → 服务端
- **输入参数**: 无
- **输出响应**:
  - `CmdResPong`: 心跳响应
- **功能**: 保持连接活跃

#### 1.2.4 ReqOpen (请求打开连接)
- **方向**: 客户端 → 服务端
- **输入参数**:
  - `deviceCode` (String): 目标设备码
- **输出响应**:
  - `CmdResOpen`:
    - `OK`: 连接成功
    - `OFFLINE`: 目标设备不在线
    - `CONTROL`: 目标设备已被控制
- **功能**: 请求打开与目标设备的连接

#### 1.2.5 ReqCapture (请求屏幕捕获)
- **方向**: 客户端 → 服务端
- **输入参数**:
  - `deviceCode` (String): 目标设备码
  - `password` (String): 目标设备密码
  - `captureOp` (int): 操作类型
    - `START_CAPTURE`: 开始捕获
    - `STOP_CAPTURE`: 停止捕获
    - `STOP_CAPTURE_BY_CONTROLLED`: 被控制端停止捕获
- **输出响应**:
  - `CmdResCapture`:
    - `OK`: 捕获成功
    - `OFFLINE`: 目标设备不在线
    - `PWDERROR`: 密码错误
    - `CONTROL`: 目标设备已被控制
    - `STOP`: 停止捕获
- **功能**: 请求开始或停止屏幕捕获

#### 1.2.6 Capture (屏幕捕获数据)
- **方向**: 服务端 → 客户端
- **输入参数**:
  - 屏幕图像数据
- **输出响应**: 无
- **功能**: 传输屏幕捕获数据

#### 1.2.7 ResRemoteClipboard (远程剪贴板响应)
- **方向**: 服务端 → 客户端
- **输入参数**:
  - 剪贴板数据
- **输出响应**: 无
- **功能**: 响应远程剪贴板请求

#### 1.2.8 CaptureConfig (屏幕捕获配置)
- **方向**: 客户端 → 服务端
- **输入参数**:
  - 屏幕捕获配置参数
- **输出响应**: 无
- **功能**: 配置屏幕捕获参数

#### 1.2.9 CompressorConfig (压缩配置)
- **方向**: 客户端 → 服务端
- **输入参数**:
  - 压缩配置参数
- **输出响应**: 无
- **功能**: 配置压缩参数

#### 1.2.10 KeyControl (键盘控制)
- **方向**: 客户端 → 服务端
- **输入参数**:
  - 键盘事件数据
- **输出响应**: 无
- **功能**: 发送键盘控制指令

#### 1.2.11 MouseControl (鼠标控制)
- **方向**: 客户端 → 服务端
- **输入参数**:
  - 鼠标事件数据
- **输出响应**: 无
- **功能**: 发送鼠标控制指令

#### 1.2.12 ReqRemoteClipboard (请求远程剪贴板)
- **方向**: 客户端 → 服务端
- **输入参数**: 无
- **输出响应**:
  - `ResRemoteClipboard`: 远程剪贴板数据
- **功能**: 请求远程剪贴板内容

#### 1.2.13 SelectScreen (选择屏幕)
- **方向**: 客户端 → 服务端
- **输入参数**:
  - 屏幕索引
- **输出响应**: 无
- **功能**: 选择要控制的屏幕

#### 1.2.14 ClipboardText (剪贴板文本)
- **方向**: 客户端 ↔ 服务端
- **输入参数**:
  - 剪贴板文本内容
- **输出响应**: 无
- **功能**: 同步剪贴板文本

#### 1.2.15 ClipboardTransfer (剪贴板传输)
- **方向**: 客户端 ↔ 服务端
- **输入参数**:
  - 剪贴板文件数据
- **输出响应**: 无
- **功能**: 传输剪贴板文件

#### 1.2.16 ResCliInfo (客户端信息响应)
- **方向**: 服务端 → 客户端
- **输入参数**:
  - `deviceCode` (String): 设备码
  - `password` (String): 密码
- **输出响应**: 无
- **功能**: 返回客户端设备码和密码

#### 1.2.17 ResPong (心跳响应)
- **方向**: 服务端 → 客户端
- **输入参数**: 无
- **输出响应**: 无
- **功能**: 响应心跳请求

#### 1.2.18 ResOpen (打开连接响应)
- **方向**: 服务端 → 客户端
- **输入参数**:
  - `status` (int): 连接状态
    - `OK`: 连接成功
    - `OFFLINE`: 目标设备不在线
    - `CONTROL`: 目标设备已被控制
- **输出响应**: 无
- **功能**: 响应打开连接请求

#### 1.2.19 ResCapture (屏幕捕获响应)
- **方向**: 服务端 → 客户端
- **输入参数**:
  - `status` (int): 捕获状态
    - `OK`: 捕获成功
    - `OFFLINE`: 目标设备不在线
    - `PWDERROR`: 密码错误
    - `CONTROL`: 目标设备已被控制
    - `STOP`: 停止捕获
- **输出响应**: 无
- **功能**: 响应屏幕捕获请求

## 2. HTTP 接口

### 2.1 文件操作接口

#### 2.1.1 下载文件
- **URL**: `/file/downloadFile`
- **方法**: GET
- **输入参数**:
  - `fileInfoId` (String): 文件信息ID
- **输出响应**:
  - 文件流
- **功能**: 下载文件

#### 2.1.2 快速上传文件（检查文件是否已存在）
- **URL**: `/file/quickUploadFile`
- **方法**: GET
- **输入参数**:
  - `md5` (String): 文件MD5值
  - `fileSize` (Long): 文件大小
- **输出响应**:
  - String: 文件信息ID或状态
- **功能**: 检查文件是否已存在

#### 2.1.3 检查文件分片是否已上传
- **URL**: `/file/checkChunk`
- **方法**: GET
- **输入参数**:
  - `md5` (String): 文件MD5值
  - `chunkNo` (Integer): 分片序号
  - `chunkSize` (Long): 分片大小
- **输出响应**:
  - boolean: 是否已上传
- **功能**: 检查文件分片是否已上传

#### 2.1.4 上传文件分片
- **URL**: `/file/uploadFileChunk`
- **方法**: POST
- **输入参数**:
  - `file` (MultipartFile): 文件分片
  - `md5` (String): 文件MD5值
  - `chunkNo` (Integer): 分片序号
  - `fileName` (String): 文件名
- **输出响应**:
  - String: 文件信息ID
- **功能**: 上传文件分片

#### 2.1.5 删除文件
- **URL**: `/file/deleteFile`
- **方法**: POST
- **输入参数**:
  - `fileInfoIds` (List<String>): 文件信息ID列表
- **输出响应**:
  - void
- **功能**: 删除文件

### 2.2 剪贴板操作接口

#### 2.2.1 清空剪贴板
- **URL**: `/clipboard/clear`
- **方法**: POST
- **输入参数**:
  - `deviceCode` (String): 设备编码
- **输出响应**:
  - void
- **功能**: 清空剪贴板

#### 2.2.2 保存剪贴板内容
- **URL**: `/clipboard/save`
- **方法**: POST
- **输入参数**:
  - `clipboards` (List<Clipboard>): 剪贴板内容列表
- **输出响应**:
  - void
- **功能**: 保存剪贴板内容

#### 2.2.3 获取剪贴板内容
- **URL**: `/clipboard/get`
- **方法**: GET
- **输入参数**:
  - `deviceCode` (String): 设备编码
- **输出响应**:
  - List<Clipboard>: 剪贴板内容列表
- **功能**: 获取剪贴板内容

## 3. 数据模型

### 3.1 Clipboard (剪贴板)
- `id` (Long): 主键ID
- `deviceCode` (String): 设备编码
- `content` (String): 剪贴板内容
- `type` (String): 内容类型
- `createTime` (Date): 创建时间

### 3.2 FileInfo (文件信息)
- `id` (String): 文件信息ID
- `fileName` (String): 文件名
- `fileSize` (Long): 文件大小
- `md5` (String): 文件MD5值
- `createTime` (Date): 创建时间

### 3.3 FileChunk (文件分片)
- `id` (Long): 主键ID
- `fileInfoId` (String): 文件信息ID
- `chunkNo` (Integer): 分片序号
- `chunkSize` (Long): 分片大小
- `md5` (String): 分片MD5值
- `createTime` (Date): 创建时间

### 3.4 FileUploadProgress (文件上传进度)
- `id` (Long): 主键ID
- `fileInfoId` (String): 文件信息ID
- `uploadedSize` (Long): 已上传大小
- `totalSize` (Long): 总大小
- `status` (String): 上传状态
- `createTime` (Date): 创建时间

## 4. 客户端服务接口

### 4.1 RemoteControlService (远程控制服务)

#### 4.1.1 方法列表
| 方法名 | 参数 | 返回值 | 功能 |
|--------|------|--------|------|
| `connect` | `onSuccess: () => void`, `onError: (error: string) => void` | 无 | 连接到服务端 |
| `disconnect` | 无 | Promise<void> | 断开与服务端的连接 |
| `openRemoteScreen` | `deviceCode: string`, `password: string` | 无 | 打开远程屏幕 |
| `closeRemoteScreen` | 无 | 无 | 关闭远程屏幕 |
| `sendMouseControl` | `mouseEvent: MouseEvent` | 无 | 发送鼠标控制指令 |
| `sendKeyControl` | `keyEvent: KeyEvent` | 无 | 发送键盘控制指令 |
| `setCaptureConfig` | `config: CaptureConfig` | 无 | 设置屏幕捕获配置 |
| `setCompressorConfig` | `config: CompressorConfig` | 无 | 设置压缩配置 |
| `selectScreen` | `screenIndex: number` | 无 | 选择要控制的屏幕 |

### 4.2 ClipboardService (剪贴板服务)

#### 4.2.1 方法列表
| 方法名 | 参数 | 返回值 | 功能 |
|--------|------|--------|------|
| `getClipboard` | `deviceCode: string` | Promise<Array<Clipboard>> | 获取剪贴板内容 |
| `saveClipboard` | `clipboards: Array<Clipboard>` | Promise<void> | 保存剪贴板内容 |
| `clearClipboard` | `deviceCode: string` | Promise<void> | 清空剪贴板 |
| `syncClipboard` | `content: string`, `type: string` | 无 | 同步剪贴板内容 |

### 4.3 FileService (文件服务)

#### 4.3.1 方法列表
| 方法名 | 参数 | 返回值 | 功能 |
|--------|------|--------|------|
| `downloadFile` | `fileInfoId: string`, `onProgress: (progress: number) => void` | Promise<ArrayBuffer> | 下载文件 |
| `uploadFile` | `file: File`, `onProgress: (progress: number) => void` | Promise<string> | 上传文件 |
| `checkFileExists` | `md5: string`, `fileSize: number` | Promise<string> | 检查文件是否存在 |
| `checkChunkExists` | `md5: string`, `chunkNo: number`, `chunkSize: number` | Promise<boolean> | 检查文件分片是否存在 |
| `uploadChunk` | `file: File`, `md5: string`, `chunkNo: number`, `fileName: string` | Promise<string> | 上传文件分片 |
| `deleteFile` | `fileInfoIds: Array<string>` | Promise<void> | 删除文件 |
| `cleanup` | 无 | void | 清理服务资源 |

## 5. 接口使用流程

### 5.1 远程控制流程
1. **连接服务端**：调用 `RemoteControlService.connect()`
2. **打开远程屏幕**：调用 `RemoteControlService.openRemoteScreen(deviceCode, password)`
3. **发送控制指令**：
   - 鼠标控制：调用 `RemoteControlService.sendMouseControl(mouseEvent)`
   - 键盘控制：调用 `RemoteControlService.sendKeyControl(keyEvent)`
4. **关闭远程屏幕**：调用 `RemoteControlService.closeRemoteScreen()`
5. **断开连接**：调用 `RemoteControlService.disconnect()`

### 5.2 文件传输流程
1. **检查文件是否存在**：调用 `FileService.checkFileExists(md5, fileSize)`
2. **上传文件**：调用 `FileService.uploadFile(file, onProgress)`
3. **下载文件**：调用 `FileService.downloadFile(fileInfoId, onProgress)`
4. **删除文件**：调用 `FileService.deleteFile(fileInfoIds)`

### 5.3 剪贴板同步流程
1. **获取剪贴板**：调用 `ClipboardService.getClipboard(deviceCode)`
2. **保存剪贴板**：调用 `ClipboardService.saveClipboard(clipboards)`
3. **清空剪贴板**：调用 `ClipboardService.clearClipboard(deviceCode)`
4. **同步剪贴板**：调用 `ClipboardService.syncClipboard(content, type)`

## 6. 接口错误处理

### 6.1 错误类型
- **网络错误**：网络连接失败、超时等
- **认证错误**：密码错误、设备不在线等
- **权限错误**：无权限访问资源
- **服务错误**：服务端内部错误

### 6.2 错误处理建议
- 所有网络请求都应使用 try-catch 包裹
- 对错误进行分类处理，提供友好的用户提示
- 实现重试机制，提高接口调用的可靠性
- 记录错误日志，便于问题排查

## 7. 接口性能优化

### 7.1 优化建议
- **批量操作**：对于多个文件或剪贴板项，使用批量接口减少网络请求
- **断点续传**：文件传输支持断点续传，提高大文件传输的可靠性
- **压缩传输**：对屏幕数据和文件数据进行压缩，减少传输带宽
- **缓存机制**：对频繁访问的数据进行缓存，减少重复请求
- **异步操作**：使用异步接口，避免阻塞主线程

## 8. 接口安全性

### 8.1 安全建议
- **加密传输**：使用HTTPS和TLS加密传输数据
- **身份验证**：确保所有接口都经过身份验证
- **权限控制**：实现细粒度的权限控制
- **数据验证**：对所有输入参数进行验证，防止注入攻击
- **日志审计**：记录关键操作日志，便于安全审计

## 9. 总结

本报告详细描述了客户端与服务端之间的所有接口，包括Netty命令接口、HTTP接口以及客户端服务接口。这些接口构成了远程桌面控制、文件传输和剪贴板同步的核心功能。通过合理使用这些接口，客户端可以实现与服务端的高效通信，为用户提供流畅的远程控制体验。

在实际开发中，应根据具体需求选择合适的接口，并注意错误处理、性能优化和安全性，以确保系统的稳定运行和用户数据的安全。