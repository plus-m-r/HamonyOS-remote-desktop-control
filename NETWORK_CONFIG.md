# 局域网IP配置说明

## 📋 本机网络信息

**局域网IP地址**: `10.19.91.247` (WLAN)

---

## 🔧 已完成的配置

### 1. Java服务端
- **状态**: ✅ 运行中 (PID 14044)
- **监听地址**: `0.0.0.0:54321` (所有网络接口)
- **HTTP API**: `http://10.19.91.247:12345/remote-desktop-control`

### 2. Java客户端
- **状态**: ✅ 运行中 (PID 27376)
- **配置文件**: `client/config.properties`
- **服务器地址**: `10.19.91.247:54321`
- **剪贴板服务**: `http://10.19.91.247:12345/remote-desktop-control`

### 3. HarmonyOS客户端
需要修改以下文件中的服务器IP：

#### 文件1: GlobalContext.ets
```typescript
// 路径: HarmonOS_remote_desktop_control_client/entry/src/main/ets/utils/GlobalContext.ets
export class GlobalContext {
  private static readonly SERVER_IP = '10.19.91.247';  // 修改此处
  private static readonly SERVER_PORT = 54321;
  // ...
}
```

#### 文件2: 其他可能硬编码IP的地方
搜索项目中的所有 `.ets` 文件，查找IP地址并替换为 `10.19.91.247`

---

## 🚀 启动顺序

1. **启动Java服务端**
   ```bash
   cd c:\learn\HamonyOS-remote-desktop-control\server
   java -jar target\server-1.0.0.jar
   ```

2. **启动Java客户端**
   ```bash
   cd c:\learn\HamonyOS-remote-desktop-control\client
   java -jar target\RemoteClient.jar
   ```

3. **编译并运行HarmonyOS客户端**
   ```bash
   cd HarmonOS_remote_desktop_control_client
   .\build_with_env.bat
   # 然后在DevEco Studio中运行
   ```

---

## 🔍 验证连接

### 检查服务端是否正常运行
```powershell
# 查看Java进程
Get-Process | Where-Object {$_.ProcessName -eq "java"} | Select-Object Id, ProcessName, @{Name="Memory(MB)";Expression={[math]::Round($_.WorkingSet/1MB,2)}}

# 应该看到至少2个Java进程（服务端和客户端）
```

### 测试端口连通性
```powershell
# 测试Netty端口
Test-NetConnection -ComputerName 10.19.91.247 -Port 54321

# 测试HTTP端口
Test-NetConnection -ComputerName 10.19.91.247 -Port 12345
```

### 访问Web管理界面
在浏览器中打开：
```
http://10.19.91.247:12345/remote-desktop-control
```

---

## 📝 注意事项

### 防火墙设置
确保Windows防火墙允许以下端口的入站连接：
- **54321** (TCP) - Netty远程控制
- **12345** (TCP) - HTTP API
- **49152** (TCP) - Robot服务（可选）

### 局域网访问
其他设备（如HarmonyOS设备）需要：
1. 连接到同一个局域网（WiFi）
2. 使用IP地址 `10.19.91.247` 连接服务端
3. 确保没有被路由器或防火墙阻止

### IP地址变化
如果重启电脑或重新连接WiFi，IP地址可能会改变。需要：
1. 重新获取IP：`ipconfig`
2. 更新所有配置文件中的IP地址
3. 重启所有服务

---

## 🎯 当前状态

| 组件 | 状态 | IP地址 | 端口 |
|------|------|--------|------|
| Java服务端 | ✅ 运行中 | 10.19.91.247 | 54321, 12345 |
| Java客户端 | ✅ 运行中 | 指向 10.19.91.247 | - |
| HarmonyOS客户端 | ⏸️ 待配置 | 需要修改IP | - |

---

**最后更新**: 2026-04-25 09:17  
**配置人员**: AI Assistant
