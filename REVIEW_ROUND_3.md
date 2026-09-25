# Review Round 3 — small, testable shellcheck fixes (PROPOSAL)

**Baseline:** branch `dev` at R2 + regression fix, **plus** the already-applied post-R2 safe cleanup (`get_bytes` bc-string quoting, SC2125×4 → 0). Working tree is clean apart from the uncommitted SC2125 fix; shellcheck stands at **98 findings / 18 codes**.
**Goal:** knock out the *small, individually verifiable* RISKY items — the ones where the "fix" is provably behavior-preserving or a defensible improvement and can each be spot-tested. Everything else stays in the backlog.

Read `AGENTS.md` first (SAFE vs RISKY, verification playbook, Git rules). **Every item below is RISKY-class, so it requires explicit per-item user approval before it is applied.** Nothing here is applied silently.

## Proposed items (approve / reject per line)

| # | Finding (line, live file) | Current | Change | Class | Why it's safe / note |
|---|---|---|---|---|---|
| R3.1 | SC2021 — L782 `get_bytes` | `tr -cd '[[kmgtbKMGTB]]'` | `tr -cd 'kmgtbKMGTB'` | RISKY (suffix set = user-visible) | tr parses `[[kmgtb…]]` as literal `[` + set + literal `]`, so the set *accidentally* also keeps `[`/`]`. Proven: for any realistic size input (`1024kb`, `5mb`, …) both forms return the **same** suffix (`kb`). Removing the stray `[`/`]` is a latent-bug fix; only diverges if a size string ever contains a bracket (it never does). L781/899/903 (`[[:digit:]]`) are *correct* — leave (FPs). |
| R3.2 | SC2053 — L1771 `media_restore` guard | `[[ $(file_device "$INFILE") = $OUTDEV ]]` | `… = "$OUTDEV" ]]` | RISKY (glob-pattern RHS) | `=` matches a *pattern* on the RHS; quoting forces literal. Both operands are device paths (`/dev/sda`), never globs → quoting is an improvement and can only make the equality check more correct. |
| R3.3 | SC2053 — L2023 root-guard | `[[ $1 = $ROOT ]]` | `… = "$ROOT" ]]` | RISKY (glob-pattern RHS) | Same as R3.2: comparing the argument device against the root-device path. Literal → quoting is safe. |
| R3.4 | SC2164 — L952 `file_list_image_files` (entry `cd`) | `cd "$DIR"` | `cd "$DIR" \|\| return 1` | RISKY (fail-fast behavior) | `DIR` is `$DEFAULT_PATH`; if the `cd` fails the glob loop below would run in the caller's cwd. Fail-fast is the correct semantic. |
| R3.5 | SC2164 — L966 (restore `cd`) | `cd "$OLD_PWD"` | `cd "$OLD_PWD" \|\| true` **or leave** | RISKY (optional) | This is best-effort cleanup *after* the list is already printed; a hard `return 1` here would retroactively fail an otherwise-successful call. `‖‖ true` silences SC2164 without changing the observable return. **Judgment call — your pick.** |
| R3.6 | SC2143 — L2215 `media_format` | `[[ -n $(echo "$BITS" \| grep 32) ]]` | `echo "$BITS" \| grep -q 32` | RISKY (exit-code flow) | `-q` exits 0 on match, 1 on no match — the exact truth value of `-n` over the captured output. Single-grep → `-q` is a clean, equivalent conversion. |
| R3.7 | SC2143 — L2217 `media_format` | `[[ -n $(echo "$BITS" \| grep 64) ]]` | `echo "$BITS" \| grep -q 64` | RISKY (exit-code flow) | Same as R3.6. |

**Result if all approved:** 98 → 90 findings (−8: SC2021×1, SC2053×2, SC2164×2, SC2143×2… i.e. R3.1–R3.7 minus the optional R3.5 = −6, or −7 with R3.5 as `‖‖ true`). 18 → 15 codes (SC2053 and SC2164 disappear; SC2021→3, SC2143→1).

## Explicitly OUT of scope this round (left in backlog)

* **SC2143 — L1507**: `[[ -z $(… | grep -v Free | tail -1 | sed … | grep primary) ]]` — the decision hinges on a **multi-stage pipeline** whose final command is `grep`; `-q`-ing it would change which command's exit code is tested. Not a clean one-liner; needs deliberate redesign. *Backlog.*
* **SC2181 ×18** (`if (( $? ))`), **SC2155 ×13** (`local X=$(…)`), **SC2005 ×9** (`echo $(…)`), **SC2002 ×5** (useless `cat`), **SC2034 ×15** (unused vars): the large mechanical sweeps / dead-var removal. Each is legitimate but is a behavior/flow/scope change deserving its **own** approved round with a full test battery. *Backlog — do a dedicated round(s) if you want.*
* Everything already classified **leave-as-is**: the 17-item SC2086 keep-list, the menu field-split idiom (SC2027/SC2068/SC2207), the L1992 SC2027 false positive, SC2059/SC2048 (keep-list intent), SC2215 (dead `notes_desktop_environment`), SC1001 (intentional `\1`), the three `[[:digit:]]` SC2021 FPs.

## Verification (must actually run; paste real output)

1. `bash -n pisafe` → PASS (before and after each edit).
2. `bash pisafe -v` → `1.2.12.beta1`.
3. **R3.1:** spot-test `get_bytes` suffix extraction for `1024kb`, `5mb`, `2gb`, `1tb`, `100`, `1024` — output must be **byte-identical** to current before/after (the `[`/`]` never appear, so identical).
4. **R3.2 / R3.3:** confirm the two `= "$VAR"` comparisons are literal path guards; a quick `[[ /dev/sda = "/dev/sda" ]]` style check shows the guard still trips on match and not on `*`/`[` in a path.
5. **R3.4 / R3.5:** `bash -n` + a subshell stub of `file_list_image_files` with `DEFAULT_PATH` pointed at an existing dir → runs; pointed at a **nonexistent** dir → R3.4 returns 1 (fail-fast) rather than globbing the caller's cwd.
6. **R3.6 / R3.7:** subshell: `BITS="x32y"` → matches 32 arm; `BITS="64bit"` → matches 64 arm; `BITS="arm"` → neither. Same as the `-n $(…|grep N)` form.
7. shellcheck delta: 98 → (90 or 91 depending on R3.5); confirm each approved code count drops as above.
8. `git diff --stat pisafe` and a full read-through — every hunk must map to one of R3.1–R3.7.

## Deliverables

1. `pisafe` modified per the **approved** subset of R3.1–R3.7.
2. `REVIEW_ROUNDS.md` — new "Round 3" section: per-item before/after, per-item rationale, verbatim verification output, and which (if any) proposed items were **rejected**.
3. Concise change report in chat, ending with: "Waiting for user functional testing. On approval, commit `pisafe` + `REVIEW_ROUNDS.md` + `REVIEW_ROUND_3.md` as `review R3: <summary>`. No push, no tag, no version bump."
4. **Stop** and wait for the user.

**Status: APPROVED (all 7 — R3.1, R3.2, R3.3, R3.4, R3.5 as `cd || true`, R3.6, R3.7) + APPLIED + VERIFIED on `dev` 2026-09-25. Commit pending user approval. See "Round 3" section in `REVIEW_ROUNDS.md` for before/after, rationale, and verbatim verification output. Residual: 98 → 91 findings, 18 → 16 codes.**
