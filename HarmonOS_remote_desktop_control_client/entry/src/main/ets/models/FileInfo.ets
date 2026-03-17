// entry/src/main/ets/models/FileInfo.ts
export interface FileInfo {
  fileInfoId: string;
  fileName: string;
  fileSize: number;
  md5: string;
  createTime: string;
  fileUuid?: string;
}
