#!/bin/zsh
# probe-agents.sh — environment self-check for coordinator-review-drive (step 1, before any allocation).
#
# usage: probe-agents.sh [extra-binary ...]
#
# Checks ONLY: binaries on PATH (`which`, `--version` with a 10 s limit), the PRESENCE of a few config
# directories/files, and host capacity (CPUs, load, free disk). It never opens, reads or prints credentials,
# tokens, auth/session files or .env files, and it calls no model (no quota is spent).
# A binary being present does NOT mean the account/model behind it is usable: confirm with the user, and only
# with the user's consent run one tiny live probe per model (see PLAYBOOK.md "Environment discovery").
set -u
B=(codex claude zcode dsh gemini cursor-agent opencode aider gh git node npx python3 perl jq)
(( $# )) && B+=("$@")

ver() { perl -e 'alarm shift; exec @ARGV or exit 127' 10 "$@" 2>&1 | grep -m1 -v '^[[:space:]]*$' | cut -c1-80; }
have() { [[ -e $1 ]] && print -r -- "present" || print -r -- "absent"; }

print "== binaries =="
for b in "${B[@]}"; do
  p=$(whence -p -- "$b" 2>/dev/null)
  if [[ -n $p ]]; then
    v=$(ver "$p" --version); [[ -z $v && $b == dsh ]] && v=$(ver "$p" -V)
    printf 'OK  %-13s %-40s %s\n' "$b" "${v:-?}" "$p"
  else
    printf '--  %-13s not found\n' "$b"
  fi
done

print "\n== config presence (contents not read; auth files deliberately not inspected) =="
printf '%-48s %s\n' "~/.codex/config.toml" "$(have ~/.codex/config.toml)"
printf '%-48s %s\n' "~/.claude/ (Claude Code home)" "$(have ~/.claude)"
printf '%-48s %s\n' "~/.claude/skills/coordinator-review-drive" "$(have ~/.claude/skills/coordinator-review-drive)"
printf '%-48s %s\n' "ZCode provider config (app bundle)" "$(have /Applications/ZCode.app/Contents/Resources/config/provider/zcode-builtin.json)"
for d in ${DSH_HOME:-} ~/.dsh ~/.config/dsh; do
  [[ -n $d && -d $d/profiles ]] || continue
  pat="$d/profiles/*(N/:t)"; prof=( $~pat )
  printf '%-48s %s\n' "dsh profiles ($d/profiles)" "${prof[*]:-none}"
done
printf '%-48s %s\n' "Google Chrome.app" "$(have '/Applications/Google Chrome.app')"
pat="$HOME/.npm/_npx/*/node_modules/chrome-devtools-mcp(N/)"; m=( $~pat )
printf '%-48s %s\n' "chrome-devtools-mcp (npx cache)" "$(( $#m )) copies"
port=${CRD_BROWSER_PORT:-9333}
if command -v lsof >/dev/null && lsof -nP -iTCP:$port -sTCP:LISTEN >/dev/null 2>&1; then
  printf '%-48s %s\n' "DevTools port $port" "listening"
else
  printf '%-48s %s\n' "DevTools port $port" "not listening"
fi

print "\n== host capacity (use a load gate before heavy suites) =="
ncpu=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || print '?')
print -r -- "cpus: $ncpu"
print -r -- "load: $(uptime | sed 's/.*load average[s]*: //')"
print -r -- "disk (\$HOME): $(df -h "$HOME" | tail -n 1 | awk '{print $4 " free of " $2 " (" $5 " used)"}')"

cat <<'EOF'

== next (ask the user; do not assume) ==
1. Which of the agents above may be used now, under which account, and which exact model names
   (e.g. Codex model ids, zcode/GLM, dsh provider+model, Claude Opus/Sonnet/Haiku subagents, headless claude -p)?
2. Quotas/cost limits per agent (5-hour/weekly windows, credits), and which ones are scarce.
3. Authority: push/merge/deploy, real providers or paid calls, user data/manuscripts, browser accounts.
4. Language for records/reports. Then record D-001 + GOAL-STATE.environment + ALLOCATION.md.
EOF
