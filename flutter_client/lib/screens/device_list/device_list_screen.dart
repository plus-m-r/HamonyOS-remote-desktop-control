import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/device_list_controller.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart';

class DeviceListScreen extends StatelessWidget {
  const DeviceListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DeviceListController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('设备列表'),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (controller.filteredDevices.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.devices_other,
                  size: 64,
                  color: AppTheme.disabledColor,
                ),
                const SizedBox(height: AppTheme.spacingL),
                Text(
                  '没有找到设备',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // 搜索框
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: SearchBar(
                controller: controller.searchController,
                leading: const Icon(Icons.search),
                hintText: '搜索设备名称',
                onChanged: (value) => controller.filterDevices(value),
              ),
            ),

            // 设备列表
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
                itemCount: controller.filteredDevices.length,
                itemBuilder: (context, index) {
                  final device = controller.filteredDevices[index];
                  return _DeviceListTile(device: device);
                },
              ),
            ),
          ],
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => controller.addNewDevice(),
        icon: const Icon(Icons.add),
        label: const Text('添加新设备'),
      ),
    );
  }
}

class _DeviceListTile extends StatelessWidget {
  final RemoteDevice device;

  const _DeviceListTile({required this.device});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.devices,
        color: device.isOnline ? AppTheme.successColor : AppTheme.disabledColor,
      ),
      title: Text(device.deviceName),
      subtitle: Text(device.deviceModel),
      trailing: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingXs,
        ),
        decoration: BoxDecoration(
          color: device.isOnline
              ? AppTheme.successColor.withOpacity(0.1)
              : AppTheme.disabledColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: Text(
          device.isOnline ? '在线' : '离线',
          style: TextStyle(
            color: device.isOnline
                ? AppTheme.successColor
                : AppTheme.disabledColor,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
      onTap: () => Get.back(result: device),
    );
  }
}
