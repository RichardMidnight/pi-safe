# PiSafe — function inventory (dependency order)

* **Source:** `development` @ `b33c890` (R11) + the R12 one-line fix (blob `b0ddbd1`) · generated 2026-10-18 (v4 scanner, re-run after the R12 fix) · file is 3008 lines, **78 functions** + top-level flow
* **Rev 2026-10-18 (v4):** dependency re-scan with a context-correct parser. The v3 scanner missed function calls made as `$( … )` inside double-quoted strings (and nested-quote contexts could shuffle state). v4 recovers **42 such edges** (all verified against source lines); **zero spurious edges were removed** — so v3's "no deps" claims were undercounts, never overcounts. Depths rose for 25 of 78 functions; the group order below reflects the corrected depths.
* **Purpose:** make the campaign goal "review all leaf → mid → top functions" a finite, checkable checklist. Work through this list **in document order** (leaves first, menus/dispatch last) — every `open`/`partial` function gets a round; `reviewed` rows stay marked with their evidence.
* **Order:** groups sorted by their **maximum** dependency depth (increasing dependency, as requested); within a group, functions by depth then line number. `deps` = other pisafe functions it calls (verified against the code; quoted strings and comments excluded, so string mentions do not create edges).
* **Status legend:** `reviewed` = has a logged review/fix round · `partial` = only a named area reviewed — the rest of the body is still open · `open` = not yet reviewed.
* **Cross-cutting passes (not per-function):** R1 SAFE quoting (237 sites, whole file), R10 shellcheck 17→0 — applied file-wide by the `lint.sh` gate; these do **not** count as a function review.

## Depth guide

```
  0  calls no other pisafe function          (true leaves)
  1-2  depend only on 0-1                    (helpers)
  3-4  depend on helper layer                (mid)
  5-9  engine + lifecycle                    (mid-top)
10-12  menus / main dispatch                 (top)
```

> Cycle note: the graph is acyclic (no function — directly or transitively — calls itself), re-verified with the v4 scanner. The `media_backup ↔ media_size` scare seen during v3 analysis was a parser artifact, not real recursion.

## 1. environment detection  ·  depth 0–2
*mostly leaf; env_sysinfo composes its siblings.*

| function | lines | size | depth | deps (pisafe functions it calls) | status |
|---|---|---|---|---|---|
| `env_root_device` | 593–606 | 14 | 0 | — | reviewed — beta.3 env family audit; R11 evidence re-check |
| `env_which` | 659–681 | 23 | 0 | — | reviewed — beta.3 env family audit (Manjaro `which` fix); R11 evidence re-check |
| `env_installer` | 571–590 | 20 | 1 | env_which | reviewed — beta.3 env family audit + beta.5 batch; R11 evidence re-check |
| `env_terminal` | 609–644 | 36 | 1 | env_which | reviewed — beta.3 audit + beta.5 batch (x-terminal-emulator target dispatch); R11 evidence re-check |
| `env_texteditor` | 647–656 | 10 | 1 | env_which | reviewed — beta.3 audit + beta.5 batch (locals); R11 evidence re-check |
| `env_sysinfo` | 684–690 | 7 | 2 | env_installer, env_root_device, env_terminal, env_texteditor | reviewed — beta.3 env family audit; R11 evidence re-check (v4 adds 4 real `$( )` edges) |

## 2. color/output + misc helpers  ·  depth 0–2
*echo colors, run_command, echo_if_cli.*

| function | lines | size | depth | deps (pisafe functions it calls) | status |
|---|---|---|---|---|---|
| `echo_white` | 39–39 | 1 | 0 | — | reviewed — R11 leaf layer — ANSI wrapper + $* safety verified (T01) |
| `echo_red` | 40–40 | 1 | 0 | — | reviewed — R11 leaf layer — ANSI wrapper + $* safety verified (T02) |
| `echo_blue` | 41–41 | 1 | 0 | — | reviewed — R11 leaf layer — ANSI wrapper + $* safety verified (T03) |
| `notes_performance` | 91–112 | 22 | 0 | — | reviewed — R10 user decision: keep dead text block as-is; R11 confirmed dead (0 call sites) — see O6 |
| `echo_if_cli` | 2529–2540 | 12 | 1 | echo_blue, echo_red, echo_white | reviewed — R11 — CLI dispatch verified (T19; white+blue+red all colorize); O1 `blue` arm added in R11 fix |
| `run_command` | 115–125 | 11 | 2 | ui_echo | reviewed — R11 — eval/ES path verified (T17-T18); R10 B1 quoting; O2 dead local `LINE=$2` removed in R11 fix |

## 3. settings-file I/O  ·  depth 0–3
*get/set + defaults + load; no ui layer yet.*

| function | lines | size | depth | deps (pisafe functions it calls) | status |
|---|---|---|---|---|---|
| `config_var_get` | 509–512 | 4 | 0 | — | reviewed — beta.3 config_var family audit + R5.3/R7 + beta.5 batch; R11 evidence re-check |
| `config_var_set` | 485–506 | 22 | 1 | config_var_get | reviewed — beta.3 config_var family audit + R5.3/R7 + beta.5 batch; R11 evidence re-check |
| `config_var_get_settings` | 541–567 | 27 | 1 | config_var_get | reviewed — beta.3 config_var family audit + R5.3/R7 + beta.5 batch; R11 evidence re-check |
| `config_var_set_defaults` | 515–538 | 24 | 2 | config_var_set, env_texteditor | reviewed — beta.3 audit + beta.5 batch (ghost keys removed); R11 evidence re-check |
| `config_var_init_configfile` | 470–482 | 13 | 3 | config_var_set_defaults, file_path | reviewed — beta.3 config_var family audit + R5.3/R7; R11 evidence re-check (v4 adds file_path edge — real call) |

## 4. UI primitives  ·  depth 0–3
*whiptail/CLI message layer; ui_msg_error is the deepest (beep gate).*

| function | lines | size | depth | deps (pisafe functions it calls) | status |
|---|---|---|---|---|---|
| `ui_log` | 1956–1966 | 11 | 0 | — | reviewed — R11 — LOG gate + literal-newline collapse verified (T04-T05) |
| `ui_yesno` | 2011–2051 | 41 | 0 | — | reviewed — R11 — rc contract + EOF no-loop guard verified (T06-T08) |
| `ui_countdown` | 1922–1933 | 12 | 1 | do_countdown, whiptail_countdown | reviewed — R11 — CLI/GUI dispatch verified CLI side (T13); GUI arm = user harness |
| `ui_echo` | 1936–1953 | 18 | 1 | echo_blue, echo_red, echo_white, ui_log | reviewed — ui_echo scope/stream fix (logged in campaign) + R11 re-verify (T09) |
| `ui_msg` | 1969–1987 | 19 | 2 | ui_echo, ui_log | reviewed — R11 — CLI arm verified (T10); O4: empty --ok-button is file-wide convention |
| `ui_msg_error` | 1990–1997 | 8 | 3 | do_beep_down, ui_msg | reviewed — R11 — shift-before-capture order + lineno format verified (T11) |
| `ui_msg_warning` | 2000–2008 | 9 | 3 | do_beep, ui_msg | reviewed — R11 — verified; double beep intentional (T12) |

## 5. value parsing helpers  ·  depth 0–4
*flags, version ints, byte conversion.*

| function | lines | size | depth | deps (pisafe functions it calls) | status |
|---|---|---|---|---|---|
| `get_elapsed_time` | 716–724 | 9 | 0 | — | reviewed — cleaned in review; no open items; R11 re-confirmed |
| `get_ver_to_int` | 754–764 | 11 | 0 | — | reviewed — R2 — parse crash on `1.2.12rc1`-class input fixed; R11 re-confirmed |
| `get_args` | 767–819 | 53 | 0 | — | reviewed — R11 — flag map verified (T15-T16); O3: unknown flags silently ignored |
| `get_bytes` | 822–879 | 58 | 4 | ui_msg_error, ui_msg_warning | reviewed — R1 — TB multiplier bug fixed + R11 regression re-run (T20) |

## 6. lifecycle — install / update / uninstall + about / help  ·  depth 0–5
*env_installer + run_command dependent.*

| function | lines | size | depth | deps (pisafe functions it calls) | status |
|---|---|---|---|---|---|
| `pisafe_about` | 128–149 | 22 | 0 | — | reviewed — R12 — pure echo provenance text; no defects (T01) |
| `pisafe_help` | 152–195 | 44 | 0 | — | reviewed — R12 — usage/help text; no defects (T02) |
| `pisafe_update` | 374–433 | 60 | 3 | get_ver_to_int, ui_echo, ui_msg, ui_yesno | reviewed — R12 — netfail/decline/same-version/apply paths verified (T14-T17); O2 + O4 (tmp kept on decline) left to user |
| `pisafe_uninstall` | 436–466 | 31 | 3 | ui_echo, ui_msg, ui_yesno | reviewed — R12 — removal set + decline path verified (T18-T19); O3 (msg omits config removal) left to user |
| `pisafe_install` | 198–273 | 76 | 4 | env_terminal, ui_echo, ui_msg, ui_msg_warning, ui_yesno | reviewed — R12 — full stubbed pass (T20): cp/chmod, desktop NoDisplay + failure-keep paths; O1 cp source + O2 unguarded -v left to user |
| `pisafe_install_tool` | 276–333 | 58 | 4 | env_installer, env_which, run_command, ui_echo, ui_msg_warning | reviewed — R12 — all 3 arms verified (T03-T09): xz-utils mapping, pishrink download+cleanup, generic ES branch; env_which re-check kept |
| `pisafe_install_tools` | 336–371 | 36 | 5 | env_installer, env_which, pisafe_install_tool, run_command, ui_msg_warning, ui_yesno | reviewed — R12 — D1 FIX: missing `SILENT=${1:-"-n"}` (dead ask branch, silent auto-install) added; ask/no, ask/yes, silent, newt-fallback verified (T10-T13) |

## 7. file/size introspection  ·  depth 0–6
*device paths, sizes, image file listing, freespace.*

| function | lines | size | depth | deps (pisafe functions it calls) | status |
|---|---|---|---|---|---|
| `file_base` | 883–894 | 12 | 0 | — | open |
| `file_device` | 897–901 | 5 | 0 | — | open |
| `file_ext` | 904–906 | 3 | 0 | — | open |
| `file_folder_size` | 909–922 | 14 | 0 | — | open |
| `file_path` | 1006–1008 | 3 | 0 | — | open |
| `file_fs_freespace` | 925–949 | 25 | 5 | get_bytes | open |
| `file_image_size` | 952–980 | 29 | 5 | file_ext, get_bytes | open |
| `file_size` | 1011–1030 | 20 | 5 | get_bytes | open |
| `file_list_image_files` | 983–1003 | 21 | 6 | file_image_size, file_size | open |

## 8. whiptail dialog helpers  ·  depth 0–6
*calc-size + countdown are pure plumbing; fselect is a file browser (calls the file/size helpers).*

| function | lines | size | depth | deps (pisafe functions it calls) | status |
|---|---|---|---|---|---|
| `whiptail_calc_wt_size` | 2377–2403 | 27 | 0 | — | open |
| `whiptail_countdown` | 2512–2526 | 15 | 0 | — | open |
| `whiptail_fselect` | 2406–2509 | 104 | 6 | file_image_size, get_bytes | open |

## 9. small action runners  ·  depth 0–7
*beeps, countdown, list-info (list-info composes the file/media layer).*

| function | lines | size | depth | deps (pisafe functions it calls) | status |
|---|---|---|---|---|---|
| `do_countdown` | 727–751 | 25 | 0 | — | open |
| `do_beep` | 694–701 | 8 | 1 | env_which | open |
| `do_beep_up` | 704–707 | 4 | 2 | do_beep | open |
| `do_beep_down` | 710–713 | 4 | 2 | do_beep | open |
| `do_list_info` | 1036–1054 | 19 | 7 | env_root_device, file_folder_size, file_fs_freespace, file_list_image_files, media_list, media_size | open |

## 10. media ops — backup/restore/format core  ·  depth 0–10
*the engine: checklists, est, backup, restore, format.*

| function | lines | size | depth | deps (pisafe functions it calls) | status |
|---|---|---|---|---|---|
| `media_name` | 1060–1073 | 14 | 0 | — | open |
| `media_mount` | 1905–1917 | 13 | 0 | — | open |
| `media_partition_info` | 2268–2352 | 85 | 0 | — | open |
| `media_list` | 1877–1902 | 26 | 1 | env_root_device | open |
| `media_os` | 2355–2370 | 16 | 1 | media_partition_info | open |
| `media_format` | 2057–2246 | 190 | 4 | env_installer, env_root_device, env_which, media_name, run_command, ui_countdown, ui_echo, ui_msg, ui_msg_error, ui_msg_warning, ui_yesno | partial — beta.5 batch: no-PM install guards on the 4 ensure arms; rest of body open |
| `media_size` | 1076–1102 | 27 | 5 | get_bytes | open |
| `media_backup_bytes_to_read` | 1328–1349 | 22 | 6 | media_size, ui_msg_warning | open |
| `media_backup_check_indev` | 1352–1401 | 50 | 6 | env_root_device, get_bytes, media_name, media_os, media_size, ui_msg_error, ui_msg_warning, ui_yesno | open |
| `media_backup_estimate` | 1546–1633 | 88 | 6 | get_bytes, media_size, ui_echo | open |
| `media_backup_check_outfile` | 1404–1485 | 82 | 7 | file_base, file_ext, file_fs_freespace, file_path, get_bytes, media_backup_bytes_to_read, media_name, pisafe_install_tool, ui_msg_error, ui_msg_warning | open |
| `media_restore_checklist` | 1765–1874 | 110 | 7 | do_beep, echo_if_cli, env_root_device, file_device, file_ext, file_image_size, get_bytes, media_name, media_size, menu_select_device, pisafe_install_tool, ui_echo, ui_msg, ui_msg_error, ui_msg_warning, ui_yesno, whiptail_fselect | open |
| `media_details` | 2249–2265 | 17 | 7 | media_backup_estimate, media_name, media_os, ui_msg | open |
| `media_restore` | 1636–1762 | 127 | 8 | do_beep_up, echo_if_cli, echo_red, echo_white, file_ext, file_image_size, get_elapsed_time, media_name, media_restore_checklist, run_command, ui_countdown, ui_echo, ui_msg, ui_msg_error | open |
| `media_backup_checklist` | 1488–1543 | 56 | 9 | media_backup_check_indev, media_backup_check_outfile, media_name, menu_get_outfile, menu_select_device, ui_log, ui_msg_error, ui_yesno | partial — #55 no-media/boot-disk message; rest of checklist flow open |
| `media_backup` | 1105–1325 | 221 | 10 | do_beep_down, do_beep_up, echo_white, file_base, file_ext, file_size, get_bytes, get_elapsed_time, media_backup_bytes_to_read, media_backup_checklist, media_name, media_size, run_command, ui_echo, ui_msg, ui_msg_error | open |

## 11. menus + main dispatch  ·  depth 2–12
*drives everything above; deepest functions in the file.*

| function | lines | size | depth | deps (pisafe functions it calls) | status |
|---|---|---|---|---|---|
| `menu_select_device` | 2701–2738 | 38 | 2 | media_list | open |
| `menu_set_compression` | 2741–2758 | 18 | 2 | config_var_set | open |
| `menu_settings_default_extension` | 2801–2825 | 25 | 2 | config_var_set | open |
| `menu_settings_options` | 2852–2887 | 36 | 2 | config_var_get_settings, config_var_set | open |
| `menu_settings_default_path` | 2828–2849 | 22 | 4 | config_var_set, ui_msg_error | open |
| `menu_settings` | 2761–2798 | 38 | 5 | config_var_get_settings, config_var_set_defaults, menu_set_compression, menu_settings_default_extension, menu_settings_default_path, menu_settings_options, ui_log, ui_yesno | open |
| `menu_get_outfile` | 2601–2656 | 56 | 8 | file_base, file_ext, media_backup_check_outfile, media_backup_estimate, media_name, media_os | open |
| `menu_tools` | 2890–2964 | 75 | 8 | media_details, media_format, menu_select_device, pisafe_about, pisafe_help, pisafe_install, pisafe_uninstall, pisafe_update, ui_msg_error | open |
| `menu_gui` | 2659–2698 | 40 | 11 | config_var_get_settings, do_list_info, media_backup, media_restore, menu_settings, menu_tools, pisafe_about, pisafe_help, ui_msg, whiptail_calc_wt_size | open |
| `menu_cli` | 2545–2598 | 54 | 12 | config_var_set_defaults, do_beep, do_beep_down, do_beep_up, do_list_info, env_sysinfo, env_which, media_backup, media_details, media_format, media_restore, menu_gui, pisafe_about, pisafe_help, pisafe_install, pisafe_uninstall, pisafe_update, ui_yesno | open |

## 12. Top-level flow (outside any function)
Line regions not covered by the 78 definitions (blank-line/comment gaps between functions omitted):

| region | what it is |
|---|---|
| 1–38 | header + license, `set -o pipefail`, globals and defaults (SCRIPTVER, paths, colors, sizes) |
| 42–90 | commented-out dead function `notes_desktop_environment` (per the in-code comment: zero call sites — kept as reference documentation) |
| 2965–3008 | **the main flow:** `-v` early-exit, product banner, settings init, arg parse/dispatch into the entry points below |

Directly called from the top-level flow (the real entry points): `config_var_get_settings` · `config_var_init_configfile` · `get_args` · `menu_cli` · `pisafe_install_tools` · `pisafe_uninstall` · `pisafe_update` · `ui_echo`

## Coverage summary

| status | count | functions |
|---|---|---|
| reviewed | 35 | `env_installer`, `env_root_device`, `env_terminal`, `env_texteditor`, `env_which`, `env_sysinfo`, `echo_white`, `echo_red`, `echo_blue`, `notes_performance`, `run_command`, `echo_if_cli`, `config_var_init_configfile`, `config_var_set`, `config_var_get`, `config_var_set_defaults`, `config_var_get_settings`, `ui_countdown`, `ui_echo`, `ui_log`, `ui_msg`, `ui_msg_error`, `ui_msg_warning`, `ui_yesno`, `get_elapsed_time`, `get_ver_to_int`, `get_args`, `get_bytes`, `pisafe_about`, `pisafe_help`, `pisafe_install`, `pisafe_install_tool`, `pisafe_install_tools`, `pisafe_update`, `pisafe_uninstall` |
| partial | 2 | `media_backup_checklist`, `media_format` |
| open | 41 | `file_base`, `file_device`, `file_ext`, `file_folder_size`, `file_fs_freespace`, `file_image_size`, `file_list_image_files`, `file_path`, `file_size`, `whiptail_calc_wt_size`, `whiptail_fselect`, `whiptail_countdown`, `do_beep`, `do_beep_up`, `do_beep_down`, `do_countdown`, `do_list_info`, `media_name`, `media_size`, `media_backup`, `media_backup_bytes_to_read`, `media_backup_check_indev`, `media_backup_check_outfile`, `media_backup_estimate`, `media_restore`, `media_restore_checklist`, `media_list`, `media_mount`, `media_details`, `media_partition_info`, `media_os`, `menu_cli`, `menu_get_outfile`, `menu_gui`, `menu_select_device`, `menu_set_compression`, `menu_settings`, `menu_settings_default_extension`, `menu_settings_default_path`, `menu_settings_options`, `menu_tools` |
| **total** | **78** | + top-level flow |

## Method + caveats
- Parsed from the live worktree file on 2026-10-18 (blob `b0ddbd1` = `dev:pisafe` @ `b33c890` + the R12 one-line fix, hash-verified).
- Function ends = first column-0 `}` line after the definition; cross-checked — **every** column-0 `}` in the file is claimed by exactly one function, and no function span contains a nested one, so spans are provably exact.
- `deps` = word-boundary matches of other function names in the function's **code**, found by a context scanner that blanks single-quoted strings, double-quoted strings, and comments — while still parsing into `$( … )` command substitutions in any context (including nested, and across lines). A name appearing *only* inside a string or comment creates no edge. v3→v4 delta audited: 42 edges added (all `$( )`-in-quotes calls, each verified on its source line), 0 removed.
- `reviewed` marks a *logged* review round for that function/family; it does not mean the function is defect-free, and `open` functions are untouched by the SAFE quoting/shellcheck passes (which were file-wide).
- Four functions were invisible to naive `^name()` greps (indented or `name () {` spacing): `env_which`, `media_backup_estimate`, `echo_if_cli`, `menu_settings` — all are here (the first is `reviewed`; the other three `open`).

