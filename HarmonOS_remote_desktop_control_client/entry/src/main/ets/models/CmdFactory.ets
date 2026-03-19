/**
 * 命令工厂类
 * 用于创建各种类型的命令对象
 */
import { ConcreteCmd } from './ConcreteCmd';
import { CmdData } from './CmdData';
import { CmdType, MouseAction, OpenStatus, CaptureStatus, CompressionMethod, ClipboardData } from './CmdProtocol';

/**
 * 命令工厂类
 */
export class CmdUtils {
  /**
   * 创建请求客户端信息命令
   */
  static createReqCliInfoCmd(screenNum: number = 1, osName: string = 'HarmonyOS'): ConcreteCmd {
    const data = new CmdData();
    data.screenNum = screenNum;
    data.osName = osName;
    return new ConcreteCmd(CmdType.ReqCliInfo, data);
  }

  /**
   * 创建响应客户端信息命令
   */
  static createResCliInfoCmd(deviceCode: string, password: string): ConcreteCmd {
    const data = new CmdData();
    data.deviceCode = deviceCode;
    data.password = password;
    return new ConcreteCmd(CmdType.ResCliInfo, data);
  }

  /**
   * 创建修改密码命令
   */
  static createChangePwdCmd(deviceCode: string, oldPassword: string, newPassword: string): ConcreteCmd {
    const data = new CmdData();
    data.deviceCode = deviceCode;
    data.oldPassword = oldPassword;
    data.newPassword = newPassword;
    return new ConcreteCmd(CmdType.ChangePwd, data);
  }

  /**
   * 创建心跳请求命令
   */
  static createPingCmd(): ConcreteCmd {
    return new ConcreteCmd(CmdType.ReqPing);
  }

  /**
   * 创建心跳响应命令
   */
  static createPongCmd(): ConcreteCmd {
    return new ConcreteCmd(CmdType.ResPong);
  }

  /**
   * 创建打开连接请求命令
   */
  static createOpenCmd(deviceCode: string): ConcreteCmd {
    const data = new CmdData();
    data.deviceCode = deviceCode;
    return new ConcreteCmd(CmdType.ReqOpen, data);
  }

  /**
   * 创建打开连接响应命令
   */
  static createOpenResponseCmd(status: OpenStatus): ConcreteCmd {
    const data = new CmdData();
    data.status = status;
    return new ConcreteCmd(CmdType.ResOpen, data);
  }

  /**
   * 创建屏幕捕获请求命令
   */
  static createCaptureCmd(deviceCode: string, password: string, captureOp: number): ConcreteCmd {
    const data = new CmdData();
    data.deviceCode = deviceCode;
    data.password = password;
    data.captureOp = captureOp;
    return new ConcreteCmd(CmdType.ReqCapture, data);
  }

  /**
   * 创建屏幕捕获响应命令
   */
  static createCaptureResponseCmd(status: CaptureStatus): ConcreteCmd {
    const data = new CmdData();
    data.status = status;
    return new ConcreteCmd(CmdType.ResCapture, data);
  }

  /**
   * 创建屏幕捕获数据命令
   */
  static createCaptureDataCmd(
    imageData: string | ArrayBuffer,
    width: number,
    height: number,
    compressionMethod: CompressionMethod | number
  ): ConcreteCmd {
    const data = new CmdData();
    data.imageData = imageData;
    data.width = width;
    data.height = height;
    data.compressionMethod = compressionMethod as number;
    return new ConcreteCmd(CmdType.Capture, data);
  }

  /**
   * 创建选择屏幕命令
   */
  static createSelectScreenCmd(deviceCode: string, screenIndex: number): ConcreteCmd {
    const data = new CmdData();
    data.deviceCode = deviceCode;
    data.screenIndex = screenIndex;
    return new ConcreteCmd(CmdType.SelectScreen, data);
  }

  /**
   * 创建鼠标控制命令
   */
  static createMouseControlCmd(
    deviceCode: string,
    x: number,
    y: number,
    action: MouseAction,
    wheelDelta?: number
  ): ConcreteCmd {
    const data = new CmdData();
    data.deviceCode = deviceCode;
    data.x = x;
    data.y = y;
    data.action = action;
    if (wheelDelta !== undefined) {
      data.wheelDelta = wheelDelta;
    }
    return new ConcreteCmd(CmdType.MouseControl, data);
  }

  /**
   * 创建键盘控制命令
   */
  static createKeyControlCmd(deviceCode: string, keyCode: number, pressed: boolean): ConcreteCmd {
    const data = new CmdData();
    data.deviceCode = deviceCode;
    data.keyCode = keyCode;
    data.pressed = pressed;
    return new ConcreteCmd(CmdType.KeyControl, data);
  }

  /**
   * 创建屏幕捕获配置命令
   */
  static createCaptureConfigCmd(
    deviceCode: string,
    captureFrequency: number,
    quality: number,
    maxFps: number
  ): ConcreteCmd {
    const data = new CmdData();
    data.deviceCode = deviceCode;
    data.captureFrequency = captureFrequency;
    data.quality = quality;
    data.maxFps = maxFps;
    return new ConcreteCmd(CmdType.CaptureConfig, data);
  }

  /**
   * 创建压缩器配置命令
   */
  static createCompressorConfigCmd(
    deviceCode: string,
    compressionMethod: CompressionMethod,
    compressionLevel: number
  ): ConcreteCmd {
    const data = new CmdData();
    data.deviceCode = deviceCode;
    data.compressionMethod = compressionMethod;
    data.compressionLevel = compressionLevel;
    return new ConcreteCmd(CmdType.CompressorConfig, data);
  }

  /**
   * 创建请求远程剪贴板命令
   */
  static createClipboardRequestCmd(deviceCode: string): ConcreteCmd {
    const data = new CmdData();
    data.deviceCode = deviceCode;
    return new ConcreteCmd(CmdType.ReqRemoteClipboard, data);
  }

  /**
   * 创建响应远程剪贴板命令
   */
  static createClipboardResponseCmd(clipboards: ClipboardData[]): ConcreteCmd {
    const data = new CmdData();
    data.clipboards = clipboards;
    return new ConcreteCmd(CmdType.ResRemoteClipboard, data);
  }

  /**
   * 创建文本剪贴板命令
   */
  static createClipboardTextCmd(deviceCode: string, text: string): ConcreteCmd {
    const data = new CmdData();
    data.deviceCode = deviceCode;
    data.text = text;
    return new ConcreteCmd(CmdType.ClipboardText, data);
  }

  /**
   * 创建文件传输剪贴板命令
   */
  static createClipboardTransferCmd(deviceCode: string, fileInfoId: string, fileName: string): ConcreteCmd {
    const data = new CmdData();
    data.deviceCode = deviceCode;
    data.fileInfoId = fileInfoId;
    data.fileName = fileName;
    return new ConcreteCmd(CmdType.ClipboardTransfer, data);
  }


}