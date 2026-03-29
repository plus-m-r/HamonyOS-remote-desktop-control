/**
 * 输入控制器实现
 *
 * 实现 IInputController 接口
 */

import {
  IInputController,
  InputEvent,
  InputEventType,
  InputEventHandler,
  MouseButton
} from './IInputController';

interface Subscription {
  id: string;
  handler: InputEventHandler;
}

export class InputControllerImpl implements IInputController {
  private element: any = null;
  private subscriptions: Map<string, Subscription> = new Map();
  private isEnabled: boolean = true;
  private currentScale: number = 1.0;
  private minScale: number = 0.5;
  private maxScale: number = 3.0;
  private lastScale: number = 1.0;
  private longPressTimer: number | null = null;
  private isLongPress: boolean = false;
  private lastTouchX: number = 0;
  private lastTouchY: number = 0;
  private subscriptionIdCounter: number = 0;

  init(element: any): void {
    this.element = element;
    console.info('InputControllerImpl: Initialized');
  }

  handleTouchStart(x: number, y: number): void {
    if (!this.isEnabled) return;

    this.lastTouchX = x;
    this.lastTouchY = y;
    this.isLongPress = false;

    // 设置长按定时器
    this.longPressTimer = setTimeout(() => {
      this.isLongPress = true;
      this.notifyEvent({
        type: InputEventType.LONG_PRESS,
        x,
        y,
        timestamp: Date.now(),
        data: { isLongPress: true }
      });
    }, 500);

    this.notifyEvent({
      type: InputEventType.TOUCH_START,
      x,
      y,
      timestamp: Date.now()
    });
  }

  handleTouchMove(x: number, y: number): void {
    if (!this.isEnabled) return;

    // 取消长按
    if (this.longPressTimer) {
      clearTimeout(this.longPressTimer);
      this.longPressTimer = null;
    }

    this.lastTouchX = x;
    this.lastTouchY = y;

    this.notifyEvent({
      type: InputEventType.TOUCH_MOVE,
      x,
      y,
      timestamp: Date.now()
    });
  }

  handleTouchEnd(x: number, y: number): void {
    if (!this.isEnabled) return;

    // 清除长按定时器
    if (this.longPressTimer) {
      clearTimeout(this.longPressTimer);
      this.longPressTimer = null;
    }

    // 如果不是长按，发送点击事件
    if (!this.isLongPress) {
      this.notifyEvent({
        type: InputEventType.TAP,
        x,
        y,
        timestamp: Date.now(),
        data: { button: MouseButton.LEFT }
      });
    }

    this.notifyEvent({
      type: InputEventType.TOUCH_END,
      x,
      y,
      timestamp: Date.now()
    });

    this.isLongPress = false;
  }

  handlePinch(scale: number, centerX: number, centerY: number): void {
    if (!this.isEnabled) return;

    // 计算新的缩放比例
    let newScale = this.lastScale * scale;

    // 限制缩放范围
    newScale = Math.max(this.minScale, Math.min(this.maxScale, newScale));

    this.currentScale = newScale;

    this.notifyEvent({
      type: InputEventType.PINCH,
      x: centerX,
      y: centerY,
      timestamp: Date.now(),
      data: { scale: newScale }
    });
  }

  handlePan(deltaX: number, deltaY: number): void {
    if (!this.isEnabled) return;

    this.notifyEvent({
      type: InputEventType.PAN,
      x: this.lastTouchX,
      y: this.lastTouchY,
      timestamp: Date.now(),
      data: { deltaX, deltaY }
    });
  }

  handleClick(x: number, y: number, button: MouseButton = MouseButton.LEFT): void {
    if (!this.isEnabled) return;

    this.notifyEvent({
      type: InputEventType.TAP,
      x,
      y,
      timestamp: Date.now(),
      data: { button }
    });
  }

  handleLongPress(x: number, y: number): void {
    if (!this.isEnabled) return;

    this.isLongPress = true;

    this.notifyEvent({
      type: InputEventType.LONG_PRESS,
      x,
      y,
      timestamp: Date.now(),
      data: { isLongPress: true, button: MouseButton.RIGHT }
    });
  }

  setScaleRange(minScale: number, maxScale: number): void {
    this.minScale = minScale;
    this.maxScale = maxScale;

    // 确保当前缩放比例在范围内
    this.currentScale = Math.max(minScale, Math.min(maxScale, this.currentScale));
  }

  getCurrentScale(): number {
    return this.currentScale;
  }

  setScale(scale: number): void {
    this.currentScale = Math.max(this.minScale, Math.min(this.maxScale, scale));
    this.lastScale = this.currentScale;
  }

  subscribe(handler: InputEventHandler): string {
    const subscriptionId = `sub_${++this.subscriptionIdCounter}`;
    this.subscriptions.set(subscriptionId, { id: subscriptionId, handler });
    return subscriptionId;
  }

  unsubscribe(subscriptionId: string): void {
    this.subscriptions.delete(subscriptionId);
  }

  setEnabled(enabled: boolean): void {
    this.isEnabled = enabled;

    // 禁用时清除状态
    if (!enabled) {
      if (this.longPressTimer) {
        clearTimeout(this.longPressTimer);
        this.longPressTimer = null;
      }
      this.isLongPress = false;
    }
  }

  destroy(): void {
    this.subscriptions.clear();

    if (this.longPressTimer) {
      clearTimeout(this.longPressTimer);
      this.longPressTimer = null;
    }

    this.element = null;
    this.isEnabled = false;

    console.info('InputControllerImpl: Destroyed');
  }

  /**
   * 保存当前缩放比例（用于捏合手势）
   */
  saveCurrentScale(): void {
    this.lastScale = this.currentScale;
  }

  private notifyEvent(event: InputEvent): void {
    this.subscriptions.forEach((subscription) => {
      try {
        Promise.resolve(subscription.handler(event)).catch((error) => {
          console.error('InputControllerImpl: Handler error', error);
        });
      } catch (error) {
        console.error('InputControllerImpl: Handler error', error);
      }
    });
  }
}
