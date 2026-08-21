# 🚀 程序级优化套件 · 使用指南（30 秒上手）

> 适用：Windows 10/11 · 零依赖（无需安装 Python/Node）· 除 TUN 外均不需要管理员

## 一、拿到文件

任选其一：

```powershell
# 方式 A：git（推荐）
git clone -b arena/01a022ed-onefanyun https://github.com/Me-Is-You/onefanyun.git
cd onefanyun\optimization

# 方式 B：浏览器下载分支 ZIP
#   https://github.com/Me-Is-You/onefanyun/archive/refs/heads/arena/01a022ed-onefanyun.zip
#   解压后进入 onefanyun-arena-01a022ed-onefanyun\optimization
# 方式 C：合并 PR 到 main 后直接拉 main
```

## 二、获取订阅 token

登录一翻云面板（`1flyun.cc` → 用户中心）→ 「我的订阅」→ 复制订阅链接，取其中
`token=` 后面那串（32 位十六进制）。**注意：token 等同账号凭据，不要公开分享。**

## 三、一键运行

双击 **`Program-Optimizer.bat`**，按菜单选择：

| 选项 | 用途 | 说明 |
|------|------|------|
| **[1] 生成优化配置** | 必做第一步 | 粘贴 token，生成 `runtime\optimized-profile.yaml`（72 节点已修复+优化） |
| **[2] 本地修复代理** | 长效方案 | App 订阅地址改成 `http://127.0.0.1:8787/sub`，以后自动更新都是修复版 |
| **[3] 内核直跑** | 立即科学上网 | 用自带 mihomo 内核跑优化配置，系统代理 `127.0.0.1:7890`，看门狗自愈 |
| **[4] TUN 全局** | 全设备级接管 | 需管理员（自动提权），无需设置系统代理 |
| **[5] 系统级优化** | TCP/网络/安全加固 | 管理员，配合 [1]-[4] 使用 |

**推荐组合**：`[1] 生成配置 → [3] 或 [4] 直跑`（完全绕开 App 的订阅 bug）；或
`[1] → [2] 常驻` 继续用原 App 界面。

命令行等价用法：

```powershell
# 生成（多路复用 + DNS 固化全开）
powershell -ExecutionPolicy Bypass -File scripts\profile-optimizer.ps1 -Token <你的token> -EnableMux -PinDns

# 内核直跑（系统代理模式）
powershell -ExecutionPolicy Bypass -File scripts\run-optimized-core.ps1 -Token <你的token>

# 内核直跑（TUN 全局）
powershell -ExecutionPolicy Bypass -File scripts\run-optimized-core.ps1 -Tun -Token <你的token>
```

## 四、成功的样子

菜单 [1] 输出：

```
[+] 节点数: 72
[+] 已应用: FIX-2  香港11 端口 40111 -> 44111
[+] 已应用: FIX-3  清除 3 个节点的 short-id: null（直连德国-02/03/04）
[+] 已应用: SEC-1  allow-lan: true -> false（关闭局域网开放代理）
[+] 已应用: PERF-1..4 ...
[+] 输出: ...\optimization\runtime\optimized-profile.yaml
```

菜单 [3]/[4] 启动后：

```
[+] 配置校验通过
[+] [1] 内核 PID 12345 已启动
[+] 健康探测通过：mixed 端口 7890 就绪
```

浏览器代理设为 `127.0.0.1:7890`（或 TUN 模式无需设置）→ 访问 google 验证。

## 五、常见问题

| 现象 | 处理 |
|------|------|
| SmartScreen 拦截 bat/ps1 | 右键文件 → 属性 → 勾选「解除锁定」；或照上面用 `powershell -ExecutionPolicy Bypass -File` |
| 「订阅拉取失败」 | 检查 token 是否 32 位、本机能否打开面板；机场换域名时改 `-ApiHost` |
| 「上游返回 0 节点」 | 套餐到期/被重置 → 面板续费后重跑 |
| 7890 端口占用 | 关掉正在运行的 onefcloud/其他 Clash，或改配置里 `mixed-port` |
| [2] 启动后 App 不更新 | onefcloud 若锁定订阅地址 → 改用 [1]+文件导入 或 [3]/[4] 直跑 |
| TUN 启动闪退 | 以管理员身份手动运行；确认 Windows 防火墙/杀软未拦 wintun |

## 六、把结果发回来（可选）

跑完菜单 [1] 或 [3] 后，把**控制台完整输出**复制给我，我可以继续针对性调优：
节点延迟排序、分流规则定制、DNS 策略、mux 参数等。
