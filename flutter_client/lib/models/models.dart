class ConnectionConfig {
  final String serverIp;
  final int serverPort;
  final String clipboardServer;
  final int robotPort;
  final String? deviceCode;
  final String? password;

  ConnectionConfig({
    required this.serverIp,
    required this.serverPort,
    this.clipboardServer = 'localhost',
    this.robotPort = 8888,
    this.deviceCode,
    this.password,
  });

  factory ConnectionConfig.fromJson(Map<String, dynamic> json) {
    return ConnectionConfig(
      serverIp: json['serverIp'] as String,
      serverPort: json['serverPort'] as int,
      clipboardServer: json['clipboardServer'] as String? ?? 'localhost',
      robotPort: json['robotPort'] as int? ?? 8888,
      deviceCode: json['deviceCode'] as String?,
      password: json['password'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serverIp': serverIp,
      'serverPort': serverPort,
      'clipboardServer': clipboardServer,
      'robotPort': robotPort,
      'deviceCode': deviceCode,
      'password': password,
    };
  }

  ConnectionConfig copyWith({
    String? serverIp,
    int? serverPort,
    String? clipboardServer,
    int? robotPort,
    String? deviceCode,
    String? password,
  }) {
    return ConnectionConfig(
      serverIp: serverIp ?? this.serverIp,
      serverPort: serverPort ?? this.serverPort,
      clipboardServer: clipboardServer ?? this.clipboardServer,
      robotPort: robotPort ?? this.robotPort,
      deviceCode: deviceCode ?? this.deviceCode,
      password: password ?? this.password,
    );
  }
}

class RemoteDevice {
  final String deviceId;
  final String deviceName;
  final String deviceModel;
  final String screenResolution;
  final bool isOnline;
  final DateTime? lastConnectedTime;

  RemoteDevice({
    required this.deviceId,
    required this.deviceName,
    required this.deviceModel,
    required this.screenResolution,
    this.isOnline = false,
    this.lastConnectedTime,
  });

  factory RemoteDevice.fromJson(Map<String, dynamic> json) {
    return RemoteDevice(
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String,
      deviceModel: json['deviceModel'] as String,
      screenResolution: json['screenResolution'] as String,
      isOnline: json['isOnline'] as bool? ?? false,
      lastConnectedTime: json['lastConnectedTime'] != null
          ? DateTime.parse(json['lastConnectedTime'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'deviceModel': deviceModel,
      'screenResolution': screenResolution,
      'isOnline': isOnline,
      'lastConnectedTime': lastConnectedTime?.toIso8601String(),
    };
  }
}

class FrameData {
  final int frameId;
  final int timestamp;
  final List<int> imageData;
  final String compressionType;
  final int width;
  final int height;

  FrameData({
    required this.frameId,
    required this.timestamp,
    required this.imageData,
    required this.compressionType,
    required this.width,
    required this.height,
  });

  /// 从Java RobotCaptureResponse协议创建
  /// 对应: common/remote/bean/RobotCaptureResponse.java
  factory FrameData.fromJavaResponse(
    Map<String, dynamic> json,
    int screenWidth,
    int screenHeight,
  ) {
    final screenBytes = json['screenBytes'] as List?;
    final imageBytes = screenBytes != null
        ? List<int>.from(screenBytes)
        : <int>[];

    return FrameData(
      frameId: (json['id'] ?? 0) as int,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      imageData: imageBytes,
      compressionType: json['compressionType'] as String? ?? 'binary',
      width: screenWidth,
      height: screenHeight,
    );
  }
}

class MouseEvent {
  final int x;
  final int y;
  final String button; // 'left', 'right', 'middle'
  final String action; // 'move', 'down', 'up', 'wheel'
  final int wheelDelta;

  // Java CmdMouseControl 协议常量
  static const int PRESSED = 1;
  static const int RELEASED = 1 << 1;
  static const int BUTTON1 = 1 << 2;    // 左键
  static const int BUTTON2 = 1 << 3;    // 中键
  static const int BUTTON3 = 1 << 4;    // 右键
  static const int WHEEL = 1 << 5;

  MouseEvent({
    required this.x,
    required this.y,
    this.button = 'left',
    this.action = 'move',
    this.wheelDelta = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'button': button,
      'action': action,
      'wheelDelta': wheelDelta,
    };
  }

  /// 转换为Java CmdMouseControl协议格式
  /// 用于与Java服务器通信
  Map<String, dynamic> toJavaProtocol() {
    int info = 0;

    // 按钮状态
    if (action == 'down') {
      info |= PRESSED;
    } else if (action == 'up') {
      info |= RELEASED;
    }

    // 按钮类型
    if (button == 'left') {
      info |= BUTTON1;
    } else if (button == 'middle') {
      info |= BUTTON2;
    } else if (button == 'right') {
      info |= BUTTON3;
    }

    // 滚轮操作
    if (action == 'wheel') {
      info |= WHEEL;
    }

    return {
      'x': x,
      'y': y,
      'info': info,
      'rotations': wheelDelta,
    };
  }
}

class KeyboardEvent {
  final int keyCode;
  final String action; // 'down', 'up'
  final bool ctrlPressed;
  final bool altPressed;
  final bool shiftPressed;

  // Java CmdKeyControl 协议常量
  static const int PRESSED = 1;
  static const int RELEASED = 1 << 1;

  KeyboardEvent({
    required this.keyCode,
    this.action = 'down',
    this.ctrlPressed = false,
    this.altPressed = false,
    this.shiftPressed = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'keyCode': keyCode,
      'action': action,
      'ctrlPressed': ctrlPressed,
      'altPressed': altPressed,
      'shiftPressed': shiftPressed,
    };
  }

  /// 转换为Java CmdKeyControl协议格式
  /// 用于与Java服务器通信
  Map<String, dynamic> toJavaProtocol() {
    int info = 0;

    // 按键状态
    if (action == 'down') {
      info |= PRESSED;
    } else if (action == 'up') {
      info |= RELEASED;
    }

    return {
      'info': info,
      'keyCode': keyCode,
      'keyChar': '', // 由服务器处理
    };
  }
}

class ConnectionStatus {
  final bool isConnected;
  final String? errorMessage;
  final int? reconnectAttempts;
  final DateTime? lastConnectionTime;

  const ConnectionStatus({
    this.isConnected = false,
    this.errorMessage,
    this.reconnectAttempts = 0,
    this.lastConnectionTime,
  });

  ConnectionStatus copyWith({
    bool? isConnected,
    String? errorMessage,
    int? reconnectAttempts,
    DateTime? lastConnectionTime,
  }) {
    return ConnectionStatus(
      isConnected: isConnected ?? this.isConnected,
      errorMessage: errorMessage ?? this.errorMessage,
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
      lastConnectionTime: lastConnectionTime ?? this.lastConnectionTime,
    );
  }
}
