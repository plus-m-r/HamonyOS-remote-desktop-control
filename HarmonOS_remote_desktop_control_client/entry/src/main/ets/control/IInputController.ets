/**
 * 输入控制器接口
 *
 * 抽象用户输入控制（触摸、鼠标、手势等），便于：
 * 1. 单元测试时模拟用户输入
 * 2. 支持不同的输入设备
 * 3. 统一输入处理逻辑
 * 4. 模拟输入错误场景
 */

/**
 * 输入事件类型
 */
export enum InputEventType {
  TOUCH_START = 'TOUCH_START',
  TOUCH_MOVE = 'TOUCH_MOVE',
  TOUCH_END = 'TOUCH_END',
  TOUCH_CANCEL = 'TOUCH_CANCEL',
  LONG_PRESS = 'LONG_PRESS',
  PAN = 'PAN',
  PINCH = 'PINCH',
  TAP = 'TAP',
  DOUBLE_TAP = 'DOUBLE_TAP'
}

/**
 * 鼠标按钮类型
 */
export enum MouseButton {
  LEFT = 1,
  RIGHT = 2,
  MIDDLE = 3
}

/**
 * 输入事件
 */
export interface InputEvent {
  /** 事件类型 */
  type: InputEventType;
  /** X坐标 */
  x: number;
  /** Y坐标 */
  y: number;
  /** 时间戳 */
  timestamp: number;
  /** 额外数据 */
  data?: {
    /** 缩放比例（用于捏合手势） */
    scale?: number;
    /** 移动偏移量（用于平移手势） */
    deltaX?: number;
    /** 移动偏移量（用于平移手势） */
    deltaY?: number;
    /** 鼠标按钮 */
    button?: MouseButton;
    /** 是否长按 */
    isLongPress?: boolean;
  };
}

/**
 * 输入事件处理器
 */
export type InputEventHandler = (event: InputEvent) => void | Promise<void>;

/**
 * 输入控制器接口
 */
export interface IInputController {
  /**
   * 初始化控制器
   * @param element 控制元素（如屏幕区域）
   */
  init(element: any): void;

  /**
   * 处理触摸开始
   * @param x X坐标
   * @param y Y坐标
   */
  handleTouchStart(x: number, y: number): void;

  /**
   * 处理触摸移动
   * @param x X坐标
   * @param y Y坐标
   */
  handleTouchMove(x: number, y: number): void;

  /**
   * 处理触摸结束
   * @param x X坐标
   * @param y Y坐标
   */
  handleTouchEnd(x: number, y: number): void;

  /**
   * 处理捏合手势
   * @param scale 缩放比例
   * @param centerX 中心点X坐标
   * @param centerY 中心点Y坐标
   */
  handlePinch(scale: number, centerX: number, centerY: number): void;

  /**
   * 处理平移手势
   * @param deltaX X方向偏移
   * @param deltaY Y方向偏移
   */
  handlePan(deltaX: number, deltaY: number): void;

  /**
   * 处理点击
   * @param x X坐标
   * @param y Y坐标
   * @param button 鼠标按钮
   */
  handleClick(x: number, y: number, button?: MouseButton): void;

  /**
   * 处理长按
   * @param x X坐标
   * @param y Y坐标
   */
  handleLongPress(x: number, y: number): void;

  /**
   * 设置缩放范围
   * @param minScale 最小缩放比例
   * @param maxScale 最大缩放比例
   */
  setScaleRange(minScale: number, maxScale: number): void;

  /**
   * 获取当前缩放比例
   */
  getCurrentScale(): number;

  /**
   * 设置当前缩放比例
   * @param scale 缩放比例
   */
  setScale(scale: number): void;

  /**
   * 订阅输入事件
   * @param handler 事件处理器
   * @returns 订阅ID
   */
  subscribe(handler: InputEventHandler): string;

  /**
   * 取消订阅
   * @param subscriptionId 订阅ID
   */
  unsubscribe(subscriptionId: string): void;

  /**
   * 启用/禁用控制器
   * @param enabled 是否启用
   */
  setEnabled(enabled: boolean): void;

  /**
   * 销毁控制器
   */
  destroy(): void;
}
