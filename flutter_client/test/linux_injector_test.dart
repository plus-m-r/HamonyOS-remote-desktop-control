// Linux 输入注入纯逻辑测试：AWT VK → X11 keysym 映射（不依赖 X 服务器）。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_client/platform/linux_injector.dart';

void main() {
  group('awtVkToKeysym 可打印字符直通', () {
    test('字母 A-Z 直接等于 keysym', () {
      for (var c = 0x41; c <= 0x5A; c++) {
        expect(awtVkToKeysym(c), c); // 'A'==0x41 == XK_A
      }
    });

    test('数字 0-9 直接等于 keysym', () {
      for (var c = 0x30; c <= 0x39; c++) {
        expect(awtVkToKeysym(c), c);
      }
    });

    test('标点/空格直通', () {
      expect(awtVkToKeysym(0x20), 0x20); // 空格
      expect(awtVkToKeysym(0x2E), 0x2E); // '.'
      expect(awtVkToKeysym(0x3B), 0x3B); // ';'
    });
  });

  group('awtVkToKeysym 功能键映射', () {
    test('回车/退格/Tab/Esc', () {
      expect(awtVkToKeysym(0x0D), 0xFF0D); // VK_ENTER → XK_Return
      expect(awtVkToKeysym(0x08), 0xFF08); // VK_BACK_SPACE → XK_BackSpace
      expect(awtVkToKeysym(0x09), 0xFF09); // VK_TAB → XK_Tab
      expect(awtVkToKeysym(0x1B), 0xFF1B); // VK_ESCAPE → XK_Escape
    });

    test('方向键/编辑键', () {
      expect(awtVkToKeysym(0x25), 0xFF51); // ←
      expect(awtVkToKeysym(0x26), 0xFF52); // ↑
      expect(awtVkToKeysym(0x27), 0xFF53); // →
      expect(awtVkToKeysym(0x28), 0xFF54); // ↓
      expect(awtVkToKeysym(0x24), 0xFF50); // Home
      expect(awtVkToKeysym(0x23), 0xFF57); // End
      expect(awtVkToKeysym(0x21), 0xFF55); // PageUp
      expect(awtVkToKeysym(0x22), 0xFF56); // PageDown
    });

    test('修饰键', () {
      expect(awtVkToKeysym(0x10), 0xFFE1); // Shift
      expect(awtVkToKeysym(0x11), 0xFFE3); // Control
      expect(awtVkToKeysym(0x12), 0xFFE9); // Alt
      expect(awtVkToKeysym(0x01D8), 0xFFEB); // Meta（mac）
      expect(awtVkToKeysym(0x020C), 0xFFEB); // Windows
    });

    test('无法映射的键返回 0', () {
      expect(awtVkToKeysym(0), 0); // VK_UNDEFINED
      expect(awtVkToKeysym(0x02), 0); // 未定义
    });
  });

  group('awtFunctionKeyToKeysym F1-F12', () {
    test('F1=VK112 → keysym F1', () {
      expect(awtFunctionKeyToKeysym(112), 0xFFBE);
    });
    test('F12=VK123 → keysym F12', () {
      expect(awtFunctionKeyToKeysym(123), 0xFFBE + 11);
    });
    test('非功能键返回 0', () {
      expect(awtFunctionKeyToKeysym(500), 0);
    });
  });

  group('组合映射：普通键进 awtVkToKeysym，功能键走 awtFunctionKeyToKeysym', () {
    test('F5 通过商标函数取到', () {
      expect(awtFunctionKeyToKeysym(116), 0xFFBE + 4); // VK_F5=116
    });
  });
}