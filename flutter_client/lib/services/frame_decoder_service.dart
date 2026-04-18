import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';
import '../models/models.dart';

/// 屏幕帧解码服务
/// 支持多种压缩格式: JPEG, PNG, raw binary等
class FrameDecoderService {
  final logger = Logger();

  /// 解码帧数据
  /// 支持JPEG, PNG等压缩格式
  Future<Uint8List?> decodeFrame(FrameData frameData) async {
    try {
      if (frameData.imageData.isEmpty) {
        logger.w('帧数据为空');
        return null;
      }

      switch (frameData.compressionType.toLowerCase()) {
        case 'jpeg':
        case 'jpg':
          return _decodeJpeg(frameData);

        case 'png':
          return _decodePng(frameData);

        case 'binary':
        case 'raw':
          return frameData.imageData;

        case 'compressed':
          return _decompressFrame(frameData);

        default:
          logger.w('未知的压缩格式: ${frameData.compressionType}');
          return frameData.imageData;
      }
    } catch (e) {
      logger.e('解码帧失败: $e');
      return null;
    }
  }

  /// 解码JPEG
  Uint8List? _decodeJpeg(FrameData frameData) {
    try {
      // 使用image库解码JPEG
      final image = img.decodeJpg(frameData.imageData);
      if (image == null) {
        logger.e('JPEG解码失败');
        return null;
      }

      // 转换为PNG格式便于显示
      return Uint8List.fromList(img.encodePng(image));
    } catch (e) {
      logger.e('JPEG解码异常: $e');
      return null;
    }
  }

  /// 解码PNG
  Uint8List? _decodePng(FrameData frameData) {
    try {
      final image = img.decodePng(frameData.imageData);
      if (image == null) {
        logger.e('PNG解码失败');
        return null;
      }

      // 直接返回PNG数据
      return frameData.imageData;
    } catch (e) {
      logger.e('PNG解码异常: $e');
      return null;
    }
  }

  /// 解压缩帧数据
  /// 支持gzip等常见压缩方式
  Uint8List? _decompressFrame(FrameData frameData) {
    try {
      // 如果是gzip压缩，可以在这里解压
      // 目前直接返回原始数据
      logger.d('压缩帧数据大小: ${frameData.imageData.length} bytes');
      return frameData.imageData;
    } catch (e) {
      logger.e('解压缩失败: $e');
      return null;
    }
  }

  /// 生成缩略图
  Future<Uint8List?> generateThumbnail(FrameData frameData, int width, int height) async {
    try {
      final decoded = await decodeFrame(frameData);
      if (decoded == null) return null;

      final image = img.decodeImage(decoded);
      if (image == null) return null;

      final thumbnail = img.copyResize(image, width: width, height: height);
      return Uint8List.fromList(img.encodePng(thumbnail));
    } catch (e) {
      logger.e('生成缩略图失败: $e');
      return null;
    }
  }

  /// 获取帧信息
  String getFrameInfo(FrameData frameData) {
    final size = _formatFileSize(frameData.imageData.length);
    return '帧#${frameData.frameId} | ${frameData.width}x${frameData.height} | $size | ${frameData.compressionType}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
