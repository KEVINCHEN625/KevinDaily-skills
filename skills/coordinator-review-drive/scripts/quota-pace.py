#!/usr/bin/env python3
"""Straight-line pacing for a rate-limited usage window (e.g. a 5-hour model window).

Prints used% vs a straight-line target (target_pct x elapsed / window) and a recommendation:
  START        behind the line: start the next queued bounded task
  ON-TRACK     keep the current load
  HOLD         ahead of the line: start nothing new now (never kill running work for this)
  FINISH-ONLY  last <finish-min> minutes: no new task; let running ones finish
It also warns when a longer, non-renewing window (e.g. weekly) resets soon with quota left unused.

Inputs (never reads credentials, tokens or transcripts):
  a) --used PCT --resets-at EPOCH            manual values (e.g. read off the usage UI)
  b) a JSONL snapshot file (default $CRD_QUOTA_SNAPSHOTS, else ~/.claude/statusline/rate_limits.jsonl)
     with lines like {"captured_at": "...", "rate_limits": {"five_hour": {"used_percentage": 42,
     "resets_at": 1793092200}, "seven_day": {...}}}. Several writers may append; per window the newest
     resets_at wins and, within it, the highest used_percentage (usage only grows inside one window).
  `quota-pace.py capture` reads a Claude Code statusline JSON on stdin and appends only its
  rate_limits (used_percentage, resets_at) to the snapshot file; call it from your statusline script.

Usage: quota-pace.py [--window five_hour] [--window-min 300] [--target 97] [--band 8] [--finish-min 40]
                     [--long-window seven_day] [--use-before-h 12] [--snapshots FILE] [--used P --resets-at T]
"""
import argparse, datetime as dt, json, os, sys, time

DEFAULT_SNAPSHOTS = os.environ.get('CRD_QUOTA_SNAPSHOTS',
                                   os.path.expanduser('~/.claude/statusline/rate_limits.jsonl'))


def capture(path):
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return
    rates = data.get('rate_limits') if isinstance(data.get('rate_limits'), dict) else {}
    clean = {w: {k: v[k] for k in ('used_percentage', 'resets_at') if v.get(k) is not None}
             for w, v in rates.items() if isinstance(v, dict)}
    if not clean:
        return
    os.makedirs(os.path.dirname(path) or '.', exist_ok=True)
    with open(path, 'a', encoding='utf-8') as f:
        f.write(json.dumps({'captured_at': dt.datetime.now().astimezone().isoformat(timespec='seconds'),
                            'rate_limits': clean}, separators=(',', ':')) + '\n')
    print(' · '.join(f"{w} {v.get('used_percentage', '?')}%" for w, v in clean.items()))


def latest(path):
    best = {}
    try:
        with open(path, encoding='utf-8') as f:
            for line in f:
                try:
                    rates = (json.loads(line).get('rate_limits') or {})
                except ValueError:
                    continue
                for w, v in rates.items():
                    cur = best.get(w)
                    key = (v.get('resets_at') or 0, v.get('used_percentage') or 0)
                    if cur is None or key > (cur.get('resets_at') or 0, cur.get('used_percentage') or 0):
                        best[w] = v
    except OSError:
        pass
    now = time.time()
    return {w: v for w, v in best.items() if (v.get('resets_at') or 0) > now}  # drop windows that already reset


def main():
    if len(sys.argv) > 1 and sys.argv[1] == 'capture':
        p = argparse.ArgumentParser(); p.add_argument('cmd'); p.add_argument('--snapshots', default=DEFAULT_SNAPSHOTS)
        capture(p.parse_args().snapshots); return
    p = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    p.add_argument('--snapshots', default=DEFAULT_SNAPSHOTS)
    p.add_argument('--window', default='five_hour')
    p.add_argument('--window-min', type=float, default=300)
    p.add_argument('--target', type=float, default=97, help='%% to reach at the window end')
    p.add_argument('--band', type=float, default=8, help='+/- %% around the line counted as on-track')
    p.add_argument('--finish-min', type=float, default=40)
    p.add_argument('--long-window', default='seven_day')
    p.add_argument('--use-before-h', type=float, default=12, help='warn if the long window resets within N h')
    p.add_argument('--used', type=float); p.add_argument('--resets-at', type=float)
    a = p.parse_args()
    windows = latest(a.snapshots)
    if a.used is not None and a.resets_at is not None:
        windows[a.window] = {'used_percentage': a.used, 'resets_at': a.resets_at}
    w = windows.get(a.window)
    if not w:
        print(f'NO-DATA: no live {a.window} value in {a.snapshots}; pass --used/--resets-at'); sys.exit(2)
    used = float(w.get('used_percentage') or 0)
    left = max(0.0, (w['resets_at'] - time.time()) / 60)
    elapsed = max(0.0, a.window_min - left)
    line = min(a.target, a.target * elapsed / a.window_min)
    if left < a.finish_min:
        rec = 'FINISH-ONLY (no new task; let running ones finish)'
    elif used > line + a.band:
        rec = 'HOLD (ahead of the line; start nothing new, do not kill running work)'
    elif used < line - a.band:
        rec = 'START (behind the line; start the next queued bounded task)'
    else:
        rec = 'ON-TRACK (keep the current load)'
    out = f'{a.window} used {used:.0f}% | line-now {line:.0f}% | {left:.0f} min left | {rec}'
    lw = windows.get(a.long_window)
    if lw:
        lu = float(lw.get('used_percentage') or 0); lh = (lw['resets_at'] - time.time()) / 3600
        out += f' | {a.long_window} {lu:.0f}% resets in {lh:.1f} h'
        if lh < a.use_before_h and lu < 90:
            out += ' -> USE-REMAINING before it resets (queue important bounded work)'
    print(out)


if __name__ == '__main__':
    main()
