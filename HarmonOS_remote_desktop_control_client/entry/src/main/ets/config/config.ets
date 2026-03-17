
// 服务器配置文件
interface ServerConfig {
  host: string;
  tcpPort: number;
  httpPort: number;
  contextPath: string;
}
// TCP地址配置
interface TcpAddress {
  host: string;
  port: number;
}

// 配置选项接口
interface ConfigOptions {
  ORIGINAL: ServerConfig;
  LOCALHOST: ServerConfig;
  EMULATOR: ServerConfig;
}

// 配置选项
const CONFIG_OPTIONS: ConfigOptions = {
  // 原始服务端配置
  ORIGINAL: {
    host: '10.11.108.247',
    tcpPort: 54321,
    httpPort: 12345,
    contextPath: '/remote-desktop-control'
  },
  // localhost配置（用于本地测试）
  LOCALHOST: {
    host: '127.0.0.1',
    tcpPort: 54321,
    httpPort: 12345,
    contextPath: '/remote-desktop-control'
  },
  // 模拟器特殊地址（Android模拟器）
  EMULATOR: {
    host: '10.0.2.2',
    tcpPort: 54321,
    httpPort: 12345,
    contextPath: '/remote-desktop-control'
  }
};

// 环境检测函数
function detectEnvironment(): string {
  // 这里可以添加环境检测逻辑
  // 例如：检查是否在模拟器中运行、检查网络可达性等
  
  // 默认使用原始配置
  return 'ORIGINAL';
}

// 获取当前配置
function getCurrentConfig(): ServerConfig {
  const env = detectEnvironment();
  
  switch (env) {
    case 'LOCALHOST':
      console.info('使用localhost配置（本地测试）');
      return CONFIG_OPTIONS.LOCALHOST;
    case 'EMULATOR':
      console.info('使用模拟器配置');
      return CONFIG_OPTIONS.EMULATOR;
    case 'ORIGINAL':
    default:
      console.info('使用原始服务端配置');
      return CONFIG_OPTIONS.ORIGINAL;
  }
}

// 导出配置
export const SERVER_CONFIG: ServerConfig = getCurrentConfig();

// 辅助函数：打印配置信息
export function printServerConfig(): void {
  console.info('=== 服务器配置 ===');
  console.info(`主机: ${SERVER_CONFIG.host}`);
  console.info(`TCP端口: ${SERVER_CONFIG.tcpPort}`);
  console.info(`HTTP端口: ${SERVER_CONFIG.httpPort}`);
  console.info(`上下文路径: ${SERVER_CONFIG.contextPath}`);
  console.info('=================');
}

// 辅助函数：获取HTTP URL
export function getHttpUrl(path: string = ''): string {
  return `http://${SERVER_CONFIG.host}:${SERVER_CONFIG.httpPort}${SERVER_CONFIG.contextPath}${path}`;
}
// 辅助函数：获取TCP地址
export function getTcpAddress(): TcpAddress {
  return {
    host: SERVER_CONFIG.host,
    port: SERVER_CONFIG.tcpPort
  };
}