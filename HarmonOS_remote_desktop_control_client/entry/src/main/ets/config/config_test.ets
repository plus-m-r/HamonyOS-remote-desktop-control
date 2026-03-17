// 测试用服务器配置
// 根据您的环境选择不同的配置

interface ServerConfig {
  host: string;
  tcpPort: number;
  httpPort: number;
  contextPath: string;
}

// 配置选项：
// 1. 原始服务端IP（如果模拟器可以访问）
export const SERVER_CONFIG_ORIGINAL: ServerConfig = {
  host: '10.11.108.247',
  tcpPort: 54321,
  httpPort: 12345,
  contextPath: '/remote-desktop-control'
};

// 2. localhost（如果服务端运行在本地）
export const SERVER_CONFIG_LOCALHOST: ServerConfig = {
  host: '127.0.0.1',
  tcpPort: 54321,
  httpPort: 12345,
  contextPath: '/remote-desktop-control'
};

// 3. 特殊地址（Android模拟器）
export const SERVER_CONFIG_EMULATOR: ServerConfig = {
  host: '10.0.2.2',  // Android模拟器访问主机的特殊地址
  tcpPort: 54321,
  httpPort: 12345,
  contextPath: '/remote-desktop-control'
};

// 4. 主机实际IP（需要替换为您的实际IP）
export const SERVER_CONFIG_HOST_IP: ServerConfig = {
  host: '192.168.1.100',  // 替换为您的实际主机IP
  tcpPort: 54321,
  httpPort: 12345,
  contextPath: '/remote-desktop-control'
};

// 5. 动态选择配置（根据环境）
function getServerConfig(): ServerConfig {
  // 这里可以根据运行环境返回不同的配置
  // 例如：检查是否在模拟器中运行
  
  // 默认使用原始配置
  return SERVER_CONFIG_ORIGINAL;
}

// 导出当前使用的配置
export const SERVER_CONFIG = getServerConfig();

// 测试函数：打印当前配置
export function printServerConfig(): void {
  console.info('=== 服务器配置信息 ===');
  console.info(`主机: ${SERVER_CONFIG.host}`);
  console.info(`TCP端口: ${SERVER_CONFIG.tcpPort}`);
  console.info(`HTTP端口: ${SERVER_CONFIG.httpPort}`);
  console.info(`上下文路径: ${SERVER_CONFIG.contextPath}`);
  console.info('=====================');
}

// 测试连接函数
export async function testConnection(): Promise<boolean> {
  try {
    console.info('开始测试服务器连接...');
    printServerConfig();
    
    // 这里可以添加实际的连接测试逻辑
    // 例如：使用fetch测试HTTP连接
    
    return true;
  } catch (error) {
    console.error('连接测试失败:', error);
    return false;
  }
}