# 详细性能监控方案

## 概述

本方案在原有的FPS、延迟、跳帧率监控基础上，增加了每个处理环节的详细性能指标监控，帮助精确定位性能瓶颈。

## 监控环节划分

### 1. 网络层
- **数据包大小** (dataPacketSize): 接收到的原始数据包大小（字节）
- **队列等待时间** (queueWaitTime): 数据在队列中等待处理的时间

### 2. 协议解析层
- **协议解析耗时** (protocolParseTime): 解析CmdCapture命令的耗时

### 3. 解压缩层
- **解压缩耗时** (decompressTime): ZSTD/ZIP/XZ解压缩的耗时
- **解压后数据大小** (decompressedSize): 解压缩后的原始数据大小

### 4. 帧组装层
- **图像组装耗时** (assembleTime): 将tiles组装成完整图像的耗时
- **Buffer复用率** (bufferReuseRate): 缓冲区复用的百分比

### 5. 渲染层
- **渲染耗时** (renderTime): UI渲染和PixelMap创建的耗时
- **端到端总延迟** (endToEndDelay): 从数据接收到屏幕显示的总时间

### 6. 缓存层
- **缓存命中率** (cacheHitRate): CaptureCache的命中百分比
- **pending队列长度** (pendingQueueSize): 待处理帧队列的长度

## 实现细节

### PerformanceMonitor增强

#### 新增接口字段
```typescript
export interface PerformanceStats {
  // 原有字段...
  
  // 各环节详细性能指标
  networkReceiveTime: number;
  protocolParseTime: number;
  decompressTime: number;
  decompressedSize: number;
  assembleTime: number;
  renderTime: number;
  endToEndDelay: number;
  
  // 缓存统计
  cacheHitRate: number;
  pendingQueueSize: number;
  bufferReuseRate: number;
  
  // 网络统计
  dataPacketSize: number;
  queueWaitTime: number;
}
```

#### 新增监控方法

1. **markFrameStart(dataSize)**: 标记帧开始，记录数据包大小
2. **markProtocolParseStart()**: 标记协议解析开始
3. **recordProtocolParseComplete()**: 记录协议解析完成
4. **markDecompressStart()**: 标记解压缩开始
5. **recordDecompressComplete(decompressedSize)**: 记录解压缩完成
6. **markAssembleStart()**: 标记组装开始
7. **recordAssembleComplete()**: 记录组装完成
8. **markRenderStart()**: 标记渲染开始
9. **recordRenderComplete(frameDelay)**: 记录渲染完成和总延迟
10. **recordCacheAccess(isHit)**: 记录缓存访问（命中/未命中）
11. **recordBufferReuse(isReused)**: 记录Buffer复用情况
12. **recordQueueWait(waitTime)**: 记录队列等待时间
13. **setPendingQueueSize(size)**: 设置pending队列大小

### RemoteControlService集成点

#### 1. 数据接收 (handleReceivedData)
```typescript
// 标记帧开始并记录数据包大小
this.performanceMonitor.markFrameStart(dataSize);
```

#### 2. 协议解析 (processSingleData)
```typescript
// 标记协议解析开始
this.performanceMonitor.markProtocolParseStart();
const commands = await this.protocolHandler.processData(data);
// 记录协议解析完成
this.performanceMonitor.recordProtocolParseComplete();
```

#### 3. 解压缩 (onRawVideoData)
```typescript
// 标记解压缩开始
this.performanceMonitor.markDecompressStart();
const capture: Capture = await compressor.decompress(zippedData);
// 计算解压后数据大小并记录
const decompressedSize = capture.dirtyTiles.reduce(...);
this.performanceMonitor.recordDecompressComplete(decompressedSize);
```

#### 4. 缓存管理 (onRawVideoData)
```typescript
// 记录缓存访问
if (!canMergeToPreCapture) {
  this.captureCache.setPreCapture(currentCapture);
  this.performanceMonitor.recordCacheAccess(false);
} else {
  this.captureCache.addPending(currentCapture);
  this.performanceMonitor.recordCacheAccess(true);
}

// 更新pending队列大小
this.performanceMonitor.setPendingQueueSize(
  this.captureCache.getPendingCaptureQueueSize()
);
```

#### 5. 帧组装 (onRawVideoData)
```typescript
// 记录Buffer复用情况
this.performanceMonitor.recordBufferReuse(hasReusableBuffer);

// 标记组装开始
this.performanceMonitor.markAssembleStart();
const assembleResult = await this.imageAssembler.assemble(renderCapture);
// 记录组装完成
this.performanceMonitor.recordAssembleComplete();
```

#### 6. 渲染 (onRawVideoData)
```typescript
// 标记渲染开始
this.performanceMonitor.markRenderStart();

const renderTimestamp = Date.now();
this.screenCallback(bufferData, widthVal, heightVal, renderTimestamp);

// 计算精确的帧延迟
const frameDelay = renderTimestamp - this.frameReceiveTimestamp;

// 记录渲染完成
this.performanceMonitor.recordRenderComplete(frameDelay);
```

### PerformanceOverlay增强

#### 新增显示项

1. **端到端延迟**: EndToEnd: XXms
2. **解压缩耗时**: Decomp: XXms
3. **组装耗时**: Assemble: XXms
4. **渲染耗时**: Render: XXms
5. **缓存统计**: Cache: XX% (Buf:XX%)
6. **网络统计**: Network: XXB (Q:XXms)

#### 颜色编码规则

- **耗时指标**: 
  - ≤20ms: 绿色（优秀）
  - ≤40ms: 橙色（一般）
  - >40ms: 红色（差）

- **缓存命中率**:
  - ≥90%: 绿色（优秀）
  - ≥70%: 橙色（一般）
  - <70%: 红色（差）

## 日志输出

每5秒输出一次详细日志：

```
FPS: 25 (avg: 24, min: 18, max: 30) | Delay: 45ms (avg: 50ms) | Skip: 2% (5/250)
Pipeline - Network: 5ms | Parse: 3ms | Decompress: 15ms | Assemble: 10ms | Render: 8ms | EndToEnd: 45ms
Cache Hit: 85% | Buffer Reuse: 70% | Pending: 2 | Packet Size: 15KB | Queue Wait: 2ms
```

## 警告阈值

- **低FPS**: <15 FPS
- **高延迟**: >200ms
- **高跳帧率**: >10%
- **高解压缩耗时**: >50ms
- **高组装耗时**: >30ms

## 使用建议

### 性能优化方向

1. **如果解压缩耗时过高**:
   - 考虑降低压缩级别
   - 检查是否可以使用更快的压缩算法
   - 优化Tile大小配置

2. **如果组装耗时过高**:
   - 检查Buffer复用率，提高复用可以减少内存分配
   - 优化drawToBuffer算法
   - 减少不必要的内存拷贝

3. **如果渲染耗时过高**:
   - 检查PixelMap创建效率
   - 优化UI组件渲染
   - 考虑使用硬件加速

4. **如果缓存命中率低**:
   - 调整pending队列处理策略
   - 优化帧合并逻辑
   - 检查网络抖动导致的乱序

5. **如果队列等待时间长**:
   - 增加队列处理并发度
   - 优化单个数据处理速度
   - 考虑丢弃策略

### 监控浮窗使用

1. **开启监控**: 在应用中启用性能监控浮窗
2. **观察指标**: 重点关注端到端延迟和各环节耗时分布
3. **颜色提示**: 红色表示需要优化的环节
4. **趋势分析**: 观察平均值和当前值的差异，判断性能稳定性

## 技术优势

1. **全链路监控**: 覆盖从网络接收到UI渲染的完整流程
2. **精确定位**: 可以准确定位哪个环节是性能瓶颈
3. **实时反馈**: 浮窗实时显示，无需查看日志
4. **历史统计**: 滑动窗口平均，避免瞬时波动误导
5. **智能告警**: 自动检测异常并输出警告日志

## 后续扩展建议

1. **GPU监控**: 添加GPU使用率和渲染时间
2. **内存监控**: 添加内存使用和GC频率
3. **网络质量**: 添加丢包率、重传率等网络指标
4. **温度监控**: 添加设备温度和CPU频率
5. **性能报告**: 生成周期性性能报告，支持导出分析
