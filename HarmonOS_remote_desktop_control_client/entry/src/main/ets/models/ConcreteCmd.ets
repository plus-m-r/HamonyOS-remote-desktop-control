/**
 * 具体命令类
 * 实现 Cmd 接口
 */
import { Cmd, CmdType } from './CmdProtocol';
import { CmdData } from './CmdData';

/**
 * 具体命令类
 */
export class ConcreteCmd implements Cmd {
  type: CmdType;
  id: string;
  private data: CmdData;

  constructor(type: CmdType, data?: CmdData, id?: string) {
    this.type = type;
    this.id = id ?? this.generateId();
    this.data = data ?? new CmdData();
  }

  private generateId(): string {
    return Date.now().toString() + Math.random().toString(36).substring(2, 11);
  }

  /**
   * 获取命令数据
   */
  getData(): CmdData {
    return this.data;
  }

  /**
   * 转换为 JSON 对象
   */
  toJSON(): object {
    const result: Record<string, Object> = {};
    result['type'] = this.type;
    result['id'] = this.id;
    
    const data = this.data;
    if (data.deviceCode.length > 0) result['deviceCode'] = data.deviceCode;
    if (data.password.length > 0) result['password'] = data.password;
    if (data.status.length > 0) result['status'] = data.status;
    if (data.imageData.length > 0) result['imageData'] = data.imageData;
    if (data.width !== 0) result['width'] = data.width;
    if (data.height !== 0) result['height'] = data.height;
    if (data.x !== 0) result['x'] = data.x;
    if (data.y !== 0) result['y'] = data.y;
    if (data.action !== 0) result['action'] = data.action;
    if (data.wheelDelta !== 0) result['wheelDelta'] = data.wheelDelta;
    if (data.keyCode !== 0) result['keyCode'] = data.keyCode;
    if (data.pressed) result['pressed'] = data.pressed;
    if (data.fps !== 0) result['fps'] = data.fps;
    if (data.captureFrequency !== 0) result['captureFrequency'] = data.captureFrequency;
    if (data.quality !== 0) result['quality'] = data.quality;
    if (data.maxFps !== 0) result['maxFps'] = data.maxFps;
    if (data.compressionMethod !== 0) result['compressionMethod'] = data.compressionMethod;
    if (data.compressionLevel !== 0) result['compressionLevel'] = data.compressionLevel;
    if (data.screenIndex !== 0) result['screenIndex'] = data.screenIndex;
    if (data.captureOp !== 0) result['captureOp'] = data.captureOp;
    if (data.clipboards.length > 0) result['clipboards'] = data.clipboards;
    if (data.text.length > 0) result['text'] = data.text;
    if (data.fileInfoId.length > 0) result['fileInfoId'] = data.fileInfoId;
    if (data.fileName.length > 0) result['fileName'] = data.fileName;
    if (data.filePid.length > 0) result['filePid'] = data.filePid;
    if (data.isFile !== 0) result['isFile'] = data.isFile;
    if (data.oldPassword.length > 0) result['oldPassword'] = data.oldPassword;
    if (data.newPassword.length > 0) result['newPassword'] = data.newPassword;
    
    return result;
  }
}