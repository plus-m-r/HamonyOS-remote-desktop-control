# 服务端接口文档

## 1. 文件操作接口

### 1.1 下载文件
- **URL**: `/file/downloadFile`
- **方法**: GET
- **参数**:
  - `fileInfoId` (String): 文件信息ID
- **响应**: 文件流

### 1.2 快速上传文件（检查文件是否已存在）
- **URL**: `/file/quickUploadFile`
- **方法**: GET
- **参数**:
  - `md5` (String): 文件MD5值
  - `fileSize` (Long): 文件大小
- **响应**: String (文件信息ID或状态)

### 1.3 检查文件分片是否已上传
- **URL**: `/file/checkChunk`
- **方法**: GET
- **参数**:
  - `md5` (String): 文件MD5值
  - `chunkNo` (Integer): 分片序号
  - `chunkSize` (Long): 分片大小
- **响应**: boolean (是否已上传)

### 1.4 上传文件分片
- **URL**: `/file/uploadFileChunk`
- **方法**: POST
- **参数**:
  - `file` (MultipartFile): 文件分片
  - `md5` (String): 文件MD5值
  - `chunkNo` (Integer): 分片序号
  - `fileName` (String): 文件名
- **响应**: String (文件信息ID)

### 1.5 删除文件
- **URL**: `/file/deleteFile`
- **方法**: POST
- **参数**:
  - `fileInfoIds` (List<String>): 文件信息ID列表
- **响应**: void

## 2. 剪贴板操作接口

### 2.1 清空剪贴板
- **URL**: `/clipboard/clear`
- **方法**: POST
- **参数**:
  - `deviceCode` (String): 设备编码
- **响应**: void

### 2.2 保存剪贴板内容
- **URL**: `/clipboard/save`
- **方法**: POST
- **参数**:
  - `clipboards` (List<Clipboard>): 剪贴板内容列表
- **响应**: void

### 2.3 获取剪贴板内容
- **URL**: `/clipboard/get`
- **方法**: GET
- **参数**:
  - `deviceCode` (String): 设备编码
- **响应**: List<Clipboard> (剪贴板内容列表)

## 3. 数据模型

### 3.1 Clipboard
- `id` (Long): 主键ID
- `deviceCode` (String): 设备编码
- `content` (String): 剪贴板内容
- `type` (String): 内容类型
- `createTime` (Date): 创建时间

## 4. 接口说明

- 所有接口均需要在启用文件服务的情况下才能访问文件相关接口（通过配置 `dekstop.server.file.enabled=true`）
- 接口返回格式为标准的RESTful响应
- 错误处理采用全局异常处理器，返回统一的错误信息
