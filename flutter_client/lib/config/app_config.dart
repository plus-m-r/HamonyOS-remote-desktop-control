/// 环境配置文件
/// 
/// 本文件定义了应用在不同环境下的配置。
/// 根据需要选择合适的配置。

class Environment {
  static const String dev = 'development';
  static const String staging = 'staging';
  static const String production = 'production';
}

class AppConfig {
  // 当前环境 - 在构建时可以通过参数改变
  static const String currentEnvironment = Environment.dev;

  // API配置
  static const Map<String, String> apiBaseUrl = {
    Environment.dev: 'http://localhost:8080',
    Environment.staging: 'http://staging-api.example.com',
    Environment.production: 'https://api.example.com',
  };

  // 服务器配置
  static const Map<String, ServerConfig> serverConfig = {
    Environment.dev: ServerConfig(
      serverIp: 'localhost',
      serverPort: 8080,
      clipboardServer: 'localhost',
      robotPort: 8888,
      connectionTimeout: 30,
      reconnectAttempts: 5,
      reconnectDelay: 5,
    ),
    Environment.staging: ServerConfig(
      serverIp: 'staging.example.com',
      serverPort: 8080,
      clipboardServer: 'staging.example.com',
      robotPort: 8888,
      connectionTimeout: 30,
      reconnectAttempts: 5,
      reconnectDelay: 5,
    ),
    Environment.production: ServerConfig(
      serverIp: 'api.example.com',
      serverPort: 443,
      clipboardServer: 'api.example.com',
      robotPort: 443,
      connectionTimeout: 60,
      reconnectAttempts: 10,
      reconnectDelay: 10,
    ),
  };

  // 日志配置
  static const Map<String, bool> debugSettings = {
    Environment.dev: true,
    Environment.staging: true,
    Environment.production: false,
  };

  // 功能标志（Feature Flags）
  static const Map<String, FeatureFlags> featureFlags = {
    Environment.dev: FeatureFlags(
      enableClipboardSync: true,
      enableFileTransfer: false,
      enableAudioSync: false,
      enableAdvancedSettings: true,
      enableBetaFeatures: true,
    ),
    Environment.staging: FeatureFlags(
      enableClipboardSync: true,
      enableFileTransfer: true,
      enableAudioSync: false,
      enableAdvancedSettings: true,
      enableBetaFeatures: false,
    ),
    Environment.production: FeatureFlags(
      enableClipboardSync: true,
      enableFileTransfer: true,
      enableAudioSync: false,
      enableAdvancedSettings: false,
      enableBetaFeatures: false,
    ),
  };

  // 获取当前环境的API基地址
  static String get apiUrl => apiBaseUrl[currentEnvironment] ?? apiBaseUrl[Environment.dev]!;

  // 获取当前环境的服务器配置
  static ServerConfig get serverSettings =>
      serverConfig[currentEnvironment] ?? serverConfig[Environment.dev]!;

  // 获取当前环境的调试设置
  static bool get isDebugMode => debugSettings[currentEnvironment] ?? false;

  // 获取当前环境的功能标志
  static FeatureFlags get features =>
      featureFlags[currentEnvironment] ?? featureFlags[Environment.dev]!;

  // 是否生产环境
  static bool get isProduction => currentEnvironment == Environment.production;

  // 是否开发环境
  static bool get isDevelopment => currentEnvironment == Environment.dev;

  // 是否预发布环境
  static bool get isStaging => currentEnvironment == Environment.staging;
}

/// 服务器配置类
class ServerConfig {
  final String serverIp;
  final int serverPort;
  final String clipboardServer;
  final int robotPort;
  final int connectionTimeout;
  final int reconnectAttempts;
  final int reconnectDelay;

  const ServerConfig({
    required this.serverIp,
    required this.serverPort,
    required this.clipboardServer,
    required this.robotPort,
    required this.connectionTimeout,
    required this.reconnectAttempts,
    required this.reconnectDelay,
  });

  String get baseUrl => 'http://$serverIp:$serverPort';

  @override
  String toString() => 'ServerConfig('
      'serverIp: $serverIp, '
      'serverPort: $serverPort, '
      'clipboardServer: $clipboardServer, '
      'robotPort: $robotPort'
      ')';
}

/// 功能标志（Feature Flags）
class FeatureFlags {
  final bool enableClipboardSync;
  final bool enableFileTransfer;
  final bool enableAudioSync;
  final bool enableAdvancedSettings;
  final bool enableBetaFeatures;

  const FeatureFlags({
    required this.enableClipboardSync,
    required this.enableFileTransfer,
    required this.enableAudioSync,
    required this.enableAdvancedSettings,
    required this.enableBetaFeatures,
  });

  @override
  String toString() => 'FeatureFlags('
      'clipboard: $enableClipboardSync, '
      'fileTransfer: $enableFileTransfer, '
      'audioSync: $enableAudioSync, '
      'advancedSettings: $enableAdvancedSettings, '
      'betaFeatures: $enableBetaFeatures'
      ')';
}
