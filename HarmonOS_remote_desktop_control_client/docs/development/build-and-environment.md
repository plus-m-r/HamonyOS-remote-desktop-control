# 构建与开发环境

## 1. 开发环境

- 操作系统：Windows / Linux / macOS
- HarmonyOS SDK：兼容当前项目的 HarmonyOS SDK 版本
- `hvigor`：项目构建工具
- `ohos` 模块管理工具
- Java 版本：与 `client`/`server` 模块对应的 JDK 版本

## 2. 代码仓库结构

- `entry/`：HarmonyOS 客户端应用源代码
- `client/`：Java 客户端代码
- `common/`：共享模块和工具类
- `server/`：Java 服务端代码
- `docs/`：文档目录

## 3. 依赖管理

### 3.1 HarmonyOS 依赖

- `oh-package.json5`：项目包配置
- `build-profile.json5`：编译配置
- `hvigorfile.ts`：构建任务定义

### 3.2 Java 依赖

- `pom.xml`：Maven 依赖管理
- `common/pom.xml`、`client/pom.xml`、`server/pom.xml`

## 4. 构建命令

### 4.1 HarmonyOS 客户端

```powershell
cd HarmonOS_remote_desktop_control_client
 .\build_with_env.bat assembleHap
```

### 4.2 Java 模块

```powershell
cd common
..\apache-maven-3.9.14\bin\mvn clean install

cd ..\client
..\apache-maven-3.9.14\bin\mvn clean package

cd ..\server
..\apache-maven-3.9.14\bin\mvn clean package
```

## 5. 本地运行与调试

### 5.1 HarmonyOS 模拟器

- 启动 HarmonyOS 模拟器
- 在 DevEco Studio 中打开 `entry/` 项目
- 运行或调试应用

### 5.2 Java 服务端

- 启动 `server` 模块生成的服务
- 确保服务端监听 `0.0.0.0` 或可访问地址
- 检查 `test_connection.js` 中的 HTTP/TCP 地址是否匹配

## 6. 环境检查

- `adb devices` / 模拟器连接
- 端口 `12345`（HTTP）和 `54321`（TCP）是否可用
- 防火墙是否允许访问对应端口

## 7. 提交规范

- 提交时请说明变更范围、涉及模块和影响面
- 文档更新与代码变更应一并提交
