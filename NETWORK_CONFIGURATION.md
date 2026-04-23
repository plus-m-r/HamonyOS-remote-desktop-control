# 网络配置说明

## 当前配置

所有客户端已配置为连接到本机局域网IP：**10.34.4.128**

### Java客户端配置

**配置文件**: `client/config.properties`

```properties
# 服务器配置
serverIp=10.34.4.128
serverPort=54321
clipboardServer=http://10.34.4.128:12345/remote-desktop-control
robotPort=49152
```

### HarmonyOS客户端配置

**配置文件**: `HarmonOS_remote_desktop_control_client/entry/src/main/ets/config/ConfigCenter.ets`

已在以下环境中更新：
- ✅ DEFAULT_CONFIG（默认配置）
- ✅ development（开发环境）
- ✅ production（生产环境）

```typescript
server: {
  host: '10.34.4.128',
  tcpPort: 54321,
  httpPort: 12345,
  contextPath: '/remote-desktop-control'
}
```

## 端口说明

| 服务 | 端口 | 协议 | 用途 |
|------|------|------|------|
| HTTP API | 12345 | HTTP | REST API、剪贴板同步、文件传输 |
| TCP控制 | 54321 | TCP | 远程桌面控制通信 |
| Robot | 49152 | TCP | 自动化控制（可选） |

## 如何修改IP地址

### 如果需要更改到其他IP地址：

#### 1. Java客户端
编辑 `client/config.properties`，修改：
```properties
serverIp=新的IP地址
clipboardServer=http://新的IP地址:12345/remote-desktop-control
```

#### 2. HarmonyOS客户端
编辑 `HarmonOS_remote_desktop_control_client/entry/src/main/ets/config/ConfigCenter.ets`，修改以下三处：
- `DEFAULT_CONFIG.server.host`
- `ENVIRONMENT_CONFIGS.development.server.host`
- `ENVIRONMENT_CONFIGS.production.server.host`

## 获取本机局域网IP

在Windows上运行：
```powershell
ipconfig | findstr "IPv4"
```

在macOS/Linux上运行：
```bash
ifconfig | grep "inet "
# 或
ip addr show
```

## 防火墙设置

确保防火墙允许以下端口的入站连接：
- TCP 12345
- TCP 54321
- TCP 49152（如果使用Robot功能）

### Windows防火墙配置

```powershell
# 添加防火墙规则
New-NetFirewallRule -DisplayName "Remote Desktop Control" -Direction Inbound -Protocol TCP -LocalPort 12345,54321,49152 -Action Allow
```

## 测试连接

### 测试TCP连接
```bash
telnet 10.34.4.128 54321
```

### 测试HTTP连接
```bash
curl http://10.34.4.128:12345/remote-desktop-control
```

## 常见问题

### Q1: 连接失败怎么办？

**A**: 检查以下几点：
1. 确认服务端正在运行
2. 确认IP地址正确
3. 检查防火墙设置
4. 确认客户端和服务端在同一局域网

### Q2: 如何在不同网络环境下使用？

**A**: 
- **同一局域网**: 使用局域网IP（如 10.34.4.128）
- **跨网络**: 需要配置端口转发或使用内网穿透工具
- **模拟器**: HarmonyOS模拟器使用 `10.0.2.2` 访问宿主机

### Q3: 如何查看当前配置是否生效？

**A**: 
- **Java客户端**: 查看启动日志中的连接信息
- **HarmonyOS客户端**: 在DevEco Studio控制台查看ConfigCenter的初始化日志

## 配置历史

| 日期 | IP地址 | 说明 |
|------|--------|------|
| 之前 | 10.34.10.119 | 旧配置 |
| 2026-04-23 | 10.34.4.128 | 当前配置（本机局域网IP） |

---

**最后更新**: 2026-04-23
