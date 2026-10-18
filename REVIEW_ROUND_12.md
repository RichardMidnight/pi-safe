# Review Round 12 — lifecycle layer (inventory group 6, `pisafe`): 7 functions reviewed, 1 defect fixed, 4 observations

**Baseline:** `development` @ `b33c890` (R11). `pisafe` = 3007 lines, blob `fe1e94d`, version `1.2.12-beta.5`. `shellcheck` clean, `bash -n` clean.

**Goal (approved 2026-10-18, "now R12"):** complete the function review of inventory **group 6 — the `pisafe` lifecycle**: `pisafe_about`, `pisafe_help`, `pisafe_update`, `pisafe_uninstall`, `pisafe_install`, `pisafe_install_tool`, `pisafe_install_tools` (7 functions, all `open`). Campaign focus applies: **reliability first, then standards and readability — no unneeded changes**.

**Outcome:** all 7 scope functions read in full against their live code and exercised in a fully stubbed behavior battery. **1 genuine reliability defect (D-1) found, proven by the battery, and fixed** (one-line addition, user-approved "Fix and commit", 2026-10-18): `pisafe_install_tools` never read its `$1` flag, so the *ask-before-installing* branch was dead code and missing dependencies were silently auto-installed on every plain startup. O1–O4 remain as logged observations (all RISKY/user-decision class — no changes made). Net diff: **+1/−0 line** (`b0ddbd1` vs `fe1e94d`).

## Scope + findings (each function read in full at `b33c890`)

| function | finding | disposition | evidence |
|---|---|---|---|
| `pisafe_about` | pure `echo` provenance text; uses published globals (`PRODUCTNAME`, `$PRODUCTHOME`); no logic | **reviewed** | T01 exact-substring match |
| `pisafe_help` | usage/help text; escapes (`\$`) correct for the examples; trailing space inside one label string is cosmetic display text — untouched (user-visible string) | **reviewed** | T02 |
| `pisafe_install` | full pass verified under stubs: guard (`readlink -f "$0"` vs install dir), numbered `cp` + `chmod`, icon download with `-s` size check + cleanup both ways, `NO_DISPLAY`/hidden-menu paths, desktop-file write + cp with **failure-keep + warning** path, final installed/not-installed message. Two observations below. | **reviewed** + O1/O2 | T20 (desktop entry asserts `NoDisplay=true` + `Exec=`; failure-warning path; icon warning) |
| `pisafe_install_tool` | all 3 arms verified: `xz` → `xz-utils` package mapping; `pishrink.sh` → direct download (works with **no** package manager), download-fail + not-found warnings, temp cleaned both ways; `*)` generic arm → `sudo $INSTALL $TOOL` with `ES=$?` capture (correct — `run_command` returns the real status; **not** a defect) | **reviewed** | T03–T09 |
| `pisafe_install_tools` | **D-1 defect — see below.** Loop over `$REQUIRED_TOOLS` is intentional word-split over fixed tokens (RISKY class, untouched); newt/libnewt fallback for whiptailless distros verified. | **reviewed** + **D-1** *(fixed)* | T10–T13 (T11 = pre-fix failure evidence) |
| `pisafe_update` | download → `bash "$SCRIPTNAME.tmp" -v` sanity → `get_ver_to_int` compare (empty/garbage server version → 0 → "up to date", covered by the R2 fix); net-fail path cleans tmp + returns wget's rc; decline / apply paths verified incl. the `exit 0` after a successful update (contained in a battery subshell). One observation below. | **reviewed** + O2/O4 | T14–T17 |
| `pisafe_uninstall` | removal set verified (`--backup=numbered` script, desktop, icon dir, config) + `--defaultno` prompt + decline path. Final message says the log is kept but is silent about the config removal (O3). | **reviewed** + O3 | T18–T19 |

## D-1 — dead "ask before installing" branch (defect, fixed this round)

* **Symptom (battery-proven, pre-fix):** `pisafe_install_tools -n` with tools missing and a *No* answer still installed everything — `T11` **FAIL** pre-fix (19/21… 20/21 overall), passes after the fix.
* **Root cause:** the function tests the **global** `SILENT` (`elif [[ "$SILENT" = -n ]] && [[ $(ui_yesno …) = n ]]`), but **never reads its own `$1`**. At the startup call sites (main flow `pisafe` L2991–2998: `pisafe_install_tools -y` / `-n`) the argument is dropped, and `get_args` sets `YESNO`, **not** `SILENT` — so `SILENT` is whatever a previous call leaked (usually unset) → `"" = -n` is false → the `return` is unreachable → **silent install**. The `-y` case only works by accident (unset also falls through to install).
* **Corroboration:** both siblings do exactly the missing step — `pisafe_install` L199 and `pisafe_uninstall` L436 begin with `SILENT=${1:-"-n"}`; the dead comment at L278 (`#SILENT=${1:-"-n"}`, inside `pisafe_install_tool`) shows the pattern was known to the author.
* **Impact:** on every plain startup with a missing dependency, missing tools (plus the newt/libnewt fallback package) are installed **without the prompt that was written for it**.
* **Fix (1 line, mirrors the siblings, RISKY-class → user-approved 2026-10-18):**

  ```bash
  pisafe_install_tools() {
      SILENT=${1:-"-n"}        # ← added
      local MISSING_TOOLS=
  ```

* **Post-fix semantics (all battery-verified):** `-n` → ask, `n` aborts (T11), `y` installs (T11b); `-y` → silent (T12); all-present → quiet early return (T10); newt fallback unaffected (T13).

## Observations (no change made — RISKY/user-decision class)

* **O1** `pisafe_install` copies **CWD-relative `"$SCRIPTNAME"`** into `/usr/local/bin` (L212), but the guard one line above compares **`$0`** (the running script). Running the app as a differently-named copy (e.g. the AGENTS-recommended `cp pisafe /tmp/pisafe-run && bash /tmp/pisafe-run`) would install the wrong/absent file. `"$0"` would be the consistent source.
* **O2** Unguarded direct execution of `"/usr/local/bin/$SCRIPTNAME" -v` after install (L215) and after update (L417) — if the binary isn't really there (failed `sudo`), the user gets `command not found` noise and/or an empty version in the message. Same empty-variable family: `pisafe_uninstall` computes `INSTALLED_VER` only if the installed binary exists, so its prompts can show an empty version.
* **O3** `pisafe_uninstall` removes the user config (`rm -f "$CONFIG"`) but the final message only mentions the **log** file being kept — the config removal is not communicated.
* **O4** `pisafe_update` leaves `"$SCRIPTNAME.tmp"` in the CWD when the user **declines** the update (cleanup only exists on net-fail / up-to-date / applied paths).

## Resolved non-issues (checked, no action)

* `pisafe_install_tool` `*)` arm: `ES=$?` after `run_command` is **correct** (`run_command` returns the underlying command's status; R11 T17–T18 evidence).
* `xz`/`dd`/pishrink arms re-verify with `env_which` after install — defense in depth, kept.
* `SILENT` contract at *all other* call sites: `pisafe_install`/`pisafe_uninstall` set-then-test from `$1`; startup main-flow passes explicit `-y`/`-n` (only D-1 broke that path).
* `pisafe_update`'s pre-exec sanity check is `bash "$SCRIPTNAME.tmp" -v` — executes only the version-echo early-exit path (main flow L2969–2972); acceptable for a first-party script; unparseable server version degrades to "up to date" (`get_ver_to_int` → 0, R2).

## Verification (measured 2026-10-18)

* `bash -n pisafe` — OK (pre- and post-fix)
* `bash pisafe -v` — `1.2.12-beta.5`
* `./lint.sh` — **0 findings** (pre- and post-fix)
* Behavior battery **21/21 pass** post-fix (`/tmp/opencode/r12_battery.sh`, re-runnable); **20/21 pre-fix** with the sole failure = `T11`, i.e. the D-1 defect itself.
  * All system calls stubbed in one source-process: `sudo` + `run_command` record invocations to files, `wget` serves a canned file, `env_which`/`env_installer`/`env_terminal` scripted, ui layer canned — **nothing installed, no network, no device I/O**.
  * *Host note (transparency):* this box has a real `/usr/local/bin/pisafe` = `1.2.12-beta.3` (installed from a published beta). The battery runs `-v` against it once (harmless early-exit) and asserts host-independently: T20 verifies the desktop-entry *content* via the forced-failure-keep path (stub `sudo cp` → failure warning, temp `.desktop` retained — this also exercises that error branch) and matches the shared `installed` substring of the final message.
  * *Extraction drift handled:* the post-fix battery uses re-derived ranges (the added L337 shifted everything below by +1) — same lesson as R11.

* **Code changes this round:** exactly one — `git diff` shows **+1/−0 line** in `pisafe` (new blob `b0ddbd1`), the D-1 line; nothing else touched.

## Status changes

7 functions `open → reviewed`: `pisafe_about`, `pisafe_help`, `pisafe_install`, `pisafe_install_tool`, `pisafe_install_tools`, `pisafe_update`, `pisafe_uninstall`.
Inventory totals: **35 reviewed / 2 partial / 41 open** (was 28/2/48).

## Open items

* O1–O4 are open user decisions (none block anything; none are required for beta.6).
* Group 7 (`file`, 9 functions) is next in inventory order, then whiptail, do, media, menu (41 `open` + 2 `partial` remain).
* Release ladder unchanged: code done + battery green → user's destructive-harness pass on that exact code → beta.6 tag + push (each step separately confirmed).
