#Requires -RunAsAdministrator
<#
.SYNOPSIS
    安全加固脚本 - 为 onefcloud 提供极致安全防护
.DESCRIPTION
    加固 Windows 系统安全、网络安全、隐私保护等
.NOTES
    需要管理员权限运行
#>

[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# 颜色输出
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

Write-ColorOutput "开始安全加固..." -Type Info

# 禁用遥测和数据收集
function Disable-Telemetry {
    Write-ColorOutput "禁用遥测和数据收集..." -Type Info
    
    try {
        # 禁用 Windows 遥测
        $telemetrySettings = @{
            Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
            Settings = @{
                "AllowTelemetry" = 0
                "DoNotShowFeedbackNotifications" = 1
                "AllowDeviceNameInTelemetry" = 0
            }
        }
        
        if (-not (Test-Path $telemetrySettings.Path)) {
            New-Item -Path $telemetrySettings.Path -Force | Out-Null
        }
        
        foreach ($setting in $telemetrySettings.Settings.GetEnumerator()) {
            Set-ItemProperty -Path $telemetrySettings.Path -Name $setting.Key -Value $setting.Value -Type DWord -ErrorAction SilentlyContinue
            Write-ColorOutput "  设置 $($setting.Key) = $($setting.Value)" -Type Success
        }
        
        # 禁用诊断数据查看器
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack" -Name "ShowedToastAtLevel" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        
        # 禁用应用遥测
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" -Name "AITEnable" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" -Name "DisableInventory" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" -Name "DisableUAR" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        
        Write-ColorOutput "  遥测和数据收集已禁用" -Type Success
    }
    catch {
        Write-ColorOutput "  禁用遥测失败: $_" -Type Warning
    }
}

# 禁用位置服务
function Disable-LocationServices {
    Write-ColorOutput "禁用位置服务..." -Type Info
    
    try {
        # 禁用位置服务
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocation" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"Name="DisableWindowsLocationProvider" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocationScripting" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        
        Write-ColorOutput "  位置服务已禁用" -Type Success
    }
    catch {
        Write-ColorOutput "  禁用位置服务失败: $_" -Type Warning
    }
}

# 禁用 Cortana
function Disable-Cortana {
    Write-ColorOutput "禁用 Cortana..." -Type Info
    
    try {
        # 禁用 Cortana
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "DisableWebSearch" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "ConnectedSearchUseWeb" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        
        Write-ColorOutput "  Cortana 已禁用" -Type Success
    }
    catch {
        Write-ColorOutput "  禁用 Cortana 失败: $_" -Type Warning
    }
}

# 禁用广告 ID
function Disable-AdvertisingId {
    Write-ColorOutput "禁用广告 ID..." -Type Info
    
    try {
        # 禁用广告 ID
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Name "DisabledByGroupPolicy" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        
        Write-ColorOutput "  广告 ID 已禁用" -Type Success
    }
    catch {
        Write-ColorOutput "  禁用广告 ID 失败: $_" -Type Warning
    }
}

# 禁用活动历史记录
function Disable-ActivityHistory {
    Write-ColorOutput "禁用活动历史记录..." -Type Info
    
    try {
        # 禁用活动历史记录
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        
        Write-ColorOutput "  活动历史记录已禁用" -Type Success
    }
    catch {
        Write-ColorOutput "  禁用活动历史记录失败: $_" -Type Warning
    }
}

# 加固 Windows 防火墙
function Harden-Firewall {
    Write-ColorOutput "加固 Windows 防火墙..." -Type Info
    
    try {
        # 启用所有防火墙配置文件
        Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
        
        # 设置默认入站规则为阻止
        Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Block
        
        # 设置默认出站规则为允许
        Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultOutboundAction Allow
        
        # 启用日志记录
        Set-NetFirewallProfile -Profile Domain,Public,Private -LogBlocked True
        Set-NetFirewallProfile -Profile Domain,Public,Private -LogFileName "%systemroot%\system32\LogFiles\Firewall\pfirewall.log"
        Set-NetFirewallProfile -Profile Domain,Public,Private -LogMaxSizeKilobytes 32767
        
        # 禁用入站规则的例外
        Set-NetFirewallProfile -Profile Domain,Public,Private -AllowInboundRules False
        Set-NetFirewallProfile -Profile Domain,Public,Private -AllowLocalFirewallRules False
        Set-NetFirewallProfile -Profile Domain,Public,Private -AllowLocalIPsecRules False
        
        Write-ColorOutput "  防火墙加固完成" -Type Success
    }
    catch {
        Write-ColorOutput "  防火墙加固失败: $_" -Type Warning
    }
}

# 禁用远程桌面
function Disable-RemoteDesktop {
    Write-ColorOutput "禁用远程桌面..." -Type Info
    
    try {
        # 禁用远程桌面
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        
        # 禁用远程协助
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" -Name "fAllowToGetHelp" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        
        Write-ColorOutput "  远程桌面已禁用" -Type Success
    }
    catch {
        Write-ColorOutput "  禁用远程桌面失败: $_" -Type Warning
    }
}

# 禁用自动登录
function Disable-AutoLogin {
    Write-ColorOutput "禁用自动登录..." -Type Info
    
    try {
        # 禁用自动登录
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -Value 0 -Type String -ErrorAction SilentlyContinue
        
        Write-ColorOutput "  自动登录已禁用" -Type Success
    }
    catch {
        Write-ColorOutput "  禁用自动登录失败: $_" -Type Warning
    }
}

# 加固 SMB 协议
function Harden-SMB {
    Write-ColorOutput "加固 SMB 协议..." -Type Info
    
    try {
        # 禁用 SMBv1
        Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction SilentlyContinue
        
        # 启用 SMBv3 加密
        Set-SmbServerConfiguration -EncryptData $true -Force -ErrorAction SilentlyContinue
        
        # 禁用 SMB 签名
        Set-SmbServerConfiguration -RequireSecuritySignature $true -Force -ErrorAction SilentlyContinue
        
        Write-ColorOutput "  SMB 协议加固完成" -Type Success
    }
    catch {
        Write-ColorOutput "  SMB 协议加固失败: $_" -Type Warning
    }
}

# 禁用 PowerShell v2
function Disable-PowerShellV2 {
    Write-ColorOutput "禁用 PowerShell v2..." -Type Info
    
    try {
        # 禁用 PowerShell v2
        Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root -NoRestart -ErrorAction SilentlyContinue
        
        Write-ColorOutput "  PowerShell v2 已禁用" -Type Success
    }
    catch {
        Write-ColorOutput "  禁用 PowerShell v2 失败: $_" -Type Warning
    }
}

# 启用 Windows Defender 加强模式
function Enable-DefenderHardening {
    Write-ColorOutput "启用 Windows Defender 加强模式..." -Type Info
    
    try {
        # 启用实时保护
        Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
        
        # 启用云保护
        Set-MpPreference -MAPSReporting Advanced -ErrorAction SilentlyContinue
        
        # 启用样本提交
        Set-MpPreference -SubmitSamplesConsent SendAllSamples -ErrorAction SilentlyContinue
        
        # 启用行为监控
        Set-MpPreference -DisableBehaviorMonitoring $false -ErrorAction SilentlyContinue
        
        # 启用 IOAV 保护
        Set-MpPreference -DisableIOAVProtection $false -ErrorAction SilentlyContinue
        
        # 启用脚本扫描
        Set-MpPreference -DisableScriptScanning $false -ErrorAction SilentlyContinue
        
        # 启用网络保护
        Set-MpPreference -EnableNetworkProtection Enabled -ErrorAction SilentlyContinue
        
        # 启用攻击面减少规则
        Set-MpPreference -AttackSurfaceReductionRules_Ids BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550 -AttackSurfaceReductionRules_Actions Enabled -ErrorAction SilentlyContinue
        
        # 设置扫描计划
        Set-MpPreference -ScanScheduleQuickScanTime 12:00:00 -ErrorAction SilentlyContinue
        Set-MpPreference -ScanScheduleDay 0 -ErrorAction SilentlyContinue
        
        # 设置排除项（onefcloud 目录）
        $onefcloudPath = Join-Path $PSScriptRoot "..\.."
        Add-MpPreference -ExclusionPath $onefcloudPath -ErrorAction SilentlyContinue
        
        Write-ColorOutput "  Windows Defender 加强模式已启用" -Type Success
    }
    catch {
        Write-ColorOutput "  Windows Defender 加强失败: $_" -Type Warning
    }
}

# 加固网络协议
function Harden-NetworkProtocols {
    Write-ColorOutput "加固网络协议..." -Type Info
    
    try {
        # 禁用 LLMNR
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        
        # 禁用 NetBIOS
        $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
        if ($adapter) {
            $key = "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces\Tcpip_$($adapter.InterfaceGuid)"
            if (Test-Path $key) {
                Set-ItemProperty -Path $key -Name "NetbiosOptions" -Value 2 -Type DWord -ErrorAction SilentlyContinue
            }
        }
        
        # 禁用 WPAD
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad" -Name "WpadOverride" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        
        # 禁用 SMBv1
        Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction SilentlyContinue
        
        Write-ColorOutput "  网络协议加固完成" -Type Success
    }
    catch {
        Write-ColorOutput "  网络协议加固失败: $_" -Type Warning
    }
}

# 配置 DNS over HTTPS
function Configure-DoH {
    Write-ColorOutput "配置 DNS over HTTPS..." -Type Info
    
    try {
        # 配置 Cloudflare DoH
        Add-DnsClientDohServerAddress -ServerAddress "1.1.1.1" -DohTemplate "https://1.1.1.1/dns-query" -AllowFallbackToUdp $false -AutoUpgrade $true -ErrorAction SilentlyContinue
        Add-DnsClientDohServerAddress -ServerAddress "1.0.0.1" -DohTemplate "https://1.0.0.1/dns-query" -AllowFallbackToUdp $false -AutoUpgrade $true -ErrorAction SilentlyContinue
        
        # 配置 Google DoH
        Add-DnsClientDohServerAddress -ServerAddress "8.8.8.8" -DohTemplate "https://dns.google/dns-query" -AllowFallbackToUdp $false -AutoUpgrade $true -ErrorAction SilentlyContinue
        Add-DnsClientDohServerAddress -ServerAddress "8.8.4.4" -DohTemplate "https://dns.google/dns-query" -AllowFallbackToUdp $false -AutoUpgrade $true -ErrorAction SilentlyContinue
        
        Write-ColorOutput "  DNS over HTTPS 配置完成" -Type Success
    }
    catch {
        Write-ColorOutput "  配置 DNS over HTTPS 失败: $_" -Type Warning
    }
}

# 禁用 Windows 调试功能
function Disable-DebugFeatures {
    Write-ColorOutput "禁用 Windows 调试功能..." -Type Info
    
    try {
        # 禁用内核调试
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "SystemStartOptions" -Value "NODEBUG" -Type String -ErrorAction SilentlyContinue
        
        # 禁用 Dr. Watson
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AeDebug" -Name "Auto" -Value 0 -Type String -ErrorAction SilentlyContinue
        
        Write-ColorOutput "  Windows 调试功能已禁用" -Type Success
    }
    catch {
        Write-ColorOutput "  禁用调试功能失败: $_" -Type Warning
    }
}

# 加固本地安全策略
function Harden-LocalSecurityPolicy {
    Write-ColorOutput "加固本地安全策略..." -Type Info
    
    try {
        # 导出当前安全策略
        secedit /export /cfg "$env:TEMP\secpol.cfg" /quiet
        
        # 读取安全策略文件
        $secpol = Get-Content "$env:TEMP\secpol.cfg" -ErrorAction SilentlyContinue
        
        if ($secpol) {
            # 修改密码策略
            $secpol = $secpol -replace "MinimumPasswordLength = \d+", "MinimumPasswordLength = 12"
            $secpol = $secpol -replace "PasswordComplexity = \d+", "PasswordComplexity = 1"
            $secpol = $secpol -replace "PasswordHistorySize = \d+", "PasswordHistorySize = 24"
            $secpol = $secpol -replace "MaximumPasswordAge = \d+", "MaximumPasswordAge = 90"
            
            # 修改账户锁定策略
            $secpol = $secpol -replace "LockoutBadCount = \d+", "LockoutBadCount = 5"
            $secpol = $secpol -replace "ResetLockoutCount = \d+", "ResetLockoutCount = 30"
            $secpol = $secpol -replace "LockoutDuration = \d+", "LockoutDuration = 30"
            
            # 保存修改后的安全策略
            $secpol | Set-Content "$env:TEMP\secpol_new.cfg" -ErrorAction SilentlyContinue
            
            # 导入新的安全策略
            secedit /configure /db "$env:windir\security\local.sdb" /cfg "$env:TEMP\secpol_new.cfg" /quiet
            
            Write-ColorOutput "  本地安全策略加固完成" -Type Success
        }
    }
    catch {
        Write-ColorOutput "  本地安全策略加固失败: $_" -Type Warning
    }
}

# 配置 Windows 事件日志
function Configure-EventLogging {
    Write-ColorOutput "配置 Windows 事件日志..." -Type Info
    
    try {
        # 启用安全事件日志
        $securityLog = Get-WinEvent -ListLog Security -ErrorAction SilentlyContinue
        if ($securityLog) {
            wevtutil sl Security /ms:1073741824  # 1GB
            wevtutil sl Security /rt:true
            Write-ColorOutput "  安全日志配置完成" -Type Success
        }
        
        # 启用系统事件日志
        $systemLog = Get-WinEvent -ListLog System -ErrorAction SilentlyContinue
        if ($systemLog) {
            wevtutil sl System /ms:536870912  # 512MB
            Write-ColorOutput "  系统日志配置完成" -Type Success
        }
        
        # 启用应用程序事件日志
        $appLog = Get-WinEvent -ListLog Application -ErrorAction SilentlyContinue
        if ($appLog) {
            wevtutil sl Application /ms:536870912  # 512MB
            Write-ColorOutput "  应用程序日志配置完成" -Type Success
        }
        
        Write-ColorOutput "  事件日志配置完成" -Type Success
    }
    catch {
        Write-ColorOutput "  事件日志配置失败: $_" -Type Warning
    }
}

# 主执行流程
function Main {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  onefcloud 安全加固工具" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    if ($DryRun) {
        Write-ColorOutput "运行模式: 模拟运行（不实际修改）" -Type Warning
    }
    
    # 执行安全加固
    if (-not $DryRun) {
        Disable-Telemetry
        Disable-LocationServices
        Disable-Cortana
        Disable-AdvertisingId
        Disable-ActivityHistory
        Harden-Firewall
        Disable-RemoteDesktop
        Disable-AutoLogin
        Harden-SMB
        Disable-PowerShellV2
        Enable-DefenderHardening
        Harden-NetworkProtocols
        Configure-DoH
        Disable-DebugFeatures
        Harden-LocalSecurityPolicy
        Configure-EventLogging
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  安全加固完成！" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-ColorOutput "建议重启计算机以使所有更改生效" -Type Info
}

# 执行主函数
Main
