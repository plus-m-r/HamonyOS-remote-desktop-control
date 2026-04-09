/**
 * 命令数据类
 * 共享的命令数据结构定义
 */
import { CmdType, ClipboardData } from './CmdProtocol';
import { CompressionConfig } from '../network/CmdCodec';

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
  useCache: boolean = true;
  cacheMaxSize: number = 1000;
  cachePurgeSize: number = 500;
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
  compressionConfig?: CompressionConfig;

  static fromObject(obj: Record<string, Object>): CmdData {
    const data = new CmdData();
    if (obj['deviceCode'] !== undefined) data.deviceCode = String(obj['deviceCode']);
    if (obj['password'] !== undefined) data.password = String(obj['password']);
    if (obj['status'] !== undefined) data.status = String(obj['status']);
    if (obj['imageData'] !== undefined) data.imageData = obj['imageData'] as string | ArrayBuffer;
    if (obj['width'] !== undefined) data.width = Number(obj['width']);
    if (obj['height'] !== undefined) data.height = Number(obj['height']);
    if (obj['x'] !== undefined) data.x = Number(obj['x']);
    if (obj['y'] !== undefined) data.y = Number(obj['y']);
    if (obj['action'] !== undefined) data.action = Number(obj['action']);
    if (obj['wheelDelta'] !== undefined) data.wheelDelta = Number(obj['wheelDelta']);
    if (obj['keyCode'] !== undefined) data.keyCode = Number(obj['keyCode']);
    if (obj['pressed'] !== undefined) data.pressed = Boolean(obj['pressed']);
    if (obj['fps'] !== undefined) data.fps = Number(obj['fps']);
    if (obj['captureFrequency'] !== undefined) data.captureFrequency = Number(obj['captureFrequency']);
    if (obj['quality'] !== undefined) data.quality = Number(obj['quality']);
    if (obj['maxFps'] !== undefined) data.maxFps = Number(obj['maxFps']);
    if (obj['compressionMethod'] !== undefined) data.compressionMethod = Number(obj['compressionMethod']);
    if (obj['compressionLevel'] !== undefined) data.compressionLevel = Number(obj['compressionLevel']);
    if (obj['useCache'] !== undefined) data.useCache = Boolean(obj['useCache']);
    if (obj['cacheMaxSize'] !== undefined) data.cacheMaxSize = Number(obj['cacheMaxSize']);
    if (obj['cachePurgeSize'] !== undefined) data.cachePurgeSize = Number(obj['cachePurgeSize']);
    if (obj['screenIndex'] !== undefined) data.screenIndex = Number(obj['screenIndex']);
    if (obj['captureOp'] !== undefined) data.captureOp = Number(obj['captureOp']);
    if (obj['clipboards'] !== undefined) data.clipboards = obj['clipboards'] as ClipboardData[];
    if (obj['text'] !== undefined) data.text = String(obj['text']);
    if (obj['fileInfoId'] !== undefined) data.fileInfoId = String(obj['fileInfoId']);
    if (obj['fileName'] !== undefined) data.fileName = String(obj['fileName']);
    if (obj['filePid'] !== undefined) data.filePid = String(obj['filePid']);
    if (obj['isFile'] !== undefined) data.isFile = Number(obj['isFile']);
    if (obj['oldPassword'] !== undefined) data.oldPassword = String(obj['oldPassword']);
    if (obj['newPassword'] !== undefined) data.newPassword = String(obj['newPassword']);
    if (obj['screenNum'] !== undefined) data.screenNum = Number(obj['screenNum']);
    if (obj['osName'] !== undefined) data.osName = String(obj['osName']);
    if (obj['type'] !== undefined) data.type = obj['type'] as CmdType;
    if (obj['id'] !== undefined) data.id = String(obj['id']);
    if (obj['compressionConfig'] !== undefined) data.compressionConfig = obj['compressionConfig'] as CompressionConfig;
    return data;
  }
}