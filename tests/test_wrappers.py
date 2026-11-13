"""Offline regression checks. Fake executables never call a model, browser or provider."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "skills" / "coordinator-review-drive" / "scripts"
SESSION = "12345678-1234-1234-1234-123456789abc"
STUB = r'''#!/usr/bin/env python3
import json, os, pathlib, sys
args = sys.argv[1:]
tool = pathlib.Path(sys.argv[0]).name
record = pathlib.Path(os.environ['CRD_STUB_RECORD'])
records = json.loads(record.read_text()) if record.exists() else []
stdin = sys.stdin.read() if tool in ('codex', 'claude') else ''
records.append({'tool': tool, 'args': args, 'stdin': stdin, 'cwd': os.getcwd(),
                'permission_mode': os.environ.get('DSH_PERMISSION_MODE')})
record.write_text(json.dumps(records))
if tool == 'codex':
    pathlib.Path(args[args.index('-o') + 1]).write_text('READY-FOR-REVIEW stub\n')
    print('session id: 12345678-1234-1234-1234-123456789abc')
elif tool == 'claude':
    if os.environ.get('CRD_STUB_BAD_JSON'):
        print('not JSON')
    else:
        print(json.dumps({'result': 'READY-FOR-REVIEW stub',
              'modelUsage': {'stub-model': {}}, 'session_id': 'stub-session',
              'is_error': bool(os.environ.get('CRD_STUB_ERROR'))}))
elif tool == 'dsh':
    if len(records) <= int(os.environ.get('CRD_STUB_FAILS', '0')):
        print(os.environ.get('CRD_STUB_FAILURE', 'dsh: SERVER: retry me'), file=sys.stderr)
        sys.exit(9)
    print('READY-FOR-REVIEW stub')
elif tool == 'zcode':
    print('stub ' + os.environ.get('CRD_STUB_REVIEW', 'REVIEW-END'))
sys.exit(int(os.environ.get('CRD_STUB_RC', '0')))
'''


@unittest.skipUnless(shutil.which("zsh"), "zsh is required for wrapper checks")
class WrapperTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="crd-offline-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name).resolve()  # macOS: /var -> /private/var
        self.goal = self.base / "goal"
        self.cwd = self.base / "work tree"
        self.cwd.mkdir()
        self.prompt = self.base / "task.md"
        # A linted card: launch-lane.sh refuses a card without the required header (check-card.sh).
        self.prompt.write_text(
            "CARD: research\nTRACK: main\nGOAL: answer one bounded stub question.\n"
            "ITEMS:\nI1: do the bounded stub task\nREPLY-CONTRACT — STATUS, GOAL, I1, EVIDENCE.\n",
            encoding="utf-8")
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.record = self.base / "calls.json"
        self.env = os.environ.copy()
        for key in list(self.env):
            if key.startswith("CRD_"):
                self.env.pop(key)
        # Avoid loading user-specific zsh startup configuration during offline checks.
        self.env["ZDOTDIR"] = str(self.base)
        self.env["CRD_STUB_RECORD"] = str(self.record)
        for tool in ("codex", "claude", "dsh", "zcode"):
            binary = self.bin / tool
            binary.write_text(STUB)
            binary.chmod(0o755)
            self.env[f"CRD_{tool.upper()}_BIN"] = str(binary)
        self.env["CRD_RETRY_BASE_SECONDS"] = "0"
        result = self.run_script("init-goal.sh", self.goal, "Offline test")
        self.assertEqual(result.returncode, 0, result.stderr)
        (self.goal / "POLICY-HEADER.txt").write_text("LOCAL POLICY HEADER\n")

    def run_script(self, script, *args, env=None, timeout=8):
        shell = "bash" if script in {"launch-lane.sh", "wait-lane.sh"} else "zsh"
        return subprocess.run(
            [shell, str(SCRIPTS / script), *map(str, args)], cwd=self.base,
            env={**self.env, **(env or {})}, capture_output=True, text=True,
            timeout=timeout, stdin=subprocess.DEVNULL,
        )

    def calls(self):
        return json.loads(self.record.read_text()) if self.record.exists() else []

    def out(self, name="out"):
        return self.goal / "lanes" / name

    def codex(self, name="out", session="review", env=None):
        return self.run_script("run-codex.sh", self.goal, session, self.cwd,
                               "read-only", "stub-model", "high", self.prompt,
                               self.out(name), env=env)

    def assert_finished(self, out, rc=0):
        self.assertTrue((out / "FINISHED_UTC").is_file())
        self.assertEqual((out / "EXIT_CODE").read_text().strip(), str(rc))
        self.assertEqual(json.loads((out / "DISPATCH.json").read_text())["cwd"], str(self.cwd))

    def test_init_escapes_json_and_preserves_existing_files(self):
        title = 'Kevin "审查"\\scheduler\nphase two'
        goal = self.base / "quoted goal"
        result = self.run_script("init-goal.sh", goal, title)
        self.assertEqual(result.returncode, 0, result.stderr)
        state = goal / "GOAL-STATE.json"
        self.assertEqual(json.loads(state.read_text())["goal"], title)
        before = {p.name: p.read_bytes() for p in goal.iterdir() if p.is_file()}
        self.assertEqual(self.run_script("init-goal.sh", goal, "replacement").returncode, 0)
        self.assertEqual(before, {p.name: p.read_bytes() for p in goal.iterdir() if p.is_file()})

    def test_codex_new_session_resume_and_policy(self):
        self.assertEqual(self.codex().returncode, 0)
        self.assert_finished(self.out())
        self.assertEqual((self.goal / "sessions/codex/review.id").read_text().strip(), SESSION)
        self.assertEqual(self.codex("resume").returncode, 0)
        first, second = self.calls()
        self.assertEqual(second["args"][:3], ["exec", "resume", SESSION])
        self.assertIn("LOCAL POLICY HEADER", first["stdin"])
        self.assertEqual(first["cwd"], str(self.cwd))
        self.assertFalse((self.goal / "sessions/codex/review.lock").exists())

    def test_codex_propagates_exit_and_refuses_out_reuse(self):
        result = self.codex(env={"CRD_STUB_RC": "7"})
        self.assertEqual(result.returncode, 7)
        self.assert_finished(self.out(), 7)
        before = (self.out() / "codex.log").read_bytes()
        result = self.codex()
        self.assertEqual(result.returncode, 2)
        self.assertEqual((self.out() / "codex.log").read_bytes(), before)
        self.assertEqual(len(self.calls()), 1)

    def test_codex_restricts_extra_args_and_session_path(self):
        for extra in ("--dangerously-bypass-approvals-and-sandbox", "-c sandbox_mode=danger-full-access"):
            result = self.codex(env={"CRD_CODEX_EXTRA": extra})
            self.assertEqual(result.returncode, 2)
        self.assertEqual(self.codex(session="review/../../escape").returncode, 2)
        self.assertEqual(self.calls(), [])
        result = self.codex(env={"CRD_CODEX_EXTRA": "-c service_tier=fast"})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("service_tier=fast", self.calls()[0]["args"])

    def test_live_session_lock_is_preserved(self):
        lock = self.goal / "sessions/codex/review.lock"
        lock.mkdir()
        (lock / "pid").write_text(str(os.getpid()))
        result = self.codex()
        self.assertEqual(result.returncode, 2)
        self.assertIn("session busy", result.stderr)
        self.assertTrue(lock.exists())
        self.assertEqual(self.calls(), [])

    def test_incomplete_session_lock_is_not_removed_by_racing_launcher(self):
        lock = self.goal / "sessions/codex/review.lock"
        lock.mkdir()
        result = self.codex()
        self.assertEqual(result.returncode, 2)
        self.assertIn("stale or incomplete session lock", result.stderr)
        self.assertTrue(lock.is_dir())
        self.assertEqual(self.calls(), [])

    def test_codex_web_builds_session_scoped_browser_config(self):
        for name in ("web", "web-resume"):
            result = self.run_script("run-codex-web.sh", self.goal, "web-review", self.cwd,
                                     "stub-model", "high", self.prompt, self.out(name),
                                     env={"CRD_CHROME_MCP_COMMAND": "offline-mcp",
                                          "CRD_CHROME_MCP_ARGS_JSON": '["--stub"]'})
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assert_finished(self.out(name))
        args = self.calls()[0]["args"]
        self.assertIn('mcp_servers.chrome.command="offline-mcp"', args)
        self.assertIn('mcp_servers.chrome.args=["--stub"]', args)
        self.assertIn('sandbox_workspace_write.network_access=true', args)
        self.assertEqual(self.calls()[1]["args"][:3], ["exec", "resume", SESSION])

    def test_launcher_runs_fake_lane_and_waiter_observes_completion(self):
        out = self.out("launched")
        result = self.run_script("launch-lane.sh", out, "zsh", SCRIPTS / "run-codex.sh",
                                 self.goal, "launched", self.cwd, "read-only", "stub-model",
                                 "high", self.prompt, out)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(result.stdout.strip().isdigit())
        self.assertTrue((out / "WRAPPER_START").is_file())
        self.assertTrue(os.path.samefile((out / "CARD_PATH").read_text().strip(), self.prompt))
        result = self.run_script("wait-lane.sh", out, "--poll", 1, "--max", 5)
        self.assertTrue(result.stdout.startswith("LANE DONE exit=0 output=ok"), result.stdout)
        # The stub reply has no STATUS/GOAL/item lines, so the reply contract check must flag it.
        self.assertTrue(result.stdout.splitlines()[1].startswith("REPORT-CHECK FAIL"), result.stdout)
        self.assert_finished(out)

    def test_wait_lane_detects_dead_wrapper_from_direct_pid_marker(self):
        out = self.out("dead")
        out.mkdir()
        dead_process = subprocess.Popen([shutil.which("true") or "/usr/bin/true"])
        dead_process.wait()
        (out / "PID").write_text(str(dead_process.pid))
        result = self.run_script("wait-lane.sh", out, "--poll", 1, "--max", 5)
        self.assertTrue(result.stdout.startswith("LANE DIED"), result.stdout)

    def test_claude_resume_and_model_usage(self):
        for out in ("claude", "claude-resume"):
            result = self.run_script("run-claude.sh", self.goal, "review", self.cwd,
                                     "stub-model", self.prompt, self.out(out))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assert_finished(self.out(out))
        self.assertEqual((self.out("claude") / "MODEL-USAGE.txt").read_text(), "stub-model\n")
        self.assertIn("--resume", self.calls()[1]["args"])
        self.assertIn("stub-session", self.calls()[1]["args"])

    def test_claude_invalid_output_and_bypass_are_failures(self):
        args = (self.goal, "-", self.cwd, "stub-model", self.prompt)
        result = self.run_script("run-claude.sh", *args, self.out("bypass"),
                                 env={"CRD_CLAUDE_PERMISSION_MODE": "bypassPermissions"})
        self.assertEqual(result.returncode, 2)
        self.assertEqual(self.calls(), [])
        result = self.run_script("run-claude.sh", *args, self.out("bad-json"),
                                 env={"CRD_STUB_BAD_JSON": "1"})
        self.assertEqual(result.returncode, 2)
        self.assert_finished(self.out("bad-json"), 2)
        result = self.run_script("run-claude.sh", *args, self.out("tool-error"),
                                 env={"CRD_STUB_ERROR": "1"})
        self.assertEqual(result.returncode, 1)
        self.assert_finished(self.out("tool-error"), 1)

    def test_dsh_retries_upstream_errors_only(self):
        args = (self.goal, self.cwd, self.prompt, self.out("dsh"), "stub-provider", "stub-model", "high")
        result = self.run_script("run-dsh.sh", *args, "read-only", env={"CRD_STUB_FAILS": "2"})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.calls()), 3)
        self.assertTrue(all(call["permission_mode"] == "read-only" for call in self.calls()))
        self.assertEqual(len((self.out("dsh") / "RETRIES.log").read_text().splitlines()), 2)
        self.assert_finished(self.out("dsh"))
        self.record.unlink()
        result = self.run_script("run-dsh.sh", self.goal, self.cwd, self.prompt, self.out("task-error"),
                                 "stub-provider", "stub-model", "high",
                                 env={"CRD_STUB_FAILS": "2", "CRD_STUB_FAILURE": "task failed"})
        self.assertEqual(result.returncode, 9)
        self.assertEqual(len(self.calls()), 1)
        self.assert_finished(self.out("task-error"), 9)

    def test_zcode_modes_policy_and_review_marker(self):
        for script, out, mode in (("run-zcode-exec.sh", "edit", "edit"),
                                  ("run-zcode-review.sh", "review", "plan")):
            result = self.run_script(script, self.goal, self.cwd, self.prompt, self.out(out), "label-only")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assert_finished(self.out(out))
            self.assertEqual(self.calls()[-1]["args"][:2], ["--mode", mode])
            self.assertIn("LOCAL POLICY HEADER", self.calls()[-1]["args"][-1])
        self.assertEqual((self.out("review") / "REVIEW-STATUS").read_text().strip(), "COMPLETE")
        result = self.run_script("run-zcode-review.sh", self.goal, self.cwd, self.prompt, self.out("incomplete"),
                                 env={"CRD_STUB_REVIEW": "missing marker"})
        self.assertEqual(result.returncode, 0)
        self.assertEqual((self.out("incomplete") / "REVIEW-STATUS").read_text().strip(), "INCOMPLETE")

    def test_zcode_explicit_missing_config_is_not_silently_ignored(self):
        result = self.run_script("run-zcode-exec.sh", self.goal, self.cwd, self.prompt, self.out(),
                                 env={"CRD_ZCODE_PROVIDER_CONFIG": str(self.base / "absent.json")})
        self.assertEqual(result.returncode, 2)
        self.assertEqual(self.calls(), [])

    def test_mac_sandbox_wrapper_fails_closed_on_other_platforms(self):
        if os.uname().sysname == "Darwin":
            self.skipTest("this check verifies the non-macOS dependency guard")
        result = self.run_script("run-zcode-test-exec.sh", self.goal, self.cwd, self.prompt,
                                 self.out(), self.goal / "evidence")
        self.assertEqual(result.returncode, 2)
        self.assertIn("requires macOS sandbox-exec", result.stderr)
        self.assertEqual(self.calls(), [])
        self.assertFalse(self.out().exists())

    def test_wait_lane_done_handles_existing_mtime_markers(self):
        self.assertEqual(self.codex().returncode, 0)
        (self.out() / "LAUNCHED_UTC").write_text("now\n")
        result = self.run_script("wait-lane.sh", self.out())
        self.assertEqual(result.returncode, 0)
        self.assertTrue(result.stdout.startswith("LANE DONE exit=0 output=ok"), result.stdout)
        self.assertEqual(result.stderr, "")

    def test_wait_lane_stall_and_pid_without_log_timeout(self):
        out = self.out("quiet")
        out.mkdir()
        for name in ("STARTED_UTC", "LAUNCHED_UTC", "odd\nlog.txt"):
            file = out / name
            file.write_text("stub\n")
            os.utime(file, (time.time() - 60, time.time() - 60))
        result = self.run_script("wait-lane.sh", out, "--stall", 1, "--max", 2, "--poll", 1)
        self.assertTrue(result.stdout.startswith("LANE STALL"), result.stdout)
        self.assertEqual(result.stderr, "")
        result = self.run_script("wait-lane.sh", "--pid", os.getpid(), "--log", self.base / "no-log",
                                 "--stall", 60, "--max", 0, "--poll", 1)
        self.assertTrue(result.stdout.startswith("PID TIMEOUT"), result.stdout)

    def test_wait_lanes_reports_and_marks_seen(self):
        self.assertEqual(self.codex().returncode, 0)
        lanes = self.goal / "LANES.offline.txt"
        lanes.write_text("lanes/out review\n")
        result = self.run_script("wait-lanes.sh", self.goal, lanes, 1, 1)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(result.stdout.startswith("DONE review exit=0"), result.stdout)
        self.assertTrue((self.out() / ".seen").exists())
        result = self.run_script("wait-lanes.sh", self.goal, lanes, 1, 1)
        self.assertTrue(result.stdout.startswith("ALL-SEEN"), result.stdout)

    def test_launcher_preserves_used_output(self):
        self.assertEqual(self.codex().returncode, 0)
        before = (self.out() / "LAST-MESSAGE.md").read_bytes()
        result = self.run_script("launch-lane.sh", self.out(), "/bin/true")
        self.assertEqual(result.returncode, 2)
        self.assertEqual((self.out() / "LAST-MESSAGE.md").read_bytes(), before)
        self.assertFalse((self.out() / "launcher.log").exists())
        self.assertEqual(self.run_script("launch-lane.sh").returncode, 2)

    def test_shared_dependency_path_traversal_rejected_before_git_write(self):
        for bad in ("../escape", "/absolute", "deps/../../escape", ".git"):
            result = self.run_script("make-lane-worktree.sh", self.cwd, self.base / "worktrees",
                                     "lane", "HEAD", bad)
            self.assertEqual(result.returncode, 2)
            self.assertIn("shared-relpath", result.stderr)
        self.assertFalse((self.base / "worktrees").exists())

    def test_chrome_supervisor_terminates_and_releases_lock_with_fake_probe(self):
        # A successful fake curl suppresses every browser launch and every process lookup.
        curl = self.bin / "curl"
        curl.write_text("#!/bin/sh\nexit 0\n")
        curl.chmod(0o755)
        pgrep = self.bin / "pgrep"
        pgrep.write_text("#!/bin/sh\nexit 1\n")
        pgrep.chmod(0o755)
        chrome = self.bin / "fake-chrome"
        chrome.write_text("#!/bin/sh\nexit 99\n")
        chrome.chmod(0o755)
        profile = self.base / "browser profile"
        env = {**self.env, "PATH": str(self.bin) + os.pathsep + self.env["PATH"],
               "CRD_CHROME_CHECK_SECONDS": "1"}
        process = subprocess.Popen(["zsh", str(SCRIPTS / "chrome-supervisor.sh"), "9333", str(profile), str(chrome)],
                                   cwd=self.base, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            deadline = time.monotonic() + 3
            while not Path(str(profile) + ".supervisor.pid").exists() and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue(Path(str(profile) + ".supervisor.lock").exists())
            process.terminate()
            process.communicate(timeout=4)
            self.assertEqual(process.returncode, 143)
            self.assertFalse(Path(str(profile) + ".supervisor.lock").exists())
            self.assertNotIn("(re)started", Path(str(profile) + ".supervisor.log").read_text())
        finally:
            if process.poll() is None:
                process.kill()
                process.communicate()


if __name__ == "__main__":
    unittest.main()
