// entry/src/main/ets/models/Clipboard.ts
export interface Clipboard {
  id?: string;
  deviceCode: string;
  content: string;
  type: string;
  createTime?: string;
  isFile?: number;
  fileName?: string;
  filePid?: string;
  fileInfoId?: string;
  childs?: Array<Clipboard>;
}
