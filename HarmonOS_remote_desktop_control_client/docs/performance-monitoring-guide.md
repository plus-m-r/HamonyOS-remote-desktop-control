# 详细性能监控使用指南

## 快速开始

### 1. 启用性能监控

在您的应用中，确保RemoteControlService已初始化并启动性能监控：

```typescript
// RemoteControlService会自动启动性能监控
const service = new RemoteControlService(config, ...);

// 如果需要手动控制
service.getPerformanceMonitor().start();
```

### 2. 显示性能浮窗

在您的UI组件中（例如RemoteScreenView.ets）：

```typescript
@State showPerformanceOverlay: boolean = false;
@State performanceStats: PerformanceStats = {
  fps: 0,
  avgFps: 0,
  // ... 其他字段
};

// 在build方法中添加
if (this.showPerformanceOverlay) {
  PerformanceOverlay({
    stats: this.performanceStats,
    showPerformanceOverlay: $showPerformanceOverlay
  })
}

// 定期更新统计数据
private updatePerformanceStats(): void {
  const monitor = this.remoteControlService.getPerformanceMonitor();
  this.performanceStats = monitor.getStats();
}
```

### 3. 切换监控显示

添加一个按钮或手势来切换性能浮窗的显示：

```typescript
Button('性能监控')
  .onClick(() => {
    this.showPerformanceOverlay = !this.showPerformanceOverlay;
    if (this.showPerformanceOverlay) {
      this.remoteControlService.getPerformanceMonitor().start();
    } else {
      this.remoteControlService.getPerformanceMonitor().stop();
    }
  })
```

## 解读性能指标

### 核心指标

#### FPS (帧率)
- **优秀**: ≥25 FPS (绿色)
- **一般**: 15-25 FPS (橙色)
- **差**: <15 FPS (红色)

**优化建议**: 
- 检查解压缩和组装耗时
- 降低屏幕分辨率或帧率配置
- 优化网络带宽

#### Delay (帧延迟)
- **优秀**: ≤50ms (绿色)
- **一般**: 50-100ms (橙色)
- **差**: >100ms (红色)

**优化建议**:
- 检查端到端延迟的各个环节
- 优化网络传输
- 减少数据处理时间

#### EndToEnd (端到端延迟)
从数据接收到屏幕显示的总时间，包含所有处理环节。

**目标**: <100ms 为良好体验

### 各环节耗时

#### Network (网络接收)
数据包接收和处理的时间。

**正常范围**: 1-10ms

**如果过高**:
- 检查网络连接质量
- 检查数据包大小是否合理
- 考虑调整MTU大小

#### Parse (协议解析)
解析CmdCapture命令的时间。

**正常范围**: 1-5ms

**如果过高**:
- 检查协议解析逻辑
- 优化数据结构序列化

#### Decompress (解压缩)
ZSTD/ZIP/XZ解压缩的时间。

**正常范围**: 5-30ms

**如果过高**:
- 检查压缩算法选择
- 调整Tile大小
- 考虑降低压缩级别
- 检查是否启用了缓存

#### Assemble (图像组装)
将tiles组装成完整图像的时间。

**正常范围**: 5-20ms

**如果过高**:
- 提高Buffer复用率
- 优化drawToBuffer算法
- 减少内存拷贝操作

#### Render (渲染)
UI渲染和PixelMap创建的时间。

**正常范围**: 5-15ms

**如果过高**:
- 检查PixelMap创建效率
- 优化UI组件
- 启用硬件加速

### 缓存统计

#### Cache Hit (缓存命中率)
CaptureCache的命中百分比。

**优秀**: ≥90% (绿色)
**一般**: 70-90% (橙色)
**差**: <70% (红色)

**如果过低**:
- 检查帧合并逻辑
- 优化pending队列处理
- 检查网络抖动导致的乱序

#### Buffer Reuse (Buffer复用率)
缓冲区复用的百分比，高复用率可以减少内存分配。

**目标**: ≥70%

**如果过低**:
- 检查分辨率变化频率
- 优化Buffer池管理
- 避免频繁的尺寸变化

#### Pending (待处理队列)
当前等待处理的帧数量。

**正常范围**: 0-3

**如果过高**:
- 处理能力不足
- 网络突发导致积压
- 需要优化处理速度或增加丢弃策略

### 网络统计

#### Packet Size (数据包大小)
平均接收的数据包大小。

**典型范围**: 5KB-50KB (取决于压缩率和屏幕内容)

**如果过大**:
- 检查压缩配置
- 考虑降低画质
- 调整Tile大小

#### Queue Wait (队列等待)
数据在队列中等待的平均时间。

**正常范围**: 0-5ms

**如果过高**:
- 处理能力瓶颈
- 需要优化处理速度
- 考虑增加并发处理

## 性能分析案例

### 案例1: 高延迟问题

**现象**: EndToEnd延迟高达200ms

**分析步骤**:
1. 查看各环节耗时分布
2. 发现Decompress耗时80ms
3. 检查压缩配置，发现使用了最高压缩级别

**解决方案**:
- 降低压缩级别从9到6
- Decompress降至25ms
- EndToEnd降至120ms

### 案例2: 低FPS问题

**现象**: FPS只有12

**分析步骤**:
1. 检查Assemble耗时45ms（红色）
2. Buffer复用率只有30%
3. 频繁的全屏刷新导致无法复用Buffer

**解决方案**:
- 优化屏幕变化检测
- 提高增量帧比例
- Buffer复用率提升至75%
- FPS提升至22

### 案例3: 跳帧率高

**现象**: Skip rate达到15%

**分析步骤**:
1. Pending队列经常达到10+
2. 处理能力跟不上接收速度
3. 网络质量好但处理慢

**解决方案**:
- 优化Decompress和Assemble性能
- 调整队列大小限制
- 实现智能丢帧策略
- Skip rate降至3%

## 调试技巧

### 1. 日志分析

查看详细日志输出：
```
Pipeline - Network: 5ms | Parse: 3ms | Decompress: 15ms | Assemble: 10ms | Render: 8ms | EndToEnd: 45ms
```

找出耗时最长的环节进行优化。

### 2. 颜色提示

- **红色**: 立即需要优化
- **橙色**: 可以改进
- **绿色**: 性能良好

### 3. 趋势观察

关注avg值和当前值的差异：
- 如果当前值远高于avg，可能是瞬时波动
- 如果持续高于avg，说明存在系统性问题

### 4. 对比测试

在不同条件下测试：
- 不同网络环境（WiFi vs 4G）
- 不同屏幕内容（静态 vs 动态）
- 不同压缩配置
- 不同分辨率

## 常见问题

### Q1: 为什么浮窗不显示？

**A**: 检查以下几点：
1. 确认`showPerformanceOverlay`设置为true
2. 确认PerformanceMonitor已启动
3. 检查是否有其他UI元素遮挡

### Q2: 性能指标都是0？

**A**: 
1. 确认已开始远程屏幕共享
2. 确认有数据流传输
3. 检查PerformanceMonitor是否正确初始化

### Q3: 如何导出性能数据？

**A**: 目前支持：
1. 查看hilog日志输出
2. 手动记录PerformanceStats对象
3. 未来可扩展为CSV导出功能

### Q4: 监控会影响性能吗？

**A**: 
- 影响非常小（<1%）
- 仅记录时间戳和简单计算
- 滑动窗口限制内存使用
- 生产环境可以放心使用

## 最佳实践

1. **开发阶段**: 始终开启性能监控，及时发现性能问题
2. **测试阶段**: 记录不同场景的性能数据，建立基线
3. **生产环境**: 可选择性开启，用于问题诊断
4. **优化迭代**: 每次优化后对比性能指标，验证效果
5. **团队协作**: 分享性能报告，统一优化目标

## 下一步

1. 阅读[详细性能监控方案](./performance-monitoring-detailed.md)了解技术细节
2. 根据实际使用情况调整监控参数
3. 提出改进建议和新功能需求
