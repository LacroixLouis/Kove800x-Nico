"""Shell control-flow tests with fake Apple tools; these do NOT compile iOS."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class MacBuildScriptTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="nico mac test ")
        self.root = Path(self.temporary.name)
        self.tools = self.root / "fake tools"
        self.tools.mkdir()
        self.project = self.root / "project with spaces"
        (self.project / "scripts").mkdir(parents=True)
        original = Path(__file__).resolve().parents[2] / "scripts" / "build-and-install.sh"
        self.script = self.project / "scripts" / original.name
        shutil.copy2(original, self.script)
        self.marker = self.root / "installed"
        self.env = dict(os.environ, PATH=str(self.tools) + os.pathsep + os.environ["PATH"],
                        FAKE_INSTALL_MARKER=str(self.marker))
        self.fake("uname", "echo Darwin")
        self.fake("swift", 'if [[ "${FAIL_STAGE:-}" == tests ]]; then exit 3; fi')
        self.fake("codesign", 'if [[ "${FAIL_STAGE:-}" == signature ]]; then exit 4; fi')
        self.fake("xcodebuild", '''
if [[ "${FAIL_STAGE:-}" == build ]]; then exit 5; fi
while [[ $# -gt 0 ]]; do
    if [[ "$1" == -derivedDataPath ]]; then
        mkdir -p "$2/Build/Products/Debug-iphoneos/KoveMirror.app"
        break
    fi
    shift
done
''')
        self.fake("xcrun", '''
[[ "$1" == devicectl && "$2" == device && "$3" == install && "$4" == app ]] || exit 6
[[ -d "$7" ]] || exit 7
touch "$FAKE_INSTALL_MARKER"
''')

    def tearDown(self):
        self.temporary.cleanup()

    def fake(self, name, body):
        path = self.tools / name
        path.write_text("#!/bin/bash\nset -euo pipefail\n" + body + "\n")
        path.chmod(0o755)

    def run_build(self, *args):
        return subprocess.run(["bash", str(self.script), *args], env=self.env,
                              text=True, capture_output=True)

    def test_paths_with_spaces_and_successful_sequence(self):
        result = self.run_build("ABC123DEF4", "00008110-0011223344556677")
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertTrue(self.marker.exists())

    def test_tests_build_or_signature_failure_prevent_install(self):
        for stage in ["tests", "build", "signature"]:
            with self.subTest(stage=stage):
                self.env["FAIL_STAGE"] = stage
                result = self.run_build("ABC123DEF4", "00008110-0011223344556677")
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.marker.exists())

    def test_invalid_or_missing_identifiers_prevent_install(self):
        for args in [(), ("bad", "123"), ("ABC123DEF4", "$(touch x)"),
                     ("ABC123DEF4", "00008110-0011223344556677", "extra")]:
            with self.subTest(args=args):
                result = self.run_build(*args)
                self.assertEqual(result.returncode, 2)
                self.assertFalse(self.marker.exists())


if __name__ == "__main__":
    unittest.main()
