import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/login_controller.dart';
import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(LoginController());

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                  
                  // 应用标题
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.accentColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.desktop_mac,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingL),

                  // 标题文本
                  Text(
                    'HarmonyOS',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryColor,
                        ),
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    '远程桌面控制',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                  ),
                  const SizedBox(height: AppTheme.spacingXl),

                  // 设备代码输入框
                  TextField(
                    controller: controller.deviceCodeController,
                    decoration: InputDecoration(
                      labelText: '设备代码',
                      prefixIcon: const Icon(Icons.devices),
                      hintText: '请输入设备代码',
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),

                  // 服务器地址输入框
                  TextField(
                    controller: controller.serverIpController,
                    decoration: InputDecoration(
                      labelText: '服务器地址',
                      prefixIcon: const Icon(Icons.server),
                      hintText: '例如: 192.168.1.100',
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),

                  // 服务器端口输入框
                  TextField(
                    controller: controller.serverPortController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '服务器端口',
                      prefixIcon: const Icon(Icons.settings_input_antenna),
                      hintText: '例如: 8080',
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),

                  // 密码输入框
                  Obx(() => TextField(
                    controller: controller.passwordController,
                    obscureText: !controller.showPassword.value,
                    decoration: InputDecoration(
                      labelText: '密码',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          controller.showPassword.value
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          controller.togglePasswordVisibility();
                        },
                      ),
                      hintText: '请输入密码',
                    ),
                  )),
                  const SizedBox(height: AppTheme.spacingXl),

                  // 登录按钮
                  Obx(() => SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: controller.isLoading.value
                          ? null
                          : () => controller.login(),
                      child: controller.isLoading.value
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('连接并登录'),
                    ),
                  )),

                  // 错误消息显示
                  Obx(() {
                    if (controller.errorMessage.value.isNotEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: AppTheme.spacingM),
                        child: Container(
                          padding: const EdgeInsets.all(AppTheme.spacingM),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withOpacity(0.1),
                            border: Border.all(color: AppTheme.errorColor),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusM),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppTheme.errorColor,
                              ),
                              const SizedBox(width: AppTheme.spacingM),
                              Expanded(
                                child: Text(
                                  controller.errorMessage.value,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppTheme.errorColor,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),

                  const SizedBox(height: AppTheme.spacingXl),

                  // 底部链接
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '没有账户？',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () {
                          // 注册功能
                        },
                        child: const Text('立即注册'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
