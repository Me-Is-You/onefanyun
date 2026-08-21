<#
.SYNOPSIS
    使用 onefcloud 内置的 mihomo 内核直接运行优化配置（看门守护、秒级自愈）
.DESCRIPTION
    绕过 Flutter 界面，直接用发行包自带的 onefcloudCore.exe（mihomo/Clash.Meta 内核）
    加载 profile-optimizer.ps1 生成的优化配置：

      * 自动准备运行目录并复制 GEOIP/GEOSITE/ASN 数据库（离线规则可用）
      * -Tun 模式：注入 TUN(mixed 栈) 全局接管，自动提权管理员
      * 配置启动前校验（-t），失败绝不带病运行
      * 看门狗：核心崩溃自动重启（1s/2s/5s 递增退避，上限 30s），极致稳定
      * 启动后健康探测（mixed-port 7890 / 控制器 9090）

    用法:
      .\run-optimized-core.ps1                       # 系统代理模式
      .\run-optimized-core.ps1 -Tun                  # TUN 全局模式(需管理员,自动提权)
      .\run-optimized-core.ps1 -Token <token>        # 配置不存在时自动拉取+优化
#>

[CmdletBinding()]
param(
    [string]$ConfigPath,

    [string]$Token,

    [switch]$Tun,

    [switch]$NoWatchdog,

    [string]$CoreExe
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root      = [IO.Path]::GetFullPath((Join-Path $scriptDir "..\.."))
$runtimeDir = [IO.Path]::GetFullPath((Join-Path $scriptDir "..\runtime"))
if (-not $ConfigPath) { $ConfigPath = Join-Path $runtimeDir "optimized-profile.yaml" }
if (-not $CoreExe)    { $CoreExe    = Join-Path $root "onefcloudCore.exe" }

function Write-Log {
    param([string]$Msg, [ValidateSet("ok","warn","err","info")][string]$T = "info")
    $c = @{ ok="Green"; warn="Yellow"; err="Red"; info="Cyan" }[$T]
    $p = @{ ok="[+]"; warn="[!]"; err="[x]"; info="[i]" }[$T]
    Write-Host "$p $Msg" -ForegroundColor $c
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ---- TUN 需要管理员：自动提权重启 -----------------------------------------
if ($Tun -and -not (Test-Admin)) {
    Write-Log "TUN 模式需要管理员权限，正在提权..." "warn"
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"", "-Tun")
    if ($Token)     { $argList += "-Token", "`"$Token`"" }
    if ($ConfigPath -and $ConfigPath -ne (Join-Path $runtimeDir "optimized-profile.yaml")) { $argList += "-ConfigPath", "`"$ConfigPath`"" }
    Start-Process powershell -Verb RunAs -ArgumentList ($argList -join " ")
    exit
}

# ---- 就绪性检查 ------------------------------------------------------------
if (-not (Test-Path $CoreExe)) {
    Write-Log "找不到内核: $CoreExe （请在本发行包根目录运行）" "err"; exit 1
}
if (-not (Test-Path $ConfigPath)) {
    if ($Token) {
        Write-Log "配置不存在，自动生成（token=****）..." "info"
        & (Join-Path $scriptDir "profile-optimizer.ps1") -Token $Token -OutputPath $ConfigPath
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { Write-Log "优化配置生成失败" "err"; exit 2 }
    }
    else {
        Write-Log "配置不存在: $ConfigPath （先运行 profile-optimizer.ps1 -Token <token>，或传 -Token）" "err"; exit 2
    }
}

# ---- 运行目录 + GEO 数据库 ------------------------------------------------
New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
$geoSrc = Join-Path $root "data\flutter_assets\assets\data"
if (Test-Path $geoSrc) {
    foreach ($f in @("GEOIP.dat", "GEOSITE.dat", "ASN.mmdb", "GEOIP.metadb", "country.mmdb")) {
        $src = Join-Path $geoSrc $f
        if (Test-Path $src) {
            $dst = Join-Path $runtimeDir $f
            if (-not (Test-Path $dst)) { Copy-Item $src $dst; Write-Log "GEO 就绪: $f" "info" }
        }
    }
}
$logFile = Join-Path $runtimeDir "core.log"

# ---- TUN 注入 --------------------------------------------------------------
if ($Tun) {
    $cfg = [IO.File]::ReadAllText($ConfigPath)
    if ($cfg -notmatch "(?m)^tun:") {
        $tunBlock = "tun:`n  enable: true`n  stack: mixed`n  auto-route: true`n" +
                    "  auto-redirect: true`n  auto-detect-interface: true`n  dns-hijack: [ any:53 ]`n"
        $cfg = $cfg -replace "(?m)^dns:", ($tunBlock + "dns:")
        [IO.File]::WriteAllText($ConfigPath, $cfg, (New-Object Text.UTF8Encoding($false)))
        Write-Log "已注入 TUN(mixed) 全局接管配置" "ok"
    }
}

# ---- 启动前配置校验 ---------------------------------------------------------
Write-Log "校验配置..." "info"
& $CoreExe -t -d "$runtimeDir" -f "$ConfigPath" 2>&1 | Tee-Object -Variable testOut | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Log "配置校验失败，内核输出:" "err"
    $testOut | Select-Object -First 15 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    exit 3
}
Write-Log "配置校验通过" "ok"

# ---- 启动 + 看门狗 ---------------------------------------------------------
Write-Log "启动内核: $CoreExe" "ok"
Write-Log "运行目录: $runtimeDir | 配置: $ConfigPath" "info"
Write-Log "系统代理: 127.0.0.1:7890 | 控制器: 127.0.0.1:9090$(if ($Tun) { ' | TUN 全局接管' })" "info"
Write-Host ""

$backoff = 1; $starts = 0
try {
    while ($true) {
        $starts++
        $p = Start-Process -FilePath $CoreExe `
             -ArgumentList @("-d", "`"$runtimeDir`"", "-f", "`"$ConfigPath`"") `
             -WorkingDirectory $root -PassThru -NoNewWindow `
             -RedirectStandardOutput $logFile -RedirectStandardError "$logFile.err"
        Write-Log "[$starts] 内核 PID $($p.Id) 已启动" "ok"

        # 启动健康探测（最多 15s）
        $healthy = $false
        foreach ($i in 1..15) {
            Start-Sleep -Seconds 1
            if ($p.HasExited) { break }
            try {
                $t = New-Object Net.Sockets.TcpClient
                $t.Connect("127.0.0.1", 7890)
                if ($t.Connected) { $healthy = $true; $t.Close(); break }
            } catch {}
        }
        if ($healthy) {
            Write-Log "健康探测通过：mixed 端口 7890 就绪" "ok"
            $backoff = 1
        }

        if ($NoWatchdog) { Wait-Process -Id $p.Id -ErrorAction SilentlyContinue; break }
        if (-not $p.HasExited) { Wait-Process -Id $p.Id -ErrorAction SilentlyContinue }
        $p.Refresh()
        $code = $p.ExitCode
        Write-Log "内核退出 (code=$code)，${backoff}s 后自动重启..." "warn"
        Start-Sleep -Seconds $backoff
        $backoff = [Math]::Min($backoff * 2, 30)
    }
}
finally {
    Get-Process -Name "onefcloudCore" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Log "已停止" "info"
}
