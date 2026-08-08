import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';

import '../capture/tile_splitter.dart';
import '../platform/windows_capturer.dart';
import '../platform/windows_injector.dart';
import '../protocol/cmd_capture_codec.dart';
import '../protocol/cmd_codec.dart';
import '../protocol/cmd_type.dart';

/// 连接页：分三块——连接服务端 / 连接设备 / 本机设置。
class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  // 连接服务端用的输入
  final TextEditingController _ipController = TextEditingController(text: '');
  final TextEditingController _portController = TextEditingController(text: '');

  // 连接设备用的输入
  final TextEditingController _deviceCodeController =
      TextEditingController(text: '');
  final TextEditingController _linkPasswordController =
      TextEditingController(text: '');

  // 状态
  bool _connectingServer = false;
  bool _connectingDevice = false;
  String _serverStatus = '';
  String _deviceStatus = '';
  String _deviceCode = ''; // 服务器返回的本机设备码
  String _linkPassword = ''; // 服务器返回的本机密码
  Socket? _socket;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  DateTime? _lastrepongtime; // 上次收到心跳的时间，用于判断连接是否断开
  bool _waitingDeviceResp = false; // 正在等待"连接设备"的 resCapture 响应
  Timer? _captureTimer; // 抓屏定时器（30ms 一帧）
  WindowsCapturer? _capturer; // 屏幕捕获器（延迟创建：首次抓屏时才建）
  final _tileSplitter = TileSplitter(); // 瓦片切分器
  final _injector = WindowsInjector(); // 输入注入器（SendInput）
  int _captureId = 0; // 帧序号
  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _deviceCodeController.dispose();
    _linkPasswordController.dispose();
    _socket?.destroy();
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _captureTimer?.cancel();
    super.dispose();
  }

  /// 连接服务端：连上 TCP → 收 resCliInfo（设备码+密码）→ 发 reqCliInfo 上报本机信息。
  Future<void> _connectServer() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    if (ip.isEmpty || port == null) {
      setState(() => _serverStatus = '请输入正确的 IP 和端口');
      return;
    }
    setState(() {
      _connectingServer = true;
      _serverStatus = '正在连接服务器 $ip:$port …';
    });
    try {
      final socket =
          await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
      _socket = socket;
      _lastrepongtime = DateTime.now(); // 连上即视为活着

      // 统一用 socket.listen 持续监听（socket 流只能被监听一次！）
      _startReadLoop(socket);

      // 2. 上报本机信息（屏幕数 + 系统名），服务器随后下发 resCliInfo
      final reqBody = CmdCodec.buildReqCliInfoBody(1, 'Windows');
      socket.add(CmdCodec.encode(CmdType.reqCliInfo, reqBody));

      // 3. 启动心跳定时器，每 5 秒发一次 reqPing
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        final lasttime = _lastrepongtime;
        if (lasttime != null &&
            DateTime.now().difference(lasttime) > const Duration(seconds: 15)) {
          _handleDisconnect(); // 超 15 秒无数据 → 判死重连
          return;
        }
        try {
          socket.add(CmdCodec.encode(CmdType.reqPing, Uint8List(0)));
        } catch (e) {
          _handleDisconnect();
        }
      });
      _reconnectTimer?.cancel(); // 连上了，取消待触发的重连
      if (!mounted) return;
      setState(() {
        _connectingServer = false;
        _serverStatus = '连接成功，等待设备信息…';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connectingServer = false;
        _serverStatus = '连接失败：$e,5秒后尝试重连…';
      });
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {
        _serverStatus = '尝试重连…';
      });
      _connectServer();
    });
  }
  void _handleDisconnect(){
    if (!mounted) return;
    _heartbeatTimer?.cancel();
    setState(() {
      _connectingServer = false;
      _serverStatus = '与服务器断开连接，5秒后尝试重连…';
    });
    _scheduleReconnect();
  }

  /// 连接设备：向服务器发送 reqCapture（设备码+密码），请求开始控制目标设备。
  Future<void> _connectDevice() async {
    final deviceCode = _deviceCodeController.text.trim();
    final password = _linkPasswordController.text.trim();
    if (deviceCode.isEmpty || password.isEmpty) {
      setState(() => _deviceStatus = '请输入设备码和链接密码');
      return;
    }
    final socket = _socket;
    if (socket == null) {
      setState(() => _deviceStatus = '请先连接服务端');
      return;
    }
    setState(() {
      _connectingDevice = true;
      _deviceStatus = '正在连接设备 $deviceCode …';
    });
    try {
      // 0 = 开始截屏（建立控制会话）
      final body = CmdCodec.buildReqCaptureBody(deviceCode, 0, password);
      socket.add(CmdCodec.encode(CmdType.reqCapture, body));
      // 响应由 _startReadLoop 的监听收到（_onFrame 处理 resCapture），这里只等
      _waitingDeviceResp = true;
      setState(() {
        _deviceStatus = '已发送连接请求，等待服务器确认…';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connectingDevice = false;
        _deviceStatus = '发送失败：$e';
      });
    }
  }

  /// 唯一的数据监听：收字节 → 攒缓冲 → 解析出完整帧 → 分发。
  /// 注意：socket 是单订阅流，全连接生命周期只能 listen 这一次。
  void _startReadLoop(Socket socket) {
    var builder = BytesBuilder();
    socket.listen(
      (chunk) {
        builder.add(chunk);
        // 循环解析缓冲里的完整帧（可能一次收多帧）
        while (true) {
          final bytes = builder.toBytes();
          if (bytes.length < CmdCodec.headerLength) break; // 帧头都没齐
          final length = ByteData.sublistView(bytes).getUint32(3);
          final frameLength = CmdCodec.headerLength + length;
          if (bytes.length < frameLength) break; // body 没齐，等更多数据
          // 取出一帧并移除已消费部分
          final frame = bytes.sublist(0, frameLength);
          final rest = bytes.sublist(frameLength);
          builder = BytesBuilder()..add(rest);
          _onFrame(frame);
        }
      },
      onDone: () => _handleDisconnect(), // 流结束 = 服务器关闭连接
      onError: (_) => _handleDisconnect(), // 读错误 = 断开
    );
  }

  /// 收到一帧完整数据后的处理。
  void _onFrame(Uint8List frame) {
    _lastrepongtime = DateTime.now(); // 收到任何帧 = 连接活着
    final (type, body) = CmdCodec.decode(frame);
    if (type == CmdType.resCliInfo) {
      // 握手帧：服务器下发本机设备码+密码
      final (deviceCode, password) = CmdCodec.parseResCliInfoBody(body);
      if (!mounted) return;
      setState(() {
        _deviceCode = deviceCode; // 填进"本机设置"区
        _linkPassword = password;
        _serverStatus = '连接成功，已获取本机设备信息';
      });
    } else if (type == CmdType.resCapture) {
      // 服务器转发的被控端截屏指令：0x10=开始 0x11=停止（CmdResCapture.START_/STOP_）
      final code = body.isEmpty ? -1 : body[0];
      if (code == 0x10) {
        _startCaptureLoop(); // 开始持续抓屏
        if (!mounted) return;
        setState(() => _deviceStatus = '正在被远程控制中…');
      } else if (code == 0x11) {
        _stopCaptureLoop(); // 停止抓屏
        if (!mounted) return;
        setState(() => _deviceStatus = '远程控制已结束');
      } else if (_waitingDeviceResp) {
        // 控制端发起的连接设备响应（设备码+密码校验结果）
        _waitingDeviceResp = false;
        if (!mounted) return;
        setState(() => _deviceStatus = '设备连接成功（状态码 $code）');
      }
    } else if (type == CmdType.mouseControl) {
      _handleMouseControl(body); // 鸿蒙端鼠标命令 → 本机注入
    } else if (type == CmdType.keyControl) {
      _handleKeyControl(body); // 鸿蒙端键盘命令 → 本机注入
    }
  }

  /// 解析并执行鼠标命令（CmdMouseControl）。
  /// info 位：PRESSED=1 RELEASED=2 BUTTON1=4 BUTTON2=8 BUTTON3=16 WHEEL=32
  void _handleMouseControl(Uint8List body) {
    final data = ByteData.sublistView(body);
    if (body.length < 8) return; // x(2)+y(2)+info(4) 至少 8 字节
    final x = data.getInt16(0); // 屏幕坐标
    final y = data.getInt16(2);
    final info = data.getUint32(4);
    var rotations = 0;
    if ((info & 32) != 0 && body.length >= 12) {
      rotations = data.getInt32(8); // WHEEL 才有 rotations
    }

    // 先移动鼠标到目标位置（Java：move 之后才 press/release）
    _injector.moveMouse(x, y);

    if ((info & 1) != 0) {
      // PRESSED
      if ((info & 4) != 0) _injector.mouseDown(1); // BUTTON1=左
      if ((info & 8) != 0) _injector.mouseDown(2); // BUTTON2=中
      if ((info & 16) != 0) _injector.mouseDown(3); // BUTTON3=右
    } else if ((info & 2) != 0) {
      // RELEASED
      if ((info & 4) != 0) _injector.mouseUp(1);
      if ((info & 8) != 0) _injector.mouseUp(2);
      if ((info & 16) != 0) _injector.mouseUp(3);
    } else if ((info & 32) != 0) {
      _injector.mouseWheel(rotations); // 滚轮
    }
  }

  /// 解析并执行键盘命令（CmdKeyControl）。
  /// info 位：PRESSED=1 RELEASED=2
  void _handleKeyControl(Uint8List body) {
    final data = ByteData.sublistView(body);
    if (body.length < 8) return; // info(4)+keyCode(4) 至少 8 字节
    final info = data.getUint32(0);
    final keyCode = data.getInt32(4);

    if ((info & 1) != 0) {
      _injector.keyDown(keyCode); // PRESSED
    } else if ((info & 2) != 0) {
      _injector.keyUp(keyCode); // RELEASED
    }
  }

  /// 启动抓屏循环：每 30ms 抓一帧 → 切瓦片 → 编码 → 发送。
  void _startCaptureLoop() {
    _captureTimer?.cancel();
    _captureTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      _sendCaptureFrame();
    });
  }

  /// 停止抓屏循环。
  void _stopCaptureLoop() {
    _captureTimer?.cancel();
    _captureTimer = null;
  }

  /// 抓一帧屏幕并发送 CmdCapture。
  Future<void> _sendCaptureFrame() async {
    final socket = _socket;
    if (socket == null) return;
    try {
      // 延迟创建抓屏器（首次抓屏时才建，避免启动时初始化崩溃）
      final capturer = _capturer ??= WindowsCapturer();
      final pixels = await capturer.capture(); // 1. 抓屏（BGRA）
      final grid = _tileSplitter.computeDirtyTiles(
          pixels, capturer.width, capturer.height); // 2. 切瓦片找变化（完整网格，null=没变）
      if (grid.isEmpty) return; // 没变化不发送（省带宽）

      _captureId++;
      // 3. 编码成 CmdCapture body（网格转 DirtyTileData，null 保持 null）
      final body = CmdCaptureCodec.buildCaptureFrame(
        id: _captureId,
        reset: _captureId == 1, // 首帧 reset=1，鸿蒙端清缓存重建
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
      // 4. 外包 CmdCodec 帧头并发送
      socket.add(CmdCodec.encode(CmdType.capture, body));
    } catch (e) {
      debugPrint('抓屏发送失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCard(
            title: '连接服务端',
            children: [
              _buildTextField(_ipController, '服务端 IP', '请输入服务端 IP 地址'),
              const SizedBox(height: 16),
              _buildTextField(_portController, '服务端端口', '请输入服务端端口号',
                  isNumber: true),
              const SizedBox(height: 20),
              _buildConnectButton(
                label: '连接服务端',
                connecting: _connectingServer,
                onPressed: _connectServer,
              ),
              const SizedBox(height: 12),
              Text(_serverStatus, style: const TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 24),
          _buildCard(
            title: '连接设备',
            children: [
              _buildTextField(_deviceCodeController, '设备码', '输入要控制的设备码'),
              const SizedBox(height: 16),
              _buildTextField(_linkPasswordController, '链接密码', '输入设备的链接密码',
                  obscure: true),
              const SizedBox(height: 20),
              _buildConnectButton(
                label: '连接设备',
                connecting: _connectingDevice,
                onPressed: _connectDevice,
              ),
              const SizedBox(height: 12),
              Text(_deviceStatus, style: const TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 24),
          _buildCard(
            title: '本机设置',
            children: [
              _buildInfoRow('设备代码', _deviceCode),
              const SizedBox(height: 8),
              _buildInfoRow('链接密码', _linkPassword),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      String hint, {bool isNumber = false, bool obscure = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : null,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildConnectButton({
    required String label,
    required bool connecting,
    required VoidCallback onPressed,
  }) {
    return FilledButton.icon(
      onPressed: connecting ? null : onPressed,
      icon: connecting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.link),
      label: Text(connecting ? '连接中…' : label),
      style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    // SelectableText = 可选择/长按复制的文字（Text 默认不能复制）
    return Container(
      // Container 包一层，给行加内边距撑高，与输入框高度接近
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFB0BEC5)), // 浅灰边框，与输入框呼应
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label)),
          Expanded(
            child: SelectableText(value.isEmpty ? '未连接' : value),
          ),
        ],
      ),
    );
  }
}
