class Constants {
  // 应用相关
  static const String appName = 'HarmonyOS 远程桌面控制';
  static const String appVersion = '1.0.0';
  
  // 服务器配置
  static const String defaultServerIp = 'localhost';
  static const int defaultServerPort = 8080;
  static const String defaultClipboardServer = 'localhost';
  static const int defaultRobotPort = 8888;
  
  // 超时设置
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  // 重连配置
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectDelay = Duration(seconds: 5);
  
  // 视频相关
  static const int defaultFrameRate = 30;
  static const int maxFrameRate = 60;
  static const int minFrameRate = 10;
  
  // 存储键
  static const String keyServerIp = 'server_ip';
  static const String keyServerPort = 'server_port';
  static const String keyDeviceCode = 'device_code';
  static const String keyAuthToken = 'auth_token';
  static const String keyRememberMe = 'remember_me';
  static const String keyThemeMode = 'theme_mode';
  static const String keyLanguage = 'language';
  
  // API端点
  static const String apiLogin = '/api/login';
  static const String apiDevices = '/api/devices';
  static const String apiRemoteOpen = '/api/remote/open';
  static const String apiRemoteClose = '/api/remote/close';
  static const String apiPasswordChange = '/api/password/change';
  static const String apiMouseEvent = '/api/events/mouse';
  static const String apiKeyboardEvent = '/api/events/keyboard';
  static const String apiClipboard = '/api/clipboard';
}
