import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/settings_controller.dart';
import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SettingsController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        children: [
          // 应用设置
          _SettingsSection(
            title: '应用',
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('语言'),
                subtitle: const Text('中文'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  controller.changeLanguage();
                },
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.brightness_6),
                title: const Text('主题'),
                subtitle: const Text('跟随系统'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  controller.changeTheme();
                },
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),

          // 连接设置
          _SettingsSection(
            title: '连接',
            children: [
              ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('连接设置'),
                subtitle: const Text('配置服务器参数'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Get.toNamed(AppRoutes.connection),
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('连接历史'),
                subtitle: const Text('查看最近的连接'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  controller.viewConnectionHistory();
                },
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.delete_history),
                title: const Text('清除历史'),
                subtitle: const Text('删除所有连接记录'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  controller.clearHistory();
                },
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),

          // 关于应用
          _SettingsSection(
            title: '关于',
            children: [
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('应用版本'),
                subtitle: const Text('1.0.0'),
                trailing: const Icon(Icons.chevron_right),
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.help),
                title: const Text('帮助文档'),
                subtitle: const Text('查看使用说明'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  controller.openHelp();
                },
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.feedback),
                title: const Text('反馈意见'),
                subtitle: const Text('向我们提交您的建议'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  controller.sendFeedback();
                },
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),

          // 登出按钮
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              onPressed: () {
                controller.logout();
              },
              child: const Text('登出账户'),
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingM,
            vertical: AppTheme.spacingS,
          ),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
}
