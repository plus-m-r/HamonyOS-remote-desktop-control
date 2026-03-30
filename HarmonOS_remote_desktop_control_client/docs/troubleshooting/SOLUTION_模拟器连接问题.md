 HarmonyOS模拟器连接问题 - 综合解决方案

## 📋 问题概述
模拟器无法连接到服务端 `10.11.108.247:12345/54321`

## 🔍 根本原因分析

### 可能的原因：
1. **模拟器网络隔离** - HarmonyOS模拟器默认使用NAT网络，无法直接访问局域网
2. **防火墙阻止** - Windows防火墙可能阻止了端口访问
3. **IP地址不可达** - 模拟器与服务器不在同一网络
4. **服务端监听配置** - 服务端可能只绑定到特定IP

## 🚀 快速解决方案

### 方案1：使用localhost（最快速）
如果服务端运行在您的开发机器上：

**步骤：**
1. 修改 `entry/src/main/ets/config/config.ets`：
   ```typescript
   // 将第10行改为：
   host: '127.0.0.1',  // 或 'localhost'
   ```

2. 确保服务端监听所有接口（0.0.0.0）或localhost

3. 重新编译并运行应用

### 方案2：使用模拟器特殊地址
如果使用Android/HarmonyOS模拟器：

**步骤：**
1. 修改 `entry/src/main/ets/config/config.ets`：
   ```typescript
   // 将第10行改为：
   host: '10.0.2.2',  // Android模拟器访问主机的特殊地址
   ```

2. 确保服务端监听所有接口（0.0.0.0）

3. 重新编译并运行应用

### 方案3：使用主机实际IP
如果模拟器使用桥接模式：

**步骤：**
1. 获取您的主机IP地址：
   ```bash
   # Windows
   ipconfig
   # Linux/Mac
   ifconfig
   ```

2. 修改 `entry/src/main/ets/config/config.ets`：
   ```typescript
   // 将第10行改为：
   host: '192.168.x.x',  // 替换为您的实际主机IP
   ```

3. 确保防火墙允许端口12345和54321

## 🛠️ 诊断工具

### 1. 运行网络测试脚本
```bash
# 在项目目录中运行
.\network_test.bat
```

### 2. 在模拟器中测试连接
```bash
# 通过ADB连接到模拟器
adb connect 127.0.0.1:5555

# 测试HTTP连接
adb shell curl -v http://10.11.108.247:12345/remote-desktop-control

# 测试TCP连接
adb shell nc -zv 10.11.108.247 54321
```

### 3. 检查服务端状态
确保服务端显示：
```
HTTP接口 ：运行在端口12345
Netty服务器 ：运行在IP 10.11.108.247，端口54321
```

## 📝 配置文件修改指南

### 当前配置文件位置：
`entry/src/main/ets/config/config.ets`

### 可用的配置选项：

#### 选项A：使用原始服务端IP（如果网络可达）
```typescript
host: '10.11.108.247'
```

#### 选项B：使用localhost（服务端在本地）
```typescript
host: '127.0.0.1'
```

#### 选项C：使用模拟器特殊地址
```typescript
host: '10.0.2.2'
```

#### 选项D：使用主机实际IP
```typescript
host: '192.168.1.100'  // 替换为您的实际IP
```

## 🔧 服务端配置检查

### 确保服务端监听正确地址：
```java
// Java服务端应该监听所有接口
server.bind(new InetSocketAddress("0.0.0.0", 54321));
httpServer.listen(12345, "0.0.0.0");
```

### 检查服务端防火墙：
```bash
# Windows
netsh advfirewall firewall add rule name="RemoteControl-HTTP" dir=in action=allow protocol=TCP localport=12345
netsh advfirewall firewall add rule name="RemoteControl-TCP" dir=in action=allow protocol=TCP localport=54321

# Linux
sudo ufw allow 12345/tcp
sudo ufw allow 54321/tcp
```

## 📊 测试步骤

### 步骤1：基本连接测试
1. 在浏览器中访问：`http://10.11.108.247:12345/remote-desktop-control`
2. 使用telnet测试：`telnet 10.11.108.247 54321`

### 步骤2：模拟器内测试
1. 启动HarmonyOS模拟器
2. 打开浏览器应用
3. 访问：`http://10.11.108.247:12345/remote-desktop-control`

### 步骤3：应用内测试
1. 启动HarmonyOS应用
2. 进入"连接测试"页面
3. 点击"测试HTTP连接"按钮

## 🐛 常见错误及解决方案

### 错误1：Connection refused
**原因**：服务端未运行或端口被阻止
**解决**：
- 确认服务端正在运行
- 检查防火墙设置
- 确认服务端监听0.0.0.0

### 错误2：Network is unreachable
**原因**：模拟器无法访问目标网络
**解决**：
- 使用localhost或10.0.2.2
- 切换模拟器网络模式为桥接
- 检查主机网络配置

### 错误3：Timeout
**原因**：网络延迟或服务端无响应
**解决**：
- 增加连接超时时间
- 检查网络稳定性
- 确认服务端负载正常

## 📋 检查清单

### 服务端检查：
- [ ] 服务端进程正在运行（PID: 32337）
- [ ] HTTP服务器监听端口12345
- [ ] Netty服务器监听端口54321
- [ ] 服务端绑定到0.0.0.0
- [ ] 防火墙允许端口12345和54321

### 客户端检查：
- [ ] config.ets中IP地址正确
- [ ] module.json5包含网络权限
- [ ] 应用编译成功
- [ ] 模拟器网络配置正确

### 网络检查：
- [ ] 主机可以ping通10.11.108.247
- [ ] 端口12345和54321可访问
- [ ] 模拟器可以访问主机网络

## 🎯 推荐方案

### 对于开发测试环境：
1. **首选方案**：使用localhost（127.0.0.1）
2. **备用方案**：使用模拟器特殊地址（10.0.2.2）
3. **最终方案**：使用主机实际IP + 桥接模式

### 对于生产环境：
1. 使用固定服务器IP
2. 配置正确的DNS
3. 确保网络路由可达

## 📞 进一步帮助

如果以上方案都无法解决问题：

1. **查看详细日志**：
   - 服务端日志：检查连接请求
   - 客户端日志：查看错误详情
   - 模拟器日志：网络相关错误

2. **网络抓包分析**：
   ```bash
   # 使用Wireshark或tcpdump
   tcpdump -i any port 12345 or port 54321
   ```

3. **联系支持**：
   - 提供完整的错误日志
   - 提供网络配置信息
   - 提供服务端和客户端版本

## ✅ 完成状态

我已完成的配置：
1. ✅ 更新了客户端配置文件，支持动态环境检测
2. ✅ 创建了网络测试脚本（network_test.bat）
3. ✅ 提供了详细的诊断指南（diagnose_connection.md）
4. ✅ 创建了模拟器专用解决方案（emulator_solution.md）
5. ✅ 增强了ConnectionTest页面的错误处理

现在您可以：
1. 尝试使用localhost配置（方案1）
2. 运行网络测试脚本验证连通性
3. 按照检查清单逐一排查问题