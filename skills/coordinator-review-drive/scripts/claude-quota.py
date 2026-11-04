#!/usr/bin/env python3
"""claude-quota.py — estimate the coordinator's Claude usage window from local session logs (coordinator-review-drive).

usage:
  python3 claude-quota.py --ref-start 2026-10-16T16:50+08:00 --ref-end 2026-10-16T21:25+08:00 \
                          --cur-start 2026-10-17T02:50+08:00 [--cur-end <iso>] [--model opus] [--root ~/.claude/projects]

Why: usage dashboards may group tokens into blocks whose boundaries differ from the official 5-hour window, so their
percentages do not match what the user sees. This script weights tokens of one model family
(input 1, output 5, cache-read 0.1, cache-create 1.25) in the current window and divides by the same weight of a
REFERENCE window that is known to have hit 100 % (the window in which the limit was reached). Calibrate once: the
result should reproduce a percentage the user read in the UI. Update the bounds when the official reset time moves.

Reads only the "usage", "model", "id", "requestId" and "timestamp" fields of *.jsonl lines under --root; never prints
message content. Duplicate (message id, request id) pairs are counted once.
"""
import argparse
import datetime as dt
import glob
import json
import os
import sys

WEIGHTS = {"input_tokens": 1.0, "output_tokens": 5.0,
           "cache_read_input_tokens": 0.1, "cache_creation_input_tokens": 1.25}


def parse(ts):
    t = dt.datetime.fromisoformat(ts.replace("Z", "+00:00"))
    if t.tzinfo is None:
        sys.exit(f"timestamp needs a UTC offset: {ts}")
    return t


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--ref-start", required=True)
    ap.add_argument("--ref-end", required=True)
    ap.add_argument("--cur-start", required=True)
    ap.add_argument("--cur-end", default=None, help="default: now")
    ap.add_argument("--model", default="opus", help="substring of the model id to count (default: opus)")
    ap.add_argument("--root", default="~/.claude/projects")
    a = ap.parse_args()

    ref = (parse(a.ref_start), parse(a.ref_end))
    cur = (parse(a.cur_start), parse(a.cur_end) if a.cur_end else dt.datetime.now(dt.timezone.utc))
    earliest = min(ref[0], cur[0]).timestamp()
    acc = {"ref": 0.0, "cur": 0.0}
    seen = set()
    for f in glob.glob(os.path.join(os.path.expanduser(a.root), "**", "*.jsonl"), recursive=True):
        try:
            if os.path.getmtime(f) < earliest:
                continue
            fh = open(f, errors="ignore")
        except OSError:
            continue
        with fh:
            for line in fh:
                if '"usage"' not in line:
                    continue
                try:
                    d = json.loads(line)
                except ValueError:
                    continue
                m = d.get("message") or {}
                u, ts = m.get("usage"), d.get("timestamp")
                if not u or not ts or a.model not in str(m.get("model", "")):
                    continue
                key = (m.get("id"), d.get("requestId"))
                if key in seen:
                    continue
                seen.add(key)
                w = sum(float(u.get(k, 0) or 0) * v for k, v in WEIGHTS.items())
                t = parse(ts)
                for name, (s, e) in (("ref", ref), ("cur", cur)):
                    if s <= t < e:
                        acc[name] += w
    r, c = acc["ref"], acc["cur"]
    pct = 100.0 * c / r if r else 0.0
    print(f"model~{a.model} ref_weight={r:.3e} cur_weight={c:.3e} cur_pct_of_ref={pct:.1f}%")
    if not r:
        print("reference window has no usage: check --ref-start/--ref-end and --model", file=sys.stderr)


if __name__ == "__main__":
    main()
