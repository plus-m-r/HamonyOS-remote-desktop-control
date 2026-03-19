/**
 * Netty 命令协议测试
 */
import { describe, it, expect, TestContext } from '@ohos/hypium';
import { CmdType, MouseAction, OpenStatus, CaptureStatus, CompressionMethod, ClipboardData } from '../main/ets/models/CmdProtocol';
import { CmdUtils } from '../main/ets/models/CmdFactory';
import { CmdCodec } from '../main/ets/network/CmdCodec';
import { Cmd } from '../main/ets/models/Cmd';

// 命令数据JSON接口
interface CmdDataJSON {
  deviceCode?: string;
  password?: string;
  status?: string;
  imageData?: string | ArrayBuffer;
  width?: number;
  height?: number;
  x?: number;
  y?: number;
  action?: number;
  wheelDelta?: number;
  keyCode?: number;
  pressed?: boolean;
  fps?: number;
  captureFrequency?: number;
  quality?: number;
  maxFps?: number;
  compressionMethod?: number;
  compressionLevel?: number;
  screenIndex?: number;
  caputureOp?: number;
  clipboards?: ClipboardData[];
  text?: string;
  fileInfoId?: string;
  fileName?: string;
  filePid?: string;
  isFile?: number;
  oldPassword?: string;
  newPassword?: string;
  type?: CmdType;
  id?: string;
}

export default function cmdProtocolTest() {
  describe('CmdProtocolTest', () => {
    it('test_cmd_type_enum', 0, () => {
      // 测试命令类型枚举
      expect(CmdType.ResCliInfo).assertEqual('ResCliInfo');
      expect(CmdType.ReqCliInfo).assertEqual('ReqCliInfo');
      expect(CmdType.ChangePwd).assertEqual('ChangePwd');
      expect(CmdType.ReqPing).assertEqual('ReqPing');
      expect(CmdType.ResPong).assertEqual('ResPong');
      expect(CmdType.ReqOpen).assertEqual('ReqOpen');
      expect(CmdType.ResOpen).assertEqual('ResOpen');
      expect(CmdType.ReqCapture).assertEqual('ReqCapture');
      expect(CmdType.ResCapture).assertEqual('ResCapture');
      expect(CmdType.Capture).assertEqual('Capture');
      expect(CmdType.SelectScreen).assertEqual('SelectScreen');
      expect(CmdType.MouseControl).assertEqual('MouseControl');
      expect(CmdType.KeyControl).assertEqual('KeyControl');
      expect(CmdType.CaptureConfig).assertEqual('CaptureConfig');
      expect(CmdType.CompressorConfig).assertEqual('CompressorConfig');
      expect(CmdType.ReqRemoteClipboard).assertEqual('ReqRemoteClipboard');
      expect(CmdType.ResRemoteClipboard).assertEqual('ResRemoteClipboard');
      expect(CmdType.ClipboardText).assertEqual('ClipboardText');
      expect(CmdType.ClipboardTransfer).assertEqual('ClipboardTransfer');
    });

    it('test_mouse_action_enum', 0, () => {
      // 测试鼠标动作枚举
      expect(MouseAction.MOVE).assertEqual(1);
      expect(MouseAction.LEFT_CLICK).assertEqual(2);
      expect(MouseAction.RIGHT_CLICK).assertEqual(3);
      expect(MouseAction.WHEEL).assertEqual(4);
    });

    it('test_open_status_type', 0, () => {
      // 测试打开连接状态类�?      const okStatus: OpenStatus = 'OK';
      const offlineStatus: OpenStatus = 'OFFLINE';
      const controlStatus: OpenStatus = 'CONTROL';
      
      expect(okStatus).assertEqual('OK');
      expect(offlineStatus).assertEqual('OFFLINE');
      expect(controlStatus).assertEqual('CONTROL');
    });

    it('test_capture_status_type', 0, () => {
      // 测试捕获状态类�?      const okStatus: CaptureStatus = 'OK';
      const offlineStatus: CaptureStatus = 'OFFLINE';
      const pwdErrorStatus: CaptureStatus = 'PWDERROR';
      const controlStatus: CaptureStatus = 'CONTROL';
      const stopStatus: CaptureStatus = 'STOP';
      
      expect(okStatus).assertEqual('OK');
      expect(offlineStatus).assertEqual('OFFLINE');
      expect(pwdErrorStatus).assertEqual('PWDERROR');
      expect(controlStatus).assertEqual('CONTROL');
      expect(stopStatus).assertEqual('STOP');
    });

    it('test_compression_method_enum', 0, () => {
      // 测试压缩方法枚举
      expect(CompressionMethod.ZSTD).assertEqual(1);
      expect(CompressionMethod.XZ).assertEqual(2);
      expect(CompressionMethod.ZIP).assertEqual(3);
    });

    it('test_cmd_creation', 0, () => {
      // 测试命令创建
      const pingCmd = CmdCodec.createPingCmd();
      expect(pingCmd.getType()).assertEqual(CmdType.ReqPing);
      expect(pingCmd.getId()).assertContain('cmd_');
      
      const openCmd = CmdCodec.createOpenCmd('device_123');
      expect(openCmd.getType()).assertEqual(CmdType.ReqOpen);
      const openData = openCmd.toJSON() as CmdDataJSON;
      expect(openData.deviceCode).assertEqual('device_123');
      
      const captureCmd = CmdCodec.createCaptureCmd('device_123', 'password', true);
      expect(captureCmd.getType()).assertEqual(CmdType.ReqCapture);
      const captureData = captureCmd.toJSON() as CmdDataJSON;
      expect(captureData.deviceCode).assertEqual('device_123');
      expect(captureData.password).assertEqual('password');
      expect(captureData.caputureOp).assertEqual(1);
      
      const mouseCmd = CmdCodec.createMouseControlCmd('device_123', 100, 200, MouseAction.LEFT_CLICK);
      expect(mouseCmd.getType()).assertEqual(CmdType.MouseControl);
      const mouseData = mouseCmd.toJSON() as CmdDataJSON;
      expect(mouseData.deviceCode).assertEqual('device_123');
      expect(mouseData.x).assertEqual(100);
      expect(mouseData.y).assertEqual(200);
      expect(mouseData.action).assertEqual(MouseAction.LEFT_CLICK);
      
      const keyCmd = CmdCodec.createKeyControlCmd('device_123', 65, true);
      expect(keyCmd.getType()).assertEqual(CmdType.KeyControl);
      const keyData = keyCmd.toJSON() as CmdDataJSON;
      expect(keyData.deviceCode).assertEqual('device_123');
      expect(keyData.keyCode).assertEqual(65);
      expect(keyData.pressed).assertEqual(true);
    });

    

    it('test_cmd_codec', 0, () => {
      // 测试命令编解�?      const originalCmd = CmdCodec.createMouseControlCmd('device_123', 100, 200, MouseAction.MOVE, 0);
      
      // 编码
      const encodedBuffer = CmdCodec.encode(originalCmd);
      expect(encodedBuffer.byteLength).assertLarger(0);
      
      // 解码
      const decodedCmd = CmdCodec.decode(encodedBuffer);
      expect(decodedCmd).assertNotUndefined();
      expect(decodedCmd?.getType()).assertEqual(CmdType.MouseControl);
      
      const decodedData = decodedCmd?.toJSON() as CmdDataJSON;
      expect(decodedData.deviceCode).assertEqual('device_123');
      expect(decodedData.x).assertEqual(100);
      expect(decodedData.y).assertEqual(200);
      expect(decodedData.action).assertEqual(MouseAction.MOVE);
    });

    it('test_cmd_codec_stream', 0, () => {
      // 测试流式命令解码
      const cmd1 = CmdCodec.createPingCmd();
      const cmd2 = CmdCodec.createOpenCmd('device_123');
      
      const buffer1 = CmdCodec.encode(cmd1);
      const buffer2 = CmdCodec.encode(cmd2);
      
      // 合并两个缓冲�?      const combinedBuffer = new ArrayBuffer(buffer1.byteLength + buffer2.byteLength);
      const combinedView = new Uint8Array(combinedBuffer);
      combinedView.set(new Uint8Array(buffer1), 0);
      combinedView.set(new Uint8Array(buffer2), buffer1.byteLength);
      
      // 提取命令
      const [remainingBuffer, commands] = CmdCodec.extractCommands(combinedBuffer);
      
      expect(commands.length).assertEqual(2);
      expect(commands[0].getType()).assertEqual(CmdType.ReqPing);
      expect(commands[1].getType()).assertEqual(CmdType.ReqOpen);
      expect(remainingBuffer.byteLength).assertEqual(0);
    });

    it('test_clipboard_commands', 0, () => {
      // 测试剪贴板相关命�?      const clipboardRequestCmd = CmdCodec.createClipboardRequestCmd('device_123');
      expect(clipboardRequestCmd.getType()).assertEqual(CmdType.ReqRemoteClipboard);
      
      const clipboardTextCmd = CmdCodec.createClipboardTextCmd('device_123', 'Hello World');
      expect(clipboardTextCmd.getType()).assertEqual(CmdType.ClipboardText);
      const textData = clipboardTextCmd.toJSON() as CmdDataJSON;
      expect(textData.text).assertEqual('Hello World');
      
      const clipboardTransferCmd = CmdCodec.createClipboardTransferCmd('device_123', 'file_123', 'test.txt');
      expect(clipboardTransferCmd.getType()).assertEqual(CmdType.ClipboardTransfer);
      const transferData = clipboardTransferCmd.toJSON() as CmdDataJSON;
      expect(transferData.fileInfoId).assertEqual('file_123');
      expect(transferData.fileName).assertEqual('test.txt');
    });

    it('test_cmd_validation', 0, () => {
      // 测试命令验证
      const validCmdData = {
        type: 'ReqOpen',
        id: 'cmd_123',
        deviceCode: 'device_123'
      };
      
      const invalidCmdData1 = {
        type: 'ReqOpen'
        // 缺少 id
      };
      
      const invalidCmdData2 = {
        id: 'cmd_123'
        // 缺少 type
      };
      
      expect(CmdUtils.validateCmdData(validCmdData)).assertTrue();
      expect(CmdUtils.validateCmdData(invalidCmdData1)).assertFalse();
      expect(CmdUtils.validateCmdData(invalidCmdData2)).assertFalse();
    });

    it('test_cmd_factory', 0, () => {
      // 测试命令工厂
      const cmdData = {
        type: 'ResCliInfo',
        id: 'cmd_123',
        deviceCode: 'device_123',
        password: 'password_123'
      };
      
      const cmd = CmdUtils.createCmdFromData(cmdData);
      expect(cmd).assertNotUndefined();
      expect(cmd?.getType()).assertEqual(CmdType.ResCliInfo);
      
      const cmdJson = cmd?.toJSON() as CmdDataJSON;
      expect(cmdJson.deviceCode).assertEqual('device_123');
      expect(cmdJson.password).assertEqual('password_123');
    });
  });
}
