"""Offline checks for the coordinator's verdict scripts and guarded actions.

Everything runs in temporary directories with throwaway git repositories and processes. No network, no model,
no harness CLI is called.
"""
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import textwrap
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "skills" / "coordinator-review-drive" / "scripts"
TEMPLATES = ROOT / "skills" / "coordinator-review-drive" / "templates"

IMPL_CARD = """\
CARD: fix
TRACK: main
GOAL: a user who saves a draft sees it again after a refresh.
DONE-EVIDENCE: test_save_roundtrip passes on the real service path; page step 3 shows the saved text.
SCOPE: src/drafts/
FORBIDDEN: other lanes' files; commit; push.
ITEMS:
I1: reproduce the lost save with a failing test
I2: fix the save path
REPLY-CONTRACT — your final message: STATUS, GOAL, one line per item, EVIDENCE, RESOURCE-HANDOFF.
"""

IMPL_REPLY = """\
STATUS: READY-FOR-REVIEW
GOAL: saved drafts survive a refresh.
I1: done
I2: done
EVIDENCE:
$ python3 -m pytest -q tests/test_drafts.py
RED before fix: 1 failed — AssertionError: '' != 'hello'
after fix: 2 passed in 0.10s
RESOURCE-HANDOFF: none created
"""

REVIEW_CARD = """\
CARD: review
TRACK: main
GOAL: a user who saves a draft sees it again after a refresh.
REVIEW-SHA: 0123456789abcdef
ITEMS:
I1: walk every path-matrix row
REPLY-CONTRACT — list every provable issue; end with a COVERAGE block and REVIEW-END.
"""


def clean_env(base):
    env = {k: v for k, v in os.environ.items() if not k.startswith(("CRD_", "GIT_"))}
    env.update({"ZDOTDIR": str(base), "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1",
                "GIT_AUTHOR_NAME": "Offline Test", "GIT_AUTHOR_EMAIL": "offline@example.invalid",
                "GIT_COMMITTER_NAME": "Offline Test", "GIT_COMMITTER_EMAIL": "offline@example.invalid",
                "LC_ALL": "C"})
    env.pop("COAUTHOR", None)
    env.pop("WIP_OVERRIDE", None)
    env.pop("LEGACY_CARD", None)
    return env


class ScriptCase(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="crd-checks-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name).resolve()
        self.env = clean_env(self.base)

    def run_script(self, script, *args, env=None, cwd=None, timeout=20):
        shell = "zsh" if script == "init-goal.sh" else "bash"
        return subprocess.run([shell, str(SCRIPTS / script), *map(str, args)], cwd=cwd or self.base,
                              env={**self.env, **(env or {})}, capture_output=True, text=True,
                              timeout=timeout, stdin=subprocess.DEVNULL)

    def write(self, path, text):
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return path

    def git(self, repo, *args):
        result = subprocess.run(["git", "-C", str(repo), *args], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def make_repo(self, name="repo"):
        repo = self.base / name
        repo.mkdir()
        self.git(repo, "init", "-q", "-b", "main")
        self.write(repo / "a.txt", "one\n")
        self.git(repo, "add", "a.txt")
        self.git(repo, "commit", "-q", "-m", "base")
        return repo


class CardAndReportTests(ScriptCase):
    def test_card_passes_with_full_header(self):
        result = self.run_script("check-card.sh", self.write(self.base / "TASK-OK.md", IMPL_CARD))
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertTrue(result.stdout.startswith("CARD-CHECK PASS type=fix"), result.stdout)

    def test_card_fails_on_unknown_type_and_missing_fields(self):
        card = IMPL_CARD.replace("CARD: fix", "CARD: banana").replace("SCOPE: src/drafts/\n", "")
        result = self.run_script("check-card.sh", self.write(self.base / "TASK-BAD.md", card))
        self.assertEqual(result.returncode, 1)
        self.assertIn("got 'banana'", result.stdout)
        result = self.run_script("check-card.sh", self.write(self.base / "TASK-NOSCOPE.md",
                                                            IMPL_CARD.replace("SCOPE: src/drafts/\n", "")))
        self.assertEqual(result.returncode, 1)
        self.assertIn("SCOPE:", result.stdout)

    def test_card_header_after_contract_does_not_count(self):
        # A card whose header lines appear only after REPLY-CONTRACT (e.g. echoed from the contract) is not scoped.
        card = "CARD: fix\nREPLY-CONTRACT\nTRACK: main\nGOAL: g\nDONE-EVIDENCE: d\nSCOPE: s\nFORBIDDEN: f\nITEMS:\nI1: x\n"
        result = self.run_script("check-card.sh", self.write(self.base / "TASK-LATE.md", card))
        self.assertEqual(result.returncode, 1)
        for field in ("GOAL:", "TRACK: main|side", "ITEMS:", "item I1:", "DONE-EVIDENCE:"):
            self.assertIn(field, result.stdout)

    def test_card_must_name_forbidden_tests(self):
        lanes = self.base / "goal" / "lanes" / "area"
        self.write(self.base / "goal" / "FORBIDDEN-TESTS.txt", "tests/test_slow_live.py  # never run\n")
        result = self.run_script("check-card.sh", self.write(lanes / "TASK-A.md", IMPL_CARD))
        self.assertEqual(result.returncode, 1)
        self.assertIn("forbidden test not named: tests/test_slow_live.py", result.stdout)
        named = IMPL_CARD.replace("push.", "push; never run test_slow_live.py.")
        self.assertEqual(self.run_script("check-card.sh", self.write(lanes / "TASK-B.md", named)).returncode, 0)

    def test_report_passes_complete_reply(self):
        card = self.write(self.base / "TASK.md", IMPL_CARD)
        result = self.run_script("check-report.sh", self.write(self.base / "reply.md", IMPL_REPLY), card)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertTrue(result.stdout.startswith("REPORT-CHECK PASS type=fix"), result.stdout)

    def test_report_fails_not_done_item_and_missing_evidence(self):
        card = self.write(self.base / "TASK.md", IMPL_CARD)
        for bad, expected in ((IMPL_REPLY.replace("I2: done", "I2: not done"), "I2: done | skip"),
                              (IMPL_REPLY.replace("I2: done", "I2: skip"), "I2: done | skip"),
                              (IMPL_REPLY.replace("$ python3", "python3"), "EVIDENCE command lines"),
                              (IMPL_REPLY.replace("RED before fix", "first run"), "RED-before-fix"),
                              (IMPL_REPLY.replace("RESOURCE-HANDOFF: none created\n", ""), "RESOURCE-HANDOFF")):
            result = self.run_script("check-report.sh", self.write(self.base / "bad.md", bad), card)
            self.assertEqual(result.returncode, 1, bad)
            self.assertIn(expected, result.stdout)
        result = self.run_script("check-report.sh", self.base / "absent.md", card)
        self.assertEqual(result.returncode, 1)

    def test_review_findings_need_proof_and_coverage(self):
        card = self.write(self.base / "REVIEW.md", REVIEW_CARD)
        reply = textwrap.dedent("""\
            STATUS: REQUEST_CHANGES
            GOAL: drafts survive a refresh.
            I1: done
            F1 P1 src/drafts/save.py:42 — the refresh reads a stale cache
            PROOF: $ python3 -m pytest -q tests/test_refresh.py → 1 failed
            F2 P2 src/drafts/api.py:7 — error code is generic
            COVERAGE:
            M1: checked — F1
            REVIEW-END
            """)
        result = self.run_script("check-report.sh", self.write(self.base / "r1.md", reply), card)
        self.assertEqual(result.returncode, 1)
        self.assertIn("PROOF for findings: F2", result.stdout)
        fixed = reply.replace("is generic\n", "is generic\nPROOF: quoted excerpt at REVIEW-SHA: raise Error()\n")
        result = self.run_script("check-report.sh", self.write(self.base / "r2.md", fixed), card)
        self.assertEqual(result.returncode, 0, result.stdout)
        no_cov = fixed.replace("COVERAGE:\nM1: checked — F1\n", "")
        result = self.run_script("check-report.sh", self.write(self.base / "r3.md", no_cov), card)
        self.assertEqual(result.returncode, 1)
        self.assertIn("COVERAGE block", result.stdout)

    def test_published_review_templates_pass_the_card_lint(self):
        for name in ("REVIEW-SECOND.md", "REVIEW-KEY-DESIGN.md", "TASK-CARD.md", "WEB-TESTER-TASK.md"):
            text = (TEMPLATES / name).read_text(encoding="utf-8")
            blocks = [b.split("```", 1)[0] for b in text.split("```\n")[1::2] if "CARD:" in b]
            self.assertTrue(blocks, name)
            for index, block in enumerate(blocks):
                result = self.run_script("check-card.sh", self.write(self.base / f"{name}-{index}.md", block))
                self.assertEqual(result.returncode, 0, f"{name} block {index}: {result.stdout}")


class GoalLedgerTests(ScriptCase):
    def setUp(self):
        super().setUp()
        self.goal = self.base / "goal"
        self.assertEqual(self.run_script("init-goal.sh", self.goal, "Offline").returncode, 0)
        self.write(self.goal / "HANDOFF.md", textwrap.dedent("""\
            MAIN-GOAL: drafts — saved drafts survive a refresh
            PREDICATE: fresh account, 5/5 steps on the real page
            PROGRESS: 2/5 — steps passed
            ENV: test instance on a local port
            NEXT: run the replay
            WIP: main | fix-save | fix the save path | running | lanes/fix-save
            """))
        self.evidence = self.write(self.base / "evidence.txt", "evidence\n")

    def log(self, *args):
        result = self.run_script("log-run.sh", self.goal, "drafts", *args)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def check(self):
        return self.run_script("goal-check.sh", self.goal)

    def stuck_line(self):
        return next(line for line in self.check().stdout.splitlines() if line.startswith("STUCK-CHECK"))

    def test_handoff_and_no_runs(self):
        result = self.check()
        self.assertIn("HANDOFF OK: goal=drafts", result.stdout)
        self.assertIn("STUCK-CHECK NO-RUNS", result.stdout)
        self.assertIn("WIP OK: main=1 side=0", result.stdout)

    def test_two_failed_page_runs_are_stuck_until_an_unstuck_record(self):
        self.log("page", "abcdef1", 2, 5, "FAIL", self.evidence, "save 500")
        self.assertTrue(self.stuck_line().startswith("STUCK-CHECK OK"), self.stuck_line())
        self.log("replay", "abcdef1", 5, 5, "PASS", self.evidence)
        self.log("page", "abcdef1", 3, 5, "FAIL", self.evidence, "refresh empty")
        line = self.stuck_line()
        self.assertTrue(line.startswith("STUCK-CHECK STUCK"), line)  # a replay PASS does not reset the counter
        self.assertIn("2 failed page runs", line)
        self.assertEqual(self.check().returncode, 1)
        # A side lane is refused while stuck; WIP_OVERRIDE lets it through and records the reason.
        side = self.write(self.goal / "lanes" / "TASK-SIDE.md", IMPL_CARD.replace("TRACK: main", "TRACK: side"))
        result = self.run_script("launch-lane.sh", self.goal / "lanes" / "out-side", "/bin/sleep", "0", side)
        self.assertEqual(result.returncode, 2)
        self.assertIn("side lane while the goal needs attention", result.stderr)
        self.assertFalse((self.goal / "lanes" / "out-side").exists())
        result = self.run_script("launch-lane.sh", self.goal / "lanes" / "out-side2", "/bin/sleep", "0", side,
                                 env={"WIP_OVERRIDE": "release blocker"})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("release blocker", (self.goal / "lanes" / "out-side2" / "WIP_OVERRIDE").read_text())
        # An incomplete unstuck record is refused; a complete one resets the counters.
        record = self.goal / "unstuck" / "drafts.md"
        template = (TEMPLATES / "UNSTUCK-RECORD.md").read_text(encoding="utf-8")
        self.write(record, template)
        result = self.run_script("log-run.sh", self.goal, "drafts", "unstuck", record)
        self.assertEqual(result.returncode, 1)
        self.assertIn("placeholders", result.stdout)
        self.write(record, template.replace("<fill", "filled"))
        self.log("unstuck", record)
        self.assertTrue(self.stuck_line().startswith("STUCK-CHECK OK"), self.stuck_line())

    def test_repeated_blocker_and_met(self):
        for sha in ("abcdef1", "abcdef2", "abcdef3"):
            self.log("replay", sha, 2, 5, "FAIL", self.evidence, "save 500")
        self.assertIn("blocker 'save_500' seen in >= 3 runs", self.stuck_line())
        self.log("page", "abcdef4", 5, 5, "PASS", self.evidence)
        self.assertTrue(self.stuck_line().startswith("STUCK-CHECK MET"), self.stuck_line())

    def test_log_run_refuses_inconsistent_rows(self):
        for args in (("page", "abcdef1", 4, 5, "PASS", self.evidence),
                     ("page", "abcdef1", 4, 5, "FAIL", self.evidence),
                     ("page", "not-a-sha", 4, 5, "FAIL", self.evidence, "x"),
                     ("page", "abcdef1", 4, 5, "FAIL", self.base / "missing", "x")):
            result = self.run_script("log-run.sh", self.goal, "drafts", *args)
            self.assertEqual(result.returncode, 1, args)
        self.assertFalse((self.goal / "RUNS.tsv").exists())

    def test_preflight_refuses_page_run_without_replay(self):
        tree = self.make_repo("instance")
        common = ("--min-free-gb", 0, "--max-load", 100000)
        result = self.run_script("preflight-run.sh", self.goal, "page", tree, *common)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("REPLAY FAIL", result.stdout)
        self.assertTrue(result.stdout.splitlines()[-1].startswith("PREFLIGHT FAIL kind=page"))
        sha = self.git(tree, "rev-parse", "HEAD")
        self.log("replay", sha, 5, 5, "PASS", self.evidence)
        result = self.run_script("preflight-run.sh", self.goal, "page", tree, *common)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("REPLAY OK", result.stdout)
        self.assertTrue(result.stdout.splitlines()[-1].startswith("PREFLIGHT WARN"))  # no --port / --log given


class LogScanTests(ScriptCase):
    def test_byte_mark_window_reads_only_new_bytes(self):
        log = self.base / "backend.log"
        mark = self.base / "LOG-MARK"
        secret = "pass" + "word=hunter2"  # built at runtime so the repository privacy scan stays clean
        self.write(log, "ERROR boom in save handler\n" * 3 + f"ERROR {secret} rejected\n")
        result = self.run_script("scan-logs.sh", "--mark", mark, "--update-mark", log)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("blockers=1", result.stdout)
        self.assertNotIn("hunter2", result.stdout)
        self.assertIn("<REDACTED>", result.stdout)
        self.assertTrue(mark.is_file())
        with log.open("a", encoding="utf-8") as handle:
            handle.write("INFO all good\n" * 5)
        result = self.run_script("scan-logs.sh", "--mark", mark, "--update-mark", log)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("lines=5", result.stdout)
        self.assertIn("window=[since the --mark offsets]", result.stdout)
        with log.open("a", encoding="utf-8") as handle:
            handle.write("ValueError: new failure in refresh\n" * 4)
        result = self.run_script("scan-logs.sh", "--mark", mark, log)
        self.assertEqual(result.returncode, 1)
        self.assertIn("lines=4", result.stdout)
        self.assertNotIn("boom in save handler", result.stdout)
        # Without --update-mark the mark is not advanced; an ack line suppresses the signature.
        ack = self.write(self.base / "LOG-ACK.txt", "new failure in refresh  # D-007 known, fix queued\n")
        result = self.run_script("scan-logs.sh", "--mark", mark, "--ack", ack, log)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("ack", result.stdout)

    def test_usage_errors(self):
        self.assertEqual(self.run_script("scan-logs.sh").returncode, 2)
        self.assertEqual(self.run_script("scan-logs.sh", "--min").returncode, 2)
        self.assertEqual(self.run_script("scan-logs.sh", "--update-mark", self.base / "x.log").returncode, 2)


class LaneProcessTests(ScriptCase):
    def wait_gone(self, pid, seconds=10):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                return True
            except PermissionError:
                return False
            time.sleep(0.1)
        return False

    def launch_sleep(self, name):
        out = self.base / name
        result = self.run_script("launch-lane.sh", out, "/bin/sleep", "60")
        self.assertEqual(result.returncode, 0, result.stderr)
        pid = int(result.stdout.strip())
        self.addCleanup(self.reap, pid)
        deadline = time.monotonic() + 5  # perl calls setsid() right after the launcher returns
        while os.getpgid(pid) != pid and time.monotonic() < deadline:
            time.sleep(0.05)
        return out, pid

    @staticmethod
    def reap(pid):
        try:
            if os.getpgid(pid) == pid:  # only the lane's own group, never a recycled PID's group
                os.killpg(pid, 9)
        except (ProcessLookupError, PermissionError):
            pass

    def test_launch_refuses_failing_card_and_used_out(self):
        bad = self.write(self.base / "TASK-BAD.md", "Do something.\n")
        result = self.run_script("launch-lane.sh", self.base / "out-bad", "/bin/sleep", "0", bad)
        self.assertEqual(result.returncode, 2)
        self.assertIn("CARD-CHECK FAIL", result.stderr)
        self.assertFalse((self.base / "out-bad").exists())
        result = self.run_script("launch-lane.sh", self.base / "out-legacy", "/bin/sleep", "0", bad,
                                 env={"LEGACY_CARD": "1"})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.base / "out-legacy" / "LEGACY_CARD").exists())
        self.assertEqual(self.run_script("launch-lane.sh", "", "/bin/true").returncode, 2)

    def test_lane_runs_in_its_own_group_and_kill_lane_stops_only_it(self):
        out, pid = self.launch_sleep("out-kill")
        self.assertEqual(os.getpgid(pid), pid)
        self.assertNotEqual(os.getpgid(pid), os.getpgid(0))
        result = self.run_script("kill-lane.sh", out)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("KILL-LANE done", result.stdout)
        self.assertTrue(self.wait_gone(pid))
        self.assertTrue((out / "KILLED_UTC").is_file())
        self.assertEqual(self.run_script("kill-lane.sh", self.base / "nothing").returncode, 1)

    def test_kill_lane_refuses_a_pid_that_does_not_lead_its_group(self):
        child = subprocess.Popen(["/bin/sleep", "60"])
        self.addCleanup(lambda: (child.kill(), child.wait()))
        out = self.base / "out-legacy-group"
        out.mkdir()
        (out / "WRAPPER_PID").write_text(str(child.pid))
        result = self.run_script("kill-lane.sh", out)
        self.assertEqual(result.returncode, 1)
        self.assertIn("not its own group leader", result.stdout)
        self.assertIsNone(child.poll())

    def test_kill_lane_refuses_reused_pid(self):
        probe = subprocess.run(["ps", "-o", "lstart=", "-p", str(os.getpid())], capture_output=True, text=True)
        if sys.platform != "darwin" and not probe.stdout.strip():
            self.skipTest("ps lstart is unavailable on this platform")
        out, pid = self.launch_sleep("out-reuse")
        self.assertTrue((out / "WRAPPER_START").read_text().strip())
        (out / "WRAPPER_START").write_text("Thu Jan  1 00:00:00 1970\n")
        result = self.run_script("kill-lane.sh", out)
        self.assertEqual(result.returncode, 1)
        self.assertIn("PID was reused", result.stdout)
        os.kill(pid, 0)  # still alive

    def test_wait_lane_reports_missing_dir_and_report_check(self):
        result = self.run_script("wait-lane.sh", self.base / "typo", "--poll", 1, "--max", 1)
        self.assertEqual(result.returncode, 0)
        self.assertTrue(result.stdout.startswith("LANE USAGE-ERROR out-dir does not exist"), result.stdout)
        self.assertTrue(self.run_script("wait-lane.sh", "--stall").stdout.startswith("LANE USAGE-ERROR"))
        card = self.write(self.base / "TASK.md", IMPL_CARD)
        out = self.base / "out-report"
        script = self.write(self.base / "fake-wrapper.sh",
                            '#!/bin/bash\nprintf "%s" "$CRD_TEST_REPLY" > "$1/LAST-MESSAGE.md"\n'
                            'echo 0 > "$1/EXIT_CODE"; date -u > "$1/FINISHED_UTC"\n')
        result = self.run_script("launch-lane.sh", out, "bash", script, out, card,
                                 env={"CRD_TEST_REPLY": IMPL_REPLY})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(os.path.samefile((out / "CARD_PATH").read_text().strip(), card))
        result = self.run_script("wait-lane.sh", out, "--poll", 1, "--max", 10)
        lines = result.stdout.splitlines()
        self.assertTrue(lines[0].startswith("LANE DONE exit=0 output=ok"), result.stdout)
        self.assertTrue(lines[1].startswith("REPORT-CHECK PASS"), result.stdout)


class GitActionTests(ScriptCase):
    def test_lane_commit_proves_head_moved(self):
        repo = self.make_repo()
        before = self.git(repo, "rev-parse", "HEAD")
        self.assertIn("nothing to commit", self.run_script("lane-commit.sh", repo, "fix: none", "lane-1").stdout)
        self.write(repo / "a.txt", "two\n")
        self.write(repo / "new file.txt", "x\n")
        self.git(repo, "mv", "a.txt", "b.txt")
        result = self.run_script("lane-commit.sh", repo, "fix: keep drafts", "lane-1")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("LANE-COMMIT ok", result.stdout)
        self.assertNotEqual(self.git(repo, "rev-parse", "HEAD"), before)
        self.assertEqual(self.git(repo, "status", "--porcelain"), "")
        message = self.git(repo, "log", "-1", "--format=%B")
        self.assertTrue(message.endswith("Lane: lane-1"), message)
        self.assertNotIn("Co-Authored-By", message)
        self.write(repo / "c.txt", "c\n")
        result = self.run_script("lane-commit.sh", repo, "fix: more", "lane-1",
                                 env={"COAUTHOR": "Helper <helper@example.invalid>"})
        self.assertEqual(result.returncode, 0, result.stdout)
        trailers = self.git(repo, "log", "-1", "--format=%(trailers)")
        self.assertIn("Co-Authored-By: Helper <helper@example.invalid>", trailers)

    def test_merge_lane_gates_on_checks_and_run_lock(self):
        repo = self.make_repo("instance")
        lane = self.base / "lane-wt"
        self.git(repo, "worktree", "add", "-q", "-b", "lane-1", str(lane))
        self.write(lane / "fix.txt", "fixed\n")
        self.git(lane, "add", "fix.txt")
        self.git(lane, "commit", "-q", "-m", "fix")
        lock = self.write(self.base / "RUN-IN-PROGRESS", "")
        args = (lane, "lane-1", repo, "main")
        result = self.run_script("merge-lane.sh", *args, "true", env={"RUN_LOCK": str(lock)})
        self.assertEqual(result.returncode, 1)
        self.assertIn("run is in progress", result.stdout)
        result = self.run_script("merge-lane.sh", *args, "true", "exit 3")
        self.assertEqual(result.returncode, 1)
        self.assertIn("MERGE-LANE FAIL: check 2", result.stdout)
        self.assertFalse((repo / "fix.txt").exists())
        result = self.run_script("merge-lane.sh", *args, "test -f fix.txt")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("MERGE-LANE ok", result.stdout)
        self.assertTrue((repo / "fix.txt").exists())


class SafeRemoveTests(ScriptCase):
    def setUp(self):
        super().setUp()
        self.root = self.base / "scratch" / "root"
        self.target = self.root / "old-run"
        self.write(self.target / "data.bin", "x" * 10)

    def test_dry_run_then_apply(self):
        result = self.run_script("safe-rm.sh", self.root, self.target)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("would remove", result.stdout)
        self.assertTrue(self.target.exists())
        result = self.run_script("safe-rm.sh", "--apply", self.root, self.target)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertFalse(self.target.exists())

    def test_refusals_delete_nothing(self):
        outside = self.write(self.base / "keep" / "file.txt", "keep\n")
        work = self.write(self.root / "lane" / "TASK-X.md", "card\n").parent
        link = self.root / "link"
        link.symlink_to(self.target)
        cases = ((self.root, self.target, ""), (self.root, self.target, outside), (self.root, self.root),
                 (self.root, "relative/path"), (self.root, f"{self.root}/old-run/../old-run"),
                 (self.root, link), (self.root, work))
        for root, *paths in cases:
            result = self.run_script("safe-rm.sh", "--apply", root, *paths)
            self.assertIn(result.returncode, (1, 2), (root, paths, result.stdout))
            self.assertTrue(self.target.exists() and outside.exists() and work.exists())
        self.assertIn("root too shallow", self.run_script("safe-rm.sh", "/usr", self.target).stdout)


@unittest.skipUnless(shutil.which("lsof"), "lsof is required for the serving check")
class ServingTests(ScriptCase):
    def serve(self, cwd):
        process = subprocess.Popen([sys.executable, "-c", (
            "import socket,sys,time\n"
            "s=socket.socket(); s.bind(('127.0.0.1',0)); s.listen(); print(s.getsockname()[1], flush=True)\n"
            "time.sleep(60)\n")], cwd=cwd, stdout=subprocess.PIPE, text=True)
        self.addCleanup(lambda: (process.kill(), process.wait(), process.stdout.close()))
        return int(process.stdout.readline())

    def test_serving_verdicts(self):
        tree = self.make_repo("instance")
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            free = probe.getsockname()[1]
        result = self.run_script("check-serving.sh", tree, free)
        self.assertIn(f"port {free}: NOT-LISTENING", result.stdout)
        self.assertTrue(result.stdout.strip().endswith("SERVING-CHECK FAIL"))
        elsewhere = self.serve(self.base)
        self.assertIn("OUTSIDE-TREE", self.run_script("check-serving.sh", tree, elsewhere).stdout)
        time.sleep(1.1)  # start strictly after the HEAD update
        inside = self.serve(tree)
        result = self.run_script("check-serving.sh", tree, inside)
        self.assertIn(f"port {inside}: OK", result.stdout)
        self.assertTrue(result.stdout.strip().endswith("SERVING-CHECK PASS"), result.stdout)


if __name__ == "__main__":
    unittest.main()
