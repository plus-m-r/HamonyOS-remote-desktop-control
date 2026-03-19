/**
 * 命令数据类
 * 共享的命令数据结构定义
 */
import { CmdType, ClipboardData } from './CmdProtocol';

export class CmdData {
  deviceCode: string = '';
  password: string = '';
  status: string = '';
  imageData: string | ArrayBuffer = '';
  width: number = 0;
  height: number = 0;
  x: number = 0;
  y: number = 0;
  action: number = 0;
  wheelDelta: number = 0;
  keyCode: number = 0;
  pressed: boolean = false;
  fps: number = 0;
  captureFrequency: number = 0;
  quality: number = 0;
  maxFps: number = 0;
  compressionMethod: number = 0;
  compressionLevel: number = 0;
  screenIndex: number = 0;
  captureOp: number = 0;
  clipboards: ClipboardData[] = [];
  text: string = '';
  fileInfoId: string = '';
  fileName: string = '';
  filePid: string = '';
  isFile: number = 0;
  oldPassword: string = '';
  newPassword: string = '';
  screenNum: number = 1; // 屏幕数量，默认为1
  osName: string = 'HarmonyOS'; // 操作系统名称
  type: CmdType = CmdType.ReqPing;
  id: string = '';
}