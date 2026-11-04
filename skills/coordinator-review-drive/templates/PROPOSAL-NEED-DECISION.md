# PROPOSAL-<AREA>-<D-NNN>-<SHORT-NAME>

Status: NEED-DECISION (written by <executor/session>, <UTC>)
Related decision(s): D-<NNN>; evidence: <paths>

## 1. Facts (CONFIRMED)
- What happened, through which real path (page/API/command), with IDs, revisions, counters, and what did NOT change.

## 2. Root cause
- CONFIRMED: file:line and the exact equality/guard/state that fails.
- INFERRED (not yet proven): …

## 3. Why I stopped
- The fix needs one of: a design change / new permission / API or schema change / migration / product decision /
  loosening an existing guard / a second failed attempt.

## 4. Options
| # | Option | What changes | Safety/invariants kept | Cost/risk | Reversible? |
|---|--------|--------------|------------------------|-----------|-------------|
| A | … | … | … | … | … |
| B | … | … | … | … | … |

Recommendation: <A/B> because …

## 5. RED tests that would prove the chosen option
- positive: …
- negative (must still be refused): …

## 6. Data safety
- Existing user data touched? How is it preserved/recovered? No SQL backfills or resets.
