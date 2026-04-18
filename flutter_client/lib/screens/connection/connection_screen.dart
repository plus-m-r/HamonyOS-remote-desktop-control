import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../theme/app_theme.dart';

class ConnectionScreen extends StatelessWidget {
  const ConnectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('连接设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        children: [
          // 服务器配置部分
          _Section(
            title: '服务器配置',
            children: [
              _SettingsTile(
                title: '服务器地址',
                subtitle: 'localhost',
                icon: Icons.server,
              ),
              _SettingsTile(
                title: '服务器端口',
                subtitle: '8080',
                icon: Icons.settings_input_antenna,
              ),
              _SettingsTile(
                title: '连接超时',
                subtitle: '30秒',
                icon: Icons.schedule,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),

          // 视频设置部分
          _Section(
            title: '视频设置',
            children: [
              _SettingsTile(
                title: '视频质量',
                subtitle: '高质量',
                icon: Icons.videocam,
              ),
              _SettingsTile(
                title: '帧率',
                subtitle: '30 fps',
                icon: Icons.animation,
              ),
              _SettingsTile(
                title: '压缩方式',
                subtitle: 'ZSTD',
                icon: Icons.compress,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),

          // 高级设置部分
          _Section(
            title: '高级设置',
            children: [
              _SwitchTile(
                title: '自动重连',
                subtitle: '连接断开时自动重新连接',
                value: true,
              ),
              _SwitchTile(
                title: '保存连接历史',
                subtitle: '记住最近使用的连接',
                value: true,
              ),
              _SwitchTile(
                title: '启用日志',
                subtitle: '记录详细的连接日志',
                value: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({
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
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        // 编辑设置
      },
    );
  }
}

class _SwitchTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool value;

  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
  });

  @override
  State<_SwitchTile> createState() => _SwitchTileState();
}

class _SwitchTileState extends State<_SwitchTile> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.title),
      subtitle: Text(widget.subtitle),
      trailing: Switch(
        value: _value,
        onChanged: (value) {
          setState(() {
            _value = value;
          });
        },
      ),
    );
  }
}
