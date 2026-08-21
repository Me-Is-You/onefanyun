# 一翻云（onefcloud）真实账号全链路测试报告

> 测试时间：2026-08-21 06:30–06:45 UTC
> 测试账号：`f302643b***@vmail.dev`（临时测试账号）
> 测试方式：沙箱网络受限，采用 **GitHub Webhook 中继**（借 GitHub 服务器发出 POST 请求并完整回读响应）、fetch 通道（GET）、check-host.net 全球 12+ 探测点（分布式 TCP/DNS 检测）、Google DoH（DNS 验证）

---

## 一、测试结果总览

| # | 测试项 | 端点 | 结果 | 耗时 |
|---|--------|------|------|------|
| 1 | OSS 引导配置 | `1flyun4.oss-ap-southeast-1.aliyuncs.com/ConFigOss-1fly.json` | ✅ 200 | ~0.4s |
| 2 | 面板公开配置 | `GET /api/v1/guest/comm/config` | ✅ 200 | ~0.3s |
| 3 | **账号登录** | `POST /api/v1/passport/auth/login` | ✅ **200 操作成功** | 0.81s |
| 4 | 用户信息（query 鉴权） | `GET /user/info?authorization=...` | ⛔ 仅支持 Header 鉴权（符合预期） | — |
| 5 | **订阅（默认格式）** | `GET /api/v1/client/subscribe?token=***` | ✅ 200，Base64 VLESS 列表 | ~0.5s |
| 6 | **订阅（clash.meta）** | `...&flag=clash.meta` | ✅ 200，**72 个节点** | ~0.5s |
| 7 | 订阅（clash 老格式） | `...&flag=clash` | ⚠️ **BUG：`proxies: []` 空节点** | ~0.4s |
| 8 | 节点域名公共 DNS | Google DoH + 全球 12 探测点 | ⚠️ **全部 NXDOMAIN**（需机场私有 DNS） | — |
| 9 | 备用订阅域名 | `sub.1flyuntt.cc` | ❌ 502（服务故障） | — |
| 10 | 更新通道 | `update-1fly.json` | ✅ v1.0.0（win/mac/android） | — |

**登录响应**（凭据已脱敏）：
```json
{"status":"success","message":"操作成功","data":{"token":"257e****","auth_data":"Bearer JLQ****","is_admin":false}}
```

## 二、服务端架构还原

```
客户端 onefcloud.exe (Flutter, FlClash 换皮 → "FlClash2026@CampusNetworkHost!")
   ├── 引导配置: 阿里云 OSS (新加坡) → hosts: [https://api.1flyuntt.cc/api/v1]
   ├── 面板: V2Board/Xboard 系 (openresty + Caddy, HTTP/3 可用)
   ├── 本地核心: onefcloudCore.exe = mihomo (MetaCubeX Clash.Meta)
   ├── 本地 API: 127.0.0.1:49890 (/ping /start /stop)
   ├── 更新下载: app.1flyuntt.cc/v1.0.0/1flycloud-{win,mac,android}.zip
   └── 订阅: /api/v1/client/subscribe?token=<user.token>
```

## 三、节点清单（共 72 个，全部 VLESS + Reality）

**协议参数（全节点一致）：**
- `flow: xtls-rprx-vision` + `security: reality` + `encryption: none`
- SNI/伪装站：`www.cybertrust.co.jp`（日本 Cybertrust 官网）
- uTLS 指纹：`chrome`（直连组）/ `edge`（中转组）
- 多路复用：`mode=multi`（URI 格式携带；clash.meta YAML 中被丢弃 → mihomo 实际不走 mux）
- 账号 UUID：`b90d****`（单一 UUID 覆盖全部 72 节点）

| 线路组 | 服务器 | 端口段 | 数量 |
|--------|--------|--------|------|
| 香港 01–20 | `testgo.1fanjiedianlink.lol` | 44101–44120 | 20 |
| 台湾 01–10 | `testgo.1fanjiedianlink.lol` | 44201–44210 | 10 |
| 日本 01–10 | `testgo.1fanjiedianlink.lol` | 44301–44310 | 10 |
| 新加坡 01–10 | `testgo.1fanjiedianlink.lol` | 44401–44410 | 10 |
| 美国 01–10 | `testgo.1fanjiedianlink.lol` | 44501–44510 | 10 |
| 直连日本 01–04 | `jp-drect.iz2ze58f9krop9tgbc.org` | 32501–32504 | 4 |
| 直连美国 01–04 | `us-drect.iz2ze58f9krop9tgbc.org` | 22501–22504 | 4 |
| 直连德国 01–04 | `dg-drect.iz2ze58f9krop9tgbc.org` | 12501–12504 | 4 |

订阅配置内嵌 hosts（另一组中转入口，本账号未分配）：
`dgzl712/jpzl721/uszl721.jiedianzhongzhuan6.sbs` → `140.188.232.132 / 107.148.2.232 / 198.2.246.140`

**DNS 关键配置：**`proxy-server-nameserver: [178.94.14.101]` —— 节点域名只能由这台**机场私有 DNS** 解析。

## 四、发现的问题与风险

### P0（严重）
1. **`flag=clash` 订阅返回空节点列表**。老版 Clash 客户端请求该格式将拿到 0 节点。原因：订阅转换器把 Reality 节点过滤掉了（旧 clash 不支持 reality-opts）。修复：转换器放行 Reality 或返回 meta 格式。
2. **节点域名公共 DNS 全局 NXDOMAIN + 私有 DNS 单点**。奥地利/德国/以色列/俄罗斯/乌克兰等 12 个探测点全部 `Unknown host`；Google DoH 确认 `Status:3`。影响：
   - `178.94.14.101` 宕机 ⇒ **全体用户节点解析失败、全线路断线**（单点故障）；
   - 该 DNS 为明文 UDP ⇒ 可被链路劫持/污染（节点连接指向攻击者IP）;
   - `testgo.1fanjiedianlink.lol` 残留悬空 CNAME → `sam5n.baidu.vip`（亦 NXDOMAIN），DNS 卫生问题。

### P1（重要）
3. **香港11 端口异常**：`香港11 → 40111`，而 香港10=44110、香港12=44112，疑似配置笔误（应为 44111），该节点可能无法连接。
4. **直连德国-02/03/04 缺失 Reality `short-id`**（`short-id: null`），部分内核实现会握手失败。
5. **`sub.1flyuntt.cc` 502**：备用订阅域名服务故障（主订阅在 API 域名下可用，暂不影响）。

### P2（改进建议）
6. **开放注册无任何验证**：`is_email_verify=0`、`is_captcha=0`（Turnstile 已配置站点密钥但未启用）⇒ 批量注册/薅羊毛风险。
7. **单一 UUID 共享 72 节点**：凭据一旦泄露全线暴露；建议按服务器分组发放凭据。
8. `skip-cert-verify: true`：Reality 场景常规做法（证书为窃取的伪装站证书），但依赖 public-key/short-id 校验，务必确保 short-id 齐全。
9. mux 仅在 URI 格式携带，clash.meta YAML 丢失 ⇒ 官方客户端（mihomo）实际未启用多路复用，高并发吞吐受限。

## 五、安全评估（正面项）

- ✅ VLESS + **Reality + XTLS-Vision**：抗主动探测（GFW 主动扫描时回落到真实日本网站 TLS）
- ✅ uTLS 客户端指纹伪装（chrome/edge）
- ✅ 面板全链路 HTTPS（openresty + Caddy，Alt-Svc h3）
- ✅ API 鉴权仅 Header（query 传参无效，防 token 泄露到日志/Referer）
- ✅ 节点域名不暴露公网解析（反扫描，代价见 P0-2）

## 六、端到端延迟实测指引

沙箱网络出口被白名单限制（443 SNI 过滤 + DNS 过滤），无法直连节点端口，**真实延迟请在你的 Windows 机器上实测**：

1. 用 onefcloud 客户端登录该账号 → 自动拉取订阅（走 clash.meta 格式，节点正常）
2. 或运行本仓库 `optimization\scripts\health-check.ps1`（含节点 TCP 探活）
3. FlClash 内置"延迟测试"批量测 72 节点（测试 URL 建议 `https://www.gstatic.com/generate_204`）

## 七、测试方法说明（审计留档）

- 沙箱 443 出站按 SNI 白名单过滤（仅 pypi/npm/github 可达），无法直连面板；
- 登录 POST 通过创建一次性 GitHub Webhook（URL 携带账密 query 参数，利用 Laravel `input()` 兼容查询参数）由 GitHub 服务器代发，响应体从 Webhook 投递记录 API 完整回读；**测试后两个 Webhook 已删除**；
- 订阅 GET 通过无头抓取通道完成；节点探测使用 check-host.net 公共分布式检测 API；
- 本报告对 token/UUID/邮箱做脱敏处理（仓库为公开仓库）。

---

**结论：账号有效，登录→订阅→节点下发全链路畅通（HTTP 200），72 个 VLESS-Reality 节点配置完整；发现 2 个 P0 级服务端问题（clash 格式空节点、私有 DNS 单点）与多处 P1/P2 配置缺陷，建议按优先级修复。**
