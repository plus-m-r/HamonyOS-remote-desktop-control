package io.github.springstudent.dekstop.client.compress;

import io.github.springstudent.dekstop.client.bean.Capture;
import io.github.springstudent.dekstop.client.bean.Listeners;
import io.github.springstudent.dekstop.client.concurrent.DefaultThreadFactoryEx;
import io.github.springstudent.dekstop.client.concurrent.Executable;
import io.github.springstudent.dekstop.client.error.FatalErrorHandler;
import io.github.springstudent.dekstop.client.squeeze.Compressor;
import io.github.springstudent.dekstop.client.squeeze.NullTileCache;
import io.github.springstudent.dekstop.client.squeeze.RegularTileCache;
import io.github.springstudent.dekstop.client.squeeze.TileCache;
import io.github.springstudent.dekstop.common.command.CmdCapture;
import io.github.springstudent.dekstop.common.configuration.CompressorEngineConfiguration;
import io.github.springstudent.dekstop.common.log.Log;

import java.io.IOException;
import java.util.concurrent.*;

/**
 * 解压引擎，负责处理压缩数据的解压任务调度
 * 采用单线程池处理解压任务，确保处理顺序
 */
public class DeCompressorEngine{
	// 监听器列表，用于通知解压完成事件
	private final Listeners<DeCompressorEngineListener> listeners = new Listeners<>();

	// 线程池，用于执行解压任务
	private ThreadPoolExecutor executor;

	// 信号量，用于控制解压任务的队列大小
	private Semaphore semaphore;

	// 瓦片缓存，用于存储和获取瓦片数据
	private TileCache cache;

	/**
	 * 构造函数
	 * @param listener 解压完成监听器
	 */
	public DeCompressorEngine(DeCompressorEngineListener listener) {
		listeners.add(listener);
	}

	/**
	 * 启动解压引擎
	 * @param queueSize 队列大小，用于控制并发解压任务数量
	 */
	public void start(int queueSize) {
		// 创建单线程池，确保解压任务按顺序处理
		// 并行处理在解压器内部进行，这里需要确保处理顺序
		executor = new ThreadPoolExecutor(1, 1, 0L, TimeUnit.MILLISECONDS, new LinkedBlockingQueue<>());

		// 设置线程工厂，为线程命名
		executor.setThreadFactory(new DefaultThreadFactoryEx("DeCompressorEngine"));

		// 创建信号量，用于控制队列大小
		// 当队列满时，网络接收线程会停止从辅助端读取数据
		// 这会减慢辅助端发送捕获数据的速度，给解压引擎时间赶上
		// 队列满的情况很少见，因为网络会限制发送的捕获/瓦片数量
		// 而且解压速度通常比压缩速度快（除非本地PC比辅助端弱很多）
		semaphore = new Semaphore(queueSize, true);
	}

	/**
	 * 处理捕获数据
	 * 注意：此方法不应阻塞，因为它是从网络接收线程调用的
	 * @param capture 捕获数据命令
	 */
	public void handleCapture(CmdCapture capture) {
		try {
			// 获取信号量，控制队列大小
			semaphore.acquire();
			// 提交解压任务到线程池
			executor.execute(new MyExecutable(executor, semaphore, capture));
		} catch (InterruptedException ex) {
			// 线程中断处理
			FatalErrorHandler.bye("The [" + Thread.currentThread().getName() + "] thread is has been interrupted!", ex);
			Thread.currentThread().interrupt();
		} catch (RejectedExecutionException ex) {
			// 任务被拒绝处理（由于使用无界队列，这种情况很少发生）
			semaphore.release();
		}
	}

	/**
	 * 内部可执行类，用于执行解压任务
	 */
	private class MyExecutable extends Executable {
		// 捕获数据命令
		private final CmdCapture message;

		/**
		 * 构造函数
		 * @param executor 线程池
		 * @param semaphore 信号量
		 * @param message 捕获数据命令
		 */
		MyExecutable(ExecutorService executor, Semaphore semaphore, CmdCapture message) {
			super(executor, semaphore);
			this.message = message;
		}

		/**
		 * 执行解压任务
		 * @throws IOException IO异常
		 */
		@Override
		protected void execute() throws IOException {
			try {
				// 获取对应压缩方法的解压器
				final Compressor compressor = Compressor.get(message.getCompressionMethod());

				// 处理压缩配置
				final CompressorEngineConfiguration configuration = message.getCompressionConfiguration();
				if (configuration != null) {
					// 根据配置创建瓦片缓存
					cache = configuration.useCache() ? 
							new RegularTileCache(configuration.getCacheMaxSize(), configuration.getCachePurgeSize())
							: new NullTileCache();

					Log.info("De-Compressor engine has been reconfigured [tile:" + message.getId() + "]" + configuration);
				}

				// 清除缓存命中计数
				cache.clearHits();

				// 执行解压操作
				final Capture capture = compressor.decompress(cache, message.getPayload());
				// 计算压缩比率
				final double ratio = capture
						.computeCompressionRatio(1/* magic-number */ + message.getWireSize());

				// 通知监听器解压完成
				fireOnDeCompressed(capture, cache.getHits(), ratio);
			} finally {
				// 处理缓存
				if (cache != null) {
					cache.onCaptureProcessed();
				}
			}
		}

		/**
		 * 通知监听器解压完成
		 * @param capture 解压后的捕获对象
		 * @param cacheHits 缓存命中次数
		 * @param compressionRatio 压缩比率
		 */
		private void fireOnDeCompressed(Capture capture, int cacheHits, double compressionRatio) {
			listeners.getListeners().forEach(listener -> listener.onDeCompressed(capture, cacheHits, compressionRatio));
		}
	}

}
