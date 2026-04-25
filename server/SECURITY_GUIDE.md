# 数据库配置安全指南

## 📋 已完成的改进

### 1. .gitignore 更新
已将以下配置文件加入忽略列表：
- `application-local.properties` - 本地开发配置
- `application-dev.properties` - 开发环境配置
- `application-prod.properties` - 生产环境配置
- `*.env` - 环境变量文件

### 2. 配置文件模板
创建了 `application.properties.example` 作为配置模板，包含占位符密码。

### 3. 安全警告
在 `application.properties` 中添加了安全警告注释，提醒开发者不要提交敏感信息。

### 4. 配置文档
创建了 `DATABASE_CONFIG.md` 详细说明如何配置数据库。

---

## 🔒 推荐的安全实践

### 方案一：使用 application-local.properties（推荐）

1. 复制模板文件：
```bash
cp server/src/main/resources/application.properties.example \
   server/src/main/resources/application-local.properties
```

2. 修改 `application-local.properties` 中的数据库配置：
```properties
spring.datasource.url=jdbc:mysql://YOUR_HOST:3306/remote-desktop-control?...
spring.datasource.username=YOUR_USERNAME
spring.datasource.password=YOUR_PASSWORD
```

3. 启动时指定profile：
```bash
java -jar server/target/server-1.0.0.jar --spring.profiles.active=local
```

**优点**：
- ✅ 敏感信息不会提交到Git
- ✅ 可以为不同环境创建不同的配置文件
- ✅ Spring Boot自动支持多profile

---

### 方案二：使用环境变量（生产环境推荐）

1. 设置环境变量：
```bash
export DB_URL=jdbc:mysql://localhost:3306/remote-desktop-control?...
export DB_USERNAME=root
export DB_PASSWORD=your_password
```

2. 修改 `application.properties`：
```properties
spring.datasource.url=${DB_URL}
spring.datasource.username=${DB_USERNAME}
spring.datasource.password=${DB_PASSWORD}
```

**优点**：
- ✅ 最安全的方案
- ✅ 适合容器化部署（Docker/K8s）
- ✅ 配置与代码完全分离

---

### 方案三：使用外部配置文件

1. 将配置文件放在应用外部：
```bash
java -jar server/target/server-1.0.0.jar \
  --spring.config.location=file:/path/to/external/application.properties
```

**优点**：
- ✅ 配置文件不在项目中
- ✅ 便于运维管理

---

## ⚠️ 当前状态

目前 `application.properties` 仍包含真实密码（`619927`），建议：

1. **立即行动**：创建 `application-local.properties` 并迁移配置
2. **修改密码**：更改数据库密码为更安全的密码
3. **提交代码**：提交 `.gitignore` 和模板文件，但不要提交包含密码的文件

---

## 📝 Git 提交检查清单

在提交代码前，请确认：

- [ ] `application-local.properties` 没有被提交
- [ ] `application-dev.properties` 没有被提交
- [ ] `application-prod.properties` 没有被提交
- [ ] `.env` 文件没有被提交
- [ ] `application.properties.example` 已提交（模板文件）
- [ ] `DATABASE_CONFIG.md` 已提交（配置文档）
- [ ] `.gitignore` 已更新并提交

---

## 🔍 验证配置是否被忽略

运行以下命令检查：

```bash
git status
```

确保没有显示以下文件：
- `application-local.properties`
- `application-dev.properties`
- `application-prod.properties`
- `.env`

如果看到这些文件，说明 `.gitignore` 配置有误。

---

## 📚 相关文档

- [Spring Boot 多环境配置](https://docs.spring.io/spring-boot/docs/current/reference/html/features.html#features.external-config.profiles)
- [Spring Boot 外部化配置](https://docs.spring.io/spring-boot/docs/current/reference/html/features.html#features.external-config)
