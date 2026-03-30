# NAPI + 原生zstd 方案技术文档

## 概述

本文档描述了使用HarmonyOS NAPI（Native API）绑定原生Facebook zstd库的方案，用于实现高性能的ZSTD解压功能。

## 方案架构

```
┌─────────────────────────────────────────┐
│      ArkTS 应用层                       │
│  (RemoteControlService.ets)            │
└───────────────┬─────────────────────────┘
                │ NAPI 接口
┌───────────────▼─────────────────────────┐
│    NAPI 绑定层 (C/C++)                   │
│  (zstd_napi.cpp)                         │
└───────────────┬─────────────────────────┘
                │ 原生调用
┌───────────────▼─────────────────────────┐
│   原生 zstd 库 (C/C++)                  │
│  (Facebook 的 zstd 实现)                │
└─────────────────────────────────────────┘
```

## 技术栈

- **ArkTS**: HarmonyOS应用层开发语言
- **NAPI**: HarmonyOS Native API，用于ArkTS与C/C++互操作
- **C/C++**: 原生层开发语言
- **Facebook zstd**: 高性能ZSTD压缩库
- **CMake**: 原生代码编译工具

## 开发工作量评估

| 任务 | 工作量 | 说明 |
|------|--------|------|
| 学习NAPI | 3-5天 | 学习HarmonyOS NAPI开发框架和最佳实践 |
| 配置编译环境 | 1-2天 | 配置CMake、NDK等工具链和构建脚本 |
| 编写绑定代码 | 3-5天 | 实现ArkTS ↔ C++的数据转换和接口绑定 |
| 调试和测试 | 3-7天 | Native调试比纯ArkTS困难，需要更多时间 |
| **总计** | **10-20天** | 不包括后续优化和性能测试 |

## 详细实现步骤

### 1. 项目结构

```
HarmonOS_remote_desktop_control_client/
├── entry/
│   └── src/main/
│       ├── ets/
│       │   └── services/remote/
│       │       └── RemoteControlService.ets  (使用NAPI模块)
│       └── cpp/
│           ├── CMakeLists.txt                 (CMake构建脚本)
│           ├── zstd_napi.cpp                  (NAPI绑定代码)
│           └── zstd/                           (Facebook zstd源码)
│               ├── lib/
│               └── include/
└── build-profile.json5                      (配置NAPI模块)
```

### 2. NAPI绑定代码示例

```cpp
// zstd_napi.cpp
#include <napi/native_api.h>
#include <zstd.h>

// 解压函数
static napi_value Decompress(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    
    // 获取输入数据
    void* input_data;
    size_t input_len;
    napi_get_arraybuffer_info(env, args[0], &input_data, &input_len);
    
    // 计算解压后大小
    size_t decompressed_size = ZSTD_getFrameContentSize(input_data, input_len);
    
    // 分配输出缓冲区
    napi_value output_buffer;
    void* output_data;
    napi_create_arraybuffer(env, decompressed_size, &output_data, &output_buffer);
    
    // 执行解压
    size_t result = ZSTD_decompress(output_data, decompressed_size, input_data, input_len);
    
    if (ZSTD_isError(result)) {
        napi_throw_error(env, nullptr, "ZSTD decompression failed");
        return nullptr;
    }
    
    return output_buffer;
}

// 模块初始化
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc = {
        "decompress", nullptr, Decompress, nullptr, nullptr, nullptr,
        napi_default, nullptr
    };
    napi_define_properties(env, exports, 1, &desc);
    return exports;
}

NAPI_MODULE(NODE_GYP_MODULE_NAME, Init)
```

### 3. ArkTS调用示例

```typescript
// RemoteControlService.ets
import zstd from 'libzstd.so';

class RemoteControlService {
  async decompressZSTD(data: ArrayBuffer): Promise<ArrayBuffer> {
    return zstd.decompress(data);
  }
}
```

## 优势

1. **性能最佳** - 接近原生C/C++速度，比JavaScript/ArkTS实现快5-10倍
2. **功能完整** - 完整支持zstd的所有特性和压缩级别
3. **经过验证** - Facebook zstd是工业级标准，广泛使用
4. **资源占用低** - 原生代码内存占用更小

## 挑战和风险

1. **开发复杂度高** - 需要掌握多个技术栈
2. **调试困难** - Native调试比纯ArkTS复杂
3. **维护成本高** - 多个语言层，HarmonyOS版本更新可能需要适配
4. **编译时间长** - 每次修改都需要重新编译Native代码
5. **平台兼容性** - 需要为不同设备架构（arm64、x86等）单独编译

## 与其他方案对比

| 方案 | 开发时间 | 性能 | 复杂度 | 推荐度 |
|------|----------|------|--------|--------|
| **NAPI + 原生zstd** | 10-20天 | ⭐⭐⭐⭐⭐ | 高 | ⭐⭐ |
| **临时文件+@ohos.zlib** | 1-2天 | ⭐⭐⭐ | 低 | ⭐⭐⭐⭐⭐ |
| **pako.js (DEFLATE)** | 2-3天 | ⭐⭐⭐ | 中 | ⭐⭐⭐⭐ |
| **fzstd (纯JS)** | 2-3天(+修复错误) | ⭐⭐⭐⭐ | 高 | ⭐⭐ |

## 推荐实施策略

### 阶段1：快速验证（当前）
使用**临时文件+@ohos.zlib**方案快速验证整个远程桌面控制流程是否通畅。

### 阶段2：性能评估
如果临时文件方案性能无法满足需求，再考虑：
- 尝试pako.js等纯JS/TS库
- 或直接实施NAPI + 原生zstd方案

### 阶段3：优化实施
如果确定需要高性能，再投入资源实施NAPI + 原生zstd方案。

## 参考资料

- [HarmonyOS NAPI开发指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/napi-dev-guide-V5)
- [Facebook zstd GitHub](https://github.com/facebook/zstd)
- [HarmonyOS CMake编译配置](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/ide-building-0000001687087946-V5)
