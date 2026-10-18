# Review Round 11 — leaf layer (inventory groups 1–5): 13 functions reviewed, 2 SAFE fixes, 4 observations

**Baseline:** `development` @ `68032db` (inventory v4 scanner fix). `pisafe` = 3007 lines, version `1.2.12-beta.5`, worktree byte-identical to `dev:pisafe` (blob `a176f2f`). `shellcheck` clean, `bash -n` clean.

**Goal (approved 2026-10-18):** complete the function review of inventory groups 1–5 in the corrected dependency order — **env, primitives, config_var, ui, get** (21 functions: 13 not-yet-reviewed + 8 previously reviewed). Campaign focus applies: **reliability first, then standards and readability — no unneeded changes**.

**Outcome:** all 21 scope functions reviewed against their live code. 13 functions flip `open → reviewed`; no reliability defects found. 2 SAFE cleanups applied on user instruction ("fix and commit", 2026-10-18): **O1** `echo_if_cli` gains the missing `blue` arm (parity with `ui_echo`; was unreachable — no caller passes blue) and **O2** `run_command`'s provably-dead `local LINE=$2` removed (callers who pass a second arg are unaffected — bash ignores excess args). O3–O6 remain as logged observations (deliberate author choices / RISKY class / earlier keep-decisions). Net diff: **+1/−1 line** (`fe1e94d` vs `a176f2f`).

## Scope + findings (each function read in full at `16158f3`)

| function | finding | disposition | evidence |
|---|---|---|---|
| `env_*` (6) | unchanged since the beta.3/beta.5 audits; v4 scanner adds 4 real `$( )` edges on `env_sysinfo` (previously invisible) | KEEP — evidence re-check | code re-read; inventory v4 |
| `config_var_*` (5) | unchanged since recorded audits; v4 adds real `file_path` edge on `init_configfile` | KEEP — evidence re-check | code re-read; inventory v4 |
| `echo_white/red/blue` | one-line ANSI wrappers; `$*` is always one arg that starts with the ESC prefix — no `echo` flag-interpretation risk | **reviewed** | T01–T03 exact-output match |
| `notes_performance` | dead raw-text block — **if ever called** the text is parsed as commands (a wall of `command not found`); 0 call sites; R10 user decision was "keep" | KEEP + **O6** | read 91–112; call-site grep = 0 |
| `run_command` | `eval "$CMD"` (R10 B1 quoting), `ES=$?` capture, red exit-line on failure; **`$2` (LINE) is never read** — dead parameter → **fixed: `local LINE=$2` removed** (behavior-identical; callers passing a second arg are unaffected) | **reviewed** + O2 *(fixed)* | T17 (rc0/ES0/running-line), T18 (rc1/ES1/Exit_Status) |
| `echo_if_cli` | CLI color dispatch `white`/plain; **no `blue` arm** — blue silently uncolored on CLI. No live caller passes blue (3 call sites pass white/plain/plain) → was unreachable, not a defect → **fixed: `blue) echo_blue "$MSG" ;;` arm added** for parity with `ui_echo` | **reviewed** + **O1** *(fixed)* | T19 (now asserts white+blue+red all colorize; off-CLI silent); call-site grep |
| `ui_countdown` | locals; CLI→`do_countdown`, GUI→`whiptail_countdown` with the documented "no `--timeout`, swallows keys" constraint | **reviewed** | T13 (y-path early exit, rc0) |
| `ui_echo` | (already reviewed) locals, blue arm, `>&2`, LOGIT gate — re-confirmed | KEEP | T09 |
| `ui_log` | `local INFO=$*`; strict `LOG = on` gate; sed collapses literal `\n` → ` -` (one leading space — consistent with the identical sed at `ui_yesno` L2026) | **reviewed** | T04 (off: no file), T05 (on: `alpha -beta` line format) |
| `ui_msg` | CLI arm: `PRODUCTNAME TITLE: MSG` to stderr, colored; GUI arm: whiptail + fd-swap `3>&1 1>&2 2>&3`; empty `--ok-button ""` is a **file-wide convention** (8+ call sites incl. all `ui_msg_error/warning` paths) — shipped behavior in beta.2–4 | **reviewed** + **O4** | T10 |
| `ui_msg_error` | `shift` happens **before** `local MSG="$*"` — order is correct (MSG excludes the lineno); beep is `SOUND`-gated inside `do_beep` | **reviewed** | T11 (`Error at line 42. kaput` logged) |
| `ui_msg_warning` | double `do_beep` = intentional two-ding | **reviewed** | T12 |
| `ui_yesno` | strongest leaf in the file: documented rc contract (0 = answered, 1 = no answer); **EOF/Ctrl-C guard** (`read` rc>0 → `n`, rc1) prevents the infinite retry loop; other keys re-ask (bounded by y/n/EOF) | **reviewed** | T06 (y), T07 (q→re-ask→n), T08 (EOF → n, rc1) |
| `get_args` | global flag-setter by design (comment declares it; callers read the globals); `for ARG in $ARGS` word-split is intentional over fixed flag tokens — RISKY class, **untouched**; `-1…-9` level map | **reviewed** | T15 (`SOUND=on LVL=5 LOG=off`) |
| `get_args` | **no `*)` catch-all** (deliberately commented out, L815) → unknown flags silently ignored (a typo'd flag goes unnoticed) | KEEP + **O3** | T16 (`--totally-bogus` → rc0, no output) |
| `get_elapsed_time` / `get_ver_to_int` | previously reviewed (R2); re-confirmed | KEEP (re-verification) | read |
| `get_bytes` | previously reviewed (R1 TB fix `2014`→`1024`); regression re-run | KEEP (re-verification) | T20: 1 TiB → `1.00tb` |
| `do_countdown` *(group 9, reviewed only as `ui_countdown`'s dependency)* | full body read: key `y` → early exit rc0; other key → stop rc1; read-timeout → wait for next second; **message says "N seconds" but there is a leading `sleep 1` → actually N+1 s** — cosmetic, no change; `INPUT` is a global (file convention) | evidence pre-logged for the do-group round — status stays `open` | T13, T14 |

## Observations

* **O1** *(fixed, 2026-10-18)* `echo_if_cli` had no `blue` arm — unreachable until now (no caller passed blue); one-line arm added for parity with `ui_echo`.
* **O2** *(fixed, 2026-10-18)* `run_command`'s `$2` (LINE) was a dead local; removed.
* **O3** `get_args` silently ignores unknown flags — a `*)` warn arm would be a user-visible-string change (RISKY; the author deliberately left the `*)` arm commented out). **Left as-is.**
* **O3** `get_args` silently ignores unknown flags — a `*)` warn arm would be a user-visible-string change (RISKY).
* **O4** `--ok-button ""` (empty OK label) is used at 8+ sites — GUI appearance; shipped in beta.2–4; confirm it looks acceptable on the user's harness.
* **O5** `do_countdown`: "N seconds" wording vs N+1 real seconds (leading `sleep 1`); global `INPUT`.
* **O6** `notes_performance` — calling it would spam `command not found`; dead by design, kept per R10 decision. (User may want the same comment-out treatment `notes_desktop_environment` received.)

## Verification (measured 2026-10-18)

* `bash -n pisafe` — OK
* `bash pisafe -v` — `1.2.12-beta.5`
* `./lint.sh` — **0 findings**
* Behavior battery **20/20 pass** (`/tmp/opencode/leaf_battery.sh`, re-runnable): 13 scope functions exercised in CLI mode — colors, log gate + line format, yes/no rc contract incl. EOF guard, countdown both key paths, flag mapping, run_command success+failure paths, `get_bytes` TB regression. GUI paths stubbed (whiptail/beeps no-op) so no terminal could open; `SOUND=off`; log file under `/tmp/opencode`.
  * *Transparency note:* the first battery draft had a harness bug — nested `bash -c` layers dropped `INTERFACE=cli`, so one `ui_msg_error` test took the GUI branch and whiptail briefly opened the session terminal ("Failed to open terminal", no device I/O). Battery v2 runs in a single process with whiptail stubbed; the recorded 20/20 run is clean.
  * *Post-fix re-run:* after applying O1/O2, battery extraction ranges were re-derived (the removed `run_command` line shifted everything below by one), `T19` now asserts the **new** blue-arm behavior (white+blue+red all colorize on CLI, silent off-CLI), and the full battery re-ran **20/20 pass** against the fixed file.
* **Code changes this round:** exactly two — `git diff` shows +1/−1 line in `pisafe` (new blob `fe1e94d`), both in scope, both SAFE-class; nothing else in the working tree was touched by this round.

## Status changes

13 functions `open → reviewed`: `echo_white`, `echo_red`, `echo_blue`, `notes_performance`, `run_command`, `echo_if_cli`, `ui_log`, `ui_yesno`, `ui_countdown`, `ui_msg`, `ui_msg_error`, `ui_msg_warning`, `get_args`.
Inventory totals: **28 reviewed / 2 partial / 48 open** (was 15/2/61).

## Open items

* O3–O6 are open user decisions (none block anything). O1/O2 were fixed in this round's final pass.
* Groups 6–11 (pisafe, file, whiptail, do, media, menu) await rounds 12+ in inventory order.
* GUI-side behavior (whiptail arms of `ui_countdown`/`ui_msg`/`ui_yesno`, O4 ok-button look) remains user-harness territory.
