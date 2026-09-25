# Review Round 8 — final decision round: `ROOTREADONLY` scoping bug + open-item correction

**Baseline:** `dev` at R7 (`8c42bd2`), 2917 lines, **26 findings / 8 codes**, `1.2.12.beta1`.
**Nature:** one RISKY-class item (adding `local` — user decides per campaign rules) + one campaign-log correction (no code change).

## A — `media_partition_info`: `ROOTREADONLY` is set but never declared `local`

All four references (grep-proven, file-wide) live inside `media_partition_info`:

```bash
2247        ROOTREADONLY="$(grep /boot "$MOUNTDIR/etc/fstab" | grep ,ro )"   # set (only when fstab exists)
2248        if [[ -n "$ROOTREADONLY" ]]; then
2249            ROOTREADONLY="(READONLY)"
2265    echo "$OS$OVERLAY$ROOTREADONLY"                                       # read
```

Its siblings (`OS`, `ARCH`, `BITS`, `OVERLAY`) are all declared `local`; `ROOTREADONLY` is the exception — so it leaks into the global namespace, **and** is not re-initialized when the `fstab` branch is skipped.

### The latent bug this causes (pre-existing, demonstrable)

`local VAR=` re-initialises on every call. A bare global does not:

1. Call on a Linux image whose `fstab` has a read-only `/boot` → `ROOTREADONLY="(READONLY)"` → correct output, **global now set**.
2. Next call on a Windows image (no `etc/fstab` → branch skipped) → line 2265 still echoes the **stale** `"(READONLY)"` from call 1 → the Windows line is labelled read-only wrongly. (First-call-only sequences never trigger it — which is why it has stayed hidden.)

Grep proves nothing else reads `ROOTREADONLY`, so no caller can depend on the leak.

### Proposed fix (1 word, R8.1 — user approval required: "adding `local`" is RISKY class)

```bash
    local OVERLAY=
+   local ROOTREADONLY=
```

Effect: no global leak; per-call re-initialisation (identical to its siblings); call-1 output byte-identical; only call-2-on-a-no-fstab-device output changes (stale marker drops — the fix).

## B — open-items correction (docs only, no code)

The open-item "`tr -cd '[[kmgtbKMGTB]]' suffix-set quirk (tr `[[` = literal-`[` escape)" is **a mis-diagnosis — closed**. Verified the current code (lines 777/779/897/901):

* L779 `tr -cd 'kmgtbKMGTB'` — plain set, correct.
* L777/897/901 `tr -cd '[[:digit:]]'` — POSIX class form, correct; **these 3 are the SC2021 findings and they are false positives** (shellcheck 0.10.0 doesn't model tr's `[[:class:]]`; `bash -n` + runtime output correct). The SC2021×3 stay on the file as known FPs.

## Expected result (if R8.1 approved)

| Metric | Before | After |
|---|---|---|
| Findings | 26 | **26** (no code change to a flagged line) |
| Codes | 8 | **8** |
| Lines | 2917 | **2918** (+1) |

**Measured (post-application) — matches exactly:** 26 findings / 8 codes, 0 added / 0 removed (site-list diff = only the +1 downward line shift from the insertion); 2917 → 2918 lines; `git diff` = exactly 1 insertion.

## Verification (agent-safe)

1. `bash -n`; `bash pisafe -v` → `1.2.12.beta1`; `wc -l` 2917 → 2918; `git diff` = exactly one added line, nothing else.
2. **A/B bug demonstration** (`/tmp/opencode/r8_ab.sh`): extract `media_partition_info` from `8c42bd2` and live; stub `sudo` (parted/losetup/mount arms), `mktemp` (→ pre-built fixture dirs), `file`; two sequences:
   * **Contamination sequence** — call A (Linux, `fstab` `/boot … ,ro`) then call B (Windows dir, no `fstab`): **pre → call B output contains stale `(READONLY)`; live → clean** (documents the fix).
   * **First-call sequence** — single call on each fixture: **byte-identical pre vs live** (call-1 behavior provably unchanged).
3. shellcheck: 26 findings / 8 codes, unchanged; site-list identical.

## Deliverables

1. `pisafe` R8.1 if approved.
2. `REVIEW_ROUNDS.md` — R8 section + open-items update (tr-quirk closed; ROOTREADONLY closed).
3. Chat report → **stop, wait for user functional test + commit approval**. Candidate message: `review R8: local ROOTREADONLY (fix read-only marker cross-call bleed)`. No push / tag / version bump.

**Status: APPLIED + VERIFIED (changes on `dev`, uncommitted — commit pending user approval).**
User approval 2026-09-25: **R8.1 approved** · **R8.2 approved** (docs only).

Verification results: `bash -n` PASS; `-v` → `1.2.12.beta1`; 2917 → 2918 lines; A/B harness `/tmp/opencode/r8_ab.sh` **ALL PASS** — first-call sequences byte-identical pre/live; contamination sequence: **pre `B:['Windows'(READONLY)]` (bug reproduced) → live `B:['Windows']` (fixed)**; shellcheck 26/8 unchanged; `git diff` = 1 ins / 0 del (exactly `+ local ROOTREADONLY=`). SC2086 keep-list renumbered to 125, 1857, 1976, 2066, 2468, 2470, 2474, 2476, 2478, 2489, 2491×3, 2889, 2918.
