# Review Round 4 — variable hygiene (PROPOSAL)

**Baseline:** `dev` at R3 (`ed37b40`), 2906 lines, **91 findings / 16 codes**, `1.2.12.beta1`.
**Goal:** close the two remaining scoping/assignment classes — `get_ver_to_int` (the long-standing backlog item: no locals, global `parts`, `let`) and **SC2155 ×13** (`local X=$(…)` declaration+assignment) — plus two trivial SAFE whitespace nits. Small, cohesive, fully testable.

Read `AGENTS.md`. **R4.1 and R4.2 are RISKY-class** (locals/scoping, statement splitting, code deletion) → each item needs your explicit approval. R4.3 is SAFE.

## Proposed items

### R4.1 — `get_ver_to_int` (L710–717)

Current:
```bash
get_ver_to_int() {
    local IFS=.
    parts=("$1")

    let val=1000000*parts[0]+1000*parts[1]+parts[2]
    echo $val
    unset IFS
}
```
Proposed (final, incl. R4.1e):
```bash
get_ver_to_int() {
    local parts
    local val
    IFS='.' read -r -a parts <<< "$1"
    (( val = 1000000*parts[0] + 1000*parts[1] + parts[2] ))
    echo "$val"
}
```
| sub | change | class / proof |
|---|---|---|
| R4.1a | `parts` → `local parts` | RISKY (adding local). **Proven safe:** `parts` referenced **nowhere** else in the file (grep); sole caller is L364, which consumes stdout only. Kills the global leak (1.2.11 behavior: `parts` leaked into caller scope). |
| R4.1b | `let val=…` → `local val` + `(( val = … ))` | RISKY (let→arithmetic + local). **A/B-verified identical** on `1.2.3` `1.2.11` `0.1.0` `2` `1.2` `9.9.9` (incl. short/garbage inputs → unset array elems = 0 in both). Closes **SC2219**. |
| R4.1c | `echo $val` → `echo "$val"` | SAFE (single-token quote; not even an open finding, consistency only). |
| R4.1d | delete `unset IFS` | RISKY (code deletion) but a **proven no-op**: `IFS` is already `local` (bash restores the outer IFS on function return); the only command between `unset` and `return` is `echo`, which word-splits nothing (`$val` numeric). |
| **R4.1e** | **BUG FIX:** split `parts` across `.` — `IFS='.' read -r -a parts <<< "$1"` (replaces `local IFS=.` + `parts=("$1")`) | **Discovered during R4 A/B verification (pre-existing, since v1.2.11 baseline):** `parts=("$1")` is a *quoted* expansion → **no word splitting regardless of IFS** → single element `"1.2.11"` → `let`/arithmetic dies: `let: 1.2.11: syntax error: invalid arithmetic operator (error token is ".2.11")` on **stderr**, **empty stdout**, rc=0. A/B-verified the baseline behaves exactly this way → the sole caller (update check, L364: `SERVER_VER` is a dotted `1.2.x` string) compares `"" -gt ""` → **the "UPDATE AVAILABLE" prompt is dead, and a `let:` syntax error spits to the user's terminal on every update check.** Fix proven on 8 inputs: `1.2.3→1002003  1.2.11→1002011  0.1.0→1000  2→2000000  1.2→1002000  9.9.9→9009009  0.0.0→0  abc→0` (non-dotted/garbage unchanged from baseline; dotted now work). User chose shellcheck-endorsed robust idiom over the minimal `parts=($1)` (which adds SC2206×1) — `read -ra` adds **zero** findings. |

### R4.2 — SC2155 ×13: split `local X=$(…)` into `local X` + `X=$(…)`

The 13 sites: L271, L333 (INSTALL), L781, L782 (BASE/SUFFIX), L854, L855 (DIR/BASE), L1024, L1029, L1030 (VEN_MOD/SIZE/DEVICE), L1597 (INFILEEXT), L1990, L1991, L1992 (ROOT/TYPE/NAME).

* **12 sites — provably no behavior change:** audited each site — the *next* statement after each is another assignment/local/echo, **no `ES=$?` / `if (( $? ))` consumed in between**. Splitting only changes the statement's `$?` (from `local`'s 0 to the command's), which nothing reads. Variables stay local either way.
* **R4.2★ exception — L1024 (`media_name`):** next line **is** `ES=$?` + `if (( ES )); then return "$ES"`. Today the check is **dead**: `local` always returns 0, and after splitting it would capture the pipeline's *last* command = `sed` (which succeeds on empty input), so **observable behavior stays the same in R4 — the split is still behavior-neutral**. The *deeper* pre-existing bug (lsblk failure is swallowed by the `| sed` pipeline, so `media_name` never reports a bad device) is **logged, not fixed** — fixing it is a logic change (needs `PIPESTATUS[0]` or an empty-output check) and goes to the backlog for your explicit call.

### R4.3 — SAFE whitespace nits (no approval needed)

* L838 `else  # translate to bytes` → single space before `#`
* L1537 `[[ … = primary  ]]` → `[[ … = primary ]]`

## Expected shellcheck result

SC2155 ×13 → 0, SC2219 ×1 → 0 → **91 → 77 findings**, **16 → 14 codes**. (SC2181×18, SC2005×9, SC2002×5, SC2034×15 remain → R5 candidates.)

## Verification (actual results)

1. `bash -n pisafe` → PASS; `bash pisafe -v` → `1.2.12.beta1` (unchanged).
2. **R4.1:** A/B `get_ver_to_int` pristine-vs-live. Baseline: dotted versions → `let:` syntax error on stderr + **empty stdout** (rc=0); `2→2000000`, `abc→0`. Live post-fix: `1.2.3→1002003  1.2.11→1002011  0.1.0→1000  2→2000000  1.2→1002000  9.9.9→9009009  0.0.0→0  abc→0` — **bug fixed, non-dotted/garbage inputs byte-identical to baseline**. Global-leak check: after a live call in a subshell, `parts`/`val` are **unset** (`CLEAN`).
3. **R4.2:** `get_bytes` A/B (9 inputs incl. `abc` malformed): **identical** except the warning's `$LINENO` diagnostic moves `11 → 13` (inherent to any relocation of the warning line — noted, accepted). `file_base` A/B (5 inputs): **identical**. `media_name` A/B with stubbed `lsblk`: good device **identical**, bad device **identical** (dead `ES=$?` check stays non-firing in both — sed-at-pipeline-end confirmed, behavior neutral as documented).
4. shellcheck: 91 → **77 findings**, 16 → **14 codes** (SC2155×13 → 0, SC2219×1 → 0, nothing new; `read -ra` adds zero findings vs `parts=($1)` which would add SC2206×1). **SC2086 keep-list: same 17 sites**, lines shifted +5/+9/+12 as the splits above them predict (129, 968, 1859, 1979, 2068, 2465, 2467, 2471, 2473, 2475, 2486, 2488×3, 2889, 2898, 2918).
5. `git diff` — **17 hunks**, each mapping exactly to R4.1 (a–e), one of the 13 R4.2 splits, or one R4.3 nit. Read-through done. File 2906 → 2918 lines (net +12: +13 splits, −1 get_ver_to_int).

## Deliverables & stop

1. ✅ `pisafe` modified per approved items (R4.1 a–e, R4.2 ×13, R4.3 ×2).
2. ✅ `REVIEW_ROUNDS.md` Round 4 section.
3. **STOPPED** — awaiting user functional testing + commit approval (message: `review R4: variable hygiene — get_ver_to_int fix+loc, split local X=$(…) (SC2155/2219 → 77 findings)`). No push / tag / version bump.

**Status: APPLIED + VERIFIED — awaiting user test & commit approval.**

## Decisions log

| Decision | Choice |
|---|---|
| Round 4 scope | **All** (R4.1 a–d + R4.2×13 + R4.3×2) — "Approve all (recommended)" |
| Pre-existing `get_ver_to_int` dotted-version bug (found in R4 A/B) | **Fix in R4** (approved "Fix in R4 (Recommended)") |
| Split idiom for the fix | **`IFS='.' read -r -a parts <<< "$1"`** (shellcheck-endorsed, zero new findings) over minimal `parts=($1)` (SC2206×1) |
