import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../models/models.dart';

class ApiService {
  late final Dio _dio;
  final logger = Logger();

  ApiService(String baseUrl) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        contentType: 'application/json',
      ),
    );

    _dio.interceptors.add(LoggingInterceptor(logger));
  }

  // 登录
  Future<Map<String, dynamic>> login(String deviceCode, String password) async {
    try {
      final response = await _dio.post(
        '/api/login',
        data: {
          'deviceCode': deviceCode,
          'password': password,
        },
      );
      return response.data;
    } catch (e) {
      logger.e('登录失败: $e');
      rethrow;
    }
  }

  // 获取设备列表
  Future<List<RemoteDevice>> getDeviceList() async {
    try {
      final response = await _dio.get('/api/devices');
      final devices = (response.data as List)
          .map((device) => RemoteDevice.fromJson(device as Map<String, dynamic>))
          .toList();
      return devices;
    } catch (e) {
      logger.e('获取设备列表失败: $e');
      rethrow;
    }
  }

  // 打开远程屏幕
  Future<Map<String, dynamic>> openRemoteScreen(
    String deviceCode,
    String password,
  ) async {
    try {
      final response = await _dio.post(
        '/api/remote/open',
        data: {
          'deviceCode': deviceCode,
          'password': password,
        },
      );
      return response.data;
    } catch (e) {
      logger.e('打开远程屏幕失败: $e');
      rethrow;
    }
  }

  // 关闭远程屏幕
  Future<void> closeRemoteScreen(String deviceCode) async {
    try {
      await _dio.post(
        '/api/remote/close',
        data: {
          'deviceCode': deviceCode,
        },
      );
    } catch (e) {
      logger.e('关闭远程屏幕失败: $e');
      rethrow;
    }
  }

  // 修改密码
  Future<void> changePassword(String deviceCode, String newPassword) async {
    try {
      await _dio.post(
        '/api/password/change',
        data: {
          'deviceCode': deviceCode,
          'newPassword': newPassword,
        },
      );
    } catch (e) {
      logger.e('修改密码失败: $e');
      rethrow;
    }
  }
}

class LoggingInterceptor extends Interceptor {
  final Logger logger;

  LoggingInterceptor(this.logger);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    logger.i('请求: ${options.method} ${options.path}');
    logger.d('请求数据: ${options.data}');
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    logger.i('响应: ${response.statusCode} ${response.requestOptions.path}');
    logger.d('响应数据: ${response.data}');
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    logger.e('错误: ${err.message}');
    logger.d('错误详情: ${err.response?.data}');
    super.onError(err, handler);
  }
}
