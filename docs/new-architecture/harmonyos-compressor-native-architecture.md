# HarmonyOS端压缩库技术架构设计

## 📋 概述

本文档定义HarmonyOS端压缩库的技术架构要求，采用**Native C++底层 + ArkTS封装**的分层设计，确保高性能和跨平台一致性。

**设计目标**：
- ✅ 消除磁盘IO，使用纯内存级API
- ✅ 异步非阻塞，不阻塞UI线程
- ✅ 与Java端接口完全一致
- ✅ 高性能：利用Native C++的计算能力
- ✅ 易维护：清晰的层次分离

---

## 🏗️ 架构分层

```
┌─────────────────────────────────────────┐
│         ArkTS 应用层                     │
│  (RemoteControlService, UI组件)          │
└──────────────┬──────────────────────────┘
               │ 调用
┌──────────────▼──────────────────────────┐
│      ArkTS 封装层 (compress/)            │
│  - ICompressor 接口                      │
│  - ZstdCompressor 实现                   │
│  - CompressorFactory 工厂                │
│  - 异步Promise封装                       │
└──────────────┬──────────────────────────┘
               │ NAPI桥接
┌──────────────▼──────────────────────────┐
│     Native C++ 层 (cpp/)                 │
│  - zstd-jni/harmony 绑定                 │
│  - 内存管理 (ArrayBuffer ↔ char*)        │
│  - 错误码转换                            │
└──────────────┬──────────────────────────┘
               │ 直接调用
┌──────────────▼──────────────────────────┐
│     第三方库 (zstd library)              │
│  - libzstd.so (共享库)                   │
│  - C API: ZSTD_compress, ZSTD_decompress │
└─────────────────────────────────────────┘
```

---

## 🔧 技术要求

### 1. 第三方库选型要求

#### 1.1 库选择标准

**核心原则**：
1. **纯C/C++实现**：必须是原生C/C++库，无Java/JavaScript依赖
2. **跨平台支持**：支持Linux/Android/HarmonyOS编译
3. **许可证友好**：MIT/Apache 2.0/BSD等宽松许可证
4. **活跃维护**：GitHub Stars > 1000，最近6个月有更新
5. **性能优异**：压缩速度 > 100MB/s，解压速度 > 200MB/s

#### 1.2 推荐库清单

| 算法 | 推荐库 | 版本 | 许可证 | GitHub Stars | 说明 |
|------|--------|------|--------|--------------|------|
| **ZSTD** | [facebook/zstd](https://github.com/facebook/zstd) | >= 1.5.5 | BSD-3 | 10k+ | Facebook开源，性能最佳 |
| **LZ4** | [lz4/lz4](https://github.com/lz4/lz4) | >= 1.9.4 | BSD-2 | 8k+ | 极速压缩，适合实时场景 |
| **Snappy** | [google/snappy](https://github.com/google/snappy) | >= 1.1.10 | BSD-3 | 4k+ | Google开源，平衡型 |

#### 1.3 库获取方式

**方案A：HarmonyOS官方HAR包（推荐）**
```bash
# 从ohpm仓库安装
ohpm install @ohos/libzstd
ohpm install @ohos/liblz4
ohpm install @ohos/libsnappy
```

**方案B：手动编译集成**
```bash
# 1. 克隆源码
git clone https://github.com/facebook/zstd.git
cd zstd/build/cmake

# 2. 交叉编译为HarmonyOS架构
mkdir build && cd build
cmake -DCMAKE_TOOLCHAIN_FILE=$OHOS_NDK_ROOT/build/cmake/ohos.toolchain.cmake \
      -DOHOS_ARCH=arm64-v8a \
      -DCMAKE_BUILD_TYPE=Release \
      ..
make -j8

# 3. 生成的库文件
# libzstd.so -> entry/src/main/cpp/libs/arm64-v8a/
# libzstd.a  -> entry/src/main/cpp/libs/arm64-v8a/
```

**方案C：预编译二进制**
```bash
# 从官方Release下载预编译的.so文件
# 放置到：entry/src/main/cpp/libs/{arch}/
```

---

### 2. Native C++ 底层要求

#### 1.1 库选择

**推荐方案**：使用官方zstd库的C API

```cpp
// CMakeLists.txt
find_library(zstd-lib zstd)

target_link_libraries(entry PUBLIC ${zstd-lib})
```

**依赖版本**：
- zstd: >= 1.5.0
- 编译选项: `-O2` (优化级别)

#### 1.2 NAPI接口设计

**文件结构**：
```
entry/src/main/cpp/
├── compress/
│   ├── zstd_napi.cpp          # NAPI绑定入口
│   ├── zstd_napi.h            # NAPI接口声明
│   ├── zstd_wrapper.cpp       # C++包装器
│   └── zstd_wrapper.h         # C++包装器声明
├── CMakeLists.txt
└── types.d.ts                 # TypeScript类型定义
```

**核心NAPI函数**：

```cpp
// zstd_napi.cpp
#include <napi/native_api.h>
#include "zstd_wrapper.h"

/**
 * NAPI: 异步压缩函数
 * 
 * JavaScript调用:
 * const compressed = await zstdCompress(inputBuffer, level);
 */
napi_value ZstdCompressAsync(napi_env env, napi_callback_info info) {
    // 1. 解析参数
    napi_value argv[2];
    size_t argc = 2;
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    
    // 2. 获取输入数据 (ArrayBuffer)
    void* inputData;
    size_t inputLength;
    napi_get_arraybuffer_info(env, argv[0], &inputData, &inputLength);
    
    // 3. 获取压缩级别
    int32_t level;
    napi_get_value_int32(env, argv[1], &level);
    
    // 4. 创建Promise
    napi_deferred deferred;
    napi_value promise;
    napi_create_promise(env, &deferred, &promise);
    
    // 5. 异步执行压缩（在工作线程）
    CompressTask* task = new CompressTask{
        .env = env,
        .deferred = deferred,
        .inputData = static_cast<const char*>(inputData),
        .inputLength = inputLength,
        .level = level
    };
    
    napi_queue_async_work(env, nullptr, task, ExecuteCompress, CompleteCompress, nullptr);
    
    return promise;
}

/**
 * 工作线程执行压缩
 */
void ExecuteCompress(napi_env env, void* data) {
    CompressTask* task = static_cast<CompressTask*>(data);
    
    // 调用zstd C API
    size_t compressedSize = ZSTD_compressBound(task->inputLength);
    char* compressedBuffer = new char[compressedSize];
    
    size_t result = ZSTD_compress(
        compressedBuffer, 
        compressedSize,
        task->inputData,
        task->inputLength,
        task->level
    );
    
    if (ZSTD_isError(result)) {
        task->error = ZSTD_getErrorName(result);
        task->compressedData = nullptr;
        task->compressedSize = 0;
    } else {
        task->compressedData = compressedBuffer;
        task->compressedSize = result;
    }
}

/**
 * 主线程完成回调
 */
void CompleteCompress(napi_env env, napi_status status, void* data) {
    CompressTask* task = static_cast<CompressTask*>(data);
    
    if (task->error) {
        // 创建Error对象
        napi_value error;
        napi_create_string_utf8(env, task->error, NAPI_AUTO_LENGTH, &error);
        napi_reject_deferred(env, task->deferred, error);
    } else {
        // 创建ArrayBuffer返回结果
        napi_value arrayBuffer;
        void* bufferData;
        napi_create_arraybuffer(env, task->compressedSize, &bufferData, &arrayBuffer);
        memcpy(bufferData, task->compressedData, task->compressedSize);
        
        napi_resolve_deferred(env, task->deferred, arrayBuffer);
        
        delete[] task->compressedData;
    }
    
    delete task;
}
```

#### 1.3 内存管理规范

**关键原则**：
1. **零拷贝**：直接使用ArrayBuffer的底层指针
2. **生命周期管理**：NAPI负责JavaScript侧，C++负责Native侧
3. **避免内存泄漏**：使用RAII模式

```cpp
// 安全的内存管理类
class SafeBuffer {
public:
    SafeBuffer(size_t size) : data_(new char[size]), size_(size) {}
    ~SafeBuffer() { delete[] data_; }
    
    // 禁止拷贝
    SafeBuffer(const SafeBuffer&) = delete;
    SafeBuffer& operator=(const SafeBuffer&) = delete;
    
    // 允许移动
    SafeBuffer(SafeBuffer&& other) noexcept 
        : data_(other.data_), size_(other.size_) {
        other.data_ = nullptr;
        other.size_ = 0;
    }
    
    char* data() const { return data_; }
    size_t size() const { return size_; }
    
private:
    char* data_;
    size_t size_;
};
```

---

### 3. ArkTS 封装层要求

#### 2.1 接口定义

**文件**：`entry/src/main/ets/common/compress/ICompressor.ets`

```typescript
/**
 * 统一压缩器接口（异步流式）
 */
export interface ICompressor {
  /**
   * 异步流式压缩
   * @param inputData 原始数据（ArrayBuffer或Uint8Array）
   * @param outputCallback 输出回调（流式接收压缩数据）
   * @returns Promise，压缩完成后resolve
   */
  compress(
    inputData: ArrayBuffer | Uint8Array,
    outputCallback?: (chunk: Uint8Array) => void
  ): Promise<ArrayBuffer>;
  
  /**
   * 异步流式解压
   * @param compressedData 压缩数据
   * @param outputCallback 输出回调（流式接收解压数据）
   * @returns Promise，解压完成后resolve
   */
  decompress(
    compressedData: ArrayBuffer | Uint8Array,
    outputCallback?: (chunk: Uint8Array) => void
  ): Promise<ArrayBuffer>;
  
  /**
   * 获取压缩方法
   */
  getMethod(): CompressionMethod;
  
  /**
   * 关闭资源
   */
  close(): void;
}
```

#### 2.2 ZstdCompressor实现

**文件**：`entry/src/main/ets/common/compress/impl/ZstdCompressor.ets`

```typescript
import { ICompressor } from '../ICompressor';
import { CompressionMethod } from '../CompressionMethod';
import { CompressorConfig } from '../CompressorConfig';
import { CompressionError, CompressionErrorCode } from '../CompressionError';
import { zstdCompress, zstdDecompress } from '@kit.NativeKit'; // NAPI模块

/**
 * ZSTD压缩器实现（HarmonyOS版本）
 * 
 * 基于Native C++ zstd库的ArkTS封装
 */
export class ZstdCompressor implements ICompressor {
  private config: CompressorConfig;
  
  constructor(config: CompressorConfig) {
    if (!config || config.method !== CompressionMethod.ZSTD) {
      throw new CompressionError(
        CompressionErrorCode.CONFIG_ERROR,
        'Invalid configuration for ZstdCompressor'
      );
    }
    this.config = config;
  }
  
  /**
   * 异步压缩
   * 
   * 性能优化：
   * 1. 直接使用ArrayBuffer，避免拷贝
   * 2. Native层异步执行，不阻塞UI线程
   * 3. 支持流式输出（大文件场景）
   */
  async compress(
    inputData: ArrayBuffer | Uint8Array,
    outputCallback?: (chunk: Uint8Array) => void
  ): Promise<ArrayBuffer> {
    try {
      // 转换为ArrayBuffer
      const buffer = inputData instanceof Uint8Array 
        ? inputData.buffer 
        : inputData;
      
      // 调用Native层异步压缩
      const compressedBuffer = await zstdCompress(
        buffer,
        this.config.compressionLevel
      );
      
      // 如果提供了回调，分块输出
      if (outputCallback) {
        const chunk = new Uint8Array(compressedBuffer);
        outputCallback(chunk);
      }
      
      return compressedBuffer;
      
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      throw new CompressionError(
        CompressionErrorCode.ALGORITHM_ERROR,
        `ZSTD compression failed: ${errorMsg}`
      );
    }
  }
  
  /**
   * 异步解压
   * 
   * 性能优化：
   * 1. 零拷贝：直接使用Native层返回的ArrayBuffer
   * 2. 异步执行：在工作线程中解压
   * 3. 错误处理：统一的CompressionError
   */
  async decompress(
    compressedData: ArrayBuffer | Uint8Array,
    outputCallback?: (chunk: Uint8Array) => void
  ): Promise<ArrayBuffer> {
    try {
      // 转换为ArrayBuffer
      const buffer = compressedData instanceof Uint8Array
        ? compressedData.buffer
        : compressedData;
      
      // 调用Native层异步解压
      const decompressedBuffer = await zstdDecompress(buffer);
      
      // 如果提供了回调，分块输出
      if (outputCallback) {
        const chunk = new Uint8Array(decompressedBuffer);
        outputCallback(chunk);
      }
      
      return decompressedBuffer;
      
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      throw new CompressionError(
        CompressionErrorCode.ALGORITHM_ERROR,
        `ZSTD decompression failed: ${errorMsg}`
      );
    }
  }
  
  getMethod(): CompressionMethod {
    return CompressionMethod.ZSTD;
  }
  
  getConfig(): CompressorConfig {
    return this.config;
  }
  
  async updateConfig(config: CompressorConfig): Promise<void> {
    if (config.method !== CompressionMethod.ZSTD) {
      throw new CompressionError(
        CompressionErrorCode.CONFIG_ERROR,
        'Invalid compression method'
      );
    }
    this.config = config;
  }
  
  close(): void {
    // Native资源由GC自动管理
    // 如果有显式的资源需要释放，在这里处理
  }
}
```

#### 2.3 工厂类

**文件**：`entry/src/main/ets/common/compress/CompressorFactory.ets`

```typescript
import { ICompressor } from './ICompressor';
import { CompressionMethod } from './CompressionMethod';
import { CompressorConfig, createCompressorConfig } from './CompressorConfig';
import { ZstdCompressor } from './impl/ZstdCompressor';

/**
 * 压缩器工厂
 */
export class CompressorFactory {
  
  /**
   * 创建压缩器
   */
  static createCompressor(config: CompressorConfig): ICompressor {
    switch (config.method) {
      case CompressionMethod.ZSTD:
        return new ZstdCompressor(config);
      
      case CompressionMethod.LZ4:
        // TODO: 实现LZ4压缩器
        throw new Error('LZ4 compressor not yet implemented');
      
      case CompressionMethod.SNAPPY:
        // TODO: 实现Snappy压缩器
        throw new Error('Snappy compressor not yet implemented');
      
      case CompressionMethod.NONE:
        // TODO: 实现无压缩器
        throw new Error('None compressor not yet implemented');
      
      default:
        throw new Error(`Unsupported compression method: ${config.method}`);
    }
  }
  
  /**
   * 快速创建ZSTD压缩器
   */
  static createZstdCompressor(level: number = 3): ICompressor {
    const config = createCompressorConfig({
      method: CompressionMethod.ZSTD,
      compressionLevel: level,
      bufferSize: 64 * 1024
    });
    return this.createCompressor(config);
  }
}
```

---

## 📦 依赖管理

### 1. oh-package.json5（应用级）

```json5
{
  "name": "remote-desktop-client",
  "version": "1.0.0",
  "dependencies": {
    // 方案A：使用官方HAR包（推荐）
    "@ohos/libzstd": "^1.5.5",
    "@ohos/liblz4": "^1.9.4",
    "@ohos/libsnappy": "^1.1.10"
  }
}
```

### 2. CMakeLists.txt（Native层）

```cmake
cmake_minimum_required(VERSION 3.4.1)

project(remote-desktop-client)

# ==================== 查找第三方库 ====================

# 方案A：使用HAR包提供的库
find_library(zstd-lib zstd)
find_library(lz4-lib lz4)
find_library(snappy-lib snappy)

# 方案B：使用本地编译的库
# set(ZSTD_LIB_PATH ${CMAKE_CURRENT_SOURCE_DIR}/libs/${OHOS_ARCH}/libzstd.so)
# set(LZ4_LIB_PATH ${CMAKE_CURRENT_SOURCE_DIR}/libs/${OHOS_ARCH}/liblz4.so)
# set(SNAPPY_LIB_PATH ${CMAKE_CURRENT_SOURCE_DIR}/libs/${OHOS_ARCH}/libsnappy.so)

# ==================== 添加源文件 ====================

add_library(compress SHARED
    compress/zstd_napi.cpp
    compress/zstd_wrapper.cpp
    compress/lz4_napi.cpp
    compress/lz4_wrapper.cpp
    compress/snappy_napi.cpp
    compress/snappy_wrapper.cpp
)

# ==================== 包含头文件 ====================

target_include_directories(compress PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/compress
    # 方案B：添加本地头文件路径
    # ${CMAKE_CURRENT_SOURCE_DIR}/libs/include
)

# ==================== 链接库 ====================

target_link_libraries(compress PUBLIC
    # 第三方压缩库
    ${zstd-lib}
    ${lz4-lib}
    ${snappy-lib}
    
    # HarmonyOS系统库
    hilog_ndk.z        # 日志
    napi_ndk.z         # NAPI
    ace_ndk.z          # ACE框架
)

# ==================== 编译选项 ====================

target_compile_options(compress PRIVATE
    -O2                    # 优化级别
    -fPIC                  # 位置无关代码
    -Wall -Wextra          # 警告
    -std=c++17             # C++标准
)
```

### 3. 目录结构

```
entry/src/main/
├── cpp/
│   ├── compress/
│   │   ├── zstd_napi.cpp          # ZSTD NAPI绑定
│   │   ├── zstd_wrapper.cpp       # ZSTD C++包装器
│   │   ├── lz4_napi.cpp           # LZ4 NAPI绑定
│   │   ├── lz4_wrapper.cpp        # LZ4 C++包装器
│   │   ├── snappy_napi.cpp        # Snappy NAPI绑定
│   │   ├── snappy_wrapper.cpp     # Snappy C++包装器
│   │   ├── buffer_pool.cpp        # 内存池管理
│   │   └── compression_error.cpp  # 错误处理
│   ├── libs/
│   │   ├── arm64-v8a/
│   │   │   ├── libzstd.so
│   │   │   ├── liblz4.so
│   │   │   └── libsnappy.so
│   │   └── armeabi-v7a/
│   │       ├── libzstd.so
│   │       ├── liblz4.so
│   │       └── libsnappy.so
│   ├── include/
│   │   ├── zstd.h                 # ZSTD头文件
│   │   ├── lz4.h                  # LZ4头文件
│   │   └── snappy.h               # Snappy头文件
│   └── CMakeLists.txt
├── ets/
│   └── common/
│       └── compress/
│           ├── ICompressor.ets
│           ├── CompressionMethod.ets
│           ├── CompressorConfig.ets
│           ├── CompressionError.ets
│           ├── CompressorFactory.ets
│           └── impl/
│               ├── ZstdCompressor.ets
│               ├── Lz4Compressor.ets
│               └── SnappyCompressor.ets
└── resources/
```

### 4. build-profile.json5（架构配置）

```json5
{
  "app": {
    "signingConfigs": [],
    "products": [
      {
        "name": "default",
        "signingConfig": "default",
        "compatibleSdkVersion": "5.0.0(12)",
        "runtimeOS": "HarmonyOS",
        "buildOption": {
          "nativeLib": {
            "debugSymbol": {
              "strip": true,
              "exclude": []
            },
            "abiFilters": [
              "arm64-v8a",    // 64位ARM（主流设备）
              "armeabi-v7a"   // 32位ARM（兼容旧设备）
            ]
          }
        }
      }
    ]
  }
}
```

---

## ⚡ 性能优化策略

### 1. 零拷贝设计

**问题**：传统方案需要在JavaScript和Native之间多次拷贝数据

**解决方案**：
```cpp
// ❌ 旧方案：多次拷贝
char* temp = new char[inputLength];
memcpy(temp, inputData, inputLength);  // 第1次拷贝
// ... 压缩 ...
napi_create_arraybuffer(env, result, &outputData, &outputBuffer);
memcpy(outputData, compressedData, compressedSize);  // 第2次拷贝

// ✅ 新方案：零拷贝
void* inputData;
napi_get_arraybuffer_info(env, argv[0], &inputData, &inputLength);
// 直接使用inputData指针，无需拷贝
size_t result = ZSTD_compress(outputBuffer, ..., inputData, ...);
```

### 2. 异步执行

**问题**：压缩/解压是CPU密集型操作，会阻塞UI线程

**解决方案**：
```typescript
// ✅ 使用NAPI异步工作队列
napi_queue_async_work(env, nullptr, task, ExecuteCompress, CompleteCompress, nullptr);

// 工作线程执行
void ExecuteCompress(napi_env env, void* data) {
    // CPU密集型操作在工作线程执行
    ZSTD_compress(...);
}

// 主线程回调
void CompleteCompress(napi_env env, napi_status status, void* data) {
    // 只在主线程更新UI/返回结果
    napi_resolve_deferred(env, deferred, result);
}
```

### 3. 内存池复用

**问题**：频繁分配/释放ArrayBuffer导致GC压力

**解决方案**：
```cpp
// 内存池管理器
class BufferPool {
public:
    static BufferPool& getInstance() {
        static BufferPool instance;
        return instance;
    }
    
    char* acquire(size_t size) {
        // 从池中获取缓冲区，避免重复分配
        auto it = pool_.find(size);
        if (it != pool_.end() && !it->second.empty()) {
            char* buffer = it->second.back();
            it->second.pop_back();
            return buffer;
        }
        return new char[size];
    }
    
    void release(char* buffer, size_t size) {
        // 归还到池中，而非直接删除
        pool_[size].push_back(buffer);
    }
    
private:
    std::unordered_map<size_t, std::vector<char*>> pool_;
};
```

---

## 🧪 测试要求

### 1. 单元测试

```typescript
// ZstdCompressor.test.ets
import { describe, it, expect } from '@ohos/hypium';
import { ZstdCompressor } from '../common/compress/impl/ZstdCompressor';
import { createCompressorConfig } from '../common/compress/CompressorConfig';
import { CompressionMethod } from '../common/compress/CompressionMethod';

describe('ZstdCompressor', () => {
  it('should compress and decompress correctly', async () => {
    const config = createCompressorConfig({
      method: CompressionMethod.ZSTD,
      compressionLevel: 3
    });
    
    const compressor = new ZstdCompressor(config);
    
    // 测试数据
    const testData = new Uint8Array([1, 2, 3, 4, 5]);
    const inputBuffer = testData.buffer;
    
    // 压缩
    const compressed = await compressor.compress(inputBuffer);
    expect(compressed.byteLength).toBeLessThan(inputBuffer.byteLength);
    
    // 解压
    const decompressed = await compressor.decompress(compressed);
    const result = new Uint8Array(decompressed);
    
    // 验证数据一致性
    expect(result.length).toEqual(testData.length);
    for (let i = 0; i < testData.length; i++) {
      expect(result[i]).toEqual(testData[i]);
    }
    
    compressor.close();
  });
});
```

### 2. 性能基准测试

```typescript
// PerformanceBenchmark.ets
async function benchmarkCompression() {
  const compressor = CompressorFactory.createZstdCompressor(3);
  
  // 测试数据：1MB
  const testData = new Uint8Array(1024 * 1024);
  for (let i = 0; i < testData.length; i++) {
    testData[i] = i % 256;
  }
  
  // 压缩性能测试
  const compressStart = Date.now();
  for (let i = 0; i < 100; i++) {
    await compressor.compress(testData.buffer);
  }
  const compressEnd = Date.now();
  
  console.log(`压缩100次耗时: ${compressEnd - compressStart}ms`);
  console.log(`平均每次: ${(compressEnd - compressStart) / 100}ms`);
  
  compressor.close();
}
```

---

## 📊 预期性能指标

| 指标 | 旧方案（临时文件） | 新方案（Native内存） | 提升幅度 |
|------|------------------|---------------------|---------|
| 解压延迟 | 50-100ms/帧 | 5-10ms/帧 | **-90%** |
| 磁盘IO | 4次/帧 | 0次/帧 | **-100%** |
| 内存拷贝 | 3次 | 0次（零拷贝） | **-100%** |
| CPU使用率 | 30-40% | 15-20% | **-50%** |
| GC停顿 | 50ms/s | <10ms/s | **-80%** |

---

## 🚀 实施计划

### 阶段1：Native层开发（1周）

- [ ] 编写zstd_napi.cpp NAPI绑定
- [ ] 实现zstd_wrapper.cpp C++包装器
- [ ] 配置CMakeLists.txt
- [ ] 编写types.d.ts类型定义

### 阶段2：ArkTS封装层开发（1周）

- [ ] 实现ZstdCompressor.ets
- [ ] 实现CompressorFactory.ets
- [ ] 完善错误处理
- [ ] 添加日志记录

### 阶段3：集成测试（1周）

- [ ] 编写单元测试
- [ ] 性能基准测试
- [ ] 集成到RemoteControlService
- [ ] 端到端测试

### 阶段4：优化与调优（1周）

- [ ] 内存池优化
- [ ] 异步执行优化
- [ ] 错误处理完善
- [ ] 文档完善

---

## ⚠️ 注意事项

### 1. 兼容性

- **最低HarmonyOS版本**：API 9+
- **NAPI版本**：NAPI 8+
- **zstd库版本**：>= 1.5.0

### 2. 安全性

- **输入验证**：所有Native接口必须验证参数
- **内存安全**：使用智能指针管理Native内存
- **异常处理**：捕获所有C++异常，转换为JavaScript Error

### 3. 调试

- **日志级别**：
  - DEBUG：详细压缩/解压过程
  - INFO：关键操作（开始/完成）
  - ERROR：错误信息
  
- **性能监控**：
  - 记录每次压缩/解压的耗时
  - 监控内存使用情况
  - 跟踪GC频率

---

## ✅ 第三方库集成检查清单

### 阶段1：库准备

- [ ] **选择压缩算法**
  - [ ] ZSTD（推荐，性能最佳）
  - [ ] LZ4（极速，适合实时场景）
  - [ ] Snappy（平衡型）
  
- [ ] **获取库文件**
  - [ ] 方案A：从ohpm安装HAR包
  - [ ] 方案B：手动编译.so文件
  - [ ] 方案C：下载预编译二进制
  
- [ ] **验证库完整性**
  ```bash
  # 检查.so文件是否存在
  ls entry/src/main/cpp/libs/arm64-v8a/libzstd.so
  ls entry/src/main/cpp/libs/armeabi-v7a/libzstd.so
  
  # 检查符号表
  nm -D libzstd.so | grep ZSTD_compress
  nm -D libzstd.so | grep ZSTD_decompress
  ```

### 阶段2：Native层集成

- [ ] **配置CMakeLists.txt**
  - [ ] 添加find_library查找第三方库
  - [ ] 配置target_link_libraries链接库
  - [ ] 设置target_include_directories包含头文件
  - [ ] 配置编译选项（-O2, -fPIC, -std=c++17）
  
- [ ] **编写NAPI绑定代码**
  - [ ] zstd_napi.cpp：ZSTD的NAPI接口
  - [ ] lz4_napi.cpp：LZ4的NAPI接口
  - [ ] snappy_napi.cpp：Snappy的NAPI接口
  - [ ] 实现异步工作队列（napi_queue_async_work）
  - [ ] 实现Promise返回机制
  
- [ ] **编写C++包装器**
  - [ ] zstd_wrapper.cpp：封装ZSTD C API
  - [ ] lz4_wrapper.cpp：封装LZ4 C API
  - [ ] snappy_wrapper.cpp：封装Snappy C++ API
  - [ ] 实现错误处理逻辑
  - [ ] 实现内存管理（RAII模式）
  
- [ ] **创建TypeScript类型定义**
  - [ ] types/libzstd.d.ts：ZSTD函数签名
  - [ ] types/liblz4.d.ts：LZ4函数签名
  - [ ] types/libsnappy.d.ts：Snappy函数签名

### 阶段3：ArkTS封装层

- [ ] **实现压缩器类**
  - [ ] ZstdCompressor.ets：ZSTD实现
  - [ ] Lz4Compressor.ets：LZ4实现
  - [ ] SnappyCompressor.ets：Snappy实现
  - [ ] 统一实现ICompressor接口
  - [ ] 实现异步Promise封装
  
- [ ] **实现工厂类**
  - [ ] CompressorFactory.ets：创建压缩器实例
  - [ ] 支持配置化创建
  - [ ] 实现实例缓存（可选）
  
- [ ] **实现错误处理**
  - [ ] CompressionError.ets：统一错误类
  - [ ] CompressionErrorCode.ets：错误码枚举
  - [ ] Native错误转换为JavaScript Error

### 阶段4：测试与验证

- [ ] **单元测试**
  - [ ] 测试ZSTD压缩/解压正确性
  - [ ] 测试LZ4压缩/解压正确性
  - [ ] 测试Snappy压缩/解压正确性
  - [ ] 测试边界条件（空数据、大数据）
  - [ ] 测试错误处理（损坏数据）
  
- [ ] **性能基准测试**
  - [ ] 测量压缩速度（MB/s）
  - [ ] 测量解压速度（MB/s）
  - [ ] 测量压缩率（%）
  - [ ] 测量内存使用（MB）
  - [ ] 测量CPU使用率（%）
  
- [ ] **集成测试**
  - [ ] 集成到RemoteControlService
  - [ ] 端到端测试（发送→压缩→传输→解压→显示）
  - [ ] 压力测试（连续运行1小时）
  - [ ] 内存泄漏检测

### 阶段5：优化与调优

- [ ] **性能优化**
  - [ ] 实现零拷贝（直接使用ArrayBuffer指针）
  - [ ] 实现内存池（减少分配/释放开销）
  - [ ] 优化异步执行（工作线程池）
  - [ ] 调整压缩级别（平衡速度与压缩率）
  
- [ ] **稳定性优化**
  - [ ] 添加输入验证（防止崩溃）
  - [ ] 完善错误处理（优雅降级）
  - [ ] 添加日志记录（便于调试）
  - [ ] 监控资源使用（内存、CPU）

---

## ⚠️ 常见问题与解决方案

### 问题1：找不到库文件

**症状**：
```
ERROR: ld.so: cannot open shared object file: libzstd.so
```

**解决方案**：
```bash
# 1. 确认.so文件存在
ls entry/src/main/cpp/libs/arm64-v8a/libzstd.so

# 2. 检查CMakeLists.txt中的find_library
find_library(zstd-lib zstd PATHS ${CMAKE_CURRENT_SOURCE_DIR}/libs/${OHOS_ARCH})

# 3. 重新编译
hvigorw clean
hvigorw assembleHap
```

### 问题2：NAPI调用失败

**症状**：
```
TypeError: zstdCompress is not a function
```

**解决方案**：
```typescript
// 1. 检查模块导出
// libzstd/index.ets
export { zstdCompress, zstdDecompress } from './src/main/cpp/compress/zstd_napi'

// 2. 检查导入路径
import { zstdCompress } from '@ohos/libzstd'  // 确保路径正确

// 3. 检查types.d.ts
// 确保函数签名正确
declare function zstdCompress(input: ArrayBuffer, level: number): Promise<ArrayBuffer>
```

### 问题3：内存泄漏

**症状**：
```
应用运行一段时间后OOM（Out Of Memory）
```

**解决方案**：
```cpp
// 1. 使用智能指针管理内存
class SafeBuffer {
public:
    ~SafeBuffer() { delete[] data_; }  // 自动释放
private:
    char* data_;
};

// 2. 避免在循环中分配内存
char* buffer = BufferPool::getInstance().acquire(size);  // 从池中获取
// ... 使用buffer ...
BufferPool::getInstance().release(buffer, size);  // 归还到池

// 3. 监控内存使用
HiLog::Info(LOG_TAG, "Memory usage: %zu bytes", currentUsage);
```

### 问题4：性能不达标

**症状**：
```
压缩速度 < 50MB/s，解压速度 < 100MB/s
```

**解决方案**：
```cpp
// 1. 启用编译器优化
// CMakeLists.txt
target_compile_options(compress PRIVATE -O3)  // 最高优化级别

// 2. 使用SIMD指令
// CMakeLists.txt
target_compile_options(compress PRIVATE -march=armv8-a+simd)

// 3. 调整压缩级别
// ArkTS层
const compressor = new ZstdCompressor({
  compressionLevel: 1  // 降低级别，提高速度
});

// 4. 使用多线程
// 在工作线程中执行压缩
napi_queue_async_work(env, nullptr, task, ExecuteCompress, CompleteCompress, nullptr);
```

---

## 📝 总结

本架构设计采用**Native C++底层 + ArkTS封装**的分层设计，实现了：

✅ **高性能**：零拷贝、异步执行、内存池复用  
✅ **易用性**：统一的ICompressor接口，与Java端一致  
✅ **可维护性**：清晰的层次分离，职责明确  
✅ **可扩展性**：易于添加新的压缩算法  

**下一步**：按照实施计划逐步开发，优先完成Native层的NAPI绑定。

---

**文档版本**：v1.1  
**最后更新**：2026-05-10 20:00  
**维护团队**：方寸控技术团队  
**更新内容**：添加第三方库选型要求、依赖管理规范、集成检查清单
