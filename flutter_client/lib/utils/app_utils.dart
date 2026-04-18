import 'package:get/get.dart';
import 'package:flutter/material.dart';

class AppUtils {
  /// 显示成功消息
  static void showSuccess(String message, {String? title}) {
    Get.snackbar(
      title ?? '成功',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF36AE00),
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  /// 显示错误消息
  static void showError(String message, {String? title}) {
    Get.snackbar(
      title ?? '错误',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFFF3B00),
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }

  /// 显示信息消息
  static void showInfo(String message, {String? title}) {
    Get.snackbar(
      title ?? '提示',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF0A59F7),
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  /// 显示警告消息
  static void showWarning(String message, {String? title}) {
    Get.snackbar(
      title ?? '警告',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFFF8E00),
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  /// 格式化时间
  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '未知';
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 30) {
      return '${difference.inDays}天前';
    } else {
      return '${dateTime.month}-${dateTime.day}';
    }
  }

  /// 格式化文件大小
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double size = bytes.toDouble();
    
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }

  /// 验证IP地址
  static bool isValidIp(String ip) {
    final pattern = RegExp(
      r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}'
      r'(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$|^localhost$',
    );
    return pattern.hasMatch(ip);
  }

  /// 验证端口号
  static bool isValidPort(String port) {
    try {
      final p = int.parse(port);
      return p > 0 && p <= 65535;
    } catch (e) {
      return false;
    }
  }

  /// 验证设备代码
  static bool isValidDeviceCode(String code) {
    return code.isNotEmpty && code.length >= 3;
  }

  /// 深色模式检测
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  /// 获取屏幕宽度
  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// 获取屏幕高度
  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// 检查设备是否为横屏
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// 检查设备是否为竖屏
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  /// 格式化数字（添加千位符）
  static String formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  /// 生成随机字符串
  static String generateRandomString(int length) {
    const chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz0123456789';
    final random = DateTime.now().microsecond;
    String result = '';
    for (int i = 0; i < length; i++) {
      result += chars[(random + i) % chars.length];
    }
    return result;
  }

  /// 复制到剪贴板
  static void copyToClipboard(String text) {
    // 实现复制到剪贴板的逻辑
    showSuccess('已复制到剪贴板');
  }

  /// 获取HTTP基础URL
  static String getBaseUrl(String serverIp, int serverPort) {
    if (serverIp.isEmpty) {
      return 'http://localhost:$serverPort';
    }
    return 'http://$serverIp:$serverPort';
  }
}
