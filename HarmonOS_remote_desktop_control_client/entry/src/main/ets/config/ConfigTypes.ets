/**
 * 配置中心类型定义
 * 
 * 集中管理所有配置项的类型定义，确保类型安全
 */

/**
 * 服务器配置
 */
export interface ServerConfig {
  /** 服务器主机地址 */
  host: string;
  /** TCP 端口 */
  tcpPort: number;
  /** HTTP 端口 */
  httpPort: number;
  /** API 上下文路径 */
  contextPath: string;
}

/**
 * TCP 地址配置
 */
export interface TcpAddress {
  host: string;
  port: number;
}

/**
 * 网络配置
 */
export interface NetworkConfig {
  /** 连接超时时间（毫秒） */
  connectTimeout: number;
  /** 读取超时时间（毫秒） */
  readTimeout: number;
  /** 写入超时时间（毫秒） */
  writeTimeout: number;
  /** 最大重连次数 */
  maxReconnectAttempts: number;
  /** 重连间隔（毫秒） */
  reconnectInterval: number;
  /** 心跳间隔（毫秒） */
  heartbeatInterval: number;
  /** 心跳超时时间（毫秒） */
  heartbeatTimeout: number;
}

/**
 * 屏幕捕获配置
 */
export interface CaptureConfig {
  /** 最大帧率 */
  maxFps: number;
  /** 图像质量 (1-100) */
  quality: number;
  /** 压缩方法 */
  compressionMethod: 'none' | 'zip' | 'xz' | 'zstd';
  /** 压缩级别 */
  compressionLevel: number;
  /** 瓦片大小 */
  tileSize: number;
  /** 是否启用灰度模式 */
  grayscale: boolean;
}

/**
 * Capture缓存配置
 */
export interface CaptureCacheConfig {
  /** Capture对象缓存最大数量 */
  maxSize: number;
  /** Capture对象缓存每次清理数量 */
  purgeSize: number;
  /** PixelMap队列最大长度 */
  queueMaxSize: number;
  /** 队列基础预算（MB） */
  baseBudgetMB: number;
  /** 队列最小预算（MB） */
  minBudgetMB: number;
  /** 队列最大预算（MB） */
  maxBudgetMB: number;
  /** 每百万像素增加的预算（MB） */
  perMegapixelBudgetMB: number;
  /** 高刷新率设备附加预算（MB） */
  highRefreshExtraMB: number;
  /** 高密度屏幕附加预算（MB） */
  highDensityExtraMB: number;
  /** 高水位比例（0-1） */
  highWatermarkRatio: number;
  /** 低水位比例（0-1） */
  lowWatermarkRatio: number;
  /** 压力触发比例（0-1） */
  pressureStartRatio: number;
  /** 压力下低价值帧判定的脏瓦片比例阈值（0-1） */
  pressureDropDirtyTileRatio: number;
}

/**
 * 文件传输配置
 */
export interface FileTransferConfig {
  /** 分片大小（字节） */
  chunkSize: number;
  /** 最大并发上传数 */
  maxConcurrentUploads: number;
  /** 最大文件大小（字节） */
  maxFileSize: number;
  /** 是否启用秒传 */
  enableQuickUpload: boolean;
  /** 上传超时时间（毫秒） */
  uploadTimeout: number;
  /** 下载超时时间（毫秒） */
  downloadTimeout: number;
}

/**
 * 剪贴板配置
 */
export interface ClipboardConfig {
  /** 最大文本长度 */
  maxTextLength: number;
  /** 最大文件数量 */
  maxFileCount: number;
  /** 同步间隔（毫秒） */
  syncInterval: number;
  /** 是否启用自动同步 */
  autoSync: boolean;
}

/**
 * UI 配置
 */
export interface UIConfig {
  /** 默认语言 */
  defaultLanguage: string;
  /** 主题模式 */
  theme: 'light' | 'dark' | 'auto';
  /** 是否显示工具栏 */
  showToolbar: boolean;
  /** 工具栏自动隐藏时间（毫秒） */
  toolbarAutoHideDelay: number;
  /** 缩放级别 */
  defaultScale: number;
  /** 最小缩放级别 */
  minScale: number;
  /** 最大缩放级别 */
  maxScale: number;
}

/**
 * 日志配置
 */
export interface LogConfig {
  /** 日志级别 */
  level: 'debug' | 'info' | 'warn' | 'error';
  /** 是否启用控制台输出 */
  enableConsole: boolean;
  /** 是否启用文件日志 */
  enableFile: boolean;
  /** 日志文件最大大小（MB） */
  maxFileSize: number;
  /** 日志文件保留天数 */
  maxFileDays: number;
}


/**
 * 应用配置（所有配置的集合）
 */
export interface AppConfig {
  /** 服务器配置 */
  server: ServerConfig;
  /** 网络配置 */
  network: NetworkConfig;
  /** 屏幕捕获配置 */
  capture: CaptureConfig;
  /** Capture缓存配置 */
  captureCache: CaptureCacheConfig;
  /** 文件传输配置 */
  fileTransfer: FileTransferConfig;
  /** 剪贴板配置 */
  clipboard: ClipboardConfig;
  /** UI 配置 */
  ui: UIConfig;
  /** 日志配置 */
  log: LogConfig;
}

/**
 * 环境类型
 */
export type EnvironmentType = 'development' | 'testing' | 'staging' | 'production' | 'emulator';

/**
 * 配置变更监听器
 */
export type ConfigChangeListener<T> = (newValue: T, oldValue: T, path: string) => void;
/**
 * 通用对象接口（用于配置合并）
 * 注意：ArkTS不支持索引签名，改用具体类型
 */
export interface GenericObject {
  // 使用具体属性替代索引签名
  // 在ConfigCenter中需要调整相关逻辑
}

/**
 * 配置路径（用于类型安全的配置访问）
 */
export type ConfigPath = 
  | 'server'
  | 'server.host'
  | 'server.tcpPort'
  | 'server.httpPort'
  | 'server.contextPath'
  | 'network'
  | 'network.connectTimeout'
  | 'network.readTimeout'
  | 'network.writeTimeout'
  | 'network.maxReconnectAttempts'
  | 'network.reconnectInterval'
  | 'network.heartbeatInterval'
  | 'network.heartbeatTimeout'
  | 'capture'
  | 'capture.maxFps'
  | 'capture.quality'
  | 'capture.compressionMethod'
  | 'capture.compressionLevel'
  | 'capture.tileSize'
  | 'capture.grayscale'
  | 'captureCache'
  | 'captureCache.maxSize'
  | 'captureCache.purgeSize'
  | 'captureCache.queueMaxSize'
  | 'captureCache.baseBudgetMB'
  | 'captureCache.minBudgetMB'
  | 'captureCache.maxBudgetMB'
  | 'captureCache.perMegapixelBudgetMB'
  | 'captureCache.highRefreshExtraMB'
  | 'captureCache.highDensityExtraMB'
  | 'captureCache.highWatermarkRatio'
  | 'captureCache.lowWatermarkRatio'
  | 'captureCache.pressureStartRatio'
  | 'captureCache.pressureDropDirtyTileRatio'
  | 'fileTransfer'
  | 'fileTransfer.chunkSize'
  | 'fileTransfer.maxConcurrentUploads'
  | 'fileTransfer.maxFileSize'
  | 'fileTransfer.enableQuickUpload'
  | 'fileTransfer.uploadTimeout'
  | 'fileTransfer.downloadTimeout'
  | 'clipboard'
  | 'clipboard.maxTextLength'
  | 'clipboard.maxFileCount'
  | 'clipboard.syncInterval'
  | 'clipboard.autoSync'
  | 'ui'
  | 'ui.defaultLanguage'
  | 'ui.theme'
  | 'ui.showToolbar'
  | 'ui.toolbarAutoHideDelay'
  | 'ui.defaultScale'
  | 'ui.minScale'
  | 'ui.maxScale'
  | 'log'
  | 'log.level'
  | 'log.enableConsole'
  | 'log.enableFile'
  | 'log.maxFileSize'
  | 'log.maxFileDays'
  | 'worker'
  | 'worker.captureWorkerCount'
  | 'worker.protocolWorkerCount'
  | 'worker.maxTaskQueueSize'
  | 'worker.workerTimeout';
