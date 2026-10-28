"""CLI safety boundaries; no Android runtime is required.

Run: python3 -m unittest discover -s tests -v
"""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
NATIVE = (
    "install-openclaw-termux.sh",
    "install-openclaw-termux_En.sh",
    "install-openclaw-termux-v2.sh",
)
ALL = NATIVE + ("install_openclaw_termux_proot.sh",)


def snapshot(home):
    result = {}
    for path in sorted(home.rglob("*")):
        relative = str(path.relative_to(home))
        if path.is_symlink():
            result[relative] = ("symlink", os.readlink(path))
        elif path.is_dir():
            result[relative] = ("directory",)
        else:
            result[relative] = ("file", path.read_bytes(), path.stat().st_mode)
    return result


class InstallerCliSafety(unittest.TestCase):
    def run_cli(self, script, arguments, expected_success):
        with tempfile.TemporaryDirectory(prefix="openclaw-cli-") as tmp:
            home = Path(tmp)
            (home / ".bashrc").write_text("export EXISTING_SETTING=keep\n")
            (home / ".npmrc").write_text("registry=https://registry.npmjs.org/\n")
            state = home / ".openclaw"
            state.mkdir()
            (state / "openclaw.json").write_text('{"gateway":{"port":18999}}\n')
            before = snapshot(home)
            env = os.environ.copy()
            env.update(HOME=str(home), TERM="dumb", TMPDIR=str(home))
            # These paths must work without a Termux runtime or interactive input.
            env.pop("PREFIX", None)
            result = subprocess.run(
                ["bash", str(ROOT / script), *arguments],
                env=env,
                cwd=home,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                timeout=15,
            )
            if expected_success:
                self.assertEqual(result.returncode, 0, result.stdout)
            else:
                self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertEqual(snapshot(home), before, result.stdout)

    def test_help_is_read_only(self):
        for script in ALL:
            with self.subTest(script=script):
                self.run_cli(script, ["--help"], True)

    def test_invalid_options_fail_before_side_effects(self):
        for script in ALL:
            for args in (["--version"], ["--version", "--update"],
                         ["--version", "--update", "--help"],
                         ["--version", "^2026.10.8"], ["--unknown-option"]):
                with self.subTest(script=script, arguments=args):
                    self.run_cli(script, args, False)

    def test_dry_run_preserves_user_environment(self):
        for script in NATIVE:
            for args in (["--dry-run"],
                         ["--dry-run", "--update", "--version", "2026.10.8"],
                         ["--dry-run", "--uninstall"]):
                with self.subTest(script=script, arguments=args):
                    self.run_cli(script, args, True)


if __name__ == "__main__":
    unittest.main()
