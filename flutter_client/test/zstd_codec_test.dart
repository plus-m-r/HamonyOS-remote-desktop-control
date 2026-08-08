// ZSTD FFI 测试：验证压缩/解压往返 + 帧头含 contentSize（鸿蒙端兼容红线）。

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_client/protocol/zstd_codec.dart';

void main() {
  test('压缩→解压往返：数据原样恢复', () {
    // 模拟一段屏幕瓦片数据（BGRA，有规律便于压缩）
    final raw = Uint8List.fromList(
      List<int>.generate(64 * 64 * 4, (i) => (i ~/ 4) % 256),
    );

    final compressed = ZstdCodec.compress(raw);
    // 压缩后应该更小（有规律数据）
    expect(compressed.length, lessThan(raw.length));

    final decompressed = ZstdCodec.decompress(compressed, raw.length);
    expect(decompressed, raw); // 往返一致
  });

  test('帧头含 contentSize（bit6=1）——鸿蒙端 library_decompressor 兼容红线', () {
    final raw = Uint8List.fromList(
      List<int>.generate(4096, (i) => i % 256),
    );
    final compressed = ZstdCodec.compress(raw);

    // ZSTD 帧格式：magic(4B) + Frame_Header_Descriptor(1B)
    // descriptor bit6 (0x40) = Single Segment flag = 含 contentSize
    expect(compressed[0], 0x28);
    expect(compressed[1], 0xB5);
    expect(compressed[2], 0x2F);
    expect(compressed[3], 0xFD);
    final descriptor = compressed[4];
    expect(descriptor & 0x40, 0x40, reason: '帧头必须含 contentSize');
  });

  test('压缩结果与 Java setContentSize(true) 语义一致（能自解）', () {
    // 用不同的压缩级别都能往返
    for (final level in [1, 3, 6]) {
      final raw = Uint8List.fromList(List<int>.generate(8192, (i) => i ~/ 8));
      final compressed = ZstdCodec.compress(raw, level: level);
      final back = ZstdCodec.decompress(compressed, raw.length);
      expect(back, raw, reason: 'level=$level 往返失败');
    }
  });
}
