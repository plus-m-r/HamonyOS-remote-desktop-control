# HarmonyOS模拟器连接问题诊断指南

## 问题描述
模拟器无法连接到服务端（IP: 10.11.108.247，端口: 12345/54321）

## 常见原因和解决方案

### 1. 网络配置问题

#### 检查服务端监听状态
```bash
# 在服务端机器上运行
netstat -an | findstr ":12345"
netstat -an | findstr ":54321"

# 或使用Linux命令
# netstat -tlnp | grep :12345
# netstat -tlnp | grep :54321
```

#### 检查服务端防火墙
```bash
# Windows防火墙
netsh advfirewall firewall show rule name=all | findstr "12345\|54321"

# Linux防火墙
# sudo ufw status
# sudo firewall-cmd --list-all
```

### 2. 模拟器网络配置

#### HarmonyOS模拟器网络模式
- **桥接模式**：模拟器使用主机网络，可以直接访问局域网
- **NAT模式**：模拟器使用虚拟网络，需要通过端口转发访问外部网络

#### 检查模拟器网络配置
1. 打开DevEco Studio
2. 进入Tools > Device Manager
3. 选择模拟器，点击"..." > Settings
4. 查看网络配置

### 3. 模拟器网络测试方法

#### 方法1：在模拟器内测试网络连接
```bash
# 在模拟器的终端中运行
ping 10.11.108.247
curl http://10.11.108.247:12345/remote-desktop-control
```

#### 方法2：使用ADB测试
```bash
# 连接到模拟器
adb connect 127.0.0.1:5555

# 在模拟器中执行命令
adb shell ping -c 4 10.11.108.247
adb shell curl http://10.11.108.247:12345/remote-desktop-control
```

### 4. 客户端配置检查

#### 确认config.ets配置
```typescript
// 检查 entry/src/main/ets/config/config.ets
export const SERVER_CONFIG: ServerConfig = {
  host: '10.11.108.247',  // 确保这是正确的服务端IP
  tcpPort: 54321,          // Netty服务器端口
  httpPort: 12345,         // HTTP服务器端口
  contextPath: '/remote-desktop-control'
}
```

#### 检查网络权限
```json5
// 检查 entry/src/main/module.json5
"requestPermissions": [
  {
    "name": "ohos.permission.INTERNET",
    "reason": "$string:internet_permission_reason",
    "usedScene": {
      "abilities": ["EntryAbility"],
      "when": "always"
    }
  },
  {
    "name": "ohos.permission.DISTRIBUTED_DATASYNC",
    "reason": "$string:datasync_permission_reason",
    "usedScene": {
      "abilities": ["EntryAbility"],
      "when": "always"
    }
  }
]
```

### 5. 模拟器网络问题解决方案

#### 方案A：使用模拟器端口转发
如果模拟器使用NAT模式，需要配置端口转发：

1. 在DevEco Studio中：
   - 打开File > Settings > Build, Execution, Deployment > HarmonyOS
   - 找到模拟器设置，配置端口转发

2. 或者使用命令行：
```bash
# 将主机端口转发到模拟器
adb forward tcp:12345 tcp:12345
adb forward tcp:54321 tcp:54321
```

#### 方案B：使用桥接模式
1. 关闭当前模拟器
2. 创建新的模拟器时选择"Bridge"网络模式
3. 启动模拟器，获取模拟器的IP地址

#### 方案C：使用本地环回地址
如果服务端运行在本地机器上：
1. 修改config.ets中的host为`127.0.0.1`或`localhost`
2. 确保服务端监听所有IP地址（0.0.0.0）

### 6. 调试步骤

#### 步骤1：检查服务端日志
查看服务端是否有连接请求：
```
# 服务端启动时应该显示：
# HTTP接口 ：运行在端口12345
# Netty服务器 ：运行在IP 10.11.108.247，端口54321
```

#### 步骤2：在模拟器中测试基本网络
```bash
# 在模拟器终端中
ping 8.8.8.8  # 测试互联网连接
ping 10.11.108.247  # 测试到服务端的连接
```

#### 步骤3：使用telnet测试端口
```bash
# 在主机上测试
telnet 10.11.108.247 12345
telnet 10.11.108.247 54321
```

#### 步骤4：检查客户端日志
在DevEco Studio的Logcat中查看客户端日志：
- 搜索"ConnectionTestPage"或"TcpClient"
- 查看连接错误信息

### 7. 快速故障排除

#### 如果HTTP连接失败：
1. 在浏览器中访问：http://10.11.108.247:12345/remote-desktop-control
2. 如果无法访问，检查服务端HTTP服务器
3. 检查防火墙是否阻止了端口12345

#### 如果TCP连接失败：
1. 使用telnet测试：`telnet 10.11.108.247 54321`
2. 如果连接失败，检查服务端Netty服务器
3. 检查防火墙是否阻止了端口54321

#### 如果模拟器无法访问网络：
1. 重启模拟器
2. 检查模拟器网络设置
3. 尝试使用不同的网络模式

### 8. 备用方案：使用本地测试

如果无法连接到远程服务端，可以：
1. 在本地运行服务端（修改IP为127.0.0.1）
2. 配置模拟器使用主机网络
3. 测试本地连接

## 诊断工具

我已创建了以下诊断文件：
1. `test_connection.js` - 连接测试说明
2. 本诊断指南

请按照上述步骤逐一排查，特别是：
1. 确认服务端正在运行并监听正确的IP和端口
2. 检查模拟器网络配置
3. 测试网络连通性