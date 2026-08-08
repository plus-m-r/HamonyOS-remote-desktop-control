// 瓦片切分测试：验证 Adler32、首帧全脏、增量脏瓦片逻辑。

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_client/capture/tile_splitter.dart';

/// 造一帧"全黑"的假屏幕（BGRA，每像素 4 字节：B=0,G=0,R=0,A=255）。
Uint8List blackFrame(int width, int height) {
  final frame = Uint8List(width * height * 4);
  for (var i = 3; i < frame.length; i += 4) {
    frame[i] = 255; // Alpha = 255（不透明）
  }
  return frame;
}

/// 在帧的某个矩形区域里涂一个像素值，模拟"屏幕这一块变了"。
void paintRect(Uint8List frame, int frameWidth, int x, int y, int w, int h, int value) {
  for (var row = y; row < y + h; row++) {
    for (var col = x; col < x + w; col++) {
      final offset = (row * frameWidth + col) * 4;
      frame[offset] = value; // 只改 B 通道，够让 checksum 变化
    }
  }
}

void main() {
  group('adler32', () {
    test('同一数据指纹相同，不同数据指纹不同', () {
      final a = TileSplitter.adler32([1, 2, 3, 4]);
      final b = TileSplitter.adler32([1, 2, 3, 4]);
      final c = TileSplitter.adler32([1, 2, 3, 5]); // 最后一个字节不同
      expect(a, b);
      expect(a, isNot(c));
    });

    test('空数据指纹为 1（Adler32 算法定义）', () {
      expect(TileSplitter.adler32([]), 1);
    });
  });

  group('extractTile', () {
    test('能按位置取出 64×64 瓦片', () {
      const w = 128, h = 128; // 2×2 个瓦片
      final frame = blackFrame(w, h);
      // 左上角瓦片 (0,0)：应是全黑
      final tile = TileSplitter.extractTile(frame, w, 0, 0, 64, 64);
      expect(tile.length, 64 * 64 * 4);
    });
  });

  group('computeDirtyTiles', () {
    test('首帧全部瓦片都是脏的（没有上一帧可比）', () {
      const w = 128, h = 128; // 2×2 = 4 个瓦片
      final splitter = TileSplitter();
      final dirty = splitter.computeDirtyTiles(blackFrame(w, h), w, h);
      expect(dirty.length, 4); // 4 个瓦片全是脏的
    });

    test('屏幕没变化时返回空列表（不重复传）', () {
      const w = 128, h = 128;
      final splitter = TileSplitter();
      final frame = blackFrame(w, h);

      splitter.computeDirtyTiles(frame, w, h); // 第一帧：全脏
      final dirty = splitter.computeDirtyTiles(frame, w, h); // 第二帧：没变
      expect(dirty, isEmpty); // 没变化 → 不传
    });

    test('只有变化区域的瓦片是脏的（增量）', () {
      const w = 128, h = 128;
      final splitter = TileSplitter();
      final frame = blackFrame(w, h);

      splitter.computeDirtyTiles(frame, w, h); // 第一帧：全脏

      // 改右下角区域（右下角瓦片范围 64-127）
      paintRect(frame, w, 100, 100, 20, 20, 200);
      final grid = splitter.computeDirtyTiles(frame, w, h);

      // 完整网格 4 个位置，只有右下角（下标 3）非 null
      final dirty = grid.where((t) => t != null).toList();
      expect(dirty.length, 1);
      expect(dirty[0]!.x, 64);
      expect(dirty[0]!.y, 64);
    });

    test('边缘瓦片（不足 64）取实际大小', () {
      const w = 100, h = 100; // 100/64 → 2 列，第二列只有 36 宽
      final splitter = TileSplitter();
      final frame = blackFrame(w, h);
      final grid = splitter.computeDirtyTiles(frame, w, h);

      // 网格 = 2×2 = 4 个位置（首帧全脏，全非 null）；边缘瓦片 36×36
      expect(grid.length, 4);
      // 右下角 = 下标 3（行优先：row1*2+col1）
      final edge = grid[3]!;
      expect(edge.width, 36);
      expect(edge.height, 36);
    });
  });
}
