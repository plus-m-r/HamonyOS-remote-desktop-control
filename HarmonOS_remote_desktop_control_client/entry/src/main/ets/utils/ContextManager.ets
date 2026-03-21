import { common } from '@kit.AbilityKit';

export class ContextManager {
  private static instance: ContextManager | null = null;
  private context: common.UIAbilityContext | null = null;

  private constructor() {}

  static getInstance(): ContextManager {
    if (!ContextManager.instance) {
      ContextManager.instance = new ContextManager();
    }
    return ContextManager.instance;
  }

  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  getContext(): common.UIAbilityContext | null {
    return this.context;
  }

  getTempDir(): string {
    if (!this.context) {
      throw new Error('Context not initialized');
    }
    return this.context.tempDir;
  }
}
