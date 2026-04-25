# 客户端配置说明

## 📋 当前配置状态

### Java客户端
- **配置文件**: `client/config.properties`
- **服务器地址**: `127.0.0.1` (本机)
- **TCP端口**: `54321`
- **HTTP端口**: `12345`
- **状态**: ✅ 已配置为本机

### HarmonyOS客户端
- **配置文件**: `HarmonOS_remote_desktop_control_client/entry/src/main/ets/config/ConfigCenter.ets`
- **默认环境**: `10.34.29.75` (局域网IP)
- **模拟器环境**: `10.0.2.2` (模拟器访问宿主机)
- **状态**: ✅ 已配置为局域网IP

---

## 🔧 配置说明

### HarmonyOS客户端环境配置

#### 1. 默认配置（DEFAULT_CONFIG）
```typescript
server: {
  host: '10.34.29.75',  // 局域网IP，用于真机连接
  tcpPort: 54321,
  httpPort: 12345,
  contextPath: '/remote-desktop-control'
}
```

#### 2. 开发环境（development）
```typescript
host: '10.34.29.75'  // 局域网IP
```

#### 3. 测试环境（testing）
```typescript
host: '10.34.29.75'  // 局域网IP
```

#### 4. 生产环境（production）
```typescript
host: '10.34.29.75'  // 当前为局域网IP，生产部署需修改为实际服务器IP
```

#### 5. 模拟器环境（emulator）
```typescript
host: '10.0.2.2'  // HarmonyOS模拟器访问宿主机
```

---

## 🌐 不同场景的配置建议

### 场景1: 真机调试（USB连接）
使用 `127.0.0.1` 或局域网IP

**配置**:
```typescript
host: '127.0.0.1'  // 如果服务端在同一设备
// 或
host: '192.168.x.x'  // 局域网IP
```

### 场景2: 模拟器调试
使用 `10.0.2.2`（HarmonyOS模拟器专用）

**配置**:
```typescript
host: '10.0.2.2'  // 模拟器访问宿主机
```

### 场景3: 远程服务器
使用服务器的公网IP或域名

**配置**:
```typescript
host: 'your-server-ip.com'
```

---

## 📝 如何切换环境

### 方法1: 修改默认配置
直接编辑 `ConfigCenter.ets` 中的 `DEFAULT_CONFIG`

### 方法2: 设置环境变量
在应用启动时设置环境：
```typescript
configCenter.setEnvironment('development');
```

### 方法3: 使用不同的构建配置
为不同环境创建不同的编译配置

---

## ⚠️ 注意事项

1. **真机 vs 模拟器**:
   - 真机使用 `127.0.0.1` 或局域网IP
   - 模拟器必须使用 `10.0.2.2`

2. **防火墙设置**:
   确保服务端端口已开放：
   - TCP: `54321`
   - HTTP: `12345`

3. **网络连通性**:
   测试连接：
   ```bash
   # 测试TCP连接
   telnet 127.0.0.1 54321
   
   # 测试HTTP连接
   curl http://127.0.0.1:12345/remote-desktop-control
   ```

4. **生产环境**:
   部署到生产环境时，记得修改 `production` 配置的 `host` 为实际服务器地址

---

## 🔍 验证配置

### Java客户端
查看 `client/config.properties`:
```properties
serverIp=127.0.0.1
serverPort=54321
clipboardServer=http://127.0.0.1:12345/remote-desktop-control
```

### HarmonyOS客户端
查看日志输出：
```
ConfigCenter: Environment set to development
服务器: {"host":"127.0.0.1","tcpPort":54321,"httpPort":12345,"contextPath":"/remote-desktop-control"}
```

---

## 📊 配置对比表

| 环境 | Host | 用途 | 适用场景 |
|------|------|------|----------|
| DEFAULT | 10.34.29.75 | 默认配置 | 真机连接局域网服务端 |
| development | 10.34.29.75 | 开发环境 | 真机调试 |
| testing | 10.34.29.75 | 测试环境 | 真机集成测试 |
| production | 10.34.29.75 | 生产环境 | 需修改为实际服务器IP |
| emulator | 10.0.2.2 | 模拟器 | HarmonyOS模拟器 |

---

**最后更新**: 2026-04-24
