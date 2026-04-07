export class GlobalContext {
  private static instance: GlobalContext | null = null;
  private context: Record<string, Object> = {};

  private constructor() {}

  static getInstance(): GlobalContext {
    if (!GlobalContext.instance) {
      GlobalContext.instance = new GlobalContext();
    }
    return GlobalContext.instance;
  }

  static getContext(): GlobalContext {
    return GlobalContext.getInstance();
  }

  setObject(key: string, value: Object): void {
    this.context[key] = value;
  }

  getObject(key: string): Object | undefined {
    return this.context[key];
  }
}
