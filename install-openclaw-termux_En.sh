#!/bin/bash
# ==========================================
# Openclaw Termux Deployment Script v2.0
# ==========================================
#
# Usage: curl -sL https://s.zhihai.me/openclaw_en > openclaw-install.sh && source openclaw-install.sh [options]
#
# Options:
#   --help, -h       Show help information
#   --verbose, -v    Enable verbose output (shows command execution details)
#   --dry-run, -d    Dry run mode (simulate execution without making changes)
#   --uninstall, -u  Uninstall Openclaw and clean up configurations
#   --update, -U     Install the target version without prompting, even if already installed
#   --version, -V    Specify Openclaw version to install (e.g., --version 2026.2.26)
#
# Examples:
#   curl -sL https://s.zhihai.me/openclaw_en > openclaw-install.sh && source openclaw-install.sh
#   curl -sL https://s.zhihai.me/openclaw_en > openclaw-install.sh && source openclaw-install.sh --verbose
#   curl -sL https://s.zhihai.me/openclaw_en > openclaw-install.sh && source openclaw-install.sh --dry-run
#   curl -sL https://s.zhihai.me/openclaw_en > openclaw-install.sh && source openclaw-install.sh --uninstall
#   curl -sL https://s.zhihai.me/openclaw_en > openclaw-install.sh && source openclaw-install.sh --update
#   curl -sL https://s.zhihai.me/openclaw_en > openclaw-install.sh && source openclaw-install.sh --version 2026.2.26
#   curl -sL https://s.zhihai.me/openclaw_en > openclaw-install.sh && source openclaw-install.sh -V 2026.2.26
#
# Note: For direct local execution, use: source install-openclaw-termux.sh [options]
#
# ==========================================

# Note: This script is recommended to be executed via 'source' so that aliases and environment variables take effect immediately
# Detect execution method, prompt when not using 'source' mode
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _NEED_PROMPT=1
fi

# Parse command line options
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
                echo "Error: --version requires an exact version (e.g. 2026.10.8)" >&2
                exit 1
            fi
            shift 2
            ;;
        --help|-h)
            echo "Usage: source $0 [options]"
            echo "Options:"
            echo "  --verbose, -v    Enable verbose output"
            echo "  --dry-run, -d    Dry run mode, simulate without executing actual commands"
            echo "  --uninstall, -u  Uninstall Openclaw and related configurations"
            echo "  --update, -U     Force target installation (default latest), including same-version repair"
            echo "  --version, -V    Specify Openclaw version (e.g., 2026.2.26)"
            echo "  --help, -h       Show this help message"
            echo ""
            echo "Note: It is recommended to use 'source' to execute, so that aliases (ocr-restart, ockill-force stop, oclog-view logs) take effect immediately"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help to view help"
            exit 1
            ;;
    esac
done
if [ "$DRY_RUN" -eq 0 ] && [ "$_NEED_PROMPT" = 1 ]; then
    trap 'echo ""; echo "Run source ~/.bashrc to enable ocr/ockill/oclog"' EXIT
fi

trap 'echo -e "${RED}Error: Script execution failed, please check the output above${NC}"' ERR

# ==========================================
# Openclaw Termux Deployment Script v2.0
# ==========================================

# Color definitions
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
WHITE_ON_BLUE='\033[44;37;1m'
NC='\033[0m'

# Check if terminal supports colors
if [ -t 1 ] && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
    : # Supported, keep colors
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

# Define common path variables
BASHRC="$HOME/.bashrc"
NPM_GLOBAL="$HOME/.npm-global"
NPM_BIN="$NPM_GLOBAL/bin"
LOG_DIR="$HOME/openclaw-logs"
LOG_FILE="$LOG_DIR/install.log"
# Gateway changes process.title; allow its padded name without matching installer names.
GATEWAY_PROCESS_PATTERN='^openclaw-gateway([[:space:]]|$)|^([^[:space:]]*/)?node[[:space:]]+[^[:space:]]*/\.npm-global/lib/node_modules/openclaw/(openclaw\.mjs|dist/entry\.js)[[:space:]]+gateway([[:space:]]|$)'
if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] No HOME, npm package, configuration or service changes; target: ${TARGET_VERSION:-latest (resolved and pinned once during installation)}"
    if [ "$UNINSTALL" -eq 1 ]; then
        echo "[DRY-RUN] Would uninstall OpenClaw and remove configuration"
    else
        echo "[DRY-RUN] Would fetch the concrete npm version and engines.node, validate the full Node.js version"
        echo "[DRY-RUN] If replacement is needed: npm i -g openclaw@<resolved-version> --ignore-scripts"
        echo "[DRY-RUN] Would run npm run postinstall --if-present --ignore-scripts in package directory, create safe wrapper, check Gateway /healthz"
    fi
    [[ "${BASH_SOURCE[0]}" == "${0}" ]] && exit 0 || return 0
fi

if [ -z "${PREFIX:-}" ] || [ ! -x "$PREFIX/bin/pkg" ]; then
    echo "Error: Run this installer inside native Termux; --help and --dry-run are available elsewhere." >&2
    [[ "${BASH_SOURCE[0]}" == "${0}" ]] && exit 1 || return 1
fi

# Create logs only during an actual installation, never during dry run.
if [ "$DRY_RUN" -eq 0 ]; then mkdir -p "$LOG_DIR"; fi

# Log function
log() {
    if [ "$DRY_RUN" -eq 0 ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"; fi
}

# Command execution function (supports dry-run)
run_cmd() {
    if [ $VERBOSE -eq 1 ]; then
        echo "[VERBOSE] Executing: $@"
    fi
    log "Executing command: $@"
    if [ $DRY_RUN -eq 1 ]; then
        echo "[DRY-RUN] Skipping: $@"
        return 0
    else
        "$@" 2>&1 | tee -a "$LOG_FILE"
        return "${PIPESTATUS[0]}"
    fi
}

# Function definitions


check_deps() {
    # Check and install basic dependencies
    log "Starting basic environment check"
    echo -e "${YELLOW}[1/6] Checking basic runtime environment...${NC}"

    # Check if pkg update is needed
    UPDATE_FLAG="$HOME/.pkg_last_update"
    # Get file modification time (compatible with GNU stat and BSD stat)
    if stat --version &>/dev/null; then
        FILE_MTIME=$(stat -c %Y "$UPDATE_FLAG" 2>/dev/null || echo 0)
    else
        FILE_MTIME=$(stat -f %m "$UPDATE_FLAG" 2>/dev/null || echo 0)
    fi
    if [ ! -f "$UPDATE_FLAG" ] || [ $(($(date +%s) - FILE_MTIME)) -gt 86400 ]; then
        log "Executing pkg update"
        echo -e "${YELLOW}Updating package list...${NC}"
        run_cmd pkg update -y
        if [ $? -ne 0 ]; then
            log "pkg update failed"
            echo -e "${RED}Error: pkg update failed${NC}"
            exit 1
        fi
        run_cmd touch "$UPDATE_FLAG"
        log "pkg update completed"
    else
        log "Skipping pkg update (already updated)"
        echo -e "${GREEN}Package list is up to date${NC}"
    fi

    # Native installs skip dependency compilation; retain runtime/service tools only.
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

    # Install missing dependencies (including nodejs) first, then check version
    if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
        log "Missing dependencies: ${MISSING_DEPS[*]}"
        echo -e "${YELLOW}Checking for potentially missing components: ${MISSING_DEPS[*]}${NC}"
        run_cmd env DEBIAN_FRONTEND=noninteractive pkg upgrade -y \
            -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold
        if [ $? -ne 0 ]; then
            log "pkg upgrade failed"
            echo -e "${RED}Error: pkg upgrade failed${NC}"
            exit 1
        fi
        run_cmd env DEBIAN_FRONTEND=noninteractive pkg install "${MISSING_DEPS[@]}" -y \
            -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold
        if [ $? -ne 0 ]; then
            log "Dependency installation failed"
            echo -e "${RED}Error: Dependency installation failed${NC}"
            exit 1
        fi
        log "Dependencies installed successfully"
    else
        log "All dependencies are installed"
        echo -e "${GREEN}✅ Basic environment is ready${NC}"
    fi

    # After dependencies are installed, display version info
    log "Node.js version: $(node --version 2>/dev/null || echo 'unknown')"
    echo -e "${BLUE}Node.js version: $(node -v)${NC}"
    echo -e "${BLUE}NPM version: $(npm -v)${NC}" 

    # The precise runtime requirement comes from the selected package engines.node metadata.
    command -v npm >/dev/null || { echo -e "${RED}Error: npm unavailable${NC}"; exit 1; }
}

package_version() {
    node -p "require(process.argv[1]).version" "$1/package.json" 2>/dev/null
}

check_engine() {
    local version="$1" range="$2" runtime
    runtime=$(node -p 'process.version.slice(1)' 2>/dev/null) || return 1
    if [ -z "$range" ] || [ "$range" = "undefined" ] ||
       ! npm exec --yes --package=semver@7 -- semver -r "$range" "$runtime" >/dev/null 2>&1; then
        echo -e "${RED}Error: OpenClaw $version requires Node.js $range; current runtime is $runtime (or validation failed). Install a compatible Node.js; use proot if Android native modules are unsupported.${NC}" >&2
        return 1
    fi
}

wait_for_gateway() {
    local deadline remaining
    deadline=$((SECONDS + 180))
    while (( (remaining = deadline - SECONDS) > 0 )); do
        if curl --fail --silent --max-time "$((remaining < 2 ? remaining : 2))" "http://127.0.0.1:$PORT/healthz" >/dev/null; then
            (( SECONDS < deadline )) && return 0
            break
        fi
        remaining=$((deadline - SECONDS))
        (( remaining > 0 )) || break
        sleep "$((remaining < 2 ? remaining : 2))"
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
            echo -e "${RED}Error: Cannot read installed OpenClaw package version${NC}" >&2; return 1;
        }
    fi
    if [ "$requested" = latest ]; then
        resolved=$(npm view openclaw@latest version 2>/dev/null) || resolved=""
    else
        resolved=$(npm view "openclaw@$requested" version 2>/dev/null) || resolved=""
        if [ "$resolved" != "$requested" ]; then
            echo -e "${RED}Error: Requested version $requested is unavailable or not an exact version${NC}" >&2
            return 1
        fi
    fi
    if ! [[ "$resolved" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$ ]]; then
        echo -e "${RED}Error: Cannot resolve a concrete OpenClaw version from npm (network or metadata failure)${NC}" >&2
        return 1
    fi
    TARGET_VERSION="$resolved"
    engine=$(npm view "openclaw@$resolved" engines.node 2>/dev/null) || engine=""
    if [ -z "$engine" ] || [ "$engine" = "undefined" ]; then
        echo -e "${RED}Error: Cannot read engines.node for OpenClaw $resolved${NC}" >&2
        return 1
    fi
    echo -e "${BLUE}Target OpenClaw: $resolved; Node.js requirement: $engine${NC}"

    local install_needed=1
    if [ -n "$INSTALLED_VERSION" ]; then
        echo -e "${BLUE}Installed OpenClaw: $INSTALLED_VERSION${NC}"
        if [ "$INSTALLED_VERSION" = "$resolved" ] && [ "$FORCE_UPDATE" -eq 0 ]; then
            install_needed=0
        elif [ "$FORCE_UPDATE" -eq 0 ]; then
            read -p "Install $resolved (currently $INSTALLED_VERSION)? (y/n) [default: y]: " UPDATE_CHOICE
            UPDATE_CHOICE=${UPDATE_CHOICE:-y}
            if [ "$UPDATE_CHOICE" != y ] && [ "$UPDATE_CHOICE" != Y ]; then install_needed=0; fi
        fi
    fi
    if [ "$install_needed" -eq 0 ]; then
        installed_engine=$(node -p "require(process.argv[1]).engines?.node || ''" "$BASE_DIR/package.json" 2>/dev/null) || installed_engine=""
        [ -n "$installed_engine" ] || { echo -e "${RED}Error: Installed version is missing engines.node${NC}" >&2; return 1; }
        check_engine "$INSTALLED_VERSION" "$installed_engine" || return 1
        echo -e "${YELLOW}Keeping installed version $INSTALLED_VERSION${NC}"
    fi
    if [ "$install_needed" -eq 1 ]; then
        check_engine "$resolved" "$engine" || return 1
        mkdir -p "$NPM_GLOBAL" "$LOG_DIR" "$HOME/tmp"
        npm config set prefix "$NPM_GLOBAL" || return 1
        export TMPDIR="$HOME/tmp"
        # Only remove wrappers previously created by this installer, not unrelated binaries.
        if [ -e "$NPM_BIN/openclaw" ] && [ ! -L "$NPM_BIN/openclaw" ]; then
            if is_managed_openclaw_wrapper; then
                rm "$NPM_BIN/openclaw" || return 1
            else
                echo -e "${RED}Error: $NPM_BIN/openclaw is an unknown regular file; refusing to overwrite it.${NC}" >&2
                return 1
            fi
        fi
        if ! run_cmd env NODE_LLAMA_CPP_SKIP_DOWNLOAD=true npm i -g "openclaw@$resolved" --ignore-scripts; then
            echo -e "${RED}Error: Android may not support a required native dependency; use proot instead.${NC}" >&2
            return 1
        fi
        [ "$(package_version "$BASE_DIR")" = "$resolved" ] || {
            echo -e "${RED}Error: Installed package version does not match $resolved${NC}" >&2; return 1;
        }
        (cd "$BASE_DIR" && run_cmd npm run postinstall --if-present --ignore-scripts) || {
            echo -e "${RED}Error: OpenClaw postinstall failed; use proot if Android native features are unsupported.${NC}" >&2
            return 1
        }
        echo -e "${YELLOW}Dependency native install scripts were skipped: some Android native features may be unavailable; use proot if they fail.${NC}"
    fi
    local native_file
    for native_file in "$BASE_DIR/node_modules/koffi/index.js" \
        "$BASE_DIR/node_modules/@lancedb/lancedb/index.js" \
        "$BASE_DIR/node_modules/@mariozechner/clipboard/index.js"; do
        if [ -f "$native_file" ] &&
            grep -Eq 'stub for android-arm64|module.exports = \{ availableFormats:\(\)=>\[\]' "$native_file"; then
            echo -e "${RED}Error: Legacy fake native modules detected; cleanly reinstall the official package or use proot.${NC}" >&2
            return 1
        fi
    done
    [ -f "$BASE_DIR/openclaw.mjs" ] || {
        echo -e "${RED}Error: Official openclaw.mjs entrypoint missing${NC}" >&2; return 1;
    }
    mkdir -p "$NPM_BIN"
    # npm's bin can link to openclaw.mjs. Unlink before writing a shell wrapper.
    if [ -e "$NPM_BIN/openclaw" ] && [ ! -L "$NPM_BIN/openclaw" ] &&
       ! is_managed_openclaw_wrapper; then
        echo -e "${RED}Error: $NPM_BIN/openclaw is an unknown regular file; refusing to overwrite it.${NC}" >&2
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
    log "Starting patch application"
    echo -e "${YELLOW}[3/6] Applying Android compatibility patches...${NC}"

    # Check if BASE_DIR exists
    if [ ! -d "$BASE_DIR" ]; then
        log "BASE_DIR does not exist: $BASE_DIR"
        echo -e "${RED}Error: Openclaw installation directory does not exist${NC}"
        exit 1
    fi

    # Fix all files containing /tmp/openclaw path
    log "Searching and fixing all hardcoded /tmp/openclaw paths"
    
    # Search for all files containing /tmp/openclaw in the openclaw directory
    cd "$BASE_DIR" || { log "Cannot enter $BASE_DIR"; exit 1; }
    FILES_WITH_TMP=$(grep -rl "/tmp/openclaw" dist/ 2>/dev/null || true)
    
    if [ -n "$FILES_WITH_TMP" ]; then
        log "Found files needing fixes"
        while IFS= read -r file; do
            log "Fixing file: $file"
            node -e "const fs = require('fs'); const file = '$BASE_DIR/$file'; let c = fs.readFileSync(file, 'utf8'); c = c.replace(/\/tmp\/openclaw/g, process.env.HOME + '/openclaw-logs'); fs.writeFileSync(file, c);"
        done <<< "$FILES_WITH_TMP"
        log "All files fixed successfully"
    else
        log "No files found needing fixes"
    fi
    
    # Verify if patches were applied
    REMAINING=$(grep -r "/tmp/openclaw" dist/ 2>/dev/null || true)
    if [ -n "$REMAINING" ]; then
        log "Patch verification failed, some files still contain /tmp/openclaw"
        echo -e "${RED}Warning: Some files still contain /tmp/openclaw path${NC}"
        echo -e "${YELLOW}Affected files:${NC}"
        echo "$REMAINING"
    else
        log "Patch verification successful, all paths replaced"
        echo -e "${GREEN}✓ All /tmp/openclaw paths replaced with $HOME/openclaw-logs${NC}"
    fi

    # Fix hardcoded /bin/npm path (in Termux, npm is located at $PREFIX/bin/npm)
    log "Searching and fixing hardcoded /bin/npm paths"
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
            log "Found files containing /bin/npm, replacing with $REAL_NPM"
            while IFS= read -r file; do
                log "Fixing file: $file"
                sed -i "s|/bin/npm|${REAL_NPM}|g" "$BASE_DIR/$file"
            done <<< "$FILES_WITH_NPM"
            echo -e "${GREEN}✓ /bin/npm path replaced with $REAL_NPM${NC}"
        else
            log "No files found containing /bin/npm"
        fi
    else
        log "npm path does not need fixing"
    fi

}

setup_autostart() {
    # Configure aliases and optional autostart
    log "Configuring environment variables and aliases"
    # Backup original ~/.bashrc file
    run_cmd cp "$BASHRC" "$BASHRC.backup"
    # Clean up old configuration blocks (compatible with old version case-insensitive markers)
    run_cmd sed -i '/# --- [Oo]pen[Cc]law Start ---/,/# --- [Oo]pen[Cc]law End ---/d' "$BASHRC"
    if [ $? -ne 0 ]; then
        log "bashrc modification failed"
        echo -e "${RED}Error: bashrc modification failed${NC}"
        exit 1
    fi

    # Build autostart section (only include sshd/wake-lock when user chooses autostart)
    AUTOSTART_BLOCK=""
    if [ "$AUTO_START" == "y" ]; then
        log "Configuring autostart"
        AUTOSTART_BLOCK="sshd 2>/dev/null
termux-wake-lock 2>/dev/null"
    else
        log "Skipping autostart (only writing aliases and environment variables)"
    fi

    # Write configuration block (functions are always written, $NPM_BIN expands to actual path at write time)
    cat >> "$BASHRC" <<EOT
# --- OpenClaw Start ---
# WARNING: This section contains your access token - keep ~/.bashrc secure
export TERMUX_VERSION=1
export TMPDIR=\$HOME/tmp
export OPENCLAW_GATEWAY_TOKEN=$TOKEN
export PATH=$NPM_BIN:\$PATH
GATEWAY_PROCESS_PATTERN='$GATEWAY_PROCESS_PATTERN'
${AUTOSTART_BLOCK}

# OpenClaw color definitions
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# OpenClaw service management functions
ocr() {
    echo -e "\${YELLOW}Starting/restarting OpenClaw service...\${NC}"
    pkill -9 -f "\$GATEWAY_PROCESS_PATTERN" 2>/dev/null
    tmux kill-session -t openclaw 2>/dev/null
    sleep 1
    tmux new -d -s openclaw || return 1
    sleep 1
    tmux send-keys -t openclaw "export PATH=$NPM_BIN:\$PATH TMPDIR=\$HOME/tmp OPENCLAW_GATEWAY_TOKEN=\$OPENCLAW_GATEWAY_TOKEN; openclaw gateway --bind loopback --port $PORT --allow-unconfigured 2>&1 | tee '$LOG_DIR/runtime.log'" C-m || return 1
    local deadline remaining
    deadline=\$((SECONDS + 180))
    while (( (remaining = deadline - SECONDS) > 0 )); do
        if curl --fail --silent --max-time "\$((remaining < 2 ? remaining : 2))" "http://127.0.0.1:$PORT/healthz" >/dev/null; then
            (( SECONDS < deadline )) || break
            echo ""
            echo -e "\${GREEN}✅ Gateway /healthz ready (model function not verified)\${NC}"
            echo "   1. Open in phone browser:: http://localhost:$PORT/?token=\$OPENCLAW_GATEWAY_TOKEN"
            echo "   2. Or run command: openclaw tui"
            echo "   3. Or use Telegram bot (if configured)"
            echo ""
            echo -e "\${BLUE}💡 oclog to view logs | ockill to stop service\${NC}"
            return 0
        fi
        remaining=\$((deadline - SECONDS))
        (( remaining > 0 )) || break
        sleep "\$((remaining < 2 ? remaining : 2))"
    done
    echo -e "\${RED}Gateway did not pass http://127.0.0.1:$PORT/healthz within 180 seconds; it may still be starting. Check oclog or $LOG_DIR/runtime.log. A timeout does not stop the Gateway.\${NC}" >&2
    return 1
}

oclog() {
    if tmux has-session -t openclaw 2>/dev/null; then
        tmux attach -t openclaw
    else
        echo -e "\${YELLOW}⚠️  OpenClaw service not running, use ocr to start\${NC}"
    fi
}

ockill() {
    echo -e "\${YELLOW}Stopping OpenClaw service...\${NC}"
    pkill -9 -f "\$GATEWAY_PROCESS_PATTERN" 2>/dev/null
    tmux kill-session -t openclaw 2>/dev/null
    sleep 1
    if ! tmux has-session -t openclaw 2>/dev/null && ! pgrep -f "\$GATEWAY_PROCESS_PATTERN" > /dev/null; then
        echo -e "\${GREEN}✅ OpenClaw service stopped\${NC}"
    else
        echo -e "\${RED}❌ Failed to stop service, please check manually\${NC}"
    fi
}
# --- OpenClaw End ---
EOT

    source "$BASHRC"
    if [ $? -ne 0 ]; then
        log "bashrc loading warning"
        echo -e "${YELLOW}Warning: bashrc loading failed, aliases may be affected${NC}"
    fi
    log "Aliases and environment variables configuration completed"
}

activate_wakelock() {
    # Activate wake lock to prevent sleep
    log "Activating wake lock"
    echo -e "${YELLOW}[4/6] Activating wake lock...${NC}"
    termux-wake-lock 2>/dev/null
    if [ $? -eq 0 ]; then
        log "Wake lock activated successfully"
        echo -e "${GREEN}✅ Wake-lock activated${NC}"
    else
        log "Wake lock activation failed"
        echo -e "${YELLOW}⚠️  Wake-lock activation failed; check termux-tools and Termux background permissions${NC}"
    fi
}

start_service() {
    log "Starting service"
    echo -e "${YELLOW}[5/6] Starting service...${NC}"

    # Check if there's an instance running
    RUNNING_PROCESS=$(pgrep -f "$GATEWAY_PROCESS_PATTERN" 2>/dev/null || true)
    HAS_TMUX_SESSION=$(tmux has-session -t openclaw 2>/dev/null && echo "yes" || echo "no")

    if [ -n "$RUNNING_PROCESS" ] || [ "$HAS_TMUX_SESSION" = "yes" ]; then
        log "Found existing Openclaw instance running"
        echo -e "${YELLOW}⚠️  Detected Openclaw instance already running${NC}"
        echo -e "${BLUE}Running process: $RUNNING_PROCESS${NC}"
        read -p "Stop old instance and start new one? (y/n) [default: y]: " RESTART_CHOICE
        RESTART_CHOICE=${RESTART_CHOICE:-y}

        if [ "$RESTART_CHOICE" = "y" ] || [ "$RESTART_CHOICE" = "Y" ]; then
            log "Stopping old instance"
            echo -e "${YELLOW}Stopping old instance...${NC}"
            # Only stop the managed Gateway launcher, not other OpenClaw or Node.js processes.
            pkill -9 -f "$GATEWAY_PROCESS_PATTERN" 2>/dev/null || true
            tmux kill-session -t openclaw 2>/dev/null || true
            sleep 1
        else
            if wait_for_gateway; then
                echo -e "${GREEN}Existing Gateway HTTP /healthz ready (model function not verified)${NC}"
                return 0
            fi
            echo -e "${RED}Error: Existing Gateway did not pass http://127.0.0.1:$PORT/healthz within 180 seconds; it may still be starting. Check $LOG_DIR/runtime.log. A timeout does not stop the Gateway.${NC}" >&2
            return 1
        fi
    fi

    # 2. Ensure directories exist
    mkdir -p "$HOME/tmp"
    export TMPDIR="$HOME/tmp"

    # 3. Create session and capture possible errors
    # First start a shell, then execute commands in the shell for easier observation
    tmux new -d -s openclaw
    sleep 1
    
    # Redirect output to a temporary file, so we can see errors if tmux crashes
    tmux send-keys -t openclaw "export PATH=$NPM_BIN:\$PATH TMPDIR=$HOME/tmp OPENCLAW_GATEWAY_TOKEN=\$OPENCLAW_GATEWAY_TOKEN; openclaw gateway --bind loopback --port $PORT --allow-unconfigured 2>&1 | tee $LOG_DIR/runtime.log" C-m
    
    log "Service command sent"
    echo ""
    
    # 4. Real-time verification
    if wait_for_gateway; then
        echo -e "${GREEN}[6/6] Gateway HTTP /healthz ready (model function not verified)${NC}"
    else
        echo -e "${RED}Error: Gateway did not pass http://127.0.0.1:$PORT/healthz within 180 seconds; it may still be starting. Check $LOG_DIR/runtime.log. A timeout does not stop the Gateway.${NC}" >&2
        return 1
    fi
}

uninstall_openclaw() {
    # Uninstall Openclaw and clean up configurations
    log "Starting Openclaw uninstallation"
    echo -e "${YELLOW}Starting Openclaw uninstallation...${NC}"

    # Stop service
    echo -e "${YELLOW}Stopping service...${NC}"
    run_cmd pkill -9 -f "$GATEWAY_PROCESS_PATTERN" 2>/dev/null || true
    run_cmd tmux kill-session -t openclaw 2>/dev/null || true
    log "Service stopped"

    # Delete aliases and configurations
    echo -e "${YELLOW}Deleting aliases and configurations...${NC}"
    # Use fixed text matching to avoid regex issues
    if grep -q "# --- OpenClaw Start ---" "$BASHRC" 2>/dev/null; then
        sed -i '/# --- OpenClaw Start ---/,/# --- OpenClaw End ---/d' "$BASHRC"
        log "Deleted OpenClaw configuration block"
    else
        log "OpenClaw configuration block not found"
    fi
    # Delete possible leftover PATH configuration
    sed -i '/export PATH=.*\.npm-global\/bin/d' "$BASHRC" 2>/dev/null || true
    log "Aliases and configurations deleted"

    # Restore backed up bashrc
    if [ -f "$BASHRC.backup" ]; then
        echo -e "${YELLOW}Restoring original ~/.bashrc...${NC}"
        run_cmd cp "$BASHRC.backup" "$BASHRC"
        run_cmd rm "$BASHRC.backup"
        log "bashrc restored"
    fi

    # Uninstall npm package
    echo -e "${YELLOW}Uninstalling Openclaw package...${NC}"
    run_cmd npm uninstall -g openclaw 2>/dev/null || true
    log "Openclaw package uninstalled"

    # Delete update flag
    run_cmd rm -f "$HOME/.pkg_last_update" 2>/dev/null || true

    # Backup and delete openclaw.json (before deleting log directory)
    if [ -f "$HOME/.openclaw/openclaw.json" ]; then
        echo -e "${YELLOW}Backing up openclaw.json...${NC}"
        run_cmd cp "$HOME/.openclaw/openclaw.json" "$HOME/.openclaw/openclaw.json.$(date +%Y%m%d_%H%M%S).bak"
        log "Backed up openclaw.json"
        run_cmd rm -f "$HOME/.openclaw/openclaw.json"
        log "Deleted openclaw.json"
    fi

    # Log completion (before deleting log directory)
    log "Uninstallation completed"

    # Finally delete log and npm global directories
    echo -e "${YELLOW}Deleting log directory and npm global directory...${NC}"
    run_cmd rm -rf "$LOG_DIR" 2>/dev/null || true
    run_cmd rm -rf "$NPM_GLOBAL" 2>/dev/null || true

    echo -e "${GREEN}Uninstallation completed!${NC}"
}

# Main script

if [ "$UNINSTALL" -eq 1 ]; then
    uninstall_openclaw
    [[ "${BASH_SOURCE[0]}" == "${0}" ]] && exit 0 || return 0
fi

if [ -t 1 ] && [ -n "${TERM:-}" ] && [ "$TERM" != dumb ]; then
    clear
fi
if [ $DRY_RUN -eq 1 ]; then
    echo -e "${YELLOW}🔍 Dry run mode: no actual commands will be executed${NC}"
fi
if [ $VERBOSE -eq 1 ]; then
    echo -e "${BLUE}Verbose output mode enabled${NC}"
fi
echo -e "${BLUE}=========================================="
echo -e "   🦞 Openclaw Termux Deployment Tool"
echo -e "==========================================${NC}"

# --- Interactive configuration ---
read -p "Enter Gateway port number [default: 18789]: " INPUT_PORT
if [ -z "$INPUT_PORT" ]; then
    echo -e "${GREEN}✓ Using default port: 18789${NC}"
    PORT=18789
else
    # Validate if port number is numeric
    if ! [[ "$INPUT_PORT" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Port number must be numeric, using default 18789${NC}"
        PORT=18789
    else
        PORT=$INPUT_PORT
        echo -e "${GREEN}✓ Using port: $PORT${NC}"
    fi
fi

# Check if Token already exists
if [ -n "$OPENCLAW_GATEWAY_TOKEN" ]; then
    echo -e "${GREEN}Detected existing Token: ${OPENCLAW_GATEWAY_TOKEN:0:8}...${NC}"
    read -p "Use existing Token? (y/n) [default: y]: " USE_EXISTING
    USE_EXISTING=${USE_EXISTING:-y}
    if [ "$USE_EXISTING" = "y" ] || [ "$USE_EXISTING" = "Y" ]; then
        TOKEN="$OPENCLAW_GATEWAY_TOKEN"
        echo -e "${GREEN}✓ Using existing Token${NC}"
    else
        read -p "Enter custom Token (OPENCLAW_GATEWAY_TOKEN for secure access, strong password recommended) [leave empty for random generation]: " TOKEN
        if [ -z "$TOKEN" ]; then
            RANDOM_PART=$(date +%s | md5sum | cut -c 1-8)
            TOKEN="token$RANDOM_PART"
            echo -e "${GREEN}Generated random Token: $TOKEN${NC}"
        fi
    fi
else
    read -p "Enter custom Token (for secure access, strong password recommended) [leave empty for random generation]: " TOKEN
    if [ -z "$TOKEN" ]; then
        RANDOM_PART=$(date +%s | md5sum | cut -c 1-8)
        TOKEN="token$RANDOM_PART"
        echo -e "${GREEN}Generated random Token: $TOKEN${NC}"
    fi
fi

read -p "Enable autostart on boot? (y/n) [default: y]: " AUTO_START
AUTO_START=${AUTO_START:-y}

# Execution steps
log "Script starting, user configuration: port=$PORT, Token=$TOKEN, autostart=$AUTO_START"
check_deps
configure_npm || { [[ "${BASH_SOURCE[0]}" == "${0}" ]] && exit 1 || return 1; }
apply_patches
setup_autostart
activate_wakelock
start_service || { [[ "${BASH_SOURCE[0]}" == "${0}" ]] && exit 1 || return 1; }

echo ""
echo -e "${GREEN}=========================================="
echo -e "✅ OpenClaw initial installation completed, awaiting configuration!"
echo -e "==========================================${NC}"
echo ""
echo -e "OPENCLAW_GATEWAY_TOKEN: ${YELLOW}$TOKEN${NC}"
echo ""
echo -e "${BLUE}┌─────────────────────────────────────┐${NC}"
echo -e "${BLUE}│${NC}  Common Commands                    ${BLUE}│${NC}"
echo -e "${BLUE}│${NC}  ─────────────────────────────────  ${BLUE}│${NC}"
echo -e "${BLUE}│${NC}  ${CYAN}oclog${NC}    - View running status       ${BLUE}│${NC}"
echo -e "${BLUE}│${NC}  ${CYAN}ockill${NC}   - Stop service               ${BLUE}│${NC}"
echo -e "${BLUE}│${NC}  ${CYAN}ocr${NC}      - Restart service            ${BLUE}│${NC}"
echo -e "${BLUE}└─────────────────────────────────────┘${NC}"
echo ""


# Update mode skips configuration guide
if [ $FORCE_UPDATE -eq 1 ]; then
    echo -e "${GREEN}Update completed!${NC}"
    log "Update completed"
    exit 0
fi

# start_service already checked Gateway HTTP readiness; model function still requires configuration.

# Function to display final information
show_final_info() {
    local CONFIGURED=$1
    local SHOW_IGNORE_HINT=$2
    echo ""
    echo -e "${BLUE}┌─────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${NC}  Common Commands                    ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}  ─────────────────────────────────  ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}  ${CYAN}oclog${NC}    - View running status       ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}  ${CYAN}ockill${NC}   - Stop service               ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}  ${CYAN}ocr${NC}      - Restart service            ${BLUE}│${NC}"
    echo -e "${BLUE}└─────────────────────────────────────┘${NC}"
    echo ""
    if [ "$CONFIGURED" = "true" ]; then
        echo -e "${GREEN}✅ Configuration completed!${NC}"
        if [ "$SHOW_IGNORE_HINT" = "true" ]; then
            echo ""
            echo -e "${YELLOW}Android does not support Gateway service install; use ocr to start a user-session Gateway. Other native module failures cannot be ignored; use proot.${NC}"
        fi
        echo ""
        echo -e "${CYAN}👉 Next step: Open in phone browser${NC}"
        echo -e "${WHITE_ON_BLUE} http://localhost:$PORT/?token=$TOKEN ${NC}"
        echo -e "Or run command: openclaw tui"
    else
        echo -e "${YELLOW}Please manually run openclaw onboard to continue configuration${NC}"
        if [ "$SHOW_IGNORE_HINT" = "true" ]; then
            echo ""
            echo -e "${YELLOW}Gateway service install is unsupported on Android; use ocr. Use proot for native module failures.${NC}"
        fi
    fi
}

# Configuration guide
echo -e "Press ${YELLOW}Enter${NC} key to start configuring OpenClaw."
read -r

echo ""
echo -e "About to execute ${YELLOW}openclaw onboard${NC} command..."
echo ""
echo -e "Please prepare your ${YELLOW}LLM API Key${NC}. Recommended providers: MiniMax (minimax-cn), Zhipu (z-ai), etc."
echo ""
echo -e "${YELLOW}Gateway service install is unsupported on Android; ocr starts Gateway in tmux. Use proot for other native module failures.${NC}"
echo ""
read -p "Continue? [Y/n]: " CONTINUE_ONBOARD
CONTINUE_ONBOARD=${CONTINUE_ONBOARD:-y}

if [[ "$CONTINUE_ONBOARD" =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "Starting openclaw onboard command..."
    echo ""
    # Temporarily unset LD_PRELOAD to fix npm not finding /bin/npm when installing feishu
    OLD_LD_PRELOAD="${LD_PRELOAD:-}"
    unset LD_PRELOAD
    # Catch Ctrl+C (and restore LD_PRELOAD)
    trap 'echo -e "\n${YELLOW}Configuration cancelled${NC}"; [ -n "$OLD_LD_PRELOAD" ] && LD_PRELOAD="$OLD_LD_PRELOAD"; show_final_info "false" "true"; log "User cancelled configuration"' INT
    openclaw onboard
    trap - INT
    # Restore LD_PRELOAD
    [ -n "$OLD_LD_PRELOAD" ] && LD_PRELOAD="$OLD_LD_PRELOAD"

    # Check if configuration file exists and is valid
    if [ -f "$HOME/.openclaw/openclaw.json" ] && node -e "JSON.parse(require('fs').readFileSync('$HOME/.openclaw/openclaw.json'))" 2>/dev/null; then
        # Ensure token in openclaw.json uses environment variable reference
        TOKEN_REF='${OPENCLAW_GATEWAY_TOKEN}'
        if node -e "const fs=require('fs');const p=process.env.HOME+'/.openclaw/openclaw.json';const c=JSON.parse(fs.readFileSync(p,'utf8'));c.gateway=c.gateway||{};c.gateway.auth=c.gateway.auth||{};c.gateway.auth.token='$TOKEN_REF';fs.writeFileSync(p,JSON.stringify(c,null,2));"; then
            log "Updated token in openclaw.json to environment variable reference"
            # Restart gateway to apply new token
            echo -e "${YELLOW}Restarting Gateway service to apply new Token...${NC}"
            pkill -9 -f "$GATEWAY_PROCESS_PATTERN" 2>/dev/null || true
            tmux kill-session -t openclaw 2>/dev/null || true
            sleep 1
            tmux new -d -s openclaw
            sleep 1
            tmux send-keys -t openclaw "export PATH=$NPM_BIN:\$PATH TMPDIR=\$HOME/tmp OPENCLAW_GATEWAY_TOKEN=$TOKEN; openclaw gateway --bind loopback --port $PORT --allow-unconfigured 2>&1 | tee $LOG_DIR/runtime.log" C-m
            if wait_for_gateway; then
                log "Gateway HTTP ready"
                echo -e "${GREEN}Gateway /healthz ready (model function not verified)${NC}"
            else
                echo -e "${RED}Error: Gateway did not pass http://127.0.0.1:$PORT/healthz within 180 seconds after restart; it may still be starting. Check $LOG_DIR/runtime.log. A timeout does not stop the Gateway.${NC}" >&2
                [[ "${BASH_SOURCE[0]}" == "${0}" ]] && exit 1 || return 1
            fi
        else
            log "Warning: Failed to update token in openclaw.json"
        fi
        show_final_info "true" "true"
    else
        show_final_info "false" "true"
    fi
    log "Script execution completed"
    
else
    show_final_info "false" "true"
    log "User skipped configuration"
fi

# Return to home directory
cd ~
