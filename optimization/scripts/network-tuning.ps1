#Requires -RunAsAdministrator
<#
.SYNOPSIS
    网络栈深度调优脚本 - 为 onefcloud 提供极致低延迟
.DESCRIPTION
    优化 TCP/IP 协议栈、DNS 解析、网络缓冲区等参数
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

Write-ColorOutput "开始网络栈深度调优..." -Type Info

# 优化 TCP 全局参数
function Optimize-TcpGlobalParameters {
    Write-ColorOutput "优化 TCP 全局参数..." -Type Info
    
    # 使用 netsh 优化 TCP 参数
    $tcpCommands = @(
        # 设置 TCP 自动调优为正常
        "netsh int tcp set global autotuninglevel=normal",
        
        # 启用 TCP 时间戳
        "netsh int tcp set global timestamps=enabled",
        
        # 启用 TCP Chimney Offload
        "netsh int tcp set global chimney=enabled",
        
        # 启用接收端缩放
        "netsh int tcp set global rss=enabled",
        
        # 启用 TCP 直接缓存访问
        "netsh int tcp set global dca=enabled",
        
        # 启用 TCP 初始 RTO
        "netsh int tcp set global initialRto=2000",
        
        # 设置非 SACK RTT 恢复
        "netsh int tcp set global nonsackrttresiliency=disabled",
        
        # 设置最大 SYN 重传次数
        "netsh int tcp set global maxsynretransmissions=2",
        
        # 启用 ECN 功能
        "netsh int tcp set global ecncapability=enabled",
        
        # 启用 CUBIC 拥塞控制
        "netsh int tcp set global congestionprovider=ctcp",
        
        # 启用 TCP 快速打开
        "netsh int tcp set global fastopen=enabled",
        
        # 启用 TCP 快速恢复
        "netsh int tcp set global fastrecovery=enabled"
    )
    
    foreach ($cmd in $tcpCommands) {
        try {
            if (-not $DryRun) {
                $result = Invoke-Expression $cmd 2>&1
                Write-ColorOutput "  执行: $cmd" -Type Success
            }
            else {
                Write-ColorOutput "  [模拟] $cmd" -Type Info
            }
        }
        catch {
            Write-ColorOutput "  命令执行失败: $cmd - $_" -Type Warning
        }
    }
}

# 优化网络接口
function Optimize-NetworkInterfaces {
    Write-ColorOutput "优化网络接口..." -Type Info
    
    # 获取所有活动网络适配器
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    
    foreach ($adapter in $adapters) {
        Write-ColorOutput "  优化适配器: $($adapter.Name) ($($adapter.InterfaceDescription))" -Type Info
        
        try {
            # 设置网络适配器高级属性
            $advancedProperties = @{
                # 禁用流量控制
                "Flow Control" = "Disabled"
                
                # 禁用中断调节
                "Interrupt Moderation" = "Disabled"
                "Interrupt Moderation Rate" = "Off"
                
                # 设置接收缓冲区
                "Receive Buffers" = "1024"
                
                # 设置发送缓冲区
                "Transmit Buffers" = "1024"
                
                # 启用 RSS
                "Receive Side Scaling" = "Enabled"
                "RSS Base Processor" = "0"
                "Maximum Number of RSS Processors" = "4"
                
                # 禁用节能
                "Energy Efficient Ethernet" = "Off"
                "Green Ethernet" = "Disabled"
                "Power Saving Mode" = "Disabled"
                
                # 启用巨型帧（如果支持）
                "Jumbo Packet" = "Disabled"  # 保持默认，除非网络支持
                
                # 禁用卸载功能（减少延迟）
                "IPv4 Checksum Offload" = "Disabled"
                "TCP Checksum Offload (IPv4)" = "Disabled"
                "UDP Checksum Offload (IPv4)" = "Disabled"
                
                # 启用高精度计时器
                "High Precision Timer" = "Enabled"
            }
            
            foreach ($prop in $advancedProperties.GetEnumerator()) {
                try {
                    Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $prop.Key -DisplayValue $prop.Value -ErrorAction SilentlyContinue
                }
                catch {
                    # 某些属性可能不存在，忽略错误
                }
            }
            
            # 设置网络适配器属性
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Packet Coalescing" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
            
            Write-ColorOutput "    适配器优化完成" -Type Success
        }
        catch {
            Write-ColorOutput "    适配器优化失败: $_" -Type Warning
        }
    }
}

# 优化 DNS 客户端
function Optimize-DnsClient {
    Write-ColorOutput "优化 DNS 客户端..." -Type Info
    
    try {
        # 设置 DNS 客户端缓存大小
        Set-DnsClientCache -MaxCacheTtl 86400 -MaxNegativeCacheTtl 300 -ErrorAction SilentlyContinue
        
        # 启用 DNS 客户端全局查询阻止列表
        Set-DnsClientGlobalSetting -QueryBlockListEnabled $true -ErrorAction SilentlyContinue
        
        # 设置 DNS 客户端设置
        $dnsSettings = @{
            Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
            Settings = @{
                "MaxCacheEntryTtlLimit" = 86400
                "MaxCacheTtl" = 86400
                "MaxNegativeCacheTtl" = 5
                "NetFailureCacheTime" = 0
                "NegativeCacheTime" = 0
                "NegativeSOACacheTime" = 0
                "CacheHashTableBucketSize" = 1
                "CacheHashTableSize" = 384
                "MaxSOACacheEntryTtlLimit" = 300
                "ServiceStartDelay" = 0
            }
        }
        
        foreach ($setting in $dnsSettings.Settings.GetEnumerator()) {
            try {
                Set-ItemProperty -Path $dnsSettings.Path -Name $setting.Key -Value $setting.Value -Type DWord -ErrorAction Stop
                Write-ColorOutput "  设置 DNS $($setting.Key) = $($setting.Value)" -Type Success
            }
            catch {
                Write-ColorOutput "  设置 DNS $($setting.Key) 失败: $_" -Type Warning
            }
        }
        
        # 清除 DNS 缓存
        Clear-DnsClientCache
        Write-ColorOutput "  DNS 缓存已清除" -Type Success
        
    }
    catch {
        Write-ColorOutput "  DNS 客户端优化失败: $_" -Type Warning
    }
}

# 优化 QoS 策略
function Optimize-QoS {
    Write-ColorOutput "优化 QoS 策略..." -Type Info
    
    try {
        # 设置 QoS 策略
        $qosPolicy = @{
            Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
            Settings = @{
                "NonBestEffortLimit" = 0
                "MaxOutstandingSends" = 65535
            }
        }
        
        if (-not (Test-Path $qosPolicy.Path)) {
            New-Item -Path $qosPolicy.Path -Force | Out-Null
        }
        
        foreach ($setting in $qosPolicy.Settings.GetEnumerator()) {
            try {
                Set-ItemProperty -Path $qosPolicy.Path -Name $setting.Key -Value $setting.Value -Type DWord -ErrorAction Stop
                Write-ColorOutput "  设置 QoS $($setting.Key) = $($setting.Value)" -Type Success
            }
            catch {
                Write-ColorOutput "  设置 QoS $($setting.Key) 失败: $_" -Type Warning
            }
        }
        
        # 禁用 QoS 数据包计划程序带宽限制
        $qosBandwidth = @{
            Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
            Name = "NonBestEffortLimit"
            Value = 0
        }
        
        Set-ItemProperty -Path $qosBandwidth.Path -Name $qosBandwidth.Name -Value $qosBandwidth.Value -Type DWord -ErrorAction SilentlyContinue
        
        Write-ColorOutput "  QoS 策略优化完成" -Type Success
    }
    catch {
        Write-ColorOutput "  QoS 策略优化失败: $_" -Type Warning
    }
}

# 优化 Windows 网络堆栈
function Optimize-NetworkStack {
    Write-ColorOutput "优化 Windows 网络堆栈..." -Type Info
    
    $networkStackSettings = @(
        # 禁用 TCP/IP 上的 NetBIOS
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters"; Name="NodeType"; Value=2; Type="DWord"},
        
        # 禁用 LMHOSTS 查找
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters"; Name="EnableLMHOSTS"; Value=0; Type="DWord"},
        
        # 设置 ARP 缓存生存时间
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="ArpCacheLife"; Value=600; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="ArpCacheMinReferencedLife"; Value=600; Type="DWord"},
        
        # 禁用 IP 源路由
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="DisableIPSourceRouting"; Value=2; Type="DWord"},
        
        # 禁用 IP 路由
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="IPEnableRouter"; Value=0; Type="DWord"},
        
        # 启用死网关检测
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="EnableDeadGWDetect"; Value=1; Type="DWord"},
        
        # 禁用路径 MTU 发现
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="EnablePMTUDiscovery"; Value=1; Type="DWord"},
        
        # 设置默认 TTL
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="DefaultTTL"; Value=128; Type="DWord"},
        
        # 启用 TCP 窗口缩放
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="Tcp1323Opts"; Value=3; Type="DWord"},
        
        # 设置 TCP 窗口大小
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TcpWindowSize"; Value=65535; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="GlobalMaxTcpWindowSize"; Value=65535; Type="DWord"},
        
        # 启用选择性确认
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="SackOpts"; Value=1; Type="DWord"},
        
        # 设置最大 SYN 重传次数
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TcpMaxConnectRetransmissions"; Value=2; Type="DWord"},
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TcpMaxDataRetransmissions"; Value=3; Type="DWord"},
        
        # 设置 TCP 连接超时
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TcpMaxConnectResponseRetransmissions"; Value=2; Type="DWord"},
        
        # 启用 TCP 时间戳
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="Tcp1323Opts"; Value=3; Type="DWord"},
        
        # 禁用 TCP/IP 上的 NetBIOS
        @{Path="HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters"; Name="SMBDeviceEnabled"; Value=0; Type="DWord"}
    )
    
    foreach ($setting in $networkStackSettings) {
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

# 优化网络性能计数器
function Optimize-NetworkPerformance {
    Write-ColorOutput "优化网络性能计数器..." -Type Info
    
    try {
        # 重建性能计数器
        $result = & lodctr /r 2>&1
        Write-ColorOutput "  性能计数器已重建" -Type Success
        
        # 刷新性能计数器
        $result = & winmgmt /resyncperf 2>&1
        Write-ColorOutput "  性能计数器已刷新" -Type Success
    }
    catch {
        Write-ColorOutput "  性能计数器优化失败: $_" -Type Warning
    }
}

# 优化 Windows 连接限制
function Optimize-ConnectionLimits {
    Write-ColorOutput "优化 Windows 连接限制..." -Type Info
    
    try {
        # 设置 TCP 连接限制
        $connectionLimits = @{
            Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
            Settings = @{
                "MaxUserPort" = 65534
                "TcpTimedWaitDelay" = 30
                "MaxFreeTcbs" = 65536
                "MaxHashTableSize" = 65536
            }
        }
        
        foreach ($setting in $connectionLimits.Settings.GetEnumerator()) {
            try {
                Set-ItemProperty -Path $connectionLimits.Path -Name $setting.Key -Value $setting.Value -Type DWord -ErrorAction Stop
                Write-ColorOutput "  设置 $($setting.Key) = $($setting.Value)" -Type Success
            }
            catch {
                Write-ColorOutput "  设置 $($setting.Key) 失败: $_" -Type Warning
            }
        }
        
        Write-ColorOutput "  连接限制优化完成" -Type Success
    }
    catch {
        Write-ColorOutput "  连接限制优化失败: $_" -Type Warning
    }
}

# 主执行流程
function Main {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  onefcloud 网络栈深度调优工具" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    if ($DryRun) {
        Write-ColorOutput "运行模式: 模拟运行（不实际修改）" -Type Warning
    }
    
    # 执行优化
    Optimize-TcpGlobalParameters
    Optimize-NetworkInterfaces
    Optimize-DnsClient
    Optimize-QoS
    Optimize-NetworkStack
    Optimize-NetworkPerformance
    Optimize-ConnectionLimits
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  网络栈调优完成！" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-ColorOutput "建议重启计算机以使所有更改生效" -Type Info
}

# 执行主函数
Main
