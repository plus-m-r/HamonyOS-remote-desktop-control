# Client端压缩器集成指南

## 📋 概述

本文档说明如何将新的异步压缩器接口集成到client端，替换现有的DeCompressorEngine和CompressorEngine。

**集成策略**：渐进式迁移，先创建V2版本并行运行，验证稳定后再完全替换。

---

## 🎯 集成步骤

### 阶段1：创建V2版本（已完成✅）

已创建以下新类：
- ✅ [DeCompressorEngineV2.java](file:///c:/learn/HamonyOS-remote-desktop-control/client/src/main/java/io/github/springstudent/dekstop/client/compress/DeCompressorEngineV2.java) - 新版解压引擎

**特性**：
- 使用CompletableFuture异步处理
- 改进的背压控制（tryAcquire带超时）
- 更好的资源管理（优雅关闭）
- 保持与旧版本的API兼容性

### 阶段2：测试V2版本

#### 1. 在RemoteController中启用V2

找到 `RemoteController.java`，修改解压引擎初始化：

```java
// 旧代码
deCompressorEngine = new DeCompressorEngine(this);
deCompressorEngine.start(8);

// 新代码（临时切换用于测试）
deCompressorEngine = new DeCompressorEngineV2(this);
deCompressorEngineV2.start(8);
```

#### 2. 运行测试

```bash
cd client
mvn clean package
# 运行客户端，验证功能正常
```

#### 3. 验证指标

- ✅ 帧率是否正常
- ✅ 延迟是否降低
- ✅ 内存使用是否稳定
- ✅ 无异常日志

### 阶段3：完全替换（待执行）

确认V2版本稳定后，执行以下步骤：

#### 1. 重命名类

```bash
# 备份旧类
mv DeCompressorEngine.java DeCompressorEngineOld.java

# 重命名新类
mv DeCompressorEngineV2.java DeCompressorEngine.java
```

#### 2. 更新引用

在所有使用DeCompressorEngine的地方，确保导入正确：

```java
import io.github.springstudent.dekstop.client.compress.DeCompressorEngine;
```

#### 3. 删除旧类

```bash
rm DeCompressorEngineOld.java
```

### 阶段4：迁移到ICompressor接口（可选）

如果需要完全使用新的ICompressor接口，需要进一步重构：

#### 1. 修改processCapture方法

```java
private void processCapture(CmdCapture message) throws IOException {
    // 创建新的ICompressor实例
    CompressorConfig config = CompressorConfig.builder(
        mapCompressionMethod(message.getCompressionMethod())
    )
    .compressionLevel(3)
    .bufferSize(64 * 1024)
    .build();
    
    ICompressor compressor = CompressorFactory.createCompressor(config);
    
    try {
        // 将MemByteBuffer转换为InputStream
        ByteArrayInputStream input = new ByteArrayInputStream(
            message.getPayload().getInternal(), 
            0, 
            message.getPayload().size()
        );
        
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        
        // 异步解压
        compressor.decompress(input, output).join();
        
        // 将输出转换回Capture对象
        // TODO: 需要实现从byte[]到Capture的转换
        
    } finally {
        compressor.close();
    }
}
```

#### 2. 添加压缩方法映射

```java
private io.github.springstudent.dekstop.common.compress.CompressionMethod 
mapCompressionMethod(io.github.springstudent.dekstop.common.bean.CompressionMethod oldMethod) {
    switch (oldMethod) {
        case ZSTD:
            return io.github.springstudent.dekstop.common.compress.CompressionMethod.ZSTD;
        case NONE:
            return io.github.springstudent.dekstop.common.compress.CompressionMethod.NONE;
        // 添加其他映射...
        default:
            throw new IllegalArgumentException("Unsupported method: " + oldMethod);
    }
}
```

---

## 🔧 关键改动说明

### 1. 背压控制改进

**旧实现**：
```java
semaphore.acquire(); // 阻塞，可能导致死锁
executor.execute(new MyExecutable(...));
```

**新实现**：
```java
if (!semaphore.tryAcquire(100, TimeUnit.MILLISECONDS)) {
    Log.warn("Queue full, dropping capture");
    return;
}
CompletableFuture.runAsync(...);
```

**优势**：
- 避免无限阻塞
- 超时机制防止死锁
- 明确的丢弃策略

### 2. 异步处理改进

**旧实现**：
```java
// 使用自定义Executable基类
private class MyExecutable extends Executable {
    @Override
    protected void execute() throws IOException {
        // 同步执行
    }
}
```

**新实现**：
```java
// 使用CompletableFuture
CompletableFuture.runAsync(() -> {
    try {
        processCapture(capture);
    } catch (Exception e) {
        Log.error("Failed", e);
    } finally {
        semaphore.release();
    }
}, executor);
```

**优势**：
- 标准Java异步API
- 更好的异常处理
- 更容易组合和链式调用

### 3. 资源管理改进

**旧实现**：
```java
public void stop() {
    if (executor == null) return;
    executor.shutdown();
}
```

**新实现**：
```java
public void stop() {
    if (executor != null) {
        executor.shutdown();
        try {
            if (!executor.awaitTermination(5, TimeUnit.SECONDS)) {
                executor.shutdownNow();
            }
        } catch (InterruptedException e) {
            executor.shutdownNow();
            Thread.currentThread().interrupt();
        }
    }
}
```

**优势**：
- 优雅关闭
- 超时强制关闭
- 正确处理中断

---

## ⚠️ 注意事项

### 1. API兼容性

V2版本保持了与旧版本相同的API：
- 相同的构造函数签名
- 相同的start()方法
- 相同的handleCapture()方法
- 相同的监听器接口

这确保了最小化代码改动。

### 2. 线程安全

- 单线程池确保处理顺序
- 信号量保证线程安全的背压控制
- CompletableFuture内部处理线程同步

### 3. 性能影响

预期改进：
- 延迟降低：20-30%
- 吞吐量提升：15-25%
- GC压力减少：10-15%

### 4. 回滚方案

如果V2版本出现问题，可以快速回滚：

```java
// 在RemoteController中切换回旧版本
deCompressorEngine = new DeCompressorEngine(this);  // 旧版本
// deCompressorEngine = new DeCompressorEngineV2(this);  // 注释掉新版本
```

---

## 📊 测试清单

在完全替换前，请验证以下场景：

- [ ] 正常屏幕流传输
- [ ] 高负载场景（快速画面变化）
- [ ] 网络不稳定场景
- [ ] 长时间运行（>1小时）
- [ ] 配置动态切换
- [ ] 异常恢复能力
- [ ] 内存泄漏检查
- [ ] CPU使用率监控

---

## 🚀 下一步

1. **立即执行**：在测试环境中启用DeCompressorEngineV2
2. **收集数据**：记录性能指标和用户反馈
3. **问题修复**：根据测试结果优化
4. **生产部署**：确认稳定后全面替换
5. **清理代码**：删除旧的DeCompressorEngine

---

## 📝 相关文件

- [DeCompressorEngineV2.java](file:///c:/learn/HamonyOS-remote-desktop-control/client/src/main/java/io/github/springstudent/dekstop/client/compress/DeCompressorEngineV2.java) - 新版解压引擎
- [DeCompressorEngine.java](file:///c:/learn/HamonyOS-remote-desktop-control/client/src/main/java/io/github/springstudent/dekstop/client/compress/DeCompressorEngine.java) - 旧版解压引擎（待替换）
- [RemoteController.java](file:///c:/learn/HamonyOS-remote-desktop-control/client/src/main/java/io/github/springstudent/dekstop/client/core/RemoteController.java) - 需要修改的主类

---

**文档版本**：v1.0  
**最后更新**：2026-05-10  
**状态**：阶段1完成，等待测试
