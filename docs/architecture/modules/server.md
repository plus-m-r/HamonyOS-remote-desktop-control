# 服务端模块 (server) - API详细文档

## 1. 模块概述

**职责**：会话管理、协议路由、数据持久化、安全认证

**位置**：`server/src/main/java/io/github/springstudent/dekstop/server`

**技术栈**：Spring Boot + Netty + Database

---

## 2. 子模块结构

```
server/
├── netty/          # Netty网络框架集成
├── core/           # 核心业务逻辑
├── clipboard/      # 剪贴板管理
├── file/           # 文件服务
└── RemoteServer.java  # Spring Boot启动类
```

---

## 3. RemoteServer.java

**包路径**：`io.github.springstudent.dekstop.server`

**职责**：Spring Boot应用入口

**关键注解**：
```java
@SpringBootApplication
@EnableScheduling
```

**启动方法**：
```java
public static void main(String[] args) {
    SpringApplication.run(RemoteServer.class, args);
}
```

**配置项**（application.properties）：
```properties
server.port=8080
netty.port=9090
session.timeout=900
database.url=jdbc:mysql://localhost:3306/remote_desktop
```

---

## 4. netty 子模块

### 4.1 NettyServer.java

**职责**：Netty服务端启动器

**关键API**：
```java
public void start(int port)
public void stop()
public int getConnectedCount()
```

**配置**：
- Boss线程池：1个线程（接受连接）
- Worker线程池：CPU核心数 * 2（处理IO）
-  backlog：128
- TCP参数：SO_KEEPALIVE, TCP_NODELAY

---

### 4.2 ServerChannelHandler.java

**职责**：Netty通道处理器

**继承**：`SimpleChannelInboundHandler<Cmd>`

**关键方法**：
```java
@Override
protected void channelRead0(ChannelHandlerContext ctx, Cmd msg) {
    // 1. 会话验证
    Session session = sessionManager.getSession(ctx.channel());
    
    // 2. 命令路由
    CommandRouter.route(msg, session, ctx);
}

@Override
public void channelActive(ChannelHandlerContext ctx) {
    // 新连接建立
    sessionManager.register(ctx.channel());
}

@Override
public void channelInactive(ChannelHandlerContext ctx) {
    // 连接断开
    sessionManager.unregister(ctx.channel());
}
```

---

### 4.3 SessionManager.java

**职责**：会话管理器

**核心数据结构**：
```java
private ConcurrentHashMap<String, Session> sessions;  // sessionId -> Session
private ConcurrentHashMap<Channel, String> channelToSession;  // Channel -> sessionId
```

**关键API**：
```java
public Session createSession(DeviceCredentials credentials)
public void register(Channel channel, String sessionId)
public void unregister(Channel channel)
public Session getSession(Channel channel)
public List<Session> getAllSessions()
public void broadcast(Cmd cmd)
```

**会话生命周期**：
1. 设备认证 → 创建Session
2. 注册Channel → 绑定Session
3. 活跃期间 → 心跳保活
4. 断开连接 → 清理Session

---

## 5. core 子模块

### 5.1 CommandRouter.java

**职责**：命令路由器

**关键方法**：
```java
public static void route(Cmd cmd, Session session, ChannelHandlerContext ctx) {
    switch (cmd.getCmdType()) {
        case ReqPing:
            handlePing(cmd, session, ctx);
            break;
        case ReqOpen:
            handleOpen(cmd, session, ctx);
            break;
        case KeyControl:
        case MouseControl:
            forwardToDevice(cmd, session);
            break;
        // ... 其他命令
    }
}
```

**路由策略**：
- 心跳命令 → 本地响应
- 控制命令 → 转发到被控端
- 文件命令 → 文件服务处理
- 会话命令 → 会话管理

---

### 5.2 DeviceManager.java

**职责**：设备管理

**关键API**：
```java
public Device registerDevice(DeviceInfo info)
public Device getDevice(String deviceId)
public List<Device> getOnlineDevices()
public void updateDeviceStatus(String deviceId, DeviceStatus status)
```

**设备状态**：
- ONLINE - 在线
- OFFLINE - 离线
- BUSY - 忙碌（已被控制）

---

## 6. clipboard 子模块

### 6.1 ClipboardManager.java

**职责**：剪贴板管理中继

**关键API**：
```java
public void syncClipboard(String sessionId, RemoteClipboard clipboard)
public RemoteClipboard getClipboard(String sessionId)
public void clearClipboard(String sessionId)
```

**工作流程**：
1. 被控端剪贴板变化 → 发送到服务端
2. 服务端存储 → 通知控制端
3. 控制端接收 → 更新本地剪贴板

---

## 7. file 子模块

### 7.1 FileService.java

**职责**：文件传输服务

**关键API**：
```java
public List<FileInfo> listFiles(String sessionId, String path)
public void uploadFile(String sessionId, String path, byte[] data)
public byte[] downloadFile(String sessionId, String path)
public void deleteFile(String sessionId, String path)
```

**安全措施**：
- 路径遍历检查（防止`../`攻击）
- 文件大小限制（默认100MB）
- 文件类型白名单
- 访问权限验证

---

## 8. 数据库设计

### 8.1 用户表 (users)

```sql
CREATE TABLE users (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### 8.2 设备表 (devices)

```sql
CREATE TABLE devices (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    device_id VARCHAR(64) UNIQUE NOT NULL,
    device_name VARCHAR(100),
    owner_id BIGINT,
    status ENUM('ONLINE', 'OFFLINE', 'BUSY') DEFAULT 'OFFLINE',
    last_seen TIMESTAMP,
    FOREIGN KEY (owner_id) REFERENCES users(id)
);
```

### 8.3 会话表 (sessions)

```sql
CREATE TABLE sessions (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    session_id VARCHAR(64) UNIQUE NOT NULL,
    controller_id BIGINT,
    controlled_device_id BIGINT,
    start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP NULL,
    status ENUM('ACTIVE', 'CLOSED') DEFAULT 'ACTIVE'
);
```

### 8.4 审计日志表 (audit_logs)

```sql
CREATE TABLE audit_logs (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    session_id VARCHAR(64),
    action VARCHAR(50),
    details TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_session (session_id),
    INDEX idx_timestamp (timestamp)
);
```

---

## 9. 安全机制

### 9.1 双向TLS认证

**配置**：
```java
SslContext sslContext = SslContextBuilder.forServer(certChain, privateKey)
    .trustManager(caCert)
    .clientAuth(ClientAuth.REQUIRE)
    .build();
```

**流程**：
1. 服务端发送证书
2. 客户端验证服务端证书
3. 客户端发送证书
4. 服务端验证客户端证书
5. 建立加密通道

---

### 9.2 RBAC权限控制

**角色定义**：
- SUPER_ADMIN - 超级管理员
- ADMIN - 管理员
- CONTROLLER - 控制者
- OBSERVER - 观察者（只读）

**权限检查**：
```java
public boolean hasPermission(Session session, Permission permission) {
    Role role = session.getRole();
    return role.getPermissions().contains(permission);
}
```

---

## 10. 性能优化

### 10.1 连接池

**配置**：
```java
HikariConfig config = new HikariConfig();
config.setMaximumPoolSize(50);
config.setMinimumIdle(10);
config.setConnectionTimeout(30000);
```

---

### 10.2 缓存策略

**Redis缓存**：
- 会话信息（TTL: 15分钟）
- 设备状态（TTL: 5分钟）
- 用户权限（TTL: 30分钟）

---

## 11. 监控与日志

### 11.1 指标监控

**Prometheus指标**：
- `connected_sessions_total` - 当前会话数
- `messages_received_total` - 接收消息总数
- `messages_sent_total` - 发送消息总数
- `message_processing_duration_seconds` - 消息处理耗时

---

### 11.2 日志配置

**Log4j2配置**：
```xml
<Appenders>
    <Console name="Console" target="SYSTEM_OUT">
        <PatternLayout pattern="%d{HH:mm:ss.SSS} [%t] %-5level %logger{36} - %msg%n"/>
    </Console>
    <RollingFile name="File" fileName="logs/server.log">
        <PatternLayout pattern="%d{yyyy-MM-dd HH:mm:ss.SSS} [%t] %-5level %logger{36} - %msg%n"/>
        <Policies>
            <TimeBasedTriggeringPolicy interval="1"/>
            <SizeBasedTriggeringPolicy size="100 MB"/>
        </Policies>
    </RollingFile>
</Appenders>
```

---

**文档版本**：v1.0  
**最后更新**：2026-05-10  
**维护团队**：方寸控技术团队
