# 统一压缩器接口设计

## 📋 概述

本目录包含方寸控远程桌面系统的统一压缩器接口定义，适用于Java和HarmonyOS双端。

**设计目标**：
- ✅ 只支持异步操作，避免阻塞调用线程
- ✅ 只支持流式处理，适合大数据传输场景
- ✅ 跨平台API一致性，简化多端开发
- ✅ 完善的错误处理和资源管理

---

## 📂 文件结构

### Java端（common模块）

```
common/src/main/java/io/github/springstudent/dekstop/common/compress/
├── ICompressor.java              # 核心接口定义
├── CompressionMethod.java        # 压缩方法枚举
├── CompressorConfig.java         # 配置类（Builder模式）
└── CompressionException.java     # 异常类
```

### HarmonyOS端

```
entry/src/main/ets/common/compress/
├── ICompressor.ets               # 核心接口定义
├── CompressionMethod.ets         # 压缩方法枚举
├── CompressorConfig.ets          # 配置接口和工厂函数
├── CompressionError.ets          # 异常类
└── index.ets                     # 统一导出
```

---

## 🎯 核心接口

### ICompressor接口

**Java版本**：
```java
public interface ICompressor {
    // 异步流式压缩
    CompletableFuture<Void> compress(InputStream input, OutputStream output);
    
    // 异步流式解压
    CompletableFuture<Void> decompress(InputStream input, OutputStream output);
    
    // 获取压缩方法
    CompressionMethod getMethod();
    
    // 获取/更新配置
    CompressorConfig getConfig();
    void updateConfig(CompressorConfig config);
    
    // 关闭资源
    void close();
}
```

**HarmonyOS版本**：
```typescript
export interface ICompressor {
  // 异步流式压缩
  compress(
    inputStream: ArrayBuffer | Uint8Array,
    outputStream: (data: Uint8Array) => void
  ): Promise<void>;
  
  // 异步流式解压
  decompress(
    inputStream: ArrayBuffer | Uint8Array,
    outputStream: (data: Uint8Array) => void
  ): Promise<void>;
  
  // 获取压缩方法
  getMethod(): CompressionMethod;
  
  // 获取/更新配置
  getConfig(): CompressorConfig;
  updateConfig(config: CompressorConfig): Promise<void>;
  
  // 关闭资源
  close(): void;
}
```

---

## 💡 使用示例

### Java端使用

```java
// 1. 创建配置
CompressorConfig config = CompressorConfig.builder(CompressionMethod.ZSTD)
    .compressionLevel(3)
    .bufferSize(64 * 1024)
    .build();

// 2. 创建压缩器（待实现）
ICompressor compressor = CompressorFactory.createCompressor(config);

// 3. 异步压缩
try (InputStream input = new FileInputStream("input.bin");
     OutputStream output = new FileOutputStream("output.zst")) {
    
    CompletableFuture<Void> future = compressor.compress(input, output);
    
    // 异步等待完成
    future.thenRun(() -> System.out.println("压缩完成"))
          .exceptionally(ex -> {
              System.err.println("压缩失败: " + ex.getMessage());
              return null;
          });
}

// 4. 使用后关闭
compressor.close();
```

### HarmonyOS端使用

```typescript
import { 
  ICompressor, 
  CompressionMethod, 
  createCompressorConfig,
  CompressionError 
} from '../common/compress';

// 1. 创建配置
const config = createCompressorConfig({
  method: CompressionMethod.ZSTD,
  compressionLevel: 3,
  bufferSize: 64 * 1024
});

// 2. 创建压缩器（待实现）
const compressor: ICompressor = await createCompressor(config);

// 3. 异步压缩
try {
  const inputData = await readFile('input.bin');
  
  const chunks: Uint8Array[] = [];
  await compressor.compress(inputData, (chunk) => {
    chunks.push(chunk);
  });
  
  // 合并输出
  const outputData = mergeChunks(chunks);
  await writeFile('output.zst', outputData);
  
  console.log('压缩完成');
} catch (error) {
  if (error instanceof CompressionError) {
    console.error('压缩失败:', error.getDetailedMessage());
  }
}

// 4. 使用后关闭
compressor.close();
```

---

## 🔧 支持的压缩方法

| 方法 | 代码 | 特点 | 适用场景 |
|------|------|------|---------|
| NONE | 0 | 无压缩 | 测试、极低延迟 |
| ZSTD | 1 | 高压缩率、高性能 | **推荐，通用场景** |
| LZ4 | 2 | 极速压缩/解压 | 低延迟要求 |
| SNAPPY | 3 | 快速、Google开发 | 中等性能需求 |

---

## ⚙️ 配置说明

### 压缩级别（compressionLevel）

- **范围**：1-9
- **默认**：3（中等）
- **说明**：级别越高，压缩率越好，但速度越慢

### 缓冲区大小（bufferSize）

- **最小值**：1KB (1024字节)
- **默认**：64KB (65536字节)
- **说明**：影响内存使用和性能，建议根据数据大小调整

### 字典压缩（useDictionary）

- **默认**：false
- **说明**：适合重复数据的场景，需要预先训练字典

---

## ❌ 错误处理

### Java端

```java
try {
    compressor.compress(input, output).join();
} catch (CompletionException e) {
    if (e.getCause() instanceof CompressionException) {
        CompressionException ce = (CompressionException) e.getCause();
        System.err.println("错误代码: " + ce.getErrorCode());
        System.err.println("压缩率: " + ce.getCompressionRatio());
    }
}
```

### HarmonyOS端

```typescript
try {
  await compressor.compress(inputData, outputCallback);
} catch (error) {
  if (error instanceof CompressionError) {
    console.error('错误代码:', error.errorCode);
    console.error('详细信息:', error.getDetailedMessage());
  }
}
```

---

## 📊 设计对比

| 特性 | 旧设计 | 新设计 |
|------|--------|--------|
| 同步/异步 | 混合 | **纯异步** |
| 块式/流式 | 混合 | **纯流式** |
| 跨平台一致性 | ❌ 不一致 | ✅ 完全一致 |
| HarmonyOS磁盘IO | ❌ 4次/帧 | ✅ 0次 |
| 错误处理 | ❌ 不统一 | ✅ 统一异常 |
| 资源配置 | ❌ 硬编码 | ✅ 可配置 |

---

## 🚀 下一步

### ✅ 已完成

1. **接口定义** - ICompressor及相关类型
2. **工厂类** - CompressorFactory
3. **ZSTD压缩器** - ZstdCompressor（基于zstd-jni）✅
4. **LZ4压缩器** - Lz4Compressor（基于lz4-java）✅
5. **Snappy压缩器** - SnappyCompressor（基于snappy-java）✅
6. **无压缩器** - NoneCompressor（用于测试）✅

### 🔧 待集成

1. **集成到client端**：
   - 替换DeCompressorEngine
   - 替换CompressorEngine
   - 回归测试

2. **HarmonyOS端实现**（等待库开发）：
   - 等待@ohos/zstd或Native绑定完成
   - 实现HarmonyOS版本的压缩器
   - 集成到RemoteControlService

---

**文档版本**：v1.0  
**最后更新**：2026-05-10  
**维护团队**：方寸控技术团队
