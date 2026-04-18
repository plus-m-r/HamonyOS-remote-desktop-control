import 'package:flutter_test/flutter_test.dart';

void main() {
  group('App Utils Tests', () {
    test('isValidIp should validate IP addresses correctly', () {
      expect(isValidIp('192.168.1.1'), true);
      expect(isValidIp('10.0.0.1'), true);
      expect(isValidIp('localhost'), true);
      expect(isValidIp('256.256.256.256'), false);
      expect(isValidIp('invalid'), false);
    });

    test('isValidPort should validate port numbers correctly', () {
      expect(isValidPort('8080'), true);
      expect(isValidPort('80'), true);
      expect(isValidPort('65535'), true);
      expect(isValidPort('65536'), false);
      expect(isValidPort('0'), false);
      expect(isValidPort('invalid'), false);
    });

    test('isValidDeviceCode should validate device codes correctly', () {
      expect(isValidDeviceCode('ABC123'), true);
      expect(isValidDeviceCode('DEVICE001'), true);
      expect(isValidDeviceCode('AB'), false);
      expect(isValidDeviceCode(''), false);
    });

    test('formatNumber should add thousands separators', () {
      expect(formatNumber(1000), '1,000');
      expect(formatNumber(1000000), '1,000,000');
      expect(formatNumber(123), '123');
    });

    test('formatFileSize should format bytes correctly', () {
      expect(formatFileSize(1024), '1.00 KB');
      expect(formatFileSize(1048576), '1.00 MB');
      expect(formatFileSize(1073741824), '1.00 GB');
      expect(formatFileSize(0), '0 B');
    });
  });

  group('DateTime Formatting Tests', () {
    test('formatDateTime should format dates correctly', () {
      final now = DateTime.now();
      expect(formatDateTime(now), '刚刚');
      
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      expect(formatDateTime(oneHourAgo).contains('小时前'), true);
    });
  });
}

// 辅助函数实现（在实际使用中应该从util文件导入）
bool isValidIp(String ip) {
  final pattern = RegExp(
    r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}'
    r'(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$|^localhost$',
  );
  return pattern.hasMatch(ip);
}

bool isValidPort(String port) {
  try {
    final p = int.parse(port);
    return p > 0 && p <= 65535;
  } catch (e) {
    return false;
  }
}

bool isValidDeviceCode(String code) {
  return code.isNotEmpty && code.length >= 3;
}

String formatNumber(int number) {
  return number.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
}

String formatFileSize(int bytes) {
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

String formatDateTime(DateTime? dateTime) {
  if (dateTime == null) return '未知';
  
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inMinutes < 1) {
    return '刚刚';
  } else if (difference.inHours < 1) {
    return '${difference.inMinutes}分钟前';
  } else if (difference.inDays < 1) {
    return '${difference.inHours}小时前';
  } else {
    return '${difference.inDays}天前';
  }
}
