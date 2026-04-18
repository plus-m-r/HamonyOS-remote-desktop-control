# 第三章 详细设计

本章详细设计基于客户端实际 ArkTS 源码，内容涵盖用户界面、数据与状态管理、关键技术难点和模块协作关系，并在必要位置标注推荐绘图项。

## 1. 界面设计

HarmonyOS 客户端采用 MVVM 架构，页面只负责渲染与事件转发，业务逻辑由 ViewModel 和服务层承担。页面组件与业务服务之间通过依赖注入解耦，界面层保持轻量。

### 1.1 典型使用流程

1. 启动应用后进入首页（`entry/src/main/ets/pages/Index.ets`），用户在首页输入设备 ID、密码，并可复制设备信息。
2. 首页通过 `IndexViewModel` 调用 `remoteControlService.validateDevice` 验证设备信息，验证成功后调用 `remoteControlService.setDeviceInfo`，并通过路由导航进入控制页面。
3. 控制页面（`entry/src/main/ets/pages/Control.ets`）初始化 `ControlViewModel`，通过 `ServiceProvider` 注入 `remoteControlService`、`fileService`、`clipboardService` 等依赖。
4. `ControlViewModel` 设置连接状态回调和屏幕数据回调，并在设备凭据准备好后调用 `remoteControlService.openRemoteScreen` 发起远程屏幕捕获。
5. 远程屏幕数据在 `TcpClient` 收到后交给 `ProtocolHandler` 解析，再由 `RemoteControlService` 进入 `CaptureProcessor` / `CaptureCache` 处理，最终由 `Control.ets` 的 `Image(PixelMap)` 显示。
6. 用户在远程屏幕页进行触控、拖拽、缩放、键盘输入或三指手势，`ControlViewModel` 将这些事件转为控制命令，并调用远程控制服务发送到服务器。
7. 用户可通过设置页面（`entry/src/main/ets/pages/Settings.ets`）调整网络参数、同步策略、文件传输和剪贴板配置，保存后由 `AppStateManager` 持久化。

> 推荐绘图：典型页面导航与操作流程图，展示 `Index -> Control -> Settings` 的用户路径和核心数据流。

### 1.2 首页/设备连接页面设计

- 页面职责：录入目标设备凭证、展示本机设备信息、发起连接、提供快速复制和错误提示。
- 交互说明：输入设备 ID/密码后，页面调用 `IndexViewModel.connectToDevice()`，该函数完成输入校验、设备验证、凭据注入和路由跳转。
- 可视组件：输入框、连接按钮、状态提示、复制按钮、帮助提示。页面不直接处理连接协议。
- 代码关键点：`Index.ets` 本身只含事件映射函数，比如 `connectToDevice()`、`copyDeviceId()`、`onDeviceIdChange()`，真正业务由 `IndexViewModel` 负责。

### 1.3 远程屏幕页面设计

- 页面职责：实时显示远程桌面、响应触控交互、显示工具栏和连接状态。
- UI 组件：远程画面显示区、工具栏按钮、缩放/拖拽交互区、返回/断开按钮、错误提示区。
- 关键实现：`Control.ets` 通过 `setScreenPixelMapCallback` 接收 `PixelMap` 数据并触发 UI 刷新。远程画面显示与业务逻辑完全隔离，避免渲染阻塞。
- 交互逻辑：手势事件（触摸开始、移动、结束、捏合缩放、三指滑动）由页面捕获并转发至 `ControlViewModel`；ViewModel 负责判断长按、拖拽与控制指令类型。
- 扩展方向：当前已支持画面展示和操作控制，后续可扩展为触控区域切换、键盘浮动面板、远程菜单按钮。

### 1.4 设置/日志页面设计

- 页面职责：提供配置修改入口和运行状态展示入口。
- 配置项：文件传输自动上传、传输进度开关、剪贴板自动同步、同步间隔、仅同步文本、通知开关等。
- 实现方式：`Settings.ets` 读取、更新并保存 `SyncSettings`；保存操作最终写入 `AppStateManager`，将配置与界面状态隔离。
- 日志功能：当前文档中设计为扩展项，页面结构预留日志展示区，实际情况下可在 `Settings.ets` 中增加 `Scroll` 组件来显示连接日志、错误历史与操作记录。
- 设计原则：将页面配置与核心服务配置分离，通过 `ConfigCenter` 管理系统级默认参数，而用户自定义设置通过 `AppStateManager` 持久化。

> 推荐绘图：设置页面与状态管理关系图，说明用户界面、页面状态和持久化存储之间关联。

## 2. 数据设计

本客户端不使用传统关系型数据库，数据设计侧重于配置对象、状态缓存和环境级参数管理。

### 2.1 配置中心设计

- `ConfigCenter` 为全局配置入口，采用单例模式，源码文件位于 `entry/src/main/ets/config/ConfigCenter.ets`。
- 默认配置项涵盖：服务端地址、TCP/HTTP 端口、上下文路径、网络超时、重连策略、心跳间隔、画面压缩参数、文件传输限制、剪贴板策略、UI 默认值、日志策略、Worker 配置。
- 环境覆盖策略：`ConfigCenter` 支持 `development`、`testing`、`staging`、`production`、`emulator` 等环境，通过 `ENVIRONMENT_CONFIGS` 自动应用不同配置值。
- 设计优势：在不改动代码的情况下，可通过环境切换快速调整网络、压缩、日志与模拟器参数，保证开发与上线配置一致性。

### 2.2 状态缓存与持久化设计

- 核心类：`AppStateManager`，实现 `IAppStateManager` 接口，并依赖 `IStateStorage` 抽象存储实现。
- 主要缓存内容：用户凭据、远程设备凭证、连接状态、屏幕数据、画面尺寸、剪贴板文本、剪贴板文件列表。
- 设计目标：将临时会话数据与长期配置分开，避免页面直接访问存储实现，保证状态同步与跨页面共享。
- 监听机制：`AppStateManager` 提供状态变更监听器，页面与服务可订阅状态更新，支持配置变更实时生效。
- 典型用途：`IndexViewModel` 读取用户 ID/password，`Settings.ets` 保存同步设置，`ControlViewModel` 可读取当前连接状态，`ClipboardService` 可读取剪贴板历史。

### 2.3 客户端数据模型与非关系存储说明

- 当前客户端无需复杂关系型数据库，使用键值存储更符合轻量化需求。
- 主要数据以对象结构和键值对形式保存，而非表结构。例如 `ConfigCenter` 以嵌套对象保存配置，`AppStateManager` 以键枚举保存状态。
- 这种设计避免了数据库范式约束及事务开销，适合 HarmonyOS 客户端在本地缓存连接参数与短期运行数据的场景。
- 如果未来需要持久化历史会话、文件传输记录或日志，可考虑引入本地数据库，但当前方案已能满足快速重连和配置恢复需求。

> 推荐绘图：本地配置与状态缓存层次图，说明 `ConfigCenter`、`AppStateManager`、`IStateStorage` 之间的关系。

## 3. 关键技术与难点

关键技术部分是本客户端设计的核心，涉及网络通信、远程画面处理、模块解耦以及可测试性。

### 3.1 远程通信与重连策略

- `TcpClient` 位于 `entry/src/main/ets/network/TcpClient.ets`，负责直接与远程服务端建立、维持和重连 TCP 长连接。
- 它在连接失败或关闭时自动触发重连，默认最多尝试 5 次，重连间隔 5 秒。
- 心跳机制：`TcpClient` 每 3 秒发送一次心跳请求，快速发现链路异常并触发重连逻辑。
- `ConnectionManager` 在 `entry/src/main/ets/services/connection/ConnectionManager.ets` 中进一步封装状态管理、回调注册、错误处理和重连策略。
- 该设计使上层业务（如 `RemoteControlService`）只负责业务命令，不直接处理 socket 细节。

### 3.2 协议解析与数据处理链路

- 网络数据先由 `ConnectionManager` 接收后传给 `ProtocolHandler`，负责解析命令和控制消息。
- `RemoteControlService` 实现了接收队列机制，避免粘包与并发数据处理问题，确保数据按到达顺序逐个解析。
- 命令解析结果分发到不同功能模块，如 `handleCaptureData` 进入画面处理、剪贴板命令进入 `ClipboardService`、文件传输命令进入 `FileService`。
- 远程画面处理包括 `CaptureProcessor` 和 `CaptureCache`，用于合并、缓存和优化帧数据，提高播放稳定性。
- 最终显示路径是：网络数据→协议解析→帧处理→`createPixelMap`→UI 渲染。

### 3.3 远程屏幕渲染与 PixelMap 处理

- UI 页面不直接接收原始字节流，而是接收 `PixelMap` 对象。
- `ControlViewModel` 的 `createPixelMapOnMainThread` 方法确保 `image.createPixelMap` 在主线程上执行，以满足 HarmonyOS 渲染要求并避免线程冲突。
- 该设计解耦了数据解码与渲染，保证当画面帧到达时，UI 能以最小延迟更新显示。
- 远程屏幕显示优化点包括：尺寸适配、缩放限制、拖拽状态提示、工具栏显示控制。

### 3.4 模块解耦与可测试性

- 业务接口：`IRemoteControlService`、`IClipboardService`、`IFileService`、`IConnectionManager` 等接口定义了服务契约。
- 仓库层接口：`ITcpRepository`、`IHttpRepository`、`IWorkerRepository` 在 `entry/src/main/ets/repository/` 下定义，抽象底层实现。
- 依赖注入：通过 `ServiceProvider`、`DependencyContainer` 和工厂类将实现注入到 ViewModel 和服务层，减少硬编码依赖。
- 这使单元测试更容易，例如可用 Mock `ITcpRepository` 模拟网络异常，用 Mock `IHttpRepository` 验证剪贴板同步逻辑。
- 页面层只关心状态更新与事件转发，ViewModel 与服务层承担业务判断、异常处理和数据缓存逻辑。

### 3.5 剪贴板与文件传输子系统

- 剪贴板子系统由 `ClipboardService` 实现，独立于具体 HTTP 库，只依赖 `IHttpRepository`。
- 它支持本地剪贴板文本保存、长度限制、历史记录、远程同步获取、清空操作和错误反馈。
- 文件传输子系统由 `FileService` 和 `HttpRepositoryImpl` 负责，设计上采用 HTTP 接口处理大文件上传下载，避免将文件数据流全部压在 TCP 长连接上。
- 该子系统的主要难点在于大文件分块、进度控制、自动上传策略和用户通知，而当前实现已为这种扩展提供接口场景。
- 由于文件传输通常与业务流程分离，页面层仅需调用 `fileService.upload()` / `download()` 并展示进度。

### 3.6 关键性能与稳定性优化

- 通过 `ConfigCenter` 配置多种运行环境下的压缩策略与 `maxFps`，平衡画面质量与网络带宽。
- 画面接收和命令发送分离为不同通道，避免控制命令因大流量画面数据而阻塞。
- 状态缓存机制使连接状态、画面尺寸、剪贴板内容等信息可快速恢复，提升重连体验。
- 异常处理与日志记录贯穿模块，便于后续扩展日志查看页面和故障诊断工具。

> 推荐绘图：关键技术架构图，包含通信链路、协议解析、帧处理、服务与 UI 之间的调用关系。

## 4. 详细设计结论

本章详细设计强调“界面轻量化、业务层解耦、通信可靠、状态可控”四个原则。

- 界面层采用 MVVM，使页面专注于用户交互和渲染，避免将业务逻辑嵌入 UI。
- 配置中心与状态管理层分别满足系统级参数和会话级状态需求，避免配置与状态混淆。
- 通信层与协议层分离，使远程画面、控制命令、剪贴板和文件传输各司其职。
- 接口与依赖注入设计提高了可测试性和可扩展性，为后续扩展日志、网络参数配置、长连接优化提供基础。

该设计建议在后续评审中补充三张图：页面流程图、配置/状态关系图、关键通信与模块交互图，以便更直观地说明客户端架构。