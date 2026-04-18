import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/remote_control_controller.dart';
import '../../models/models.dart';
import '../../services/frame_decoder_service.dart';
import '../../theme/app_theme.dart';

/// 改进版远程屏幕显示Widget
/// 支持多种压缩格式、缩放、流式更新等功能
class RemoteScreenWidgetAdvanced extends StatefulWidget {
  const RemoteScreenWidgetAdvanced({Key? key}) : super(key: key);

  @override
  State<RemoteScreenWidgetAdvanced> createState() => _RemoteScreenWidgetAdvancedState();
}

class _RemoteScreenWidgetAdvancedState extends State<RemoteScreenWidgetAdvanced> with WidgetsBindingObserver {
  late FrameDecoderService _decoderService;
  Uint8List? _decodedImage;
  bool _isDecoding = false;

  @override
  void initState() {
    super.initState();
    _decoderService = FrameDecoderService();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _decodedImage = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<RemoteControlController>();

    return Obx(() {
      final frame = controller.currentFrame.value;

      if (frame == null) {
        return _buildPlaceholder('等待屏幕数据...');
      }

      // 如果帧数据改变，解码新图像
      _decodeFrameAsync(frame);

      return _buildScreenDisplay(frame);
    });
  }

  /// 异步解码帧数据
  void _decodeFrameAsync(FrameData frame) {
    if (_isDecoding || frame.imageData.isEmpty) return;

    _isDecoding = true;
    _decoderService.decodeFrame(frame).then((decoded) {
      if (mounted) {
        setState(() {
          _decodedImage = decoded;
          _isDecoding = false;
        });
      }
    }).catchError((e) {
      _isDecoding = false;
    });
  }

  Widget _buildScreenDisplay(FrameData frame) {
    if (_decodedImage == null) {
      return _buildPlaceholder('解码中...');
    }

    return Stack(
      children: [
        // 屏幕显示区域
        Container(
          color: Colors.black,
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              constrained: true,
              child: Image.memory(
                _decodedImage!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return _buildErrorWidget(error);
                },
                semanticLabel: '远程屏幕 ${frame.frameId}',
              ),
            ),
          ),
        ),

        // 帧信息显示
        if (_shouldShowFrameInfo())
          Positioned(
            bottom: 16,
            right: 16,
            child: _buildFrameInfo(frame),
          ),
      ],
    );
  }

  bool _shouldShowFrameInfo() {
    // 可以通过环境变量或设置来控制是否显示调试信息
    return false; // 生产环境不显示
  }

  Widget _buildFrameInfo(FrameData frame) {
    final info = _decoderService.getFrameInfo(frame);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        info,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String message) {
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
              message,
              style: TextStyle(
                color: AppTheme.primaryColor.withOpacity(0.5),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
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
                error.toString().replaceFirst('Exception: ', ''),
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
