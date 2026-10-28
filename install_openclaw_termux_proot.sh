#!/usr/bin/env bash
set -euo pipefail

REQUESTED_VERSION="latest"
OPENCLAW_VERSION_PATTERN='^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$'
NODE_SELECTOR_PATTERN='^[0-9]+(\.[0-9]+){0,2}$'
while [ "$#" -gt 0 ]; do
  case "$1" in
    --version|-V)
      if [ "$#" -lt 2 ] || [ -z "$2" ]; then
        echo "用法: $0 [--version|-V 版本号]" >&2
        exit 1
      fi
      if [[ ! "$2" =~ $OPENCLAW_VERSION_PATTERN ]]; then
        echo "错误：--version 必须是完整 npm 版本号，例如 2026.10.8。" >&2
        exit 1
      fi
      REQUESTED_VERSION="$2"
      shift 2
      ;;
    --help|-h)
      echo "用法: $0 [--version|-V 版本号]"
      echo "默认安装 npm 最新版；指定版本时须使用完整版本号。可设置 OPENCLAW_NODE_VERSION 选择 Ubuntu proot 内的 Node.js LTS（默认 24）。"
      exit 0
      ;;
    *)
      echo "未知参数: $1；用法: $0 [--version|-V 版本号]" >&2
      exit 1
      ;;
  esac
done
OPENCLAW_NODE_VERSION="${OPENCLAW_NODE_VERSION:-24}"
if [[ ! "$OPENCLAW_NODE_VERSION" =~ $NODE_SELECTOR_PATTERN ]]; then
  echo "错误：OPENCLAW_NODE_VERSION 必须是 Node.js LTS 数字版本，例如 24 或 26.12.1。" >&2
  exit 1
fi
NODE_MAJOR="${OPENCLAW_NODE_VERSION%%.*}"
if (( 10#$NODE_MAJOR < 24 || 10#$NODE_MAJOR % 2 != 0 )); then
  echo "错误：OPENCLAW_NODE_VERSION 须选择 24 或更新的偶数版 Node.js LTS。" >&2
  exit 1
fi
if [ -z "${PREFIX:-}" ] || [ ! -x "$PREFIX/bin/pkg" ]; then
  echo "错误：请在原生 Termux 中运行此脚本（需要有效的 PREFIX/bin/pkg）；不要在 Ubuntu proot 或普通 Linux/macOS 中运行。" >&2
  exit 1
fi

LOGFILE="$HOME/deploy_openclaw_proot.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "开始部署：$(date)"

# 0. Termux 存储授权提示（需要用户手动授权）
echo "如果尚未授权 Termux 存储，请在新终端运行: termux-setup-storage 并授权后再运行本脚本。"
# 不自动调用 termux-setup-storage 以避免非交互阻塞

termux_apt_noninteractive() {
  DEBIAN_FRONTEND=noninteractive apt-get \
    -o Dpkg::Options::=--force-confdef \
    -o Dpkg::Options::=--force-confold \
    "$@"
}

# 1. 更新 Termux 包
echo "1. 更新 Termux 包"
dpkg --force-confdef --force-confold --configure -a
termux_apt_noninteractive update
# 避免在 `curl | bash` 过程中升级当前正在运行的 bash，
# 这会触发 bash.bashrc 交互式 conffile 提示，并可能打断后续脚本执行。
termux_apt_noninteractive install -y proot-distro curl

# 2. 安装 Ubuntu（自动决定可用发行版，不要求用户选择版本）
echo "2. 安装并准备 proot-distro 的 Ubuntu"

# 检查已安装的发行版（不同版本 proot-distro 的安装目录可能不同）
INSTALLED_NAMES=""
for installed_rootfs_dir in \
  "$PREFIX/var/lib/proot-distro/installed-rootfs" \
  "$HOME/.proot-distro/installed-rootfs"
do
  if [ -d "$installed_rootfs_dir" ]; then
    INSTALLED_NAMES=$(ls -1 "$installed_rootfs_dir" 2>/dev/null || true)
    break
  fi
done

# 优先复用已安装的 Ubuntu 发行版
DISTRO=""
for candidate in ubuntu ubuntu-24.04 ubuntu-22.04 ubuntu-20.04; do
  if printf '%s\n' "$INSTALLED_NAMES" | grep -qx "$candidate"; then
    DISTRO="$candidate"
    break
  fi
done

if [ -n "$DISTRO" ]; then
  echo "检测到已安装 Ubuntu 发行版: $DISTRO，跳过安装步骤"
else
  AVAILABLE=$(proot-distro list 2>/dev/null || true)
  AVAILABLE_NAMES=$(printf '%s\n' "$AVAILABLE" | sed -n 's/.*< *\([^>]*\) *>.*/\1/p' | sed 's/[[:space:]]*$//')

  # 优先使用通用 ubuntu，只有在其不可用时才自动回退到版本化条目
  for candidate in ubuntu ubuntu-24.04 ubuntu-22.04 ubuntu-20.04; do
    if printf '%s\n' "$AVAILABLE_NAMES" | grep -qx "$candidate"; then
      DISTRO="$candidate"
      break
    fi
  done

  if [ -z "$DISTRO" ]; then
    DISTRO="ubuntu"
  fi

  echo "自动使用 Ubuntu 发行版: $DISTRO"
  if ! proot-distro install "$DISTRO"; then
    if [ "$DISTRO" != "ubuntu" ]; then
      echo "安装 $DISTRO 失败，尝试回退到 ubuntu..."
      DISTRO="ubuntu"
      proot-distro install "$DISTRO" || echo "Ubuntu 可能已安装，继续..."
    else
      echo "安装 ubuntu 失败，继续尝试后续步骤..."
    fi
  fi
fi

# 3. 进入 Ubuntu 并执行后续命令（在 proot 内部执行）
OPENCLAW_TERMUX_DISTRO="$DISTRO" proot-distro login "$DISTRO" -- bash -s -- "$REQUESTED_VERSION" "$OPENCLAW_NODE_VERSION" <<'PROOT_BASH'
set -euo pipefail
REQUESTED_VERSION="$1"
NODE_SELECTOR="$2"
echo "进入 proot-distro: $(date)"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

if ! [ -t 1 ] || [ "$(tput colors 2>/dev/null || echo 0)" -lt 8 ]; then
  GREEN=''
  BLUE=''
  YELLOW=''
  RED=''
  CYAN=''
  NC=''
fi

DISTRO_NAME="${OPENCLAW_TERMUX_DISTRO:-ubuntu}"

# 3.1 备份并替换 Ubuntu 源（根据发行版动态配置）
if [ -f /etc/apt/sources.list ]; then
  cp /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%s)
fi
# 检测当前 Ubuntu 版本代号（优先从 os-release 读取）
CODENAME=$(grep -oP 'VERSION_CODENAME=\K.*' /etc/os-release 2>/dev/null || grep -oP 'UBUNTU_CODENAME=\K.*' /etc/os-release 2>/dev/null || lsb_release -cs 2>/dev/null || echo "jammy")
echo "检测到 Ubuntu 代号: $CODENAME"

# 检测当前架构
ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
echo "检测到架构: $ARCH"

# 根据架构和版本选择源（优先使用 HTTPS，并用 apt-get update 实测可用性）
if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
  echo "arm64 架构，探测可用的 ubuntu-ports HTTPS 镜像"
  MIRROR_CANDIDATES=(
    "https://mirrors.ustc.edu.cn/ubuntu-ports"
    "https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports"
    "https://ports.ubuntu.com/ubuntu-ports"
  )
else
  echo "$ARCH 架构，探测可用的 Ubuntu HTTPS 镜像"
  MIRROR_CANDIDATES=(
    "https://mirrors.ustc.edu.cn/ubuntu"
    "https://mirrors.tuna.tsinghua.edu.cn/ubuntu"
    "https://archive.ubuntu.com/ubuntu"
  )
fi

write_sources_list() {
  local mirror_url="$1"
  cat > /etc/apt/sources.list <<OPENCLAW_SOURCES_LIST_EOF
deb $mirror_url $CODENAME main restricted universe multiverse
deb $mirror_url $CODENAME-updates main restricted universe multiverse
deb $mirror_url $CODENAME-backports main restricted universe multiverse
deb $mirror_url $CODENAME-security main restricted universe multiverse
OPENCLAW_SOURCES_LIST_EOF
}

apt_update_cleanly() {
  local log_file="$1"
  if DEBIAN_FRONTEND=noninteractive apt-get update 2>&1 | tee "$log_file"; then
    if ! grep -Eiq 'Failed to fetch|Unable to connect|Could not connect|Some index files failed to download' "$log_file"; then
      return 0
    fi
  fi
  return 1
}

MIRROR_URL=""
for candidate in "${MIRROR_CANDIDATES[@]}"; do
  TEST_URL="$candidate/dists/$CODENAME/main/binary-$ARCH/Packages.gz"
  echo "测试镜像: $TEST_URL"
  write_sources_list "$candidate"
  APT_UPDATE_LOG="$(mktemp)"
  if apt_update_cleanly "$APT_UPDATE_LOG"; then
    MIRROR_URL="$candidate"
    echo "使用镜像: $MIRROR_URL"
    rm -f "$APT_UPDATE_LOG"
    break
  fi
  echo "镜像不可用，尝试下一个: $candidate"
  rm -f "$APT_UPDATE_LOG"
done

if [ -z "$MIRROR_URL" ]; then
  if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
    MIRROR_URL="https://ports.ubuntu.com/ubuntu-ports"
  else
    MIRROR_URL="https://archive.ubuntu.com/ubuntu"
  fi
  echo "警告：镜像探测失败，回退到: $MIRROR_URL"
fi

# 写入最终选定的源，并再次刷新索引
write_sources_list "$MIRROR_URL"
FINAL_APT_UPDATE_LOG="$(mktemp)"
if ! apt_update_cleanly "$FINAL_APT_UPDATE_LOG"; then
  echo "错误：最终 apt-get update 失败，无法继续安装依赖。"
  cat "$FINAL_APT_UPDATE_LOG"
  rm -f "$FINAL_APT_UPDATE_LOG"
  exit 1
fi
rm -f "$FINAL_APT_UPDATE_LOG"
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# 4. 保留 npm 原生模块的编译后备；不预装编辑器和无关 Python 工具。
DEBIAN_FRONTEND=noninteractive apt-get install -y curl build-essential git ca-certificates python3

# 5. 在 Ubuntu proot 内安装所选 Node.js LTS（默认 24）
export NVM_DIR="$HOME/.nvm"
install_nvm() {
  echo "安装/重装 nvm..."
  rm -rf "$NVM_DIR"
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | PROFILE=/dev/null bash
}

load_nvm() {
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] || return 1
  unset -f nvm 2>/dev/null || true
  . "$NVM_DIR/nvm.sh"
  command -v nvm >/dev/null 2>&1
}

if ! load_nvm; then
  echo "检测到 nvm 不可用，尝试重新安装..."
  install_nvm
  load_nvm || { echo "错误：nvm 安装/加载失败，nvm 仍不可用"; exit 1; }
fi

# OpenClaw 新版要求较新的 Node；具体要求还须按目标包元数据核对。
if ! nvm install "$NODE_SELECTOR" || ! nvm use "$NODE_SELECTOR"; then
  echo "错误：Ubuntu proot 内无法安装 Node.js ${NODE_SELECTOR}。请检查架构、网络与 nvm 输出；可设 OPENCLAW_NODE_VERSION 为符合目标版本要求的 LTS 版本，勿在原生 Termux 内安装 Linux nvm。" >&2
  exit 1
fi
nvm alias default "$NODE_SELECTOR"
NODE_VERSION="$(node --version)"
if [ -z "$NODE_VERSION" ] || ! command -v npm >/dev/null 2>&1; then
  echo "错误：Ubuntu proot 内缺少可用的 Node.js/npm，请检查 nvm 安装。" >&2
  exit 1
fi
if ! TARGET_VERSION="$(npm view "openclaw@$REQUESTED_VERSION" version 2>/dev/null)" || [ -z "$TARGET_VERSION" ]; then
  echo "错误：无法从 npm 查询 openclaw@$REQUESTED_VERSION 的具体版本；请检查网络和版本号。" >&2
  exit 1
fi
if [[ ! "$TARGET_VERSION" =~ $OPENCLAW_VERSION_PATTERN ]] ||
   { [ "$REQUESTED_VERSION" != latest ] && [ "$TARGET_VERSION" != "$REQUESTED_VERSION" ]; }; then
  echo "错误：npm 返回的 OpenClaw 版本无效或与指定版本不符: $TARGET_VERSION" >&2
  exit 1
fi
if ! ENGINE_RANGE="$(npm view "openclaw@$TARGET_VERSION" engines.node 2>/dev/null)" || [ -z "$ENGINE_RANGE" ]; then
  echo "错误：无法读取 openclaw@$TARGET_VERSION 的 engines.node 要求，停止安装。" >&2
  exit 1
fi
if ! npm exec --yes --package=semver@7 -- semver -r "$ENGINE_RANGE" "$NODE_VERSION" >/dev/null; then
  echo "错误：Node $NODE_VERSION 不满足 openclaw@$TARGET_VERSION 的要求 ($ENGINE_RANGE)，或无法验证版本。请设置 OPENCLAW_NODE_VERSION 为符合要求的 Ubuntu proot 内 Node.js LTS 版本后重试。" >&2
  exit 1
fi
echo "安装 openclaw@${TARGET_VERSION}（Node ${NODE_VERSION}，要求 ${ENGINE_RANGE}）"
# 仅清理本脚本曾写入的 proot 包装器，避免 npm 安装时 EEXIST；
# 旧版包装器没有标记时须同时识别其 shim 和指向 openclaw 的 exec。
is_managed_proot_wrapper() {
  local file="$1"
  [ -f "$file" ] && [ ! -L "$file" ] &&
    [ "$(IFS= read -r first_line < "$file"; printf '%s' "$first_line")" = '#!/usr/bin/env bash' ] &&
    { grep -q 'OPENCLAW_PROOT_WRAPPER' "$file" ||
      { grep -Fq '/.openclaw/hijack.js' "$file" &&
        grep -Eq '^exec "[^"]*openclaw(\.proot-real|\.mjs)?" "\$@"$' "$file"; }; }
}
EXISTING_OPENCLAW_BIN="$(dirname "$(command -v node)")/openclaw"
if is_managed_proot_wrapper "$EXISTING_OPENCLAW_BIN"; then
  rm -f "$EXISTING_OPENCLAW_BIN"
fi
NODE_EXE="$(command -v node)"
NODE_BIN_DIR="$(dirname "$(command -v node)")"

# 让后续登录 shell 也能直接使用 node/npm/openclaw
mkdir -p /etc/profile.d
cat > /etc/profile.d/openclaw-nvm.sh <<OPENCLAW_NVM_PROFILE_EOF
export NVM_DIR="\$HOME/.nvm"
if [ -s "\$NVM_DIR/nvm.sh" ]; then
  . "\$NVM_DIR/nvm.sh" >/dev/null 2>&1 || true
fi
case ":\$PATH:" in
  *:"$NODE_BIN_DIR":*) ;;
  *) export PATH="$NODE_BIN_DIR:\$PATH" ;;
esac
OPENCLAW_NVM_PROFILE_EOF
chmod 644 /etc/profile.d/openclaw-nvm.sh

# 6. 安装 OpenClaw（全局）
npm config set fund false
if ! npm install -g "openclaw@$TARGET_VERSION"; then
  echo "错误：openclaw@$TARGET_VERSION 安装失败；请检查 npm 输出及 Ubuntu proot 的平台依赖。" >&2
  exit 1
fi

# 7. 创建 hijack.js 脚本（确保目录存在）
mkdir -p "$HOME/.openclaw"
cat > "$HOME/.openclaw/hijack.js" <<'OPENCLAW_HIJACK_JS_EOF'
const Module = require('module');
const os = require('node:os');
const originalNetworkInterfaces = os.networkInterfaces.bind(os);

os.networkInterfaces = function patchedNetworkInterfaces() {
  try {
    return originalNetworkInterfaces();
  } catch (err) {
    const fallbackIp = process.env.OPENCLAW_PROOT_IPV4 || '127.0.0.1';
    return {
      eth0: [{
        address: fallbackIp,
        netmask: '255.0.0.0',
        family: 'IPv4',
        mac: '00:00:00:00:00:00',
        internal: false,
        cidr: fallbackIp + '/8'
      }],
      lo: [{
        address: '127.0.0.1',
        netmask: '255.0.0.0',
        family: 'IPv4',
        mac: '00:00:00:00:00:00',
        internal: true,
        cidr: '127.0.0.1/8'
      }]
    };
  }
};

if (typeof Module.syncBuiltinESMExports === 'function') {
  Module.syncBuiltinESMExports();
}
OPENCLAW_HIJACK_JS_EOF

# 8. 使用 npm 包的官方入口包装命令，仅保留 proot 网络接口兼容 shim
PACKAGE_PATH="$(npm root -g)/openclaw"
REAL_OPENCLAW_BIN="$PACKAGE_PATH/openclaw.mjs"
OPENCLAW_BIN="$NODE_BIN_DIR/openclaw"
if [ ! -f "$REAL_OPENCLAW_BIN" ]; then
  echo "错误：npm 包缺少官方入口 ${REAL_OPENCLAW_BIN}，安装不完整。" >&2
  exit 1
fi
INSTALLED_VERSION="$(node -p 'require(process.argv[1]).version' "$PACKAGE_PATH/package.json")"
if [ "$INSTALLED_VERSION" != "$TARGET_VERSION" ]; then
  echo "错误：安装版本 $INSTALLED_VERSION 与目标版本 $TARGET_VERSION 不符。" >&2
  exit 1
fi
if [ -L "$OPENCLAW_BIN" ]; then
  # npm 的命令是指向包入口的符号链接，写包装器之前必须移除链接。
  rm -f "$OPENCLAW_BIN"
elif [ -e "$OPENCLAW_BIN" ] && ! is_managed_proot_wrapper "$OPENCLAW_BIN"; then
  echo "错误：$OPENCLAW_BIN 已存在且并非本脚本包装器，拒绝覆盖。" >&2
  exit 1
fi
cat > "$OPENCLAW_BIN" <<OPENCLAW_WRAPPER_EOF
#!/usr/bin/env bash
# OPENCLAW_PROOT_WRAPPER
export PATH="$NODE_BIN_DIR:\$PATH"
export NODE_OPTIONS="--require=$HOME/.openclaw/hijack.js\${NODE_OPTIONS:+ \$NODE_OPTIONS}"
exec "$NODE_EXE" "$REAL_OPENCLAW_BIN" "\$@"
OPENCLAW_WRAPPER_EOF
chmod +x "$OPENCLAW_BIN"
mkdir -p /usr/local/bin
ln -sf "$OPENCLAW_BIN" /usr/local/bin/openclaw
if ! CLI_VERSION="$(openclaw --version)"; then
  echo "错误：openclaw --version 无法运行；请检查 proot 内的 Node 和 npm 依赖。" >&2
  exit 1
fi
case "$CLI_VERSION" in
  *"$TARGET_VERSION"*) echo "OpenClaw 命令版本: $CLI_VERSION" ;;
  *) echo "错误：openclaw --version 返回 ${CLI_VERSION}，预期 ${TARGET_VERSION}。" >&2; exit 1 ;;
esac

is_openclaw_config_ready() {
  [ -f "$HOME/.openclaw/openclaw.json" ] || return 1
  node -e "JSON.parse(require('fs').readFileSync(process.env.HOME + '/.openclaw/openclaw.json','utf8'))" >/dev/null 2>&1
}

show_resume_tip() {
  local state="${1:-needs_onboard}"
  echo
  echo -e "${BLUE}==========================================${NC}"
  echo -e "${GREEN}✅ OpenClaw 已安装完成${NC}"
  echo -e "${BLUE}==========================================${NC}"
  if [ "$state" = "configured" ]; then
    echo "首次配置已经完成。"
    echo "下次打开时：先进入 Ubuntu，再运行 openclaw gateway。"
    echo "如果要进入对话界面，可新开一个 Termux 会话后执行 openclaw tui。"
  else
    echo "安装已经完成，还差最后一步首次配置。"
    echo "下次打开时：先进入 Ubuntu，再运行 openclaw onboard。"
  fi
  echo "进入 Ubuntu 的命令：proot-distro login $DISTRO_NAME"
  echo "提示：不要把 Termux 从后台划掉，否则 OpenClaw 进程也会一起结束。"
}

echo
echo -e "${BLUE}==========================================${NC}"
echo -e "${GREEN}✅ OpenClaw 安装完成${NC}"
echo -e "${BLUE}==========================================${NC}"
echo -e "${CYAN}接下来可以直接开始首次配置（openclaw onboard）。${NC}"

if [ ! -r /dev/tty ] || [ ! -w /dev/tty ]; then
  echo "当前不是交互终端，已跳过首次配置引导。"
  show_resume_tip "needs_onboard"
  echo "进入 proot-distro 完成。"
  exit 0
fi

echo "配置时请准备好你的模型 API Key。"
echo "如果看到 systemd 相关提示，在 proot 环境里通常可以先忽略。"
echo
read -r -p "现在开始首次配置（openclaw onboard）吗？[Y/n]: " START_ONBOARD < /dev/tty || START_ONBOARD="n"
START_ONBOARD="${START_ONBOARD:-y}"

if [[ "$START_ONBOARD" =~ ^[Yy]$ ]]; then
  echo
  echo -e "${YELLOW}即将进入 openclaw onboard 配置界面...${NC}"
  echo "如果中途想稍后再配，按 Ctrl+C 退出即可。"
  read -r -p "按回车继续..." _ < /dev/tty || true
  echo

  if openclaw onboard < /dev/tty > /dev/tty 2>&1 && is_openclaw_config_ready; then
    echo
    echo -e "${GREEN}✅ 首次配置已完成。${NC}"
    read -r -p "是否现在启动 OpenClaw gateway？[Y/n]: " START_GATEWAY < /dev/tty || START_GATEWAY="n"
    START_GATEWAY="${START_GATEWAY:-y}"

    if [[ "$START_GATEWAY" =~ ^[Yy]$ ]]; then
      echo
      echo -e "${YELLOW}正在启动 openclaw gateway（按 Ctrl+C 可退出）...${NC}"
      echo "HTTP 健康检查只验证 Gateway 响应，不保证模型调用可用。"
      echo
      GATEWAY_PORT="$(node -e 'const c=require(process.argv[1]); const p=c.gateway?.port ?? 18789; if (!Number.isInteger(p) || p<1 || p>65535) process.exit(1); console.log(p)' "$HOME/.openclaw/openclaw.json")" || {
        echo "错误：Gateway 配置端口无效。" >&2
        exit 1
      }
      openclaw gateway < /dev/null > /dev/tty 2>&1 &
      GATEWAY_PID=$!
      trap 'kill "$GATEWAY_PID" 2>/dev/null || true' INT TERM
      GATEWAY_READY=0
      GATEWAY_DEADLINE=$((SECONDS + 180))
      while (( (remaining = GATEWAY_DEADLINE - SECONDS) > 0 )); do
        if curl --fail --silent --max-time "$((remaining < 2 ? remaining : 2))" "http://127.0.0.1:$GATEWAY_PORT/healthz" > /dev/null; then
          if (( SECONDS < GATEWAY_DEADLINE )); then
            GATEWAY_READY=1
          fi
          break
        fi
        if ! kill -0 "$GATEWAY_PID" 2>/dev/null; then
          break
        fi
        remaining=$((GATEWAY_DEADLINE - SECONDS))
        (( remaining > 0 )) || break
        sleep "$((remaining < 2 ? remaining : 2))"
      done
      if [ "$GATEWAY_READY" -ne 1 ]; then
        echo "错误：Gateway 未在预期时间内通过 127.0.0.1:$GATEWAY_PORT/healthz 健康检查。" >&2
        kill "$GATEWAY_PID" 2>/dev/null || true
        wait "$GATEWAY_PID" || true
        exit 1
      fi
      echo "Gateway HTTP 健康检查通过；不代表模型功能已验证。"
      if wait "$GATEWAY_PID"; then
        :
      else
        echo
        echo -e "${YELLOW}OpenClaw gateway 已退出。${NC}"
      fi
      trap - INT TERM
    fi

    show_resume_tip "configured"
  else
    echo
    echo -e "${YELLOW}已退出首次配置，稍后还可以继续。${NC}"
    show_resume_tip "needs_onboard"
  fi
else
  echo
  echo "好的，这次先只完成安装。"
  show_resume_tip "needs_onboard"
fi

echo "进入 proot-distro 完成。"
PROOT_BASH

echo "部署脚本执行结束：$(date)"
echo "部署日志文件：$LOGFILE"