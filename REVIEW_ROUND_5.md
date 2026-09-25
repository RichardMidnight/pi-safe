# Review Round 5 — pipeline & command hygiene

**Baseline:** `dev` at R4 (`00b05fc`), 2918 lines, **77 findings / 14 codes**, `1.2.12.beta1`.
**Goal:** close three redundant-command classes — **SC2005 ×9** (useless `echo`), **SC2002 ×5** (useless `cat`), **SC2143 ×1** (non-`-q` grep whose output is only tested for emptiness). Small, mechanical, line-neutral, fully A/B-testable.

## Proposed items

### R5.1 — SC2005 ×8: `echo "$(cmd)"` → `printf '%s\n' "$(cmd)"`

* L633–636 `env_sysinfo`: `echo "$(env_terminal)"`, `…env_installer)`, `…env_texteditor)`, `…env_root_device)`
* L945 / L991 / L1062: `echo "$(get_bytes "$SIZE_BYTES" -h)"` (media size display ×3)
* L1017 `do_list_info`: `echo "$(media_list)"`

**Why `printf '%s\n'` and not the bare command:** verified that `env_terminal` (fail → `return 1` empty), `env_texteditor` (no editor found → **empty, silent**), `env_root_device` (grep miss → empty), and `get_bytes` (non-numeric → `ui_msg_warning` + `return 0`, **empty stdout**) can all yield empty output. `echo ""` prints a blank line; a bare call prints **nothing** — a behavior change. `printf '%s\n' "$(cmd)"` prints a blank line exactly as today, is the campaign's established echo→printf idiom (R2 class 3), adds **zero** shellcheck findings, and removes SC2005. Byte-identical to `echo` otherwise (bash `echo` without `-e` does no escape processing; none of the outputs begin with `-`).

### R5.2 — SC2005 ×1 (piped): L877 `file_ext`

`echo "$(basename "$*")" | grep \\. | sed 's#.*\.##g'` → `basename "$*" | grep \\. | sed 's#.*\.##g'`

Output goes to a pipe, not the terminal: `echo` here only exists to feed `grep` (an empty line vs no line both miss `grep \.` → same result). Direct `basename` is provably identical.

### R5.3 — SC2002 ×5: `cat FILE | grep …` → `grep … FILE`

* L470 `config_var_get`: `cat "$CONFIG" | grep "$SETTING" | sed …` → `grep "$SETTING" "$CONFIG" | sed …`
* L1009: `echo "$(cat /etc/os-release | grep "PRETTY_NAME=" | cut …)" hw=… kernel=…` → `echo "$(grep "PRETTY_NAME=" /etc/os-release | cut …)" …` (echo kept — multi-arg, not an SC2005 form)
* L2224: `OS="$(cat "$MOUNTDIR/etc/os-release" | grep PRETTY_NAME | cut -d= -f2)"` → `… grep PRETTY_NAME "$MOUNTDIR/etc/os-release" …`
* L2245: `ROOTREADONLY="$(cat "$MOUNTDIR/etc/fstab" | grep /boot | grep ,ro )"` → `… grep /boot "$MOUNTDIR/etc/fstab" …`
* L2253: `OVERLAY="$(cat "$MOUNTDIR/cmdline.txt" | grep boot=overlay )"` → `… grep boot=overlay "$MOUNTDIR/cmdline.txt")"`

`grep PATTERN FILE` reads the same bytes as the cat-pipe (file existence is already checked at the L2224/2245/2253 sites; L470/L1009 rely on the same failure class as before — grep-on-missing-file reports and yields no output, pipe status still `sed`'s). Behavior-preserving.

### R5.4 — SC2143 ×1: L1515 `media_partition_info` primary-partition test

`if [[ -z $(echo "$PARTED_OUTPUT" | grep -v Free | tail -1 | sed 's/[ ]\+/ /g' | grep primary) ]]; then`
→
`if ! echo "$PARTED_OUTPUT" | grep -v Free | tail -1 | sed 's/[ ]\+/ /g' | grep -q primary; then`

**RISKY-class (exit-status restructure)** — proof: `[[ -z $(P | grep primary) ]]` is true iff `grep primary` matches nothing; `! (… | grep -q primary)` is true iff `grep -q primary` exits non-zero — the same condition. Pipeline status is grep's in both; `-q` only changes *when* grep may exit (upstream SIGPIPE possible, which cannot alter the last command's status). Branch decision preserved on all inputs (`primary` present / absent / only-in-Free-lines). This is the L1507 site deferred in R3 — solvable because **only the emptiness** of the capture is used, so `-q` is a legitimate drop-in here (unlike the multi-stage sites that need actual output).

## Expected shellcheck result

SC2005×9 → 0, SC2002×5 → 0, SC2143×1 → 0 → **77 → 62 findings**, **14 → 11 codes** (three whole classes eliminated). Line-neutral (2918); SC2086 keep-list unchanged (17 sites, same lines).

## Verification (run before report)

1. `bash -n`; `bash pisafe -v` → `1.2.12.beta1`.
2. A/B pristine-vs-live per site, byte-compare stdout+stderr+rc:
   * `env_sysinfo` with stubbed `env_*` in **all-present** and **terminal-missing / editor-missing** (empty) scenarios
   * `file_ext`: 5 inputs incl. no-dot, dotfile, multi-dot
   * `get_bytes`-wrap line: stub `get_bytes` non-empty **and** empty (warn-return)
   * `media_list` wrap line: stubbed multi-line list + trailing newlines
   * `config_var_get` on a real temp `$CONFIG` (hit + miss)
   * os-release line: real `/etc/os-release` (hit) + non-matching file (miss)
   * fstab/cmdline expressions: temp files, hit + miss
   * L1515 branch: three `PARTED_OUTPUT` fixtures (primary last / no primary / primary only in a non-last line), assert identical taken branch
3. shellcheck: 77 → **62**; codes 14 → **11**; keep-list 17/17 same lines; **no new findings**.
4. `git diff` read-through — 15 single-line hunks, each mapping to an approved item.

## Deliverables

1. `pisafe` modified per approved items.
2. `REVIEW_ROUNDS.md` Round 5 section.
3. Chat report, then **stop and wait for user functional testing + commit approval**. Candidate commit message: `review R5: drop useless echo/cat, grep files directly, -q emptiness test (SC2005/2002/2143 → 62 findings)`. No push / tag / version bump.

**Status: APPROVED (user: "Approve all") + APPLIED + VERIFIED — awaiting user functional testing and commit approval.**

## Results (measured 2026-09-25)

1. `bash -n pisafe` — PASS. `bash pisafe -v` — `1.2.12.beta1`.
2. **A/B battery `/tmp/opencode/r5_ab.sh` — 23/23 PASS** (pristine `00b05fc` baseline `/tmp/opencode/pisafe_preR5.txt` vs live):
   * `env_sysinfo` ×3 scenarios (all-present; editor-missing = empty + silent; terminal-fail empty + root empty) — byte-identical incl. the **empty → blank-line** edge (this is why `printf '%s\n'` was chosen over bare calls)
   * `file_ext` ×5 inputs (multi-dot, no-dot, dotfile) + pipe-form ×4 — identical
   * `get_bytes`-wrap non-empty + empty (warn-return) — identical
   * `media_list`-wrap multi-line + empty — identical
   * `config_var_get` hit + miss (real temp `$CONFIG`) — identical
   * os-release / fstab / cmdline expressions: hit + miss each — identical
   * **L1515 branch test: 3 `PARTED_OUTPUT` fixtures (primary-last → branch not taken; no-primary → taken; primary with Free line after → not taken) — all 3 identical rc pre vs live**
3. shellcheck (`-f gcc`, one line per finding): **77 → 62 findings, 14 → 11 codes** — exactly SC2005×9, SC2002×5, SC2143×1 removed; sorted full-report site diff = **15 removed lines, 0 added**.
4. SC2086 keep-list: **17/17 same lines** — 129, 968, 1859, 1979, 2068, 2465, 2467, 2471, 2473, 2475, 2486, 2488×3, 2889, 2898, 2918.
5. File stays **2918 lines** (all 15 edits single-line replacements).
6. `git diff --stat`: `pisafe | 30 ++… --…` = **15 insertions / 15 deletions** — 15 one-line hunks, each mapping to an approved item (R5.1 ×8 incl. the 4-line `env_sysinfo` block, R5.2 ×1, R5.3 ×5, R5.4 ×1); nothing else touched.

### Note on the draft's "63 findings / 12 codes"

The draft's expected values were an arithmetic slip. Correct arithmetic and measured result: 77 − 15 = **62** findings; 14 − 3 = **11** codes. All three target classes are fully eliminated, zero new findings, zero unrelated removals.
