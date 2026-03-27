import taskpool from '@ohos.taskpool';

/**
 * TaskPool工具类，用于处理并发任务
 * 注意：实际的捕获任务处理已在 CaptureWorker 中实现
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
      console.error('TaskPoolUtil: Failed to execute task', error);
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
