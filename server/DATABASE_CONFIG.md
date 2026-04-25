# 服务端配置说明

## 数据库配置

### 1. 复制配置文件模板

```bash
cp server/src/main/resources/application.properties.example server/src/main/resources/application-local.properties
```

### 2. 修改数据库配置

编辑 `application-local.properties` 文件，修改以下配置：

```properties
# 数据库连接地址
spring.datasource.url=jdbc:mysql://YOUR_HOST:3306/remote-desktop-control?...

# 数据库用户名
spring.datasource.username=YOUR_USERNAME

# 数据库密码
spring.datasource.password=YOUR_PASSWORD
```

### 3. 启动服务

使用本地配置文件启动：

```bash
java -jar server/target/server-1.0.0.jar --spring.profiles.active=local
```

或者在IDE中设置VM参数：

```
-Dspring.profiles.active=local
```

## 安全建议

1. **不要提交敏感信息**：`application-local.properties` 已在 `.gitignore` 中配置
2. **使用环境变量**：生产环境建议使用环境变量管理敏感配置
3. **定期更换密码**：建议定期更换数据库密码

## 数据库初始化

执行 `server/src/main/resources/sql/` 目录下的SQL脚本创建数据库和表结构。
