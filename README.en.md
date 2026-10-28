# OpenClaw on Termux

Install, update, and manage OpenClaw Gateway on Android with Termux.

[中文](README.md) · [OpenClaw upstream](https://github.com/openclaw/openclaw) · [Report an issue](https://github.com/qq892601987/install-openclaw-on-termux/issues)

![OpenClaw on Termux Preview](./sources/OpenClaw-on-Termux-Preview.png)

## Compatibility and limitations

This update targets the published contract of OpenClaw **2026.10.8**. **Android/Termux device acceptance is still pending**; this is not a claim that every feature works on that version.

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
| `--update`, `-U` | Skip the package-update confirmation; configuration may still prompt |
| `--uninstall`, `-u` | Uninstall and remove managed configuration; back up first |

```bash
# Example version, not a device-tested compatibility guarantee
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
| Gateway readiness timeout | Inspect `~/openclaw-logs/runtime.log`, port conflicts, and `openclaw doctor` output. A tmux session alone is not considered success. |
| Android stops background execution | Disable Termux battery optimization and check background permissions and wake lock. Neither tmux nor wake lock guarantees survival of Android process termination. |

Do not use `pkill -9 node`: it kills unrelated Node services. Back up state before accepting configuration repairs proposed by Doctor.

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

- Validate the selected release's full Node engine range and resolve versions before installation.
- Use the official `openclaw.mjs` launcher and replace wrappers without writing through npm symlinks.
- Remove the automatic updater-as-build step and incomplete-package source-build fallbacks.
- Remove fake native modules and unrelated global channel SDK installs; do not bypass platform checks.
- Use bounded HTTP readiness checks for native startup; stop pinning proot to Node 22.
- Update installation URLs, limitations, and verification guidance. Local checks do not replace Android device acceptance.

## Local regression checks

Verified locally on macOS arm64 / Node 26.12.1: syntax for all four scripts, 33 CLI safety scenarios, actual pinned npm installation and postinstall, and wrapper plus HTTP readiness/timeout paths for all three native entrypoints. A real OpenClaw 2026.10.8 Gateway returned `{"ok":true,"status":"live"}` at `/healthz`. Service-management commands were isolated; Android pkg, tmux, proot, and actual model calls were not exercised.

```bash
python3 -m unittest discover -s tests -v
for script in *.sh; do bash -n "$script" || break; done
```

The CLI checks cover read-only help, invalid arguments, and dry-run preservation of user files. They do not replace on-device installation and model-request verification.

## Feedback

Include the installer used, Android/Termux versions, architecture, Node/OpenClaw versions, reproduction commands, and redacted error logs in [Issues](https://github.com/qq892601987/install-openclaw-on-termux/issues).
