/**
 * 命令编解码器
 * 负责命令的编码和解码，支持流式数据解析
 */
import { ConcreteCmd } from '../models/ConcreteCmd';
import { CmdUtils } from '../models/CmdFactory';
import { CmdType, OpenStatus, CaptureStatus, CompressionMethod, MouseAction, ClipboardData } from '../models/CmdProtocol';
import { util } from '@kit.ArkTS';

/**
 * 压缩配置接口
 */
export interface CompressionConfig {
  method: number;
  useCache: boolean;
  cacheMaxSize: number;
  cachePurgeSize: number;
}

/**
 * 命令编解码器
 */
export interface ExtractCommandsResult {
  remainingBuffer: ArrayBuffer;
  commands: ConcreteCmd[];
  protocolError: boolean;
}

export class CmdCodec {
  private static readonly textEncoder: util.TextEncoder = new util.TextEncoder();
  private static readonly textDecoder: util.TextDecoder = util.TextDecoder.create('utf-8');
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
   * 编码命令为 ArrayBuffer，与Java客户端的NettyEncoder保持一致
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
        case CmdType.ReqOpen:
          return CmdCodec.encodeReqOpenCmd(cmdData);
        case CmdType.ReqCapture:
          return CmdCodec.encodeReqCaptureCmd(cmdData);
        case CmdType.MouseControl:
          return CmdCodec.encodeMouseControlCmd(cmdData);
        case CmdType.KeyControl:
          return CmdCodec.encodeKeyControlCmd(cmdData);
        case CmdType.ReqRemoteClipboard:
          return CmdCodec.encodeClipboardRequestCmd(cmdData);
        case CmdType.ClipboardText:
          return CmdCodec.encodeClipboardTextCmd(cmdData);
        case CmdType.ClipboardTransfer:
          return CmdCodec.encodeClipboardTransferCmd(cmdData);
        case CmdType.SelectScreen:
          return CmdCodec.encodeSelectScreenCmd(cmdData);
        case CmdType.ChangePwd:
          return CmdCodec.encodeChangePwdCmd(cmdData);
        case CmdType.ResPong:
          return CmdCodec.encodePongCmd();
        case CmdType.ResCliInfo:
          return CmdCodec.encodeResCliInfoCmd(cmdData);
        case CmdType.ResOpen:
          return CmdCodec.encodeResOpenCmd(cmdData);
        case CmdType.ResCapture:
          return CmdCodec.encodeResCaptureCmd(cmdData);
        case CmdType.ResRemoteClipboard:
          return CmdCodec.encodeResRemoteClipboardCmd(cmdData);
        case CmdType.Capture:
          return CmdCodec.encodeCaptureCmd(cmdData);
        case CmdType.CaptureConfig:
          return CmdCodec.encodeCaptureConfigCmd(cmdData);
        case CmdType.CompressorConfig:
          return CmdCodec.encodeCompressorConfigCmd(cmdData);
        default:
          console.error(`CmdCodec: Unsupported command type for binary encoding: ${cmdType}`);
          // 不再支持JSON回退，直接返回空缓冲区
          return new ArrayBuffer(0);
      }
    } catch (error) {
      console.error('CmdCodec: Failed to encode command', error);
      return new ArrayBuffer(0);
    }
  }



  /**
   * 编码心跳请求命令
   */
  private static encodePingCmd(): ArrayBuffer {
    const buffer = new ArrayBuffer(7);
    const view = new DataView(buffer);
    let offset = 0;
    view.setUint8(offset, 0x64); offset += 1;
    view.setUint8(offset, 0x33); offset += 1;
    const cmdTypeOrdinal = CmdCodec.getCmdTypeOrdinal(CmdType.ReqPing);
    view.setUint8(offset, cmdTypeOrdinal); offset += 1;
    view.setUint32(offset, 0, false);
    return buffer;
  }

  /**
   * 编码心跳响应命令
   */
  private static encodePongCmd(): ArrayBuffer {
    const buffer = new ArrayBuffer(7);
    const view = new DataView(buffer);
    let offset = 0;
    view.setUint8(offset, 0x64); offset += 1;
    view.setUint8(offset, 0x33); offset += 1;
    const cmdTypeOrdinal = CmdCodec.getCmdTypeOrdinal(CmdType.ResPong);
    view.setUint8(offset, cmdTypeOrdinal); offset += 1;
    view.setUint32(offset, 0, false);
    return buffer;
  }

  /**
   * 编码响应客户端信息命令
   */
  private static encodeResCliInfoCmd(cmdData: Record<string, Object>): ArrayBuffer {
    const deviceCode = cmdData.deviceCode as string || '';
    const password = cmdData.password as string || '';
    const encoder = CmdCodec.textEncoder;
    const deviceCodeBytes = encoder.encode(deviceCode);
    const passwordBytes = encoder.encode(password);
    const dataLength = 4 + deviceCodeBytes.byteLength + 4 + passwordBytes.byteLength;
    const buffer = new ArrayBuffer(2 + 1 + 4 + dataLength);
    const view = new DataView(buffer);
    let offset = 0;
    view.setUint8(offset, 0x64); offset += 1;
    view.setUint8(offset, 0x33); offset += 1;
    const cmdTypeOrdinal = CmdCodec.getCmdTypeOrdinal(CmdType.ResCliInfo);
    view.setUint8(offset, cmdTypeOrdinal); offset += 1;
    view.setUint32(offset, dataLength, false); offset += 4;
    view.setUint32(offset, deviceCodeBytes.byteLength, false); offset += 4;
    const deviceCodeView = new Uint8Array(buffer, offset);
    deviceCodeView.set(deviceCodeBytes); offset += deviceCodeBytes.byteLength;
    view.setUint32(offset, passwordBytes.byteLength, false); offset += 4;
    const passwordView = new Uint8Array(buffer, offset);
    passwordView.set(passwordBytes);
    return buffer;
  }

  /**
   * 编码响应打开连接命令
   */
  private static encodeResOpenCmd(cmdData: Record<string, Object>): ArrayBuffer {
    const status = cmdData.status as number || 0;
    const dataLength = 1;
    const buffer = new ArrayBuffer(2 + 1 + 4 + dataLength);
    const view = new DataView(buffer);
    let offset = 0;
    view.setUint8(offset, 0x64); offset += 1;
    view.setUint8(offset, 0x33); offset += 1;
    const cmdTypeOrdinal = CmdCodec.getCmdTypeOrdinal(CmdType.ResOpen);
    view.setUint8(offset, cmdTypeOrdinal); offset += 1;
    view.setUint32(offset, dataLength, false); offset += 4;
    view.setUint8(offset, status);
    return buffer;
  }

  /**
   * 编码响应屏幕捕获命令
   * 格式：status(1) + screenNum(4)
   */
  private static encodeResCaptureCmd(cmdData: Record<string, Object>): ArrayBuffer {
    const status = cmdData.status as number || 0;
    const screenNum = cmdData.screenNum as number || 1;
    const dataLength = 1 + 4;
    const buffer = new ArrayBuffer(2 + 1 + 4 + dataLength);
    const view = new DataView(buffer);
    let offset = 0;
    view.setUint8(offset, 0x64); offset += 1;
    view.setUint8(offset, 0x33); offset += 1;
    const cmdTypeOrdinal = CmdCodec.getCmdTypeOrdinal(CmdType.ResCapture);
    view.setUint8(offset, cmdTypeOrdinal); offset += 1;
    view.setUint32(offset, dataLength, false); offset += 4;
    view.setUint8(offset, status); offset += 1;
    view.setInt32(offset, screenNum, false);
    return buffer;
  }

  /**
   * 编码响应远程剪贴板命令
   */
  private static encodeResRemoteClipboardCmd(cmdData: Record<string, Object>): ArrayBuffer {
    const buffer = new ArrayBuffer(7);
    const view = new DataView(buffer);
    let offset = 0;
    view.setUint8(offset, 0x64); offset += 1;
    view.setUint8(offset, 0x33); offset += 1;
    const cmdTypeOrdinal = CmdCodec.getCmdTypeOrdinal(CmdType.ResRemoteClipboard);
    view.setUint8(offset, cmdTypeOrdinal); offset += 1;
    view.setUint32(offset, 0, false);
    return buffer;
  }

  /**
   * 编码屏幕捕获数据命令
   */
  private static encodeCaptureCmd(cmdData: Record<string, Object>): ArrayBuffer {
    const imageData = cmdData.imageData as string || '';
    const width = cmdData.width as number || 0;
    const height = cmdData.height as number || 0;
    const compressionMethod = cmdData.compressionMethod as number || 0;
    const encoder = CmdCodec.textEncoder;
    const imageDataBytes = encoder.encode(imageData);
    const dataLength = 4 + 4 + 4 + 4 + imageDataBytes.byteLength;
    const buffer = new ArrayBuffer(2 + 1 + 4 + dataLength);
    const view = new DataView(buffer);
    let offset = 0;
    view.setUint8(offset, 0x64); offset += 1;
    view.setUint8(offset, 0x33); offset += 1;
    const cmdTypeOrdinal = CmdCodec.getCmdTypeOrdinal(CmdType.Capture);
    view.setUint8(offset, cmdTypeOrdinal); offset += 1;
    view.setUint32(offset, dataLength, false); offset += 4;
    view.setInt32(offset, width, false); offset += 4;
    view.setInt32(offset, height, false); offset += 4;
    view.setInt32(offset, compressionMethod, false); offset += 4;
    view.setUint32(offset, imageDataBytes.byteLength, false); offset += 4;
    const imageDataView = new Uint8Array(buffer, offset);
    imageDataView.set(imageDataBytes);
    return buffer;
  }

  /**
   * 编码屏幕捕获配置命令
   */
  private static encodeCaptureConfigCmd(cmdData: Record<string, Object>): ArrayBuffer {
    const quantization = cmdData.quality as number || 6;
    const captureTick = cmdData.captureFrequency as number || 30;
    const captureColors = (cmdData.maxFps as number) === 1 ? 1 : 0;
    const dataLength = 4 + 4 + 2;
    const buffer = new ArrayBuffer(2 + 1 + 4 + dataLength);
    const view = new DataView(buffer);
    let offset = 0;
    view.setUint8(offset, 0x64); offset += 1;
    view.setUint8(offset, 0x33); offset += 1;
    const cmdTypeOrdinal = CmdCodec.getCmdTypeOrdinal(CmdType.CaptureConfig);
    view.setUint8(offset, cmdTypeOrdinal); offset += 1;
    view.setUint32(offset, dataLength, false); offset += 4;
    view.setInt32(offset, quantization, false); offset += 4;
    view.setInt32(offset, captureTick, false); offset += 4;
    view.setInt16(offset, captureColors, false);
    return buffer;
  }

  /**
   * 编码压缩配置命令
   * 与 Java 端 CmdCompressorConf 线格式一致：compressionMethod(1) + useCache(1) + cacheMaxSize(4) + cachePurgeSize(4)
   */
  private static encodeCompressorConfigCmd(cmdData: Record<string, Object>): ArrayBuffer {
    const compressionMethod = cmdData.compressionMethod as number || 0;
    const useCache = (cmdData.useCache as boolean) !== false ? 1 : 0;
    const cacheMaxSize = cmdData.cacheMaxSize as number || 1000;
    const cachePurgeSize = cmdData.cachePurgeSize as number || 500;
    const dataLength = 1 + 1 + 4 + 4;
    const buffer = new ArrayBuffer(2 + 1 + 4 + dataLength);
    const view = new DataView(buffer);
    let offset = 0;
    view.setUint8(offset, 0x64); offset += 1;
    view.setUint8(offset, 0x33); offset += 1;
    const cmdTypeOrdinal = CmdCodec.getCmdTypeOrdinal(CmdType.CompressorConfig);
    view.setUint8(offset, cmdTypeOrdinal); offset += 1;
    view.setUint32(offset, dataLength, false); offset += 4;
    view.setUint8(offset, compressionMethod & 0xFF); offset += 1;
    view.setUint8(offset, useCache); offset += 1;
    view.setInt32(offset, cacheMaxSize, false); offset += 4;
    view.setInt32(offset, cachePurgeSize, false);
    return buffer;
  }

  /**
   * 编码请求客户端信息命令
   */
  private static encodeReqCliInfoCmd(cmdData: Record<string, Object>): ArrayBuffer {
    const screenNum = cmdData.screenNum as number || 1;
    const osName = cmdData.osName as string || 'HarmonyOS';
    const encoder = CmdCodec.textEncoder;
    const osNameBytes = encoder.encode(osName);
    const dataLength = 4 + 4 + osNameBytes.byteLength;
    const buffer = new ArrayBuffer(2 + 1 + 4 + dataLength);
    const view = new DataView(buffer);
    let offset = 0;
    view.setUint8(offset, 0x64); offset += 1;
    view.setUint8(offset, 0x33); offset += 1;
    const cmdTypeOrdinal = CmdCodec.getCmdTypeOrdinal(CmdType.ReqCliInfo);
    view.setUint8(offset, cmdTypeOrdinal); offset += 1;
    view.setUint32(offset, dataLength, false); offset += 4;
    view.setInt32(offset, screenNum, false); offset += 4;
    view.setUint32(offset, osNameBytes.byteLength, false); offset += 4;
    const dataView = new Uint8Array(buffer, offset);
    dataView.set(osNameBytes);
    return buffer;
  }

  /**
   * 编码请求打开连接命令
   * 格式：deviceCode长度(4) + deviceCode
   */
  private static encodeReqOpenCmd(cmdData: Record<string, Object>): ArrayBuffer {
    const deviceCode = cmdData.deviceCode as string || '';
    const encoder = CmdCodec.textEncoder;
    const deviceCodeBytes = encoder.encode(deviceCode);
    const dataLength = 4 + deviceCodeBytes.byteLength;
    const buffer = new ArrayBuffer(2 + 1 + 4 + dataLength);
    const view = new DataView(buffer);
    let offset = 0;
    view.setUint8(offset, 0x64); offset += 1;
    view.setUint8(offset, 0x33); offset += 1;
    const cmdTypeOrdinal = CmdCodec.getCmdTypeOrdinal(CmdType.ReqOpen);
    view.setUint8(offset, cmdTypeOrdinal); offset += 1;
    view.setUint32(offset, dataLength, false); offset += 4;
    view.setUint32(offset, deviceCodeBytes.byteLength, false); offset += 4;
    const dataView = new Uint8Array(buffer, offset);
    dataView.set(deviceCodeBytes);
    return buffer;
  }

  /**
   * 编码请求屏幕捕获命令
   * 格式：deviceCode长度(4) + deviceCode + captureOp(1) + password长度(4) + password
   */
  private static encodeReqCaptureCmd(cmdData: Record<string, Object>): ArrayBuffer {
    const deviceCode = cmdData.deviceCode as string || '';
    const password = cmdData.password as string || '';
    const captureOp = cmdData.caputureOp as number || 0;
    const encoder = CmdCodec.textEncoder;
    const deviceCodeBytes = encoder.encode(deviceCode);
    const passwordBytes = encoder.encode(password);
    const dataLength = 4 + deviceCodeBytes.byteLength + 1 + 4 + passwordBytes.byteLength;
    const buffer = new ArrayBuffer(2 + 1 + 4 + dataLength);
    const view = new DataView(buffer);
    let offset = 0;
    view.setUint8(offset, 0x64); offset += 1;
    view.setUint8(offset, 0x33); offset += 1;
    const cmdTypeOrdinal = CmdCodec.getCmdTypeOrdinal(CmdType.ReqCapture);
    view.setUint8(offset, cmdTypeOrdinal); offset += 1;
    view.setUint32(offset, dataLength, false); offset += 4;
    view.setUint32(offset, deviceCodeBytes.byteLength, false); offset += 4;
    const dataView = new Uint8Array(buffer, offset);
    dataView.set(deviceCodeBytes); offset += deviceCodeBytes.byteLength;
    view.setUint8(offset, captureOp); offset += 1;
    view.setUint32(offset, passwordBytes.byteLength, false); offset += 4;
    const passwordView = new Uint8Array(buffer, offset);
    passwordView.set(passwordBytes);
    return buffer;
  }

  /**
   * 编码鼠标控制命令
   * 格式：x(2) + y(2) + info(4) + [rotations(4)]
   */
  private static encodeMouseControlCmd(cmdData: Record<string, Object>): ArrayBuffer {
    const x = cmdData.x as number || 0;
    const y = cmdData.y as number || 0;
    const action = cmdData.action as number || 0;
    const wheelDelta = cmdData.wheelDelta as number || 0;
    let info = 0;
    const isWheel = wheelDelta !== undefined && wheelDelta !== 0;
    if (isWheel) {
      info = 1 << 5;
    } else {
      if (action === 1) {
        info = (1 << 2) | 1;
      } else if (action === 2) {
        info = (1 << 2) | (1 << 1);
      }
    }
    const dataLength = isWheel ? 12 : 8;
    const buffer = new ArrayBuffer(2 + 1 + 4 + dataLength);
    const view = new DataView(buffer);
    let offset = 0;
    view.setUint8(offset, 0x64); offset += 1;
    view.setUint8(offset, 0x33); offset += 1;
    const cmdTypeOrdinal = CmdCodec.getCmdTypeOrdinal(CmdType.MouseControl);
    view.setUint8(offset, cmdTypeOrdinal); offset += 1;
    view.setUint32(offset, dataLength, false); offset += 4;
    view.setInt16(offset, x, false); offset += 2;
    view.setInt16(offset, y, false); offset += 2;
    view.setInt32(offset, info, false); offset += 4;
    if (isWheel) {
      view.setInt32(offset, wheelDelta, false);
    }
    return buffer;
  }

  /**
   * 编码键盘控制命令
   * 格式：info(4) + keyCode(4) + keyChar(2)
   */
  private static encodeKeyControlCmd(cmdData: Record<string, Object>): ArrayBuffer {
    const keyCode = cmdData.keyCode as number || 0;
    const pressed = cmdData.pressed as boolean ? 1 : 2;
    const info = pressed;
    const keyChar = ' ';
    const dataLength = 10;
    const buffer = new ArrayBuffer(2 + 1 + 4 + dataLength);
    const view = new DataView(buffer);
    let offset = 0;
    view.setUint8(offset, 0x64); offset += 1;
    view.setUint8(offset, 0x33); offset += 1;
    const cmdTypeOrdinal = CmdCodec.getCmdTypeOrdinal(CmdType.KeyControl);
    view.setUint8(offset, cmdTypeOrdinal); offset += 1;
    view.setUint32(offset, dataLength, false); offset += 4;
    view.setInt32(offset, info, false); offset += 4;
    view.setInt32(offset, keyCode, false); offset += 4;
    const encoder = CmdCodec.textEncoder;
    const keyCharBytes = encoder.encode(keyChar);
    if (keyCharBytes.byteLength >= 2) {
      view.setUint16(offset, (keyCharBytes[0] << 8) | keyCharBytes[1], false);
    } else if (keyCharBytes.byteLength === 1) {
      view.setUint16(offset, keyCharBytes[0], false);
    }
    return buffer;
  }

  /**
   * 编码请求远程剪贴板命令
   * 格式：deviceCode长度(4) + deviceCode
   */
  private static encodeClipboardRequestCmd(cmdData: Record<string, Object>): ArrayBuffer {
    const deviceCode = cmdData.deviceCode as string || '';
    const encoder = CmdCodec.textEncoder;
    const deviceCodeBytes = encoder.encode(deviceCode);
    const dataLength = 4 + deviceCodeBytes.byteLength;
    const buffer = new ArrayBuffer(2 + 1 + 4 + dataLength);
    const view = new DataView(buffer);
    let offset = 0;
    view.setUint8(offset, 0x64); offset += 1;
    view.setUint8(offset, 0x33); offset += 1;
    const cmdTypeOrdinal = CmdCodec.getCmdTypeOrdinal(CmdType.ReqRemoteClipboard);
    view.setUint8(offset, cmdTypeOrdinal); offset += 1;
    view.setUint32(offset, dataLength, false); offset += 4;
    view.setUint32(offset, deviceCodeBytes.byteLength, false); offset += 4;
    const dataView = new Uint8Array(buffer, offset);
    dataView.set(deviceCodeBytes);
    return buffer;
  }

  /**
   * 编码文本剪贴板命令
   * 格式：payload长度(4) + payload + controlType长度(4) + controlType
   */
  private static encodeClipboardTextCmd(cmdData: Record<string, Object>): ArrayBuffer {
    const text = cmdData.text as string || '';
    const controlType = cmdData.controlType as string || '';
    const encoder = CmdCodec.textEncoder;
    const payloadBytes = encoder.encode(text);
    const controlTypeBytes = encoder.encode(controlType);
    const dataLength = 4 + payloadBytes.byteLength + 4 + controlTypeBytes.byteLength;
    const buffer = new ArrayBuffer(2 + 1 + 4 + dataLength);
    const view = new DataView(buffer);
    let offset = 0;
    view.setUint8(offset, 0x64); offset += 1;
    view.setUint8(offset, 0x33); offset += 1;
    const cmdTypeOrdinal = CmdCodec.getCmdTypeOrdinal(CmdType.ClipboardText);
    view.setUint8(offset, cmdTypeOrdinal); offset += 1;
    view.setUint32(offset, dataLength, false); offset += 4;
    view.setUint32(offset, payloadBytes.byteLength, false); offset += 4;
    const payloadView = new Uint8Array(buffer, offset);
    payloadView.set(payloadBytes); offset += payloadBytes.byteLength;
    view.setUint32(offset, controlTypeBytes.byteLength, false); offset += 4;
    const controlTypeView = new Uint8Array(buffer, offset);
    controlTypeView.set(controlTypeBytes);
    return buffer;
  }

  /**
   * 编码文件传输剪贴板命令
   * 格式：deviceCode长度(4) + deviceCode + controlType长度(4) + controlType
   */
  private static encodeClipboardTransferCmd(cmdData: Record<string, Object>): ArrayBuffer {
    const deviceCode = cmdData.deviceCode as string || '';
    const controlType = cmdData.controlType as string || '';
    const encoder = CmdCodec.textEncoder;
    const deviceCodeBytes = encoder.encode(deviceCode);
    const controlTypeBytes = encoder.encode(controlType);
    const dataLength = 4 + deviceCodeBytes.byteLength + 4 + controlTypeBytes.byteLength;
    const buffer = new ArrayBuffer(2 + 1 + 4 + dataLength);
    const view = new DataView(buffer);
    let offset = 0;
    view.setUint8(offset, 0x64); offset += 1;
    view.setUint8(offset, 0x33); offset += 1;
    const cmdTypeOrdinal = CmdCodec.getCmdTypeOrdinal(CmdType.ClipboardTransfer);
    view.setUint8(offset, cmdTypeOrdinal); offset += 1;
    view.setUint32(offset, dataLength, false); offset += 4;
    view.setUint32(offset, deviceCodeBytes.byteLength, false); offset += 4;
    const dataView = new Uint8Array(buffer, offset);
    dataView.set(deviceCodeBytes); offset += deviceCodeBytes.byteLength;
    view.setUint32(offset, controlTypeBytes.byteLength, false); offset += 4;
    const controlTypeView = new Uint8Array(buffer, offset);
    controlTypeView.set(controlTypeBytes);
    return buffer;
  }

  /**
   * 编码选择屏幕命令
   * 格式：screenIndex(4)
   */
  private static encodeSelectScreenCmd(cmdData: Record<string, Object>): ArrayBuffer {
    const screenIndex = cmdData.screenIndex as number || 0;
    const dataLength = 4;
    const buffer = new ArrayBuffer(2 + 1 + 4 + dataLength);
    const view = new DataView(buffer);
    let offset = 0;
    view.setUint8(offset, 0x64); offset += 1;
    view.setUint8(offset, 0x33); offset += 1;
    const cmdTypeOrdinal = CmdCodec.getCmdTypeOrdinal(CmdType.SelectScreen);
    view.setUint8(offset, cmdTypeOrdinal); offset += 1;
    view.setUint32(offset, dataLength, false); offset += 4;
    view.setInt32(offset, screenIndex, false);
    return buffer;
  }

  /**
   * 编码修改密码命令
   * 格式：password长度(4) + password
   */
  private static encodeChangePwdCmd(cmdData: Record<string, Object>): ArrayBuffer {
    const password = cmdData.password as string || '';
    const encoder = CmdCodec.textEncoder;
    const passwordBytes = encoder.encode(password);
    const dataLength = 4 + passwordBytes.byteLength;
    const buffer = new ArrayBuffer(2 + 1 + 4 + dataLength);
    const view = new DataView(buffer);
    let offset = 0;
    view.setUint8(offset, 0x64); offset += 1;
    view.setUint8(offset, 0x33); offset += 1;
    const cmdTypeOrdinal = CmdCodec.getCmdTypeOrdinal(CmdType.ChangePwd);
    view.setUint8(offset, cmdTypeOrdinal); offset += 1;
    view.setUint32(offset, dataLength, false); offset += 4;
    view.setUint32(offset, passwordBytes.byteLength, false); offset += 4;
    const dataView = new Uint8Array(buffer, offset);
    dataView.set(passwordBytes);
    return buffer;
  }

  /**
   * 解码二进制数据为命令
   * 只支持二进制格式：魔数(1字节) + 命令类型(1字节) + 数据长度(4字节) + 数据体
   */
  static decode(buffer: ArrayBuffer): ConcreteCmd | undefined {
    try {
      if (buffer.byteLength < 7) {
        return undefined;
      }
      const view = new DataView(buffer);
      const magic0 = view.getUint8(0);
      const magic1 = view.getUint8(1);
      if (magic0 !== 0x64 || magic1 !== 0x33) {
        return undefined;
      }
      const cmdTypeOrdinal = view.getUint8(2);
      const dataLength = view.getUint32(3, false);
      if (buffer.byteLength < 7 + dataLength) {
        return undefined;
      }
      const result = CmdCodec.decodeBinaryCommand(cmdTypeOrdinal, buffer.slice(7, 7 + dataLength));
      return result;
    } catch (error) {
      console.error('CmdCodec: Failed to decode command', error);
      return undefined;
    }
  }

  /**
   * 解码二进制格式的命令，与Java客户端的NettyDecoder保持一致
   */
  private static decodeBinaryCommand(cmdTypeOrdinal: number, dataBuffer: ArrayBuffer): ConcreteCmd | undefined {
    try {
      // 根据命令类型解码
      const cmdType = CmdCodec.getCmdTypeFromOrdinal(cmdTypeOrdinal);
      
      if (!cmdType) {
        console.error(`CmdCodec: Unknown command type ordinal: ${cmdTypeOrdinal}`);
        return undefined;
      }

      switch (cmdType) {
        case CmdType.ResCliInfo:
          return CmdCodec.decodeResCliInfoCmd(dataBuffer);
        case CmdType.ResPong:
          // 心跳响应命令没有数据体
          return CmdUtils.createPongCmd();
        case CmdType.ResOpen:
          return CmdCodec.decodeResOpenCmd(dataBuffer);
        case CmdType.ResCapture:
          return CmdCodec.decodeResCaptureCmd(dataBuffer);
        case CmdType.ResRemoteClipboard:
          return CmdUtils.createClipboardResponseCmd([]);
        case CmdType.Capture:
          return CmdCodec.decodeCaptureCmd(dataBuffer);
        case CmdType.CaptureConfig:
          return CmdCodec.decodeCaptureConfigCmd(dataBuffer);
        case CmdType.CompressorConfig:
          return CmdCodec.decodeCompressorConfigCmd(dataBuffer);
        case CmdType.KeyControl:
          return CmdCodec.decodeKeyControlCmd(dataBuffer);
        case CmdType.MouseControl:
          return CmdCodec.decodeMouseControlCmd(dataBuffer);
        case CmdType.ClipboardText:
          return CmdCodec.decodeClipboardTextCmd(dataBuffer);
        case CmdType.ClipboardTransfer:
          return CmdCodec.decodeClipboardTransferCmd(dataBuffer);
        case CmdType.ReqPing:
          return CmdUtils.createPingCmd();
        case CmdType.ReqOpen:
          return CmdCodec.decodeReqOpenCmd(dataBuffer);
        case CmdType.ReqCapture:
          return CmdCodec.decodeReqCaptureCmd(dataBuffer);
        case CmdType.ReqRemoteClipboard:
          return CmdUtils.createClipboardRequestCmd('');
        case CmdType.ReqCliInfo:
          return CmdCodec.decodeReqCliInfoCmd(dataBuffer);
        case CmdType.SelectScreen:
          return CmdCodec.decodeSelectScreenCmd(dataBuffer);
        case CmdType.ChangePwd:
          return CmdCodec.decodeChangePwdCmd(dataBuffer);
        default:
          console.error(`CmdCodec: Unsupported binary command type: ${cmdType}`);
          return undefined;
      }
    } catch (error) {
      console.error('CmdCodec: Failed to decode binary command', error);
      return undefined;
    }
  }

  /**
   * 从ordinal值获取命令类型
   */
  private static getCmdTypeFromOrdinal(ordinal: number): CmdType | undefined {
    switch (ordinal) {
      case 0: return CmdType.ReqPing;
      case 1: return CmdType.ReqOpen;
      case 2: return CmdType.ReqCapture;
      case 3: return CmdType.ReqRemoteClipboard;
      case 4: return CmdType.ResOpen;
      case 5: return CmdType.ResCliInfo;
      case 6: return CmdType.ResCapture;
      case 7: return CmdType.ResPong;
      case 8: return CmdType.ResRemoteClipboard;
      case 9: return CmdType.Capture;
      case 10: return CmdType.CompressorConfig;
      case 11: return CmdType.CaptureConfig;
      case 12: return CmdType.KeyControl;
      case 13: return CmdType.MouseControl;
      case 14: return CmdType.ClipboardText;
      case 15: return CmdType.ClipboardTransfer;
      case 16: return CmdType.ReqCliInfo;
      case 17: return CmdType.SelectScreen;
      case 18: return CmdType.ChangePwd;
      default: return undefined;
    }
  }

  /**
   * 解码 ResCliInfo 命令（二进制格式）
   * 格式：deviceCode长度(4) + deviceCode + password长度(4) + password
   */
  private static decodeResCliInfoCmd(dataBuffer: ArrayBuffer): ConcreteCmd | undefined {
    try {
      console.info('CmdCodec.decodeResCliInfoCmd: Starting, dataBuffer size=' + dataBuffer.byteLength);
      
      if (dataBuffer.byteLength < 8) {
        console.error('CmdCodec: ResCliInfo data buffer too short, need at least 8, have ' + dataBuffer.byteLength);
        return undefined;
      }

      const view = new DataView(dataBuffer);
      let offset = 0;

      // 读取 deviceCode 长度
      const deviceCodeLength = view.getUint32(offset, false);
      offset += 4;
      console.info('CmdCodec.decodeResCliInfoCmd: deviceCodeLength=' + deviceCodeLength);

      // 检查是否有足够的字节
      if (offset + deviceCodeLength > dataBuffer.byteLength) {
        console.error('CmdCodec: ResCliInfo deviceCode incomplete, need ' + deviceCodeLength + ' bytes at offset ' + offset);
        return undefined;
      }

      // 读取 deviceCode
      const deviceCodeBytes = dataBuffer.slice(offset, offset + deviceCodeLength);
      const decoder = CmdCodec.textDecoder;
      const deviceCode = decoder.decodeToString(new Uint8Array(deviceCodeBytes));
      offset += deviceCodeLength;
      console.info('CmdCodec.decodeResCliInfoCmd: deviceCode=' + deviceCode);

      // 读取 password 长度
      if (offset + 4 > dataBuffer.byteLength) {
        console.error('CmdCodec: ResCliInfo password length incomplete');
        return undefined;
      }
      const passwordLength = view.getUint32(offset, false);
      offset += 4;
      console.info('CmdCodec.decodeResCliInfoCmd: passwordLength=' + passwordLength);

      // 读取 password
      if (offset + passwordLength > dataBuffer.byteLength) {
        console.error('CmdCodec: ResCliInfo password incomplete');
        return undefined;
      }
      const passwordBytes = dataBuffer.slice(offset, offset + passwordLength);
      const password = decoder.decodeToString(new Uint8Array(passwordBytes));

      console.log(`CmdCodec: Decoded ResCliInfo command - deviceCode: ${deviceCode}, password: ${password}`);

      // 创建命令对象
      const result = CmdUtils.createResCliInfoCmd(deviceCode, password);
      console.info('CmdCodec.decodeResCliInfoCmd: Created command successfully');
      return result;
    } catch (error) {
      console.error('CmdCodec: Failed to decode ResCliInfo command', error);
      return undefined;
    }
  }

  /**
   * 解码 ResOpen 命令（二进制格式）
   * 格式：code(1)
   */
  private static decodeResOpenCmd(dataBuffer: ArrayBuffer): ConcreteCmd | undefined {
    try {
      if (dataBuffer.byteLength < 1) {
        console.error('CmdCodec: ResOpen data buffer too short');
        return undefined;
      }

      const view = new DataView(dataBuffer);
      const code = view.getUint8(0);
      
      console.log(`CmdCodec: Decoded ResOpen command - code: ${code}`);
      
      // 将数字转换为OpenStatus类型
      // 注意：Java服务器端定义：OK=0, OFFLINE=5, CONTROL=4
      let status: OpenStatus = 'OK';
      switch (code) {
        case 0:
          status = 'OK';
          break;
        case 5:
          status = 'OFFLINE';
          break;
        case 4:
          status = 'CONTROL';
          break;
      }

      // 创建命令对象
      return CmdUtils.createOpenResponseCmd(status);
    } catch (error) {
      console.error('CmdCodec: Failed to decode ResOpen command', error);
      return undefined;
    }
  }

  /**
   * 解码 ResCapture 命令（二进制格式）
   * 格式：code(1) + screenNum(4)
   */
  private static decodeResCaptureCmd(dataBuffer: ArrayBuffer): ConcreteCmd | undefined {
    try {
      if (dataBuffer.byteLength < 5) {
        console.error('CmdCodec: ResCapture data buffer too short');
        return undefined;
      }

      const view = new DataView(dataBuffer);
      let offset = 0;
      
      // 读取 code
      const code = view.getUint8(offset);
      offset += 1;
      
      // 读取 screenNum
      const screenNum = view.getInt32(offset, false);
      
      // 将数字转换为CaptureStatus类型
      let status: CaptureStatus = 'OK';
      switch (code) {
        case 0: // START
          status = 'OK';
          break;
        case 4: // OFFLINE
          status = 'OFFLINE';
          break;
        case 6: // PWDERROR
          status = 'PWDERROR';
          break;
        case 5: // CONTROL
          status = 'CONTROL';
          break;
        case 1: // STOP
        case 2: // STOP_BYCONTROLLED
        case 3: // STOP_CHANNELINACTIVE
          status = 'STOP';
          break;
      }

      console.log(`CmdCodec: Decoded ResCapture command - code: ${code}, screenNum: ${screenNum}, status: ${status}`);

      // 创建命令对象
      return CmdUtils.createCaptureResponseCmd(status);
    } catch (error) {
      console.error('CmdCodec: Failed to decode ResCapture command', error);
      return undefined;
    }
  }

  /**
   * 解码 Capture 命令（二进制格式）
   * 格式：id(4) + compressionMethod(1) + hasCompressionConfig(1) + [compressionConfig(10)] + payloadLength(4) + payload
   */
  private static decodeCaptureCmd(dataBuffer: ArrayBuffer): ConcreteCmd | undefined {
    try {
      if (dataBuffer.byteLength < 10) {
        console.error('CmdCodec: Capture data buffer too short');
        return undefined;
      }

      const view = new DataView(dataBuffer);
      let offset = 0;

      // 读取 id
      const id = view.getInt32(offset, false);
      offset += 4;

      // 读取 compressionMethod (enum ordinal)
      const compressionMethodOrdinal = view.getUint8(offset);
      offset += 1;

      // 读取 hasCompressionConfig
      const hasCompressionConfig = view.getUint8(offset) === 1;
      offset += 1;

      // 解析压缩配置（如果有）
      let compressionConfig: CompressionConfig | undefined = undefined;
      if (hasCompressionConfig) {
        if (dataBuffer.byteLength < offset + 10) {
          console.error('CmdCodec: Capture compression config incomplete');
          return undefined;
        }
        
        // 解析压缩配置（与 CmdCompressorConf 一致）
        const method = view.getUint8(offset);
        offset += 1;
        const useCache = view.getUint8(offset) === 1;
        offset += 1;
        const cacheMaxSize = view.getInt32(offset, false);
        offset += 4;
        const cachePurgeSize = view.getInt32(offset, false);
        offset += 4;
        
        const config: CompressionConfig = {
          method,
          useCache,
          cacheMaxSize,
          cachePurgeSize
        };
        compressionConfig = config;
        
        console.log(`CmdCodec: Decoded Capture compression config - method: ${method}, useCache: ${useCache}, cacheMaxSize: ${cacheMaxSize}, cachePurgeSize: ${cachePurgeSize}`);
      }

      // 读取 payload 长度
      if (dataBuffer.byteLength < offset + 4) {
        console.error('CmdCodec: Capture payload length incomplete');
        return undefined;
      }
      const payloadLength = view.getUint32(offset, false);
      offset += 4;

      if (payloadLength === 0) {
        console.error('CmdCodec: Capture payload length is zero');
        return undefined;
      }

      // 检查数据长度
      if (dataBuffer.byteLength < offset + payloadLength) {
        console.error(`CmdCodec: Capture data buffer incomplete - expected ${payloadLength}, got ${dataBuffer.byteLength - offset}`);
        return undefined;
      }

      // 读取 payload (image data)
      const imageData = dataBuffer.slice(offset, offset + payloadLength);

      console.log(`CmdCodec: Decoded Capture command - id: ${id}, compressionMethod: ${compressionMethodOrdinal}, payloadSize: ${payloadLength}, hasConfig: ${hasCompressionConfig}`);

      // 创建命令对象（不需要width和height，它们从解压后的Capture获取）
      return CmdUtils.createCaptureDataCmd(imageData, compressionMethodOrdinal, compressionConfig);
    } catch (error) {
      console.error('CmdCodec: Failed to decode Capture command', error);
      return undefined;
    }
  }

  /**
   * 解码 CaptureConfig 命令（二进制格式）
   * 格式：width(4) + height(4) + fps(4)
   */
  private static decodeCaptureConfigCmd(dataBuffer: ArrayBuffer): ConcreteCmd | undefined {
    try {
      if (dataBuffer.byteLength < 10) {
        console.error('CmdCodec: CaptureConfig data buffer too short');
        return undefined;
      }

      const view = new DataView(dataBuffer);
      let offset = 0;
      
      const quantization = view.getInt32(offset, false);
      offset += 4;
      
      const captureTick = view.getInt32(offset, false);
      offset += 4;
      
      const captureColors = view.getInt16(offset, false) === 1;

      // 创建命令对象 - 使用 quality 存储 quantization, captureFrequency 存储 captureTick, maxFps 作为 colors 标志
      return CmdUtils.createCaptureConfigCmd('', captureTick, quantization, captureColors ? 1 : 0);
    } catch (error) {
      console.error('CmdCodec: Failed to decode CaptureConfig command', error);
      return undefined;
    }
  }

  /**
   * 解码 CompressorConfig 命令（二进制格式）
   * 与 Java 端 CmdCompressorConf 线格式一致：compressionMethod(1) + useCache(1) + cacheMaxSize(4) + cachePurgeSize(4)
   */
  private static decodeCompressorConfigCmd(dataBuffer: ArrayBuffer): ConcreteCmd | undefined {
    try {
      if (dataBuffer.byteLength < 10) {
        console.error('CmdCodec: CompressorConfig data buffer too short');
        return undefined;
      }

      const view = new DataView(dataBuffer);
      let offset = 0;
      
      const compressionMethod = view.getUint8(offset);
      offset += 1;
      
      const useCache = view.getUint8(offset) === 1;
      offset += 1;
      
      const cacheMaxSize = view.getInt32(offset, false);
      offset += 4;
      
      const cachePurgeSize = view.getInt32(offset, false);

      // 将数字转换为CompressionMethod枚举（与Java端一致：0=NONE, 1=ZIP, 2=XZ, 3=ZSTD）
      let compressionMethodEnum: CompressionMethod = CompressionMethod.ZSTD;
      if (compressionMethod === 0) {
        compressionMethodEnum = CompressionMethod.NONE;
      } else if (compressionMethod === 1) {
        compressionMethodEnum = CompressionMethod.ZIP;
      } else if (compressionMethod === 2) {
        compressionMethodEnum = CompressionMethod.XZ;
      } else if (compressionMethod === 3) {
        compressionMethodEnum = CompressionMethod.ZSTD;
      }
      
      // 创建命令对象
      return CmdUtils.createCompressorConfigCmd('', compressionMethodEnum, 0, useCache, cacheMaxSize, cachePurgeSize);
    } catch (error) {
      console.error('CmdCodec: Failed to decode CompressorConfig command', error);
      return undefined;
    }
  }

  /**
   * 解码 KeyControl 命令（二进制格式）
   * 格式：info(4) + keyCode(4) + keyChar(2)
   */
  private static decodeKeyControlCmd(dataBuffer: ArrayBuffer): ConcreteCmd | undefined {
    try {
      if (dataBuffer.byteLength < 10) {
        console.error('CmdCodec: KeyControl data buffer too short');
        return undefined;
      }

      const view = new DataView(dataBuffer);
      let offset = 0;

      // 读取 info
      const info = view.getInt32(offset, false);
      offset += 4;

      // 读取 keyCode
      const keyCode = view.getInt32(offset, false);
      offset += 4;

      // 读取 keyChar
      const keyCharCode = view.getUint16(offset, false);
      const keyChar = String.fromCharCode(keyCharCode);

      // 解析pressed
      const pressed = (info & 1) === 1;

      // 创建命令对象（使用空的deviceCode，因为Java协议中没有这个字段
      return CmdUtils.createKeyControlCmd('', keyCode, pressed);
    } catch (error) {
      console.error('CmdCodec: Failed to decode KeyControl command', error);
      return undefined;
    }
  }

  /**
   * 解码 MouseControl 命令（二进制格式）
   * 格式：x(2) + y(2) + info(4) + [rotations(4)]
   */
  private static decodeMouseControlCmd(dataBuffer: ArrayBuffer): ConcreteCmd | undefined {
    try {
      if (dataBuffer.byteLength < 8) {
        console.error('CmdCodec: MouseControl data buffer too short');
        return undefined;
      }

      const view = new DataView(dataBuffer);
      let offset = 0;

      // 读取 x (short)
      const x = view.getInt16(offset, false);
      offset += 2;

      // 读取 y (short)
      const y = view.getInt16(offset, false);
      offset += 2;

      // 读取 info
      const info = view.getInt32(offset, false);
      offset += 4;

      // 检查是否是wheel事件
      const isWheel = (info & (1 << 5)) === (1 << 5);
      let wheelDelta: number | undefined = undefined;
      if (isWheel && dataBuffer.byteLength >= offset + 4) {
        wheelDelta = view.getInt32(offset, false);
      }

      // 简单解析action映射
      let action = 0;
      if (!isWheel) {
        const isPressed = (info & 1) === 1;
        const isButton1 = (info & (1 << 2)) === (1 << 2);
        if (isButton1) {
          action = isPressed ? 1 : 2;
        }
      }

      // 创建命令对象（使用空的deviceCode，因为Java协议中没有这个字段
      return CmdUtils.createMouseControlCmd('', x, y, action, wheelDelta);
    } catch (error) {
      console.error('CmdCodec: Failed to decode MouseControl command', error);
      return undefined;
    }
  }

  /**
   * 解码 ClipboardText 命令（二进制格式）
   * 格式：payload长度(4) + payload + controlType长度(4) + controlType
   */
  private static decodeClipboardTextCmd(dataBuffer: ArrayBuffer): ConcreteCmd | undefined {
    try {
      if (dataBuffer.byteLength < 8) {
        console.error('CmdCodec: ClipboardText data buffer too short');
        return undefined;
      }

      const view = new DataView(dataBuffer);
      let offset = 0;

      // 读取 payload 长度
      const payloadLength = view.getUint32(offset, false);
      offset += 4;

      // 读取 payload
      const payloadBytes = dataBuffer.slice(offset, offset + payloadLength);
      const decoder = CmdCodec.textDecoder;
      const payload = decoder.decodeToString(new Uint8Array(payloadBytes));
      offset += payloadLength;

      // 读取 controlType 长度
      const controlTypeLength = view.getUint32(offset, false);
      offset += 4;

      // 检查数据长度
      if (dataBuffer.byteLength < offset + controlTypeLength) {
        console.error('CmdCodec: ClipboardText controlType buffer incomplete');
        return undefined;
      }

      // 读取 controlType
      const controlTypeBytes = dataBuffer.slice(offset, offset + controlTypeLength);
      const controlType = decoder.decodeToString(new Uint8Array(controlTypeBytes));

      console.log(`CmdCodec: Decoded ClipboardText command - payload: ${payload}, controlType: ${controlType}`);

      // 创建命令对象（使用空的deviceCode，因为Java协议中没有这个字段
      return CmdUtils.createClipboardTextCmd('', payload);
    } catch (error) {
      console.error('CmdCodec: Failed to decode ClipboardText command', error);
      return undefined;
    }
  }

  /**
   * 解码 ClipboardTransfer 命令（二进制格式）
   * 格式：deviceCode长度(4) + deviceCode + controlType长度(4) + controlType
   */
  private static decodeClipboardTransferCmd(dataBuffer: ArrayBuffer): ConcreteCmd | undefined {
    try {
      if (dataBuffer.byteLength < 8) {
        console.error('CmdCodec: ClipboardTransfer data buffer too short');
        return undefined;
      }

      const view = new DataView(dataBuffer);
      let offset = 0;

      // 读取 deviceCode 长度
      const deviceCodeLength = view.getUint32(offset, false);
      offset += 4;

      // 读取 deviceCode
      const deviceCodeBytes = dataBuffer.slice(offset, offset + deviceCodeLength);
      const decoder = CmdCodec.textDecoder;
      const deviceCode = decoder.decodeToString(new Uint8Array(deviceCodeBytes));
      offset += deviceCodeLength;

      // 读取 controlType 长度
      const controlTypeLength = view.getUint32(offset, false);
      offset += 4;

      // 检查数据长度
      if (dataBuffer.byteLength < offset + controlTypeLength) {
        console.error('CmdCodec: ClipboardTransfer controlType buffer incomplete');
        return undefined;
      }

      // 读取 controlType
      const controlTypeBytes = dataBuffer.slice(offset, offset + controlTypeLength);
      const controlType = decoder.decodeToString(new Uint8Array(controlTypeBytes));

      console.log(`CmdCodec: Decoded ClipboardTransfer command - deviceCode: ${deviceCode}, controlType: ${controlType}`);

      // 创建命令对象
      return CmdUtils.createClipboardTransferCmd(deviceCode, '', '');
    } catch (error) {
      console.error('CmdCodec: Failed to decode ClipboardTransfer command', error);
      return undefined;
    }
  }

  /**
   * 解码 ReqOpen 命令（二进制格式）
   * 格式：deviceCode长度(4) + deviceCode
   */
  private static decodeReqOpenCmd(dataBuffer: ArrayBuffer): ConcreteCmd | undefined {
    try {
      if (dataBuffer.byteLength < 4) {
        console.error('CmdCodec: ReqOpen data buffer too short');
        return undefined;
      }

      const view = new DataView(dataBuffer);
      let offset = 0;

      // 读取 deviceCode 长度
      const deviceCodeLength = view.getUint32(offset, false);
      offset += 4;

      // 检查数据长度
      if (dataBuffer.byteLength < offset + deviceCodeLength) {
        console.error('CmdCodec: ReqOpen data buffer incomplete');
        return undefined;
      }

      // 读取 deviceCode
      const deviceCodeBytes = dataBuffer.slice(offset, offset + deviceCodeLength);
      const decoder = CmdCodec.textDecoder;
      const deviceCode = decoder.decodeToString(new Uint8Array(deviceCodeBytes));

      // 创建命令对象
      return CmdUtils.createOpenCmd(deviceCode);
    } catch (error) {
      console.error('CmdCodec: Failed to decode ReqOpen command', error);
      return undefined;
    }
  }

  /**
   * 解码 ReqCapture 命令（二进制格式）
   * 格式：deviceCode长度(4) + deviceCode + captureOp(1) + password长度(4) + password
   */
  private static decodeReqCaptureCmd(dataBuffer: ArrayBuffer): ConcreteCmd | undefined {
    try {
      if (dataBuffer.byteLength < 9) {
        console.error('CmdCodec: ReqCapture data buffer too short');
        return undefined;
      }

      const view = new DataView(dataBuffer);
      let offset = 0;

      // 读取 deviceCode 长度
      const deviceCodeLength = view.getUint32(offset, false);
      offset += 4;

      // 读取 deviceCode
      const deviceCodeBytes = dataBuffer.slice(offset, offset + deviceCodeLength);
      const decoder = CmdCodec.textDecoder;
      const deviceCode = decoder.decodeToString(new Uint8Array(deviceCodeBytes));
      offset += deviceCodeLength;

      // 读取 captureOp
      const captureOp = view.getUint8(offset);
      offset += 1;

      // 读取 password 长度
      const passwordLength = view.getUint32(offset, false);
      offset += 4;

      // 读取 password
      const passwordBytes = dataBuffer.slice(offset, offset + passwordLength);
      const password = decoder.decodeToString(new Uint8Array(passwordBytes));

      // 创建命令对象
      return CmdUtils.createCaptureCmd(deviceCode, password, captureOp);
    } catch (error) {
      console.error('CmdCodec: Failed to decode ReqCapture command', error);
      return undefined;
    }
  }

  /**
   * 解码 ReqCliInfo 命令（二进制格式）
   * 格式：screenNum(4) + osName长度(4) + osName
   */
  private static decodeReqCliInfoCmd(dataBuffer: ArrayBuffer): ConcreteCmd | undefined {
    try {
      if (dataBuffer.byteLength < 8) {
        console.error('CmdCodec: ReqCliInfo data buffer too short');
        return undefined;
      }

      const view = new DataView(dataBuffer);
      let offset = 0;

      // 读取 screenNum
      const screenNum = view.getInt32(offset, false);
      offset += 4;

      // 读取 osName 长度
      const osNameLength = view.getUint32(offset, false);
      offset += 4;

      // 检查数据长度
      if (dataBuffer.byteLength < offset + osNameLength) {
        console.error('CmdCodec: ReqCliInfo data buffer incomplete');
        return undefined;
      }

      // 读取 osName
      const osNameBytes = dataBuffer.slice(offset, offset + osNameLength);
      const decoder = CmdCodec.textDecoder;
      const osName = decoder.decodeToString(new Uint8Array(osNameBytes));

      // 创建命令对象
      return CmdUtils.createReqCliInfoCmd(screenNum, osName);
    } catch (error) {
      console.error('CmdCodec: Failed to decode ReqCliInfo command', error);
      return undefined;
    }
  }

  /**
   * 解码 SelectScreen 命令（二进制格式）
   * 格式：screenIndex(4)
   */
  private static decodeSelectScreenCmd(dataBuffer: ArrayBuffer): ConcreteCmd | undefined {
    try {
      if (dataBuffer.byteLength < 4) {
        console.error('CmdCodec: SelectScreen data buffer too short');
        return undefined;
      }

      const view = new DataView(dataBuffer);
      const screenIndex = view.getInt32(0, false);

      // 创建命令对象
      return CmdUtils.createSelectScreenCmd('', screenIndex);
    } catch (error) {
      console.error('CmdCodec: Failed to decode SelectScreen command', error);
      return undefined;
    }
  }

  /**
   * 解码 ChangePwd 命令（二进制格式）
   * 格式：password长度(4) + password
   */
  private static decodeChangePwdCmd(dataBuffer: ArrayBuffer): ConcreteCmd | undefined {
    try {
      if (dataBuffer.byteLength < 4) {
        console.error('CmdCodec: ChangePwd data buffer too short');
        return undefined;
      }

      const view = new DataView(dataBuffer);
      let offset = 0;

      // 读取 password 长度
      const passwordLength = view.getUint32(offset, false);
      offset += 4;

      // 检查数据长度
      if (dataBuffer.byteLength < offset + passwordLength) {
        console.error('CmdCodec: ChangePwd data buffer incomplete');
        return undefined;
      }

      // 读取 password
      const passwordBytes = dataBuffer.slice(offset, offset + passwordLength);
      const decoder = CmdCodec.textDecoder;
      const password = decoder.decodeToString(new Uint8Array(passwordBytes));

      // 创建命令对象
      return CmdUtils.createChangePwdCmd('', '', password);
    } catch (error) {
      console.error('CmdCodec: Failed to decode ChangePwd command', error);
      return undefined;
    }
  }

  /**
   * 从流式缓冲区中提取命令
   * 返回 [剩余缓冲区, 命令数组]
   * 只支持二进制格式：魔数(1字节) + 命令类型(1字节) + 数据长度(4字节) + 数据体
   */
  private static readonly MAX_CMD_DATA_LENGTH: number = 10 * 1024 * 1024;
  private static readonly MAX_CMD_TYPE_ORDINAL: number = 18;

  static extractCommands(buffer: ArrayBuffer): ExtractCommandsResult {
    const commands: ConcreteCmd[] = [];
    let readOffset = 0;
    const totalLength = new Uint8Array(buffer).length;
    const view = new Uint8Array(buffer);

    try {
      while (readOffset + 7 <= totalLength) {
        if (view[readOffset] === 0x64 && view[readOffset + 1] === 0x33) {
          const headerView = new DataView(buffer, readOffset, totalLength - readOffset);
          const cmdTypeOrdinal = headerView.getUint8(2);
          const wireSize = headerView.getUint32(3, false);

          if (cmdTypeOrdinal <= CmdCodec.MAX_CMD_TYPE_ORDINAL && wireSize <= CmdCodec.MAX_CMD_DATA_LENGTH) {
            const frameLength = 7 + wireSize;
            if (readOffset + frameLength <= totalLength) {
              const cmdBuffer = buffer.slice(readOffset, readOffset + frameLength);
              const cmd = CmdCodec.decode(cmdBuffer);
              if (cmd) {
                commands.push(cmd);
                readOffset += frameLength;
                continue;
              }
            } else {
              break;
            }
          }
        }
        readOffset += 1;
      }

      const remaining = readOffset < totalLength ? buffer.slice(readOffset) : new ArrayBuffer(0);
      return { remainingBuffer: remaining, commands: commands, protocolError: false };
    } catch (error) {
      console.error('CmdCodec: Failed to extract commands', error);
      const remaining = readOffset < totalLength ? buffer.slice(readOffset) : new ArrayBuffer(0);
      return { remainingBuffer: remaining, commands: commands, protocolError: false };
    }
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
   * @param captureOp 0=START_CAPTURE, 1=STOP_CAPTURE
   */
  static createCaptureCmd(deviceCode: string, password: string, captureOp: number): ConcreteCmd {
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
    imageData: string | ArrayBuffer,
    width: number,
    height: number,
    compressionMethod: number
  ): ConcreteCmd {
    // 注意：CmdUtils.createCaptureDataCmd不需要width和height参数
    return CmdUtils.createCaptureDataCmd(imageData, compressionMethod);
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