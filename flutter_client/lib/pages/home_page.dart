import 'package:flutter/material.dart';

import 'connect_page.dart';
import 'settings_page.dart';
import 'tools_page.dart';

/// 主框架：左侧导航（连接/设置/工具），右侧显示对应页面。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = [
    ConnectPage(),
    SettingsPage(),
    ToolsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildSideNav(),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }

  Widget _buildSideNav() {
    return Container(
      width: 96,
      color: const Color(0xFFF2F6FF),
      child: Column(
        children: [
          const SizedBox(height: 40),
          _navItem(0, Icons.link, '连接'),
          _navItem(1, Icons.settings, '设置'),
          _navItem(2, Icons.build, '工具'),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final selected = _selectedIndex == index;
    final color = selected ? const Color(0xFF1E5EFF) : const Color(0xFF6B7280);
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1E5EFF).withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
