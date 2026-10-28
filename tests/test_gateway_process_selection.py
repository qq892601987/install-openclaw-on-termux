"""Protect installers and unrelated services when stopping a renamed Gateway."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
NODE = shutil.which("node")
PKILL = shutil.which("pkill")
BASH = shutil.which("bash")
SCRIPTS = (
    "install-openclaw-termux.sh",
    "install-openclaw-termux_En.sh",
    "install-openclaw-termux-v2.sh",
)


@unittest.skipUnless(os.name == "posix" and NODE and PKILL and BASH,
                     "requires POSIX process tools and Node.js")
class GatewayProcessSelection(unittest.TestCase):
    def test_stop_targets_gateways_not_installer_or_other_node(self):
        for script in SCRIPTS:
            with self.subTest(script=script), tempfile.TemporaryDirectory() as tmp:
                env = os.environ.copy()
                env.update(HOME=tmp, TERM="dumb")
                if script.endswith("-v2.sh"):
                    command = ('source "$1" --dry-run --yes >/dev/null || exit; '
                               'openclaw_gateway_process_pattern')
                else:
                    command = ('source "$1" --dry-run >/dev/null || exit; '
                               'printf "%s" "$GATEWAY_PROCESS_PATTERN"')
                pattern = subprocess.check_output(
                    [BASH, "-c", command, "fixture", str(ROOT / script)],
                    env=env, text=True, timeout=15,
                )
                base = str(Path(tmp) / ".npm-global/lib/node_modules/openclaw")
                titles = (
                    "openclaw-gateway",
                    "node " + base + "/openclaw.mjs gateway",
                    "node " + base + "/dist/entry.js gateway",
                    "bash " + tmp + "/openclaw-install.sh",
                    "node " + tmp + "/unrelated-service.js",
                )
                children = []
                try:
                    for title in titles:
                        child = subprocess.Popen(
                            [NODE, "-e", 'process.title=process.argv[1]; '
                             'console.log(process.title); setInterval(()=>{},1000)', title],
                            stdout=subprocess.PIPE, text=True,
                        )
                        children.append(child)
                        # Synchronize on the actual title change, not a startup sleep.
                        self.assertEqual(child.stdout.readline().strip(), title)
                    # Limit real signals to our own children, regardless of the pattern.
                    result = subprocess.run(
                        [PKILL, "-9", "-P", str(os.getpid()), "-f", pattern],
                        capture_output=True, text=True, timeout=10,
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)
                    for child in children[:3]:
                        self.assertNotEqual(child.wait(timeout=5), 0)
                    for child in children[3:]:
                        self.assertIsNone(child.poll(), "stopped an unrelated process")
                finally:
                    for child in children:
                        if child.poll() is None:
                            child.kill()
                        child.wait()
                        child.stdout.close()


if __name__ == "__main__":
    unittest.main()
