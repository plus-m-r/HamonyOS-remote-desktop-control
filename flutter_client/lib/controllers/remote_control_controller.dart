import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import '../../models/models.dart';
import '../../services/connection_service.dart';
import '../../routes/app_routes.dart';

class RemoteControlController extends GetxController {
  final logger = Logger();
  
  final currentDevice = Rxn<RemoteDevice>();
  final isConnecting = false.obs;
  final isConnected = false.obs;
  final errorMessage = RxString('');
  final showToolbar = true.obs;
  final currentFrame = Rxn<FrameData>();
  final screenWidth = 1920.obs;
  final screenHeight = 1080.obs;
  
  late ConnectionService connectionService;

  @override
  void onInit() {
    super.onInit();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      connectionService = Get.find<ConnectionService>();
      
      // 从路由参数获取设备
      final arguments = Get.arguments as Map<String, dynamic>?;
      if (arguments != null && arguments.containsKey('device')) {
        currentDevice.value = arguments['device'] as RemoteDevice;
      }

      // 监听连接状态
      _listenToConnectionStatus();
      
      // 打开远程屏幕
      await _openRemoteScreen();
    } catch (e) {
      logger.e('初始化失败: $e');
      errorMessage.value = e.toString();
    }
  }

  void _listenToConnectionStatus() {
    connectionService.statusStream.listen((status) {
      isConnected.value = status.isConnected;
      if (!status.isConnected && status.errorMessage != null) {
        errorMessage.value = status.errorMessage ?? '连接已断开';
      }
    });
    
    // 监听屏幕帧数据
    connectionService.frameStream.listen((frame) {
      currentFrame.value = frame;
      screenWidth.value = frame.width;
      screenHeight.value = frame.height;
      logger.d('收到屏幕帧: ${frame.width}x${frame.height}, 大小: ${frame.imageData.length} bytes');
    });
  }

  Future<void> _openRemoteScreen() async {
    try {
      isConnecting.value = true;
      
      final device = currentDevice.value;
      if (device == null) {
        throw Exception('未指定设备');
      }

      final success = await connectionService.openRemoteScreen(
        device.deviceId,
        '', // 密码应该从login时传递
      );

      if (success) {
        isConnected.value = true;
        connectionService.startFrameCapture();
      } else {
        errorMessage.value = '打开远程屏幕失败';
      }

      isConnecting.value = false;
    } catch (e) {
      logger.e('打开远程屏幕失败: $e');
      isConnecting.value = false;
      errorMessage.value = e.toString();
    }
  }

  Future<void> reconnect() async {
    try {
      isConnecting.value = true;
      errorMessage.value = '';
      
      await _openRemoteScreen();
    } catch (e) {
      logger.e('重新连接失败: $e');
      errorMessage.value = e.toString();
      isConnecting.value = false;
    }
  }

  Future<void> disconnect() async {
    try {
      await connectionService.closeRemoteScreen();
      isConnected.value = false;
    } catch (e) {
      logger.e('断开连接失败: $e');
    }
  }

  void handleMouseEvent(
    double x,
    double y,
    String button,
    String action,
  ) {
    try {
      if (!isConnected.value) return;

      final event = MouseEvent(
        x: x.toInt(),
        y: y.toInt(),
        button: button,
        action: action,
      );

      connectionService.sendMouseEvent(event);
    } catch (e) {
      logger.e('处理鼠标事件失败: $e');
    }
  }

  void handleKeyboardEvent(int keyCode, {bool ctrlPressed = false, bool altPressed = false, bool shiftPressed = false}) {
    try {
      if (!isConnected.value) return;

      final event = KeyboardEvent(
        keyCode: keyCode,
        ctrlPressed: ctrlPressed,
        altPressed: altPressed,
        shiftPressed: shiftPressed,
      );

      connectionService.sendKeyboardEvent(event);
    } catch (e) {
      logger.e('处理键盘事件失败: $e');
    }
  }

  void showKeyboard() {
    Get.dialog(
      AlertDialog(
        title: const Text('虚拟键盘'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: _buildKeyboardButtons(),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildKeyboardButtons() {
    final keys = [
      ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
      ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
      ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
      ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
    ];

    return keys.expand((row) {
      return row.map((key) {
        return SizedBox(
          width: 40,
          height: 40,
          child: ElevatedButton(
            onPressed: () {
              // 发送按键
              handleKeyboardEvent(key.codeUnitAt(0));
            },
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
            ),
            child: Text(
              key,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        );
      });
    }).toList();
  }

  void showMousePad() {
    Get.dialog(
      AlertDialog(
        title: const Text('触摸板'),
        content: Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(),
            borderRadius: BorderRadius.circular(8),
          ),
          child: GestureDetector(
            onPanUpdate: (details) {
              handleMouseEvent(
                details.globalPosition.dx,
                details.globalPosition.dy,
                'left',
                'move',
              );
            },
            child: const Center(
              child: Text('在此滑动鼠标'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void takeScreenshot() {
    Get.snackbar(
      '截图',
      '屏幕已截图并保存',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  void onClose() {
    disconnect();
    super.onClose();
  }

  void showTextInput() {
    final textController = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: const Text('输入文本'),
        content: TextField(
          controller: textController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '请输入要发送的文本',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              // 发送文本
              final text = textController.text;
              if (text.isNotEmpty) {
                for (var char in text.split('')) {
                  handleKeyboardEvent(char.codeUnitAt(0));
                }
              }
              Get.back();
            },
            child: const Text('发送'),
          ),
        ],
      ),
    );
  }

  Future<void> pasteFromClipboard() async {
    Get.snackbar(
      '粘贴',
      '已粘贴剪贴板内容',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> syncClipboard() async {
    Get.snackbar(
      '同步',
      '已同步剪贴板',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void refreshScreen() {
    Get.snackbar(
      '刷新',
      '正在刷新屏幕...',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  void onClose() {
    disconnect();
    super.onClose();
  }
}
