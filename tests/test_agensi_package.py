"""Offline Agensi adapter checks: every executed script is an isolated temp file."""

import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import threading
import unittest


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "skills" / "coordinator-review-drive"


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


builder = load_module("crd_agensi_builder", ROOT / "scripts" / "build_agensi.py")
fixtures = load_module("crd_existing_wrapper_fixtures", ROOT / "tests" / "test_wrappers.py")


class AgensiBuildTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="crd-agensi-build-")
        self.addCleanup(temp.cleanup)
        self.base = Path(temp.name)

    def test_reproducible_build_copies_overrides_and_preserves_source(self):
        before = {p.relative_to(SOURCE): p.read_bytes() for p in SOURCE.rglob("*") if p.is_file()}
        docs = self.base / "docs"
        docs.mkdir()
        for name in builder.DOCUMENTS:
            (docs / name.replace(".md", ".source.md")).write_text(f"# Agensi {name}\n")
        first, second = self.base / "first", self.base / "second"
        report = builder.build_package(SOURCE, first, docs)
        again = builder.build_package(SOURCE, second, docs)
        self.assertEqual(report, again)
        self.assertEqual(report["scripts"], 15)
        self.assertEqual(report["templates"], 18)
        self.assertEqual(report["missing_documentation_overrides"], [])
        self.assertLessEqual(report["max_script_bytes"], 20_000)
        for name in builder.DOCUMENTS:
            self.assertEqual((first / name).read_text(), f"# Agensi {name}\n")
        self.assertFalse((first / "scripts/lib.zsh").exists())
        self.assertFalse((first / "scripts/launch-lane.sh").exists())
        self.assertFalse((first / "agents").exists())
        for path in (SOURCE / "templates").iterdir():
            self.assertEqual((first / "templates" / path.name).read_bytes(), path.read_bytes())
        self.assertEqual(before, {p.relative_to(SOURCE): p.read_bytes()
                                  for p in SOURCE.rglob("*") if p.is_file()})

    def test_rejects_unsafe_or_nonempty_outputs_without_replacing_files(self):
        with self.assertRaisesRegex(ValueError, "absolute"):
            builder.build_package(SOURCE, Path("relative-output"))
        forbidden = SOURCE / "do-not-create-agensi-output"
        with self.assertRaisesRegex(ValueError, "outside"):
            builder.build_package(SOURCE, forbidden)
        self.assertFalse(forbidden.exists())
        output = self.base / "existing"
        output.mkdir()
        sentinel = output / "user.txt"
        sentinel.write_text("keep me")
        with self.assertRaisesRegex(ValueError, "new or an empty"):
            builder.build_package(SOURCE, output)
        self.assertEqual(sentinel.read_text(), "keep me")


@unittest.skipUnless(shutil.which("zsh"), "zsh is required for isolated runner checks")
class AgensiIsolatedScriptTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.package_temp = tempfile.TemporaryDirectory(prefix="crd-agensi-package-")
        cls.addClassCleanup(cls.package_temp.cleanup)
        cls.package = Path(cls.package_temp.name) / "package"
        builder.build_package(SOURCE, cls.package)

    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="crd-agensi-runtime-")
        self.addCleanup(temp.cleanup)
        self.base = Path(temp.name)
        self.goal = self.base / "goal"
        self.cwd = self.base / "work tree"
        self.cwd.mkdir()
        self.prompt = self.base / "task.md"
        self.prompt.write_text("Do this bounded project task.\n", encoding="utf-8")
        self.record = self.base / "calls.json"
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.env = {key: value for key, value in os.environ.items() if not key.startswith("CRD_")}
        self.env.update({"ZDOTDIR": str(self.base), "CRD_STUB_RECORD": str(self.record),
                         "CRD_RETRY_BASE_SECONDS": "0"})
        stub = fixtures.STUB.replace(
            "if tool == 'codex':\n",
            "if tool == 'codex':\n    import time\n    time.sleep(float(os.environ.get('CRD_STUB_DELAY', '0')))\n",
            1,
        )
        for name in ("codex", "claude", "zcode", "dsh"):
            path = self.bin / name
            path.write_text(stub)
            path.chmod(0o755)
            self.env[f"CRD_{name.upper()}_BIN"] = str(path)
        result = self.run_script("init-goal.sh", self.goal, "Agensi isolated test")
        self.assertEqual(result.returncode, 0, result.stderr)

    def isolated_path(self, name):
        directory = Path(tempfile.mkdtemp(prefix="one-file-", dir=self.base))
        # Renaming proves the script does not rely on its package path or name.
        path = directory / ("temporary" + Path(name).suffix)
        path.write_bytes((self.package / "scripts" / name).read_bytes())
        path.chmod(0o755)
        self.assertEqual(list(directory.iterdir()), [path])
        return path

    def run_script(self, name, *args, env=None, timeout=8):
        path = self.isolated_path(name)
        shell = "bash" if name == "wait-lane.sh" else "zsh"
        try:
            result = subprocess.run([shell, str(path), *map(str, args)], cwd=self.base,
                                    env={**self.env, **(env or {})}, capture_output=True,
                                    text=True, stdin=subprocess.DEVNULL, timeout=timeout)
            self.assertEqual(list(path.parent.iterdir()), [path])
            return result
        finally:
            shutil.rmtree(path.parent)

    def calls(self):
        return json.loads(self.record.read_text()) if self.record.exists() else []

    def out(self, name):
        return self.goal / "lanes" / name

    def assert_finished(self, out, rc=0):
        self.assertTrue((out / "FINISHED_UTC").is_file())
        self.assertEqual((out / "EXIT_CODE").read_text().strip(), str(rc))
        self.assertTrue((out / "PID").read_text().strip().isdigit())

    def test_init_quotes_preserves_existing_and_creates_only_empty_project_records(self):
        title = 'Kevin "审查"\\scheduler\nphase two'
        goal = self.base / "quoted goal"
        result = self.run_script("init-goal.sh", goal, title)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual({path.name for path in goal.iterdir() if path.is_file()},
                         {"DECISIONS.md", "GOAL-STATE.json", "AGENT-LESSONS.md", "ALLOCATION.md", "LANES.txt"})
        state = json.loads((goal / "GOAL-STATE.json").read_text())
        self.assertEqual(state["goal"], title)
        self.assertEqual(state["lanes"], [])
        self.assertEqual(state["environment"]["agents"], [])
        self.assertEqual(state["sessions"], {})
        self.assertEqual(state["authority"]["real_providers"], "none")
        self.assertIsNone(state["baseline"]["dirty_entries"])
        lessons = (goal / "AGENT-LESSONS.md").read_text()
        self.assertLess(len(lessons), 1000)
        self.assertNotIn("Historical", lessons)
        (goal / "DECISIONS.md").write_text("User decision to preserve.\n")
        (goal / "POLICY-HEADER.txt").write_text("Project-specific existing constraint.\n")
        before = {path.name: path.read_bytes() for path in goal.iterdir() if path.is_file()}
        result = self.run_script("init-goal.sh", goal, "new title must not overwrite")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(before, {path.name: path.read_bytes() for path in goal.iterdir() if path.is_file()})

    def test_all_four_harness_runners_use_embedded_policy_without_package_siblings(self):
        cases = [
            ("run-codex.sh", "codex", (self.goal, "review", self.cwd, "read-only", "stub-model", "high", self.prompt, self.out("codex"))),
            ("run-claude.sh", "claude", (self.goal, "-", self.cwd, "stub-model", self.prompt, self.out("claude"))),
            ("run-zcode-review.sh", "zcode", (self.goal, self.cwd, self.prompt, self.out("zcode"), "label-only")),
            ("run-dsh.sh", "dsh", (self.goal, self.cwd, self.prompt, self.out("dsh"), "stub-provider", "stub-model", "high", "read-only")),
        ]
        for script, tool, args in cases:
            with self.subTest(script=script):
                result = self.run_script(script, *args)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assert_finished(self.out(tool))
                call = self.calls()[-1]
                prompt = call["stdin"] if tool in {"codex", "claude"} else call["args"][-1]
                self.assertIn("You are a single-role executor", prompt)
                self.assertIn("Never use --dangerously-bypass", prompt)
                self.assertIn("Do this bounded project task.", prompt)
        self.assertFalse((self.goal / "POLICY-HEADER.txt").exists())
        self.assertFalse((self.goal / "PREAMBLE-IMPLEMENTER.md").exists())

    def test_secondary_runner_variants_and_named_session_survive_temp_file_removal(self):
        for name in ("first", "resume"):
            result = self.run_script("run-codex.sh", self.goal, "persistent", self.cwd, "read-only",
                                     "stub-model", "high", self.prompt, self.out(name))
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[1]["args"][:3], ["exec", "resume", fixtures.SESSION])
        result = self.run_script("run-codex-web.sh", self.goal, "web", self.cwd, "stub-model", "high",
                                 self.prompt, self.out("web"), env={"CRD_CHROME_MCP_COMMAND": "offline-mcp",
                                 "CRD_CHROME_MCP_ARGS_JSON": '["--stub"]'})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_finished(self.out("web"))
        result = self.run_script("run-zcode-exec.sh", self.goal, self.cwd, self.prompt, self.out("edit"), "label-only")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_finished(self.out("edit"))
        self.assertEqual(self.calls()[-1]["args"][:2], ["--mode", "edit"])

    def test_user_project_policy_and_failure_result_are_preserved(self):
        (self.goal / "POLICY-HEADER.txt").write_text("USER PROJECT CONSTRAINT\n")
        result = self.run_script("run-codex.sh", self.goal, "failure", self.cwd, "read-only", "stub-model",
                                 "high", self.prompt, self.out("failure"), env={"CRD_STUB_RC": "7"})
        self.assertEqual(result.returncode, 7, result.stderr)
        self.assert_finished(self.out("failure"), 7)
        self.assertIn("USER PROJECT CONSTRAINT", self.calls()[0]["stdin"])

    def test_host_background_wrapper_and_separate_waiter_complete_without_launcher(self):
        path = self.isolated_path("run-codex.sh")
        out = self.out("background")
        process = subprocess.Popen(
            ["zsh", str(path), str(self.goal), "background", str(self.cwd), "read-only", "stub-model",
             "high", str(self.prompt), str(out)], cwd=self.base,
            env={**self.env, "CRD_STUB_DELAY": "0.3"}, stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        )
        try:
            result = self.run_script("wait-lane.sh", out, "--poll", "0.05", "--max", 5)
            stdout, stderr = process.communicate(timeout=5)
            self.assertEqual(process.returncode, 0, stderr + stdout)
            self.assertTrue(result.stdout.startswith("LANE DONE exit=0 output=ok"), result.stdout)
            self.assert_finished(out)
            self.assertFalse((out / "WRAPPER_PID").exists())
            self.assertEqual(list(path.parent.iterdir()), [path])
        finally:
            if process.poll() is None:
                process.kill()
                process.communicate()
            shutil.rmtree(path.parent)

    def test_mac_specific_runner_is_standalone_and_fails_closed_elsewhere(self):
        if os.uname().sysname == "Darwin":
            self.skipTest("native macOS sandbox execution is not part of these offline checks")
        result = self.run_script("run-zcode-test-exec.sh", self.goal, self.cwd, self.prompt,
                                 self.out("mac"), self.goal / "evidence")
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn("requires macOS sandbox-exec", result.stderr)
        self.assertEqual(self.calls(), [])

    def test_waiter_refreshes_late_pid_and_detects_precompletion_death(self):
        out = self.out("late-pid")
        out.mkdir()
        # Simulate host scheduling the waiter before the wrapper finishes startup.
        # This process deliberately dies without FINISHED_UTC after publishing PID.
        stub = (
            "import os,sys,time; from pathlib import Path; time.sleep(0.15); "
            "Path(sys.argv[1]).write_text(str(os.getpid())); sys.exit(9)"
        )
        process = subprocess.Popen([sys.executable, "-I", "-c", stub, str(out / "PID")],
                                   stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, text=True)
        # A real host reaps its background child. Do the same here so kill -0
        # observes disappearance rather than an intentionally unreaped zombie.
        reaper = threading.Thread(target=process.wait)
        reaper.start()
        try:
            result = self.run_script("wait-lane.sh", out, "--poll", "0.05", "--max", 2, "--stall", 10)
            reaper.join(timeout=2)
            process.communicate(timeout=2)
            self.assertEqual(process.returncode, 9)
            self.assertTrue(result.stdout.startswith("LANE DIED"), result.stdout)
            self.assertFalse((out / "FINISHED_UTC").exists())
        finally:
            if process.poll() is None:
                process.kill()
                process.communicate()
            reaper.join(timeout=2)


if __name__ == "__main__":
    unittest.main()
