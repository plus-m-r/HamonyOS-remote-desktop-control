# 公共模块 (common) - API详细文档

## 1. 模块概述

**职责**：提供跨端共享的数据结构、协议定义、工具类和接口规范

**位置**：`common/src/main/java/io/github/springstudent/dekstop/common`

**依赖关系**：
- 被 `server`、`client`、`HarmonOS_remote_desktop_control_client` 依赖
- 无外部依赖（纯Java标准库）

---

## 2. 子模块结构

```
common/
├── bean/           # 数据模型
├── command/        # 命令对象
├── configuration/  # 配置管理
├── protocol/       # 协议编解码
├── remote/         # 远程控制接口
├── utils/          # 工具类
└── log/            # 日志框架
```

---

## 3. bean 子模块 - 数据模型

### 3.1 Capture.java

**包路径**：`io.github.springstudent.dekstop.common.bean`

**职责**：封装屏幕捕获数据

**核心字段**：
```java
private int id;              // 捕获ID
private boolean reset;       // 是否重置
private int width;           // 屏幕宽度
private int height;          // 屏幕高度
private int tileWidth;       // Tile宽度
private int tileHeight;      // Tile高度
private byte[] data;         // 压缩后的图像数据
```

**关键API**：
- `getId()` / `setId(int id)` - 获取/设置捕获ID
- `getWidth()` / `getHeight()` - 获取屏幕尺寸
- `getTileWidth()` / `getTileHeight()` - 获取Tile尺寸
- `getData()` / `setData(byte[] data)` - 获取/设置图像数据
- `isReset()` / `setReset(boolean reset)` - 获取/设置重置标志

**使用场景**：
- 被控端采集屏幕后封装为Capture对象
- 通过ResCapture命令发送给控制端

---

### 3.2 CaptureTile.java

**包路径**：`io.github.springstudent.dekstop.common.bean`

**职责**：表示单个Tile（分块）的数据

**核心字段**：
```java
private int x;               // Tile X坐标
private int y;               // Tile Y坐标
private int width;           // Tile宽度
private int height;          // Tile高度
private long checksum;       // Adler32校验和
private byte[] data;         // Tile数据
```

**关键API**：
- `getX()` / `getY()` - 获取Tile位置
- `getWidth()` / `getHeight()` - 获取Tile尺寸
- `getChecksum()` / `setChecksum(long checksum)` - 获取/设置校验和
- `getData()` / `setData(byte[] data)` - 获取/设置Tile数据

**使用场景**：
- 分块增量传输时，只传输变化的Tile
- 控制端根据checksum判断是否需要更新

---

### 3.3 Position.java

**包路径**：`io.github.springstudent.dekstop.common.bean`

**职责**：表示二维坐标点

**核心字段**：
```java
private int x;
private int y;
```

**关键API**：
- `getX()` / `setX(int x)` - 获取/设置X坐标
- `getY()` / `setY(int y)` - 获取/设置Y坐标
- `equals(Object obj)` - 坐标比较
- `hashCode()` - 哈希码计算

**使用场景**：
- 鼠标位置记录
- Tile网格坐标计算

---

### 3.4 FileInfo.java

**包路径**：`io.github.springstudent.dekstop.common.bean`

**职责**：文件元数据信息

**核心字段**：
```java
private String name;         // 文件名
private long size;           // 文件大小（字节）
private boolean directory;   // 是否为目录
private long lastModified;   // 最后修改时间
private String path;         // 完整路径
```

**关键API**：
- `getName()` / `setName(String name)` - 获取/设置文件名
- `getSize()` / `setSize(long size)` - 获取/设置文件大小
- `isDirectory()` / `setDirectory(boolean directory)` - 获取/设置目录标志
- `getLastModified()` / `setLastModified(long lastModified)` - 获取/设置修改时间
- `getPath()` / `setPath(String path)` - 获取/设置路径

**使用场景**：
- 文件列表传输
- 文件属性展示

---

### 3.5 Gray8Bits.java

**包路径**：`io.github.springstudent.dekstop.common.bean`

**职责**：8位灰度图像处理

**核心字段**：
```java
private byte[] pixels;       // 像素数据
private int width;
private int height;
```

**关键API**：
- `getPixels()` / `setPixels(byte[] pixels)` - 获取/设置像素数据
- `getWidth()` / `getHeight()` - 获取图像尺寸
- `toBufferedImage()` - 转换为Java BufferedImage

**使用场景**：
- 单色检测优化
- 图像预处理

---

### 3.6 MemByteBuffer.java

**包路径**：`io.github.springstudent.dekstop.common.bean`

**职责**：内存缓冲区管理（零拷贝优化）

**核心字段**：
```java
private byte[] buffer;       // 底层字节数组
private int position;        // 当前位置
private int limit;           // 限制位置
private int capacity;        // 容量
```

**关键API**：
- `put(byte b)` - 写入单个字节
- `put(byte[] src)` - 写入字节数组
- `get()` - 读取单个字节
- `get(byte[] dst)` - 读取到字节数组
- `flip()` - 翻转缓冲区（写→读）
- `clear()` - 清空缓冲区
- `remaining()` - 剩余可读字节数

**使用场景**：
- 协议编码/解码时的临时缓冲
- 减少内存分配开销

---

### 3.7 RemoteClipboard.java

**包路径**：`io.github.springstudent.dekstop.common.bean`

**职责**：远程剪贴板数据

**核心字段**：
```java
private String text;         // 文本内容
private byte[] image;        // 图片数据
private List<String> files;  // 文件列表
```

**关键API**：
- `getText()` / `setText(String text)` - 获取/设置文本
- `getImage()` / `setImage(byte[] image)` - 获取/设置图片
- `getFiles()` / `setFiles(List<String> files)` - 获取/设置文件列表
- `hasText()` / `hasImage()` / `hasFiles()` - 类型判断

**使用场景**：
- 跨设备剪贴板同步
- 支持文本、图片、文件三种类型

---

### 3.8 Listener.java

**包路径**：`io.github.springstudent.dekstop.common.bean`

**职责**：事件监听器接口

**关键方法**：
```java
void onEvent(Object event);
```

**使用场景**：
- 观察者模式实现
- 异步事件通知

---

### 3.9 AtomicPositiveInteger.java

**包路径**：`io.github.springstudent.dekstop.common.bean`

**职责**：原子递增正整数计数器

**核心字段**：
```java
private AtomicInteger counter;
```

**关键API**：
- `incrementAndGet()` - 原子递增并返回
- `get()` - 获取当前值
- `reset()` - 重置为0

**使用场景**：
- 生成唯一ID
- 序列号管理

---

## 4. command 子模块 - 命令对象

### 4.1 CmdType.java

**包路径**：`io.github.springstudent.dekstop.common.command`

**职责**：定义26种命令类型枚举

**枚举值**：
```java
// 心跳类
ReqPing, ResPong

// 会话类
ReqOpen, ResOpen

// 屏幕类
ReqCapture, ResCapture, Capture

// 控制类
KeyControl, MouseControl

// 剪贴板类
ReqRemoteClipboard, ResRemoteClipboard, ClipboardText, ClipboardTransfer

// 文件类
ReqFileList, ResFileList

// 配置类
CompressorConfig, CaptureConfig

// 信息类
ReqCliInfo, ResCliInfo

// 其他
SelectScreen, ChangePwd, ReqUserHome, ResUserHome
```

**使用场景**：
- 协议帧头中的CmdType字段
- 路由分发依据

---

### 4.2 Cmd.java (抽象基类)

**包路径**：`io.github.springstudent.dekstop.common.command`

**职责**：所有命令的基类

**核心字段**：
```java
protected CmdType cmdType;   // 命令类型
protected int version;       // 协议版本
```

**关键API**：
- `getCmdType()` - 获取命令类型
- `getVersion()` / `setVersion(int version)` - 获取/设置版本
- `encode()` - 编码为字节数组（抽象方法）
- `decode(byte[] data)` - 从字节数组解码（抽象方法）

**子类**：
- CmdReqPing, CmdResPong
- CmdReqOpen, CmdResOpen
- CmdReqCapture, CmdResCapture
- CmdKeyControl, CmdMouseControl
- 等等...

---

### 4.3 CmdKeyControl.java

**包路径**：`io.github.springstudent.dekstop.common.command`

**职责**：键盘控制命令

**核心字段**：
```java
private int keyCode;         // 键码
private boolean pressed;     // 按下/释放
private boolean shift;       // Shift键状态
private boolean control;     // Ctrl键状态
private boolean alt;         // Alt键状态
```

**关键API**：
- `getKeyCode()` / `setKeyCode(int keyCode)` - 获取/设置键码
- `isPressed()` / `setPressed(boolean pressed)` - 获取/设置按键状态
- `isShift()` / `setShift(boolean shift)` - 获取/设置Shift状态
- `isControl()` / `setControl(boolean control)` - 获取/设置Ctrl状态
- `isAlt()` / `setAlt(boolean alt)` - 获取/设置Alt状态

**编码格式**：
```
[cmdType:2][keyCode:4][pressed:1][shift:1][control:1][alt:1]
```

**使用场景**：
- 控制端发送键盘事件
- 被控端执行按键操作

---

### 4.4 CmdMouseControl.java

**包路径**：`io.github.springstudent.dekstop.common.command`

**职责**：鼠标控制命令

**核心字段**：
```java
private int x;               // X坐标
private int y;               // Y坐标
private int button;          // 按钮（左/中/右）
private int type;            // 类型（移动/按下/释放/滚轮）
private int wheelRotation;   // 滚轮旋转量
```

**关键API**：
- `getX()` / `setX(int x)` - 获取/设置X坐标
- `getY()` / `setY(int y)` - 获取/设置Y坐标
- `getButton()` / `setButton(int button)` - 获取/设置按钮
- `getType()` / `setType(int type)` - 获取/设置类型
- `getWheelRotation()` / `setWheelRotation(int rotation)` - 获取/设置滚轮

**按钮映射**：
- 1 = 左键
- 2 = 中键
- 3 = 右键

**类型映射**：
- 0 = 移动
- 1 = 按下
- 2 = 释放
- 3 = 滚轮

**使用场景**：
- 控制端发送鼠标事件
- 被控端执行鼠标操作

---

### 4.5 CmdResCapture.java

**包路径**：`io.github.springstudent.dekstop.common.command`

**职责**：屏幕捕获响应命令

**核心字段**：
```java
private Capture capture;     // 捕获数据
```

**关键API**：
- `getCapture()` / `setCapture(Capture capture)` - 获取/设置捕获数据

**编码格式**：
```
[cmdType:2][captureLength:4][captureData:N]
```

**使用场景**：
- 被控端发送屏幕数据
- 控制端接收并渲染

---

### 4.6 CmdClipboardText.java

**包路径**：`io.github.springstudent.dekstop.common.command`

**职责**：剪贴板文本命令

**核心字段**：
```java
private String text;         // 文本内容
```

**关键API**：
- `getText()` / `setText(String text)` - 获取/设置文本

**编码格式**：
```
[cmdType:2][textLength:4][textUTF8:N]
```

**使用场景**：
- 跨设备文本复制粘贴

---

### 4.7 CmdReqFileList.java

**包路径**：`io.github.springstudent.dekstop.common.command`

**职责**：请求文件列表命令

**核心字段**：
```java
private String path;         // 目录路径
```

**关键API**：
- `getPath()` / `setPath(String path)` - 获取/设置路径

**使用场景**：
- 浏览远程文件系统

---

### 4.8 CmdResFileList.java

**包路径**：`io.github.springstudent.dekstop.common.command`

**职责**：响应文件列表命令

**核心字段**：
```java
private List<FileInfo> files; // 文件列表
```

**关键API**：
- `getFiles()` / `setFiles(List<FileInfo> files)` - 获取/设置文件列表

**编码格式**：
```
[cmdType:2][fileCount:4][file1:N1][file2:N2]...
```

**使用场景**：
- 返回目录下的文件信息

---

## 5. protocol 子模块 - 协议编解码

### 5.1 NettyEncoder.java

**包路径**：`io.github.springstudent.dekstop.common.protocol`

**职责**：Netty编码器（对象 → 字节流）

**继承**：`MessageToByteEncoder<Cmd>`

**关键方法**：
```java
@Override
protected void encode(ChannelHandlerContext ctx, Cmd msg, ByteBuf out) {
    // 1. 写入Magic Number (4 bytes)
    out.writeInt(MAGIC_NUMBER);
    
    // 2. 写入版本号 (1 byte)
    out.writeByte(msg.getVersion());
    
    // 3. 写入命令类型 (2 bytes)
    out.writeShort(msg.getCmdType().ordinal());
    
    // 4. 编码命令数据
    byte[] data = msg.encode();
    
    // 5. 写入数据长度 (4 bytes)
    out.writeInt(data.length);
    
    // 6. 写入数据体
    out.writeBytes(data);
}
```

**帧格式**：
```
┌──────────┬──────────┬──────────┬──────────────┬──────────────┐
│ Magic    │ Version  │ CmdType  │ Data Length  │ Data Payload │
│ 4 bytes  │ 1 byte   │ 2 bytes  │ 4 bytes      │ N bytes      │
└──────────┴──────────┴──────────┴──────────────┴──────────────┘
```

**使用场景**：
- 服务端发送命令到客户端
- 客户端发送命令到服务端

---

### 5.2 NettyDecoder.java

**包路径**：`io.github.springstudent.dekstop.common.protocol`

**职责**：Netty解码器（字节流 → 对象）

**继承**：`ByteToMessageDecoder`

**关键方法**：
```java
@Override
protected void decode(ChannelHandlerContext ctx, ByteBuf in, List<Object> out) {
    // 1. 检查是否有足够数据读取帧头（11 bytes）
    if (in.readableBytes() < 11) {
        return;
    }
    
    // 2. 标记读位置
    in.markReaderIndex();
    
    // 3. 读取Magic Number
    int magic = in.readInt();
    if (magic != MAGIC_NUMBER) {
        throw new IllegalArgumentException("Invalid magic number");
    }
    
    // 4. 读取版本号
    byte version = in.readByte();
    
    // 5. 读取命令类型
    short cmdTypeOrdinal = in.readShort();
    CmdType cmdType = CmdType.values()[cmdTypeOrdinal];
    
    // 6. 读取数据长度
    int dataLength = in.readInt();
    
    // 7. 检查是否有足够数据读取数据体
    if (in.readableBytes() < dataLength) {
        in.resetReaderIndex();
        return;
    }
    
    // 8. 读取数据体
    byte[] data = new byte[dataLength];
    in.readBytes(data);
    
    // 9. 解码命令对象
    Cmd cmd = CmdUtils.decode(cmdType, data);
    cmd.setVersion(version);
    
    // 10. 添加到输出列表
    out.add(cmd);
}
```

**粘包处理**：
- 通过dataLength字段精确读取数据体
- 不足时等待更多数据
- 多余数据留在缓冲区供下次解码

**使用场景**：
- 服务端接收客户端命令
- 客户端接收服务端命令

---

## 6. configuration 子模块 - 配置管理

### 6.1 Configuration.java (接口)

**包路径**：`io.github.springstudent.dekstop.common.configuration`

**职责**：配置接口定义

**关键方法**：
```java
void load(Properties props);   // 加载配置
void save(Properties props);   // 保存配置
```

---

### 6.2 CaptureEngineConfiguration.java

**包路径**：`io.github.springstudent.dekstop.common.configuration`

**职责**：捕获引擎配置

**核心字段**：
```java
private int tileSize = 64;     // Tile尺寸
private int fps = 30;          // 帧率
private int maxRetries = 3;    // 最大重试次数
```

**关键API**：
- `getTileSize()` / `setTileSize(int tileSize)` - 获取/设置Tile尺寸
- `getFps()` / `setFps(int fps)` - 获取/设置帧率
- `getMaxRetries()` / `setMaxRetries(int retries)` - 获取/设置重试次数

**配置项**：
```properties
capture.tile-size=64
capture.fps=30
capture.max-retries=3
```

---

### 6.3 CompressorEngineConfiguration.java

**包路径**：`io.github.springstudent.dekstop.common.configuration`

**职责**：压缩引擎配置

**核心字段**：
```java
private int compressionLevel = 3;  // 压缩级别（1-9）
private boolean useRLE = true;     // 是否启用RLE
private boolean useZSTD = true;    // 是否启用ZSTD
```

**关键API**：
- `getCompressionLevel()` / `setCompressionLevel(int level)` - 获取/设置压缩级别
- `isUseRLE()` / `setUseRLE(boolean use)` - 获取/设置RLE开关
- `isUseZSTD()` / `setUseZSTD(boolean use)` - 获取/设置ZSTD开关

**配置项**：
```properties
compression.level=3
compression.rle=true
compression.zstd=true
```

---

## 7. utils 子模块 - 工具类

### 7.1 EmptyUtils.java

**包路径**：`io.github.springstudent.dekstop.common.utils`

**职责**：空值检查工具

**关键API**：
```java
public static boolean isEmpty(String str)
public static boolean isEmpty(Collection<?> collection)
public static boolean isEmpty(Map<?, ?> map)
public static boolean isEmpty(Object[] array)
public static boolean isNotEmpty(String str)
```

**使用场景**：
- 参数校验
- 防御性编程

---

### 7.2 FileUtilities.java

**包路径**：`io.github.springstudent.dekstop.common.utils`

**职责**：文件操作工具

**关键API**：
```java
public static byte[] readFile(String path)
public static void writeFile(String path, byte[] data)
public static List<FileInfo> listFiles(String directory)
public static String getFileExtension(String fileName)
public static long getFileSize(String path)
```

**使用场景**：
- 文件读写
- 目录遍历

---

### 7.3 NettyUtils.java

**包路径**：`io.github.springstudent.dekstop.common.utils`

**职责**：Netty工具类

**关键API**：
```java
public static ChannelFuture sendCommand(Channel channel, Cmd cmd)
public static boolean isConnected(Channel channel)
public static void closeChannel(Channel channel)
public static InetSocketAddress getRemoteAddress(Channel channel)
```

**使用场景**：
- 简化Netty操作
- 连接状态检查

---

### 7.4 RemoteUtils.java

**包路径**：`io.github.springstudent.dekstop.common.utils`

**职责**：远程控制工具类

**关键API**：
```java
public static Point convertTouchToMouse(float touchX, float touchY, 
                                         int screenWidth, int screenHeight)
public static int calculateChecksum(byte[] data)
public static byte[] compress(byte[] data, CompressionMethod method)
public static byte[] decompress(byte[] data, CompressionMethod method)
```

**使用场景**：
- 触控坐标转换
- 校验和计算
- 数据压缩/解压

---

### 7.5 UnitUtilities.java

**包路径**：`io.github.springstudent.dekstop.common.utils`

**职责**：单位转换工具

**关键API**：
```java
public static long bytesToKB(long bytes)
public static long bytesToMB(long bytes)
public static double formatSpeed(long bytes, long durationMs)
```

**使用场景**：
- 带宽计算
- 文件大小格式化

---

## 8. remote 子模块 - 远程控制接口

### 8.1 RemoteScreenListener.java (接口)

**包路径**：`io.github.springstudent.dekstop.common.remote`

**职责**：屏幕数据监听器

**关键方法**：
```java
void onScreenData(Capture capture);
void onError(Throwable error);
```

**使用场景**：
- 控制端接收屏幕数据回调

---

### 8.2 RemoteScreenRobot.java (接口)

**包路径**：`io.github.springstudent.dekstop.common.remote`

**职责**：屏幕机器人接口（键鼠模拟）

**关键方法**：
```java
void mouseMove(int x, int y);
void mousePress(int button);
void mouseRelease(int button);
void mouseWheel(int rotation);
void keyPress(int keyCode);
void keyRelease(int keyCode);
Rectangle getScreenBounds();
BufferedImage captureScreen(Rectangle bounds);
```

**实现类**：
- `WinDesktop` (Windows平台，JNI实现)
- `LinuxDesktop` (Linux平台)
- `MacDesktop` (macOS平台)

**使用场景**：
- 被控端执行远程控制指令

---

### 8.3 RemoteClpboardListener.java (接口)

**包路径**：`io.github.springstudent.dekstop.common.remote`

**职责**：剪贴板监听器

**关键方法**：
```java
void onClipboardChanged(RemoteClipboard clipboard);
```

**使用场景**：
- 监听剪贴板变化
- 跨设备同步

---

## 9. log 子模块 - 日志框架

### 9.1 Log.java (接口)

**包路径**：`io.github.springstudent.dekstop.common.log`

**职责**：日志接口

**关键方法**：
```java
void debug(String message);
void info(String message);
void warn(String message);
void error(String message);
void error(String message, Throwable throwable);
```

**实现类**：
- `ConsoleLogAppender` - 控制台输出
- `FileLogAppender` - 文件输出

---

### 9.2 LogLevel.java

**包路径**：`io.github.springstudent.dekstop.common.log`

**职责**：日志级别枚举

**枚举值**：
```java
DEBUG, INFO, WARN, ERROR
```

---

## 10. 使用示例

### 10.1 发送键盘事件

```java
// 创建键盘控制命令
CmdKeyControl cmd = new CmdKeyControl();
cmd.setKeyCode(KeyEvent.VK_A);
cmd.setPressed(true);
cmd.setShift(false);
cmd.setControl(false);
cmd.setAlt(false);

// 编码并发送
byte[] data = cmd.encode();
channel.writeAndFlush(Unpooled.wrappedBuffer(data));
```

### 10.2 接收屏幕数据

```java
// 注册监听器
RemoteScreenListener listener = new RemoteScreenListener() {
    @Override
    public void onScreenData(Capture capture) {
        System.out.println("收到屏幕数据: " + capture.getWidth() + "x" + capture.getHeight());
        // 渲染图像...
    }
    
    @Override
    public void onError(Throwable error) {
        error.printStackTrace();
    }
};

// 在协议处理器中调用
listener.onScreenData(capture);
```

### 10.3 配置文件加载

```java
Properties props = new Properties();
props.load(new FileInputStream("config.properties"));

CaptureEngineConfiguration config = new CaptureEngineConfiguration();
config.load(props);

System.out.println("Tile Size: " + config.getTileSize());
System.out.println("FPS: " + config.getFps());
```

---

## 11. 扩展指南

### 11.1 新增命令类型

1. 在 `CmdType.java` 中添加枚举值
2. 创建新的Cmd子类（如 `CmdNewFeature.java`）
3. 实现 `encode()` 和 `decode()` 方法
4. 在 `CmdUtils.java` 中注册解码器

### 11.2 新增压缩算法

1. 实现 `Compressor` 接口
2. 在 `CompressionMethod.java` 中添加枚举值
3. 在 `CompressorFactory.java` 中注册

### 11.3 新增平台支持

1. 实现 `RemoteScreenRobot` 接口
2. 根据平台特性实现键鼠模拟
3. 在工厂类中注册新平台

---

**文档版本**：v1.0  
**最后更新**：2026-05-10  
**维护团队**：方寸控技术团队
