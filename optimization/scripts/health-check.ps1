<#
.SYNOPSIS
    健康检查与自动恢复脚本 - 为 onefcloud 提供持续稳定运行
.DESCRIPTION
    监控 onefcloud 运行状态，自动检测和恢复故障
.NOTES
    可以作为计划任务定期运行
#>

[CmdletBinding()]
param(
    [int]$Interval = 60,
    [switch]$AutoRecover,
    [switch]$Continuous
)

$ErrorActionPreference = "Continue"

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

# 检查 onefcloud 进程
function Test-OnefcloudProcess {
    $processes = @(
        @{Name="onefcloud"; Path="onefcloud.exe"},
        @{Name="onefcloudCore"; Path="onefcloudCore.exe"},
        @{Name="onefcloudHelperService"; Path="onefcloudHelperService.exe"}
    )
    
    $results = @()
    
    foreach ($proc in $processes) {
        $process = Get-Process -Name $proc.Name -ErrorAction SilentlyContinue
        
        if ($process) {
            $results += @{
                Name = $proc.Name
                Status = "Running"
                PID = $process.Id
                CPU = $process.CPU
                Memory = [math]::Round($process.WorkingSet64 / 1MB, 2)
                Handles = $process.HandleCount
                Threads = $process.Threads.Count
            }
        }
        else {
            $results += @{
                Name = $proc.Name
                Status = "Stopped"
                PID = $null
                CPU = $null
                Memory = $null
                Handles = $null
                Threads = $null
            }
        }
    }
    
    return $results
}

# 检查网络连接
function Test-NetworkConnectivity {
    $tests = @(
        @{Name="本地代理"; Address="127.0.0.1"; Port=2080},
        @{Name="Clash API"; Address="127.0.0.1"; Port=9090},
        @{Name="Cloudflare DNS"; Address="1.1.1.1"; Port=443},
        @{Name="Google DNS"; Address="8.8.8.8"; Port=443},
        @{Name="国内 DNS"; Address="119.29.29.29"; Port=443}
    )
    
    $results = @()
    
    foreach ($test in $tests) {
        $result = Test-NetConnection -ComputerName $test.Address -Port $test.Port -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        
        $results += @{
            Name = $test.Name
            Address = $test.Address
            Port = $test.Port
            Connected = $result.TcpTestSucceeded
            Latency = $result.PingReplyDetails.RoundtripTime
        }
    }
    
    return $results
}

# 检查 DNS 解析
function Test-DnsResolution {
    $domains = @(
        "www.google.com",
        "www.youtube.com",
        "www.github.com",
        "www.baidu.com",
        "www.taobao.com"
    )
    
    $results = @()
    
    foreach ($domain in $domains) {
        try {
            $dns = Resolve-DnsName -Name $domain -Type A -ErrorAction Stop | Select-Object -First 1
            
            $results += @{
                Domain = $domain
                Resolved = $true
                IP = $dns.IPAddress
                TTL = $dns.TTL
            }
        }
        catch {
            $results += @{
                Domain = $domain
                Resolved = $false
                IP = $null
                TTL = $null
            }
        }
    }
    
    return $results
}

# 检查系统资源
function Test-SystemResources {
    $cpu = (Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
    
    $memory = Get-WmiObject Win32_OperatingSystem
    $memoryUsage = [math]::Round((($memory.TotalVisibleMemorySize - $memory.FreePhysicalMemory) / $memory.TotalVisibleMemorySize) * 100, 2)
    
    $disk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
    $diskUsage = [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 2)
    
    return @{
        CPU = @{
            Usage = $cpu
            Status = if ($cpu -gt 80) { "High" } elseif ($cpu -gt 50) { "Medium" } else { "Normal" }
        }
        Memory = @{
            Usage = $memoryUsage
            TotalGB = [math]::Round($memory.TotalVisibleMemorySize / 1MB, 2)
            FreeGB = [math]::Round($memory.FreePhysicalMemory / 1MB, 2)
            Status = if ($memoryUsage -gt 90) { "Critical" } elseif ($memoryUsage -gt 70) { "High" } else { "Normal" }
        }
        Disk = @{
            Usage = $diskUsage
            TotalGB = [math]::Round($disk.Size / 1GB, 2)
            FreeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
            Status = if ($diskUsage -gt 90) { "Critical" } elseif ($diskUsage -gt 80) { "High" } else { "Normal" }
        }
    }
}

# 检查日志文件
function Test-LogFiles {
    $logPath = Join-Path $PSScriptRoot "..\..\logs\sing-box.log"
    
    $results = @{
        LogExists = Test-Path $logPath
        LogSize = $null
        LastError = $null
        ErrorCount = 0
        WarningCount = 0
    }
    
    if ($results.LogExists) {
        $logFile = Get-Item $logPath
        $results.LogSize = [math]::Round($logFile.Length / 1KB, 2)
        
        # 读取最后 100 行日志
        $logContent = Get-Content $logPath -Tail 100 -ErrorAction SilentlyContinue
        
        if ($logContent) {
            $results.ErrorCount = ($logContent | Select-String -Pattern "error|Error|ERROR" | Measure-Object).Count
            $results.WarningCount = ($logContent | Select-String -Pattern "warn|Warn|WARN" | Measure-Object).Count
            
            # 获取最后一条错误
            $lastError = $logContent | Select-String -Pattern "error|Error|ERROR" | Select-Object -Last 1
            if ($lastError) {
                $results.LastError = $lastError.Line
            }
        }
    }
    
    return $results
}

# 自动恢复
function Invoke-AutoRecover {
    param(
        [string]$ProcessName
    )
    
    Write-ColorOutput "尝试恢复进程: $ProcessName" -Type Warning
    
    $processPath = Join-Path $PSScriptRoot "..\..\$ProcessName.exe"
    
    if (Test-Path $processPath) {
        try {
            Start-Process -FilePath $processPath -WindowStyle Hidden
            Write-ColorOutput "  进程 $ProcessName 已启动" -Type Success
            return $true
        }
        catch {
            Write-ColorOutput "  启动进程 $ProcessName 失败: $_" -Type Error
            return $false
        }
    }
    else {
        Write-ColorOutput "  找不到可执行文件: $processPath" -Type Error
        return $false
    }
}

# 清理 DNS 缓存
function Clear-DnsCache {
    Write-ColorOutput "清理 DNS 缓存..." -Type Info
    
    try {
        Clear-DnsClientCache
        Write-ColorOutput "  DNS 缓存已清理" -Type Success
    }
    catch {
        Write-ColorOutput "  清理 DNS 缓存失败: $_" -Type Warning
    }
}

# 重启网络适配器
function Restart-NetworkAdapter {
    Write-ColorOutput "重启网络适配器..." -Type Info
    
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.InterfaceDescription -notmatch "onefcloud|TAP|VPN" }
    
    foreach ($adapter in $adapters) {
        try {
            Write-ColorOutput "  重启适配器: $($adapter.Name)" -Type Info
            Restart-NetAdapter -Name $adapter.Name -ErrorAction SilentlyContinue
            Write-ColorOutput "    适配器已重启" -Type Success
        }
        catch {
            Write-ColorOutput "    重启适配器失败: $_" -Type Warning
        }
    }
}

# 生成健康报告
function New-HealthReport {
    param(
        [array]$ProcessResults,
        [array]$NetworkResults,
        [array]$DnsResults,
        [hashtable]$SystemResults,
        [hashtable]$LogResults
    )
    
    $report = @"
========================================
  onefcloud 健康检查报告
  时间: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
========================================

[进程状态]
$($ProcessResults | ForEach-Object {
    "$($_.Name): $($_.Status) $(if ($_.PID) { "(PID: $($_.PID), Memory: $($_.Memory)MB)" })"
} | Out-String)

[网络连接]
$($NetworkResults | ForEach-Object {
    "$($_.Name) ($($_.Address):$($_.Port)): $(if ($_.Connected) { "✓ 连接正常 ($($_.Latency)ms)" } else { "✗ 连接失败" })"
} | Out-String)

[DNS 解析]
$($DnsResults | ForEach-Object {
    "$($_.Domain): $(if ($_.Resolved) { "✓ 解析成功 ($($_.IP))" } else { "✗ 解析失败" })"
} | Out-String)

[系统资源]
CPU 使用率: $($SystemResults.CPU.Usage)% ($($SystemResults.CPU.Status))
内存使用率: $($SystemResults.Memory.Usage)% ($($SystemResults.Memory.Status)) - $($SystemResults.Memory.FreeGB)GB 可用
磁盘使用率: $($SystemResults.Disk.Usage)% ($($SystemResults.Disk.Status)) - $($SystemResults.Disk.FreeGB)GB 可用

[日志状态]
日志文件存在: $($LogResults.LogExists)
日志大小: $($LogResults.LogSize) KB
错误数量: $($LogResults.ErrorCount)
警告数量: $($LogResults.WarningCount)
$(if ($LogResults.LastError) { "最后错误: $($LogResults.LastError)" })

========================================
"@
    
    return $report
}

# 主执行流程
function Main {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  onefcloud 健康检查工具" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    do {
        Write-ColorOutput "开始健康检查... $(Get-Date -Format 'HH:mm:ss')" -Type Info
        
        # 执行检查
        $processResults = Test-OnefcloudProcess
        $networkResults = Test-NetworkConnectivity
        $dnsResults = Test-DnsResolution
        $systemResults = Test-SystemResources
        $logResults = Test-LogFiles
        
        # 生成报告
        $report = New-HealthReport -ProcessResults $processResults -NetworkResults $networkResults -DnsResults $dnsResults -SystemResults $systemResults -LogResults $logResults
        
        # 输出报告
        Write-Host $report
        
        # 检查是否需要自动恢复
        if ($AutoRecover) {
            foreach ($proc in $processResults) {
                if ($proc.Status -eq "Stopped" -and $proc.Name -ne "onefcloudHelperService") {
                    Invoke-AutoRecover -ProcessName $proc.Name
                }
            }
            
            # 检查系统资源
            if ($systemResults.CPU.Status -eq "High" -or $systemResults.Memory.Status -eq "Critical") {
                Write-ColorOutput "系统资源紧张，建议关闭不必要的程序" -Type Warning
            }
            
            # 检查 DNS 解析
            $failedDns = $dnsResults | Where-Object { -not $_.Resolved }
            if ($failedDns) {
                Write-ColorOutput "DNS 解析失败，清理 DNS 缓存..." -Type Warning
                Clear-DnsCache
            }
            
            # 检查日志错误
            if ($logResults.ErrorCount -gt 10) {
                Write-ColorOutput "日志中发现大量错误，请检查配置" -Type Warning
            }
        }
        
        # 保存报告
        $reportPath = Join-Path $PSScriptRoot "..\..\logs\health-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
        $report | Out-File -FilePath $reportPath -Encoding UTF8 -ErrorAction SilentlyContinue
        
        # 持续监控模式
        if ($Continuous) {
            Write-ColorOutput "等待 $Interval 秒后进行下一次检查..." -Type Info
            Start-Sleep -Seconds $Interval
        }
        
    } while ($Continuous)
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  健康检查完成！" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
}

# 执行主函数
Main
