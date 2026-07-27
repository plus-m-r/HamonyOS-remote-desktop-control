/**
 * 配置中心
 * 
 * 集中管理应用的所有配置，提供类型安全、默认值、配置验证、变更监听等功能
 * 采用单例模式，确保全局配置一致性
 */

import { 
  AppConfig, 
  ServerConfig, 
  NetworkConfig, 
  CaptureConfig, 
  CaptureCacheConfig,
  FileTransferConfig,
  ClipboardConfig,
  UIConfig,
  LogConfig,
  EnvironmentType,
  TcpAddress
} from './ConfigTypes';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001;
const TAG = 'ConfigCenter';

export interface CaptureCacheRuntimeConfig {
  maxSize: number;
  purgeSize: number;
  queueMaxSize: number;
  queueMaxBytes: number;
  queueLowWatermarkBytes: number;
  queueHighWatermarkBytes: number;
  pressureStartRatio: number;
  pressureDropDirtyTileRatio: number;
}

/**
 * 默认配置
 */
const DEFAULT_CONFIG: AppConfig = {
  server: {
    host: '10.19.91.247',
    tcpPort: 54321,
    httpPort: 12345,
    contextPath: '/remote-desktop-control'
  },
  network: {
    connectTimeout: 10000,
    readTimeout: 30000,
    writeTimeout: 30000,
    maxReconnectAttempts: 3,
    reconnectInterval: 2000,
    heartbeatInterval: 3000,
    heartbeatTimeout: 10000
  },
  capture: {
    maxFps: 10,           // 降低帧率，给服务器更多时间发送所有tile
    quality: 75,
    compressionMethod: 'zstd',
    compressionLevel: 1,
    tileSize: 64,         // 与Java端保持一致（从32改为64）
    grayscale: false
  },
  captureCache: {
    maxSize: 30,
    purgeSize: 15,
    queueMaxSize: 1,
    baseBudgetMB: 32,
    minBudgetMB: 24,
    maxBudgetMB: 96,
    perMegapixelBudgetMB: 8,
    highRefreshExtraMB: 8,
    highDensityExtraMB: 4,
    highWatermarkRatio: 0.85,
    lowWatermarkRatio: 0.5,
    pressureStartRatio: 0.8,
    pressureDropDirtyTileRatio: 0.15
  },
  fileTransfer: {
    chunkSize: 1048576,
    maxConcurrentUploads: 3,
    maxFileSize: 1073741824,
    enableQuickUpload: true,
    uploadTimeout: 300000,
    downloadTimeout: 300000
  },
  clipboard: {
    maxTextLength: 10000,
    maxFileCount: 10,
    syncInterval: 1000,
    autoSync: true
  },
  ui: {
    defaultLanguage: 'zh-CN',
    theme: 'auto',
    showToolbar: true,
    toolbarAutoHideDelay: 3000,
    defaultScale: 1.0,
    minScale: 0.5,
    maxScale: 3.0
  },
  log: {
    level: 'info',
    enableConsole: true,
    enableFile: false,
    maxFileSize: 10,
    maxFileDays: 7
  }
};

/**
 * 环境特定配置
 */
interface EnvironmentConfigs {
  development: Partial<AppConfig>;
  testing: Partial<AppConfig>;
  staging: Partial<AppConfig>;
  production: Partial<AppConfig>;
  emulator: Partial<AppConfig>;
}

const ENVIRONMENT_CONFIGS: EnvironmentConfigs = {
  development: {
    server: {
      host: '10.19.91.247',
      tcpPort: 54321,
      httpPort: 12345,
      contextPath: '/remote-desktop-control'
    },
    log: {
      level: 'debug',
      enableConsole: true,
      enableFile: true,
      maxFileSize: 10,
      maxFileDays: 7
    }
  },
  testing: {
    server: {
      host: '10.19.91.247',
      tcpPort: 54321,
      httpPort: 12345,
      contextPath: '/remote-desktop-control'
    },
    log: {
      level: 'debug',
      enableConsole: true,
      enableFile: false,
      maxFileSize: 10,
      maxFileDays: 7
    }
  },
  staging: {
    log: {
      level: 'info',
      enableConsole: true,
      enableFile: true,
      maxFileSize: 50,
      maxFileDays: 30
    }
  },
  production: {
    server: {
      host: '10.19.91.247',
      tcpPort: 54321,
      httpPort: 12345,
      contextPath: '/remote-desktop-control'
    },
    log: {
      level: 'warn',
      enableConsole: false,
      enableFile: true,
      maxFileSize: 100,
      maxFileDays: 30
    }
  },
  emulator: {
    server: {
      host: '10.19.91.247',
      tcpPort: 54321,
      httpPort: 12345,
      contextPath: '/remote-desktop-control'
    },
    capture: {
      maxFps: 15,
      quality: 60,
      compressionMethod: 'zip',
      compressionLevel: 1,
      tileSize: 64,
      grayscale: false
    },
    captureCache: {
      maxSize: 30,
      purgeSize: 15,
      queueMaxSize: 2,
      baseBudgetMB: 20,
      minBudgetMB: 16,
      maxBudgetMB: 48,
      perMegapixelBudgetMB: 6,
      highRefreshExtraMB: 4,
      highDensityExtraMB: 2,
      highWatermarkRatio: 0.85,
      lowWatermarkRatio: 0.5,
      pressureStartRatio: 0.75,
      pressureDropDirtyTileRatio: 0.2
    },
    log: {
      level: 'debug',
      enableConsole: true,
      enableFile: false,
      maxFileSize: 10,
      maxFileDays: 7
    }
  }
};

/**
 * 配置中心类
 */
export class ConfigCenter {
  private static instance: ConfigCenter | null = null;
  private config: AppConfig;
  private currentEnvironment: EnvironmentType = 'production';

  static getInstance(): ConfigCenter {
    if (!ConfigCenter.instance) {
      ConfigCenter.instance = new ConfigCenter();
    }
    return ConfigCenter.instance;
  }

  private constructor() {
    this.config = JSON.parse(JSON.stringify(DEFAULT_CONFIG));
    this.detectEnvironment();
    hilog.info(DOMAIN, TAG, 'Initialized');
  }

  private detectEnvironment(): void {
    this.currentEnvironment = 'production';
    this.applyEnvironmentConfig();
    hilog.info(DOMAIN, TAG, 'Environment detected as %{public}s', this.currentEnvironment);
  }

  private applyEnvironmentConfig(): void {
    let envConfig: Partial<AppConfig>;
    if (this.currentEnvironment === 'development') {
      envConfig = ENVIRONMENT_CONFIGS.development;
    } else if (this.currentEnvironment === 'testing') {
      envConfig = ENVIRONMENT_CONFIGS.testing;
    } else if (this.currentEnvironment === 'staging') {
      envConfig = ENVIRONMENT_CONFIGS.staging;
    } else if (this.currentEnvironment === 'production') {
      envConfig = ENVIRONMENT_CONFIGS.production;
    } else {
      envConfig = ENVIRONMENT_CONFIGS.emulator;
    }
    this.config = this.mergeConfig(this.config, envConfig);
    hilog.info(DOMAIN, TAG, 'Applied %{public}s environment config', this.currentEnvironment);
  }

  private mergeConfig(target: AppConfig, source: Partial<AppConfig>): AppConfig {
    const result: AppConfig = JSON.parse(JSON.stringify(target));
    
    if (source.server) {
      if (source.server.host !== undefined) {
        result.server.host = source.server.host;
      }
      if (source.server.tcpPort !== undefined) {
        result.server.tcpPort = source.server.tcpPort;
      }
      if (source.server.httpPort !== undefined) {
        result.server.httpPort = source.server.httpPort;
      }
      if (source.server.contextPath !== undefined) {
        result.server.contextPath = source.server.contextPath;
      }
    }
    
    if (source.network) {
      if (source.network.connectTimeout !== undefined) {
        result.network.connectTimeout = source.network.connectTimeout;
      }
      if (source.network.readTimeout !== undefined) {
        result.network.readTimeout = source.network.readTimeout;
      }
      if (source.network.writeTimeout !== undefined) {
        result.network.writeTimeout = source.network.writeTimeout;
      }
      if (source.network.maxReconnectAttempts !== undefined) {
        result.network.maxReconnectAttempts = source.network.maxReconnectAttempts;
      }
      if (source.network.reconnectInterval !== undefined) {
        result.network.reconnectInterval = source.network.reconnectInterval;
      }
      if (source.network.heartbeatInterval !== undefined) {
        result.network.heartbeatInterval = source.network.heartbeatInterval;
      }
      if (source.network.heartbeatTimeout !== undefined) {
        result.network.heartbeatTimeout = source.network.heartbeatTimeout;
      }
    }
    
    if (source.capture) {
      if (source.capture.maxFps !== undefined) {
        result.capture.maxFps = source.capture.maxFps;
      }
      if (source.capture.quality !== undefined) {
        result.capture.quality = source.capture.quality;
      }
      if (source.capture.compressionMethod !== undefined) {
        result.capture.compressionMethod = source.capture.compressionMethod;
      }
      if (source.capture.compressionLevel !== undefined) {
        result.capture.compressionLevel = source.capture.compressionLevel;
      }
      if (source.capture.tileSize !== undefined) {
        result.capture.tileSize = source.capture.tileSize;
      }
      if (source.capture.grayscale !== undefined) {
        result.capture.grayscale = source.capture.grayscale;
      }
    }

    if (source.captureCache) {
      if (source.captureCache.maxSize !== undefined) {
        result.captureCache.maxSize = source.captureCache.maxSize;
      }
      if (source.captureCache.purgeSize !== undefined) {
        result.captureCache.purgeSize = source.captureCache.purgeSize;
      }
      if (source.captureCache.queueMaxSize !== undefined) {
        result.captureCache.queueMaxSize = source.captureCache.queueMaxSize;
      }
      if (source.captureCache.baseBudgetMB !== undefined) {
        result.captureCache.baseBudgetMB = source.captureCache.baseBudgetMB;
      }
      if (source.captureCache.minBudgetMB !== undefined) {
        result.captureCache.minBudgetMB = source.captureCache.minBudgetMB;
      }
      if (source.captureCache.maxBudgetMB !== undefined) {
        result.captureCache.maxBudgetMB = source.captureCache.maxBudgetMB;
      }
      if (source.captureCache.perMegapixelBudgetMB !== undefined) {
        result.captureCache.perMegapixelBudgetMB = source.captureCache.perMegapixelBudgetMB;
      }
      if (source.captureCache.highRefreshExtraMB !== undefined) {
        result.captureCache.highRefreshExtraMB = source.captureCache.highRefreshExtraMB;
      }
      if (source.captureCache.highDensityExtraMB !== undefined) {
        result.captureCache.highDensityExtraMB = source.captureCache.highDensityExtraMB;
      }
      if (source.captureCache.highWatermarkRatio !== undefined) {
        result.captureCache.highWatermarkRatio = source.captureCache.highWatermarkRatio;
      }
      if (source.captureCache.lowWatermarkRatio !== undefined) {
        result.captureCache.lowWatermarkRatio = source.captureCache.lowWatermarkRatio;
      }
      if (source.captureCache.pressureStartRatio !== undefined) {
        result.captureCache.pressureStartRatio = source.captureCache.pressureStartRatio;
      }
      if (source.captureCache.pressureDropDirtyTileRatio !== undefined) {
        result.captureCache.pressureDropDirtyTileRatio = source.captureCache.pressureDropDirtyTileRatio;
      }
    }
    
    if (source.fileTransfer) {
      if (source.fileTransfer.chunkSize !== undefined) {
        result.fileTransfer.chunkSize = source.fileTransfer.chunkSize;
      }
      if (source.fileTransfer.maxConcurrentUploads !== undefined) {
        result.fileTransfer.maxConcurrentUploads = source.fileTransfer.maxConcurrentUploads;
      }
      if (source.fileTransfer.maxFileSize !== undefined) {
        result.fileTransfer.maxFileSize = source.fileTransfer.maxFileSize;
      }
      if (source.fileTransfer.enableQuickUpload !== undefined) {
        result.fileTransfer.enableQuickUpload = source.fileTransfer.enableQuickUpload;
      }
      if (source.fileTransfer.uploadTimeout !== undefined) {
        result.fileTransfer.uploadTimeout = source.fileTransfer.uploadTimeout;
      }
      if (source.fileTransfer.downloadTimeout !== undefined) {
        result.fileTransfer.downloadTimeout = source.fileTransfer.downloadTimeout;
      }
    }
    
    if (source.clipboard) {
      if (source.clipboard.maxTextLength !== undefined) {
        result.clipboard.maxTextLength = source.clipboard.maxTextLength;
      }
      if (source.clipboard.maxFileCount !== undefined) {
        result.clipboard.maxFileCount = source.clipboard.maxFileCount;
      }
      if (source.clipboard.syncInterval !== undefined) {
        result.clipboard.syncInterval = source.clipboard.syncInterval;
      }
      if (source.clipboard.autoSync !== undefined) {
        result.clipboard.autoSync = source.clipboard.autoSync;
      }
    }
    
    if (source.ui) {
      if (source.ui.defaultLanguage !== undefined) {
        result.ui.defaultLanguage = source.ui.defaultLanguage;
      }
      if (source.ui.theme !== undefined) {
        result.ui.theme = source.ui.theme;
      }
      if (source.ui.showToolbar !== undefined) {
        result.ui.showToolbar = source.ui.showToolbar;
      }
      if (source.ui.toolbarAutoHideDelay !== undefined) {
        result.ui.toolbarAutoHideDelay = source.ui.toolbarAutoHideDelay;
      }
      if (source.ui.defaultScale !== undefined) {
        result.ui.defaultScale = source.ui.defaultScale;
      }
      if (source.ui.minScale !== undefined) {
        result.ui.minScale = source.ui.minScale;
      }
      if (source.ui.maxScale !== undefined) {
        result.ui.maxScale = source.ui.maxScale;
      }
    }
    
    if (source.log) {
      if (source.log.level !== undefined) {
        result.log.level = source.log.level;
      }
      if (source.log.enableConsole !== undefined) {
        result.log.enableConsole = source.log.enableConsole;
      }
      if (source.log.enableFile !== undefined) {
        result.log.enableFile = source.log.enableFile;
      }
      if (source.log.maxFileSize !== undefined) {
        result.log.maxFileSize = source.log.maxFileSize;
      }
      if (source.log.maxFileDays !== undefined) {
        result.log.maxFileDays = source.log.maxFileDays;
      }
    }
    
    return result;
  }

  setEnvironment(environment: EnvironmentType): void {
    this.currentEnvironment = environment;
    this.applyEnvironmentConfig();
    console.info(`ConfigCenter: Environment set to ${environment}`);
  }

  getEnvironment(): EnvironmentType {
    return this.currentEnvironment;
  }

  getConfig(): AppConfig {
    return this.config;
  }

  getServerConfig(): ServerConfig {
    return this.config.server;
  }

  /**
   * ⭐ 动态更新服务器IP地址
   * @param host 新的服务器主机地址
   */
  updateServerHost(host: string): void {
    hilog.info(DOMAIN, TAG, '更新服务器IP: %{public}s', host);
    this.config.server.host = host;
  }

  /**
   * ⭐ 动态更新服务器端口
   * @param port 新的服务器端口
   */
  updateServerPort(port: number): void {
    hilog.info(DOMAIN, TAG, '更新服务器端口: %{public}d', port);
    this.config.server.tcpPort = port;
  }

  getNetworkConfig(): NetworkConfig {
    return this.config.network;
  }

  getCaptureConfig(): CaptureConfig {
    return this.config.capture;
  }

  getCaptureCacheConfig(): CaptureCacheConfig {
    return this.config.captureCache;
  }

  getCaptureCacheRuntimeConfig(): CaptureCacheRuntimeConfig {
    const cacheCfg = this.config.captureCache;
    const captureCfg = this.config.capture;

    // 避免依赖特定 SDK Kit，按当前配置推导设备能力预算。
    let width = 1920;
    let height = 1080;
    let refreshRate = 60;
    let density = 2.0;

    if (this.currentEnvironment === 'emulator') {
      width = 1280;
      height = 720;
      refreshRate = 30;
      density = 1.5;
    } else {
      // 以捕获参数推导能力：更大的tileSize通常对应更高分辨率/吞吐。
      const tileFactor = Math.max(1, captureCfg.tileSize / 64);
      width = Math.floor(width * tileFactor);
      height = Math.floor(height * tileFactor);
      refreshRate = Math.max(30, Math.min(120, captureCfg.maxFps));
      density = captureCfg.grayscale ? 1.8 : 2.6;
    }

    const megaPixels = (width * height) / 1000000;
    let budgetMB = cacheCfg.baseBudgetMB + megaPixels * cacheCfg.perMegapixelBudgetMB;
    if (refreshRate >= 90) {
      budgetMB += cacheCfg.highRefreshExtraMB;
    }
    if (density >= 3.0) {
      budgetMB += cacheCfg.highDensityExtraMB;
    }

    budgetMB = Math.max(cacheCfg.minBudgetMB, Math.min(cacheCfg.maxBudgetMB, budgetMB));

    const queueMaxBytes = Math.floor(budgetMB * 1024 * 1024);
    const lowRatio = Math.max(0.1, Math.min(0.95, cacheCfg.lowWatermarkRatio));
    const highRatio = Math.max(lowRatio, Math.min(0.99, cacheCfg.highWatermarkRatio));

    return {
      maxSize: cacheCfg.maxSize,
      purgeSize: cacheCfg.purgeSize,
      queueMaxSize: cacheCfg.queueMaxSize,
      queueMaxBytes: queueMaxBytes,
      queueLowWatermarkBytes: Math.floor(queueMaxBytes * lowRatio),
      queueHighWatermarkBytes: Math.floor(queueMaxBytes * highRatio),
      pressureStartRatio: Math.max(0.1, Math.min(0.95, cacheCfg.pressureStartRatio)),
      pressureDropDirtyTileRatio: Math.max(0.01, Math.min(0.9, cacheCfg.pressureDropDirtyTileRatio))
    };
  }

  getFileTransferConfig(): FileTransferConfig {
    return this.config.fileTransfer;
  }

  getClipboardConfig(): ClipboardConfig {
    return this.config.clipboard;
  }

  getUIConfig(): UIConfig {
    return this.config.ui;
  }

  getLogConfig(): LogConfig {
    return this.config.log;
  }

  getHttpUrl(path: string = ''): string {
    const host = this.config.server.host;
    const httpPort = this.config.server.httpPort;
    const contextPath = this.config.server.contextPath;
    return `http://${host}:${httpPort}${contextPath}${path}`;
  }

  getTcpAddress(): TcpAddress {
    const host = this.config.server.host;
    const tcpPort = this.config.server.tcpPort;
    return { host: host, port: tcpPort };
  }

  printConfig(): void {
    console.info('=== 当前配置 ===');
    console.info(`环境: ${this.currentEnvironment}`);
    console.info('服务器:', JSON.stringify(this.config.server));
    console.info('网络:', JSON.stringify(this.config.network));
    console.info('捕获:', JSON.stringify(this.config.capture));
    console.info('捕获缓存:', JSON.stringify(this.config.captureCache));
    console.info('文件传输:', JSON.stringify(this.config.fileTransfer));
    console.info('剪贴板:', JSON.stringify(this.config.clipboard));
    console.info('UI:', JSON.stringify(this.config.ui));
    console.info('日志:', JSON.stringify(this.config.log));
    console.info('===============');
  }
}

export const configCenter = ConfigCenter.getInstance();
