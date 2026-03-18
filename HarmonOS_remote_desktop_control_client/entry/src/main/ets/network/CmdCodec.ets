/**
 * 命令编解码器
 * 负责命令的编码和解码，支持流式数据解析
 */
import { ConcreteCmd } from '../models/ConcreteCmd';
import { CmdUtils } from '../models/CmdFactory';
import { CmdType, OpenStatus, CaptureStatus, CompressionMethod, MouseAction, ClipboardData } from '../models/CmdProtocol';
import { util } from '@kit.ArkTS';

/**
 * 命令编解码器
 */
export class CmdCodec {
  /**
   * 获取命令类型的ordinal值（与Java服务端保持一致）
   */
  private static getCmdTypeOrdinal(cmdType: CmdType): number {
    switch (cmdType) {
      case CmdType.ReqPing: return 0;
      case CmdType.ReqOpen: return 1;
      case CmdType.ReqCapture: return 2;
      case CmdType.ReqRemoteClipboard: return 3;
      case CmdType.ResOpen: return 4;
      case CmdType.ResCliInfo: return 5;
      case CmdType.ResCapture: return 6;
      case CmdType.ResPong: return 7;
      case CmdType.ResRemoteClipboard: return 8;
      case CmdType.Capture: return 9;
      case CmdType.CompressorConfig: return 10;
      case CmdType.CaptureConfig: return 11;
      case CmdType.KeyControl: return 12;
      case CmdType.MouseControl: return 13;
      case CmdType.ClipboardText: return 14;
      case CmdType.ClipboardTransfer: return 15;
      case CmdType.ReqCliInfo: return 16;
      case CmdType.SelectScreen: return 17;
      case CmdType.ChangePwd: return 18;
      default: return -1;
    }
  }

  /**
   * 编码命令为 ArrayBuffer
   */
  static encode(cmd: ConcreteCmd): ArrayBuffer {
    try {
      // 使用二进制协议，与Java服务端保持一致
      const cmdType = cmd.type;
      const cmdData = cmd.toJSON() as Record<string, Object>;
      
      // 根据命令类型进行编码
      switch (cmdType) {
        case CmdType.ReqPing:
          return CmdCodec.encodePingCmd();
        case CmdType.ReqCliInfo:
          return CmdCodec.encodeReqCliInfoCmd(cmdData);
        default:
          console.error(`CmdCodec: Unsupported command type for binary encoding: ${cmdType}`);
          return CmdCodec.encodeJsonFallback(cmd);
      }
    } catch (error) {
      console.error('CmdCodec: Failed to encode command', error);
      return new ArrayBuffer(0);
    }
  }

  /**
   * JSON回退编码（用于其他命令类型）
   */
  private static encodeJsonFallback(cmd: ConcreteCmd): ArrayBuffer {
    try {
      // 序列化命令为 JSON 字符串
      const jsonStr = CmdUtils.serialize(cmd);
      
      // 使用 TextEncoder 将字符串转换为 UTF-8 字节数组
      const encoder = new util.TextEncoder();
      const jsonBytes = encoder.encode(jsonStr);
      
      // 获取编码后的字节数
      const byteLength = jsonBytes.byteLength;
      
      // 创建缓冲区：4字节长度 + 数据
      const buffer = new ArrayBuffer(4 + byteLength);
      const view = new DataView(buffer);
      
      // 写入数据长度（大端序）
      view.setUint32(0, byteLength, false);
      
      // 写入数据
      const dataView = new Uint8Array(buffer, 4);
      dataView.set(jsonBytes);
      
      return buffer;
    } catch (error) {
      console.error('CmdCodec: Failed to encode JSON fallback', error);
      return new ArrayBuffer(0);
    }
  }

  /**
   * 编码心跳请求命令
   */
  private static encodePingCmd(): ArrayBuffer {
    // 心跳命令格式：魔数(1) + 命令类型(1) + 数据长度(4) = 6字节
    const buffer = new ArrayBuffer(6);
    const view = new DataView(buffer);
    
    // 魔数：100（与Java服务端一致）
    view.setUint8(0, 100);
    
    // 命令类型：ReqPing的ordinal值
    const cmdTypeOrdinal = CmdCodec.getCmdTypeOrdinal(CmdType.ReqPing);
    view.setUint8(1, cmdTypeOrdinal);
    
    // 数据长度：心跳命令没有额外数据
    view.setUint32(2, 0, false);
    
    return buffer;
  }

  /**
   * 编码请求客户端信息命令
   */
  private static encodeReqCliInfoCmd(cmdData: Record<string, Object>): ArrayBuffer {
    const screenNum = cmdData.screenNum as number || 1;
    const osName = cmdData.osName as string || 'HarmonyOS';
    
    // 将osName转换为UTF-8字节数组
    const encoder = new util.TextEncoder();
    const osNameBytes = encoder.encode(osName);
    
    // 计算数据长度：screenNum(4) + osName长度(4) + osName字节数
    const dataLength = 4 + 4 + osNameBytes.byteLength;
    
    // 总缓冲区大小：魔数(1) + 命令类型(1) + 数据长度(4) + 数据
    const buffer = new ArrayBuffer(1 + 1 + 4 + dataLength);
    const view = new DataView(buffer);
    let offset = 0;
    
    // 魔数：100
    view.setUint8(offset, 100);
    offset += 1;
    
    // 命令类型：ReqCliInfo的ordinal值
    const cmdTypeOrdinal = CmdCodec.getCmdTypeOrdinal(CmdType.ReqCliInfo);
    view.setUint8(offset, cmdTypeOrdinal);
    offset += 1;
    
    // 数据长度
    view.setUint32(offset, dataLength, false);
    offset += 4;
    
    // screenNum
    view.setInt32(offset, screenNum, false);
    offset += 4;
    
    // osName长度
    view.setUint32(offset, osNameBytes.byteLength, false);
    offset += 4;
    
    // osName字节
    const dataView = new Uint8Array(buffer, offset);
    dataView.set(osNameBytes);
    
    return buffer;
  }

  /**
   * 解码二进制数据为命令
   */
  static decode(buffer: ArrayBuffer): ConcreteCmd | undefined {
    try {
      if (buffer.byteLength < 4) {
        console.error('CmdCodec: Buffer too short for decoding');
        return undefined;
      }
      
      const view = new DataView(buffer);
      
      // 读取数据长度（大端序）
      const dataLength = view.getUint32(0, false);
      
      if (buffer.byteLength < 4 + dataLength) {
        console.error('CmdCodec: Incomplete data in buffer');
        return undefined;
      }
      
      // 提取 JSON 数据
      const jsonBytes = buffer.slice(4, 4 + dataLength);
      
      // 解码为字符串
      const decoder = util.TextDecoder.create('utf-8');
      const jsonStr = decoder.decodeToString(new Uint8Array(jsonBytes));
      
      // 反序列化为命令
      return CmdUtils.deserialize(jsonStr);
    } catch (error) {
      console.error('CmdCodec: Failed to decode command', error);
      return undefined;
    }
  }

  /**
   * 从流式缓冲区中提取命令
   * 返回 [剩余缓冲区, 命令数组]
   */
  static extractCommands(buffer: ArrayBuffer): [ArrayBuffer, ConcreteCmd[]] {
    const commands: ConcreteCmd[] = [];
    let remainingBuffer = buffer;
    
    try {
      while (remainingBuffer.byteLength >= 4) {
        const view = new DataView(remainingBuffer);
        const dataLength = view.getUint32(0, false);
        
        // 检查是否有完整的数据包
        if (remainingBuffer.byteLength < 4 + dataLength) {
          break;
        }
        
        // 提取单个命令的数据
        const cmdBuffer = remainingBuffer.slice(0, 4 + dataLength);
        const cmd = CmdCodec.decode(cmdBuffer);
        
        if (cmd) {
          commands.push(cmd);
        }
        
        // 移动到下一个命令
        remainingBuffer = remainingBuffer.slice(4 + dataLength);
      }
    } catch (error) {
      console.error('CmdCodec: Failed to extract commands', error);
    }
    
    return [remainingBuffer, commands];
  }

  /**
   * 创建心跳请求命令
   */
  static createPingCmd(): ConcreteCmd {
    return CmdUtils.createPingCmd();
  }

  /**
   * 创建心跳响应命令
   */
  static createPongCmd(): ConcreteCmd {
    return CmdUtils.createPongCmd();
  }

  /**
   * 创建请求客户端信息命令
   */
  static createReqCliInfoCmd(screenNum: number = 1, osName: string = 'HarmonyOS'): ConcreteCmd {
    return CmdUtils.createReqCliInfoCmd(screenNum, osName);
  }

  /**
   * 创建修改密码命令
   */
  static createChangePwdCmd(deviceCode: string, oldPassword: string, newPassword: string): ConcreteCmd {
    return CmdUtils.createChangePwdCmd(deviceCode, oldPassword, newPassword);
  }

  /**
   * 创建打开连接请求命令
   */
  static createOpenCmd(deviceCode: string): ConcreteCmd {
    return CmdUtils.createOpenCmd(deviceCode);
  }

  /**
   * 创建打开连接响应命令
   */
  static createOpenResponseCmd(status: string): ConcreteCmd {
    return CmdUtils.createOpenResponseCmd(status as OpenStatus);
  }

  /**
   * 创建屏幕捕获请求命令
   */
  static createCaptureCmd(deviceCode: string, password: string, start: boolean): ConcreteCmd {
    const captureOp = start ? 1 : 0;
    return CmdUtils.createCaptureCmd(deviceCode, password, captureOp);
  }

  /**
   * 创建屏幕捕获响应命令
   */
  static createCaptureResponseCmd(status: string): ConcreteCmd {
    return CmdUtils.createCaptureResponseCmd(status as CaptureStatus);
  }

  /**
   * 创建屏幕捕获数据命令
   */
  static createCaptureDataCmd(
    imageData: string,
    width: number,
    height: number,
    compressionMethod: number
  ): ConcreteCmd {
    return CmdUtils.createCaptureDataCmd(imageData, width, height, compressionMethod as CompressionMethod);
  }

  /**
   * 创建鼠标控制命令
   */
  static createMouseControlCmd(
    deviceCode: string,
    x: number,
    y: number,
    action: number,
    wheelDelta?: number
  ): ConcreteCmd {
    return CmdUtils.createMouseControlCmd(deviceCode, x, y, action as MouseAction, wheelDelta);
  }

  /**
   * 创建键盘控制命令
   */
  static createKeyControlCmd(deviceCode: string, keyCode: number, pressed: boolean): ConcreteCmd {
    return CmdUtils.createKeyControlCmd(deviceCode, keyCode, pressed);
  }

  /**
   * 创建请求远程剪贴板命令
   */
  static createClipboardRequestCmd(deviceCode: string): ConcreteCmd {
    return CmdUtils.createClipboardRequestCmd(deviceCode);
  }

  /**
   * 创建响应远程剪贴板命令
   */
  static createClipboardResponseCmd(clipboards: ClipboardData[]): ConcreteCmd {
    return CmdUtils.createClipboardResponseCmd(clipboards);
  }

  /**
   * 创建文本剪贴板命令
   */
  static createClipboardTextCmd(deviceCode: string, text: string): ConcreteCmd {
    return CmdUtils.createClipboardTextCmd(deviceCode, text);
  }

  /**
   * 创建文件传输剪贴板命令
   */
  static createClipboardTransferCmd(deviceCode: string, fileInfoId: string, fileName: string): ConcreteCmd {
    return CmdUtils.createClipboardTransferCmd(deviceCode, fileInfoId, fileName);
  }
}