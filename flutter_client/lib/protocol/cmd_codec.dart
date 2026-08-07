import 'dart:convert';
import 'dart:typed_data';

import 'cmd_type.dart';

/// 帧编解码器：把"命令"和"字节流"互转。
///
/// 帧格式（与 Java 端 NettyEncoder/NettyDecoder 一致，字节级兼容）：
/// ┌────────┬────────┬─────────────┬──────────────┐
/// │ magic  │ cmdType│ dataLength  │ body          │
/// │ 2 字节  │ 1 字节  │ 4 字节(大端) │ N 字节         │
/// │ 0x64,0x33│ 枚举序号 │ = body长度   │ 命令的具体数据  │
/// └────────┴────────┴─────────────┴──────────────┘
class CmdCodec {
  static const int _magicByte0 = 0x64;
  static const int _magicByte1 = 0x33;

  /// 帧头长度：magic(2) + type(1) + length(4)
  static const int headerLength = 2 + 1 + 4;

  /// 编码：把命令类型 [type] 和命令数据 [body] 拼成一帧字节流。
  static Uint8List encode(CmdType type, List<int> body) {
    final data = ByteData(headerLength + body.length);
    data.setUint8(0, _magicByte0); // magic 第 1 字节：0x64
    data.setUint8(1, _magicByte1); // magic 第 2 字节：0x33
    data.setUint8(2, type.index); // cmdType：枚举序号（大端序无关，单字节）
    data.setUint32(3, body.length); // dataLength：4 字节大端，= body 长度
    // 把 body 拷贝进帧的尾部
    for (var i = 0; i < body.length; i++) {
      data.setUint8(headerLength + i, body[i]);
    }
    return data.buffer.asUint8List();
  }

  /// 解码：解析一帧字节流，返回 [CmdType] 和 body 数据。
  static (CmdType, Uint8List) decode(Uint8List frame) {
    final data = ByteData.sublistView(frame);
    // 校验 magic，不对说明协议错乱
    if (data.getUint8(0) != _magicByte0 || data.getUint8(1) != _magicByte1) {
      throw FormatException('Protocol error: bad magic');
    }
    final type = CmdType.values[data.getUint8(2)]; // 按序号还原枚举
    final length = data.getUint32(3); // 大端读长度
    // 截取 body 部分
    final body = frame.sublist(headerLength, headerLength + length);
    return (type, body);
  }

  /// 构建 reqCliInfo 的 body：screenNum(int) + osName长度(int) + osName(UTF8)。
  /// 对应 Java 端 CmdReqCliInfo.encode()。
  static Uint8List buildReqCliInfoBody(int screenNum, String osName) {
    final osBytes = utf8.encode(osName);
    final data = ByteData(4 + 4 + osBytes.length);
    data.setUint32(0, screenNum); // 屏幕数量
    data.setUint32(4, osBytes.length); // osName 长度
    for (var i = 0; i < osBytes.length; i++) {
      data.setUint8(8 + i, osBytes[i]);
    }
    return data.buffer.asUint8List();
  }

  /// 解析 resCliInfo 的 body：deviceCode长度 + deviceCode + password长度 + password。
  /// 对应 Java 端 CmdResCliInfo.decode()，返回 (deviceCode, password)。
  static (String, String) parseResCliInfoBody(Uint8List body) {
    final data = ByteData.sublistView(body);
    var offset = 0;
    final deviceCodeLen = data.getUint32(offset); // 读设备码长度
    offset += 4;
    final deviceCode =
        utf8.decode(body.sublist(offset, offset + deviceCodeLen));
    offset += deviceCodeLen;
    final passwordLen = data.getUint32(offset); // 读密码长度
    offset += 4;
    final password = utf8.decode(body.sublist(offset, offset + passwordLen));
    return (deviceCode, password);
  }

  /// 构建 reqCapture 的 body：deviceCode长度 + deviceCode + 操作码(1B) + password长度 + password。
  /// 对应 Java 端 CmdReqCapture.encode()。op 含义：0=开始截屏 1=停止 2=被控端停止 3=通道断开。
  static Uint8List buildReqCaptureBody(String deviceCode, int op, String password) {
    final deviceBytes = utf8.encode(deviceCode);
    final passwordBytes = utf8.encode(password);
    final data = ByteData(4 + deviceBytes.length + 1 + 4 + passwordBytes.length);
    var offset = 0;
    data.setUint32(offset, deviceBytes.length); // 设备码长度
    offset += 4;
    for (var i = 0; i < deviceBytes.length; i++) {
      data.setUint8(offset + i, deviceBytes[i]); // 设备码内容
    }
    offset += deviceBytes.length;
    data.setUint8(offset, op); // 操作码（1 字节）
    offset += 1;
    data.setUint32(offset, passwordBytes.length); // 密码长度
    offset += 4;
    for (var i = 0; i < passwordBytes.length; i++) {
      data.setUint8(offset + i, passwordBytes[i]); // 密码内容
    }
    return data.buffer.asUint8List();
  }
}
