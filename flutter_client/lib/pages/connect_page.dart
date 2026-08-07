import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

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

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _deviceCodeController.dispose();
    _linkPasswordController.dispose();
    _socket?.destroy();
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

      // 1. 服务器连上会自动下发 resCliInfo（NettyServerHandler.channelActive）
      final (type, body) = await _readFrame(socket);
      if (type != CmdType.resCliInfo) {
        throw Exception('服务器返回了意外命令: ${type.name}');
      }
      final (deviceCode, password) = CmdCodec.parseResCliInfoBody(body);

      // 2. 收到设备码密码后，再上报本机信息（屏幕数 + 系统名）
      final reqBody = CmdCodec.buildReqCliInfoBody(1, 'Windows');
      socket.add(CmdCodec.encode(CmdType.reqCliInfo, reqBody));

      if (!mounted) return;
      setState(() {
        _connectingServer = false;
        _deviceCode = deviceCode; // 填进"本机设置"区
        _linkPassword = password;
        _serverStatus = '连接成功，已获取本机设备信息';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connectingServer = false;
        _serverStatus = '连接失败：$e';
      });
    }
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

      // 等待服务器返回 resCapture 确认
      final (type, respBody) = await _readFrame(socket);
      if (type != CmdType.resCapture) {
        throw Exception('服务器返回了意外命令: ${type.name}');
      }
      final code = respBody.isEmpty ? -1 : respBody[0]; // resCapture 第 1 字节是状态码
      if (!mounted) return;
      setState(() {
        _connectingDevice = false;
        _deviceStatus = '设备连接成功（状态码 $code）';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connectingDevice = false;
        _deviceStatus = '连接失败：$e';
      });
    }
  }

  /// 从 socket 读取完整一帧（7 字节头 + body）。
  Future<(CmdType, Uint8List)> _readFrame(Socket socket) async {
    final builder = BytesBuilder();
    // 先收齐 7 字节帧头
    while (builder.length < CmdCodec.headerLength) {
      final chunk = await socket.first;
      builder.add(chunk);
    }
    final header = builder.toBytes();
    final length = ByteData.sublistView(header).getUint32(3);
    // 再收齐 body
    while (builder.length < CmdCodec.headerLength + length) {
      final chunk = await socket.first;
      builder.add(chunk);
    }
    return CmdCodec.decode(builder.toBytes());
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
