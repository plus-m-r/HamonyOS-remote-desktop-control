import 'package:get/get.dart';
import 'package:logger/logger.dart';
import '../../routes/app_routes.dart';
import '../../services/connection_service.dart';

class SettingsController extends GetxController {
  final logger = Logger();
  
  final currentTheme = 'system'.obs;
  final currentLanguage = 'zh'.obs;

  void changeLanguage() {
    Get.dialog(
      AlertDialog(
        title: const Text('选择语言'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('简体中文'),
              onTap: () {
                currentLanguage.value = 'zh';
                Get.back();
                Get.snackbar('成功', '语言已更改为中文');
              },
            ),
            ListTile(
              title: const Text('English'),
              onTap: () {
                currentLanguage.value = 'en';
                Get.back();
                Get.snackbar('Success', 'Language changed to English');
              },
            ),
          ],
        ),
      ),
    );
  }

  void changeTheme() {
    Get.dialog(
      AlertDialog(
        title: const Text('选择主题'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('跟随系统'),
              onTap: () {
                currentTheme.value = 'system';
                Get.back();
                Get.snackbar('成功', '主题已更改');
              },
            ),
            ListTile(
              title: const Text('亮色主题'),
              onTap: () {
                currentTheme.value = 'light';
                Get.back();
                Get.snackbar('成功', '主题已更改为亮色');
              },
            ),
            ListTile(
              title: const Text('深色主题'),
              onTap: () {
                currentTheme.value = 'dark';
                Get.back();
                Get.snackbar('成功', '主题已更改为深色');
              },
            ),
          ],
        ),
      ),
    );
  }

  void viewConnectionHistory() {
    Get.dialog(
      AlertDialog(
        title: const Text('连接历史'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: const [
              ListTile(
                title: Text('Work Computer'),
                subtitle: Text('192.168.1.100:8080'),
                trailing: Text('2小时前'),
              ),
              ListTile(
                title: Text('Server'),
                subtitle: Text('192.168.1.50:8080'),
                trailing: Text('1天前'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void clearHistory() {
    Get.dialog(
      AlertDialog(
        title: const Text('清除历史'),
        content: const Text('确定要删除所有连接历史记录吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              // 清除历史
              Get.back();
              Get.snackbar('成功', '连接历史已清除');
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void openHelp() {
    Get.snackbar('帮助', '正在打开帮助文档...');
  }

  void sendFeedback() {
    Get.dialog(
      AlertDialog(
        title: const Text('反馈意见'),
        content: TextField(
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: '请输入您的反馈意见',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              Get.snackbar('谢谢', '感谢您的反馈！');
            },
            child: const Text('发送'),
          ),
        ],
      ),
    );
  }

  void logout() {
    Get.dialog(
      AlertDialog(
        title: const Text('确认登出'),
        content: const Text('确定要登出账户吗？'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              try {
                final connectionService = Get.find<ConnectionService>();
                connectionService.disconnect();
              } catch (e) {
                logger.e('断开连接失败: $e');
              }
              
              Get.back(); // 关闭对话框
              Get.offAllNamed(AppRoutes.login);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
