import taskpool from '@ohos.taskpool';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001;
const TAG = 'TaskPoolUtil';

/**
 * TaskPool工具类，用于处理并发任务
 */
export class TaskPoolUtil {
  /**
   * 提交任务到TaskPool
   * @param task 要执行的任务函数
   * @param args 任务参数
   * @returns Promise<T> 任务执行结果
   */
  static async submit<T>(task: (...args: Array<Object>) => T, ...args: Array<Object>): Promise<T> {
    try {
      // 使用TaskPool执行任务
      const result = await taskpool.execute(task, args);
      return result as T;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to execute task: %{public}s', error instanceof Error ? error.message : String(error));
      throw new Error(error instanceof Error ? error.message : String(error));
    }
  }

  /**
   * 提交任务到TaskPool
   * @param task 任务函数
   * @param taskData 任务数据
   * @returns Promise<T> 任务执行结果
   */
  static async submitTask<T>(task: (...args: Array<Object>) => T, taskData: Object): Promise<T> {
    return TaskPoolUtil.submit(task, taskData);
  }
}
