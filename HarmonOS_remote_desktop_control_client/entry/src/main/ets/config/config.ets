/**
 * 配置入口文件
 * 
 * 统一导出配置中心和配置类型
 * 原有的配置已迁移到 ConfigCenter 中管理
 * 
 * 使用示例：
 * ```typescript
 * import { configCenter } from './config/config';
 * 
 * // 获取服务器配置
 * const serverConfig = configCenter.getServerConfig();
 * 
 * // 获取 HTTP URL
 * const url = configCenter.getHttpUrl('/api/user');
 * 
 * // 监听配置变更
 * configCenter.addListener('server.host', (newVal, oldVal) => {
 *   console.log('服务器地址已变更:', newVal);
 * });
 * ```
 */

import { configCenter } from './ConfigCenter';
import type { ServerConfig, TcpAddress } from './ConfigTypes';

// 导出配置中心
export { ConfigCenter, configCenter } from './ConfigCenter';

// 导出配置类型
export type {
  AppConfig,
  ServerConfig,
  NetworkConfig,
  CaptureConfig,
  FileTransferConfig,
  ClipboardConfig,
  UIConfig,
  LogConfig,
  EnvironmentType,
  ConfigChangeListener,
  ConfigPath
} from './ConfigTypes';

// 为了向后兼容，保留原有的导出
// 但建议使用新的 ConfigCenter API

/**
 * 服务器配置（向后兼容）
 * @deprecated 建议使用 configCenter.getServerConfig()
 */
export const SERVER_CONFIG: ServerConfig = configCenter.getServerConfig();

/**
 * 打印服务器配置（向后兼容）
 * @deprecated 建议使用 configCenter.printConfig()
 */
export function printServerConfig(): void {
  configCenter.printConfig();
}

/**
 * 获取 HTTP URL（向后兼容）
 * @deprecated 建议使用 configCenter.getHttpUrl()
 */
export function getHttpUrl(path: string = ''): string {
  return configCenter.getHttpUrl(path);
}

/**
 * 获取 TCP 地址（向后兼容）
 * @deprecated 建议使用 configCenter.getTcpAddress()
 */
export function getTcpAddress(): TcpAddress {
  return configCenter.getTcpAddress();
}

// 在应用启动时打印配置
console.info('配置中心已加载，当前环境:', configCenter.getEnvironment());
