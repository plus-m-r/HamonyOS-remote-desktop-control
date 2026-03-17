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
   * 编码命令为 ArrayBuffer
   */
  static encode(cmd: ConcreteCmd): ArrayBuffer {
    try {
      // 序列化命令为 JSON 字符串
      const jsonStr = CmdUtils.serialize(cmd);
      
      // 使用 TextEncoder 将字符串转换为 UTF-8 字节数组
      const encoder = new util.TextEncoder();
      const jsonBytes = encoder.encodeInto(jsonStr);
      
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
      console.error('CmdCodec: Failed to encode command', error);
      return new ArrayBuffer(0);
    }
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