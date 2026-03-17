@echo off
echo ============================================
echo HarmonyOS客户端配置快速修复工具
echo ============================================
echo.

echo 请选择要使用的服务器配置：
echo.
echo [1] 使用原始服务端IP (10.11.108.247)
echo [2] 使用localhost (127.0.0.1)
echo [3] 使用模拟器特殊地址 (10.0.2.2)
echo [4] 手动输入IP地址
echo [5] 查看当前配置
echo [6] 测试网络连接
echo [7] 退出
echo.

set /p choice="请选择 (1-7): "

if "%choice%"=="1" goto option1
if "%choice%"=="2" goto option2
if "%choice%"=="3" goto option3
if "%choice%"=="4" goto option4
if "%choice%"=="5" goto option5
if "%choice%"=="6" goto option6
if "%choice%"=="7" goto exit
echo 无效的选择
goto :eof

:option1
echo 正在配置为原始服务端IP: 10.11.108.247
powershell -Command "(Get-Content 'entry\src\main\ets\config\config.ets') -replace \"host: '.*'\", \"host: '10.11.108.247'\" | Set-Content 'entry\src\main\ets\config\config.ets'"
echo 配置已更新为: 10.11.108.247
goto rebuild

:option2
echo 正在配置为localhost: 127.0.0.1
powershell -Command "(Get-Content 'entry\src\main\ets\config\config.ets') -replace \"host: '.*'\", \"host: '127.0.0.1'\" | Set-Content 'entry\src\main\ets\config\config.ets'"
echo 配置已更新为: 127.0.0.1
goto rebuild

:option3
echo 正在配置为模拟器特殊地址: 10.0.2.2
powershell -Command "(Get-Content 'entry\src\main\ets\config\config.ets') -replace \"host: '.*'\", \"host: '10.0.2.2'\" | Set-Content 'entry\src\main\ets\config\config.ets'"
echo 配置已更新为: 10.0.2.2
goto rebuild

:option4
set /p custom_ip="请输入IP地址: "
echo 正在配置为: %custom_ip%
powershell -Command "(Get-Content 'entry\src\main\ets\config\config.ets') -replace \"host: '.*'\", \"host: '%custom_ip%'\" | Set-Content 'entry\src\main\ets\config\config.ets'"
echo 配置已更新为: %custom_ip%
goto rebuild

:option5
echo 当前配置文件内容:
echo.
type "entry\src\main\ets\config\config.ets"
echo.
pause
goto :eof

:option6
echo 正在测试网络连接...
call network_test.bat
pause
goto :eof

:rebuild
echo.
echo 正在重新编译项目...
call build_with_env.bat
if %errorlevel% neq 0 (
    echo 编译失败，请检查错误信息
    pause
    exit /b 1
)
echo 编译成功！
echo.
echo 配置已更新，请重新运行应用测试连接。
pause
goto :eof

:exit
echo 退出配置工具
exit /b 0