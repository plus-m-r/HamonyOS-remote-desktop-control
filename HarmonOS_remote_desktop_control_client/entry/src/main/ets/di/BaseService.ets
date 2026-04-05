/**
 * 基础服务接口
 * 所有服务都应该实现此接口
 */
export interface BaseService {
  /**
   * 清理资源
   */
  cleanup?(): void;
}
