#Requires -RunAsAdministrator
<#
.SYNOPSIS
    onefcloud 一键优化启动脚本
.DESCRIPTION
    自动执行系统优化、网络调优、安全加固，为 onefcloud 提供极致性能和安全
.NOTES
    需要管理员权限运行
#>

[CmdletBinding()]
param(
    [switch]$SkipSystemOptimize,
    [switch]$SkipNetworkTuning,
    [switch]$SkipSecurityHardening,
    [switch]$SkipHealthCheck,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# 颜色输出
function Write-ColorOutput {
    param(
        [string]$Message,
        [ValidateSet("Success", "Warning", "Error", "Info", "Header")]
        [string]$Type = "Info"
    )
    
    $colors = @{
        "Success" = "Green"
        "Warning" = "Yellow"
        "Error"   = "Red"
        "Info"    = "Cyan"
        "Header"  = "Magenta"
    }
    
    $prefix = switch ($Type) {
        "Success" { "[✓]" }
        "Warning" { "[!]" }
        "Error"   { "[✗]" }
        "Info"    { "[i]" }
        "Header"  { "[*]" }
    }
    
    Write-Host "$prefix $Message" -ForegroundColor $colors[$Type]
}

# 显示横幅
function Show-Banner {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                                                            ║" -ForegroundColor Cyan
    Write-Host "║           onefcloud 极致优化工具 v1.0.0                   ║" -ForegroundColor Cyan
    Write-Host "║                                                            ║" -ForegroundColor Cyan
    Write-Host "║       极致稳定 · 超低延迟 · 极致安全                      ║" -ForegroundColor Cyan
    Write-Host "║                                                            ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

# 检查管理员权限
function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# 显示优化摘要
function Show-OptimizationSummary {
    param(
        [bool]$SystemOptimized,
        [bool]$NetworkTuned,
        [bool]$SecurityHardened,
        [bool]$HealthChecked
    )
    
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                      优化完成摘要                          ║" -ForegroundColor Green
    Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Green
    Write-Host "║                                                            ║" -ForegroundColor Green
    Write-Host "║  系统优化: $(if ($SystemOptimized) { '✓ 完成' } else { '✗ 跳过' })                                          ║" -ForegroundColor Green
    Write-Host "║  网络调优: $(if ($NetworkTuned) { '✓ 完成' } else { '✗ 跳过' })                                          ║" -ForegroundColor Green
    Write-Host "║  安全加固: $(if ($SecurityHardened) { '✓ 完成' } else { '✗ 跳过' })                                          ║" -ForegroundColor Green
    Write-Host "║  健康检查: $(if ($HealthChecked) { '✓ 完成' } else { '✗ 跳过' })                                          ║" -ForegroundColor Green
    Write-Host "║                                                            ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
}

# 主执行流程
function Main {
    # 显示横幅
    Show-Banner
    
    # 检查管理员权限
    if (-not (Test-Admin)) {
        Write-ColorOutput "请以管理员权限运行此脚本！" -Type Error
        Write-ColorOutput "右键点击 PowerShell，选择'以管理员身份运行'" -Type Info
        exit 1
    }
    
    Write-ColorOutput "开始一键优化..." -Type Header
    Write-ColorOutput "优化时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Type Info
    Write-ColorOutput "运行模式: $(if ($DryRun) { '模拟运行' } else { '实际执行' })" -Type Info
    Write-Host ""
    
    # 初始化状态
    $systemOptimized = $false
    $networkTuned = $false
    $securityHardened = $false
    $healthChecked = $false
    
    # 1. 系统优化
    if (-not $SkipSystemOptimize) {
        Write-ColorOutput "步骤 1/4: 系统优化" -Type Header
        Write-Host "----------------------------------------"
        
        try {
            $script = Join-Path $scriptPath "scripts\windows-optimize.ps1"
            if (Test-Path $script) {
                if (-not $DryRun) {
                    & $script -SkipReboot
                }
                else {
                    & $script -DryRun
                }
                $systemOptimized = $true
                Write-ColorOutput "系统优化完成" -Type Success
            }
            else {
                Write-ColorOutput "找不到系统优化脚本: $script" -Type Warning
            }
        }
        catch {
            Write-ColorOutput "系统优化失败: $_" -Type Error
        }
        
        Write-Host ""
    }
    else {
        Write-ColorOutput "步骤 1/4: 系统优化 - 已跳过" -Type Warning
    }
    
    # 2. 网络调优
    if (-not $SkipNetworkTuning) {
        Write-ColorOutput "步骤 2/4: 网络调优" -Type Header
        Write-Host "----------------------------------------"
        
        try {
            $script = Join-Path $scriptPath "scripts\network-tuning.ps1"
            if (Test-Path $script) {
                if (-not $DryRun) {
                    & $script
                }
                else {
                    & $script -DryRun
                }
                $networkTuned = $true
                Write-ColorOutput "网络调优完成" -Type Success
            }
            else {
                Write-ColorOutput "找不到网络调优脚本: $script" -Type Warning
            }
        }
        catch {
            Write-ColorOutput "网络调优失败: $_" -Type Error
        }
        
        Write-Host ""
    }
    else {
        Write-ColorOutput "步骤 2/4: 网络调优 - 已跳过" -Type Warning
    }
    
    # 3. 安全加固
    if (-not $SkipSecurityHardening) {
        Write-ColorOutput "步骤 3/4: 安全加固" -Type Header
        Write-Host "----------------------------------------"
        
        try {
            $script = Join-Path $scriptPath "scripts\security-hardening.ps1"
            if (Test-Path $script) {
                if (-not $DryRun) {
                    & $script
                }
                else {
                    & $script -DryRun
                }
                $securityHardened = $true
                Write-ColorOutput "安全加固完成" -Type Success
            }
            else {
                Write-ColorOutput "找不到安全加固脚本: $script" -Type Warning
            }
        }
        catch {
            Write-ColorOutput "安全加固失败: $_" -Type Error
        }
        
        Write-Host ""
    }
    else {
        Write-ColorOutput "步骤 3/4: 安全加固 - 已跳过" -Type Warning
    }
    
    # 4. 健康检查
    if (-not $SkipHealthCheck) {
        Write-ColorOutput "步骤 4/4: 健康检查" -Type Header
        Write-Host "----------------------------------------"
        
        try {
            $script = Join-Path $scriptPath "scripts\health-check.ps1"
            if (Test-Path $script) {
                & $script
                $healthChecked = $true
                Write-ColorOutput "健康检查完成" -Type Success
            }
            else {
                Write-ColorOutput "找不到健康检查脚本: $script" -Type Warning
            }
        }
        catch {
            Write-ColorOutput "健康检查失败: $_" -Type Error
        }
        
        Write-Host ""
    }
    else {
        Write-ColorOutput "步骤 4/4: 健康检查 - 已跳过" -Type Warning
    }
    
    # 显示优化摘要
    Show-OptimizationSummary -SystemOptimized $systemOptimized -NetworkTuned $networkTuned -SecurityHardened $securityHardened -HealthChecked $healthChecked
    
    # 显示后续步骤
    Write-ColorOutput "后续步骤:" -Type Header
    Write-Host "----------------------------------------"
    Write-ColorOutput "1. 配置 onefcloud 配置文件" -Type Info
    Write-ColorOutput "2. 启动 onefcloud 应用" -Type Info
    Write-ColorOutput "3. 运行健康检查验证: .\scripts\health-check.ps1" -Type Info
    Write-ColorOutput "4. 查看优化文档: docs\deployment-guide.md" -Type Info
    Write-Host ""
    
    # 询问是否重启
    if (-not $DryRun -and ($systemOptimized -or $networkTuned -or $securityHardened)) {
        $reboot = Read-Host "是否立即重启计算机以应用所有更改？(Y/N)"
        if ($reboot -eq "Y" -or $reboot -eq "y") {
            Write-ColorOutput "正在重启计算机..." -Type Warning
            Start-Sleep -Seconds 3
            Restart-Computer -Force
        }
        else {
            Write-ColorOutput "请稍后手动重启计算机以应用所有更改" -Type Info
        }
    }
}

# 执行主函数
Main
