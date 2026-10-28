# OpenClaw on Termux

在 Android 的 Termux 环境安装、更新和管理 OpenClaw Gateway。

[English](README.en.md) · [OpenClaw 上游](https://github.com/openclaw/openclaw) · [报告问题](https://github.com/qq892601987/install-openclaw-on-termux/issues)

![OpenClaw on Termux Preview](./sources/OpenClaw-on-Termux-Preview.png)

## 兼容性与限制

本次更新对照 OpenClaw **2026.10.8** 的发布契约；**尚未完成 Android/Termux 真机验收**，不代表该版本的所有功能已经适配。

- OpenClaw 2026.10.8 要求 Node.js **`>=24.22.1 <25 || >=26.12.1`**。其他版本以该版本 npm 包的 `engines.node` 为准，不能只检查“Node ≥22”或主版本号。
- 安装器默认将 npm `latest` 解析为一个具体版本，再读取并检查该版本的 Node 要求。需要可重复安装时，请使用 `--version` 指定准确版本。
- 原生 Termux 使用 Android/Bionic；Linux 原生模块不一定能用。脚本不再用假的 koffi、LanceDB 或剪贴板模块掩盖不支持的功能，也不强制绕过平台检查。
- **原生安装遇到平台或原生模块错误时，优先尝试下方 proot Ubuntu 方案。** proot 提供 Linux 用户空间，但仍受 Android 后台管理、内存和系统调用限制，不等于完整 Linux 主机。
- Gateway 的 HTTP `/healthz` 就绪检查只证明服务响应，不证明模型凭据、消息渠道、向量库、浏览器或剪贴板功能可用。安装后还需配置并测试实际使用的功能。

## 选择安装入口

| 脚本 | 用途 |
| --- | --- |
| `install-openclaw-termux.sh` | 原生 Termux，中文交互 |
| `install-openclaw-termux_En.sh` | 原生 Termux，英文交互 |
| `install-openclaw-termux-v2.sh` | 分阶段原生安装器，额外支持 `--yes`、`--list-versions`、端口和自启动选项 |
| `install_openclaw_termux_proot.sh` | 在 Termux 的 proot Ubuntu 内安装；与原生安装使用不同的用户目录和运行环境 |

请从可信来源安装最新 Termux（例如 F-Droid），准备稳定网络和足够的存储空间。依赖包、npm 下载及原生模块可能占用较多空间；旧版文档的“500MB 足够”不作为容量保证。

### 默认系统依赖

| 安装环境 | 显式安装的系统包 |
| --- | --- |
| 原生 Termux（三个原生脚本） | `nodejs-lts`、`git`、`openssh`、`tmux`、`termux-tools`、`curl` |
| proot 的 Termux 外层 | `proot-distro`、`curl` |
| proot 的 Ubuntu 内层 | `curl`、`build-essential`、`git`、`ca-certificates`、`python3` |

原生安装不再强制安装 `cmake`、`python`、`golang`、`which`、`clang`、`ninja`、`pkg-config`、`build-essential` 和 `termux-api`。唤醒锁命令属于 [termux-tools](https://github.com/termux/termux-tools/blob/master/scripts/termux-wake-lock.in)，无需为唤醒锁安装 Termux:API。需要额外技能或设备 API 时，再按实际功能安装所需工具。

proot 不再预装 `wget`、`nano`、`python3-pip`、`gnupg` 和 `lsb-release`，但保留基础编译工具与 Python，以支持正常 npm 生命周期中的原生模块编译后备。系统包管理器仍会安装这些包自身的传递依赖。本次仅精简安装清单，不卸载设备上已存在的软件包，也不修改 OpenClaw 发布包声明的 npm 依赖。

### 原生 Termux

直接使用本仓库地址，避免短链接指向旧脚本：

```bash
curl -fLsS https://raw.githubusercontent.com/qq892601987/install-openclaw-on-termux/main/install-openclaw-termux.sh -o openclaw-install.sh
bash openclaw-install.sh
source ~/.bashrc
```

也可以下载后先检查脚本，再运行。不要在下载失败后继续执行之前残留的文件。

```bash
git clone https://github.com/qq892601987/install-openclaw-on-termux.git
cd install-openclaw-on-termux
bash install-openclaw-termux.sh --help
bash install-openclaw-termux.sh
source ~/.bashrc
```

脚本会修改 npm 全局前缀、registry 和 `~/.bashrc`，并安装系统依赖。运行前备份自己的环境配置。推荐使用 `bash` 执行，完成后再加载 `~/.bashrc`；仍保留 `source` 调用方式。

### proot Ubuntu

```bash
curl -fLsS https://raw.githubusercontent.com/qq892601987/install-openclaw-on-termux/main/install_openclaw_termux_proot.sh -o openclaw-proot.sh
bash openclaw-proot.sh --help
bash openclaw-proot.sh --version 2026.10.8
```

此方案会安装或复用 Ubuntu、配置 apt 镜像和 nvm，并安装 Node 24 的最新维护版本；运行时仍须满足所选 OpenClaw 的完整版本范围。如果不满足，安装器停止并给出错误，不把 Node 24 一概视为兼容。该方案会更新 Ubuntu 软件包，请先备份已有 Ubuntu 环境。

如果目标版本需要其他受支持的 Node LTS 主版本，可显式选择，例如 `OPENCLAW_NODE_VERSION=26 bash openclaw-proot.sh --version 2026.10.8`；安装器仍检查完整版本范围。

## 安装与更新选项

以下选项适用于中文、英文原生脚本；v2 的额外选项请查看其 `--help`。

| 选项 | 说明 |
| --- | --- |
| `--help`, `-h` | 显示帮助 |
| `--verbose`, `-v` | 详细输出 |
| `--dry-run`, `-d` | 查看计划，不执行安装、配置写入或服务启动；不代表真实安装一定成功 |
| `--version`, `-V <version>` | 安装指定版本，包括降级；不会再自动调用 `openclaw update` 改成其他版本 |
| `--update`, `-U` | 不询问是否更新软件包；其他配置仍可能需要交互 |
| `--uninstall`, `-u` | 卸载并清理脚本管理的配置；执行前先备份 |

```bash
# 指定版本；版本号仅作为示例，不代表已经真机验证
bash install-openclaw-termux.sh --version 2026.10.8

# 更新到运行时查询得到的 latest
bash install-openclaw-termux.sh --update

# 预览
bash install-openclaw-termux.sh --dry-run

# v2 非交互安装
bash install-openclaw-termux-v2.sh --yes --version 2026.10.8
```

原生安装为避免 Android 不支持的依赖编译，先跳过 npm 自动生命周期，再显式执行 OpenClaw 包自身的 postinstall（如果存在）。这**不代表所有原生依赖已完成构建**；需要原生功能时仍须单独验证，失败应查看错误或改用 proot。proot 使用正常 npm 安装生命周期。

安装器使用 npm 提供的 `semver` 工具检查完整版本范围，因此需要能访问 npm registry。无法取得版本或运行时要求时会停止，不在信息缺失时猜测兼容性。

## 配置和服务管理

- 默认端口：`18789`。
- 默认仅绑定 loopback；在**同一手机**打开 `http://127.0.0.1:18789/`，按 Gateway 提示配置认证。
- 不要直接将端口暴露到公网。局域网访问需要另行配置绑定地址、认证与安全访问方式。
- 原生脚本的配置和快捷命令写入 `~/.bashrc`；v2 还使用 `~/.config/openclaw/env.sh`。
- 配置文件中可能包含访问 Token，不要公开文件、截图、日志或带 Token 的网址。

原生脚本的服务命令：

```bash
source ~/.bashrc
ocr       # 启动/重启，并等待 HTTP 就绪检查
oclog     # 查看 tmux 会话输出
ockill    # 停止服务
```

日志通常位于 `~/openclaw-logs/`；proot 部署日志位于 Termux 的 `~/deploy_openclaw_proot.log`。proot 内的 OpenClaw 配置和命令位于 Ubuntu 用户环境，不能把 Termux 外层的 npm 包当作同一个安装。

## 安装后检查与故障排除

在实际安装 OpenClaw 的环境中执行：

```bash
node --version
openclaw --version
openclaw doctor
openclaw gateway --help
curl --fail --silent --show-error http://127.0.0.1:18789/healthz
```

然后配置模型和渠道，完成一次实际模型请求。不要仅以 npm 安装成功、tmux 会话存在或 HTTP 健康检查成功判断所有功能正常。

| 问题 | 处理 |
| --- | --- |
| Node 版本不满足 `engines.node` | 原生环境更新 Termux 包列表和 Node 包；proot 更新其 nvm Node。重新检查完整版本，不要使用 `--force` 掩盖错误。 |
| `EBADPLATFORM`、原生库加载或编译失败 | 保留错误信息，尝试 proot；不要手动写入空模块伪装修复。 |
| 缺少官方启动文件或构建产物 | 重新安装对应的 npm 发布包；不要在不完整的全局包目录中尝试 `tsc` 构建。 |
| Gateway 健康检查超时 | 查看 `~/openclaw-logs/runtime.log`、端口占用及 `openclaw doctor` 输出。服务不会因为 tmux 存在就被判为成功。 |
| 后台运行中断 | 关闭 Android 对 Termux 的电池优化，检查后台权限及唤醒锁。tmux 和唤醒锁不能保证系统永不杀进程。 |

不要使用 `pkill -9 node`，它会杀死其他 Node 服务。`openclaw doctor` 可能提出配置修复，执行修复前备份状态目录。

## 备份与卸载

升级或降级前备份实际运行环境中的 `~/.openclaw`、shell 配置和自己的工作目录。新版可能迁移状态；只降级 npm 包不保证旧版还能读取迁移后的状态。备份文件包含凭据，应私密保存。

```bash
# 在原生环境或 Ubuntu 内分别执行，按实际位置备份
cp -a ~/.openclaw ~/.openclaw.backup-$(date +%Y%m%d-%H%M%S)

# 原生卸载
bash install-openclaw-termux.sh --uninstall
```

旧版原生卸载流程会删除 `~/.npm-global`，该目录可能还包含其他全局包；若有其他工具，请勿直接执行该卸载选项，先自行备份并逐项清理。proot 的移除应与原生安装分别处理，不要误删正在使用的 Ubuntu。

## 更新记录

### 2026-10-28：新版 OpenClaw 兼容性更新

- 精简原生/Ubuntu 默认依赖，移除原生安装的旧 GYP 配置写入；按实际命令检测 OpenSSH 和唤醒锁，避免重复安装已存在的包。

- 按所选 npm 发布版本检查完整 Node 版本范围，解析具体版本后安装。
- 使用官方 `openclaw.mjs` 入口，安全替换命令包装器，避免写穿 npm 符号链接。
- 移除把自动更新当作构建的步骤和不完整 npm 包的源码构建回退。
- 移除假的原生模块替换和额外的全局渠道 SDK 安装；不绕过平台检查。
- 原生启动使用有界 HTTP 健康检查，proot 不再固定安装 Node 22。
- 同步安装入口、功能限制和验证说明；本地验证不代替 Android 真机验收。

## 本地回归检查

本次在 macOS arm64 / Node 26.12.1 上通过：四个脚本的语法检查、33 个 CLI 安全场景、实际 npm 指定版本安装与 postinstall、三个原生入口的包装器和 HTTP 就绪/超时路径。真实 OpenClaw 2026.10.8 Gateway 的 `/healthz` 返回 `{"ok":true,"status":"live"}`。服务管理命令在隔离环境中验证，未验证 Android 的 pkg、tmux、proot 或实际模型调用。

依赖精简另在隔离的最小 PATH 下执行三个原生安装器的依赖检查：无编译工具、Python、Go、`which` 或 Termux:API 时均通过，且不触发补包；旧版同场景会误判缺包。v2 实际 npm/git 配置也通过，未创建 `.gyp`。

```bash
python3 -m unittest discover -s tests -v
for script in *.sh; do bash -n "$script" || break; done
```

CLI 回归检查覆盖帮助、错误参数和 dry-run 不修改用户目录的安全边界，不代替真机安装和模型请求验证。

## 反馈

请在 [Issues](https://github.com/qq892601987/install-openclaw-on-termux/issues) 提供所用脚本、Android/Termux 版本、架构、Node/OpenClaw 版本、复现命令和已脱敏的错误日志。
