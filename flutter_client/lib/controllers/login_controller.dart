import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/connection_service.dart';
import '../../services/connection_service_enhanced.dart';
import '../../routes/app_routes.dart';

class LoginController extends GetxController {
  final logger = Logger();
  
  final deviceCodeController = TextEditingController();
  final serverIpController = TextEditingController();
  final serverPortController = TextEditingController();
  final passwordController = TextEditingController();
  
  final showPassword = false.obs;
  final isLoading = false.obs;
  final errorMessage = RxString('');

  late SharedPreferences prefs;
  late ApiService apiService;

  @override
  void onInit() {
    super.onInit();
    _initializeControllers();
  }

  Future<void> _initializeControllers() async {
    try {
      prefs = await SharedPreferences.getInstance();
      _loadSavedCredentials();
    } catch (e) {
      logger.e('初始化失败: $e');
    }
  }

  void _loadSavedCredentials() {
    final savedIp = prefs.getString('server_ip');
    final savedPort = prefs.getString('server_port');
    final savedDeviceCode = prefs.getString('device_code');
    final rememberMe = prefs.getBool('remember_me') ?? false;

    if (rememberMe && savedIp != null) {
      serverIpController.text = savedIp;
      serverPortController.text = savedPort ?? '8080';
      deviceCodeController.text = savedDeviceCode ?? '';
    } else {
      serverIpController.text = 'localhost';
      serverPortController.text = '8080';
    }
  }

  void togglePasswordVisibility() {
    showPassword.value = !showPassword.value;
  }

  Future<void> login() async {
    try {
      if (!_validateInputs()) {
        return;
      }

      isLoading.value = true;
      errorMessage.value = '';

      final deviceCode = deviceCodeController.text.trim();
      final serverIp = serverIpController.text.trim();
      final serverPort = int.parse(serverPortController.text.trim());
      final password = passwordController.text;

      // 初始化API服务
      final baseUrl = 'http://$serverIp:$serverPort';
      apiService = ApiService(baseUrl);

      // 发起登录请求
      final result = await apiService.login(deviceCode, password);

      if (result['code'] == 0 || result['success'] == true) {
        // 保存连接配置
        await prefs.setString('server_ip', serverIp);
        await prefs.setString('server_port', serverPort.toString());
        await prefs.setString('device_code', deviceCode);
        await prefs.setString('auth_token', result['token'] ?? '');

        // 初始化连接服务
        // 使用增强版WebSocket服务用于实时屏幕传输
        final connectionService = Get.put(ConnectionServiceEnhanced());
        final config = ConnectionConfig(
          serverIp: serverIp,
          serverPort: serverPort,
          robotPort: serverPort + 808,  // 默认WebSocket端口为REST端口 + 808
          deviceCode: deviceCode,
          password: password,
        );

        final connected = await connectionService.initializeConnection(config);

        if (connected) {
          isLoading.value = false;
          Get.offAllNamed(AppRoutes.home);
        } else {
          isLoading.value = false;
          errorMessage.value = '连接失败，请检查服务器地址和端口';
        }
      } else {
        isLoading.value = false;
        errorMessage.value = result['message'] ?? '登录失败，请检查凭证';
      }
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = _getErrorMessage(e);
      logger.e('登录失败: $e');
    }
  }

  bool _validateInputs() {
    if (deviceCodeController.text.isEmpty) {
      errorMessage.value = '请输入设备代码';
      return false;
    }

    if (serverIpController.text.isEmpty) {
      errorMessage.value = '请输入服务器地址';
      return false;
    }

    if (serverPortController.text.isEmpty) {
      errorMessage.value = '请输入服务器端口';
      return false;
    }

    if (passwordController.text.isEmpty) {
      errorMessage.value = '请输入密码';
      return false;
    }

    try {
      int.parse(serverPortController.text);
    } catch (e) {
      errorMessage.value = '服务器端口必须是数字';
      return false;
    }

    return true;
  }

  String _getErrorMessage(dynamic error) {
    if (error is SocketException) {
      return '网络连接失败，请检查网络和服务器地址';
    } else if (error.toString().contains('TimeoutException')) {
      return '连接超时，请检查服务器是否在线';
    } else if (error.toString().contains('ConnectionRefused')) {
      return '连接被拒绝，请检查服务器端口';
    }
    return error.toString();
  }

  @override
  void onClose() {
    deviceCodeController.dispose();
    serverIpController.dispose();
    serverPortController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}

class SocketException implements Exception {
  final String message;
  SocketException(this.message);

  @override
  String toString() => message;
}
