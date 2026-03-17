@echo off
echo Setting environment variables for Hvigor...
set GRADLE_OPTS=-Dorg.gradle.daemon.port=53000-53100
set HIGVOR_OPTS=-Dorg.gradle.daemon.port=53000-53100

echo Cleaning Hvigor cache...
rmdir /s /q .hvigor 2>nul

echo Starting build...
"C:\Program Files\Huawei\DevEco Studio\tools\node\node.exe" "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js" --mode module -p product=default assembleHap --analyze=normal --parallel --incremental --daemon

pause