@echo off
chcp 65001 >nul
title 一翻云 程序级优化工具 v1.1
cd /d "%~dp0"

:menu
cls
echo.
echo  ================================================================
echo              一翻云 (onefcloud) 程序级优化工具
echo          修复 P0/P1 缺陷 - 安全加固 - 低延迟调优 - 稳定守护
echo  ================================================================
echo.
echo   [1] 一键生成 修复+优化 订阅配置  (需订阅 token)
echo   [2] 启动 本地订阅修复代理        (App 订阅地址换成 127.0.0.1:8787/sub)
echo   [3] 用内置内核直接运行优化配置   (系统代理模式, 含看门狗自愈)
echo   [4] 用内置内核 TUN 全局模式      (需管理员, 自动提权)
echo   [5] 系统级全套优化 quick-start   (管理员: TCP/网络/安全/巡检)
echo   [0] 退出
echo.
set /p choice=请选择: 

if "%choice%"=="1" goto opt1
if "%choice%"=="2" goto opt2
if "%choice%"=="3" goto opt3
if "%choice%"=="4" goto opt4
if "%choice%"=="5" goto opt5
if "%choice%"=="0" exit /b 0
goto menu

:opt1
set "MUXARGS="
set /p token=输入订阅 token (面板-我的订阅链接里 token= 后面的串): 
set /p muxflag=启用多路复用 smux? 可降低握手延迟 [y/N]: 
set /p pinflag=固化节点域名解析(抗私有DNS单点)? [Y/n]: 
if /i "%muxflag%"=="y" set "MUXARGS=%MUXARGS% -EnableMux"
if /i not "%pinflag%"=="n" set "MUXARGS=%MUXARGS% -PinDns"
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\profile-optimizer.ps1" -Token "%token%"%MUXARGS%
echo.
pause
goto menu

:opt2
set /p token=输入订阅 token: 
echo 启动后把 App 内订阅地址改为  http://127.0.0.1:8787/sub
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\subscription-optimizer-server.ps1" -Token "%token%"
pause
goto menu

:opt3
set "TOKARG="
if exist "runtime\optimized-profile.yaml" goto run3
set /p token=尚未生成优化配置, 输入订阅 token 自动生成: 
set "TOKARG=-Token "%token%""
:run3
if not defined TOKARG echo 使用现有配置 runtime\optimized-profile.yaml ^(重新生成请选 [1]^)
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\run-optimized-core.ps1" %TOKARG%
pause
goto menu

:opt4
set "TOKARG="
if exist "runtime\optimized-profile.yaml" goto run4
set /p token=尚未生成优化配置, 输入订阅 token 自动生成: 
set "TOKARG=-Token "%token%""
:run4
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\run-optimized-core.ps1" -Tun %TOKARG%
pause
goto menu

:opt5
powershell -NoProfile -ExecutionPolicy Bypass -File "quick-start.ps1"
pause
goto menu
