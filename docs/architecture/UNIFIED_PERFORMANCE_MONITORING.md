# 方寸控远程桌面系统 - 统一性能监控架构设计

## 📋 文档说明

本文档分析当前项目中性能监控的分散性问题，并提出统一的性能监控架构设计方案。

**分析时间**：2026-05-10  
**问题等级**：P1（重要）  
**影响范围**：全系统（Java被控端 + HarmonyOS控制端 + Java服务端）  

---

## 🔴 问题描述

### 问题4：缺乏统一的性能监控体系

#### 4.1 核心问题

当前项目中存在多个独立的性能监控实现，但缺乏统一的管理和集成：

```
项目结构：
├── Java被控端 (client/)
│   └── monitor/
│       ├── BigBrother.java          ← 简单的计数器调度器
│       ├── Counter.java             ← 抽象计数器基类
│       ├── CaptureRateCounter.java  ← FPS计数器
│       ├── TileCounter.java         ← Tile计数器
│       └── ... (12个独立计数器)
│
├── HarmonyOS控制端 (HarmonOS_remote_desktop_control_client/)
│   └── utils/PerformanceMonitor.ets ← 单一性能监控类
│       ├── PerformanceStats接口      ← 18个字段
│       ├── recordFrame()            ← 帧记录
│       ├── recordRenderComplete()   ← 渲染完成
│       └── getStats()               ← 获取统计
│
└── Java服务端 (server/)
    └── ❌ 无任何性能监控实现
```

**关键缺陷**：

1. **监控分散**：3个端各自为政，没有统一的监控框架
2. **数据孤岛**：无法进行端到端性能分析（从采集到渲染的全链路）
3. **指标不一致**：各端定义的指标不同，无法横向对比
4. **可视化缺失**：只有HarmonyOS端有简单的浮窗，其他端无UI展示
5. **告警机制缺失**：没有性能异常检测和告警
6. **历史数据缺失**：所有监控数据都是实时的，无法回溯分析

---

## 🔍 现状分析

### 4.2 Java被控端监控现状

#### BigBrother + Counter架构

```java
// BigBrother.java - 简单的定时器调度器
public final class BigBrother {
    private final ScheduledExecutorService scheduler = 
        Executors.newSingleThreadScheduledExecutor();
    
    public void registerCounter(final Counter<?> counter, final long instantRatePeriod) {
        scheduler.scheduleAtFixedRate(
            counter::computeAndResetInstantValue, 
            0, 
            instantRatePeriod, 
            TimeUnit.MILLISECONDS
        );
    }
}

// Counter.java - 抽象基类
public abstract class Counter<T> {
    public abstract void computeAndResetInstantValue();
    public abstract String formatInstantValue(T value);
}

// CaptureRateCounter.java - FPS计数器
public class CaptureRateCounter extends RateCounter {
    @Override
    public String formatRate(Double rate) {
        return String.format("%.0f FPS", rate);
    }
}
```

**问题**：
1. ❌ **功能单一**：仅支持计数器和速率计算，不支持延迟、百分位等高级指标
2. ❌ **无数据存储**：计算后立即丢弃，无法查询历史数据
3. ❌ **无可视化**：仅在StatusBar中显示文本，无图表
4. ❌ **无告警**：无法检测性能异常
5. ❌ **耦合严重**：Counter直接依赖BigBrother，难以测试和扩展

**现有计数器列表**：
- `CaptureRateCounter` - 屏幕捕获FPS
- `TileCounter` - Tile数量统计
- `MergedTileCounter` - 合并Tile数量
- `SkippedTileCounter` - 跳过Tile数量
- `CaptureCompressionCounter` - 压缩率统计
- `BitCounter` - 比特率统计
- `AverageValueCounter` - 平均值统计
- `AbsoluteValueCounter` - 绝对值统计

**总计**：8种计数器，但都只支持简单的数值统计。

---

### 4.3 HarmonyOS控制端监控现状

#### PerformanceMonitor单例模式

```typescript
export class PerformanceMonitor {
  private static instance: PerformanceMonitor | null = null;
  
  // FPS统计
  private frameCount: number = 0;
  private currentFps: number = 0;
  private fpsSamples: number[] = [];
  
  // 延迟统计
  private delaySamples: number[] = [];
  private currentDelay: number = 0;
  
  // 各环节性能统计
  private networkReceiveTimes: number[] = [];
  private decompressTimes: number[] = [];
  private assembleTimes: number[] = [];
  private renderTimes: number[] = [];
  private endToEndDelays: number[] = [];
  
  // 缓存统计
  private cacheHits: number = 0;
  private cacheMisses: number = 0;
  
  // 获取统计数据
  getStats(): PerformanceStats {
    return {
      fps: this.currentFps,
      avgFrameDelay: avgDelay,
      decompressTime: avgDecompress,
      renderTime: avgRender,
      endToEndDelay: avgEndToEnd,
      cacheHitRate: cacheHitRate,
      // ... 共18个字段
    };
  }
}
```

**优势**：
- ✅ 支持多维度指标（FPS、延迟、缓存命中率等）
- ✅ 滑动窗口统计（最近30-60个样本）
- ✅ 提供UI浮窗展示（PerformanceOverlay组件）

**问题**：
1. ❌ **单点故障**：单例模式，一旦崩溃整个监控系统失效
2. ❌ **内存泄漏风险**：数组无限增长（虽然有shift，但未设置上限检查）
3. ❌ **无持久化**：应用重启后数据丢失
4. ❌ **无告警**：无法检测性能退化
5. ❌ **无法对比**：缺少基准线（Baseline），无法判断性能是否正常
6. ❌ **埋点不完整**：缺少网络发送、协议编码等环节的监控

**现有指标**（18个字段）：
- FPS相关：fps, avgFps, minFps, maxFps
- 延迟相关：avgFrameDelay, currentFrameDelay, endToEndDelay
- 跳帧相关：totalFrames, skippedFrames, skipRate
- 环节耗时：networkReceiveTime, protocolParseTime, decompressTime, assembleTime, renderTime
- 缓存相关：cacheHitRate, pendingQueueSize, bufferReuseRate
- 网络相关：dataPacketSize, queueWaitTime

---

### 4.4 Java服务端监控现状

**完全空白**：服务端没有任何性能监控实现。

**应该监控的指标**：
- 并发连接数
- 消息吞吐量（msg/s）
- 平均消息延迟
- 会话存活时间
- CPU/内存占用
- 网络带宽使用

---

## 🎯 统一性能监控架构设计

### 4.3 设计目标

1. **统一性**：三端使用相同的监控API和数据模型
2. **可扩展性**：轻松添加新的监控指标
3. **低开销**：监控本身对性能影响<1%
4. **可观测性**：支持实时查看、历史查询、异常告警
5. **跨端关联**：能够追踪一帧从采集到渲染的完整路径

---

### 4.4 核心架构

```
┌─────────────────────────────────────────────────────────────┐
│                   统一性能监控架构                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  应用层 (Application Layer)                                  │
│  ├─ Java被控端                                               │
│  ├─ HarmonyOS控制端                                         │
│  └─ Java服务端                                              │
│                                                             │
│  ↓ 埋点 (Instrumentation)                                   │
│                                                             │
│  监控SDK层 (Monitoring SDK)                                 │
│  ├─ MetricCollector (指标收集器)                             │
│  ├─ MetricAggregator (指标聚合器)                            │
│  ├─ MetricExporter (指标导出器)                              │
│  └─ AlertManager (告警管理器)                                │
│                                                             │
│  ↓ 导出 (Export)                                            │
│                                                             │
│  存储层 (Storage Layer)                                     │
│  ├─ 内存存储 (实时查询)                                      │
│  ├─ 文件存储 (历史数据)                                      │
│  └─ 可选：远程存储 (Prometheus/InfluxDB)                    │
│                                                             │
│  ↓ 查询 (Query)                                             │
│                                                             │
│  可视化层 (Visualization Layer)                             │
│  ├─ 浮窗组件 (移动端)                                        │
│  ├─ Web Dashboard (PC端)                                    │
│  └─ 日志输出 (开发调试)                                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

### 4.5 核心API设计

#### 4.5.1 指标类型定义

```java
// common/src/main/java/io/github/springstudent/dekstop/common/monitor/MetricType.java
package io.github.springstudent.dekstop.common.monitor;

/**
 * 指标类型枚举
 */
public enum MetricType {
    COUNTER,        // 计数器（单调递增）
    GAUGE,          // 仪表盘（可增可减）
    HISTOGRAM,      // 直方图（分布统计）
    SUMMARY,        // 摘要（百分位统计）
    TIMER           // 计时器（耗时统计）
}
```

---

#### 4.5.2 指标接口

```java
// common/src/main/java/io/github/springstudent/dekstop/common/monitor/Metric.java
package io.github.springstudent.dekstop.common.monitor;

/**
 * 指标统一接口
 */
public interface Metric {
    
    /**
     * 获取指标名称
     */
    String getName();
    
    /**
     * 获取指标类型
     */
    MetricType getType();
    
    /**
     * 获取指标标签（用于分组和过滤）
     */
    Map<String, String> getLabels();
    
    /**
     * 记录指标值
     */
    void record(double value);
    
    /**
     * 获取当前值
     */
    double getValue();
    
    /**
     * 重置指标
     */
    void reset();
}
```

---

#### 4.5.3 指标收集器

```java
// common/src/main/java/io/github/springstudent/dekstop/common/monitor/MetricCollector.java
package io.github.springstudent.dekstop.common.monitor;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 指标收集器
 * 
 * 职责：
 * 1. 注册和管理所有指标
 * 2. 提供便捷的指标创建方法
 * 3. 线程安全的指标访问
 */
public class MetricCollector {
    
    private static final MetricCollector INSTANCE = new MetricCollector();
    
    private final Map<String, Metric> metrics = new ConcurrentHashMap<>();
    
    private MetricCollector() {}
    
    public static MetricCollector getInstance() {
        return INSTANCE;
    }
    
    /**
     * 创建或获取计数器
     */
    public Counter counter(String name, Map<String, String> labels) {
        String key = buildKey(name, labels);
        return (Counter) metrics.computeIfAbsent(key, k -> new Counter(name, labels));
    }
    
    /**
     * 创建或获取仪表盘
     */
    public Gauge gauge(String name, Map<String, String> labels) {
        String key = buildKey(name, labels);
        return (Gauge) metrics.computeIfAbsent(key, k -> new Gauge(name, labels));
    }
    
    /**
     * 创建或获取直方图
     */
    public Histogram histogram(String name, double[] buckets, Map<String, String> labels) {
        String key = buildKey(name, labels);
        return (Histogram) metrics.computeIfAbsent(key, k -> new Histogram(name, buckets, labels));
    }
    
    /**
     * 创建或获取计时器
     */
    public Timer timer(String name, Map<String, String> labels) {
        String key = buildKey(name, labels);
        return (Timer) metrics.computeIfAbsent(key, k -> new Timer(name, labels));
    }
    
    /**
     * 获取所有指标
     */
    public Map<String, Metric> getAllMetrics() {
        return new ConcurrentHashMap<>(metrics);
    }
    
    /**
     * 清除所有指标
     */
    public void clear() {
        metrics.clear();
    }
    
    private String buildKey(String name, Map<String, String> labels) {
        return name + labels.toString();
    }
}
```

---

#### 4.5.4 具体指标实现

##### Counter（计数器）

```java
// common/src/main/java/io/github/springstudent/dekstop/common/monitor/Counter.java
package io.github.springstudent.dekstop.common.monitor;

import java.util.Map;
import java.util.concurrent.atomic.AtomicLong;

/**
 * 计数器指标
 * 
 * 特点：
 * - 单调递增
 * - 只能增加，不能减少
 * - 适用于累计统计（如总请求数、总错误数）
 */
public class Counter implements Metric {
    
    private final String name;
    private final Map<String, String> labels;
    private final AtomicLong value = new AtomicLong(0);
    
    public Counter(String name, Map<String, String> labels) {
        this.name = name;
        this.labels = labels;
    }
    
    @Override
    public String getName() {
        return name;
    }
    
    @Override
    public MetricType getType() {
        return MetricType.COUNTER;
    }
    
    @Override
    public Map<String, String> getLabels() {
        return labels;
    }
    
    /**
     * 增加1
     */
    public void increment() {
        value.incrementAndGet();
    }
    
    /**
     * 增加指定值
     */
    public void increment(long amount) {
        value.addAndGet(amount);
    }
    
    @Override
    public void record(double value) {
        this.value.addAndGet((long) value);
    }
    
    @Override
    public double getValue() {
        return value.get();
    }
    
    @Override
    public void reset() {
        value.set(0);
    }
}
```

---

##### Gauge（仪表盘）

```java
// common/src/main/java/io/github/springstudent/dekstop/common/monitor/Gauge.java
package io.github.springstudent.dekstop.common.monitor;

import java.util.Map;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.Supplier;

/**
 * 仪表盘指标
 * 
 * 特点：
 * - 可增可减
 * - 反映当前状态
 * - 适用于瞬时值（如当前连接数、CPU使用率）
 */
public class Gauge implements Metric {
    
    private final String name;
    private final Map<String, String> labels;
    private final AtomicReference<Double> value = new AtomicReference<>(0.0);
    private Supplier<Double> valueSupplier; // 可选的动态值提供者
    
    public Gauge(String name, Map<String, String> labels) {
        this.name = name;
        this.labels = labels;
    }
    
    @Override
    public String getName() {
        return name;
    }
    
    @Override
    public MetricType getType() {
        return MetricType.GAUGE;
    }
    
    @Override
    public Map<String, String> getLabels() {
        return labels;
    }
    
    /**
     * 设置值
     */
    public void set(double value) {
        this.value.set(value);
    }
    
    /**
     * 增加
     */
    public void increment(double amount) {
        this.value.updateAndGet(v -> v + amount);
    }
    
    /**
     * 减少
     */
    public void decrement(double amount) {
        this.value.updateAndGet(v -> v - amount);
    }
    
    /**
     * 设置动态值提供者（用于实时获取系统指标）
     */
    public void setValueSupplier(Supplier<Double> supplier) {
        this.valueSupplier = supplier;
    }
    
    @Override
    public void record(double value) {
        set(value);
    }
    
    @Override
    public double getValue() {
        if (valueSupplier != null) {
            return valueSupplier.get();
        }
        return value.get();
    }
    
    @Override
    public void reset() {
        value.set(0.0);
    }
}
```

---

##### Histogram（直方图）

```java
// common/src/main/java/io/github/springstudent/dekstop/common/monitor/Histogram.java
package io.github.springstudent.dekstop.common.monitor;

import java.util.Map;
import java.util.Arrays;
import java.util.concurrent.atomic.LongAdder;

/**
 * 直方图指标
 * 
 * 特点：
 * - 统计值分布
 * - 支持分桶统计
 * - 适用于延迟分布、响应时间分布
 */
public class Histogram implements Metric {
    
    private final String name;
    private final Map<String, String> labels;
    private final double[] buckets; // 桶边界
    private final LongAdder[] bucketCounts; // 每个桶的计数
    private final LongAdder sum = new LongAdder(); // 总和
    private final LongAdder count = new LongAdder(); // 总计数
    
    public Histogram(String name, double[] buckets, Map<String, String> labels) {
        this.name = name;
        this.labels = labels;
        this.buckets = Arrays.copyOf(buckets, buckets.length);
        Arrays.sort(this.buckets);
        this.bucketCounts = new LongAdder[buckets.length + 1];
        for (int i = 0; i < bucketCounts.length; i++) {
            bucketCounts[i] = new LongAdder();
        }
    }
    
    @Override
    public String getName() {
        return name;
    }
    
    @Override
    public MetricType getType() {
        return MetricType.HISTOGRAM;
    }
    
    @Override
    public Map<String, String> getLabels() {
        return labels;
    }
    
    /**
     * 观察一个值
     */
    public void observe(double value) {
        // 找到对应的桶
        int bucketIndex = 0;
        for (int i = 0; i < buckets.length; i++) {
            if (value <= buckets[i]) {
                bucketIndex = i;
                break;
            }
            bucketIndex = i + 1;
        }
        
        bucketCounts[bucketIndex].increment();
        sum.add((long) value);
        count.increment();
    }
    
    @Override
    public void record(double value) {
        observe(value);
    }
    
    /**
     * 获取某个桶的计数
     */
    public long getBucketCount(int bucketIndex) {
        return bucketCounts[bucketIndex].sum();
    }
    
    /**
     * 获取平均值
     */
    public double getAverage() {
        long c = count.sum();
        return c == 0 ? 0 : (double) sum.sum() / c;
    }
    
    @Override
    public double getValue() {
        return getAverage();
    }
    
    @Override
    public void reset() {
        for (LongAdder bucketCount : bucketCounts) {
            bucketCount.reset();
        }
        sum.reset();
        count.reset();
    }
}
```

---

##### Timer（计时器）

```java
// common/src/main/java/io/github/springstudent/dekstop/common/monitor/Timer.java
package io.github.springstudent.dekstop.common.monitor;

import java.util.Map;

/**
 * 计时器指标
 * 
 * 特点：
 * - 专门用于测量耗时
 * - 自动记录开始和结束时间
 * - 内部使用Histogram统计分布
 */
public class Timer implements Metric {
    
    private final String name;
    private final Map<String, String> labels;
    private final Histogram histogram;
    private ThreadLocal<Long> startTime = ThreadLocal.withInitial(() -> 0L);
    
    // 默认桶：1ms, 5ms, 10ms, 25ms, 50ms, 100ms, 250ms, 500ms, 1s, 2.5s, 5s, 10s
    private static final double[] DEFAULT_BUCKETS = {
        1, 5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000
    };
    
    public Timer(String name, Map<String, String> labels) {
        this(name, DEFAULT_BUCKETS, labels);
    }
    
    public Timer(String name, double[] buckets, Map<String, String> labels) {
        this.name = name;
        this.labels = labels;
        this.histogram = new Histogram(name + "_duration", buckets, labels);
    }
    
    @Override
    public String getName() {
        return name;
    }
    
    @Override
    public MetricType getType() {
        return MetricType.TIMER;
    }
    
    @Override
    public Map<String, String> getLabels() {
        return labels;
    }
    
    /**
     * 开始计时
     */
    public void start() {
        startTime.set(System.nanoTime());
    }
    
    /**
     * 停止计时并记录
     */
    public void stop() {
        long start = startTime.get();
        if (start > 0) {
            long durationNanos = System.nanoTime() - start;
            double durationMillis = durationNanos / 1_000_000.0;
            histogram.observe(durationMillis);
        }
    }
    
    /**
     * 记录耗时（手动指定）
     */
    public void recordDuration(double durationMillis) {
        histogram.observe(durationMillis);
    }
    
    @Override
    public void record(double value) {
        recordDuration(value);
    }
    
    @Override
    public double getValue() {
        return histogram.getAverage();
    }
    
    @Override
    public void reset() {
        histogram.reset();
    }
    
    /**
     * 获取平均耗时
     */
    public double getAverageDuration() {
        return histogram.getAverage();
    }
}
```

---

### 4.6 预定义指标体系

#### 4.6.1 Java被控端指标

```java
// client/src/main/java/io/github/springstudent/dekstop/client/monitor/ClientMetrics.java
public class ClientMetrics {
    
    private static final MetricCollector collector = MetricCollector.getInstance();
    
    // 屏幕捕获
    public static final Counter captureTotal = collector.counter(
        "screen_capture_total",
        Map.of("device", "primary")
    );
    
    public static final Timer captureDuration = collector.timer(
        "screen_capture_duration_ms",
        Map.of("device", "primary")
    );
    
    public static final Gauge captureFps = collector.gauge(
        "screen_capture_fps",
        Map.of("device", "primary")
    );
    
    // Tile处理
    public static final Counter tileTotal = collector.counter(
        "tile_processed_total",
        Map.of("type", "all")
    );
    
    public static final Counter tileDirty = collector.counter(
        "tile_dirty_total",
        Map.of("type", "dirty")
    );
    
    public static final Counter tileSkipped = collector.counter(
        "tile_skipped_total",
        Map.of("type", "skipped")
    );
    
    // 压缩
    public static final Timer compressDuration = collector.timer(
        "compression_duration_ms",
        Map.of("algorithm", "zstd")
    );
    
    public static final Gauge compressionRatio = collector.gauge(
        "compression_ratio",
        Map.of("algorithm", "zstd")
    );
    
    // 网络发送
    public static final Counter bytesSent = collector.counter(
        "network_bytes_sent_total",
        Map.of("protocol", "tcp")
    );
    
    public static final Timer sendDuration = collector.timer(
        "network_send_duration_ms",
        Map.of("protocol", "tcp")
    );
}
```

---

#### 4.6.2 HarmonyOS控制端指标

```typescript
// HarmonOS_remote_desktop_control_client/entry/src/main/ets/monitor/ClientMetrics.ets

import { MetricCollector } from '../common/monitor/MetricCollector';

const collector = MetricCollector.getInstance();

export class ControlMetrics {
  // 网络接收
  static readonly bytesReceived = collector.counter(
    'network_bytes_received_total',
    { protocol: 'tcp' }
  );
  
  static readonly receiveDuration = collector.timer(
    'network_receive_duration_ms',
    { protocol: 'tcp' }
  );
  
  // 协议解析
  static readonly parseDuration = collector.timer(
    'protocol_parse_duration_ms',
    { version: 'v1' }
  );
  
  // 解压缩
  static readonly decompressDuration = collector.timer(
    'decompression_duration_ms',
    { algorithm: 'zstd' }
  );
  
  static readonly decompressedSize = collector.gauge(
    'decompressed_size_bytes',
    { algorithm: 'zstd' }
  );
  
  // 图像组装
  static readonly assembleDuration = collector.timer(
    'image_assemble_duration_ms',
    { method: 'tile_based' }
  );
  
  // 渲染
  static readonly renderDuration = collector.timer(
    'render_duration_ms',
    { backend: 'pixelmap' }
  );
  
  // 端到端延迟
  static readonly endToEndDelay = collector.histogram(
    'end_to_end_delay_ms',
    [10, 20, 50, 100, 200, 500, 1000],
    {}
  );
  
  // 帧率
  static readonly fps = collector.gauge(
    'render_fps',
    {}
  );
  
  // 跳帧
  static readonly framesSkipped = collector.counter(
    'frames_skipped_total',
    { reason: 'backpressure' }
  );
  
  // 缓存
  static readonly cacheHitRate = collector.gauge(
    'tile_cache_hit_rate',
    {}
  );
}
```

---

#### 4.6.3 Java服务端指标

```java
// server/src/main/java/io/github/springstudent/dekstop/server/monitor/ServerMetrics.java
public class ServerMetrics {
    
    private static final MetricCollector collector = MetricCollector.getInstance();
    
    // 连接管理
    public static final Gauge activeConnections = collector.gauge(
        "active_connections",
        Map.of("type", "tcp")
    );
    
    public static final Counter connectionsTotal = collector.counter(
        "connections_total",
        Map.of("type", "tcp")
    );
    
    // 消息处理
    public static final Counter messagesReceived = collector.counter(
        "messages_received_total",
        Map.of("direction", "inbound")
    );
    
    public static final Counter messagesSent = collector.counter(
        "messages_sent_total",
        Map.of("direction", "outbound")
    );
    
    public static final Timer messageProcessingDuration = collector.timer(
        "message_processing_duration_ms",
        Map.of()
    );
    
    // 会话管理
    public static final Gauge activeSessions = collector.gauge(
        "active_sessions",
        Map.of()
    );
    
    public static final Timer sessionDuration = collector.timer(
        "session_duration_seconds",
        Map.of()
    );
    
    // 资源使用
    public static final Gauge cpuUsage = collector.gauge(
        "cpu_usage_percent",
        Map.of()
    );
    
    public static final Gauge memoryUsage = collector.gauge(
        "memory_usage_mb",
        Map.of()
    );
}
```

---

### 4.7 指标导出与可视化

#### 4.7.1 内存导出器（实时查询）

```java
// common/src/main/java/io/github/springstudent/dekstop/common/monitor/export/MemoryExporter.java
public class MemoryExporter implements MetricExporter {
    
    @Override
    public String export(Map<String, Metric> metrics) {
        StringBuilder sb = new StringBuilder();
        
        for (Map.Entry<String, Metric> entry : metrics.entrySet()) {
            Metric metric = entry.getValue();
            sb.append(metric.getName())
              .append("{")
              .append(formatLabels(metric.getLabels()))
              .append("} ")
              .append(metric.getValue())
              .append("\n");
        }
        
        return sb.toString();
    }
    
    private String formatLabels(Map<String, String> labels) {
        return labels.entrySet().stream()
            .map(e -> e.getKey() + "=\"" + e.getValue() + "\"")
            .collect(Collectors.joining(","));
    }
}
```

---

#### 4.7.2 文件导出器（历史数据）

```java
// common/src/main/java/io/github/springstudent/dekstop/common/monitor/export/FileExporter.java
public class FileExporter implements MetricExporter {
    
    private final String logDir;
    private final long rotationIntervalMs;
    
    public FileExporter(String logDir, long rotationIntervalMs) {
        this.logDir = logDir;
        this.rotationIntervalMs = rotationIntervalMs;
    }
    
    @Override
    public void export(Map<String, Metric> metrics) {
        String timestamp = LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME);
        String filename = String.format("metrics_%s.log", timestamp);
        Path filepath = Paths.get(logDir, filename);
        
        try (PrintWriter writer = new PrintWriter(Files.newBufferedWriter(filepath))) {
            writer.println("# Timestamp: " + timestamp);
            
            for (Map.Entry<String, Metric> entry : metrics.entrySet()) {
                Metric metric = entry.getValue();
                writer.printf("%s{%s} %.2f%n",
                    metric.getName(),
                    formatLabels(metric.getLabels()),
                    metric.getValue()
                );
            }
        } catch (IOException e) {
            Log.error("Failed to export metrics to file", e);
        }
    }
}
```

---

#### 4.7.3 HarmonyOS浮窗组件优化

```typescript
// HarmonOS_remote_desktop_control_client/entry/src/main/ets/components/PerformanceOverlay.ets

import { MetricCollector } from '../common/monitor/MetricCollector';
import { ControlMetrics } from '../monitor/ControlMetrics';

@Component
export struct PerformanceOverlay {
  @Consume showPerformanceOverlay: boolean;
  @State stats: string = '';
  
  private updateTimer: number | null = null;
  
  aboutToAppear(): void {
    // 每500ms更新一次
    this.updateTimer = setInterval(() => {
      this.updateStats();
    }, 500);
  }
  
  aboutToDisappear(): void {
    if (this.updateTimer) {
      clearInterval(this.updateTimer);
    }
  }
  
  private updateStats(): void {
    const collector = MetricCollector.getInstance();
    const metrics = collector.getAllMetrics();
    
    // 格式化显示
    let text = '性能监控\n';
    text += `FPS: ${ControlMetrics.fps.getValue().toFixed(1)}\n`;
    text += `延迟: ${ControlMetrics.endToEndDelay.getValue().toFixed(0)}ms\n`;
    text += `解压: ${ControlMetrics.decompressDuration.getValue().toFixed(1)}ms\n`;
    text += `渲染: ${ControlMetrics.renderDuration.getValue().toFixed(1)}ms\n`;
    text += `缓存命中率: ${ControlMetrics.cacheHitRate.getValue().toFixed(1)}%\n`;
    
    this.stats = text;
  }
  
  build() {
    Column() {
      Text(this.stats)
        .fontSize(11)
        .fontColor('#FFFFFF')
        .padding(8)
    }
    .backgroundColor('rgba(0, 0, 0, 0.7)')
    .borderRadius(8)
  }
}
```

---

### 4.8 告警机制

#### 4.8.1 告警规则定义

```java
// common/src/main/java/io/github/springstudent/dekstop/common/monitor/alert/AlertRule.java
public class AlertRule {
    
    private final String name;
    private final String metricName;
    private final AlertCondition condition;
    private final long evaluationIntervalMs;
    private final List<AlertHandler> handlers;
    
    public AlertRule(String name, String metricName, 
                     AlertCondition condition, 
                     long evaluationIntervalMs,
                     List<AlertHandler> handlers) {
        this.name = name;
        this.metricName = metricName;
        this.condition = condition;
        this.evaluationIntervalMs = evaluationIntervalMs;
        this.handlers = handlers;
    }
    
    public void evaluate(Metric metric) {
        if (condition.test(metric.getValue())) {
            fire(metric);
        }
    }
    
    private void fire(Metric metric) {
        AlertEvent event = new AlertEvent(
            this.name,
            this.metricName,
            metric.getValue(),
            System.currentTimeMillis()
        );
        
        for (AlertHandler handler : handlers) {
            handler.handle(event);
        }
    }
}
```

---

#### 4.8.2 预定义告警规则

```java
// client/src/main/java/io/github/springstudent/dekstop/client/monitor/ClientAlertRules.java
public class ClientAlertRules {
    
    public static final AlertRule LOW_FPS = new AlertRule(
        "low_fps",
        "screen_capture_fps",
        new ThresholdCondition(ThresholdType.LESS_THAN, 20),
        5000, // 每5秒检查一次
        List.of(new LogAlertHandler(), new ToastAlertHandler())
    );
    
    public static final AlertRule HIGH_LATENCY = new AlertRule(
        "high_latency",
        "end_to_end_delay_ms",
        new ThresholdCondition(ThresholdType.GREATER_THAN, 200),
        3000, // 每3秒检查一次
        List.of(new LogAlertHandler())
    );
    
    public static final AlertRule HIGH_SKIP_RATE = new AlertRule(
        "high_skip_rate",
        "frames_skipped_total",
        new RateCondition(10, TimeUnit.SECONDS), // 10秒内跳帧超过10次
        10000,
        List.of(new LogAlertHandler())
    );
}
```

---

## 🔄 迁移方案

### 4.9 逐步迁移策略

#### 阶段1：建立统一监控SDK（2周）

1. 在`common`模块中添加：
   - `MetricCollector`
   - `Metric`接口及实现（Counter, Gauge, Histogram, Timer）
   - `MetricExporter`接口
   - `AlertManager`

2. 编写单元测试

#### 阶段2：迁移Java被控端（1周）

1. 保留旧的`BigBrother`和`Counter`，标记为`@Deprecated`
2. 在新的`ClientMetrics`中定义指标
3. 在关键路径添加埋点：
   - `CaptureEngine.onCaptured()` → 记录captureDuration
   - `CompressorEngine.onCompressed()` → 记录compressDuration
   - `NetworkManager.send()` → 记录sendDuration

4. 逐步替换旧计数器

#### 阶段3：重构HarmonyOS控制端（2周）

1. 将`PerformanceMonitor`改造为使用新的`MetricCollector`
2. 在`RemoteControlService`中添加埋点：
   - `onRawVideoData()` → 记录receiveDuration
   - `decompress()` → 记录decompressDuration
   - `assemble()` → 记录assembleDuration
   - `render()` → 记录renderDuration

3. 优化`PerformanceOverlay`组件

#### 阶段4：实现服务端监控（1周）

1. 在`server`模块中添加`ServerMetrics`
2. 在Netty Handler中添加埋点：
   - `channelActive()` → activeConnections++
   - `channelInactive()` → activeConnections--
   - `channelRead()` → messagesReceived++, messageProcessingDuration

3. 添加JMX暴露指标（可选）

#### 阶段5：集成告警系统（1周）

1. 定义告警规则
2. 实现告警处理器（日志、Toast、邮件）
3. 启动告警评估器

#### 阶段6：测试与验证（1周）

1. 功能测试：确认所有指标正确采集
2. 性能测试：确认监控开销<1%
3. 压力测试：长时间运行无内存泄漏

---

## 📊 预期收益

### 4.10 改进效果

| 维度 | 优化前 | 优化后 | 提升幅度 |
|------|--------|--------|---------|
| **监控覆盖率** | 30% | 90% | **200% ↑** |
| **指标一致性** | 无 | 统一API | **100%** |
| **可视化能力** | 简单文本 | 浮窗+Dashboard | **丰富** |
| **告警能力** | 无 | 多级告警 | **从无到有** |
| **历史数据** | 无 | 文件存储 | **可回溯** |
| **跨端关联** | 不可能 | TraceID追踪 | **全链路** |
| **监控开销** | 未知 | <1% | **可控** |

---

## ⚠️ 风险与应对

### 风险1：监控开销过大

**现象**：埋点过多导致性能下降

**应对**：
1. 采样策略：高频指标采用采样（如10%采样率）
2. 异步导出：指标导出在后台线程执行
3. 性能预算：监控本身CPU占用<1%，内存占用<10MB

### 风险2：内存泄漏

**现象**：长时间运行后内存持续增长

**应对**：
1. 滑动窗口：所有数组设置上限（如最多保留1000个样本）
2. 定期清理：每小时清理一次过期数据
3. 监控监控：监控监控系统自身的内存占用

### 风险3：数据不一致

**现象**：三端指标定义不一致，无法对比

**应对**：
1. 统一命名规范：使用Prometheus命名约定
2. 代码审查：新增指标必须经过架构师审核
3. 自动化测试：验证指标格式和类型

---

## 📝 实施计划

| 阶段 | 任务 | 负责人 | 预计工时 | 截止日期 |
|------|------|--------|---------|---------|
| 阶段1 | 建立统一监控SDK | 架构师 | 10天 | 2026-05-20 |
| 阶段2 | 迁移Java被控端 | 后端开发 | 5天 | 2026-05-25 |
| 阶段3 | 重构HarmonyOS控制端 | 前端开发 | 10天 | 2026-06-04 |
| 阶段4 | 实现服务端监控 | 后端开发 | 5天 | 2026-06-09 |
| 阶段5 | 集成告警系统 | 全体开发 | 5天 | 2026-06-14 |
| 阶段6 | 测试与验证 | QA团队 | 5天 | 2026-06-19 |
| **总计** | | | **40天** | **2026-06-19** |

---

## 🎓 总结

当前项目的性能监控存在严重的分散性问题：

1. **监控分散**：3个端各自为政，没有统一框架
2. **数据孤岛**：无法进行端到端性能分析
3. **功能缺失**：缺少告警、历史数据、可视化等关键能力

通过建立统一的性能监控架构，我们可以：

1. ✅ **统一API**：三端使用相同的监控接口
2. ✅ **全链路追踪**：从采集到渲染的完整路径监控
3. ✅ **智能告警**：自动检测性能异常
4. ✅ **历史分析**：支持性能趋势分析和容量规划

这是一个**高优先级**的基础设施改进，建议在下一个迭代周期内完成实施。
