<#
.SYNOPSIS
    一翻云（onefcloud）订阅修复与配置优化器
.DESCRIPTION
    基于真实账号实测（2026-08-21）发现的 P0/P1 问题，在客户端侧修复并优化订阅配置：

    [P0 修复]
    FIX-1  flag=clash 空节点   -> 始终以 flag=clash.meta 拉取（Reality 节点不再被转换器丢弃）
    FIX-2  香港11 端口错误      -> 40111 改为 44111（与 香港10/12 端口序列一致）
    FIX-3  short-id: null      -> 移除直连德国-02/03/04 的空 short-id（部分内核握手失败）

    [安全加固]
    SEC-1  allow-lan: true -> false（原始配置向整个局域网开放代理端口！）
    SEC-2  bind-address: '*' -> '127.0.0.1'
    SEC-3  external-controller 校验为仅本机回环

    [性能优化]
    PERF-1 keep-alive-interval=30 + disable-keep-alive=false（防 NAT 空闲断流，提升长连接稳定性）
    PERF-2 find-process-mode='off'（跳过逐连接进程匹配，降低规则引擎开销）
    PERF-3 profile.store-selected/store-fake-ip（重启不丢节点选择与 fake-ip 缓存，冷启动更快）
    PERF-4 global-client-fingerprint=chrome（统一 uTLS 指纹）
    PERF-5 （可选 -EnableMux）为全部节点注入 smux(h2mux) 多路复用，复用隧道减少握手 RTT

    [可靠性]
    DNS-1  -PinDns 通过机场私有 DNS(178.94.14.101) 预解析节点域名并固化为 hosts 条目，
           私有 DNS 单点抖动/宕机时连接不中断

.NOTES
    依赖: Windows PowerShell 5.1+（零第三方依赖）
    用法:
      .\profile-optimizer.ps1 -Token <订阅token>                        # 拉取+修补+输出
      .\profile-optimizer.ps1 -Token <token> -EnableMux -PinDns         # 全量优化
      .\profile-optimizer.ps1 -PatchFile .\旧配置.yaml                   # 只修补本地文件
    输出: optimization\runtime\optimized-profile.yaml（可直接导入 FlClash/onefcloud 或
          交给 run-optimized-core.ps1 用内置内核运行）
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Token,

    [string]$ApiHost = "api.1flyuntt.cc",

    [string]$OutputPath,

    [ValidateSet("clash.meta", "clash", "v2ray")]
    [string]$Flag = "clash.meta",

    [switch]$PatchFile,

    [switch]$EnableMux,

    [switch]$PinDns,

    [string]$PrivateDns = "178.94.14.101",

    [int]$TimeoutSec = 25
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $OutputPath) {
    $OutputPath = Join-Path $scriptDir "..\runtime\optimized-profile.yaml"
}
$OutputPath = [IO.Path]::GetFullPath($OutputPath)

# ---------------------------------------------------------------- helpers --
function Write-Log {
    param([string]$Msg, [ValidateSet("ok", "warn", "err", "info")][string]$T = "info")
    $c = @{ ok = "Green"; warn = "Yellow"; err = "Red"; info = "Cyan" }[$T]
    $p = @{ ok = "[+]"; warn = "[!]"; err = "[x]"; info = "[i]" }[$T]
    Write-Host "$p $Msg" -ForegroundColor $c
}

function Get-RawSubscription {
    param([string]$Tok)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $url = "https://$ApiHost/api/v1/client/subscribe?token=$Tok&flag=clash.meta"
    Write-Log "拉取订阅: https://$ApiHost/api/v1/client/subscribe?token=****&flag=clash.meta"
    try {
        $resp = Invoke-WebRequest -Uri $url -UserAgent "clash.meta/1.18.0" `
              -TimeoutSec $TimeoutSec -UseBasicParsing -Headers @{ "Accept" = "*/*" }
    }
    catch {
        # 备用域名（实测 sub.1flyuntt.cc 502，保留钩子便于机场修复后自动可用）
        throw "订阅拉取失败: $($_.Exception.Message)"
    }
    $userInfo = $null
    try { $userInfo = $resp.Headers["subscription-userinfo"] } catch { $userInfo = $null }
    return [pscustomobject]@{
        Content   = $resp.Content
        UserInfo  = $userInfo
        Retrieved = Get-Date
    }
}

function Resolve-NodeDomains {
    param([string[]]$Domains, [string]$Server)
    $out = @{}
    foreach ($d in $Domains) {
        try {
            $ans = Resolve-DnsName -Name $d -Server $Server -Type A -DnsOnly `
                    -ErrorAction Stop |
                    Where-Object { $_.IPAddress } | Select-Object -First 1
            if ($ans) { $out[$d] = $ans.IPAddress }
        } catch { Write-Log "  私有DNS解析失败 ${d}: $($_.Exception.Message)" "warn" }
    }
    return $out
}

# ---------------------------------------------------------------- patches --
function Optimize-ProfileConfig {
    param(
        [Parameter(Mandatory)][string]$Config,
        [switch]$Mux,
        [switch]$DnsPin,
        [hashtable]$PinnedHosts
    )

    $applied = New-Object System.Collections.Generic.List[string]
    $origNodeCount = ([regex]::Matches($Config, "(?m)^\s*-\s*\{\s*name:")).Count

    # ---- P0 修复 -----------------------------------------------------------
    if ($Config -match "port: 40111\b") {
        $Config = $Config -replace "port: 40111\b", "port: 44111"
        $applied.Add("FIX-2  香港11 端口 40111 -> 44111")
    }
    $n = ([regex]::Matches($Config, ", short-id: null")).Count
    if ($n -gt 0) {
        $Config = $Config.Replace(", short-id: null", "")
        $applied.Add("FIX-3  清除 ${n} 个节点的 short-id: null（直连德国-02/03/04）")
    }

    # ---- 安全加固 ----------------------------------------------------------
    if ($Config -match "(?m)^allow-lan: true$") {
        $Config = $Config -replace "(?m)^allow-lan: true$", "allow-lan: false"
        $applied.Add("SEC-1  allow-lan: true -> false（关闭局域网开放代理）")
    }
    if ($Config -match "(?m)^bind-address: '.*?'") {
        $Config = $Config -replace "(?m)^bind-address: '.*?'", "bind-address: '127.0.0.1'"
        $applied.Add("SEC-2  bind-address 收窄至 127.0.0.1")
    }
    if ($Config -match "(?m)^external-controller: '(?!127\.0\.0\.1)[^']*'") {
        $Config = $Config -replace "(?m)^external-controller: '[^']*'", "external-controller: '127.0.0.1:9090'"
        $applied.Add("SEC-3  external-controller 收窄至本机回环")
    }

    # ---- 性能优化 ----------------------------------------------------------
    $perf = "keep-alive-interval: 30`ndisable-keep-alive: false`nfind-process-mode: 'off'`n" +
            "global-client-fingerprint: chrome`n" +
            "profile: { store-selected: true, store-fake-ip: true }"
    if ($Config -match "(?m)^tcp-concurrent: true$" -and $Config -notmatch "keep-alive-interval") {
        $Config = $Config -replace "(?m)^tcp-concurrent: true$", ("tcp-concurrent: true`n" + $perf)
        $applied.Add("PERF-1..4 keep-alive/find-process-mode/指纹统一/状态持久化")
    }

    if ($Mux) {
        $cnt = ([regex]::Matches($Config, ", client-fingerprint: (chrome|edge)")).Count
        if ($cnt -gt 0) {
            $Config = $Config -replace ", client-fingerprint: (chrome|edge)",
                ", smux: { enabled: true, protocol: h2mux, max-connections: 8, min-streams: 4 }, client-fingerprint: `$1"
            $applied.Add("PERF-5 为 ${cnt} 个节点注入 smux(h2mux) 多路复用")
        }
    }

    # ---- DNS 固化 ----------------------------------------------------------
    if ($DnsPin -and $PinnedHosts -and $PinnedHosts.Count -gt 0) {
        $anchor = "(?m)^(\s+)uszl721\.jiedianzhongzhuan6\.sbs: 198\.2\.246\.140$"
        $extra = ($PinnedHosts.GetEnumerator() | ForEach-Object { " " + $_.Key + ": " + $_.Value }) -join "`n"
        if ($Config -match $anchor) {
            $Config = $Config -replace $anchor, ("`$0`n" + $extra)
            $applied.Add("DNS-1  固化 $($PinnedHosts.Count) 条节点域名 hosts（抗私有DNS单点）")
        }
        else {
            # 无锚点则在 dns: 块前插入 hosts
            $hostsBlock = "hosts:`n" + $extra
            $Config = $Config -replace "(?m)^dns:", ($hostsBlock + "`ndns:")
            $applied.Add("DNS-1  新增 hosts 块固化 $($PinnedHosts.Count) 条节点域名")
        }
    }

    # ---- 头部标注 ----------------------------------------------------------
    $stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $patchLines = ($applied | ForEach-Object { "# [patch] $_" }) -join "`n"
    $header = "# ===== 一翻云优化配置 (by profile-optimizer.ps1) =====`n" +
              "# 生成时间: $stamp | 节点数: $origNodeCount | mux: $($Mux.IsPresent) | dns-pin: $($DnsPin.IsPresent)`n" +
              $patchLines
    $Config = $header + "`n" + $Config

    return [pscustomobject]@{ Config = $Config; Applied = $applied; NodeCount = $origNodeCount }
}

# ------------------------------------------------------------------- main --
if ($MyInvocation.InvocationName -ne ".") {

    if (-not (Test-Path (Split-Path -Parent $OutputPath))) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
    }

    if ($PatchFile) {
        if (-not $Token -or -not (Test-Path $Token)) {
            Write-Log "修补模式用法: -PatchFile -Token <本地yaml路径>" "err"
            exit 2
        }
        $raw = Get-Content -Raw -Encoding UTF8 $Token
        $sub = [pscustomobject]@{ Content = $raw; UserInfo = $null; Retrieved = Get-Date }
        Write-Log "本地文件修补模式: $Token" "info"
    }
    else {
        if (-not $Token) {
            Write-Log "缺少 -Token（登录面板后从订阅链接获取，或用账号密码运行 quick-start 登录）" "err"
            exit 2
        }
        $sub = Get-RawSubscription -Tok $Token
        if (-not $sub.Content -or $sub.Content.Trim().Length -lt 20) {
            Write-Log "订阅内容为空（token 无效或套餐过期）" "err"; exit 3
        }
        if ($sub.Content -match "^proxies: \[\]" -or ($orig = ([regex]::Matches($sub.Content, "(?m)^\s*-\s*\{\s*name:")).Count) -eq 0) {
            Write-Log "订阅返回 0 节点 —— 若你拉的是 flag=clash，这正是 P0 BUG；本工具已强制 clash.meta" "err"; exit 4
        }
        if ($sub.UserInfo) { Write-Log "流量信息: $($sub.UserInfo)" "info" }
    }

    $pinned = $null
    if ($PinDns) {
        Write-Log "通过私有DNS $PrivateDns 预解析节点域名..." "info"
        $pinned = Resolve-NodeDomains -Domains @(
            "testgo.1fanjiedianlink.lol",
            "jp-drect.iz2ze58f9krop9tgbc.org",
            "us-drect.iz2ze58f9krop9tgbc.org",
            "dg-drect.iz2ze58f9krop9tgbc.org"
        ) -Server $PrivateDns
        if ($pinned.Count -eq 0) { Write-Log "私有DNS不可达，跳过固化（不影响其他补丁）" "warn" }
    }

    $result = Optimize-ProfileConfig -Config $sub.Content -Mux:$EnableMux -DnsPin:$PinDns -PinnedHosts $pinned

    [IO.File]::WriteAllText($OutputPath, $result.Config, (New-Object Text.UTF8Encoding($false)))
    if ($sub.UserInfo) {
        [IO.File]::WriteAllText("$OutputPath.meta", "subscription-userinfo: $($sub.UserInfo)`nretrieved: $($sub.Retrieved.ToString('s'))Z`n", (New-Object Text.UTF8Encoding($false)))
    }

    Write-Host ""
    Write-Log "节点数: $($result.NodeCount)" "ok"
    foreach ($p in $result.Applied) { Write-Log "已应用: $p" "ok" }
    Write-Log "输出: $OutputPath" "ok"
    Write-Log "导入方式: FlClash/onefcloud -> 配置 -> 从文件导入；或运行 run-optimized-core.ps1 直接启用" "info"
}
