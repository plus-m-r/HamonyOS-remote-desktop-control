import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/connection_service.dart';
import '../../routes/app_routes.dart';

class HomeController extends GetxController {
  final logger = Logger();
  
  final devices = <RemoteDevice>[].obs;
  final isLoading = false.obs;
  
  late ApiService apiService;
  late ConnectionService connectionService;

  @override
  void onInit() {
    super.onInit();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      connectionService = Get.find<ConnectionService>();
      
      // 从SharedPreferences获取之前保存的配置
      final prefs = await SharedPreferences.getInstance();
      final serverIp = prefs.getString('server_ip') ?? 'localhost';
      final serverPort = prefs.getInt('server_port') ?? 8080;
      
      final baseUrl = 'http://$serverIp:$serverPort';
      apiService = ApiService(baseUrl);
      
      await loadDevices();
    } catch (e) {
      logger.e('初始化失败: $e');
    }
  }

  Future<void> loadDevices() async {
    try {
      isLoading.value = true;
      
      // 模拟加载设备
      await Future.delayed(const Duration(milliseconds: 500));
      
      devices.addAll([
        RemoteDevice(
          deviceId: 'device_001',
          deviceName: 'Work Computer',
          deviceModel: 'Windows 10',
          screenResolution: '1920x1080',
          isOnline: true,
          lastConnectedTime: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        RemoteDevice(
          deviceId: 'device_002',
          deviceName: 'Laptop',
          deviceModel: 'MacOS Monterey',
          screenResolution: '2560x1600',
          isOnline: false,
          lastConnectedTime: DateTime.now().subtract(const Duration(days: 1)),
        ),
        RemoteDevice(
          deviceId: 'device_003',
          deviceName: 'Server',
          deviceModel: 'Ubuntu 20.04',
          screenResolution: '1024x768',
          isOnline: true,
          lastConnectedTime: DateTime.now(),
        ),
      ]);
      
      isLoading.value = false;
    } catch (e) {
      logger.e('加载设备失败: $e');
      isLoading.value = false;
    }
  }

  Future<void> refreshDevices() async {
    await loadDevices();
  }

  Future<void> connectToDevice(RemoteDevice device) async {
    try {
      // 导航到连接屏幕
      Get.toNamed(
        AppRoutes.remoteControl,
        arguments: {'device': device},
      );
    } catch (e) {
      logger.e('连接设备失败: $e');
      Get.snackbar(
        '错误',
        '连接失败: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void logout() {
    Get.dialog(
      AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出登录吗?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              connectionService.disconnect();
              Get.back();
              Get.offAllNamed(AppRoutes.login);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}
