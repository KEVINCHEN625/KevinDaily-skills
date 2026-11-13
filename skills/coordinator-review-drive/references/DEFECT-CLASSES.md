# Fix the class, not the instance

Read when: the same kind of defect appeared a second time, or a fix is growing machinery.
Priority rule: a class program never competes with the MAIN goal. If the class blocks the main path, ship the
narrow fix on the main path now and queue the class mechanism as a `side` item; start it when the main predicate is
met or when `goal-check.sh` shows WIP room (why: a 13-lane unification program was once planned while the main user
path was still blocked).

- **After 2–3 failures of the same class** (the same kind of model-output drift, the same integrity hole found again
  by review), stop patching instances: audit the whole class and fix it with one general mechanism (one shared
  helper/step, distinct reason codes). Four rounds of instance patches on one ledger meant the design was wrong;
  a simpler design based on the real source of truth replaced it.
- **Attack the premise** (pstack): when two fixes that share one premise failed the same gate, write the premise
  down as one sentence and test it directly before a third fix.
- **Encode lessons in structure** (pstack correct / encode-lessons-in-structure): a mistake that happened twice is
  fixed at the highest level that works — architecture (one owner, one way) > a check that fails with an error naming
  the fix (script, lint, launcher refusal) > a behaviour test > text last. AGENT-LESSONS records `enforced by:` for
  each lesson; a text-only lesson that repeats is encoded in the same change.
- **Read the raw evidence first**: keep the runtime of failing live runs (e.g. a keep-runtime flag) and have the
  designer read the actual outputs before designing; the cause is often one layer earlier than the symptom (a
  cleanup step deleted exactly the keys the repair needed).
- **Audit prompts for self-contradiction**: repair or stage prompts that state a limit and also forbid truncation,
  or ask to "drop" and "never delete" the same items, make models fail repairs; prompts stricter than the schema
  make repairs over-produce. Fix the wording before adding machinery.
- **Provenance over values**: before enforcing a number as a hard limit, record where it came from (user-set,
  declared by the provider/route, or a default/estimate); enforce only user-set or declared limits, treat defaults as
  estimates (why: a default silently became a hard cap that refused valid requests).
- **Error transparency**: never let a router or catch-all collapse unknown errors into a specific, misleading code
  (a masked `ValueError` became a "plan changed" conflict; a connection reset became "unknown send"; a diagnostic
  read in an except path hid the real provider error). A misleading user-facing message is a product bug: map each
  cause to an accurate, author-fixable message.
- **Sealed/versioned contracts are immutable**: when shared models drift from a sealed artifact (a pinned schema,
  a manifest hash, a registered pack), decouple the consumer via a frozen copy plus a drift test; never regenerate
  the sealed artifact (it breaks in-flight work pinned to it). Changes go into a new version.
