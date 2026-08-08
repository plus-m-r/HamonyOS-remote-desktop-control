// CmdCapture 编码测试：验证帧格式、payload 结构、瓦片序列与 Java 兼容。

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_client/protocol/cmd_capture_codec.dart';
import 'package:flutter_client/protocol/cmd_codec.dart';
import 'package:flutter_client/protocol/cmd_type.dart';
import 'package:flutter_client/protocol/zstd_codec.dart';

/// 造一个假脏瓦片（64×64 BGRA 像素）。
DirtyTileData makeTile(int x, int y, int fill) {
  final pixels = Uint8List(64 * 64 * 4);
  for (var i = 0; i < pixels.length; i += 4) {
    pixels[i] = fill; // B
    pixels[i + 1] = fill; // G
    pixels[i + 2] = fill; // R
    pixels[i + 3] = 255; // A
  }
  return DirtyTileData(
    x: x,
    y: y,
    width: 64,
    height: 64,
    pixelData: pixels,
  );
}

void main() {
  group('encodeFrame 帧体', () {
    test('完整帧：magic + cmdType=capture(9) + body(method=ZSTD)', () {
      // encodeFrame 返回 body 片段，外包 CmdCodec.encode 成完整帧
      final body = CmdCaptureCodec.encodeFrame(1, Uint8List(0));
      final frame = CmdCodec.encode(CmdType.capture, body);

      // magic: 0x64 0x33
      expect(frame[0], 0x64);
      expect(frame[1], 0x33);
      // cmdType: capture = 枚举序号 9
      expect(frame[2], 9);
      // body 从偏移 7 开始：id(4B 大端)=1, method=3, hasConfig=0
      expect(frame.sublist(7, 11), [0x00, 0x00, 0x00, 0x01]);
      expect(frame[11], 3); // method = ZSTD
      expect(frame[12], 0); // hasConfig = false
    });

    test('payloadLen 与实际 payload 长度一致', () {
      final payload = Uint8List.fromList([1, 2, 3, 4, 5]);
      final body = CmdCaptureCodec.encodeFrame(1, payload);

      // body = id(4)+method(1)+hasConfig(1)+payloadLen(4)+payload
      // payloadLen 在 body 偏移 6 处（4 字节大端）
      final payloadLen = ByteData.sublistView(body).getInt32(6);
      expect(payloadLen, 5);
    });
  });

  group('encodePayload 元数据', () {
    test('元数据段字段正确（id/reset/尺寸）', () {
      final tileBytes = Uint8List(0);
      final payload = CmdCaptureCodec.encodePayload(
        id: 42,
        reset: true,
        width: 1920,
        height: 1080,
        tileWidth: 64,
        tileHeight: 64,
        tileBytes: tileBytes,
      );

      // 元数据 = id(4)+reset(1)+skipped(1)+merged(1)+w(2)+h(2)+tw(2)+th(2) = 15 字节
      expect(payload.length, 15);
      final data = ByteData.sublistView(payload);
      expect(data.getInt32(0), 42); // id
      expect(data.getUint8(4), 1); // reset = true
      expect(data.getUint8(5), 0); // skipped
      expect(data.getUint8(6), 0); // merged
      expect(data.getInt16(7), 1920); // w
      expect(data.getInt16(9), 1080); // h
      expect(data.getInt16(11), 64); // tw
      expect(data.getInt16(13), 64); // th
    });
  });

  group('encodeTileBytes 瓦片序列', () {
    test('未缓存瓦片：marker=数量 + short(-len) + 像素', () {
      final tile = makeTile(0, 0, 128);
      final List<DirtyTileData?> grid = [tile]; // 完整网格（1 个非空）
      final tileBytes = CmdCaptureCodec.encodeTileBytes(grid);

      // 第 1 字节 = marker（连续非空瓦片数量 = 1）
      expect(tileBytes[0], 1);
      // 第 2-3 字节 = short(-len)，len = 64*64*4 = 16384，-16384 = 0xC000
      expect(tileBytes[1], 0xC0); // 高字节
      expect(tileBytes[2], 0x00); // 低字节
      // 之后是 16384 字节像素
      expect(tileBytes.length, 3 + 16384);
    });

    test('空瓦片用负 marker 跳过（位置靠网格顺序隐含）', () {
      // 网格 4 位置：null, tile, null, tile（第 1、3 个没变）
      final tile2 = makeTile(64, 0, 100);
      final tile4 = makeTile(64, 64, 200);
      final List<DirtyTileData?> grid = [null, tile2, null, tile4];
      final tileBytes = CmdCaptureCodec.encodeTileBytes(grid);

      // marker 语义（对齐 Java computeMarkerCount）：
      // -0 表示"1 个空瓦片"（解码端 idx += -0+1），+1 表示"1 个非空"
      // 序列：-0(1个空) + 1(tile2) + -0(1个空) + 1(tile4)
      expect(tileBytes[0], 0); // 负 marker -0：1 个空瓦片
      expect(tileBytes[1], 1); // 正 marker：1 个非空
      expect(tileBytes[2], 0xC0); // tile2 的 short(-16384) 高字节
      expect(tileBytes[3], 0x00); // 低字节
      // 之后 16384 字节 tile2 像素
      // 然后 -0(空) + 1(非空 tile4)
      final offset = 4 + 16384;
      expect(tileBytes[offset], 0);
      expect(tileBytes[offset + 1], 1);
    });
  });

  group('buildCaptureFrame 总编排', () {
    test('完整帧可解压并还原元数据', () {
      final List<DirtyTileData?> tiles = [makeTile(0, 0, 100), makeTile(64, 0, 200)];
      final frameBody = CmdCaptureCodec.buildCaptureFrame(
        id: 7,
        reset: true,
        width: 128,
        height: 64,
        tileWidth: 64,
        tileHeight: 64,
        tiles: tiles,
      );

      // 1. buildCaptureFrame 返回 body 片段，外包 CmdCodec.encode 成完整帧
      final frame = CmdCodec.encode(CmdType.capture, frameBody);

      // 2. 帧头 magic + capture(9)
      expect(frame[0], 0x64);
      expect(frame[1], 0x33);
      expect(frame[2], 9);

      // 3. 解压 payload 验证内容
      // frameBody = id(4)+method(1)+hasConfig(1)+payloadLen(4)+compressed
      final payloadLen = ByteData.sublistView(frameBody).getInt32(6);
      final compressed = frameBody.sublist(10, 10 + payloadLen);

      // 3. ZSTD 解压 payload
      // 解压后 = 15 字节元数据 + marker(1B) + 2×瓦片(各 short 2B + 16384 像素)
      final expectedUncompressed = 15 + 1 + 2 * (2 + 16384);
      final decompressed = ZstdCodec.decompress(compressed, expectedUncompressed);
      final data = ByteData.sublistView(decompressed);

      // 4. 验证元数据还原
      expect(data.getInt32(0), 7); // id
      expect(data.getUint8(4), 1); // reset
      expect(data.getInt16(7), 128); // w
      expect(data.getInt16(9), 64); // h

      // 5. 瓦片序列：marker = 2（两个非空瓦片）
      expect(decompressed[15], 2);
    });
  });
}
