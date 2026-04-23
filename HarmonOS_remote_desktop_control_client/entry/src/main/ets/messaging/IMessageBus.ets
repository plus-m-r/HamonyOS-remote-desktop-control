/**
 * 消息总线接口
 * 
 * 抽象主线程和 Worker 线程之间的通信，便于：
 * 1. 单元测试时模拟线程间通信
 * 2. 统一消息格式和错误处理
 * 3. 支持消息追踪和调试
 * 4. 实现消息队列和优先级
 */

/**
 * 消息类型
 */
export enum MessageType {
  // 图像处理相关
  PROCESS_IMAGE = 'PROCESS_IMAGE',
  IMAGE_RESULT = 'IMAGE_RESULT',
  
  // 协议解析相关
  PARSE_PROTOCOL = 'PARSE_PROTOCOL',
  PROTOCOL_RESULT = 'PROTOCOL_RESULT',
  
  // 心跳相关
  HEARTBEAT_TICK = 'HEARTBEAT_TICK',
  HEARTBEAT_ACK = 'HEARTBEAT_ACK',
  
  // 文件处理相关
  PROCESS_FILE = 'PROCESS_FILE',
  FILE_RESULT = 'FILE_RESULT',
  
  // 控制命令
  START = 'START',
  STOP = 'STOP',
  PAUSE = 'PAUSE',
  RESUME = 'RESUME',
  
  // 错误和状态
  ERROR = 'ERROR',
  STATUS_UPDATE = 'STATUS_UPDATE'
}

/**
 * 消息优先级
 */
export enum MessagePriority {
  HIGH = 0,
  NORMAL = 1,
  LOW = 2
}

/**
 * 消息接口
 */
export interface IMessage {
  /** 消息类型 */
  type: MessageType;
  /** 消息ID */
  id: string;
  /** 发送时间戳 */
  timestamp: number;
  /** 消息数据 */
  payload?: Record<string, Object>;
  /** 消息优先级 */
  priority?: MessagePriority;
  /** 源线程ID */
  sourceThreadId?: string;
  /** 目标线程ID */
  targetThreadId?: string;
}

/**
 * 消息处理器
 */
export type MessageHandler = (message: IMessage) => void | Promise<void>;

/**
 * 消息过滤器
 */
export type MessageFilter = (message: IMessage) => boolean;

/**
 * 消息总线接口
 */
export interface IMessageBus {
  /**
   * 初始化消息总线
   * @param threadId 当前线程ID
   */
  init(threadId: string): void;

  /**
   * 发送消息
   * @param message 消息
   * @returns 是否发送成功
   */
  send(message: IMessage): boolean;

  /**
   * 发送消息（快捷方法）
   * @param type 消息类型
   * @param payload 消息数据
   * @param priority 优先级
   */
  sendMessage(type: MessageType, payload?: Record<string, Object>, priority?: MessagePriority): boolean;

  /**
   * 订阅消息
   * @param type 消息类型
   * @param handler 消息处理器
   * @param filter 可选的消息过滤器
   * @returns 订阅ID
   */
  subscribe(type: MessageType, handler: MessageHandler, filter?: MessageFilter): string;

  /**
   * 取消订阅
   * @param subscriptionId 订阅ID
   */
  unsubscribe(subscriptionId: string): void;

  /**
   * 订阅一次（自动取消订阅）
   * @param type 消息类型
   * @param handler 消息处理器
   * @param timeout 超时时间（毫秒）
   */
  subscribeOnce(type: MessageType, handler: MessageHandler, timeout?: number): Promise<void>;

  /**
   * 广播消息（发送给所有线程）
   * @param message 消息
   */
  broadcast(message: IMessage): void;

  /**
   * 请求-响应模式
   * @param request 请求消息
   * @param timeout 超时时间（毫秒）
   * @returns Promise<IMessage>
   */
  request(request: IMessage, timeout?: number): Promise<IMessage>;

  /**
   * 获取待处理消息数量
   */
  getPendingMessageCount(): number;

  /**
   * 清空消息队列
   */
  clearQueue(): void;

  /**
   * 设置错误处理器
   * @param handler 错误处理器
   */
  setErrorHandler(handler: (error: Error, message: IMessage) => void): void;

  /**
   * 销毁消息总线
   */
  destroy(): void;
}
