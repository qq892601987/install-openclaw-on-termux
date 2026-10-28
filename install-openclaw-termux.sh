#!/bin/bash
# ==========================================
# Openclaw Termux Deployment Script v2.0
# ==========================================
#
# Usage: curl -sL https://s.zhihai.me/openclaw > openclaw-install.sh && source openclaw-install.sh [options]
#
# Options:
#   --help, -h       Show help information
#   --verbose, -v    Enable verbose output (shows command execution details)
#   --dry-run, -d    Dry run mode (simulate execution without making changes)
#   --uninstall, -u  Uninstall Openclaw and clean up configurations
#   --update, -U     Force update Openclaw to latest version without prompting
#   --version, -V    Specify Openclaw version to install (e.g., --version 1.2.3)
#
# Examples:
#   curl -sL https://s.zhihai.me/openclaw > openclaw-install.sh && source openclaw-install.sh
#   curl -sL https://s.zhihai.me/openclaw > openclaw-install.sh && source openclaw-install.sh --verbose
#   curl -sL https://s.zhihai.me/openclaw > openclaw-install.sh && source openclaw-install.sh --dry-run
#   curl -sL https://s.zhihai.me/openclaw > openclaw-install.sh && source openclaw-install.sh --uninstall
#   curl -sL https://s.zhihai.me/openclaw > openclaw-install.sh && source openclaw-install.sh --update
#   curl -sL https://s.zhihai.me/openclaw > openclaw-install.sh && source openclaw-install.sh --version 2026.2.26
#   curl -sL https://s.zhihai.me/openclaw > openclaw-install.sh && source openclaw-install.sh -V 2026.2.26
#
# Note: For direct local execution, use: source install-openclaw-termux.sh [options]
#
# ==========================================

# 注意：此脚本建议使用 source 方式执行，以便别名和环境变量立即生效
# 检测执行方式，非 source 方式时在脚本结束时提示
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _NEED_PROMPT=1
fi

# 解析命令行选项
VERBOSE=0
DRY_RUN=0
UNINSTALL=0
FORCE_UPDATE=0
TARGET_VERSION=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=1
            shift
            ;;
        --dry-run|-d)
            DRY_RUN=1
            shift
            ;;
        --uninstall|-u)
            UNINSTALL=1
            shift
            ;;
        --update|-U)
            FORCE_UPDATE=1
            shift
            ;;
        --version|-V)
            TARGET_VERSION="${2:-}"
            if ! [[ "$TARGET_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$ ]]; then
                echo "错误: --version 需要精确版本号（如 2026.10.8）" >&2
                exit 1
            fi
            shift 2
            ;;
        --help|-h)
            echo "用法: source $0 [选项]"
            echo "选项:"
            echo "  --verbose, -v    启用详细输出"
            echo "  --dry-run, -d    模拟运行，不执行实际命令"
            echo "  --uninstall, -u  卸载 Openclaw 和相关配置"
            echo "  --update, -U     强制更新到最新版本"
            echo "  --version, -V    指定 Openclaw 版本号（如 2026.2.26）"
            echo "  --help, -h       显示此帮助信息"
            echo ""
            echo "注意: 建议使用 source 方式执行，以便别名（ocr-重启、ockill-强制关闭、oclog-查看日志）立即生效"
            exit 0
            ;;
        *)
            echo "未知选项: $1"
            echo "使用 --help 查看帮助"
            exit 1
            ;;
    esac
done
if [ "$DRY_RUN" -eq 0 ] && [ "$_NEED_PROMPT" = 1 ]; then
    trap 'echo ""; echo "请执行 source ~/.bashrc 使 ocr/ockill/oclog 生效"' EXIT
fi

trap 'echo -e "${RED}错误：脚本执行失败，请检查上述输出${NC}"' ERR

# ==========================================
# Openclaw Termux Deployment Script v2.0
# ==========================================

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
WHITE_ON_BLUE='\033[44;37;1m'
NC='\033[0m'

# 检查终端是否支持颜色
if [ -t 1 ] && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
    : # 支持，保持颜色
else
    GREEN=''
    BLUE=''
    YELLOW=''
    RED=''
    CYAN=''
    BOLD=''
    WHITE_ON_BLUE=''
    NC=''
fi

# 定义常用路径变量
BASHRC="$HOME/.bashrc"
NPM_GLOBAL="$HOME/.npm-global"
NPM_BIN="$NPM_GLOBAL/bin"
LOG_DIR="$HOME/openclaw-logs"
LOG_FILE="$LOG_DIR/install.log"
if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] 不修改 HOME、npm 包、配置或服务；目标版本：${TARGET_VERSION:-latest（正式安装时解析并固定一次）}"
    if [ "$UNINSTALL" -eq 1 ]; then
        echo "[DRY-RUN] 将卸载 OpenClaw 并清理配置"
    else
        echo "[DRY-RUN] 将读取 npm 的具体版本与 engines.node，并验证 Node.js 完整版本"
        echo "[DRY-RUN] 若需替换：npm i -g openclaw@<解析后的版本> --ignore-scripts"
        echo "[DRY-RUN] 在包目录运行 npm run postinstall --if-present --ignore-scripts，创建安全包装脚本并检查 Gateway /healthz"
    fi
    [[ "${BASH_SOURCE[0]}" == "${0}" ]] && exit 0 || return 0
fi

if [ -z "${PREFIX:-}" ] || [ ! -x "$PREFIX/bin/pkg" ]; then
    echo "错误：请在原生 Termux 中运行此脚本；--help 和 --dry-run 可在其他环境查看。" >&2
    [[ "${BASH_SOURCE[0]}" == "${0}" ]] && exit 1 || return 1
fi

# 日志目录在实际执行时创建，dry-run 不写入文件
if [ "$DRY_RUN" -eq 0 ]; then mkdir -p "$LOG_DIR"; fi

# 日志函数
log() {
    if [ "$DRY_RUN" -eq 0 ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"; fi
}

# 命令执行函数（支持 dry-run）
run_cmd() {
    if [ $VERBOSE -eq 1 ]; then
        echo "[VERBOSE] 执行: $@"
    fi
    log "执行命令: $@"
    if [ $DRY_RUN -eq 1 ]; then
        echo "[DRY-RUN] 跳过: $@"
        return 0
    else
        "$@"
    fi
}

# Function definitions


check_deps() {
    # Check and install basic dependencies
    log "开始检查基础环境"
    echo -e "${YELLOW}[1/6] 正在检查基础运行环境...${NC}"

    # 检查是否需要更新 pkg
    UPDATE_FLAG="$HOME/.pkg_last_update"
    # 获取文件修改时间（兼容 GNU stat 和 BSD stat）
    if stat --version &>/dev/null; then
        FILE_MTIME=$(stat -c %Y "$UPDATE_FLAG" 2>/dev/null || echo 0)
    else
        FILE_MTIME=$(stat -f %m "$UPDATE_FLAG" 2>/dev/null || echo 0)
    fi
    if [ ! -f "$UPDATE_FLAG" ] || [ $(($(date +%s) - FILE_MTIME)) -gt 86400 ]; then
        log "执行 pkg update"
        echo -e "${YELLOW}更新包列表...${NC}"
        run_cmd pkg update -y
        if [ $? -ne 0 ]; then
            log "pkg update 失败"
            echo -e "${RED}错误：pkg 更新失败${NC}"
            exit 1
        fi
        run_cmd touch "$UPDATE_FLAG"
        log "pkg update 完成"
    else
        log "跳过 pkg update（已更新）"
        echo -e "${GREEN}包列表已是最新${NC}"
    fi

    # 原生安装跳过依赖编译，仅安装运行与服务管理所需工具。
    DEPS=("nodejs-lts" "git" "openssh" "tmux" "termux-tools" "curl")
    MISSING_DEPS=()

    for dep in "${DEPS[@]}"; do
        case "$dep" in
            nodejs-lts) cmd="node" ;;
            openssh) cmd="sshd" ;;
            termux-tools) cmd="termux-wake-lock" ;;
            *) cmd="$dep" ;;
        esac
        if ! command -v "$cmd" &> /dev/null ||
            { [ "$dep" = "nodejs-lts" ] && ! command -v npm &> /dev/null; }; then
            MISSING_DEPS+=("$dep")
        fi
    done

    # 先安装缺失的依赖（包括 nodejs），再做版本检查
    if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
        log "缺失依赖: ${MISSING_DEPS[*]}"
        echo -e "${YELLOW}检查可能的组件缺失: ${MISSING_DEPS[*]}${NC}"
        run_cmd pkg upgrade -y
        if [ $? -ne 0 ]; then
            log "pkg upgrade 失败"
            echo -e "${RED}错误：pkg 升级失败${NC}"
            exit 1
        fi
        run_cmd pkg install "${MISSING_DEPS[@]}" -y
        if [ $? -ne 0 ]; then
            log "依赖安装失败"
            echo -e "${RED}错误：依赖安装失败${NC}"
            exit 1
        fi
        log "依赖安装完成"
    else
        log "所有依赖已安装"
        echo -e "${GREEN}✅ 基础环境已就绪${NC}"
    fi

    # 依赖安装完毕后，显示版本信息
    log "Node.js 版本: $(node --version 2>/dev/null || echo '未知')"
    echo -e "${BLUE}Node.js 版本: $(node -v)${NC}"
    echo -e "${BLUE}NPM 版本: $(npm -v)${NC}" 

    # 精确的 Node.js 要求由目标 OpenClaw 包的 engines.node 元数据决定。
    command -v npm >/dev/null || { echo -e "${RED}错误：npm 不可用${NC}"; exit 1; }

    touch "$BASHRC" 2>/dev/null
}

package_version() {
    node -p "require(process.argv[1]).version" "$1/package.json" 2>/dev/null
}

check_engine() {
    local version="$1" range="$2" runtime
    runtime=$(node -p 'process.version.slice(1)' 2>/dev/null) || return 1
    if [ -z "$range" ] || [ "$range" = "undefined" ] ||
       ! npm exec --yes --package=semver@7 -- semver -r "$range" "$runtime" >/dev/null 2>&1; then
        echo -e "${RED}错误：OpenClaw $version 要求 Node.js ${range}，当前为 ${runtime}（或无法验证版本）。请安装符合要求的 Node.js；原生模块不支持 Android 时请使用 proot。${NC}" >&2
        return 1
    fi
}

wait_for_gateway() {
    local attempt
    for ((attempt=1; attempt<=30; attempt++)); do
        if curl --fail --silent --max-time 2 "http://127.0.0.1:$PORT/healthz" >/dev/null; then
            return 0
        fi
        [ "$attempt" -eq 30 ] || sleep 2
    done
    return 1
}

is_managed_openclaw_wrapper() {
    node -e '
const fs = require("fs");
const [bin, base] = process.argv.slice(1);
const lines = fs.readFileSync(bin, "utf8").replace(/\r?\n$/, "").split(/\r?\n/);
const entries = [base + "/dist/entry.js", base + "/openclaw.mjs"];
if (lines.length !== 2 || !/^#!\/.+\/sh$/.test(lines[0]) ||
    !entries.some(p => lines[1] === `exec node "${p}" "$@"` || lines[1] === `exec node ${p} "$@"`)) process.exit(1);
' "$NPM_BIN/openclaw" "$BASE_DIR" 2>/dev/null
}

configure_npm() {
    local requested="${TARGET_VERSION:-latest}" resolved engine installed_engine
    BASE_DIR="$NPM_GLOBAL/lib/node_modules/openclaw"
    export PATH="$NPM_BIN:$PATH"
    INSTALLED_VERSION=""
    if [ -f "$BASE_DIR/package.json" ]; then
        INSTALLED_VERSION=$(package_version "$BASE_DIR")
        [ -n "$INSTALLED_VERSION" ] && [ "$INSTALLED_VERSION" != "undefined" ] || {
            echo -e "${RED}错误：无法读取已安装 OpenClaw 的版本${NC}" >&2; return 1;
        }
    fi
    if [ "$requested" = latest ]; then
        resolved=$(npm view openclaw@latest version 2>/dev/null) || resolved=""
    else
        resolved=$(npm view "openclaw@$requested" version 2>/dev/null) || resolved=""
        if [ "$resolved" != "$requested" ]; then
            echo -e "${RED}错误：指定版本 $requested 不存在或不是精确版本${NC}" >&2
            return 1
        fi
    fi
    if ! [[ "$resolved" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$ ]]; then
        echo -e "${RED}错误：无法从 npm 获取具体 OpenClaw 版本（网络或元数据异常）${NC}" >&2
        return 1
    fi
    TARGET_VERSION="$resolved"
    engine=$(npm view "openclaw@$resolved" engines.node 2>/dev/null) || engine=""
    if [ -z "$engine" ] || [ "$engine" = "undefined" ]; then
        echo -e "${RED}错误：无法读取 OpenClaw $resolved 的 engines.node${NC}" >&2
        return 1
    fi
    echo -e "${BLUE}目标 OpenClaw: ${resolved}；Node.js 要求: $engine${NC}"

    local install_needed=1
    if [ -n "$INSTALLED_VERSION" ]; then
        echo -e "${BLUE}已安装 OpenClaw: $INSTALLED_VERSION${NC}"
        if [ "$INSTALLED_VERSION" = "$resolved" ]; then
            install_needed=0
        elif [ "$FORCE_UPDATE" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
            read -p "是否安装 ${resolved}（当前 ${INSTALLED_VERSION}）? (y/n) [默认: y]: " UPDATE_CHOICE
            UPDATE_CHOICE=${UPDATE_CHOICE:-y}
            if [ "$UPDATE_CHOICE" != y ] && [ "$UPDATE_CHOICE" != Y ]; then install_needed=0; fi
        fi
    fi
    if [ "$install_needed" -eq 0 ]; then
        if [ -z "$INSTALLED_VERSION" ]; then
            echo -e "${RED}错误：没有可用的 OpenClaw 安装${NC}" >&2; return 1
        fi
        installed_engine=$(node -p "require(process.argv[1]).engines?.node || ''" "$BASE_DIR/package.json" 2>/dev/null) || installed_engine=""
        [ -n "$installed_engine" ] || { echo -e "${RED}错误：已安装版本缺少 engines.node${NC}" >&2; return 1; }
        check_engine "$INSTALLED_VERSION" "$installed_engine" || return 1
        echo -e "${YELLOW}继续使用已安装版本 $INSTALLED_VERSION${NC}"
    fi
    if [ "$install_needed" -eq 1 ]; then
        check_engine "$resolved" "$engine" || return 1
        mkdir -p "$NPM_GLOBAL" "$LOG_DIR" "$HOME/tmp"
        npm config set prefix "$NPM_GLOBAL" || return 1
        export PATH="$NPM_BIN:$PATH" TMPDIR="$HOME/tmp"
        # 仅删除本安装器生成的旧包装文件，绝不覆盖未知的用户文件。
        if [ -e "$NPM_BIN/openclaw" ] && [ ! -L "$NPM_BIN/openclaw" ]; then
            if is_managed_openclaw_wrapper; then
                rm "$NPM_BIN/openclaw" || return 1
            else
                echo -e "${RED}错误：$NPM_BIN/openclaw 是未知的普通文件，拒绝覆盖。请先手工处理。${NC}" >&2
                return 1
            fi
        fi
        if ! env NODE_LLAMA_CPP_SKIP_DOWNLOAD=true npm i -g "openclaw@$resolved" --ignore-scripts; then
            echo -e "${RED}错误：Android 平台可能不支持所需原生模块；请改用 proot 安装。${NC}" >&2
            return 1
        fi
        [ "$(package_version "$BASE_DIR")" = "$resolved" ] || {
            echo -e "${RED}错误：安装后的包版本不等于 $resolved${NC}" >&2; return 1;
        }
        (cd "$BASE_DIR" && npm run postinstall --if-present --ignore-scripts) || {
            echo -e "${RED}错误：OpenClaw postinstall 失败；Android 原生功能不支持时请使用 proot。${NC}" >&2
            return 1
        }
        echo -e "${YELLOW}已跳过依赖包的原生安装脚本：部分 Android 原生功能可能不可用；若失败请使用 proot。${NC}"
    fi
    local native_file
    for native_file in "$BASE_DIR/node_modules/koffi/index.js" \
        "$BASE_DIR/node_modules/@lancedb/lancedb/index.js" \
        "$BASE_DIR/node_modules/@mariozechner/clipboard/index.js"; do
        if [ -f "$native_file" ] &&
            grep -Eq 'stub for android-arm64|module.exports = \{ availableFormats:\(\)=>\[\]' "$native_file"; then
            echo -e "${RED}错误：检测到旧脚本留下的假原生模块；请干净重装官方包，或使用 proot。${NC}" >&2
            return 1
        fi
    done
    [ -f "$BASE_DIR/openclaw.mjs" ] || {
        echo -e "${RED}错误：缺少官方入口 openclaw.mjs${NC}" >&2; return 1;
    }
    mkdir -p "$NPM_BIN"
    # npm bin 可能是指向包入口的符号链接，先移除链接，绝不能重定向覆盖其目标。
    if [ -e "$NPM_BIN/openclaw" ] && [ ! -L "$NPM_BIN/openclaw" ] &&
       ! is_managed_openclaw_wrapper; then
        echo -e "${RED}错误：$NPM_BIN/openclaw 是未知的普通文件，拒绝覆盖。${NC}" >&2
        return 1
    fi
    if [ -L "$NPM_BIN/openclaw" ]; then rm "$NPM_BIN/openclaw" || return 1; fi
    cat > "$NPM_BIN/openclaw" <<WRAPPER
#!${PREFIX:-/data/data/com.termux/files/usr}/bin/sh
exec node "$BASE_DIR/openclaw.mjs" "\$@"
WRAPPER
    chmod +x "$NPM_BIN/openclaw"
}

apply_patches() {
    # Apply Android compatibility patches
    log "开始应用补丁"
    echo -e "${YELLOW}[3/6] 正在应用 Android 兼容性补丁...${NC}"

    # 检查 BASE_DIR 是否存在
    if [ ! -d "$BASE_DIR" ]; then
        log "BASE_DIR 不存在: $BASE_DIR"
        echo -e "${RED}错误：Openclaw 安装目录不存在${NC}"
        exit 1
    fi

    # 修复所有包含 /tmp/openclaw 路径的文件
    log "搜索并修复所有硬编码的 /tmp/openclaw 路径"
    
    # 在 openclaw 目录中搜索所有包含 /tmp/openclaw 的文件
    cd "$BASE_DIR" || { log "无法进入 $BASE_DIR"; exit 1; }
    FILES_WITH_TMP=$(grep -rl "/tmp/openclaw" dist/ 2>/dev/null || true)
    
    if [ -n "$FILES_WITH_TMP" ]; then
        log "找到需要修复的文件"
        while IFS= read -r file; do
            log "修复文件: $file"
            node -e "const fs = require('fs'); const file = '$BASE_DIR/$file'; let c = fs.readFileSync(file, 'utf8'); c = c.replace(/\/tmp\/openclaw/g, process.env.HOME + '/openclaw-logs'); fs.writeFileSync(file, c);"
        done <<< "$FILES_WITH_TMP"
        log "所有文件修复完成"
    else
        log "未找到需要修复的文件"
    fi
    
    # 验证补丁是否生效
    REMAINING=$(grep -r "/tmp/openclaw" dist/ 2>/dev/null || true)
    if [ -n "$REMAINING" ]; then
        log "补丁验证失败，仍有文件包含 /tmp/openclaw"
        echo -e "${RED}警告：部分文件仍包含 /tmp/openclaw 路径${NC}"
        echo -e "${YELLOW}受影响的文件：${NC}"
        echo "$REMAINING"
    else
        log "补丁验证成功，所有路径已替换"
        echo -e "${GREEN}✓ 所有 /tmp/openclaw 路径已替换为 $HOME/openclaw-logs${NC}"
    fi

    # 修复硬编码的 /bin/npm 路径（Termux 下 npm 位于 $PREFIX/bin/npm）
    log "搜索并修复硬编码的 /bin/npm 路径"
    REAL_NPM=$(command -v npm 2>/dev/null || echo "")
    if [ -n "$REAL_NPM" ] && [ "$REAL_NPM" != "/bin/npm" ]; then
        FILES_WITH_NPM=$(grep -rl '"/bin/npm"' dist/ 2>/dev/null || true)
        if [ -z "$FILES_WITH_NPM" ]; then
            FILES_WITH_NPM=$(grep -rl "'/bin/npm'" dist/ 2>/dev/null || true)
        fi
        if [ -z "$FILES_WITH_NPM" ]; then
            FILES_WITH_NPM=$(grep -rl '/bin/npm' dist/ 2>/dev/null || true)
        fi
        
        if [ -n "$FILES_WITH_NPM" ]; then
            log "找到包含 /bin/npm 的文件，替换为 $REAL_NPM"
            while IFS= read -r file; do
                log "修复文件: $file"
                sed -i "s|/bin/npm|${REAL_NPM}|g" "$BASE_DIR/$file"
            done <<< "$FILES_WITH_NPM"
            echo -e "${GREEN}✓ /bin/npm 路径已替换为 $REAL_NPM${NC}"
        else
            log "未找到包含 /bin/npm 的文件"
        fi
    else
        log "npm 路径无需修复"
    fi

}

setup_autostart() {
    # Configure aliases and optional autostart
    log "配置环境变量和别名"
    # 备份原 ~/.bashrc 文件
    run_cmd cp "$BASHRC" "$BASHRC.backup"
    # 清理旧配置块（兼容旧版大小写不一致的标记）
    run_cmd sed -i '/# --- [Oo]pen[Cc]law Start ---/,/# --- [Oo]pen[Cc]law End ---/d' "$BASHRC"
    if [ $? -ne 0 ]; then
        log "bashrc 修改失败"
        echo -e "${RED}错误：bashrc 修改失败${NC}"
        exit 1
    fi

    # 构建 autostart 部分（仅当用户选择自启动时才包含 sshd/wake-lock）
    AUTOSTART_BLOCK=""
    if [ "$AUTO_START" == "y" ]; then
        log "配置自启动"
        AUTOSTART_BLOCK="sshd 2>/dev/null
termux-wake-lock 2>/dev/null"
    else
        log "跳过自启动（仅写入别名和环境变量）"
    fi

    # 写入配置块（函数始终写入，$NPM_BIN 在写入时展开为实际路径）
    cat >> "$BASHRC" <<EOT
# --- OpenClaw Start ---
# WARNING: This section contains your access token - keep ~/.bashrc secure
export TERMUX_VERSION=1
export TMPDIR=\$HOME/tmp
export OPENCLAW_GATEWAY_TOKEN=$TOKEN
export PATH=$NPM_BIN:\$PATH
${AUTOSTART_BLOCK}

# OpenClaw 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# OpenClaw 服务管理函数
ocr() {
    echo -e "\${YELLOW}正在启动/重启 OpenClaw 服务...\${NC}"
    pkill -9 -f 'openclaw' 2>/dev/null
    tmux kill-session -t openclaw 2>/dev/null
    sleep 1
    tmux new -d -s openclaw || return 1
    sleep 1
    tmux send-keys -t openclaw "export PATH=$NPM_BIN:\$PATH TMPDIR=\$HOME/tmp OPENCLAW_GATEWAY_TOKEN=\$OPENCLAW_GATEWAY_TOKEN; openclaw gateway --bind loopback --port $PORT --token \\\$OPENCLAW_GATEWAY_TOKEN --allow-unconfigured" C-m || return 1
    local attempt
    for ((attempt=1; attempt<=30; attempt++)); do
        if curl --fail --silent --max-time 2 "http://127.0.0.1:$PORT/healthz" >/dev/null; then break; fi
        [ "\$attempt" -eq 30 ] || sleep 2
    done
    if [ "\$attempt" -le 30 ]; then
        echo ""
        echo -e "\${GREEN}✅ Gateway /healthz 已就绪（不代表模型功能可用）\${NC}"
        echo -e "\${CYAN}本机访问: http://localhost:$PORT/?token=\$OPENCLAW_GATEWAY_TOKEN\${NC}"
        echo "   1. 本手机浏览器打开: http://localhost:$PORT/?token=\$OPENCLAW_GATEWAY_TOKEN"
        echo "   2. 或运行命令: openclaw tui"
        echo "   3. 或使用 Telegram 机器人(若已配置)"
        echo ""
        echo -e "\${BLUE}💡 oclog 查看日志 | ockill 停止服务\${NC}"
    else
        echo -e "\${RED}❌ Gateway 未在规定时间内通过 HTTP /healthz，请查看 oclog；Android 原生功能不支持时请使用 proot。\${NC}"
        return 1
    fi
}

oclog() {
    if tmux has-session -t openclaw 2>/dev/null; then
        tmux attach -t openclaw
    else
        echo -e "\${YELLOW}⚠️  OpenClaw 服务未运行，使用 ocr 启动\${NC}"
    fi
}

ockill() {
    echo -e "\${YELLOW}正在停止 OpenClaw 服务...\${NC}"
    pkill -9 -f "openclaw" 2>/dev/null
    tmux kill-session -t openclaw 2>/dev/null
    sleep 1
    if ! tmux has-session -t openclaw 2>/dev/null && ! pgrep -f "openclaw" > /dev/null; then
        echo -e "\${GREEN}✅ OpenClaw 服务已停止\${NC}"
    else
        echo -e "\${RED}❌ 服务停止失败，请手动检查\${NC}"
    fi
}
# --- OpenClaw End ---
EOT

    source "$BASHRC"
    if [ $? -ne 0 ]; then
        log "bashrc 加载警告"
        echo -e "${YELLOW}警告：bashrc 加载失败，可能影响别名${NC}"
    fi
    log "别名和环境变量配置完成"
}

activate_wakelock() {
    # Activate wake lock to prevent sleep
    log "激活唤醒锁"
    echo -e "${YELLOW}[4/6] 激活唤醒锁...${NC}"
    termux-wake-lock 2>/dev/null
    if [ $? -eq 0 ]; then
        log "唤醒锁激活成功"
        echo -e "${GREEN}✅ Wake-lock 已激活${NC}"
    else
        log "唤醒锁激活失败"
        echo -e "${YELLOW}⚠️  Wake-lock 激活失败，请检查 termux-tools 和 Termux 后台权限${NC}"
    fi
}

start_service() {
    log "启动服务"
    echo -e "${YELLOW}[5/6] 启动服务...${NC}"

    # 检查是否有实例在运行
    RUNNING_PROCESS=$(pgrep -f "openclaw gateway" 2>/dev/null || true)
    HAS_TMUX_SESSION=$(tmux has-session -t openclaw 2>/dev/null && echo "yes" || echo "no")

    if [ -n "$RUNNING_PROCESS" ] || [ "$HAS_TMUX_SESSION" = "yes" ]; then
        log "发现已有 Openclaw 实例在运行"
        echo -e "${YELLOW}⚠️  检测到 Openclaw 实例已在运行${NC}"
        echo -e "${BLUE}运行中的进程: $RUNNING_PROCESS${NC}"
        read -p "是否停止旧实例并启动新实例? (y/n) [默认: y]: " RESTART_CHOICE
        RESTART_CHOICE=${RESTART_CHOICE:-y}

        if [ "$RESTART_CHOICE" = "y" ] || [ "$RESTART_CHOICE" = "Y" ]; then
            log "停止旧实例"
            echo -e "${YELLOW}正在停止旧实例...${NC}"
            # 只停止 openclaw 相关进程，不杀死所有 node 进程
            pkill -9 -f "openclaw" 2>/dev/null || true
            tmux kill-session -t openclaw 2>/dev/null || true
            sleep 1
        else
            log "用户选择不重启"
            if wait_for_gateway; then
                echo -e "${GREEN}现有 Gateway HTTP /healthz 已就绪（不代表模型功能可用）${NC}"
                return 0
            fi
            echo -e "${RED}错误：现有 Gateway 未通过 HTTP /healthz${NC}" >&2
            return 1
        fi
    fi

    # 2. 确保目录存在
    mkdir -p "$HOME/tmp"
    export TMPDIR="$HOME/tmp"

    # 3. 创建会话并捕获可能的错误
    # 这里我们先启动一个 shell，再在 shell 里执行命令，方便观察
    tmux new -d -s openclaw
    sleep 1
    
    # 将输出重定向到一个临时文件，如果 tmux 崩了也能看到报错
    tmux send-keys -t openclaw "export PATH=$NPM_BIN:\$PATH TMPDIR=$HOME/tmp OPENCLAW_GATEWAY_TOKEN=\$OPENCLAW_GATEWAY_TOKEN; openclaw gateway --bind loopback --port $PORT --token \\\$OPENCLAW_GATEWAY_TOKEN --allow-unconfigured 2>&1 | tee $LOG_DIR/runtime.log" C-m
    
    log "服务指令已发送"
    echo ""
    
    if wait_for_gateway; then
        echo -e "${GREEN}[6/6] ✅ Gateway HTTP /healthz 已就绪（不代表模型功能可用）${NC}"
    else
        echo -e "${RED}错误：Gateway 未在规定时间内通过 HTTP /healthz；请检查 $LOG_DIR/runtime.log。Android 原生功能不支持时请使用 proot。${NC}" >&2
        return 1
    fi
}

uninstall_openclaw() {
    # Uninstall Openclaw and clean up configurations
    log "开始卸载 Openclaw"
    echo -e "${YELLOW}开始卸载 Openclaw...${NC}"

    # 停止服务
    echo -e "${YELLOW}停止服务...${NC}"
    run_cmd pkill -9 -f "openclaw" 2>/dev/null || true
    run_cmd tmux kill-session -t openclaw 2>/dev/null || true
    log "服务已停止"

    # 删除别名和配置
    echo -e "${YELLOW}删除别名和配置...${NC}"
    # 使用固定文本匹配，避免正则表达式问题
    if grep -q "# --- OpenClaw Start ---" "$BASHRC" 2>/dev/null; then
        sed -i '/# --- OpenClaw Start ---/,/# --- OpenClaw End ---/d' "$BASHRC"
        log "已删除 OpenClaw 配置块"
    else
        log "未找到 OpenClaw 配置块"
    fi
    # 删除可能残留的 PATH 配置
    sed -i '/export PATH=.*\.npm-global\/bin/d' "$BASHRC" 2>/dev/null || true
    log "别名和配置已删除"

    # 恢复备份的 bashrc
    if [ -f "$BASHRC.backup" ]; then
        echo -e "${YELLOW}恢复原始 ~/.bashrc...${NC}"
        run_cmd cp "$BASHRC.backup" "$BASHRC"
        run_cmd rm "$BASHRC.backup"
        log "bashrc 已恢复"
    fi

    # 卸载 npm 包
    echo -e "${YELLOW}卸载 Openclaw 包...${NC}"
    run_cmd npm uninstall -g openclaw 2>/dev/null || true
    log "Openclaw 包已卸载"

    # 删除更新标志
    run_cmd rm -f "$HOME/.pkg_last_update" 2>/dev/null || true

    # 备份并删除 openclaw.json（在删除日志目录之前）
    if [ -f "$HOME/.openclaw/openclaw.json" ]; then
        echo -e "${YELLOW}备份 openclaw.json...${NC}"
        run_cmd cp "$HOME/.openclaw/openclaw.json" "$HOME/.openclaw/openclaw.json.$(date +%Y%m%d_%H%M%S).bak"
        log "已备份 openclaw.json"
        run_cmd rm -f "$HOME/.openclaw/openclaw.json"
        log "已删除 openclaw.json"
    fi

    # 记录完成日志（在删除日志目录之前）
    log "卸载完成"

    # 最后删除日志和 npm 全局目录
    echo -e "${YELLOW}删除日志目录和 npm 全局目录...${NC}"
    run_cmd rm -rf "$LOG_DIR" 2>/dev/null || true
    run_cmd rm -rf "$NPM_GLOBAL" 2>/dev/null || true

    echo -e "${GREEN}卸载完成！${NC}"
}

# 主脚本

if [ "$UNINSTALL" -eq 1 ]; then
    uninstall_openclaw
    [[ "${BASH_SOURCE[0]}" == "${0}" ]] && exit 0 || return 0
fi

clear
if [ $DRY_RUN -eq 1 ]; then
    echo -e "${YELLOW}🔍 模拟运行模式：不执行实际命令${NC}"
fi
if [ $VERBOSE -eq 1 ]; then
    echo -e "${BLUE}详细输出模式已启用${NC}"
fi
echo -e "${BLUE}=========================================="
echo -e "   🦞 Openclaw Termux 部署工具"
echo -e "==========================================${NC}"

# --- 交互配置 ---
read -p "请输入 Gateway 端口号 [默认: 18789]: " INPUT_PORT
if [ -z "$INPUT_PORT" ]; then
    echo -e "${GREEN}✓ 使用默认端口: 18789${NC}"
    PORT=18789
else
    # 验证输入的端口号是否为数字
    if ! [[ "$INPUT_PORT" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}错误：端口号必须是数字，使用默认值 18789${NC}"
        PORT=18789
    else
        PORT=$INPUT_PORT
        echo -e "${GREEN}✓ 使用端口: $PORT${NC}"
    fi
fi

# 检查是否已存在 Token
if [ -n "$OPENCLAW_GATEWAY_TOKEN" ]; then
    echo -e "${GREEN}检测到已存在的 Token: ${OPENCLAW_GATEWAY_TOKEN:0:8}...${NC}"
    read -p "是否使用现有 Token? (y/n) [默认: y]: " USE_EXISTING
    USE_EXISTING=${USE_EXISTING:-y}
    if [ "$USE_EXISTING" = "y" ] || [ "$USE_EXISTING" = "Y" ]; then
        TOKEN="$OPENCLAW_GATEWAY_TOKEN"
        echo -e "${GREEN}✓ 使用现有 Token${NC}"
    else
        read -p "请输入自定义 Token (OPENCLAW_GATEWAY_TOKEN，用于安全访问，建议强密码) [留空随机生成]: " TOKEN
        if [ -z "$TOKEN" ]; then
            RANDOM_PART=$(date +%s | md5sum | cut -c 1-8)
            TOKEN="token$RANDOM_PART"
            echo -e "${GREEN}生成的随机 Token: $TOKEN${NC}"
        fi
    fi
else
    read -p "请输入自定义 Token (用于安全访问，建议强密码) [留空随机生成]: " TOKEN
    if [ -z "$TOKEN" ]; then
        RANDOM_PART=$(date +%s | md5sum | cut -c 1-8)
        TOKEN="token$RANDOM_PART"
        echo -e "${GREEN}生成的随机 Token: $TOKEN${NC}"
    fi
fi

read -p "是否需要开启开机自启动? (y/n) [默认: y]: " AUTO_START
AUTO_START=${AUTO_START:-y}

# 执行步骤
log "脚本开始执行，用户配置: 端口=$PORT, Token=$TOKEN, 自启动=$AUTO_START"
check_deps
configure_npm || { [[ "${BASH_SOURCE[0]}" == "${0}" ]] && exit 1 || return 1; }
apply_patches
setup_autostart
activate_wakelock
start_service || { [[ "${BASH_SOURCE[0]}" == "${0}" ]] && exit 1 || return 1; }

echo ""
echo -e "${GREEN}=========================================="
echo -e "✅ OpenClaw 初始安装已完成，待配置！"
echo -e "==========================================${NC}"
echo ""
echo -e "OPENCLAW_GATEWAY_TOKEN: ${YELLOW}$TOKEN${NC}"
echo ""
echo -e "${BLUE}┌─────────────────────────────────────┐${NC}"
echo -e "${BLUE}│${NC}  常用命令                           ${BLUE}│${NC}"
echo -e "${BLUE}│${NC}  ─────────────────────────────────  ${BLUE}│${NC}"
echo -e "${BLUE}│${NC}  ${CYAN}oclog${NC}    - 查看运行状态            ${BLUE}│${NC}"
echo -e "${BLUE}│${NC}  ${CYAN}ockill${NC}   - 停止服务                ${BLUE}│${NC}"
echo -e "${BLUE}│${NC}  ${CYAN}ocr${NC}      - 重启服务                ${BLUE}│${NC}"
echo -e "${BLUE}└─────────────────────────────────────┘${NC}"
echo ""


# 更新模式跳过配置引导
if [ $FORCE_UPDATE -eq 1 ]; then
    echo -e "${GREEN}更新完成！${NC}"
    log "更新完成"
    exit 0
fi

# start_service 已在 HTTP /healthz 验证 Gateway 就绪；模型功能仍需用户配置后确认。

# 显示最终信息的函数
show_final_info() {
    local CONFIGURED=$1
    local SHOW_IGNORE_HINT=$2
    echo ""
    echo -e "${BLUE}┌─────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${NC}  常用命令                           ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}  ─────────────────────────────────  ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}  ${CYAN}oclog${NC}    - 查看运行状态            ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}  ${CYAN}ockill${NC}   - 停止服务                ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}  ${CYAN}ocr${NC}      - 重启服务                ${BLUE}│${NC}"
    echo -e "${BLUE}└─────────────────────────────────────┘${NC}"
    echo ""
    if [ "$CONFIGURED" = "true" ]; then
        echo -e "${GREEN}✅ 配置完成！${NC}"
        if [ "$SHOW_IGNORE_HINT" = "true" ]; then
            echo ""
            echo -e "${YELLOW}Android 不支持 Gateway service install 时，请用 ocr 启动用户会话中的 Gateway；其他原生模块报错不能忽略，请改用 proot。${NC}"
        fi
        echo ""
        echo -e "${CYAN}👉 下一步：手机浏览器访问${NC}"
        echo -e "${WHITE_ON_BLUE} http://localhost:$PORT/?token=$TOKEN ${NC}"
        echo -e "或运行命令 openclaw tui"
    else
        echo -e "${YELLOW}后续请手动执行 openclaw onboard 继续配置${NC}"
        if [ "$SHOW_IGNORE_HINT" = "true" ]; then
            echo ""
            echo -e "${YELLOW}Gateway service install 在 Android 上不受支持，可用 ocr 启动；原生模块错误请使用 proot。${NC}"
        fi
    fi
}

# 配置引导
echo -e "请按 ${YELLOW}确认${NC} 键（Enter键）开始配置 OpenClaw 。"
read -r

echo ""
echo -e "即将执行 ${YELLOW}openclaw onboard ${NC}命令..."
echo ""
echo -e "请准备好 ${YELLOW}大模型 API Key ${NC}，中国大陆推荐 MiniMax（minimax-cn）、智谱（z-ai） 等"
echo ""
echo -e "${YELLOW}Gateway service install 在 Android 上不受支持；ocr 使用 tmux 启动 Gateway。其他原生模块错误请使用 proot。${NC}"
echo ""
read -p "是否继续？[Y/n]: " CONTINUE_ONBOARD
CONTINUE_ONBOARD=${CONTINUE_ONBOARD:-y}

if [[ "$CONTINUE_ONBOARD" =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "正在启动 openclaw onboard 命令..."
    echo ""
    # 临时取消 LD_PRELOAD 以解决 npm 安装 feishu 时找不到 /bin/npm 的问题
    OLD_LD_PRELOAD="${LD_PRELOAD:-}"
    unset LD_PRELOAD
    # 捕获 Ctrl+C（同时恢复 LD_PRELOAD）
    trap 'echo -e "\n${YELLOW}已取消配置${NC}"; [ -n "$OLD_LD_PRELOAD" ] && LD_PRELOAD="$OLD_LD_PRELOAD"; show_final_info "false" "true"; log "用户取消配置"' INT
    openclaw onboard
    trap - INT
    # 恢复 LD_PRELOAD
    [ -n "$OLD_LD_PRELOAD" ] && LD_PRELOAD="$OLD_LD_PRELOAD"

    # 检查配置文件是否存在且有效
    if [ -f "$HOME/.openclaw/openclaw.json" ] && node -e "JSON.parse(require('fs').readFileSync('$HOME/.openclaw/openclaw.json'))" 2>/dev/null; then
        # 确保 openclaw.json 中的 token 使用环境变量引用
        TOKEN_REF='${OPENCLAW_GATEWAY_TOKEN}'
        if node -e "const fs=require('fs');const p=process.env.HOME+'/.openclaw/openclaw.json';const c=JSON.parse(fs.readFileSync(p,'utf8'));c.gateway=c.gateway||{};c.gateway.auth=c.gateway.auth||{};c.gateway.auth.token='$TOKEN_REF';fs.writeFileSync(p,JSON.stringify(c,null,2));"; then
            log "已更新 openclaw.json 中的 token 为环境变量引用"
            # 重启 gateway 使新 token 生效
            echo -e "${YELLOW}正在重启 Gateway 服务以应用新 Token...${NC}"
            pkill -9 -f 'openclaw' 2>/dev/null || true
            tmux kill-session -t openclaw 2>/dev/null || true
            sleep 1
            tmux new -d -s openclaw
            sleep 1
            tmux send-keys -t openclaw "export PATH=$NPM_BIN:\$PATH TMPDIR=\$HOME/tmp OPENCLAW_GATEWAY_TOKEN=$TOKEN; openclaw gateway --bind loopback --port $PORT --token \$OPENCLAW_GATEWAY_TOKEN --allow-unconfigured 2>&1 | tee $LOG_DIR/runtime.log" C-m
            if wait_for_gateway; then
                log "Gateway HTTP 就绪"
                echo -e "${GREEN}✅ Gateway /healthz 就绪（不代表模型功能可用）${NC}"
            else
                echo -e "${RED}错误：Gateway 重启后未通过 HTTP /healthz，请检查日志；Android 原生功能不支持时请使用 proot。${NC}" >&2
                [[ "${BASH_SOURCE[0]}" == "${0}" ]] && exit 1 || return 1
            fi
        else
            log "警告: 更新 openclaw.json 中的 token 失败"
        fi
        show_final_info "true" "true"
    else
        show_final_info "false" "true"
    fi
    log "脚本执行完成"
    
else
    show_final_info "false" "true"
    log "用户跳过配置"
fi

# 回到主目录
cd ~
