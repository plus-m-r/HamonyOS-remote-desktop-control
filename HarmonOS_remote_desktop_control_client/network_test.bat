@echo off
echo ============================================
echo HarmonyOS远程桌面控制 - 网络连通性测试
echo ============================================
echo.

echo [1] 测试服务端HTTP端口 (12345)...
echo 正在测试 HTTP://10.11.108.247:12345/remote-desktop-control
powershell -Command "try { $response = Invoke-WebRequest -Uri 'http://10.11.108.247:12345/remote-desktop-control' -Method GET -TimeoutSec 5; echo 'HTTP连接成功! 状态码:' $response.StatusCode } catch { echo 'HTTP连接失败: ' $_.Exception.Message }"
echo.

echo [2] 测试服务端TCP端口 (54321)...
echo 正在测试 TCP://10.11.108.247:54321
powershell -Command "try { $tcpClient = New-Object System.Net.Sockets.TcpClient; $result = $tcpClient.BeginConnect('10.11.108.247', 54321, $null, $null); $success = $result.AsyncWaitHandle.WaitOne(5000, $false); if ($success) { echo 'TCP连接成功!'; $tcpClient.EndConnect($result); $tcpClient.Close() } else { echo 'TCP连接超时' } } catch { echo 'TCP连接失败: ' $_.Exception.Message }"
echo.

echo [3] 检查本地网络配置...
echo 本地IP地址:
ipconfig | findstr IPv4
echo.

echo [4] 检查到服务端的网络路由...
echo 路由跟踪到 10.11.108.247:
tracert -d -h 5 10.11.108.247
echo.

echo [5] 检查防火墙状态...
echo Windows Defender防火墙状态:
netsh advfirewall show allprofiles state
echo.

echo [6] 检查端口监听状态...
echo 检查本地端口占用:
netstat -an | findstr ":12345"
netstat -an | findstr ":54321"
echo.

echo ============================================
echo 测试完成！
echo ============================================
echo.
echo 如果测试失败，请检查：
echo 1. 服务端是否正在运行
echo 2. 防火墙是否允许端口12345和54321
echo 3. 网络是否可达10.11.108.247
echo 4. 服务端IP地址是否正确
echo.
pause