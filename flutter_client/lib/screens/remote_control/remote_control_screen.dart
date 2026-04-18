import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/remote_control_controller.dart';
import '../../theme/app_theme.dart';

class RemoteControlScreen extends StatelessWidget {
  const RemoteControlScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(RemoteControlController());

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _showExitDialog(context, controller);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Obx(() => Text(controller.currentDevice.value?.deviceName ?? '远程控制')),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _showExitDialog(context, controller),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showConnectionInfo(context, controller),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showMoreOptions(context, controller),
            ),
          ],
        ),
        body: Obx(() {
          if (controller.isConnecting.value) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppTheme.spacingL),
                  Text(
                    '正在连接...',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            );
          }

          if (!controller.isConnected.value) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: 64,
                    color: AppTheme.disabledColor,
                  ),
                  const SizedBox(height: AppTheme.spacingL),
                  Text(
                    '连接已断开',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    controller.errorMessage.value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacingL),
                  ElevatedButton(
                    onPressed: () => controller.reconnect(),
                    child: const Text('重新连接'),
                  ),
                ],
              ),
            );
          }

          return Stack(
            children: [
              // 远程屏幕显示区域
              Container(
                color: Colors.black,
                child: GestureDetector(
                  onTapDown: (details) {
                    controller.handleMouseEvent(
                      details.globalPosition.dx,
                      details.globalPosition.dy,
                      'left',
                      'down',
                    );
                  },
                  onTapUp: (details) {
                    controller.handleMouseEvent(
                      details.globalPosition.dx,
                      details.globalPosition.dy,
                      'left',
                      'up',
                    );
                  },
                  onPanUpdate: (details) {
                    controller.handleMouseEvent(
                      details.globalPosition.dx,
                      details.globalPosition.dy,
                      'left',
                      'move',
                    );
                  },
                  child: const RemoteScreenWidget(),
                ),
              ),

              // 控制工具栏
              if (controller.showToolbar.value)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.black87,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingM,
                      vertical: AppTheme.spacingS,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ToolbarButton(
                          icon: Icons.keyboard,
                          label: '键盘',
                          onPressed: () => controller.showKeyboard(),
                        ),
                        _ToolbarButton(
                          icon: Icons.touch_app,
                          label: '鼠标',
                          onPressed: () => controller.showMousePad(),
                        ),
                        _ToolbarButton(
                          icon: Icons.screenshot,
                          label: '截图',
                          onPressed: () => controller.takeScreenshot(),
                        ),
                        _ToolbarButton(
                          icon: Icons.more_horiz,
                          label: '更多',
                          onPressed: () =>
                              _showToolbarOptions(context, controller),
                        ),
                      ],
                    ),
                  ),
                ),

              // 工具栏切换按钮
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  mini: true,
                  onPressed: () {
                    controller.showToolbar.value = !controller.showToolbar.value;
                  },
                  child: Icon(
                    controller.showToolbar.value
                        ? Icons.expand_more
                        : Icons.expand_less,
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  void _showExitDialog(BuildContext context, RemoteControlController controller) {
    Get.dialog(
      AlertDialog(
        title: const Text('退出远程控制'),
        content: const Text('确定要断开连接吗?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              controller.disconnect();
              Get.back();
              Get.back();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showConnectionInfo(BuildContext context, RemoteControlController controller) {
    Get.dialog(
      AlertDialog(
        title: const Text('连接信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow('设备名称', controller.currentDevice.value?.deviceName ?? '未知'),
            _InfoRow('设备型号', controller.currentDevice.value?.deviceModel ?? '未知'),
            _InfoRow('分辨率', controller.currentDevice.value?.screenResolution ?? '未知'),
            _InfoRow('连接状态', controller.isConnected.value ? '已连接' : '未连接'),
          ],
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

  void _showMoreOptions(BuildContext context, RemoteControlController controller) {
    Get.bottomSheet(
      Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.key),
              title: const Text('修改密码'),
              onTap: () {
                Get.back();
                // 实现修改密码功能
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('刷新屏幕'),
              onTap: () {
                Get.back();
                controller.refreshScreen();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('连接设置'),
              onTap: () {
                Get.back();
                // 实现连接设置功能
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showToolbarOptions(BuildContext context, RemoteControlController controller) {
    Get.bottomSheet(
      Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('输入文本'),
              onTap: () {
                Get.back();
                controller.showTextInput();
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('粘贴剪贴板'),
              onTap: () {
                Get.back();
                controller.pasteFromClipboard();
              },
            ),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('同步剪贴板'),
              onTap: () {
                Get.back();
                controller.syncClipboard();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class RemoteScreenWidget extends StatefulWidget {
  const RemoteScreenWidget({Key? key}) : super(key: key);

  @override
  State<RemoteScreenWidget> createState() => _RemoteScreenWidgetState();
}

class _RemoteScreenWidgetState extends State<RemoteScreenWidget> {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<RemoteControlController>();

    return Obx(() {
      final frame = controller.currentFrame.value;

      if (frame == null) {
        return _buildPlaceholder();
      }

      // 如果有帧数据，尝试显示图像
      return _buildRemoteScreen(frame);
    });
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam,
              size: 64,
              color: AppTheme.primaryColor.withOpacity(0.3),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              '等待屏幕数据...',
              style: TextStyle(
                color: AppTheme.primaryColor.withOpacity(0.3),
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteScreen(FrameData frame) {
    try {
      // 如果imageData为空，显示占位符
      if (frame.imageData.isEmpty) {
        return _buildPlaceholder();
      }

      // 显示远程屏幕图像
      return Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: Image.memory(
              frame.imageData,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return _buildErrorWidget(error);
              },
              semanticLabel: '远程屏幕 ${frame.frameId}',
            ),
          ),
        ),
      );
    } catch (e) {
      return _buildErrorWidget(e);
    }
  }

  Widget _buildErrorWidget(Object error) {
    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.errorColor.withOpacity(0.5),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              '图像显示失败',
              style: TextStyle(
                color: AppTheme.errorColor.withOpacity(0.7),
                fontSize: 18,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                error.toString(),
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.white),
          onPressed: onPressed,
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(value),
        ],
      ),
    );
  }
}
