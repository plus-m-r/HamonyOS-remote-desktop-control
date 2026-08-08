import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '../platform/windows_capturer.dart';
import '../protocol/cmd_capture_codec.dart';
import 'tile_splitter.dart';

/// 长驻抓屏 isolate：WindowsCapturer/TileSplitter 只建一次，状态保留。
///
/// 为什么用长驻 isolate 而不是 Isolate.run：
/// - Isolate.run 每帧重建 TileSplitter → _previousChecksums 状态丢失 → 脏瓦片失效
/// - 长驻 isolate 启动时建一次 FFI 对象，抓屏循环中复用，增量逻辑正常
///
/// 通信模型（重要：ReceivePort 是单订阅流，只能 listen 一次）：
///   start(): _resultPort.listen() 只订阅一次，回调统一处理
///            SendPort（握手）→ 存 _workerPort
///            _FrameResult → 按 id 完成对应 Completer
///   captureFrame(): 建 Completer 注册到 _pending，发请求，等 future
///   积压控制：后台单线程顺序处理；主侧每帧一个 completer（实时优先）。
class CaptureIsolate {
  Isolate? _isolate;
  SendPort? _workerPort; // 发请求给后台
  final _resultPort = ReceivePort(); // 收后台结果（只订阅一次）
  final Map<int, Completer<Uint8List?>> _pending = {}; // 按帧号配对的挂起请求
  int _captureId = 0;
  bool _started = false;

  /// 启动后台 isolate（建一次 FFI 对象）。
  Future<void> start(int width, int height) async {
    if (_started) return;
    _started = true;
    // 只订阅一次结果流：统一处理握手和帧结果
    _resultPort.listen(_onResult);
    _isolate = await Isolate.spawn(
      _entryPoint,
      _InitialMessage(
          width: width, height: height, mainPort: _resultPort.sendPort),
      debugName: 'capture-isolate',
    );
    // 等后台回 SendPort（握手完成）
    while (_workerPort == null) {
      await Future.delayed(const Duration(milliseconds: 1));
    }
  }

  /// 处理后台消息：SendPort=握手；_FrameResult=按 id 完成请求。
  void _onResult(dynamic msg) {
    if (msg is SendPort) {
      _workerPort = msg; // 握手：拿到发请求的端口
    } else if (msg is _FrameResult) {
      final completer = _pending.remove(msg.id);
      completer?.complete(msg.body);
    }
  }

  /// 请求抓一帧，返回编码后的 CmdCapture body（null = 没变化无需发送）。
  Future<Uint8List?> captureFrame({required bool reset}) async {
    final workerPort = _workerPort;
    if (workerPort == null) return null;
    _captureId++;
    final id = _captureId;
    final completer = Completer<Uint8List?>();
    _pending[id] = completer;
    workerPort.send(_FrameRequest(id: id, reset: reset));
    return completer.future;
  }

  /// 关闭后台 isolate（页面销毁时调用）。
  void dispose() {
    // 先发退出信号，让后台释放 GDI 对象（优雅），再 kill 兜底
    _workerPort?.send(const _ShutdownRequest());
    _isolate?.kill(priority: Isolate.immediate);
    _resultPort.close();
    for (final c in _pending.values) {
      c.complete(null); // 让挂起的请求结束
    }
    _pending.clear();
    _isolate = null;
    _workerPort = null;
    _started = false;
  }
}

/// 主 → 后台的握手消息（启动参数）。
class _InitialMessage {
  final int width;
  final int height;
  final SendPort mainPort; // 主 isolate 收结果端口
  _InitialMessage(
      {required this.width, required this.height, required this.mainPort});
}

/// 主 → 后台的抓帧请求。
class _FrameRequest {
  final int id;
  final bool reset;
  _FrameRequest({required this.id, required this.reset});
}

/// 主 → 后台的退出信号（后台收到后释放 FFI 对象）。
class _ShutdownRequest {
  const _ShutdownRequest();
}

/// 后台 → 主 的抓帧结果（body 为编码后 CmdCapture body；null=没变化）。
class _FrameResult {
  final int id;
  final Uint8List? body;
  _FrameResult({required this.id, required this.body});
}

/// 后台 isolate 入口（顶层函数，不能闭包捕获 FFI 对象）。
void _entryPoint(_InitialMessage msg) {
  // 建一次 FFI 对象 —— 长驻 vs Isolate.run 的本质区别
  final capturer = WindowsCapturer();
  final splitter = TileSplitter();
  final mainPort = msg.mainPort; // 主 isolate 收结果端口
  final workerPort = ReceivePort(); // 后台收请求的端口

  // 把"发请求的端口"回传给主 isolate
  mainPort.send(workerPort.sendPort);

  // 循环等请求，单线程顺序处理（async 回调：capture 是异步的）
  workerPort.listen((req) async {
    if (req is _ShutdownRequest) {
      // 收到退出信号：释放 GDI 对象，结束后台 isolate
      capturer.dispose();
      workerPort.close();
      return;
    }
    if (req is! _FrameRequest) return;
    try {
      final pixels = await capturer.capture(); // 抓屏（BGRA）
      final grid =
          splitter.computeDirtyTiles(pixels, capturer.width, capturer.height);
      Uint8List? body;
      if (grid.isNotEmpty) {
        body = CmdCaptureCodec.buildCaptureFrame(
          id: req.id,
          reset: req.reset,
          width: capturer.width,
          height: capturer.height,
          tileWidth: TileSplitter.tileSize,
          tileHeight: TileSplitter.tileSize,
          tiles: grid
              .map((t) => t == null
                  ? null
                  : DirtyTileData(
                      x: t.x,
                      y: t.y,
                      width: t.width,
                      height: t.height,
                      pixelData: t.pixelData,
                    ))
              .toList(),
        );
      }
      mainPort.send(_FrameResult(id: req.id, body: body));
    } catch (e) {
      // 单帧失败不崩 isolate，回 null 让主侧跳过
      mainPort.send(_FrameResult(id: req.id, body: null));
    }
  });
}
