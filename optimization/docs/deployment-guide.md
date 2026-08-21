# onefcloud 部署指南

> 极致稳定 · 超低延迟 · 极致安全

## 目录

1. [系统要求](#系统要求)
2. [安装步骤](#安装步骤)
3. [配置优化](#配置优化)
4. [安全加固](#安全加固)
5. [性能监控](#性能监控)
6. [故障排除](#故障排除)

---

## 系统要求

### 最低配置

| 组件 | 要求 |
|------|------|
| 操作系统 | Windows 10 64-bit (版本 1903 或更高) |
| 处理器 | 1 GHz 或更快 |
| 内存 | 4 GB RAM |
| 存储空间 | 500 MB 可用空间 |
| 网络 | 宽带互联网连接 |

### 推荐配置

| 组件 | 要求 |
|------|------|
| 操作系统 | Windows 11 64-bit |
| 处理器 | 2 GHz 或更快，多核 |
| 内存 | 8 GB RAM 或更多 |
| 存储空间 | 1 GB 可用空间（SSD 推荐） |
| 网络 | 稳定的宽带连接，延迟 < 100ms |

### 前置软件

- **WebView2 Runtime**：用于渲染 Web 内容
  - 下载地址：https://developer.microsoft.com/en-us/microsoft-edge/webview2/
  - Windows 11 通常已预装

- **Visual C++ Redistributable**：运行时库
  - 下载地址：https://aka.ms/vs/17/release/vc_redist.x64.exe

---

## 安装步骤

### 1. 下载并解压

```powershell
# 创建安装目录
mkdir C:\Program Files\onefcloud

# 解压文件到安装目录
Expand-Archive -Path onefcloud.zip -DestinationPath "C:\Program Files\onefcloud"
```

### 2. 运行系统优化脚本（推荐）

```powershell
# 以管理员身份运行 PowerShell
# 进入优化脚本目录
cd "C:\Program Files\onefcloud\optimization\scripts"

# 运行 Windows 系统优化
.\windows-optimize.ps1

# 运行网络栈调优
.\network-tuning.ps1

# 运行安全加固
.\security-hardening.ps1
```

### 3. 配置 onefcloud

#### 3.1 复制优化配置

```powershell
# 复制客户端配置
Copy-Item "C:\Program Files\onefcloud\optimization\config\sing-box-client.json" -Destination "$env:APPDATA\onefcloud\config.json"
```

#### 3.2 编辑配置文件

打开配置文件，修改以下参数：

```json
{
  "outbounds": [
    {
      "type": "vless",
      "tag": "proxy-out",
      "server": "YOUR_SERVER_ADDRESS",  // ← 替换为你的服务器地址
      "server_port": 443,
      "uuid": "YOUR_UUID",  // ← 替换为你的 UUID
      "tls": {
        "server_name": "YOUR_SERVER_NAME",  // ← 替换为你的域名
        "reality": {
          "public_key": "YOUR_PUBLIC_KEY",  // ← 替换为你的公钥
          "short_id": "YOUR_SHORT_ID"  // ← 替换为你的短 ID
        }
      }
    }
  ]
}
```

### 4. 启动 onefcloud

```powershell
# 启动主程序
Start-Process "C:\Program Files\onefcloud\onefcloud.exe"
```

### 5. 验证安装

```powershell
# 运行健康检查
.\health-check.ps1

# 测试网络连接
curl -x http://127.0.0.1:2080 https://www.google.com
```

---

## 配置优化

### DNS 优化

配置文件中的 DNS 设置：

```json
{
  "dns": {
    "servers": [
      {
        "tag": "dns-secure",
        "address": "https://1.1.1.1/dns-query",  // Cloudflare DoH
        "address_resolver": "dns-direct",
        "address_strategy": "prefer_ipv4",
        "strategy": "prefer_ipv4",
        "detour": "proxy-out",
        "max_cache_size": 65535,
        "disable_cache": false,
        "disable_expire": false
      },
      {
        "tag": "dns-direct",
        "address": "https://doh.pub/dns-query",  // 腾讯 DoH（国内）
        "address_strategy": "prefer_ipv4",
        "strategy": "prefer_ipv4",
        "detour": "direct-out",
        "max_cache_size": 65535
      }
    ],
    "rules": [
      {
        "domain_suffix": [".cn", ".中国"],
        "server": "dns-direct"  // 国内域名使用国内 DNS
      }
    ],
    "final": "dns-secure",  // 其他域名使用加密 DNS
    "independent_cache": true
  }
}
```

**优化要点：**
- 使用 DNS-over-HTTPS (DoH) 或 DNS-over-TLS (DoT) 加密 DNS 查询
- 分离国内外 DNS，提高解析速度
- 启用 DNS 缓存，减少重复解析
- 设置合理的缓存大小和 TTL

### 代理协议优化

推荐使用 **VLESS + Reality** 协议：

```json
{
  "type": "vless",
  "flow": "xtls-rprx-vision",
  "tls": {
    "enabled": true,
    "server_name": "www.microsoft.com",
    "reality": {
      "enabled": true,
      "public_key": "...",
      "short_id": "..."
    },
    "alpn": ["h2", "http/1.1"],
    "min_version": "1.3",
    "max_version": "1.3"
  },
  "multiplex": {
    "enabled": true,
    "protocol": "h2mux",
    "max_connections": 4,
    "min_streams": 4,
    "max_streams": 0,
    "padding": true,
    "brutal": {
      "enabled": true,
      "up_mbps": 100,
      "down_mbps": 500
    }
  }
}
```

**优化要点：**
- 使用 TLS 1.3 强制加密
- 启用 Reality 协议，伪装流量
- 启用 Multiplex 多路复用，减少连接数
- 启用 Brutal 拥塞控制，提高吞吐量
- 使用 XUDP 数据包编码，减少开销

### TUN 模式优化

```json
{
  "type": "tun",
  "tag": "tun-in",
  "interface_name": "onefcloud-tun",
  "inet4_address": "172.19.0.1/30",
  "inet6_address": "fdfe:dcba:9876::1/126",
  "auto_route": true,
  "strict_route": true,
  "stack": "mixed",
  "mtu": 9000,
  "sniff": true,
  "sniff_override_destination": true,
  "sniff_timeout": "300ms",
  "domain_strategy": "prefer_ipv4",
  "endpoint_independent_nat": false
}
```

**优化要点：**
- 使用 mixed 栈，兼容性最好
- 设置 MTU 为 9000（巨型帧），提高吞吐量
- 启用流量嗅探，智能分流
- 设置严格的路由规则，防止泄露

---

## 安全加固

### 1. 系统安全加固

```powershell
# 运行安全加固脚本
.\security-hardening.ps1
```

**加固内容：**
- 禁用遥测和数据收集
- 禁用位置服务
- 禁用 Cortana
- 禁用广告 ID
- 禁用活动历史记录
- 加固 Windows 防火墙
- 禁用远程桌面
- 禁用自动登录
- 加固 SMB 协议
- 禁用 PowerShell v2
- 启用 Windows Defender 加强模式
- 加固网络协议
- 配置 DNS over HTTPS
- 禁用 Windows 调试功能
- 加固本地安全策略
- 配置 Windows 事件日志

### 2. 网络安全配置

**防火墙规则：**
- 仅允许 onefcloud 和 onefcloudCore 通过防火墙
- 阻止所有其他入站连接
- 记录被阻止的连接

**DNS 安全：**
- 使用 DNS-over-HTTPS (DoH) 加密 DNS 查询
- 启用 DNSSEC 验证
- 禁用 LLMNR 和 NetBIOS

### 3. 应用安全配置

```json
{
  "tls": {
    "enabled": true,
    "min_version": "1.3",
    "max_version": "1.3",
    "alpn": ["h2", "http/1.1"]
  }
}
```

**安全要点：**
- 强制 TLS 1.3
- 启用完美前向保密 (PFS)
- 使用 Reality 协议伪装流量
- 启用流量混淆

---

## 性能监控

### 1. 健康检查

```powershell
# 单次健康检查
.\health-check.ps1

# 持续监控模式
.\health-check.ps1 -Continuous -Interval 60

# 启用自动恢复
.\health-check.ps1 -Continuous -AutoRecover
```

### 2. 性能指标

| 指标 | 正常范围 | 警告阈值 | 严重阈值 |
|------|----------|----------|----------|
| CPU 使用率 | < 50% | 50-80% | > 80% |
| 内存使用率 | < 70% | 70-90% | > 90% |
| 磁盘使用率 | < 80% | 80-90% | > 90% |
| 网络延迟 | < 50ms | 50-100ms | > 100ms |
| DNS 解析时间 | < 20ms | 20-50ms | > 50ms |

### 3. 日志监控

```powershell
# 查看实时日志
Get-Content "C:\Program Files\onefcloud\logs\sing-box.log" -Tail 50 -Wait

# 搜索错误日志
Select-String -Path "C:\Program Files\onefcloud\logs\sing-box.log" -Pattern "error|Error|ERROR"

# 统计错误数量
(Get-Content "C:\Program Files\onefcloud\logs\sing-box.log" | Select-String "error").Count
```

---

## 故障排除

### 1. 连接问题

**问题：无法连接到代理服务器**

```powershell
# 检查进程状态
Get-Process -Name "onefcloud*", "onefcloudCore*"

# 检查端口监听
netstat -ano | findstr "2080 9090"

# 检查防火墙规则
Get-NetFirewallRule -DisplayName "onefcloud*"

# 测试服务器连接
Test-NetConnection -ComputerName "YOUR_SERVER" -Port 443
```

**解决方案：**
1. 确认 onefcloud 和 onefcloudCore 进程正在运行
2. 检查防火墙是否阻止了连接
3. 验证服务器地址和端口是否正确
4. 检查网络连接是否正常

### 2. DNS 解析问题

**问题：DNS 解析失败**

```powershell
# 清理 DNS 缓存
Clear-DnsClientCache

# 测试 DNS 解析
Resolve-DnsName -Name "www.google.com" -Type A

# 检查 DNS 配置
Get-DnsClientServerAddress
```

**解决方案：**
1. 清理 DNS 缓存
2. 更换 DNS 服务器
3. 检查 DNS 配置是否正确
4. 启用 DNS-over-HTTPS

### 3. 性能问题

**问题：网络速度慢**

```powershell
# 检查系统资源
Get-Process | Sort-Object CPU -Descending | Select-Object -First 10

# 检查网络连接
Get-NetTCPConnection | Group-Object State

# 测试网络速度
speedtest-cli
```

**解决方案：**
1. 关闭不必要的程序
2. 优化代理协议配置
3. 启用 Multiplex 多路复用
4. 使用 Brutal 拥塞控制
5. 更换服务器节点

### 4. 稳定性问题

**问题：频繁断开连接**

```powershell
# 查看错误日志
Select-String -Path "C:\Program Files\onefcloud\logs\sing-box.log" -Pattern "error|disconnect"

# 检查网络稳定性
Test-Connection -ComputerName "YOUR_SERVER" -Count 100
```

**解决方案：**
1. 启用自动重连
2. 使用健康检查脚本监控
3. 启用自动恢复功能
4. 更换更稳定的服务器

---

## 高级配置

### 1. 自定义分流规则

编辑 `config/routing-rules.json`，添加自定义规则：

```json
{
  "direct_domains": {
    "custom": [
      ".example.com",
      ".example.org"
    ]
  },
  "proxy_domains": {
    "custom": [
      ".blocked-site.com"
    ]
  }
}
```

### 2. 多服务器配置

```json
{
  "outbounds": [
    {
      "type": "vless",
      "tag": "proxy-1",
      "server": "server1.example.com",
      "server_port": 443
    },
    {
      "type": "vless",
      "tag": "proxy-2",
      "server": "server2.example.com",
      "server_port": 443
    },
    {
      "type": "urltest",
      "tag": "auto",
      "outbounds": ["proxy-1", "proxy-2"],
      "url": "https://www.gstatic.com/generate_204",
      "interval": "3m",
      "tolerance": 50
    }
  ]
}
```

### 3. 负载均衡

```json
{
  "type": "loadbalance",
  "tag": "balance",
  "outbounds": ["proxy-1", "proxy-2", "proxy-3"],
  "url": "https://www.gstatic.com/generate_204",
  "interval": "3m",
  "strategy": "least_load"
}
```

---

## 更新日志

### v1.0.0 (2024-01-01)
- 初始版本发布
- 支持 VLESS + Reality 协议
- 支持 TUN 模式
- 支持智能分流
- 支持 DNS-over-HTTPS
- 支持 Multiplex 多路复用
- 支持 Brutal 拥塞控制

---

## 技术支持

如有问题，请通过以下方式获取支持：

1. 查看本文档的故障排除章节
2. 运行健康检查脚本诊断问题
3. 查看日志文件获取详细错误信息

---

## 许可证

本软件仅供学习和研究使用，请遵守当地法律法规。
