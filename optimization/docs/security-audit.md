# onefcloud 安全审计清单

> 极致安全 · 全面防护 · 持续监控

## 目录

1. [系统安全](#系统安全)
2. [网络安全](#网络安全)
3. [应用安全](#应用安全)
4. [数据安全](#数据安全)
5. [隐私保护](#隐私保护)
6. [监控审计](#监控审计)
7. [应急响应](#应急响应)

---

## 系统安全

### Windows 系统加固

- [ ] **禁用遥测和数据收集**
  ```powershell
  Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0
  ```

- [ ] **禁用位置服务**
  ```powershell
  Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocation" -Value 1
  ```

- [ ] **禁用 Cortana**
  ```powershell
  Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0
  ```

- [ ] **禁用广告 ID**
  ```powershell
  Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Name "DisabledByGroupPolicy" -Value 1
  ```

- [ ] **禁用活动历史记录**
  ```powershell
  Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Value 0
  ```

- [ ] **禁用远程桌面**
  ```powershell
  Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 1
  ```

- [ ] **禁用自动登录**
  ```powershell
  Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -Value 0
  ```

- [ ] **加固 SMB 协议**
  ```powershell
  Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
  Set-SmbServerConfiguration -EncryptData $true -Force
  ```

- [ ] **禁用 PowerShell v2**
  ```powershell
  Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root -NoRestart
  ```

### Windows Defender 加固

- [ ] **启用实时保护**
  ```powershell
  Set-MpPreference -DisableRealtimeMonitoring $false
  ```

- [ ] **启用云保护**
  ```powershell
  Set-MpPreference -MAPSReporting Advanced
  ```

- [ ] **启用行为监控**
  ```powershell
  Set-MpPreference -DisableBehaviorMonitoring $false
  ```

- [ ] **启用网络保护**
  ```powershell
  Set-MpPreference -EnableNetworkProtection Enabled
  ```

- [ ] **配置排除项**
  ```powershell
  Add-MpPreference -ExclusionPath "C:\Program Files\onefcloud"
  ```

### 本地安全策略

- [ ] **密码策略**
  - 最小密码长度：12 位
  - 密码复杂度：启用
  - 密码历史：24 个
  - 最大密码有效期：90 天

- [ ] **账户锁定策略**
  - 锁定阈值：5 次
  - 锁定时间：30 分钟
  - 重置计数：30 分钟

- [ ] **审核策略**
  - 登录事件：成功/失败
  - 账户管理：成功/失败
  - 策略更改：成功/失败
  - 系统事件：成功/失败

---

## 网络安全

### 防火墙配置

- [ ] **启用所有防火墙配置文件**
  ```powershell
  Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
  ```

- [ ] **设置默认入站规则为阻止**
  ```powershell
  Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Block
  ```

- [ ] **启用日志记录**
  ```powershell
  Set-NetFirewallProfile -Profile Domain,Public,Private -LogBlocked True
  Set-NetFirewallProfile -Profile Domain,Public,Private -LogMaxSizeKilobytes 32767
  ```

- [ ] **配置应用规则**
  - 允许 onefcloud.exe 入站/出站
  - 允许 onefcloudCore.exe 入站/出站
  - 阻止其他所有入站连接

### 网络协议加固

- [ ] **禁用 LLMNR**
  ```powershell
  Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -Value 0
  ```

- [ ] **禁用 NetBIOS**
  ```powershell
  # 设置网络适配器 NetbiosOptions 为 2（禁用）
  ```

- [ ] **禁用 WPAD**
  ```powershell
  Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad" -Name "WpadOverride" -Value 1
  ```

- [ ] **禁用 SMBv1**
  ```powershell
  Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
  ```

### DNS 安全

- [ ] **启用 DNS-over-HTTPS (DoH)**
  ```powershell
  Add-DnsClientDohServerAddress -ServerAddress "1.1.1.1" -DohTemplate "https://1.1.1.1/dns-query"
  Add-DnsClientDohServerAddress -ServerAddress "8.8.8.8" -DohTemplate "https://dns.google/dns-query"
  ```

- [ ] **配置安全 DNS 服务器**
  - 主 DNS：Cloudflare DoH (1.1.1.1)
  - 备用 DNS：Google DoH (8.8.8.8)
  - 国内 DNS：腾讯 DoH (119.29.29.29)

- [ ] **启用 DNSSEC 验证**

- [ ] **禁用 DNS 缓存投毒**

### 网络栈优化

- [ ] **禁用 IP 源路由**
  ```powershell
  Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "DisableIPSourceRouting" -Value 2
  ```

- [ ] **启用 SYN 保护**
  ```powershell
  netsh int tcp set global maxsynretransmissions=2
  ```

- [ ] **设置合理的连接超时**
  ```powershell
  Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TcpTimedWaitDelay" -Value 30
  ```

---

## 应用安全

### TLS/SSL 配置

- [ ] **强制 TLS 1.3**
  ```json
  {
    "tls": {
      "enabled": true,
      "min_version": "1.3",
      "max_version": "1.3"
    }
  }
  ```

- [ ] **启用完美前向保密 (PFS)**
  - 使用 ECDHE 密钥交换
  - 禁用静态 RSA 密钥交换

- [ ] **配置安全的密码套件**
  - TLS_AES_256_GCM_SHA384
  - TLS_CHACHA20_POLY1305_SHA256
  - TLS_AES_128_GCM_SHA256

- [ ] **禁用不安全的协议**
  - SSLv2
  - SSLv3
  - TLS 1.0
  - TLS 1.1

### 代理协议安全

- [ ] **使用 VLESS + Reality 协议**
  - 伪装为正常 HTTPS 流量
  - 使用真实的 TLS 握手
  - 防止协议检测

- [ ] **启用 Multiplex 多路复用**
  - 减少连接数
  - 隐藏流量特征
  - 提高性能

- [ ] **启用流量混淆**
  - 使用 XUDP 数据包编码
  - 启用 Padding 填充
  - 隐藏流量模式

- [ ] **使用安全的认证方式**
  - 使用 UUID 认证
  - 定期更换 UUID
  - 禁用弱密码

### 应用隔离

- [ ] **以普通用户权限运行**
  - 不使用管理员权限
  - 使用标准用户账户

- [ ] **限制文件系统访问**
  - 仅访问必要目录
  - 禁止访问敏感目录

- [ ] **限制网络访问**
  - 仅允许必要端口
  - 禁止不必要的协议

---

## 数据安全

### 配置文件保护

- [ ] **加密敏感配置**
  - UUID
  - 服务器地址
  - 密码
  - 密钥

- [ ] **设置文件权限**
  ```powershell
  # 限制配置文件访问权限
  icacls "config.json" /inheritance:r /grant:r "Users:(R)" /grant:r "Administrators:(F)"
  ```

- [ ] **定期备份配置**
  ```powershell
  # 备份配置文件
  Copy-Item "config.json" "config.json.bak.$(Get-Date -Format 'yyyyMMdd')"
  ```

### 日志安全

- [ ] **配置日志级别**
  ```json
  {
    "log": {
      "level": "warn",
      "output": "logs/sing-box.log",
      "timestamp": true
    }
  }
  ```

- [ ] **限制日志访问**
  - 仅管理员可访问
  - 定期轮转日志
  - 加密敏感日志

- [ ] **日志审计**
  - 定期审查日志
  - 检测异常活动
  - 保留审计日志

### 密钥管理

- [ ] **安全生成密钥**
  ```bash
  # 生成 Reality 密钥对
  sing-box generate reality-keypair
  ```

- [ ] **安全存储密钥**
  - 不在配置文件中明文存储
  - 使用环境变量
  - 使用密钥管理服务

- [ ] **定期轮换密钥**
  - 每 90 天轮换一次
  - 记录密钥使用历史
  - 及时撤销旧密钥

---

## 隐私保护

### 流量隐私

- [ ] **启用流量加密**
  - 使用 TLS 1.3
  - 使用 Reality 协议
  - 启用流量混淆

- [ ] **防止流量分析**
  - 使用 Multiplex 多路复用
  - 启用 Padding 填充
  - 隐藏流量模式

- [ ] **防止 DNS 泄露**
  - 使用 DNS-over-HTTPS
  - 启用 DNS 缓存
  - 禁用系统 DNS

### WebRTC 防护

- [ ] **禁用 WebRTC**
  ```javascript
  // 在浏览器中禁用 WebRTC
  // Chrome: chrome://flags/#disable-webrtc
  // Firefox: about:config -> media.peerconnection.enabled = false
  ```

- [ ] **使用 WebRTC 泄露防护扩展**

### IPv6 泄露防护

- [ ] **配置 IPv6**
  ```json
  {
    "tun": {
      "inet6_address": "fdfe:dcba:9876::1/126"
    }
  }
  ```

- [ ] **禁用 IPv6（如果不需要）**
  ```powershell
  # 禁用 IPv6
  Disable-NetAdapterBinding -Name "*" -ComponentID ms_tcpip6
  ```

### 浏览器隐私

- [ ] **使用隐私浏览器**
  - Firefox（配置隐私设置）
  - Brave
  - Tor Browser

- [ ] **安装隐私扩展**
  - uBlock Origin（广告拦截）
  - Privacy Badger（跟踪防护）
  - HTTPS Everywhere（强制 HTTPS）

- [ ] **配置隐私设置**
  - 禁用第三方 Cookie
  - 禁用位置共享
  - 禁用摄像头/麦克风

---

## 监控审计

### 实时监控

- [ ] **进程监控**
  ```powershell
  # 监控 onefcloud 进程
  Get-Process -Name "onefcloud*" | Select-Object Name, Id, CPU, WorkingSet
  ```

- [ ] **网络监控**
  ```powershell
  # 监控网络连接
  Get-NetTCPConnection | Where-Object {$_.RemotePort -eq 443} | Select-Object LocalPort, RemoteAddress, RemotePort, State
  ```

- [ ] **日志监控**
  ```powershell
  # 监控错误日志
  Get-Content "logs\sing-box.log" -Tail 50 -Wait | Select-String "error|Error|ERROR"
  ```

### 定期审计

- [ ] **系统安全审计**
  ```powershell
  # 运行安全审计脚本
  .\security-hardening.ps1 -DryRun
  ```

- [ ] **网络安全审计**
  ```powershell
  # 检查开放端口
  netstat -ano | findstr "LISTENING"
  
  # 检查防火墙规则
  Get-NetFirewallRule | Where-Object {$_.Enabled -eq "True"} | Select-Object DisplayName, Direction, Action
  ```

- [ ] **应用安全审计**
  ```powershell
  # 检查文件完整性
  Get-FileHash "onefcloud.exe" -Algorithm SHA256
  Get-FileHash "onefcloudCore.exe" -Algorithm SHA256
  ```

### 告警配置

- [ ] **配置日志告警**
  - 错误日志超过阈值
  - 异常连接尝试
  - 配置文件更改

- [ ] **配置性能告警**
  - CPU 使用率 > 80%
  - 内存使用率 > 90%
  - 磁盘使用率 > 90%

- [ ] **配置安全告警**
  - 登录失败次数过多
  - 异常网络连接
  - 配置文件篡改

---

## 应急响应

### 应急预案

#### 1. 检测阶段

- [ ] **识别安全事件**
  - 监控系统日志
  - 检查网络流量
  - 分析异常行为

- [ ] **评估事件影响**
  - 确定受影响范围
  - 评估数据泄露风险
  - 评估业务影响

#### 2. 响应阶段

- [ ] **隔离受影响系统**
  ```powershell
  # 断开网络连接
  Disable-NetAdapter -Name "Ethernet"
  
  # 停止 onefcloud 服务
  Stop-Process -Name "onefcloud*" -Force
  ```

- [ ] **保留证据**
  ```powershell
  # 备份日志文件
  Copy-Item "logs\sing-box.log" "evidence\logs-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
  
  # 备份配置文件
  Copy-Item "config.json" "evidence\config-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
  
  # 导出系统事件日志
  wevtutil epl Security "evidence\security-$(Get-Date -Format 'yyyyMMdd-HHmmss').evtx"
  ```

- [ ] **分析事件原因**
  - 检查日志文件
  - 分析网络流量
  - 检查系统配置

#### 3. 恢复阶段

- [ ] **修复安全漏洞**
  - 更新系统补丁
  - 修复配置错误
  - 加固安全设置

- [ ] **恢复系统服务**
  ```powershell
  # 恢复网络连接
  Enable-NetAdapter -Name "Ethernet"
  
  # 启动 onefcloud 服务
  Start-Process "onefcloud.exe"
  ```

- [ ] **验证系统安全**
  - 运行安全扫描
  - 测试系统功能
  - 监控系统状态

#### 4. 总结阶段

- [ ] **编写事件报告**
  - 事件时间线
  - 影响范围
  - 原因分析
  - 改进措施

- [ ] **更新安全策略**
  - 修复发现的问题
  - 更新安全配置
  - 加强监控告警

- [ ] **培训相关人员**
  - 安全意识培训
  - 应急响应培训
  - 技术能力培训

---

## 安全检查工具

### 系统安全检查

```powershell
# 运行系统安全检查
.\security-hardening.ps1 -DryRun
```

### 网络安全检查

```powershell
# 检查开放端口
netstat -ano | findstr "LISTENING"

# 检查防火墙规则
Get-NetFirewallRule | Where-Object {$_.Enabled -eq "True"}

# 检查网络连接
Get-NetTCPConnection | Select-Object LocalPort, RemoteAddress, RemotePort, State
```

### 应用安全检查

```powershell
# 检查文件完整性
Get-FileHash "onefcloud.exe" -Algorithm SHA256
Get-FileHash "onefcloudCore.exe" -Algorithm SHA256

# 检查进程状态
Get-Process -Name "onefcloud*"

# 检查日志文件
Select-String -Path "logs\sing-box.log" -Pattern "error|Error|ERROR"
```

---

## 安全最佳实践

### 1. 最小权限原则

- 以普通用户权限运行 onefcloud
- 仅授予必要的文件系统权限
- 限制网络访问权限

### 2. 纵深防御

- 系统层安全加固
- 网络层安全防护
- 应用层安全配置
- 数据层安全保护

### 3. 持续监控

- 实时监控系统状态
- 定期安全审计
- 及时响应安全事件

### 4. 定期更新

- 更新系统补丁
- 更新应用程序
- 更新安全配置

### 5. 安全意识

- 定期安全培训
- 遵循安全规范
- 及时报告安全问题

---

## 参考资料

- [Windows 安全基线](https://learn.microsoft.com/en-us/windows/security/threat-protection/windows-security-baselines)
- [CIS Windows 基准](https://www.cisecurity.org/benchmark/microsoft_windows_desktop)
- [NIST 网络安全框架](https://www.nist.gov/cyberframework)
- [OWASP 安全指南](https://owasp.org/www-project-web-security-testing-guide/)

---

## 更新日志

### v1.0.0 (2024-01-01)
- 初始版本发布
- 包含系统安全、网络安全、应用安全、数据安全、隐私保护、监控审计、应急响应等章节
- 提供详细的安全配置和检查清单
- 包含应急响应预案和安全最佳实践
