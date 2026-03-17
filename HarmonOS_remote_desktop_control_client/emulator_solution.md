# HarmonyOS模拟器连接问题解决方案

## 问题分析
模拟器无法连接到服务端（IP: 10.11.108.247），这通常是由于以下原因：

### 常见原因
1. **模拟器网络模式限制** - 模拟器可能使用NAT模式，无法直接访问局域网
2. **防火墙阻止** - Windows防火墙可能阻止了端口访问
3. **IP地址不可达** - 模拟器网络与服务器网络不在同一子网
4. **服务端监听配置** - 服务端可能只监听localhost或特定IP

## 解决方案

### 方案1：修改服务端监听地址（推荐）
如果服务端运行在您的开发机器上：

1. **修改服务端配置**，使其监听所有网络接口：
   ```java
   // 在服务端代码中，将监听地址改为 0.0.0.0
   server.bind(new InetSocketAddress("0.0.0.0", 54321));
   httpServer.listen(12345, "0.0.0.0");
   ```

2. **修改客户端配置**，使用主机IP或特殊地址：
   ```typescript
   // 修改 config.ets 文件
   export const SERVER_CONFIG: ServerConfig = {
     // 方案A：使用主机IP（如果模拟器可以访问）
     host: '192.168.x.x',  // 替换为您的实际主机IP
     
     // 方案B：使用特殊地址（如果模拟器使用NAT）
     // host: '10.0.2.2',  // Android模拟器的特殊地址
     // host: 'host.docker.internal',  // Docker容器的特殊地址
     
     tcpPort: 54321,
     httpPort: 12345,
     contextPath: '/remote-desktop-control'
   }
   ```

### 方案2：配置模拟器网络

#### 对于HarmonyOS模拟器：
1. **使用桥接模式**：
   - 关闭当前模拟器
   - 在DevEco Studio中：Tools > Device Manager
   - 点击"Create"创建新模拟器
   - 在"Network"选项中选择"Bridge"
   - 启动模拟器，获取模拟器的IP地址

2. **配置端口转发**（如果使用NAT模式）：
   ```bash
   # 在命令行中执行
   adb forward tcp:12345 tcp:12345
   adb forward tcp:54321 tcp:54321
   ```

### 方案3：使用本地测试配置

#### 临时解决方案（快速测试）：
1. **修改客户端配置使用localhost**：
   ```typescript
   // 临时修改 config.ets
   export const SERVER_CONFIG: ServerConfig = {
     host: '127.0.0.1',  // 或 'localhost'
     tcpPort: 54321,
     httpPort: 12345,
     contextPath: '/remote-desktop-control'
   }
   ```

2. **确保服务端监听localhost**：
   - 启动服务端时确保绑定到127.0.0.1或0.0.0.0

### 方案4：网络诊断步骤

#### 步骤1：在模拟器中测试网络
```bash
# 通过ADB连接到模拟器
adb connect 127.0.0.1:5555

# 测试网络连通性
adb shell ping -c 4 10.11.108.247
adb shell curl http://10.11.108.247:12345/remote-desktop-control
```

#### 步骤2：检查模拟器网络配置
```bash
# 查看模拟器网络信息
adb shell ifconfig
adb shell ip route
```

#### 步骤3：检查防火墙设置
```bash
# Windows防火墙
netsh advfirewall firewall add rule name="HarmonyOS Remote Control HTTP" dir=in action=allow protocol=TCP localport=12345
netsh advfirewall firewall add rule name="HarmonyOS Remote Control TCP" dir=in action=allow protocol=TCP localport=54321
```

### 方案5：使用替代IP地址

#### 根据模拟器类型使用不同的IP：
- **HarmonyOS模拟器（NAT模式）**：`10.0.2.2`（主机回环地址）
- **HarmonyOS模拟器（桥接模式）**：使用主机实际IP
- **物理设备**：使用服务端局域网IP

#### 修改config.ets为动态配置：
```typescript
// 根据运行环境动态选择IP
function getServerHost(): string {
  // 这里可以根据运行环境返回不同的IP
  // 例如：检查是否在模拟器中运行
  return '10.11.108.247'; // 默认使用服务端IP
}

export const SERVER_CONFIG: ServerConfig = {
  host: getServerHost(),
  tcpPort: 54321,
  httpPort: 12345,
  contextPath: '/remote-desktop-control'
}
```

## 快速修复步骤

### 立即尝试的解决方案：

1. **修改客户端IP为localhost**（如果服务端在本地）：
   ```bash
   # 编辑 config.ets 文件
   # 将 host: '10.11.108.247' 改为 host: '127.0.0.1'
   ```

2. **运行网络测试脚本**：
   ```bash
   # 在项目目录中运行
   .\network_test.bat
   ```

3. **检查服务端日志**：
   - 确认服务端显示"正在监听 0.0.0.0:54321"和"0.0.0.0:12345"

4. **在模拟器中打开浏览器测试**：
   - 在模拟器中打开浏览器
   - 访问：http://10.11.108.247:12345/remote-desktop-control
   - 或访问：http://127.0.0.1:12345/remote-desktop-control

## 调试技巧

### 查看客户端日志：
1. 在DevEco Studio中运行应用
2. 打开Logcat窗口
3. 过滤日志：`tag:ConnectionTestPage` 或 `tag:TcpClient`

### 启用详细日志：
在客户端代码中添加更多日志：
```typescript
console.info(`尝试连接到: ${this.host}:${this.port}`);
console.error(`连接失败: ${error}`);
```

### 测试连接的不同阶段：
1. **DNS解析**：能否解析主机名
2. **TCP握手**：能否建立TCP连接
3. **HTTP请求**：能否发送HTTP请求
4. **数据交换**：能否发送/接收数据

## 最终建议

如果以上方案都不行，建议：

1. **在物理HarmonyOS设备上测试** - 排除模拟器网络问题
2. **使用Wireshark抓包分析** - 查看网络流量
3. **检查路由器/网络设备** - 确保网络互通
4. **联系网络管理员** - 检查网络策略限制

## 创建测试版本

我已创建了以下文件帮助诊断：
1. `network_test.bat` - Windows网络测试脚本
2. `diagnose_connection.md` - 详细诊断指南
3. `emulator_solution.md` - 本解决方案文档

请按照上述步骤逐一尝试，通常方案1或方案3能解决大多数模拟器连接问题。