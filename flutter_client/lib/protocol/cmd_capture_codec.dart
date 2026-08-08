import 'dart:typed_data';

import 'zstd_codec.dart';

/// CmdCapture 帧编解码。
/// 对照 Java 端 CmdCapture.encode() + Compressor.compress()（字节级一致）。
class CmdCaptureCodec {
  // CompressionMethod 枚举序号（Java 端 CompressionMethod）：NONE=0 ZIP=1 XZ=2 ZSTD=3
  static const int methodZstd = 3;

  /// 编码一帧 CmdCapture：
  /// id(int) + method(1B) + hasConfig(1B) + [config] + payloadLen(int) + payload
  /// [payload] 是已压缩好的瓦片数据（第 2 部分做）。
  static Uint8List encodeFrame(int id, Uint8List payload, {bool withConfig = false}) {
    // 无 config 时：4 + 1 + 1 + 4 + payload.length
    final configSize = withConfig ? 10 : 0;
    final data = ByteData(4 + 1 + 1 + configSize + 4 + payload.length);
    var offset = 0;

    data.setInt32(offset, id, Endian.big); // id
    offset += 4;
    data.setUint8(offset, methodZstd); // method = ZSTD(3)
    offset += 1;
    data.setUint8(offset, withConfig ? 1 : 0); // hasConfig
    offset += 1;
    // 这里预留 config 位置（withConfig=true 时第 3 部分补）
    offset += configSize;
    data.setInt32(offset, payload.length, Endian.big); // payloadLen
    offset += 4;
    // payload 拷进帧
    for (var i = 0; i < payload.length; i++) {
      data.setUint8(offset + i, payload[i]);
    }
    return data.buffer.asUint8List();
  }

  /// 编码 payload 的元数据段 + 瓦片数据。
  /// 对应 Java Compressor.compress() 第 101-140 行。
  /// [tileBytes] = 瓦片序列的已编码字节（第 3 部分产出）。
  static Uint8List encodePayload({
    required int id,
    required bool reset,
    required int width,
    required int height,
    required int tileWidth,
    required int tileHeight,
    required Uint8List tileBytes, // 瓦片序列（marker + 瓦片）
  }) {
    // 元数据段 = id(4) + reset(1) + skipped(1) + merged(1) + 2*4(w/h/tw/th) = 15 字节
    final data = ByteData(15 + tileBytes.length);
    var offset = 0;

    data.setInt32(offset, id, Endian.big); // id
    offset += 4;
    data.setUint8(offset, reset ? 1 : 0); // reset
    offset += 1;
    data.setUint8(offset, 0); // skipped（未做合并，写 0）
    offset += 1;
    data.setUint8(offset, 0); // merged（写 0）
    offset += 1;
    data.setInt16(offset, width, Endian.big); // w
    offset += 2;
    data.setInt16(offset, height, Endian.big); // h
    offset += 2;
    data.setInt16(offset, tileWidth, Endian.big); // tw
    offset += 2;
    data.setInt16(offset, tileHeight, Endian.big); // th
    offset += 2;

    // 瓦片序列拷进 payload
    for (var i = 0; i < tileBytes.length; i++) {
      data.setUint8(offset + i, tileBytes[i]);
    }
    return data.buffer.asUint8List();
  }

  /// 编码瓦片序列（marker + 每个瓦片数据）。
  /// 完整复刻 Java Compressor.compress() 第 118-137 行 + computeMarkerCount() 第 153-169 行。
  ///
  /// [tiles] = 完整网格的瓦片数组（下标 = 网格顺序，null = 该位置没变）。
  /// marker 规则：>0 = 后面 N 个连续非空瓦片（N≤127）；<0 = 后面 (-N+1) 个空瓦片（≤128）。
  static Uint8List encodeTileBytes(List<DirtyTileData?> tiles) {
    final out = BytesBuilder();
    var idx = 0;
    while (idx < tiles.length) {
      final markerCount = _computeMarkerCount(tiles, idx);
      if (markerCount > 0) {
        // 连续非空瓦片：写正 marker + 逐个编码
        out.addByte(markerCount);
        for (var t = idx; t < idx + markerCount; t++) {
          _encodeUncachedTile(out, tiles[t]!.pixelData); // 全走"未缓存"分支
        }
        idx += markerCount;
      } else {
        // 连续空瓦片：写负 marker（-N+1 表示 N 个空位）
        // marker 是有符号 byte（Java writeByte），负数按补码存（-1 → 0xFF）
        out.addByte(markerCount & 0xFF);
        idx += (-markerCount + 1);
      }
    }
    return out.toBytes();
  }

  /// 计算从 [from] 开始的连续瓦片数。
  /// 对应 Java computeMarkerCount()：正=非空数，负=-空数。
  static int _computeMarkerCount(List<DirtyTileData?> tiles, int from) {
    final tile = tiles[from++];
    if (tile == null) {
      // 连续空瓦片（最多 128 个）
      var count = 0;
      while (count < 128 && from < tiles.length && tiles[from++] == null) {
        count++;
      }
      return -count;
    }
    // 连续非空瓦片（最多 127 个）
    var count = 1;
    while (count < 127 && from < tiles.length && tiles[from++] != null) {
      count++;
    }
    return count;
  }

  /// 未缓存瓦片：short(负数=像素长度) + 像素数据。
  /// 对应 Java encodeTile() 第 192-197 行（ZSTD 组合 = NullRLE，数据原样放）。
  static void _encodeUncachedTile(BytesBuilder out, Uint8List pixels) {
    final len = pixels.length;
    // short 是 2 字节，取负值（Java writeShort(-len)）
    out.addByte(((-len) >> 8) & 0xFF); // 高字节
    out.addByte((-len) & 0xFF); // 低字节
    out.add(pixels); // 像素数据原样
  }

  /// 总编排：脏瓦片 → CmdCapture 完整帧（ZSTD 压缩后）。
  /// 对应 Java 链路：Compressor.compress() → CmdCapture.encode()。
  /// [tiles] = 完整网格的瓦片数组（null = 没变，位置靠下标隐含）。
  static Uint8List buildCaptureFrame({
    required int id,
    required bool reset,
    required int width,
    required int height,
    required int tileWidth,
    required int tileHeight,
    required List<DirtyTileData?> tiles,
  }) {
    // 1. 瓦片序列（marker + 瓦片）
    final tileBytes = encodeTileBytes(tiles);
    // 2. payload（元数据 + 瓦片序列）
    final payload = encodePayload(
      id: id,
      reset: reset,
      width: width,
      height: height,
      tileWidth: tileWidth,
      tileHeight: tileHeight,
      tileBytes: tileBytes,
    );
    // 3. ZSTD 压缩 payload（帧头含 contentSize，鸿蒙端兼容）
    final compressed = ZstdCodec.compress(payload);
    // 4. 拼成 CmdCapture 帧
    return encodeFrame(id, compressed);
  }
}

/// 脏瓦片数据（传给 CmdCaptureCodec 编码用）。
/// 由 TileSplitter.computeDirtyTiles 产生后转换。
class DirtyTileData {
  final int x; // 瓦片左上角 x
  final int y; // 瓦片左上角 y
  final int width; // 瓦片宽
  final int height; // 瓦片高
  final Uint8List pixelData; // BGRA 像素

  DirtyTileData({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.pixelData,
  });
}
