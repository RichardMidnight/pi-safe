# Review Round 7 — decision round: dead variables (SC2034×15) + 3 flagged idioms

**Baseline:** `dev` at R6 (`87b6a38`), 2936 lines, **44 findings / 10 codes**, `1.2.12.beta1`.
**Nature:** every item this round is **RISKY** per campaign rules (code deletion, or quoting change that could touch word-splitting) — nothing is applied without explicit per-group approval.

## A. SC2034 audit — full evidence (15 findings)

File-wide checks supporting the verdicts:
* **No `export` anywhere in the file** — no dead global can be consumed by an external child process.
* Each variable was grepped file-wide with word-boundary matching (catches `$VAR`, `${VAR}`, arithmetic, and dynamic-scope reads in other functions).
* Caller audit: **no `run_command` caller passes a 3rd argument** (all calls use 1–2 args) and **no `ui_yesno` caller passes a 4th argument** (all use 1–3).

| Line | Variable | Context | References (file-wide) | Verdict |
|---|---|---|---|---|
| 3 | `COPYRIGHT` | `"By Richard Reed 2018 - 2022"` | 1 = definition | **truly dead** (see item B) |
| 22 | `CURRENT_DIR` | `$(pwd)` | 1 = definition | **truly dead** |
| 28 | `OPTIONAL_TOOLS` | `"xz pigz zstd"` | 1 = definition (only `REQUIRED_TOOLS` is used by the installer) | **truly dead** |
| 41 | `BLUE` | `'\033[0;34m'` | 1 = definition (`echo_blue` uses `LTBLUE`; the string `blue` in `ui_echo … blue` is a color *name*, not this variable) | **truly dead** |
| 126 | `QUIET` | `local QUIET=${3:-n}` in `run_command` | 1 = definition; 0 callers pass a 3rd arg | **truly dead** |
| 506 | `SETTINGS_SCRIPT_VER` | loaded from config | 1 = definition; no reader, no matching `config_var_set` | **truly dead** |
| 515 | `VERIFY` | `VERIFY=off` | 1 = definition | **truly dead** |
| 528 | `SAFETY` | loaded from config | 1 = definition (save path uses the literal *string* `safety`, not this variable) | **truly dead** |
| 557 | `ROOT_PARTITION` | `local` in `env_root_device` | definition + 1 hit in a **comment** (L565) | **truly dead** local |
| 558 | `ROOT_DRIVE` | `local` in `env_root_device` | 1 = definition | **truly dead** local |
| 814 | `p_eta` | `local` in `get_bytes` | 1 = definition (case arms stop at `t_era`/len 15; no petabyte arm exists) | **truly dead** |
| 1504 | `MEDIA_PARTITION_LIST` | parsed from `parted` in `media_list` | 1 = assignment (sibling vars `…_COUNT`, `…_LAST_PARTITION_*` are used; this one is not) | **truly dead** |
| 1972 | `TIMEOUT` | `local TIMEOUT=${4:-0}` in `ui_yesno` | 1 = definition; 0 callers pass a 4th arg; neither the CLI `read` path nor the whiptail path consumes it | **truly dead** |
| 2207 | `READONLY` | `local READONLY=` in `media_partition_info` | 1 = definition (working code uses a *different* var, `ROOTREADONLY`) | **truly dead** local |
| 2569 | `EXT` | `menu_get_outfile` | 3 refs, **all writes** (2534, ~2566, 2569), **zero reads** | **truly dead** store (see item C) |

**Adjacent observation (log only, no action):** `media_partition_info` uses `ROOTREADONLY` *without* declaring it `local` → it leaks into the global namespace. Separate hygiene item for a future round if desired.

## B. Item decisions (proposed)

### B1 — 13 clean deletions (recommended)
Delete these dead lines/locals: `CURRENT_DIR` (22), `OPTIONAL_TOOLS` (28), `BLUE` (41), `QUIET` (126), `SETTINGS_SCRIPT_VER` (506), `VERIFY` (515), `SAFETY` (528), `ROOT_PARTITION`+`ROOT_DRIVE` (557/558), `p_eta` (814), `MEDIA_PARTITION_LIST` (1504), `TIMEOUT` (1972), `READONLY` (2207).
Rationale: each is an unreferenced store in a function that has no reader, and no external consumer (no `export`). Deleting an unset-able local cannot change any branch (nothing reads it).

### B2 — L3 `COPYRIGHT` (recommend: delete now)
The copyright notice currently lives *only* in this dead variable (the release-backlog item "header says 2018 - 2022" points at it). Options: delete now (campaign records the text in this file) vs. defer to the release round. **Recommend delete now** — it is dead, and keeping the notice is a release-time display decision (e.g. `pisafe_about` text or a comment), not a variable.

### B3 — `EXT` dead block in `menu_get_outfile` (recommend: delete the block)
```bash
EXT=$DEFAULT_EXTENSION          # initial
...
if [[ -n $(file_ext "$OUTFILE") ]]; then
    EXT=$(file_ext "$OUTFILE")   # both branches store, nothing ever reads EXT
else
    EXT=$DEFAULT_EXTENSION
fi
```
`EXT` has **zero readers** file-wide, so the whole 6-line store block (initial + if/else) is behavior-neutral to remove. **Log as latent oddity:** the UI tells the user "if you don't include an extension `.img.$DEFAULT_EXTENSION` will be added" — the *actual* extension handling is in the final `file_ext` check + `OUTFILE=$OUTFILE.img.$DEFAULT_EXTENSION` (works); the dead block was probably the original (pre-refactor) handler.

### B4 — L971 `printf $FILES | column -t` (SC2059) — recommend: fix
`FILES` is built as one string containing literal `\n` sequences and is passed **unquoted as the printf *format***; with `IFS=$'\t\n'` the string isn't split, so every `\n` becomes a newline. It works, but any `%` or extra `\` in a filename/size field is interpreted as a conversion (corrupted output or a printf error).
Fix (byte-identical output for all sane inputs, injection-proof):
```bash
printf '%b' "$FILES" | column -t
```
(`%b` interprets the same escape sequences in a *quoted argument*; no format-string parsing.)

### B5 — L2916 `get_args $*` (SC2048) — recommend: fix
Top-level positional-arg forwarding. Recommend `get_args "$@"` — preserves arguments containing spaces verbatim instead of re-splitting them (strictly safer; no caller relies on the split).

### B6 — `media_name` dead error check (recommend: **leave**, documented)
`ES=$?` after `lsblk … | sed …` tests **sed's** status (always 0), not lsblk's. Deeper audit: **all call sites embed `$(media_name …)` inside a larger string**, so the function's return code is swallowed at every one of them — a fix (`PIPESTATUS[0]` or empty-output test) would change no user-observable behavior in this version. **Recommend: leave as-is, log as known-limitation** (the real fix = empty-output check + callers surfacing the error, a feature decision beyond the review campaign).

### Leave (no action, rationale recorded)
* SC2086×17 — campaign keep-list policy (flag/list/eval/`for-in`/menu semantics).
* SC2207 L2646 / SC2068+SC2027 L2661 — `options=($(…))` + `""${options[@]}""` menu idiom (R2-regression guard).
* SC2027 L2013 — nested-quote FP.
* SC2021×3 — `[[:digit:]]` FPs.
* SC2215×2 (L79/L87) — comment-block styling artifact.
* SC1001 L2093 — `$DEVICE\1` is deliberate (device name + partition suffix `1`).

## Decisions (per item, as approved 2026-09-25)

* **B1 — approved**: 13 clean dead vars/locals deleted.
* **B2 — DEFERRED TO RELEASE**: L3 `COPYRIGHT` kept (the release round owns the copyright date + display placement).
* **B3 — approved**: `EXT` dead-store block (initial + if/else) deleted.
* **B4 — approved**: `printf $FILES` → `printf '%b' "$FILES"`.
* **B5 — approved**: `get_args $*` → `get_args "$@"`.
* **B6 — left as-is, documented**: `media_name` return code is swallowed at every call site; real fix is feature work.

## Measured result

| Metric | Before | After |
|---|---|---|
| Findings | 44 | **26** (−14 SC2034, −1 SC2059, −1 SC2048, **−2 SC2086**) |
| Codes | 10 | **8** (SC2086, SC2034×1, SC2021×3, SC2027×2, SC2215×2, SC2207, SC2068, SC1001) |
| Lines | 2936 | **2917** (−19: B1 gives 13 lines, B3 gives 6 lines; B4/B5 are line rewrites) |

Note: the two fixed lines (`printf $FILES`, `get_args $*`) carried a **double flag** (SC2059+SC2086, SC2048+SC2086) — clearing them also removed 2 SC2086 notes that had been counted in the 17-site "keep-list". The true keep-list is now **15 sites**: 125, 1857, 1976, 2066, 2467, 2469, 2473, 2475, 2477, 2488, 2490×3, 2888, 2917 (tool-verified, 15/15).

Remaining `SC2034×1` = L3 `COPYRIGHT` (B2 deferred to release round).

## Verification (agent-safe)

1. `bash -n` **PASS**; `bash pisafe -v` → `1.2.12.beta1`; `wc -l` = **2917**.
2. A/B pristine-vs-live (`git show 87b6a38:pisafe` → `/tmp/opencode/pisafe_preR7.txt`, battery `/tmp/opencode/r7_ab.sh`) — **ALL PASS**:
   * `get_bytes` (p_eta removed): lens 1–18 + suffix/invalid/empty arms → byte-identical.
   * `file_list_image_files`: clean-file dir → byte-identical pre vs live, rc match; **% filename fixture: pre mangled `gamma 50%.xz` → `gamma_50z` (printf format-string parsing), live renders it cleanly, rc 0** — documents a real bug fixed by B4.
   * `run_command` (QUIET removed): ok/failing/compound/3-arg → identical rc+output.
   * `ui_yesno` (TIMEOUT removed): y / n / stray-then-y / 4th-arg → identical.
   * `env_root_device` (ROOT_PARTITION/ROOT_DRIVE removed): real read-only `findmnt`/`lsblk` → identical output+rc.
   * `get_args` (`$*` vs `"$@"`): identical globals incl. a space-containing token.
   * `config_var_get_settings` (3 dead vars removed): all shared globals identical.
3. shellcheck: **44 → 26 findings, 10 → 8 codes**; site-diff = exactly **18 removed** (14 SC2034, 1 SC2059, 1 SC2048, 2 SC2086) and **0 added, 0 unrelated**; SC2086 keep-list 15/15.
4. `git diff --stat`: `pisafe | 23 ++---------------------` = **2 insertions / 21 deletions**; full read-through confirms 19 pure deletions + 2 line rewrites (B4/B5), nothing else.

## Deliverables

1. `pisafe` per approved items (B1, B3, B4, B5 applied; B2 deferred; B6 documented).
2. `REVIEW_ROUNDS.md` Round 7 section.
3. Chat report → **stop, wait for user functional testing + commit approval**. Candidate message: `review R7: delete dead vars/locals (SC2034×14), printf %b, get_args "$@" (44→26 findings)`. No push / tag / version bump.

**Status: APPLIED + VERIFIED — awaiting user functional test and commit approval (B2 `COPYRIGHT` intentionally deferred to release round).**
