/**
 * 日志管理器 - 控制日志输出级别，提升生产环境性能
 */
import hilog from '@ohos.hilog';

export enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3,
  NONE = 4
}

export class LogManager {
  private static instance: LogManager;
  private currentLevel: LogLevel = LogLevel.INFO; // 生产环境使用INFO级别
  private isDebugMode: boolean = false;

  static getInstance(): LogManager {
    if (!LogManager.instance) {
      LogManager.instance = new LogManager();
    }
    return LogManager.instance;
  }

  /**
   * 设置日志级别
   */
  setLogLevel(level: LogLevel): void {
    this.currentLevel = level;
  }

  /**
   * 启用调试模式
   */
  enableDebugMode(): void {
    this.isDebugMode = true;
    this.currentLevel = LogLevel.DEBUG;
  }

  /**
   * 禁用调试模式
   */
  disableDebugMode(): void {
    this.isDebugMode = false;
    this.currentLevel = LogLevel.INFO;
  }

  /**
   * 检查是否为调试模式
   */
  isDebug(): boolean {
    return this.isDebugMode;
  }

  /**
   * 调试日志
   */
  debug(domain: number, tag: string, format: string, ...args: unknown[]): void {
    if (this.currentLevel <= LogLevel.DEBUG) {
      hilog.debug(domain, tag, format, ...args);
    }
  }

  /**
   * 信息日志
   */
  info(domain: number, tag: string, format: string, ...args: unknown[]): void {
    if (this.currentLevel <= LogLevel.INFO) {
      hilog.info(domain, tag, format, ...args);
    }
  }

  /**
   * 警告日志
   */
  warn(domain: number, tag: string, format: string, ...args: unknown[]): void {
    if (this.currentLevel <= LogLevel.WARN) {
      hilog.warn(domain, tag, format, ...args);
    }
  }

  /**
   * 错误日志
   */
  error(domain: number, tag: string, format: string, ...args: unknown[]): void {
    if (this.currentLevel <= LogLevel.ERROR) {
      hilog.error(domain, tag, format, ...args);
    }
  }

  /**
   * 控制台日志（仅在调试模式）
   */
  consoleLog(message: string, ...optionalParams: unknown[]): void {
    if (this.isDebugMode) {
      console.log(message, ...optionalParams);
    }
  }

  /**
   * 控制台错误（仅在调试模式）
   */
  consoleError(message: string, ...optionalParams: unknown[]): void {
    if (this.isDebugMode) {
      console.error(message, ...optionalParams);
    }
  }
}

// 导出便捷方法
export const logManager = LogManager.getInstance();
