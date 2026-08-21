<#
.SYNOPSIS
    一翻云本地订阅修复代理（零依赖、无需管理员）
.DESCRIPTION
    在本机 127.0.0.1:8787 起一个微型 HTTP 服务。把 App 的订阅地址换成
        http://127.0.0.1:8787/sub
    之后每次自动更新，App 拿到的都是「已修复 + 已优化」的配置：

      * 上游强制 flag=clash.meta —— 根治 flag=clash 返回空节点的 P0 BUG
      * 自动应用 profile-optimizer.ps1 的全部修复（端口/short-id/安全/性能）
      * 透传 subscription-userinfo 响应头 —— App 内流量/到期显示不受影响
      * 上游结果缓存 CacheTtl 秒 —— 秒级响应、断网时继续用缓存（低延迟+高可用）
      * 记录访问与刷新日志，Ctrl+C 退出

    路由:
      GET /sub      -> 优化后的 clash.meta 配置
      GET /health   -> 服务与缓存状态
      GET /refresh  -> 立刻强制刷新上游
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Token,

    [int]$Port = 8787,

    [int]$CacheTtl = 300,

    [string]$ApiHost = "api.1flyuntt.cc",

    [switch]$EnableMux,

    [switch]$PinDns
)

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "profile-optimizer.ps1")

$script:cache = $null          # { Body, UserInfo, Fetched }
$script:stats = @{ served = 0; refreshed = 0; errors = 0 }

function Write-SrvLog {
    param([string]$Msg, [string]$T = "info")
    Write-Log ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Msg) $T
}

function Update-Cache {
    param([switch]$Force)
    if ($script:cache -and -not $Force -and
        ((Get-Date) - $script:cache.Fetched).TotalSeconds -lt $CacheTtl) { return }

    try {
        $sub = Get-RawSubscription -Tok $Token
        if (-not $sub.Content -or $sub.Content.Trim().Length -lt 20) { throw "上游返回空内容" }
        $nodeCount = ([regex]::Matches($sub.Content, "(?m)^\s*-\s*\{\s*name:")).Count
        if ($nodeCount -eq 0) { throw "上游返回 0 节点（套餐过期或 token 失效）" }

        $pinned = $null
        if ($PinDns) {
            $pinned = Resolve-NodeDomains -Domains @(
                "testgo.1fanjiedianlink.lol", "jp-drect.iz2ze58f9krop9tgbc.org",
                "us-drect.iz2ze58f9krop9tgbc.org", "dg-drect.iz2ze58f9krop9tgbc.org"
            ) -Server "178.94.14.101"
        }
        $result = Optimize-ProfileConfig -Config $sub.Content -Mux:$EnableMux -DnsPin:$PinDns -PinnedHosts $pinned
        $script:cache = [pscustomobject]@{
            Body = $result.Config; UserInfo = $sub.UserInfo; Fetched = Get-Date; Nodes = $nodeCount
        }
        $script:stats.refreshed++
        Write-SrvLog "上游刷新成功: $nodeCount 节点, $($result.Applied.Count) 项补丁" "ok"
    }
    catch {
        $script:stats.errors++
        if ($script:cache) { Write-SrvLog "刷新失败(继续用缓存): $($_.Exception.Message)" "warn" }
        else { Write-SrvLog "刷新失败且无缓存: $($_.Exception.Message)" "err" }
    }
}

function Send-Response {
    param($Stream, [int]$Code, [string]$Status, [string]$Body,
          [hashtable]$ExtraHeaders = @{})
    $enc = [Text.Encoding]::UTF8
    $bytes = $enc.GetBytes($Body)
    $h = "HTTP/1.1 $Code $Status`r`nContent-Type: text/plain; charset=utf-8`r`n" +
         "Content-Length: $($bytes.Length)`r`nConnection: close`r`n"
    foreach ($k in $ExtraHeaders.Keys) { $h += "$k`: $($ExtraHeaders[$k])`r`n" }
    $h += "`r`n"
    $hb = $enc.GetBytes($h)
    $Stream.Write($hb, 0, $hb.Length)
    if ($bytes.Length -gt 0) { $Stream.Write($bytes, 0, $bytes.Length) }
    $Stream.Flush()
}

function Handle-Client {
    param($Client)
    try {
        $Client.ReceiveTimeout = 10000
        $stream = $Client.GetStream()
        $reader = New-Object IO.StreamReader($stream, [Text.Encoding]::ASCII)
        $reqLine = $reader.ReadLine()
        if (-not $reqLine) { return }
        $parts = $reqLine.Split(" ")
        if ($parts.Count -lt 3) { return }
        $method, $path = $parts[0], ($parts[1] -split "\?")[0]

        if ($method -ne "GET" -and $method -ne "HEAD") {
            Send-Response $stream 405 "Method Not Allowed" "405 Method Not Allowed`n"
            return
        }

        switch ($path) {
            "/sub" {
                Update-Cache
                if ($script:cache) {
                    $extra = @{ "profile-update-interval" = "6" }
                    if ($script:cache.UserInfo) { $extra["subscription-userinfo"] = $script:cache.UserInfo }
                    $extra["Content-Disposition"] = 'attachment; filename="optimized-profile.yaml"'
                    Send-Response $stream 200 "OK" $script:cache.Body $extra
                    $script:stats.served++
                    Write-SrvLog "/sub -> 200 ($($script:cache.Nodes) 节点, 缓存 $([int]((Get-Date) - $script:cache.Fetched).TotalSeconds)s)")
                }
                else {
                    Send-Response $stream 502 "Bad Gateway" "# 上游订阅暂不可用且无缓存，请稍后重试`n"
                }
            }
            "/health" {
                Update-Cache
                $age = if ($script:cache) { [int]((Get-Date) - $script:cache.Fetched).TotalSeconds } else { -1 }
                $json = '{{"status":"ok","served":{0},"refreshed":{1},"errors":{2},"cache_age_sec":{3},"nodes":{4}}}' -f `
                        $script:stats.served, $script:stats.refreshed, $script:stats.errors, $age, $(if ($script:cache) { $script:cache.Nodes } else { 0 })
                Send-Response $stream 200 "OK" $json
            }
            "/refresh" {
                Update-Cache -Force
                Send-Response $stream 200 "OK" '{"refreshed":true}'
            }
            default {
                Send-Response $stream 404 "Not Found" "404`n用法: GET /sub | /health | /refresh`n"
            }
        }
    }
    catch { Write-SrvLog "连接处理异常: $($_.Exception.Message)" "warn" }
    finally { try { $Client.Close() } catch {} }
}

# ------------------------------------------------------------------- main --
Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  一翻云 本地订阅修复代理  127.0.0.1:$Port" -ForegroundColor Cyan
Write-Host "  上游: https://$ApiHost (flag=clash.meta 强制)" -ForegroundColor Cyan
Write-Host "  缓存: ${CacheTtl}s   mux: $($EnableMux.IsPresent)   dns-pin: $($PinDns.IsPresent)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
Write-SrvLog "预热上游订阅..." "info"
Update-Cache -Force

$listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $Port)
$listener.Start()
Write-SrvLog "就绪。把 App 订阅地址改为: http://127.0.0.1:$Port/sub  (Ctrl+C 退出)" "ok"

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        Handle-Client -Client $client
    }
}
finally {
    $listener.Stop()
    Write-SrvLog "已停止 (served=$($script:stats.served) refreshed=$($script:stats.refreshed) errors=$($script:stats.errors))" "info"
}
