// Linux 抓屏纯逻辑测试：XImage 像素 → BGRA 转换（不依赖 X 服务器，任何平台可跑）。

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_client/platform/linux_capturer.dart';

void main() {
  group('xImageToBgra 32bpp 小端', () {
    test('常见 ARGB8888 像素（小端 BGR 在前）转 BGRA', () {
      // 2x1 像素，64 位小端：每个像素 4 字节 = B,G,R,A
      // 像素[0] = ARGB(0xFF, 0x12, 0x34, 0x56) → 小端字节 56 34 12 FF
      // 像素[1] = ARGB(0xFF, 0xAA, 0xBB, 0xCC) → 小端字节 CC BB AA FF
      final raw = Uint8List.fromList([
        0x56, 0x34, 0x12, 0xFF, // 像素0
        0xCC, 0xBB, 0xAA, 0xFF, // 像素1
      ]);
      final out = xImageToBgra(
        raw: raw,
        width: 2,
        height: 1,
        bytesPerLine: 8,
        bitsPerPixel: 32,
        lsbFirst: true,
        redMask: 0x00FF0000, // ARGB：Red 在第 3 字节
        greenMask: 0x0000FF00,
        blueMask: 0x000000FF,
      );
      // 期望 BGRA：蓝,绿,红,不透明(255)
      expect(out, [
        0x56, 0x34, 0x12, 0xFF, // 像素0 BGRA
        0xCC, 0xBB, 0xAA, 0xFF, // 像素1 BGRA
      ]);
    });

    test('24bpp 小端（每像素 3 字节 B,G,R）正确转换', () {
      final raw = Uint8List.fromList([
        0x11, 0x22, 0x33, // 像素0 B=0x11 G=0x22 R=0x33
        0x44, 0x55, 0x66, // 像素1 B=0x44 G=0x55 R=0x66
      ]);
      final out = xImageToBgra(
        raw: raw,
        width: 2,
        height: 1,
        bytesPerLine: 6,
        bitsPerPixel: 24,
        lsbFirst: true,
        redMask: 0x00FF0000,
        greenMask: 0x0000FF00,
        blueMask: 0x000000FF,
      );
      expect(out, [
        0x11, 0x22, 0x33, 0xFF,
        0x44, 0x55, 0x66, 0xFF,
      ]);
    });

    test('bytes_per_line 含对齐 padding 时按行读取', () {
      // 宽 2 像素，32bpp；bytesPerLine=16（比 2*4=8 大，模拟对齐）
      final raw = Uint8List.fromList([
        0x0a, 0x0b, 0x0c, 0xFF, 0x1a, 0x1b, 0x1c, 0xFF,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // padding 区
      ]);
      final out = xImageToBgra(
        raw: raw,
        width: 2,
        height: 1,
        bytesPerLine: 16,
        bitsPerPixel: 32,
        lsbFirst: true,
        redMask: 0x00FF0000,
        greenMask: 0x0000FF00,
        blueMask: 0x000000FF,
      );
      expect(out, [
        0x0a, 0x0b, 0x0c, 0xFF,
        0x1a, 0x1b, 0x1c, 0xFF,
      ]);
    });
  });

  group('xImageToBgra 32bpp 大端', () {
    test('大端（MSBFirst）像素正确转换', () {
      // 大端像素值 0xAARRGGBB：字节序 = A,R,G,B
      // 像素0：A=0xFF R=0x12 G=0x34 B=0x56 → 字节 FF 12 34 56
      final raw = Uint8List.fromList([
        0xFF, 0x12, 0x34, 0x56,
      ]);
      final out = xImageToBgra(
        raw: raw,
        width: 1,
        height: 1,
        bytesPerLine: 4,
        bitsPerPixel: 32,
        lsbFirst: false,
        redMask: 0x00FF0000,
        greenMask: 0x0000FF00,
        blueMask: 0x000000FF,
      );
      expect(out, [0x56, 0x34, 0x12, 0xFF]); // BGRA
    });
  });

  group('xImageToBgra 边界', () {
    test('输出长度 = 宽×高×4', () {
      final raw = Uint8List(3 * 3 * 4);
      final out = xImageToBgra(
        raw: raw,
        width: 3,
        height: 3,
        bytesPerLine: 12,
        bitsPerPixel: 32,
        lsbFirst: true,
        redMask: 0x00FF0000,
        greenMask: 0x0000FF00,
        blueMask: 0x000000FF,
      );
      expect(out.length, 3 * 3 * 4);
    });

    test('alpha 固定为不透明 FF', () {
      final raw = Uint8List.fromList([0x10, 0x20, 0x30, 0x00]); // A=0
      final out = xImageToBgra(
        raw: raw,
        width: 1,
        height: 1,
        bytesPerLine: 4,
        bitsPerPixel: 32,
        lsbFirst: true,
        redMask: 0x00FF0000,
        greenMask: 0x0000FF00,
        blueMask: 0x000000FF,
      );
      expect(out[3], 0xFF); // 忽略源 alpha，强制不透明白
    });
  });
}