# 远程桌面控制项目

## 项目简介

这是一个跨平台的远程桌面控制系统，支持从HarmonyOS设备和Java客户端远程控制Windows/Mac/Linux等操作系统的计算机。

### 主要功能

- ✅ 跨平台支持：服务端支持Windows、Mac、Linux；客户端支持HarmonyOS和Java
- ✅ 高效屏幕捕获：基于tile的分块捕获，减少数据传输量
- ✅ 智能压缩算法：结合ZSTD压缩和RLE编码，平衡传输速度和质量
- ✅ 实时响应：优化的网络传输和异步处理，确保流畅的用户体验
- ✅ 多客户端支持：服务端可同时处理多个客户端连接

## 技术栈

| 组件 | 技术 | 版本 |
|------|------|------|
| 服务端 | Java | 11+ |
| 服务端框架 | Spring Boot | 2.5+ |
| 网络通信 | Netty | 4.1+ |
| 压缩算法 | ZSTD | 1.5+ |
| HarmonyOS客户端 | ArkTS | 3.0+ |
| Java客户端 | Swing | - |

## 快速开始

### 1. 启动服务端

```bash
# 编译打包
cd server
mvn clean package

# 运行
java -jar target/server-1.0.0.jar
```

### 2. 运行Java客户端

```bash
# 编译打包
cd client
mvn clean package

# 运行
java -jar target/client-1.0.0.jar
```

### 3. 运行HarmonyOS客户端

1. 使用DevEco Studio打开项目 `HarmonOS_remote_desktop_control_client`
2. 编译构建HAP包
3. 安装到HarmonyOS设备
4. 配置服务器地址（修改 `config.ets`）

## 配置说明

### 服务端配置 (`server/src/main/resources/application.properties`)

```properties
# 服务端口
server.port=8080

# 屏幕捕获配置
capture.tile-size=32
capture.fps=30

# 压缩配置
compression.level=3
```

### Java客户端配置 (`client/config.properties`)

```properties
# 服务器地址
server.host=127.0.0.1
server.port=8080

# 捕获配置
capture.fps=30
```

### HarmonyOS客户端配置 (`HarmonOS_remote_desktop_control_client/entry/src/main/ets/config/config.ets`)

```typescript
export const SERVER_IP = '127.0.0.1';
export const SERVER_PORT = 8080;
export const MAX_FPS = 30;
```

## 项目结构

```
HamonyOS-remote-desktop-control/
├── server/             # Java服务端
├── client/             # Java客户端
├── HarmonOS_remote_desktop_control_client/  # HarmonyOS客户端
├── docs/               # 项目文档
└── latex_pdf/          # LaTeX文档
```

## 核心功能模块

1. **屏幕捕获模块**：使用Java AWT Robot进行屏幕捕获，支持分块处理
2. **压缩解压模块**：结合ZSTD和RLE算法，优化数据传输
3. **网络通信模块**：基于Netty的高性能网络通信
4. **客户端UI模块**：HarmonyOS和Java客户端的用户界面
5. **异步处理模块**：使用任务队列和线程池，提高性能

## 性能优化

- **增量更新**：只传输变化的屏幕区域
- **智能压缩**：ZSTD + RLE组合压缩
- **异步处理**：使用任务队列和线程池
- **内存优化**：减少内存分配和拷贝
- **网络优化**：调整TCP参数，提高传输效率

## 常见问题

### 连接失败
- 检查网络连接和服务器状态
- 确保防火墙允许指定端口的连接
- 确认使用正确的IP地址

### 屏幕显示异常
- 确保客户端和服务端使用相同的压缩配置
- 检查客户端设备的屏幕分辨率支持

### 性能卡顿
- 降低捕获帧率以减少网络带宽使用
- 调整压缩级别以提高速度
- 关闭不必要的应用，减少系统负载

## 未来计划

- ✅ 支持文件传输
- ✅ 支持音频传输
- ✅ 多显示器支持
- ✅ 远程开关机
- ✅ WebRTC集成

## 技术文档

详细的技术文档请参考 `docs/project_documentation.md`。

## 许可证

本项目采用 MIT 许可证。