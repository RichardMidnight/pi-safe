# Review Round 17 — menus + main dispatch (inventory group 11): 10 functions reviewed, 2 approved changes (O1 sed portability, GUI ABOUT wired), 8 observations logged

**Baseline:** `development` @ `a5497f4` (R16). `pisafe` = blob `ec90f24`, 3009 lines, version `1.2.12-beta.5`. `shellcheck` + `bash -n` clean.

**Goal (approved 2026-10-18):** complete the function review of inventory **group 11 — menus + main dispatch** (`menu_*`, 10 functions, everything above them) + the top-level flow (L2967–3010, previously covered by the region table). Campaign focus applies: **reliability first, then standards and readability — no unneeded changes.**

**Outcome:** all 10 scope functions read in full (post-R16 spans) and exercised by a **60-test battery, 60/60 assertions green** (`/tmp/opencode/r17`, re-runnable). **0 hard defects.** 10 findings; the user approved **2** (applied): **O1** `sed` bracket portability in `menu_settings_default_path`, and **wiring the previously-dead GUI `ABOUT`** into the main menu. The remaining **8 observations are logged, unmodified** (per user decision: no dead-arm pruning, no log-only cleanup this round). All 10 `open` → `reviewed`; inventory now **78 reviewed / 0 partial / 0 open — every function in the inventory has a logged review round** (only the top-level-flow region note + release steps remain before a harness pass).

## Scope + findings (each function read in full)

| function (lines) | finding | evidence |
|---|---|---|
| `menu_cli` (2546–2599) | no defects. All 17 arms dispatch with correct arg mapping (`$2..$4` passthrough matches group-10 signatures — consistent with the R16-reviewed entry points). O2 (hard-coded `nano` for `log`/`settings` while GUI uses `$TEXT_EDITOR` — the help text explicitly documents `nano`, so kept), O3 (`-v)` arm is dead: shadowed by the top-level `-v` early-exit L2971) | battery C1–C18, CB |
| `menu_get_outfile` (2602–2657) | no defects. Real `media_backup_check_outfile` chain exercised: no-ext → `.img.zip` appended, `.zip` → `.img` inserted, `.tar` → "Unsupported" rejection then retry loop. `OUTFILEDEFAULT` seeded from `$DEFAULT_PATH` + date (display default only) | battery F1–F4 |
| `menu_gui` (2660–2700) | **R17 change 2 applied** (see below). O9 (stray `echo "Getting list of images ready..."` in the `LIST)` arm leaks to the terminal even in GUI mode — cosmetic, logged) | battery G1–G11 |
| `menu_select_device` (2703–2740) | no defects. `sed 's/ / | /'` (no `/g`) is **correct**: first space splits device\|description, the rest of the description stays whole (multi-word vendor survives as one menu token). O4 (`ES=$?` after `mapfile` reads mapfile's rc — always 0 — not `media_list`'s: a process-substitution rc is not propagated pre-bash-5.1; the empty-list→rc1 behavior is still covered by the `arraylength` check; `IFS=$'\n'` before `mapfile` is a no-op), O10 (vendor/model containing `|` would break the token split — rare edge) | battery D1–D4 |
| `menu_set_compression` (2743–2760) | no defects. Selection + config write correct; cancel is a no-op. O5 (radiolist hard-codes level “5 on” regardless of the stored level — cosmetic asymmetry with `menu_settings_default_extension`, which does reflect the current value) | battery K1–K2 |
| `menu_settings` (2763–2800) | no defects. All 7 live arms dispatch correctly; Factory-yes/no gated on `ui_yesno`; loop exits only on Back (rc1). O3 (dead `Text*)` case arm — no such menu item exists), O6 (function indented 2 spaces vs the file's 4 — cosmetic; left for a standards pass, not this round) | battery S1–S5 |
| `menu_settings_default_extension` (2803–2827) | no defects. Radio state reflects the current default (zip/xz/gz/img/zst); unknown → xz arm; selection + config write verified. O6 (mixed 5/9-space body indent — cosmetic) | battery X1–X2 |
| `menu_settings_default_path` (2830–2851) | **R17 change 1 (O1) applied** (see below). Loop discipline verified: empty input → retry, nonexistent dir → `ui_msg_error` + retry, valid dir → store + rc0 | battery P1–P4 |
| `menu_settings_options` (2854–2889) | no defects. All-off-then-mark-selected logic gives the correct config state for every selection (incl. empty selection → all 7 off); cancel → config byte-identical. O7 (cancel → implicit rc0 vs `return "$ES"` elsewhere; `CHOICE`/`ON` globals + the intentionally-unquoted `for SELECTED in $ON` list split — making `local` = RISKY) | battery O1–O3 |
| `menu_tools` (2892–2966) | no defects. All 9 arms dispatch correctly (INSTALL/UPDATE\`gui\`/UNINSTALL/DETAILS→select→details/ERASE→select+format→`media_format "$DEVICE" "$FORMAT"`/TERMINAL read-EOF degrades gracefully/LOG→`$TEXT_EDITOR "$LOG_FILE"`/HELP+ABOUT via msgbox). O3 (dead `HELP)` case arm — the TOOLS menu has no `HELP` item) | battery T1–T6 |
| **top-level flow** (2967–3010) | no defects. `-v`/`uninstall` early-exits **before** config init are intentional (fast, side-effect-free probes). O8 (update-check exemption `[[ $4 = -y ]]` is position-dependent — the documented order `backup [media] [file] [-y]` (help L163) works; out-of-order `backup -y dev out` trips `IN-DEV '-y'` — logged, behavior preserved) | gated probes (`bash pisafe -v`); arm-level mapping covered by C-*/G-* |

## Changes applied (both user-approved 2026-10-18)

Net diff: **3 insertions / 2 deletions** (blob `ec90f24` → `bd78b79`; 3009 → 3010 lines — the one added line is the `ABOUT` menu row, so group-11 line refs from `menu_select_device` onward shift +1; inventory re-verified against the new spans).

### O1 — `menu_settings_default_path`: GNU-ism in the strip-`sed` bracket (portability)
Old: `DEFAULT_PATH=$(echo "$NEWPATH" | sed 's/[/\t]*$//')`. New: `sed $'s/[/\t]*$//'` (+ inline comment).
* **Measured (GNU sed 4.9, the target):** current code already behaves — `/tmp`→`/tmp`, `test`→`test`, `/home/bob/`→`/home/bob`, trailing tab stripped. So this is **latent, not active** on GNU hosts.
* **Risk it removes:** a POSIX-strict `sed` (busybox-class) reads the in-bracket `\t` as backslash-`t` (literal `t`), i.e. bracket = `{/, t}` — it would **eat the trailing `t`**: `/tmp` → `/tm`, `test` → `tes`. On a Pi where `sed` is busybox, a valid typed path ending in `t` would be silently mangled into a non-existent directory on the *next* use.
* `$'…'` makes the bracket contain a **real tab byte** — identical under GNU and strict-POSIX seds. Battery **P2** pins exactly this: `/tmp` stored as `/tmp` (a strict-POSIX sed would fail the assertion).

### R17 change 2 — `menu_gui`: wire in `ABOUT` (and fix the HELP continuation)
Old: `"HELP"    "   Help"\` (missing space before the continuation — the token `Help" \` … `ABOUT"` would have fused) directly into `3>&1 1>&2 2>&3`. New:
```
"HELP"     "   Help" \
"ABOUT"    "   About $PRODUCTNAME" \
```
* Makes the **previously-dead `ABOUT)` case arm (→ `ui_msg ABOUT "$(pisafe_about)"`) reachable** — `pisafe_about` itself was reviewed in R11 and battery-verified (C9/G2 exercise it end-to-end now). Symmetric with `menu_tools`, which already offers ABOUT.
* Battery **G2** asserts: the main menu now *offers* the item (whiptail args contain `About PiSafe`) **and** the arm fires (`ui_msg ABOUT` + `pisafe_about` recorder).
* Behavior-preserving otherwise: one new menu item + one space fix; no arm, rc, or string changed (the ABOUT description is new text by design — it *is* the feature the user approved).

Both changes re-ran the full gates post-edit: `bash -n` ✓, `bash pisafe -v` → `1.2.12-beta.5` ✓, `./lint.sh` **0 findings** ✓, full 2-hunk diff read ✓.

## Verification

* Battery **60/60 green** (`/tmp/opencode/r17/r17_battery.sh`, re-runnable; authoritative counts from the `2>` `RRESULT` capture, per the R16 stale-file-surface lesson). Harness: single-process `lib.sh` = R16 lib + the 10 group-11 functions + the real `config_var_*` layer (extracted verbatim from the app post-edit) + recorder stubs for the layer below (media_*/pisafe_*/`do_list_info`/`env_sysinfo`); scripted `whiptail` fake (call N reads response line N; `CANCEL*` → rc1; **answers on fd 2** because the app's `3>&1 1>&2 2>&3` swap routes real whiptail's stderr into `$( )`); controlled `lsblk` in `binls/` (deterministic 2-device media list); `bin3/` + `env_which`-absent override for the no-whiptail CLI branch (the host has a real `/usr/bin/whiptail`); `editor`/`nano` recorders (real editor on the sandbox is interactive). Loop-exit rule encoded: `menu_settings`/`menu_tools` exit **only** on whiptail rc≠0 (their `*)` arms msgbox-and-loop), so all their tests end in a scripted `CANCEL`; `menu_gui` exits on any non-item (`*) return`).
* Gates: `bash -n` ok · `bash pisafe -v` → `1.2.12-beta.5` · `./lint.sh` → **0 findings** · `git status` → only `pisafe` + the round docs modified · full 3/2 diff read ✓.
* Pre-existing behavior probes (read-only, no device I/O): `media_backup_check_outfile` full chain with real `lsblk`/`df` on the host's `/dev/sda` (F-tests), `menu_cli` arg mapping, top-level `-v`. **Nothing in `media_backup|restore|format|install|uninstall|update` real bodies was executed** — those arms are recorders; destructive harness pass remains the user's step.

## Status changes

* Inventory §11: 10 `open` → **`reviewed`** (10/10, line refs re-verified at the +1 shift). Coverage: **78 reviewed / 0 partial / 0 open** — the function checklist is complete; the group-12 top-level-flow region note updated to 2967–3010.
* Known-issues backlog: O1 resolved; 8 observations below remain open-logged.
* Release ladder: **(a)** code done + agent battery green ✓ (this round closes it). **User instruction 2026-10-19 (deviating from the default ladder):** `SCRIPTVER` bumped `1.2.12-beta.5` → `1.2.12-beta.6` and the code was **committed + pushed to `development` before the harness pass** — the destructive `pisafe_test` pass on this exact code remains the outstanding functional-verification step; a pre-harness defect would require a beta retraction. No tag (separate user action).

## Open items (logged, no changes — user-call; user chose not to act on these in R17)

1. **O2** `menu_cli` runs literal `nano` for `log`/`settings` (L2562/2564) while the GUI uses `$TEXT_EDITOR` — the CLI help text documents `nano` explicitly; kept as-is (changing = user-visible behavior, RISKY-class).
2. **O3** dead case arms: `menu_cli -v)` (shadowed by the top-level `-v` early-exit), `menu_settings Text*)`, `menu_tools HELP)` (no TOOLS menu item) — dead code left in place (deletion = RISKY-class, user declined this round).
3. **O4** `menu_select_device` L2712: `ES=$?` after `mapfile < <(media_list …)` reads mapfile's rc (always 0), not the list's — the empty-list→rc1 path is behaviorally covered by the `arraylength 0 → return 1` check; `IFS=$'\n'` before `mapfile` is a no-op.
4. **O5** `menu_set_compression` radiolist hard-codes level `5 on` regardless of the stored level (asymmetry with the extension picker, which reflects the current value) — cosmetic.
5. **O6** cosmetic indentation: `menu_settings` def at 2 spaces; `menu_settings_default_extension` body mixed 5/9 spaces — candidate for a future standards pass, not applied (focus: no unneeded changes).
6. **O7** `CHOICE`/`ON`/`TEMP_PATH`/`arraylength` are globals (making them `local` = RISKY scoping change); `menu_settings_options` cancel → implicit rc0 vs `return "$ES"` elsewhere; `for SELECTED in $ON` is an intentionally-unquoted list split.
7. **O8** top-level update-check exemption `[[ $4 = -y ]]` is position-dependent: the documented flag-last order works (help L163); out-of-order `backup -y dev out` produces the `IN-DEV '-y'` error. Documented behavior; preserved.
8. **O9** `menu_gui` `LIST)` arm's stray `echo "Getting list of images ready..."` prints to the terminal even in GUI mode (log line leaked) — cosmetic.
9. **O10** `menu_select_device`: a device vendor/model string containing `|` would break the `IFS='|'` token pairing (tag/description split) — rare edge, no action.

*Resolved-not-defects during review:* `sed 's/ / | /'` no-`/g` is correct (first-space-only split — D4 battery multi-word vendor); `.tar` out-files cleanly rejected by the real `media_backup_check_outfile` ("Unsupported file extension") with the retry loop (F3); `env_which` contract (`1`+rc0 present / empty+rc1 absent); `menu_cli` `$2..$4` mapping consistent with the R16-reviewed entry-point signatures; `TERMINAL)` `read -r -s -n 1` degrades gracefully on EOF (T5/G10); top-level `-v`/`uninstall` early-exits before config init are intentional probes (covered by the `bash pisafe -v` gate).
