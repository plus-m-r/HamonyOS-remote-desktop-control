import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// ZSTD 压缩/解压：FFI 直调官方 libzstd.dll。
///
/// 为什么不用 pub 的 zstd 包：
/// 1. pub 的 zstd 是 Flutter 平台插件，纯 Dart 测试环境跑不了
/// 2. 它是流式压缩，帧头不含 contentSize（鸿蒙端 library_decompressor 解不了）
/// 3. 官方 one-shot API 默认帧头就含 contentSize —— 正好对齐
///    Java 端 ZstdCompressCtx.setContentSize(true) 的效果（红线）
///
/// 性能设计：
/// - 压缩用 ZSTD_compressCCtx 复用同一个压缩上下文（CCtx），
///   避免每帧都 ZSTD_createCCtx 创建上下文（屏幕 30ms/帧 = 每秒 33 次创建）
/// - one-shot（非流式）：屏幕帧大小已知（宽×高×4），流式反而更慢
///
/// DLL 位置：exe 同目录 libzstd.dll（优先）或工程 third_party/（测试时）
class ZstdCodec {
  // FFI 函数句柄（延迟加载）
  // C 签名：size_t ZSTD_compressCCtx(ZSTD_CCtx*, void* dst, size_t cap, const void* src, size_t size, int level)
  // FFI 映射：size_t→Uint64(native)/int(Dart)，指针→Pointer<Uint8>，int→Int32
  static final DynamicLibrary _lib = _loadLib();
  static final _createCCtx = _lib
      .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function(
          )>('ZSTD_createCCtx');
  // 注：CCtx 进程级复用，不主动释放（进程退出时系统回收 DLL）；故不绑定 ZSTD_freeCCtx
  static final _compressCCtx = _lib.lookupFunction<
      Uint64 Function(
          Pointer<Void>, Pointer<Uint8>, Uint64, Pointer<Uint8>, Uint64, Int32),
      int Function(
          Pointer<Void>, Pointer<Uint8>, int, Pointer<Uint8>, int, int)>(
              'ZSTD_compressCCtx');
  static final _decompress = _lib.lookupFunction<
      Uint64 Function(Pointer<Uint8>, Uint64, Pointer<Uint8>, Uint64),
      int Function(Pointer<Uint8>, int, Pointer<Uint8>, int)>('ZSTD_decompress');
  static final _compressBound = _lib
      .lookupFunction<Uint64 Function(Uint64), int Function(int)>(
          'ZSTD_compressBound');
  static final _isError =
      _lib.lookupFunction<Uint32 Function(Uint64), int Function(int)>(
          'ZSTD_isError');

  /// 复用的压缩上下文（懒创建，进程生命周期内只建一次）。
  static Pointer<Void>? _cctx;

  static DynamicLibrary _loadLib() {
    // 多路径尝试：① exe 同目录（运行时工作目录是 exe 目录，DLL 拷到那里最稳）
    //             ② 工程相对路径（flutter test 工作目录 = 工程根）
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      '$exeDir\\libzstd.dll',
      'third_party/zstd-win64/zstd-v1.5.7-win64/dll/libzstd.dll',
    ];
    Object? lastError;
    for (final path in candidates) {
      try {
        return DynamicLibrary.open(path);
      } catch (e) {
        lastError = e;
      }
    }
    throw StateError('找不到 libzstd.dll：$candidates，最后错误: $lastError');
  }

  static Pointer<Void> _getCctx() {
    return _cctx ??= _createCCtx();
  }

  /// 压缩：返回含 contentSize 帧头的 ZSTD 数据（对齐 Java setContentSize(true)）。
  /// 复用同一个 CCtx，避免每帧重新创建压缩上下文。
  static Uint8List compress(Uint8List src, {int level = 1}) {
    // 1. 算最大压缩后大小（ZSTD_compressBound）
    final bound = _compressBound(src.length);
    // 2. 分配输入/输出缓冲
    final srcPtr = calloc<Uint8>(src.length);
    final dstPtr = calloc<Uint8>(bound);
    try {
      // 拷贝输入数据到原生内存
      srcPtr.asTypedList(src.length).setAll(0, src);
      // 3. 用复用的 CCtx 压缩（省掉每帧的上下文创建）
      final size = _compressCCtx(_getCctx(), dstPtr, bound, srcPtr, src.length, level);
      if (_isError(size) != 0) {
        throw Exception('ZSTD 压缩失败，错误码: $size');
      }
      // 4. 把压缩结果拷回 Dart
      return dstPtr.asTypedList(size).sublist(0);
    } finally {
      calloc.free(srcPtr);
      calloc.free(dstPtr);
    }
  }

  /// 解压：src 是 ZSTD 数据，[knownSize] 是原数据大小（协议里能从瓦片尺寸算出）。
  static Uint8List decompress(Uint8List src, int knownSize) {
    final srcPtr = calloc<Uint8>(src.length);
    final dstPtr = calloc<Uint8>(knownSize);
    try {
      srcPtr.asTypedList(src.length).setAll(0, src);
      final size = _decompress(dstPtr, knownSize, srcPtr, src.length);
      if (_isError(size) != 0) {
        throw Exception('ZSTD 解压失败，错误码: $size');
      }
      return dstPtr.asTypedList(size).sublist(0);
    } finally {
      calloc.free(srcPtr);
      calloc.free(dstPtr);
    }
  }
}
