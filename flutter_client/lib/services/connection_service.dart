import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/models.dart';

class ConnectionService extends GetxService {
  final logger = Logger();
  
  final isConnected = false.obs;
  final isConnecting = false.obs;
  final errorMessage = Rxn<String>();
  final currentDevice = Rxn<RemoteDevice>();
  final connectionStatus = Rx<ConnectionStatus>(
    const ConnectionStatus(isConnected: false),
  );

  late ConnectionConfig _config;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  WebSocketChannel? _wsChannel;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectDelay = Duration(seconds: 5);
  static const Duration heartbeatInterval = Duration(seconds: 3);

  // 流事件
  final _frameStreamController = StreamController<FrameData>.broadcast();
  final _statusStreamController = StreamController<ConnectionStatus>.broadcast();

  Stream<FrameData> get frameStream => _frameStreamController.stream;
  Stream<ConnectionStatus> get statusStream => _statusStreamController.stream;

  @override
  void onClose() {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _wsChannel?.sink.close();
    _frameStreamController.close();
    _statusStreamController.close();
    super.onClose();
  }

  /// 初始化连接 - 建立WebSocket连接
  Future<bool> initializeConnection(ConnectionConfig config) async {
    try {
      isConnecting.value = true;
      _config = config;
      _reconnectAttempts = 0;
      errorMessage.value = null;

      logger.i('初始化WebSocket连接: ${config.serverIp}:${config.robotPort}');

      // 构建WebSocket URL
      final wsUrl = 'ws://${config.serverIp}:${config.robotPort}';
      
      try {
        // 建立WebSocket连接
        _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
        
        // 等待连接建立
        await Future.delayed(const Duration(milliseconds: 500));
        
        // 监听WebSocket消息
        _wsChannel!.stream.listen(
          _handleWebSocketMessage,
          onError: _handleWebSocketError,
          onDone: _handleWebSocketClosed,
        );
        
        // 启动心跳
        _startHeartbeat();
        
        isConnected.value = true;
        isConnecting.value = false;

        final newStatus = connectionStatus.value.copyWith(
          isConnected: true,
          lastConnectionTime: DateTime.now(),
          errorMessage: null,
          reconnectAttempts: 0,
        );
        connectionStatus.value = newStatus;
        _statusStreamController.add(newStatus);

        logger.i('WebSocket连接成功');
        
        // 启动屏幕帧捕获
        _startFrameCapture();
        
        return true;
      } on SocketException catch (e) {
        throw Exception('WebSocket连接失败: ${e.message}');
      }
    } catch (e) {
      logger.e('初始化连接失败: $e');
      isConnecting.value = false;
      errorMessage.value = e.toString();
      _handleConnectionError();
      return false;
    }
  }

  /// 处理WebSocket消息
  void _handleWebSocketMessage(dynamic message) {
    try {
      if (message is String) {
        final data = jsonDecode(message) as Map<String, dynamic>;
        final messageType = data['type'] as String?;
        
        switch (messageType) {
          case 'frameData':
            _processFrameData(data['data'] as Map<String, dynamic>);
            break;
          case 'pong':
            logger.d('收到心跳响应');
            break;
          case 'error':
            logger.w('服务器错误: ${data['message']}');
            break;
          default:
            logger.d('收到未知消息类型: $messageType');
        }
      } else if (message is List<int>) {
        // 二进制消息 - 屏幕帧数据
        _processBinaryFrameData(message);
      }
    } catch (e) {
      logger.e('处理消息异常: $e');
    }
  }

  /// 处理WebSocket错误
  void _handleWebSocketError(dynamic error) {
    logger.e('WebSocket错误: $error');
    errorMessage.value = '连接错误: $error';
    _handleConnectionError();
  }

  /// 处理WebSocket关闭
  void _handleWebSocketClosed() {
    logger.i('WebSocket连接已关闭');
    isConnected.value = false;
    _heartbeatTimer?.cancel();
    
    final newStatus = connectionStatus.value.copyWith(
      isConnected: false,
      errorMessage: '连接已断开',
    );
    connectionStatus.value = newStatus;
    _statusStreamController.add(newStatus);
    
    _handleConnectionError();
  }

  /// 处理帧数据 (JSON格式)
  void _processFrameData(Map<String, dynamic> data) {
    try {
      final frame = FrameData.fromJavaResponse(
        data,
        data['width'] as int? ?? 1920,
        data['height'] as int? ?? 1080,
      );
      _frameStreamController.add(frame);
    } catch (e) {
      logger.e('处理帧数据失败: $e');
    }
  }

  /// 处理帧数据 (二进制格式)
  void _processBinaryFrameData(List<int> bytes) {
    try {
      // 假设二进制数据格式: [帧ID(4字节)] [宽度(2字节)] [高度(2字节)] [数据]
      if (bytes.length < 8) return;
      
      final frameId = ByteData.view(
        bytes.buffer,
        bytes.offsetInBytes,
        4,
      ).getInt32(0);
      
      final width = ByteData.view(
        bytes.buffer,
        bytes.offsetInBytes + 4,
        2,
      ).getInt16(0);
      
      final height = ByteData.view(
        bytes.buffer,
        bytes.offsetInBytes + 6,
        2,
      ).getInt16(0);
      
      final imageData = bytes.sublist(8);
      
      final frame = FrameData(
        frameId: frameId,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        imageData: imageData,
        compressionType: 'binary',
        width: width,
        height: height,
      );
      
      _frameStreamController.add(frame);
    } catch (e) {
      logger.e('处理二进制帧数据失败: $e');
    }
  }

  /// 启动心跳
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      _sendHeartbeat();
    });
  }

  /// 发送心跳
  void _sendHeartbeat() {
    try {
      if (_wsChannel != null && isConnected.value) {
        _wsChannel!.sink.add(jsonEncode({
          'type': 'ping',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }));
      }
    } catch (e) {
      logger.e('发送心跳失败: $e');
    }
  }

  /// 启动屏幕帧捕获（请求服务器发送帧）
  void _startFrameCapture() {
    try {
      _wsChannel?.sink.add(jsonEncode({
        'type': 'startCapture',
        'fps': 30,
      }));
      logger.i('已请求屏幕帧捕获');
    } catch (e) {
      logger.e('启动帧捕获失败: $e');
    }
  }

  /// 打开远程屏幕
  Future<bool> openRemoteScreen(
    String deviceCode,
    String password,
  ) async {
    try {
      isConnecting.value = true;
      logger.i('打开远程屏幕: $deviceCode');

      // 模拟打开屏幕
      await Future.delayed(const Duration(milliseconds: 800));

      isConnecting.value = false;
      logger.i('远程屏幕已打开');
      return true;
    } catch (e) {
      logger.e('打开远程屏幕失败: $e');
      isConnecting.value = false;
      errorMessage.value = e.toString();
      return false;
    }
  }

  /// 关闭远程屏幕
  Future<void> closeRemoteScreen() async {
    try {
      logger.i('关闭远程屏幕');
      await Future.delayed(const Duration(milliseconds: 300));
      logger.i('远程屏幕已关闭');
    } catch (e) {
      logger.e('关闭远程屏幕失败: $e');
      rethrow;
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    try {
      logger.i('断开连接');
      _reconnectTimer?.cancel();
      isConnected.value = false;

      final newStatus = connectionStatus.value.copyWith(
        isConnected: false,
      );
      connectionStatus.value = newStatus;
      _statusStreamController.add(newStatus);

      await Future.delayed(const Duration(milliseconds: 200));
      logger.i('连接已断开');
    } catch (e) {
      logger.e('断开连接失败: $e');
      rethrow;
    }
  }

  /// 发送鼠标事件
  Future<void> sendMouseEvent(MouseEvent event) async {
    try {
      if (!isConnected.value || _wsChannel == null) {
        throw Exception('未连接到服务器');
      }
      
      // 使用Java协议格式发送
      _wsChannel!.sink.add(jsonEncode({
        'type': 'mouseEvent',
        'data': event.toJavaProtocol(),
      }));
      
      logger.d('已发送鼠标事件: x=${event.x}, y=${event.y}, action=${event.action}');
    } catch (e) {
      logger.e('发送鼠标事件失败: $e');
      rethrow;
    }
  }

  /// 发送键盘事件
  Future<void> sendKeyboardEvent(KeyboardEvent event) async {
    try {
      if (!isConnected.value || _wsChannel == null) {
        throw Exception('未连接到服务器');
      }
      
      // 使用Java协议格式发送
      _wsChannel!.sink.add(jsonEncode({
        'type': 'keyboardEvent',
        'data': event.toJavaProtocol(),
      }));
      
      logger.d('已发送键盘事件: keyCode=${event.keyCode}, action=${event.action}');
    } catch (e) {
      logger.e('发送键盘事件失败: $e');
      rethrow;
    }
  }
    } catch (e) {
      logger.e('发送键盘事件失败: $e');
      rethrow;
    }
  }

  /// 处理连接错误和重新连接
  void _handleConnectionError() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      logger.e('达到最大重新连接次数，停止重新连接');
      final newStatus = connectionStatus.value.copyWith(
        isConnected: false,
        errorMessage: '连接失败，已达到最大重试次数',
      );
      connectionStatus.value = newStatus;
      _statusStreamController.add(newStatus);
      return;
    }

    _reconnectAttempts++;
    logger.i('第 $_reconnectAttempts 次重新连接尝试，在 ${reconnectDelay.inSeconds} 秒后重试');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(reconnectDelay, () {
      _attemptReconnect();
    });
  }

  /// 尝试重新连接
  Future<void> _attemptReconnect() async {
    try {
      await initializeConnection(_config);
      _reconnectAttempts = 0;
    } catch (e) {
      logger.e('重新连接失败: $e');
      _handleConnectionError();
    }
  }

  /// 模拟接收视频帧
  void startFrameCapture() {
    logger.i('开始捕获视频帧');
    Timer.periodic(const Duration(milliseconds: 33), (timer) {
      if (!isConnected.value) {
        timer.cancel();
        return;
      }

      final frameData = FrameData(
        frameId: timer.tick,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        imageData: [],
        compressionType: 'zstd',
        width: 1920,
        height: 1080,
      );

      _frameStreamController.add(frameData);
    });
  }
}
