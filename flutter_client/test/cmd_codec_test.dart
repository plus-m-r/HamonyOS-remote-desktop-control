// M1 协议层测试：验证帧编解码与 Java 端字节级兼容。

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
}
