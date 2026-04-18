import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';

class DeviceListController extends GetxController {
  final logger = Logger();
  
  final devices = <RemoteDevice>[].obs;
  final filteredDevices = <RemoteDevice>[].obs;
  final isLoading = false.obs;
  final searchController = TextEditingController();
  
  late ApiService apiService;

  @override
  void onInit() {
    super.onInit();
    _initialize();
  }

  Future<void> _initialize() async {
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
        ),
        RemoteDevice(
          deviceId: 'device_002',
          deviceName: 'Laptop',
          deviceModel: 'MacOS Monterey',
          screenResolution: '2560x1600',
          isOnline: false,
        ),
        RemoteDevice(
          deviceId: 'device_003',
          deviceName: 'Server',
          deviceModel: 'Ubuntu 20.04',
          screenResolution: '1024x768',
          isOnline: true,
        ),
        RemoteDevice(
          deviceId: 'device_004',
          deviceName: 'Test Device',
          deviceModel: 'Windows 11',
          screenResolution: '2560x1440',
          isOnline: true,
        ),
      ]);
      
      filteredDevices.assignAll(devices);
      isLoading.value = false;
    } catch (e) {
      logger.e('加载设备失败: $e');
      isLoading.value = false;
    }
  }

  void filterDevices(String query) {
    if (query.isEmpty) {
      filteredDevices.assignAll(devices);
    } else {
      final filtered = devices
          .where((device) =>
              device.deviceName.toLowerCase().contains(query.toLowerCase()) ||
              device.deviceModel.toLowerCase().contains(query.toLowerCase()))
          .toList();
      filteredDevices.assignAll(filtered);
    }
  }

  void addNewDevice() {
    Get.dialog(
      AlertDialog(
        title: const Text('添加新设备'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: '设备名称',
                hintText: '例如: My Computer',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: '设备代码',
                hintText: '例如: DEVICE123',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              // 添加设备逻辑
              Get.back();
              Get.snackbar('成功', '设备添加成功');
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }
}
