import 'dart:typed_data';

/// 一块变了的瓦片：位置 + 尺寸 + BGRA 像素。
/// 对照 Java 端 CaptureTile（position/width/height/capture）。
class DirtyTile {
  final int x; // 瓦片左上角 x（像素）
  final int y; // 瓦片左上角 y（像素）
  final int width; // 瓦片宽
  final int height; // 瓦片高
  final Uint8List pixelData; // BGRA 像素

  DirtyTile({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.pixelData,
  });
}

/// 瓦片切分器：把整帧像素切成 64×64 瓦片，对比上一帧找出变化（dirty）的瓦片。
/// 对照 Java 端 CaptureEngine（computeDirtyTiles + previousCapture）。
class TileSplitter {
  static const int tileSize = 64; // 瓦片尺寸（Java 的 TILE_DIMENSION）
  List<int>? _previousChecksums; // 上一帧每个瓦片的 checksum（null = 首帧）

  /// 对比上一帧，返回完整网格的脏瓦片数组（null = 该位置没变）。
  /// 位置隐含在数组下标（按网格顺序：行优先），与 Java 的 dirty[] 数组一致。
  /// 对应 Java 的 computeDirtyTiles()（返回 CaptureTile[]，null 表示没变）。
  List<DirtyTile?> computeDirtyTiles(Uint8List frame, int frameWidth, int frameHeight) {
    // ① 算瓦片网格：宽/高各除以 64 向上取整（有余数进一位）
    final cols = (frameWidth + tileSize - 1) ~/ tileSize; // 每行几个瓦片
    final rows = (frameHeight + tileSize - 1) ~/ tileSize; // 每列几个瓦片
    final total = cols * rows;

    // ② 分辨率变化时重建 checksum 数组（-1 = 首帧全视为变化）
    if (_previousChecksums == null || _previousChecksums!.length != total) {
      _previousChecksums = List<int>.filled(total, -1);
    }

    // ③ 遍历所有瓦片位置，提取→算指纹→对比
    // 返回完整网格数组：变的放 DirtyTile，没变的留 null（位置靠下标隐含）
    final grid = List<DirtyTile?>.filled(total, null);
    var hasDirty = false;
    var tileIndex = 0;
    for (var ty = 0; ty < frameHeight; ty += tileSize) {
      final th = frameHeight - ty < tileSize ? frameHeight - ty : tileSize; // 边缘瓦片取实际高
      for (var tx = 0; tx < frameWidth; tx += tileSize) {
        final tw = frameWidth - tx < tileSize ? frameWidth - tx : tileSize; // 边缘取实际宽

        // ④ 提取瓦片像素 → 算 Adler32 指纹 → 和上次比
        final pixels = extractTile(frame, frameWidth, tx, ty, tw, th);
        final cs = adler32(pixels);
        if (cs != _previousChecksums![tileIndex]) {
          grid[tileIndex] = DirtyTile(
            x: tx,
            y: ty,
            width: tw,
            height: th,
            pixelData: pixels,
          );
          _previousChecksums![tileIndex] = cs; // 更新"上次"
          hasDirty = true;
        }
        tileIndex++;
      }
    }
    // 全部没变时返回空列表（调用方据此跳过发送）
    return hasDirty ? grid : const [];
  }

  /// Adler32 校验：把数据算成一个"只和内容有关"的 32 位指纹。
  /// 对照 Java 的 CaptureTile.computeChecksum（java.util.zip.Adler32）。
  static int adler32(List<int> data) {
    const mod = 65521; // Adler32 算法规定的质数
    var a = 1; // A = 所有字节之和（前缀和）
    var b = 0; // B = A 的历史累计（前缀和的和）
    for (final byte in data) {
      a = (a + byte) % mod;
      b = (b + a) % mod;
    }
    return (b << 16) | a; // B 放高 16 位，A 放低 16 位
  }

  /// 从整帧像素里取出一块瓦片（BGRA）。
  /// 对应 Java 的 createTile()（screen-rectangle → tile-rectangle buffer）。
  static Uint8List extractTile(Uint8List frame, int frameWidth,
      int tileX, int tileY, int tileWidth, int tileHeight) {
    const pixelSize = 4; // BGRA = 每像素 4 字节
    final tile = Uint8List(tileWidth * tileHeight * pixelSize); // 瓦片空盒
    for (var row = 0; row < tileHeight; row++) {
      // 源（整帧）这一行的起点：第几行×每行多长 + 列位置，再×4 换字节
      final srcStart = ((tileY + row) * frameWidth + tileX) * pixelSize;
      // 把源那一行的瓦片宽度拷进瓦片的对应行
      tile.setRange(
        row * tileWidth * pixelSize,
        (row + 1) * tileWidth * pixelSize,
        frame,
        srcStart,
      );
    }
    return tile;
  }
}
