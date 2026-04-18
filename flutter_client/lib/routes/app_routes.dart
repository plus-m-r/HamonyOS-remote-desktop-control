import 'package:get/get.dart';
import '../screens/login/login_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/remote_control/remote_control_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/device_list/device_list_screen.dart';
import '../screens/connection/connection_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';
  static const String remoteControl = '/remote-control';
  static const String settings = '/settings';
  static const String deviceList = '/device-list';
  static const String connection = '/connection';

  static final List<GetPage> pages = [
    GetPage(
      name: login,
      page: () => const LoginScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: home,
      page: () => const HomeScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: remoteControl,
      page: () => const RemoteControlScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: settings,
      page: () => const SettingsScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: deviceList,
      page: () => const DeviceListScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: connection,
      page: () => const ConnectionScreen(),
      transition: Transition.fadeIn,
    ),
  ];
}
