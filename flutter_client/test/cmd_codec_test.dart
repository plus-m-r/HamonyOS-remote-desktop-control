// M1 协议层测试：验证帧编解码与 Java 端字节级兼容。

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_client/protocol/cmd_codec.dart';
import 'package:flutter_client/protocol/cmd_type.dart';

void main() {
  test('reqPing 帧头字节与 Java 一致', () {
    // Java: CmdReqPing wireSize=0，帧 = 64 33 00 00 00 00 00
    //       magic(64 33) + type=0 + length=0(4字节)
    final frame = CmdCodec.encode(CmdType.reqPing, const []);
    expect(frame, [0x64, 0x33, 0x00, 0x00, 0x00, 0x00, 0x00]);
  });

  test('decode 能还原 type 和 body', () {
    final frame = CmdCodec.encode(CmdType.reqCapture, [0x01, 0x02, 0x03]);
    final (type, body) = CmdCodec.decode(frame);
    expect(type, CmdType.reqCapture);
    expect(body, [0x01, 0x02, 0x03]);
  });

  test('magic 错误时抛异常', () {
    final bad = Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
    expect(() => CmdCodec.decode(bad), throwsFormatException);
  });

  test('reqCliInfo body 字节与 Java 一致', () {
    // Java: CmdReqCliInfo.encode() = writeInt(screenNum) + writeInt(osName.length) + osName
    // screenNum=1, osName="Windows"(7字节)
    // body = 00 00 00 01 | 00 00 00 07 | 57 69 6E 64 6F 77 73 ("Windows")
    final body = CmdCodec.buildReqCliInfoBody(1, 'Windows');
    expect(body, [
      0x00, 0x00, 0x00, 0x01, // screenNum=1
      0x00, 0x00, 0x00, 0x07, // osName 长度=7
      ...utf8.encode('Windows'), // "Windows" 本身
    ]);
  });

  test('resCliInfo body 解析与 Java 一致', () {
    // Java: CmdResCliInfo.decode() = writeInt(len)+deviceCode + writeInt(len)+password
    // deviceCode="abcd1234"(8), password="123456"(6)
    final body = Uint8List.fromList([
      0x00, 0x00, 0x00, 0x08, // deviceCode 长度=8
      ...utf8.encode('abcd1234'),
      0x00, 0x00, 0x00, 0x06, // password 长度=6
      ...utf8.encode('123456'),
    ]);
    final (deviceCode, password) = CmdCodec.parseResCliInfoBody(body);
    expect(deviceCode, 'abcd1234');
    expect(password, '123456');
  });

  test('reqCapture body 字节与 Java 一致', () {
    // Java: CmdReqCapture.encode() =
    //   writeInt(deviceCode.length) + deviceCode + writeByte(op) + writeInt(password.length) + password
    // deviceCode="abcd"(4), op=0(开始截屏), password="123456"(6)
    final body = CmdCodec.buildReqCaptureBody('abcd', 0, '123456');
    expect(body, [
      0x00, 0x00, 0x00, 0x04, // deviceCode 长度=4
      ...utf8.encode('abcd'), // "abcd"
      0x00, // op=0（START_CAPTURE）
      0x00, 0x00, 0x00, 0x06, // password 长度=6
      ...utf8.encode('123456'), // "123456"
    ]);
  });

  test('reqCapture 完整帧可 encode→decode 往返', () {
    // 端到端：编成帧再解回来，type 和 body 一致
    final body = CmdCodec.buildReqCaptureBody('device01', 0, 'pwd123');
    final frame = CmdCodec.encode(CmdType.reqCapture, body);
    final (type, decodedBody) = CmdCodec.decode(frame);
    expect(type, CmdType.reqCapture);
    expect(decodedBody, body);
  });
}
