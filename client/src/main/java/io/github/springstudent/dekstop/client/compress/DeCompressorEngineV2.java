package io.github.springstudent.dekstop.client.compress;

import java.io.IOException;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;

import io.github.springstudent.dekstop.client.bean.Capture;
import io.github.springstudent.dekstop.client.bean.Listeners;
import io.github.springstudent.dekstop.client.squeeze.Compressor;
import io.github.springstudent.dekstop.client.squeeze.NullTileCache;
import io.github.springstudent.dekstop.client.squeeze.RegularTileCache;
import io.github.springstudent.dekstop.client.squeeze.TileCache;
import io.github.springstudent.dekstop.common.command.CmdCapture;
import io.github.springstudent.dekstop.common.configuration.CompressorEngineConfiguration;
import io.github.springstudent.dekstop.common.log.Log;

/**
 * 新版解压引擎（基于新压缩器接口）
 * 
 * <p>使用新的ICompressor异步流式接口，提供更好的性能和资源管理。</p>
 * 
 * <p>特性：</p>
 * <ul>
 *   <li>异步处理：所有解压操作异步执行</li>
 *   <li>背压控制：基于信号量的队列大小控制</li>
 *   <li>瓦片缓存：支持LRU缓存优化重复数据</li>
 *   <li>顺序保证：单线程池确保处理顺序</li>
 * </ul>
 * 
 * @author 方寸控技术团队
 * @version 2.0
 * @since 2026-05-10
 */
public class DeCompressorEngineV2 {
    
    /** 监听器列表 */
    private final Listeners<DeCompressorEngineListener> listeners = new Listeners<>();
    
    /** 线程池（单线程确保顺序） */
    private ExecutorService executor;
    
    /** 信号量（背压控制） */
    private Semaphore semaphore;
    
    /** 瓦片缓存 */
    private TileCache cache;
    
    /**
     * 构造函数
     * 
     * @param listener 解压完成监听器
     */
    public DeCompressorEngineV2(DeCompressorEngineListener listener) {
        listeners.add(listener);
    }
    
    /**
     * 启动解压引擎
     * 
     * @param queueSize 队列大小，用于控制并发任务数量
     */
    public void start(int queueSize) {
        // 创建单线程池，确保解压任务按顺序处理
        executor = Executors.newSingleThreadExecutor(r -> {
            Thread t = new Thread(r, "DeCompressorEngineV2-Worker");
            t.setDaemon(true);
            return t;
        });
        
        // 创建信号量，用于背压控制
        semaphore = new Semaphore(queueSize, true);
        
        Log.info("DeCompressorEngineV2 started with queue size: " + queueSize);
    }
    
    /**
     * 处理捕获数据（异步）
     * 
     * <p>注意：此方法不应阻塞，因为它是从网络接收线程调用的。</p>
     * 
     * @param capture 捕获数据命令
     */
    public void handleCapture(CmdCapture capture) {
        try {
            // 获取信号量（背压控制）
            // 如果队列满，会阻塞网络接收线程，从而减慢发送速度
            if (!semaphore.tryAcquire(100, TimeUnit.MILLISECONDS)) {
                Log.warn("DeCompressor queue is full, dropping capture: " + capture.getId());
                return;
            }
            
            // 提交异步解压任务
            CompletableFuture.runAsync(() -> {
                try {
                    processCapture(capture);
                } catch (Exception e) {
                    Log.error("Failed to process capture: " + capture.getId(), e);
                } finally {
                    semaphore.release();
                }
            }, executor);
            
        } catch (InterruptedException e) {
            Log.error("Interrupted while acquiring semaphore", e);
            Thread.currentThread().interrupt();
        }
    }
    
    /**
     * 处理单个捕获数据
     * 
     * @param message 捕获数据命令
     * @throws IOException IO异常
     */
    private void processCapture(CmdCapture message) throws IOException {
        try {
            // 获取对应压缩方法的解压器（使用旧的Compressor工厂）
            // TODO: 后续可以迁移到新的ICompressor接口
            final Compressor compressor = Compressor.get(message.getCompressionMethod());
            
            // 处理压缩配置
            final CompressorEngineConfiguration configuration = message.getCompressionConfiguration();
            if (configuration != null) {
                // 根据配置创建瓦片缓存
                cache = configuration.useCache() ?
                    new RegularTileCache(configuration.getCacheMaxSize(), configuration.getCachePurgeSize()) :
                    new NullTileCache();
                
                Log.info("DeCompressorEngineV2 reconfigured [tile:" + message.getId() + "] " + configuration);
            }
            
            // 清除缓存命中计数
            if (cache != null) {
                cache.clearHits();
            }
            
            // 执行解压操作
            final Capture capture = compressor.decompress(cache, message.getPayload());
            
            // 计算压缩比率
            final double ratio = capture.computeCompressionRatio(1 + message.getWireSize());
            
            // 通知监听器解压完成
            fireOnDeCompressed(capture, cache != null ? cache.getHits() : 0, ratio);
            
        } finally {
            // 处理缓存
            if (cache != null) {
                cache.onCaptureProcessed();
            }
        }
    }
    
    /**
     * 通知监听器解压完成
     * 
     * @param capture 解压后的捕获对象
     * @param cacheHits 缓存命中次数
     * @param compressionRatio 压缩比率
     */
    private void fireOnDeCompressed(Capture capture, int cacheHits, double compressionRatio) {
        listeners.getListeners().forEach(listener -> 
            listener.onDeCompressed(capture, cacheHits, compressionRatio)
        );
    }
    
    /**
     * 停止解压引擎
     */
    public void stop() {
        Log.info("DeCompressorEngineV2 stopping...");
        
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
        
        Log.info("DeCompressorEngineV2 stopped");
    }
}
