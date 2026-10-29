# OpenClaw on Termux

Install, update, and manage OpenClaw Gateway on Android with Termux.

[中文](README.md) · [OpenClaw upstream](https://github.com/openclaw/openclaw) · [Report an issue](https://github.com/qq892601987/install-openclaw-on-termux/issues)

![OpenClaw on Termux Preview](./sources/OpenClaw-on-Termux-Preview.png)

## Compatibility and limitations

The **Chinese native installer has now been exercised on a non-root Android device**; see the device-verification record below. This is not a guarantee for every device, installer, or OpenClaw feature.

- OpenClaw 2026.10.8 requires Node.js **`>=24.22.1 <25 || >=26.12.1`**. Other releases use their own npm `engines.node` requirement. Checking only “Node >=22” or the major version is insufficient.
- Installers resolve npm `latest` to a concrete version before reading its runtime requirements and installing it. Use an exact `--version` for reproducible installations.
- Native Termux uses Android/Bionic, not a conventional Linux userspace. Linux native modules may not work. The scripts no longer replace koffi, LanceDB, or clipboard modules with fake implementations or force past platform checks.
- **Try the proot Ubuntu path when native installation fails on platform or native-module compatibility.** It provides a Linux userspace but remains subject to Android memory, background-process, and syscall restrictions.
- HTTP `/healthz` readiness proves only that Gateway responds. Verify model credentials, channels, vector storage, browser integration, and other required features separately.

## Choose an installer

| Script | Purpose |
| --- | --- |
| `install-openclaw-termux.sh` | Native Termux, Chinese prompts |
| `install-openclaw-termux_En.sh` | Native Termux, English prompts |
| `install-openclaw-termux-v2.sh` | Staged native installer; also supports `--yes`, `--list-versions`, port and autostart options |
| `install_openclaw_termux_proot.sh` | Installs inside proot Ubuntu; separate home directory and runtime from native Termux |

Use a current Termux from a trusted source such as F-Droid. Allow sufficient storage and a stable network: dependencies, npm downloads, and native modules may consume substantial space. The former 500MB estimate is not a capacity guarantee.

### Default system dependencies

| Installation environment | Explicitly installed system packages |
| --- | --- |
| Native Termux (all three native scripts) | `nodejs-lts`, `git`, `openssh`, `tmux`, `termux-tools`, `curl` |
| Termux outside proot | `proot-distro`, `curl` |
| Ubuntu inside proot | `curl`, `build-essential`, `git`, `ca-certificates`, `python3` |

Native installation no longer forces `cmake`, `python`, `golang`, `which`, `clang`, `ninja`, `pkg-config`, `build-essential`, or `termux-api`. The wake-lock command belongs to [termux-tools](https://github.com/termux/termux-tools/blob/master/scripts/termux-wake-lock.in); it does not require Termux:API. Install extra skill or device-API dependencies only when needed.

The proot path no longer preinstalls `wget`, `nano`, `python3-pip`, `gnupg`, or `lsb-release`. It retains basic build tools and Python for native-module build fallback during the normal npm lifecycle. Package managers still install transitive dependencies of these system packages. This cleanup does not uninstall software already on your device or alter npm dependencies declared by the OpenClaw release.

### Native Termux

Use the repository URL directly rather than a short URL that might serve an older script:

```bash
curl -fLsS https://raw.githubusercontent.com/qq892601987/install-openclaw-on-termux/main/install-openclaw-termux_En.sh -o openclaw-install.sh
bash openclaw-install.sh
source ~/.bashrc
```

Inspect downloaded scripts before executing them. If downloading fails, do not execute a stale file left from a previous download.

```bash
git clone https://github.com/qq892601987/install-openclaw-on-termux.git
cd install-openclaw-on-termux
bash install-openclaw-termux_En.sh --help
bash install-openclaw-termux_En.sh
source ~/.bashrc
```

The scripts change the npm global prefix, registry, and `~/.bashrc`, and install system dependencies. Back up your configuration first. Running with `bash`, then loading `~/.bashrc`, is recommended; sourcing the installer remains supported.

### proot Ubuntu

```bash
curl -fLsS https://raw.githubusercontent.com/qq892601987/install-openclaw-on-termux/main/install_openclaw_termux_proot.sh -o openclaw-proot.sh
bash openclaw-proot.sh --help
bash openclaw-proot.sh --version 2026.10.8
```

This path installs or reuses Ubuntu, configures apt mirrors and nvm, and installs the latest maintained Node 24 release. The selected OpenClaw version's complete engine range must still match; Node 24 is not assumed to be universally compatible. It updates Ubuntu packages, so back up an existing Ubuntu environment first.

To select another supported Node LTS major, use e.g. `OPENCLAW_NODE_VERSION=26 bash openclaw-proot.sh --version 2026.10.8`. The full engine-range check still applies.

## Installation and update options

These options apply to the Chinese and English native installers. See v2's `--help` for its additional options.

| Option | Meaning |
| --- | --- |
| `--help`, `-h` | Display help |
| `--verbose`, `-v` | Verbose output |
| `--dry-run`, `-d` | Preview without installing packages, writing configuration, or starting services; not proof that installation will succeed |
| `--version`, `-V <version>` | Select a version, including downgrades; no subsequent automatic `openclaw update` changes it |
| `--update`, `-U` | Install the target without confirmation, even when already installed, to repair interrupted dependencies; configuration may still prompt |
| `--uninstall`, `-u` | Uninstall and remove managed configuration; back up first |

```bash
# Exact-version example; see the scoped device-verification record
bash install-openclaw-termux_En.sh --version 2026.10.8

# Update to the latest version resolved at runtime
bash install-openclaw-termux_En.sh --update

# Preview
bash install-openclaw-termux_En.sh --dry-run

# Non-interactive v2 installation
bash install-openclaw-termux-v2.sh --yes --version 2026.10.8
```

Native installation skips automatic npm lifecycle execution to avoid unsupported Android dependency builds, then explicitly runs the OpenClaw package's own postinstall if present. This **does not build every native dependency**. Verify required native functionality separately; inspect failures or use proot. The proot path uses the normal npm installation lifecycle.

Complete engine-range validation uses npm's `semver` tool and needs registry access. Missing version or engine metadata is an error, not permission to guess compatibility.

If the official npm registry is slow, select a trusted mirror for one invocation without changing the global registry:

```bash
npm_config_registry=https://registry.npmmirror.com bash install-openclaw-termux_En.sh --version 2026.10.8
```

Copy download commands as complete lines; do not submit `-o` and its filename separately. Mirrors are third-party sources. The OpenClaw 2026.10.8 tarball integrity value matched the official registry in this test; other releases still require normal npm integrity validation.

## Configuration and service management

- Default port: `18789`.
- Native Gateway binds to loopback by default. Open `http://127.0.0.1:18789/` on the **same phone** and follow Gateway's authentication instructions.
- Do not expose the port publicly. LAN access requires separate binding, authentication, and secure-access configuration.
- Native scripts manage shell configuration in `~/.bashrc`; v2 also uses `~/.config/openclaw/env.sh`.
- Configuration can contain access tokens. Do not publish it, unredacted logs, screenshots, or token-bearing URLs.

Native service commands:

```bash
source ~/.bashrc
ocr       # Start/restart and wait for HTTP readiness
oclog     # View the tmux session output
ockill    # Stop the service
```

Native logs are normally under `~/openclaw-logs/`; proot deployment logs are in Termux's `~/deploy_openclaw_proot.log`. OpenClaw inside Ubuntu has its own runtime and configuration; the outer Termux npm installation is not the same installation.

## Verification and troubleshooting

Run these commands in the environment where OpenClaw is installed:

```bash
node --version
openclaw --version
openclaw doctor
openclaw gateway --help
curl --fail --silent --show-error http://127.0.0.1:18789/healthz
```

Configure the model and channels, then complete a real model request. npm success, a surviving tmux shell, and an HTTP readiness response are not proof that all integrations work.

| Problem | Action |
| --- | --- |
| Node does not satisfy `engines.node` | Update Termux's package list and Node package, or the nvm runtime inside Ubuntu. Recheck the complete range; do not hide the failure with `--force`. |
| `EBADPLATFORM`, native-library load or build failure | Preserve the actual error and try proot. Do not write empty replacement modules. |
| Missing official launcher or build output | Reinstall the npm release package. Do not try to compile an incomplete globally installed package with `tsc`. |
| Gateway readiness timeout | Startup waits up to 180 seconds. Inspect `~/openclaw-logs/runtime.log` and the actual port. Native timeout does not stop Gateway; it may still be starting, so avoid repeatedly restarting it. |
| Android stops background execution | Disable Termux battery optimization and check background permissions and wake lock. Neither tmux nor wake lock guarantees survival of Android process termination. |
| `dpkg` reports `end of file on stdin` at a conffile prompt | The updated installer preserves local configuration without waiting for that prompt. For an interrupted transaction, run `dpkg --force-confdef --force-confold --configure -a` inside Termux before retrying, not in Android `adb shell`. |
| `gateway auth mode is token, but no token was configured` | Regenerate service helpers using the updated installer. The token is passed through the environment rather than a multiply escaped literal `$OPENCLAW_GATEWAY_TOKEN` argument. Do not disable authentication. |

Do not use `pkill -9 node`: it kills unrelated Node services. Back up state before accepting configuration repairs proposed by Doctor.

### Gateway reported ready but remains unusable

`[gateway] ready` means the process reached its startup milestone, not that the UI, authentication, model, and channels all work. Check from another Termux session on the same phone; replace `18789` if configured differently:

```bash
node --version
openclaw --version
curl -i --max-time 5 http://127.0.0.1:18789/healthz
curl -I --max-time 5 http://127.0.0.1:18789/
```

Specify whether the installer reports failure, the page cannot open, authentication fails, or a model request fails, and provide the relevant output. Do not uninstall, delete state, or repeatedly update before preserving the failure.

- `watcher using fallback polling ... every 30000 ms`: skill-directory monitoring is using 30-second polling. [Upstream emits this message only for a ready watcher](https://github.com/openclaw/openclaw/blob/v2026.10.8/src/skills/runtime/refresh-observation-source.ts); it is not itself a process-exit report. `@openclaw/fs-safe@0.26.0` declares no Android native prebuild; installing CMake/Go does not establish Android native support.
- `fetch timeout ... clawhub.ai/v1/feeds/plugins`: a plugin-catalog network request timed out. [Upstream supports snapshot/bundled fallback](https://github.com/openclaw/openclaw/blob/v2026.10.8/src/plugins/official-external-plugin-catalog-hosted.ts). This proves neither successful model calls nor a stopped Gateway.
- npm install and package postinstall stdout/stderr now stream to the terminal and append to native `~/openclaw-logs/install.log` (`install-v2.log` for v2), preserving command failure status. Older installers did not save all output, so a past error may be unrecoverable there. Use `npm config get cache` to locate npm cache and inspect its `_logs` directory.

Logs may contain tokens, API keys, and addresses; share only redacted error excerpts. Isolated-clock checks cover an 84-second startup and the 180-second deadline, with real HTTP responses, failing-command output/status, and process matching that excludes installers named openclaw. This does not establish that every reported Android failure is fixed.

The automated regression also exercises a real Node process renamed to `openclaw-gateway`, restricting signals to fixture children and confirming installers and unrelated Node services survive. It requires POSIX `pkill` and Node and skips when unavailable; CLI safety tests still run.

## Backup and removal

Before upgrading or downgrading, back up `~/.openclaw`, shell configuration, and your work directories in the actual runtime environment. New releases may migrate state; downgrading only the npm package does not guarantee an older version can read migrated state. Backups contain credentials and must remain private.

```bash
# Run separately in native Termux or Ubuntu, as appropriate
cp -a ~/.openclaw ~/.openclaw.backup-$(date +%Y%m%d-%H%M%S)

# Native removal
bash install-openclaw-termux_En.sh --uninstall
```

The legacy native uninstall flow removes `~/.npm-global`, which may contain other tools. Do not use that option if the prefix is shared without first backing it up and reviewing what to remove. Manage proot removal separately; do not delete an Ubuntu environment that is still in use.

## Change log

### 2026-10-28: Modern OpenClaw compatibility

- Trim native/Ubuntu package lists and remove legacy native GYP configuration writes; detect OpenSSH and wake lock by their actual commands to avoid reinstalling available packages.

- Validate the selected release's full Node engine range and resolve versions before installation.
- Use the official `openclaw.mjs` launcher and replace wrappers without writing through npm symlinks.
- Remove the automatic updater-as-build step and incomplete-package source-build fallbacks.
- Remove fake native modules and unrelated global channel SDK installs; do not bypass platform checks.
- Use bounded HTTP readiness checks for native startup; stop pinning proot to Node 22.
- Update installation URLs, limitations, and verification guidance. Local checks do not replace Android device acceptance.

## Device-verification record

| Item | Observed result |
| --- | --- |
| Device and OS | Samsung SM-T510, Android 11, no root; 32-bit ARM userspace |
| Termux and runtime | Termux 0.119.0-beta.3; Node 24.22.1, npm 11.21.1, `process.arch=arm` |
| Release and entrypoint | OpenClaw 2026.10.8; Chinese native installer |
| Installation and upgrade recovery | Actual npm install, postinstall, and package upgrade preserving local configuration; normal installer exited 0 |
| Service management | Generated `ocr` restarted Gateway successfully; HTTP `/healthz` returned `ok: true` |
| Authentication | `openclaw health --json` returned `ok: true`, with no plugin-loading errors |
| Phone browser | Actual Chrome rendered model settings; Gateway logged the Control UI WebSocket connection and successful configuration read |

No model API key was entered, so model replies, messaging channels, vector storage, and related features remain unverified. The English, v2, and proot paths received code/local regression checks, not separate device acceptance. Startup took about 80 seconds and the device reported CPU pressure; a 2-second initial dashboard-probe timeout is not itself a stopped Gateway.

Device-driven fixes include noninteractive upgrades preserving local conffiles, skipping `clear` without a TTY, same-version repair with `--update`, and removal of multiply escaped Gateway token arguments. Skill-watcher polling warnings were not hidden.

## Local regression checks

Earlier macOS arm64 / Node 26.12.1 checks covered syntax for all four scripts, 33 CLI safety scenarios, actual pinned npm installation/postinstall, and wrapper plus HTTP readiness/timeout paths for all three native entrypoints. That round did not exercise Android; the new device results are scoped above.

Dependency cleanup was also exercised with an isolated minimal PATH: all three native dependency checks passed without compilers, Python, Go, `which`, or Termux:API and did not request package installation; the previous installer incorrectly requested packages in the same scenario. Actual v2 npm/git configuration also completed without creating `.gyp`.

```bash
python3 -m unittest discover -s tests -v
for script in *.sh; do bash -n "$script" || break; done
```

The CLI checks cover read-only help, invalid arguments, and dry-run preservation of user files. They do not replace on-device installation and model-request verification.

## Feedback

Include the installer used, Android/Termux versions, architecture, Node/OpenClaw versions, reproduction commands, and redacted error logs in [Issues](https://github.com/qq892601987/install-openclaw-on-termux/issues).
