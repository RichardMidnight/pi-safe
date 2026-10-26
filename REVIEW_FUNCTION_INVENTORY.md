# PiSafe — function inventory (dependency order)

* **Source:** `development` @ `a5497f4` (R16) + the R17 two-line change (blob `bd78b79`) · generated 2026-10-18 (v4 scanner) · spans re-verified after the R17 edit · **R18 refresh (2026-10-24):** all spans/sizes/depths/deps re-computed from the live file; `media_mount` removed (R18) and `notes_performance` converted to a comment block (R18) exit the function set; `image_size_display` (added 2026-10-19, `166f997`) added · **R19 re-verification (2026-10-24):** all spans re-verified against the live file after the R19 reference-block rewrite — uniform +23 shift for every function, zero drift · file is 3060 lines, **77 functions** + top-level flow
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
| `env_root_device` | 615–628 | 14 | 0 | — | reviewed — beta.3 env family audit; R11 evidence re-check |
| `env_which` | 681–703 | 23 | 0 | — | reviewed — beta.3 env family audit (Manjaro `which` fix); R11 evidence re-check |
| `env_installer` | 593–612 | 20 | 1 | env_which | reviewed — beta.3 env family audit + beta.5 batch; R11 evidence re-check |
| `env_terminal` | 631–666 | 36 | 1 | env_which | reviewed — beta.3 audit + beta.5 batch (x-terminal-emulator target dispatch); R11 evidence re-check |
| `env_texteditor` | 669–678 | 10 | 1 | env_which | reviewed — beta.3 audit + beta.5 batch (locals); R11 evidence re-check |
| `env_sysinfo` | 706–712 | 7 | 2 | env_installer, env_root_device, env_terminal, env_texteditor | reviewed — beta.3 env family audit; R11 evidence re-check (v4 adds 4 real `$( )` edges) |

## 2. color/output + misc helpers  ·  depth 0–2
*echo colors, run_command, echo_if_cli.*

| function | lines | size | depth | deps (pisafe functions it calls) | status |
|---|---|---|---|---|---|
| `echo_white` | 38–38 | 1 | 0 | — | reviewed — R11 leaf layer — ANSI wrapper + $* safety verified (T01) |
| `echo_red` | 39–39 | 1 | 0 | — | reviewed — R11 leaf layer — ANSI wrapper + $* safety verified (T02) |
| `echo_blue` | 40–40 | 1 | 0 | — | reviewed — R11 leaf layer — ANSI wrapper + $* safety verified (T03) |
| `echo_if_cli` | 2589–2600 | 12 | 1 | echo_blue, echo_red, echo_white | reviewed — R11 — CLI dispatch verified (T19; white+blue+red all colorize); O1 `blue` arm added in R11 fix |
| `run_command` | 136–146 | 11 | 2 | ui_echo | reviewed — R11 — eval/ES path verified (T17-T18); R10 B1 quoting; O2 dead local `LINE=$2` removed in R11 fix |

## 3. settings-file I/O  ·  depth 0–3
*get/set + defaults + load; no ui layer yet.*

| function | lines | size | depth | deps (pisafe functions it calls) | status |
|---|---|---|---|---|---|
| `config_var_get` | 531–534 | 4 | 0 | — | reviewed — beta.3 config_var family audit + R5.3/R7 + beta.5 batch; R11 evidence re-check |
| `config_var_set` | 507–528 | 22 | 1 | config_var_get | reviewed — beta.3 config_var family audit + R5.3/R7 + beta.5 batch; R11 evidence re-check |
| `config_var_get_settings` | 563–589 | 27 | 1 | config_var_get | reviewed — beta.3 config_var family audit + R5.3/R7 + beta.5 batch; R11 evidence re-check |
| `config_var_set_defaults` | 537–560 | 24 | 2 | config_var_set, env_texteditor | reviewed — beta.3 audit + beta.5 batch (ghost keys removed); R11 evidence re-check |
| `config_var_init_configfile` | 492–504 | 13 | 3 | config_var_set_defaults, file_path | reviewed — beta.3 config_var family audit + R5.3/R7; R11 evidence re-check (v4 adds file_path edge — real call) |

## 4. UI primitives  ·  depth 0–3
*whiptail/CLI message layer; ui_msg_error is the deepest (beep gate).*

| function | lines | size | depth | deps (pisafe functions it calls) | status |
|---|---|---|---|---|---|
| `ui_log` | 2035–2045 | 11 | 0 | — | reviewed — R11 — LOG gate + literal-newline collapse verified (T04-T05) |
| `ui_yesno` | 2090–2130 | 41 | 0 | — | reviewed — R11 — rc contract + EOF no-loop guard verified (T06-T08) |
| `ui_countdown` | 2001–2012 | 12 | 1 | do_countdown, whiptail_countdown | reviewed — R11 — CLI/GUI dispatch verified CLI side (T13); GUI arm = user harness |
| `ui_echo` | 2015–2032 | 18 | 1 | echo_blue, echo_red, echo_white, ui_log | reviewed — ui_echo scope/stream fix (logged in campaign) + R11 re-verify (T09) |
| `ui_msg` | 2048–2066 | 19 | 2 | ui_echo, ui_log | reviewed — R11 — CLI arm verified (T10); O4: empty --ok-button is file-wide convention |
| `ui_msg_error` | 2069–2076 | 8 | 3 | do_beep_down, ui_msg | reviewed — R11 — shift-before-capture order + lineno format verified (T11) |
| `ui_msg_warning` | 2079–2087 | 9 | 3 | do_beep, ui_msg | reviewed — R11 — verified; double beep intentional (T12) |

## 5. value parsing helpers  ·  depth 0–4
*flags, version ints, byte conversion.*

| function | lines | size | depth | deps (pisafe functions it calls) | status |
|---|---|---|---|---|---|
| `get_elapsed_time` | 738–746 | 9 | 0 | — | reviewed — cleaned in review; no open items; R11 re-confirmed |
| `get_ver_to_int` | 775–785 | 11 | 0 | — | reviewed — R2 — parse crash on `1.2.12rc1`-class input fixed; R11 re-confirmed |
| `get_args` | 788–833 | 46 | 0 | — | reviewed — R11 — flag map verified (T15-T16); O3: unknown flags silently ignored |
| `get_bytes` | 836–893 | 58 | 4 | ui_msg_error, ui_msg_warning | reviewed — R1 — TB multiplier bug fixed + R11 regression re-run (T20) |

## 6. lifecycle — install / update / uninstall + about / help  ·  depth 0–5
*env_installer + run_command dependent.*

| function | lines | size | depth | deps (pisafe functions it calls) | status |
|---|---|---|---|---|---|
| `pisafe_about` | 149–170 | 22 | 0 | — | reviewed — R12 — pure echo provenance text; no defects (T01) |
| `pisafe_help` | 173–219 | 47 | 0 | — | reviewed — R12 — usage/help text; no defects (T02) |
| `pisafe_update` | 396–455 | 60 | 3 | get_ver_to_int, ui_echo, ui_msg, ui_yesno | reviewed — R12 — netfail/decline/same-version/apply paths verified (T14-T17); O2 + O4 (tmp kept on decline) left to user |
| `pisafe_uninstall` | 458–488 | 31 | 3 | ui_echo, ui_msg, ui_yesno | reviewed — R12 — removal set + decline path verified (T18-T19); O3 (msg omits config removal) left to user |
| `pisafe_install` | 222–296 | 75 | 4 | env_terminal, ui_echo, ui_msg, ui_msg_warning, ui_yesno | reviewed — R12 — full stubbed pass (T20): cp/chmod, desktop NoDisplay + failure-keep paths; O1 cp source + O2 unguarded -v left to user |
| `pisafe_install_tool` | 299–355 | 57 | 4 | env_installer, env_which, run_command, ui_echo, ui_msg_warning | reviewed — R12 — all 3 arms verified (T03-T09): xz-utils mapping, pishrink download+cleanup, generic ES branch; env_which re-check kept |
| `pisafe_install_tools` | 358–393 | 36 | 5 | env_installer, env_which, pisafe_install_tool, run_command, ui_msg_warning, ui_yesno | reviewed — R12 — D1 FIX: missing `SILENT=${1:-"-n"}` (dead ask branch, silent auto-install) added; ask/no, ask/yes, silent, newt-fallback verified (T10-T13) |

## 7. file/size introspection  ·  depth 0–7
*device paths, sizes, image file listing, freespace.*

| function | lines | size | depth | deps (pisafe functions it calls) | status |
|---|---|---|---|---|---|
| `file_base` | 897–908 | 12 | 0 | — | reviewed — R13 — dirname/basename/first-dot-strip verified (T01) |
| `file_device` | 911–915 | 5 | 0 | — | reviewed — R13 — df+lsblk parse: positive (/ → /dev/mmcblk0) + graceful-empty on tmpfs mount (T04-T05) |
| `file_ext` | 918–920 | 3 | 0 | — | reviewed — R13 — single/absent/multi-dot verified (T02) |
| `file_folder_size` | 923–936 | 14 | 0 | — | reviewed — R13 — du chain + missing-dir guard verified (T06); trailing-space noted (O2) |
| `file_path` | 1046–1048 | 3 | 0 | — | reviewed — R13 — dirname single-token verified (T03) |
| `file_fs_freespace` | 939–961 | 23 | 5 | get_bytes | reviewed — R13 — bytes/-h + df-failure rc verified (T07-T08); ES=$? relies on the file-wide pipefail (R10) |
| `file_image_size` | 964–1008 | 45 | 5 | file_ext, get_bytes | reviewed — R13 — img/iso/zip/xz/gz/zst all measured 100000 exactly vs real tools (T10-T15) + unsupported/-h guards (T16-T17); O1 version-parse risk |
| `file_size` | 1051–1070 | 20 | 5 | get_bytes | reviewed — R13 — exact bytes + -h + missing-file guard verified (T18) |
| `image_size_display` | 1011–1021 | 11 | 6 | file_image_size, get_bytes | reviewed — 166f997 (2026-10-19 gz ≥ 4 GiB round) — listing-size display behind the `exact_gz_image_size` setting; listings covered by that round's 47/47 functional battery; deps/spans re-verified in R18 inventory refresh |
| `file_list_image_files` | 1024–1043 | 20 | 7 | file_size, image_size_display | reviewed — R13 — seeded dir incl. spaced name, sizes, CWD + IFS restore verified (T19) |

## 8. whiptail dialog helpers  ·  depth 0–7
*calc-size + countdown are pure plumbing; fselect is a file browser (calls the file/size helpers).*

| function | lines | size | depth | deps (pisafe functions it calls) | status |
|---|---|---|---|---|---|
| `whiptail_calc_wt_size` | 2439–2465 | 27 | 0 | — | reviewed — R14 — size calc + 120-wide clamp verified (T01-T02); tput-empty → negative pin (T03); dead-guards/negative-clamp noted (O1/O2) |
| `whiptail_countdown` | 2572–2586 | 15 | 0 | — | reviewed — R14 — yes/stop gate + --defaultno verified (T04-T05); dead-MAX param pinned (T06, O6) |
| `whiptail_fselect` | 2468–2569 | 102 | 7 | get_bytes, image_size_display | reviewed — R14 — menu build, descent/pick, ESC, back-entry + back-protocol, spaced dirs, empty dir, Box guard verified (T07-T14); D-1 fixed (the '..' entry was clobbered by an array reset) |

## 9. small action runners  ·  depth 0–8
*beeps, countdown, list-info (list-info composes the file/media layer).*

| function | lines | size | depth | deps (pisafe functions it calls) | status |
|---|---|---|---|---|---|
| `do_countdown` | 749–772 | 24 | 0 | — | reviewed — R15 — rc contract (y=rc0 / any other key=rc1 / run-out=rc0) + ENTRY stops (T04-T06); O4 N+1 timing pin (T07, re-confirms R11 O5); O5 bare return + global INPUT |
| `do_beep` | 716–723 | 8 | 1 | env_which | reviewed — R15 — SOUND gate + timed speaker-test verified (T01-T02); kill -9 reaps the target, no leak (T02b); O1 FREQ/TIME globals, O2 stderr not redirected |
| `do_beep_up` | 726–729 | 4 | 2 | do_beep | reviewed — R15 — chirp order verified against fake record (T03 up-half) |
| `do_beep_down` | 732–735 | 4 | 2 | do_beep | reviewed — R15 — chirp order verified against fake record (T03 down-half); O3 3-space indent FIXED (SAFE, normalized) |
| `do_list_info` | 1076–1092 | 17 | 8 | env_root_device, file_folder_size, file_fs_freespace, file_list_image_files, media_list, media_size | reviewed — R15 — full composition vs real R13 layer + media stubs (T09); media_size called `<dev> -h` (args captured); O6 $1 unused; $PRODUCTNAME quote FIXED (SAFE) |

## 10. media ops — backup/restore/format core  ·  depth 0–10
*the engine: checklists, est, backup, restore, format.*

| function | lines | size | depth | deps (pisafe functions it calls) | status |
|---|---|---|---|---|---|
| `media_name` | 1098–1111 | 14 | 0 | — | reviewed — R16: no defects; battery N1/N2 |
| `media_partition_info` | 2331–2415 | 85 | 0 | — | reviewed — R16: no defects; O3 (`lsblk -I` no-op L1895); battery P1–P7 |
| `media_list` | 1972–1997 | 26 | 1 | env_root_device | reviewed — R16: no defects; empty→rc1 via pipefail (O8); battery L1–L3 |
| `media_os` | 2418–2432 | 15 | 1 | media_partition_info | reviewed — R16: no defects; battery P-arm |
| `media_format` | 2136–2309 | 174 | 4 | env_installer, env_root_device, env_which, media_name, run_command, ui_countdown, ui_echo, ui_msg, ui_msg_error, ui_msg_warning, ui_yesno | reviewed — R16: **D-1 fixed** (unknown format was silent success → `return 1`); O1 `?`-glob umount L2135, O5 install branch; battery F1–F9 |
| `media_size` | 1114–1135 | 22 | 5 | get_bytes | reviewed — R16: no defects; O7 `SIZE_BYTES` global; battery S1–S3 |
| `media_backup_bytes_to_read` | 1362–1380 | 19 | 6 | media_size, ui_msg_warning | reviewed — R16: no defects; L1334/L1340 machine-mode parse verified vs real parted 3.6; battery B-arm |
| `media_backup_check_indev` | 1383–1430 | 48 | 6 | env_root_device, get_bytes, media_name, media_os, media_size, ui_msg_error, ui_msg_warning, ui_yesno | reviewed — R16: no defects; battery B1–B4 |
| `media_backup_estimate` | 1627–1711 | 85 | 6 | get_bytes, media_size, ui_echo | reviewed — R16: **D-4 fixed (corrected shape)** (parted 3.6 trailing blank line defeated `tail -1` at both sites → 2 `sed` blank-line deletions L1569/L1574; L1560 verified correct as-is against real 3.6); battery E1/E1b |
| `media_backup_check_outfile` | 1433–1510 | 78 | 7 | file_base, file_ext, file_fs_freespace, file_path, get_bytes, media_backup_bytes_to_read, media_name, pisafe_install_tool, ui_msg_error, ui_msg_warning | reviewed — R16: no functional defect; O4 dead `parted` L1462; battery C1 |
| `media_restore_checklist` | 1849–1969 | 121 | 8 | do_beep, echo_if_cli, env_root_device, file_device, file_ext, file_image_size, get_bytes, media_name, media_size, menu_select_device, pisafe_install_tool, ui_echo, ui_msg, ui_msg_error, ui_msg_warning, ui_yesno, whiptail_fselect | reviewed — R16: no further defects; O2 ES flattening L1641–1648; battery R-arm |
| `media_details` | 2312–2328 | 17 | 7 | media_backup_estimate, media_name, media_os, ui_msg | reviewed — R16: no defects; battery D1 |
| `media_restore` | 1714–1846 | 133 | 9 | do_beep_up, echo_if_cli, echo_red, echo_white, file_ext, file_image_size, get_elapsed_time, media_name, media_restore_checklist, run_command, ui_countdown, ui_echo, ui_msg, ui_msg_error | reviewed — R16: **D-2 fixed** (unsudoed umount L1664), **D-3 fixed** (4 GUI arms missing `conv=fsync`); O1 `?`-glob L1664, O2 ES flattening; battery R1–R15/R20 |
| `media_backup_checklist` | 1513–1624 | 112 | 9 | file_ext, get_bytes, media_backup_check_indev, media_backup_check_outfile, media_backup_estimate, media_name, menu_get_outfile, menu_select_device, ui_log, ui_msg_error, ui_msg_warning, ui_yesno | reviewed — R16: partial (beta.5 batch) completed; no further defects; O2 ES propagation (contrast with restore); battery B5–B8 |
| `media_backup` | 1138–1359 | 222 | 10 | do_beep_down, do_beep_up, echo_white, file_base, file_ext, file_size, get_bytes, get_elapsed_time, media_backup_bytes_to_read, media_backup_checklist, media_name, media_size, run_command, ui_echo, ui_msg, ui_msg_error | reviewed — R16: no defects; O6 zip pv placeholder; battery B9–B15 |

## 11. menus + main dispatch  ·  depth 2–12
*drives everything above; deepest functions in the file.*

| function | lines | size | depth | deps (pisafe functions it calls) | status |
|---|---|---|---|---|---|
| `menu_select_device` | 2758–2793 | 36 | 2 | media_list | reviewed — R17: no defects; O4 (post-mapfile `ES=$?` is a dead probe), O10 (`|` in vendor/model is a rare token edge); battery D1–D4 |
| `menu_set_compression` | 2796–2813 | 18 | 2 | config_var_set | reviewed — R17: no defects; O5 (radiolist hard-codes level “5 on” regardless of saved level); battery K1–K2 |
| `menu_settings_default_extension` | 2856–2880 | 25 | 2 | config_var_set | reviewed — R17: no defects; radio state reflects the current default (unlike the legacy hard-coded `zip on`); battery X1–X2 |
| `menu_settings_options` | 2907–2939 | 33 | 2 | config_var_get_settings, config_var_set | reviewed — R17: no defects; O7 (cancel → implicit rc0 vs `return "$ES"` elsewhere; intentionally-unquoted `$ON` list split); battery O1–O3 |
| `menu_settings_default_path` | 2883–2904 | 22 | 4 | config_var_set, ui_msg_error | reviewed — R17: **O1 fix applied** (sed `s/[/\t]*$//` → `sed $'s/[/\t]*$//'` + comment; GNU-sed measured both behaviors; POSIX-strict sed would eat the `t` of `/tmp`); battery P1–P4 |
| `menu_settings` | 2816–2853 | 38 | 5 | config_var_get_settings, config_var_set_defaults, menu_set_compression, menu_settings_default_extension, menu_settings_default_path, menu_settings_options, ui_log, ui_yesno | reviewed — R17: no defects; O3 (dead `Text*)` case arm), O6 (2-space function indent, cosmetic); battery S1–S5 |
| `menu_get_outfile` | 2660–2712 | 53 | 8 | file_base, file_ext, media_backup_check_outfile, media_backup_estimate, media_name, media_os | reviewed — R17: no defects; `.tar` rejected through the real `media_backup_check_outfile` chain; battery F1–F4 |
| `menu_tools` | 2942–3016 | 75 | 8 | media_details, media_format, menu_select_device, pisafe_about, pisafe_help, pisafe_install, pisafe_uninstall, pisafe_update, ui_msg_error | reviewed — R17: no defects; O3 (dead `HELP)` arm — TOOLS has no help item); battery T1–T6 |
| `menu_gui` | 2715–2755 | 41 | 11 | config_var_get_settings, do_list_info, media_backup, media_restore, menu_settings, menu_tools, pisafe_about, pisafe_help, ui_msg, whiptail_calc_wt_size | reviewed — R17: **R17 change 2 applied** (GUI `ABOUT` item wired in + missing space before HELP continuation fixed; previously-dead `ABOUT)` arm now reachable); O9 (stray `echo "Getting list of images ready..."` leaks to terminal); battery G1–G11 |
| `menu_cli` | 2605–2657 | 53 | 12 | config_var_set_defaults, do_beep, do_beep_down, do_beep_up, do_list_info, env_sysinfo, env_which, media_backup, media_details, media_format, media_restore, menu_gui, pisafe_about, pisafe_help, pisafe_install, pisafe_uninstall, pisafe_update, ui_yesno | reviewed — R17: no defects; O2 (hard-coded `nano` for log/settings while GUI uses `$TEXT_EDITOR` — documented in help text, left as-is); O3 (dead `-v)` arm — shadowed by the top-level `-v` early-exit); battery C1–C18, CB |

## 12. Top-level flow (outside any function)
Line regions not covered by the 77 definitions (blank-line/comment gaps between functions omitted):

| region | what it is |
|---|---|
| 1–37 | header + license, `set -o pipefail`, globals and defaults (SCRIPTVER, paths, colors, sizes) |
| 42–135 | the reference documentation block (rewritten in R19): 2026-tested distro/terminal/editor table + historical (pre-2026) rows, versioned "Tested with" lists (1.2.12 = 2026-10 rounds), the single 1.2.12-vs-1.2.11 behavior note (gz ~>= 3.9 GiB creation gate), and the historical 2019 `notes_performance` table — all commented, zero call sites |
| 3017–3060 | **the main flow:** `-v` early-exit, product banner, settings init, arg parse/dispatch into the entry points below |

Directly called from the top-level flow (the real entry points): `config_var_get_settings` · `config_var_init_configfile` · `get_args` · `menu_cli` · `pisafe_install_tools` · `pisafe_uninstall` · `pisafe_update` · `ui_echo`

## Coverage summary

| status | count | functions |
|---|---|---|
| reviewed | 77 | `env_installer`, `env_root_device`, `env_terminal`, `env_texteditor`, `env_which`, `env_sysinfo`, `echo_white`, `echo_red`, `echo_blue`, `run_command`, `echo_if_cli`, `config_var_init_configfile`, `config_var_set`, `config_var_get`, `config_var_set_defaults`, `config_var_get_settings`, `ui_countdown`, `ui_echo`, `ui_log`, `ui_msg`, `ui_msg_error`, `ui_msg_warning`, `ui_yesno`, `get_elapsed_time`, `get_ver_to_int`, `get_args`, `get_bytes`, `pisafe_about`, `pisafe_help`, `pisafe_install`, `pisafe_install_tool`, `pisafe_install_tools`, `pisafe_update`, `pisafe_uninstall`, `file_base`, `file_device`, `file_ext`, `file_folder_size`, `file_fs_freespace`, `file_image_size`, `image_size_display`, `file_list_image_files`, `file_path`, `file_size`, `whiptail_calc_wt_size`, `whiptail_fselect`, `whiptail_countdown`, `do_beep`, `do_beep_up`, `do_beep_down`, `do_countdown`, `do_list_info`, `media_name`, `media_size`, `media_list`, `media_backup`, `media_backup_bytes_to_read`, `media_backup_check_indev`, `media_backup_check_outfile`, `media_backup_checklist`, `media_backup_estimate`, `media_restore`, `media_restore_checklist`, `media_details`, `media_partition_info`, `media_os`, `media_format`, `menu_cli`, `menu_get_outfile`, `menu_gui`, `menu_select_device`, `menu_set_compression`, `menu_settings`, `menu_settings_default_extension`, `menu_settings_default_path`, `menu_settings_options`, `menu_tools` |
| partial | 0 | — |
| open | 0 | — |
| **total** | **77** | + top-level flow |

## Method + caveats
- Parsed from the live worktree file on 2026-10-18 (blob `58440e9` = `dev:pisafe` @ `8f02414` + the R14 one-line fix, hash-verified).
- Function ends = first column-0 `}` line after the definition; cross-checked — **every** column-0 `}` in the file is claimed by exactly one function, and no function span contains a nested one, so spans are provably exact.
- `deps` = word-boundary matches of other function names in the function's **code**, found by a context scanner that blanks single-quoted strings, double-quoted strings, and comments — while still parsing into `$( … )` command substitutions in any context (including nested, and across lines). A name appearing *only* inside a string or comment creates no edge. v3→v4 delta audited: 42 edges added (all `$( )`-in-quotes calls, each verified on its source line), 0 removed.
- `reviewed` marks a *logged* review round for that function/family; it does not mean the function is defect-free, and `open` functions are untouched by the SAFE quoting/shellcheck passes (which were file-wide).
- Four functions were invisible to naive `^name()` greps (indented or `name () {` spacing): `env_which`, `media_backup_estimate`, `echo_if_cli`, `menu_settings` — all are here, all now reviewed.

