# Review Round 15 — small action runners (inventory group 9, `do_*`): 5 functions reviewed, 0 defects, 6 observations

**Baseline:** `development` @ `9b7c1be` (R14). `pisafe` = 3009 lines, blob `58440e9`, version `1.2.12-beta.5`. `shellcheck` clean, `bash -n` clean.

**Goal (approved 2026-10-18, "next"):** complete the function review of inventory **group 9 — small action runners**: `do_beep`, `do_beep_up`, `do_beep_down`, `do_countdown`, `do_list_info` (5 functions, all `open`). Campaign focus applies: **reliability first, then standards and readability — no unneeded changes.**

**Outcome:** all 5 scope functions read in full and exercised by an 11-test behavior battery. **0 defects.** 2 SAFE cleanups applied on user instruction ("Docs + 2 SAFE fixes"): **O3** `do_beep_down` body indented to the file's 4-space convention, **O6** `echo "$PRODUCTNAME" ver "$SCRIPTVER"` quoted (single fixed tokens — output-identical). 4 minor observations remain logged (O1, O2, O4, O5), none block — O4 re-confirms R11's O5 with a fresh measured pin.

## Scope + findings (each function read in full at `9b7c1be`)

| function | finding | evidence |
|---|---|---|
| `do_beep` (694–701) | both guards verified: `SOUND=off` → `speaker-test` **never invoked** (short-circuit before `env_which`); `SOUND=on` + tool on PATH → exactly `speaker-test -t sign -f 600` (defaults applied) and the process is **killed dead** by the `kill -9 $!` — no survivor process. The kill pattern is correct because the target is backgrounded *inside the same subshell* that kills it (`$!` is unambiguous). Observations: **O1** `FREQ`/`TIME` are globals (adding `local` is RISKY-class; no call-site collision — every caller passes both args) · **O2** `speaker-test` stderr is not redirected (ALSA banner whiff reaches the terminal whenever SOUND=on) | T01 (SOUND=off → zero invocations), T02 (args recorded), T02b (no `sleep 7777` survivor — fake stood in for `speaker-test`) |
| `do_beep_up` / `do_beep_down` (704–713) | chirp sequences exact and in order — up = 500→600, down = 600→500 (.3/.6 cadence each); fire-and-forget callers (menu actions L1162/L1303/L1320/L1759/L1994) ignore rc, which is coherent with the design. **O3 (SAFE, fixed this round):** `do_beep_down` body indented 3 spaces vs the file's 4-space convention — normalized | T03 (fake's record file shows `-t sign -f 500, 600, 600, 500` in order) |
| `do_countdown` (727–751) | rc contract verified end-to-end: `y` → **rc0 continue**; **any other key → rc1 stop**; timeouts → loop runs out → **rc0 proceed**. The contract matches its GUI sibling `whiptail_countdown` (rc0=go / rc1=stop) so `ui_countdown`'s dispatch is coherent either way. **ENTER behaves as a stop key** (`read -N 1` preserves the newline in `$INPUT`, so it is a genuine "other key" — the prompt text "any other key to stop" is *accurate*, including for ENTER and whitespace). Observations: **O4** real pause is **N+1 seconds** (initial `sleep 1` grace is not counted; re-confirms R11-O5, now measured) · **O5** `INPUT` global + bare `return` at L742 relies on the preceding `echo` rc0 (correct; `return 0` would be more explicit) | T04 (`y` → rc0 + "Continuing"), T05 (`x` → rc1 + "Stopping"), T06 (ENTER → rc1 + "Stopping" — pin), T07 (MAX=2 took ≥3 s — O4 pin), T08 (defaults: MAX=10 message + `y` → rc0) |
| `do_list_info` (1036–1054) | full composition verified against the **real** R13-tested file/size layer: system block (product/ver/OS/kernel), `env_root_device` value, `media_size` invoked **`<rootdev> -h`** (arg list captured by stub), Trash/RootTrash sizes, `media_list` body, image-file listing + freespace header, rc0. **O6-unused-`$1`:** `$1` is unused (stale `# DIR=${1:-$PWD}` comment; caller at L2684 passes `$DEFAULT_PATH` — same value as the global that actually governs, so no effective difference). **O6-quoting (SAFE, fixed this round):** `echo "$PRODUCTNAME" ver "$SCRIPTVER"` now quoted — single fixed tokens, output-identical | T09 (all sections + stub values + arg capture), T10 (arg `/some/other/dir` provably ignored — pin) |

## Verification (measured 2026-10-18)

* **Battery 11/11 green** (`/tmp/opencode/r15_battery.sh`, re-runnable): the 5 scope functions + real `env_which`/`env_root_device` + the R13-tested `get_bytes`/`file_*` layer extracted and sourced; `media_list`/`media_size` stubbed (group-10 scope — here we verify *composition*, incl. the exact `media_size "<dev>" -h` arg list); `sudo` passthrough; `ui_msg_warning` stubbed.
* **Fake `speaker-test` on PATH:** records its exact args + PID to files, then `exec sleep 7777` — so `do_beep`'s `kill -9 $!` genuinely has to stop a live process (T02b asserts none survives via `pgrep`; `pgrep` over `kill -0` because an unreaped zombie would false-kill-check).
* **Harness self-correction (documented for transparency):** T06's first draft assumed `read` would IFS-strip the newline and predicted "ENTER is ignored" — the run showed INPUT kept the newline and took the **stop** branch. The prompt wording is correct; the test expectation was wrong. Flipped T06 to assert stop (rc1) → 10/11 → 11/11.
* Gates post-round: `bash -n` ✓ · `bash pisafe -v` → `1.2.12-beta.5` ✓ · `./lint.sh` **0 findings** ✓
* `git diff pisafe` after the two SAFE fixes = **+3/−3** (O3 indent on 2 lines, O6 quoting on 1 line — line count unchanged: 3009); diff read in full before reporting.

## Status changes

5 functions `open → reviewed`: `do_beep`, `do_beep_up`, `do_beep_down`, `do_countdown`, `do_list_info`.
Inventory totals: **52 reviewed / 2 partial / 24 open** (was 47/2/29).
`pisafe` blob `58440e9` → `c19d043` (line count unchanged: 3009).
v4 structure scan unchanged (line-count-neutral fixes); rendered with the R15 ST annotations.

## Open items

* **O1, O2, O4, O5** remain logged, none block (details in the table above + inventory annotations); the **unused-`$1`** half of O6 stays as an observation. O1/O5 (`local`s) are RISKY-class — user decides; O2 stderr redirect — cosmetic; O4 UX nit. **O3 and O6-quoting were fixed this round.**
* **No new user-facing behavior this round** — the destructive-harness pass list is unchanged (R14's `..` row check remains the only delta to try).
* Next in inventory order: **group 10 — media ops (backup/restore/format core, 15 functions)**, then group 11 `menu` (12 functions). 24 `open` + 2 `partial` remain.
* Release ladder unchanged: code done + battery green → user's destructive-harness pass on that exact code → beta.6 tag + push (each step separately confirmed).
