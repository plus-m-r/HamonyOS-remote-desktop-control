/**
 * 心跳管理器接口
 * 
 * 抽象心跳管理，便于：
 * 1. 单元测试时控制心跳行为
 * 2. 模拟心跳超时场景
 * 3. 替换心跳实现（如从 Worker 切换到主线程）
 */

/**
 * 心跳配置
 */
export interface HeartbeatConfig {
  interval: number;
  timeout: number;
}

/**
 * 心跳回调函数
 */
export type HeartbeatCallback = () => void;

/**
 * 心跳管理器接口
 */
export interface IHeartbeatManager {
  /**
   * 初始化心跳管理器
   * @param interval 心跳间隔（毫秒）
   */
  init(interval: number): void;

  /**
   * 设置心跳回调
   * @param callback 心跳回调函数
   */
  setHeartbeatCallback(callback: HeartbeatCallback): void;

  /**
   * 开始心跳
   */
  start(): void;

  /**
   * 停止心跳
   */
  stop(): void;

  /**
   * 更新心跳间隔
   * @param interval 新的心跳间隔（毫秒）
   */
  updateInterval(interval: number): void;

  /**
   * 销毁心跳管理器
   */
  destroy(): void;

  /**
   * 检查是否正在运行
   */
  isRunning(): boolean;
}
