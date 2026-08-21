#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows 系统级优化脚本 - 为 onefcloud 提供极致性能
.DESCRIPTION
    优化 Windows 网络栈、内存管理、CPU 调度等系统参数
.NOTES
    需要管理员权限运行
    作者: onefcloud Optimization Team
    版本: 1.0.0
#>

[CmdletBinding()]
param(
    [switch]$SkipReboot,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# 颜色输出函数
function Write-ColorOutput {
    param(
        [string]$Message,
        [ValidateSet("Success", "Warning", "Error", "Info")]
        [string]$Type = "Info"
    )
    
    $colors = @{
        "Success" = "Green"
        "Warning" = "Yellow"
        "Error"   = "Red"
        "Info"    = "Cyan"
    }
    
    $prefix = switch ($Type) {
        "Success" { "[✓]" }
        "Warning" { "[!]" }
        "Error"   { "[✗]" }
        "Info"    { "[i]" }
    }
    
    Write-Host "$prefix $Message" -ForegroundColor $colors[$Type]
}

# 检查管理员权限
function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-ColorOutput "请以管理员权限运行此脚本！" -Type Error
    exit 1
}

Write-ColorOutput "开始 Windows 系统优化..." -Type Info
Write-ColorOutput "优化时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Type Info

# 创建系统还原点
function New-RestorePoint {
    Write-ColorOutput "创建系统还原点..." -Type Info
    try {
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "onefcloud 优化前还原点" -RestorePointType "MODIFY_SETTINGS"
        Write-ColorOutput "系统还原点创建成功" -Type Success
    }
    catch {
        Write-ColorOutput "创建还原点失败: $_" -Type Warning
    }
}

# 优化网络栈
function Optimize-NetworkStack {
    Write-ColorOutput "优化网络栈参数..." -Type Info
    
    $networkSettings = @(
        # TCP 参数优化
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TcpAckFrequency"; Value=1; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TCPNoDelay"; Value=1; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TcpDelAckTicks"; Value=0; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="MaxUserPort"; Value=65534; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TcpTimedWaitDelay"; Value=30; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TcpFinWait2Delay"; Value=30; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="KeepAliveTime"; Value=300000; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="KeepAliveInterval"; Value=1000; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TcpMaxDataRetransmissions"; Value=5; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="SackOpts"; Value=1; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="Tcp1323Opts"; Value=3; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="GlobalMaxTcpWindowSize"; Value=65535; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TcpWindowSize"; Value=65535; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="MaxFreeTcbs"; Value=65536; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="MaxHashTableSize"; Value=65536; Type="DWord"},
        
        # 禁用 Nagle 算法
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TcpUseRFC1122UrgentPointer"; Value=0; Type="DWord"},
        
        # 网络适配器优化
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="EnablePMTUDiscovery"; Value=1; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="EnablePMTUBHDetect"; Value=0; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="DefaultTTL"; Value=64; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="EnableDca"; Value=1; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="EnableTCPA"; Value=1; Type="DWord"}
    )
    
    foreach ($setting in $networkSettings) {
        try {
            if (-not (Test-Path $setting.Path)) {
                New-Item -Path $setting.Path -Force | Out-Null
            }
            Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -Type $setting.Type -ErrorAction Stop
            Write-ColorOutput "  设置 $($setting.Name) = $($setting.Value)" -Type Success
        }
        catch {
            Write-ColorOutput "  设置 $($setting.Name) 失败: $_" -Type Warning
        }
    }
}

# 优化网络适配器高级设置
function Optimize-NetworkAdapter {
    Write-ColorOutput "优化网络适配器高级设置..." -Type Info
    
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    
    foreach ($adapter in $adapters) {
        Write-ColorOutput "  优化适配器: $($adapter.Name)" -Type Info
        
        try {
            # 禁用流量控制
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Flow Control" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
            
            # 禁用中断调节
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Interrupt Moderation" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
            
            # 设置接收/发送缓冲区
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Receive Buffers" -DisplayValue "512" -ErrorAction SilentlyContinue
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Transmit Buffers" -DisplayValue "512" -ErrorAction SilentlyContinue
            
            # 启用 RSS
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Receive Side Scaling" -DisplayValue "Enabled" -ErrorAction SilentlyContinue
            
            # 禁用节能模式
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Energy Efficient Ethernet" -DisplayValue "Off" -ErrorAction SilentlyContinue
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Green Ethernet" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Power Saving Mode" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
            
            Write-ColorOutput "    适配器优化完成" -Type Success
        }
        catch {
            Write-ColorOutput "    适配器优化部分失败: $_" -Type Warning
        }
    }
}

# 优化电源计划
function Optimize-PowerPlan {
    Write-ColorOutput "优化电源计划..." -Type Info
    
    try {
        # 获取高性能电源计划
        $highPerfPlan = powercfg -list | Select-String "高性能" | ForEach-Object { $_ -match "([a-f0-9-]+)" | Out-Null; $matches[1] }
        
        if ($highPerfPlan) {
            powercfg -setactive $highPerfPlan
            Write-ColorOutput "  已切换到高性能电源计划" -Type Success
        }
        else {
            # 创建自定义高性能计划
            $planGuid = powercfg -duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
            powercfg -setactive $planGuid
            Write-ColorOutput "  已创建并激活高性能电源计划" -Type Success
        }
        
        # 禁用 USB 选择性暂停
        powercfg -setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
        
        # 禁用 PCI Express 链路状态电源管理
        powercfg -setacvalueindex SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
        
        # 设置处理器最小状态为 100%
        powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c 100
        
        # 设置处理器最大状态为 100%
        powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 bc5038f7-23e0-4960-96da-33abaf5935ec 100
        
        powercfg -setactive SCHEME_CURRENT
        
        Write-ColorOutput "  电源计划优化完成" -Type Success
    }
    catch {
        Write-ColorOutput "  电源计划优化失败: $_" -Type Warning
    }
}

# 优化 Windows 服务
function Optimize-WindowsServices {
    Write-ColorOutput "优化 Windows 服务..." -Type Info
    
    $servicesToDisable = @(
        "DiagTrack",                    # 连接用户体验和遥测
        "dmwappushservice",             # WAP 推送消息路由服务
        "SysMain",                      # Superfetch
        "WSearch",                      # Windows Search (如果不需要)
        "WMPNetworkSvc",                # Windows Media Player 网络共享
        "XblAuthManager",               # Xbox Live 身份验证管理器
        "XblGameSave",                  # Xbox Live 游戏保存服务
        "XboxNetApiSvc",                # Xbox Live 网络服务
        "MapsBroker",                   # 离线地图
        "lfsvc",                        # 地理位置服务
        "RetailDemo",                   # 零售演示服务
        "SharedAccess",                 # Internet 连接共享 (ICS)
        "RemoteRegistry",               # 远程注册表
        "Fax"                           # 传真
    )
    
    foreach ($serviceName in $servicesToDisable) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service) {
                Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
                Set-Service -Name $serviceName -StartupType Disabled -ErrorAction SilentlyContinue
                Write-ColorOutput "  已禁用服务: $serviceName" -Type Success
            }
        }
        catch {
            Write-ColorOutput "  禁用服务 $serviceName 失败: $_" -Type Warning
        }
    }
}

# 优化 Windows 计划任务
function Optimize-ScheduledTasks {
    Write-ColorOutput "优化 Windows 计划任务..." -Type Info
    
    $tasksToDisable = @(
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "\Microsoft\Windows\Autochk\Proxy",
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
        "\Microsoft\Windows\Feedback\Siuf\DmClient",
        "\Microsoft\Windows\Maps\MapsUpdateTask",
        "\Microsoft\Windows\Maps\MapsToastTask",
        "\Microsoft\Windows\Windows Error Reporting\QueueReporting"
    )
    
    foreach ($taskPath in $tasksToDisable) {
        try {
            $task = Get-ScheduledTask -TaskPath (Split-Path $taskPath) -TaskName (Split-Path $taskPath -Leaf) -ErrorAction SilentlyContinue
            if ($task) {
                Disable-ScheduledTask -TaskPath (Split-Path $taskPath) -TaskName (Split-Path $taskPath -Leaf) -ErrorAction SilentlyContinue
                Write-ColorOutput "  已禁用计划任务: $taskPath" -Type Success
            }
        }
        catch {
            Write-ColorOutput "  禁用计划任务失败: $_" -Type Warning
        }
    }
}

# 优化内存管理
function Optimize-MemoryManagement {
    Write-ColorOutput "优化内存管理..." -Type Info
    
    $memorySettings = @(
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="DisablePagingExecutive"; Value=1; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="LargeSystemCache"; Value=0; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="ClearPageFileAtShutdown"; Value=0; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="IoPageLockLimit"; Value=983040; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="SystemPages"; Value=0; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="SecondLevelDataCache"; Value=1024; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="SessionPoolSize"; Value=48; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="NonPagedPoolSize"; Value=0; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="PagedPoolSize"; Value=0; Type="DWord"}
    )
    
    foreach ($setting in $memorySettings) {
        try {
            Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -Type $setting.Type -ErrorAction Stop
            Write-ColorOutput "  设置 $($setting.Name) = $($setting.Value)" -Type Success
        }
        catch {
            Write-ColorOutput "  设置 $($setting.Name) 失败: $_" -Type Warning
        }
    }
}

# 优化 Windows 防火墙
function Optimize-Firewall {
    Write-ColorOutput "优化 Windows 防火墙..." -Type Info
    
    try {
        # 启用防火墙
        Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
        
        # 设置默认入站规则为阻止
        Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Block
        
        # 设置默认出站规则为允许
        Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultOutboundAction Allow
        
        # 允许 onefcloud 通过防火墙
        $onefcloudPath = Join-Path $PSScriptRoot "..\..\onefcloud.exe"
        if (Test-Path $onefcloudPath) {
            New-NetFirewallRule -DisplayName "onefcloud" -Direction Inbound -Program $onefcloudPath -Action Allow -Profile Any -ErrorAction SilentlyContinue
            New-NetFirewallRule -DisplayName "onefcloud" -Direction Outbound -Program $onefcloudPath -Action Allow -Profile Any -ErrorAction SilentlyContinue
            Write-ColorOutput "  已添加 onefcloud 防火墙规则" -Type Success
        }
        
        # 允许 onefcloudCore 通过防火墙
        $onefcloudCorePath = Join-Path $PSScriptRoot "..\..\onefcloudCore.exe"
        if (Test-Path $onefcloudCorePath) {
            New-NetFirewallRule -DisplayName "onefcloudCore" -Direction Inbound -Program $onefcloudCorePath -Action Allow -Profile Any -ErrorAction SilentlyContinue
            New-NetFirewallRule -DisplayName "onefcloudCore" -Direction Outbound -Program $onefcloudCorePath -Action Allow -Profile Any -ErrorAction SilentlyContinue
            Write-ColorOutput "  已添加 onefcloudCore 防火墙规则" -Type Success
        }
        
        Write-ColorOutput "  防火墙优化完成" -Type Success
    }
    catch {
        Write-ColorOutput "  防火墙优化失败: $_" -Type Warning
    }
}

# 清理系统垃圾
function Clear-SystemJunk {
    Write-ColorOutput "清理系统垃圾..." -Type Info
    
    $tempPaths = @(
        "$env:TEMP",
        "$env:windir\Temp",
        "$env:windir\Prefetch",
        "$env:LOCALAPPDATA\Temp"
    )
    
    foreach ($path in $tempPaths) {
        if (Test-Path $path) {
            try {
                Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
                Write-ColorOutput "  已清理: $path" -Type Success
            }
            catch {
                Write-ColorOutput "  清理 $path 部分失败" -Type Warning
            }
        }
    }
    
    # 清理 DNS 缓存
    Clear-DnsClientCache
    Write-ColorOutput "  已清理 DNS 缓存" -Type Success
}

# 主执行流程
function Main {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  onefcloud Windows 系统优化工具" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    if ($DryRun) {
        Write-ColorOutput "运行模式: 模拟运行（不实际修改）" -Type Warning
    }
    
    # 创建还原点
    if (-not $DryRun) {
        New-RestorePoint
    }
    
    # 执行优化
    if (-not $DryRun) {
        Optimize-NetworkStack
        Optimize-NetworkAdapter
        Optimize-PowerPlan
        Optimize-WindowsServices
        Optimize-ScheduledTasks
        Optimize-MemoryManagement
        Optimize-Firewall
        Clear-SystemJunk
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  优化完成！" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    if (-not $SkipReboot -and -not $DryRun) {
        $reboot = Read-Host "是否立即重启计算机以应用所有更改？(Y/N)"
        if ($reboot -eq "Y" -or $reboot -eq "y") {
            Restart-Computer -Force
        }
    }
}

# 执行主函数
Main
