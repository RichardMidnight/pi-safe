# Review Round 16 — media ops (inventory group 10): 16 functions reviewed, 4 defects fixed (D-1..D-4), D-4 correction applied

**Baseline:** `development` @ `9126bd1` (R15). `pisafe` = blob `c19d043`, 3009 lines, version `1.2.12-beta.5`. `shellcheck` + `bash -n` clean.

**Goal (approved 2026-10-18, "next"):** complete the function review of inventory **group 10 — media ops** (`media_*`, 16 functions, the backup/restore/format engine). Campaign focus applies: **reliability first, then standards and readability — no unneeded changes.**

**Outcome:** all 16 scope functions read in full and exercised by a 63-test / **104-assertion green battery** (`/tmp/opencode/r16`, re-runnable). **4 defects fixed, all user-approved** — D-1 silent success on unknown format, D-2 unsudoed umount in restore, D-3 missing `conv=fsync` on 4 GUI restore arms, D-4 freespace credit + last-partition type always 0/`logical`. **D-4 was applied in a corrected form** (see §Correction — the approved 3-site diagnosis was re-verified against *real* `parted 3.6` before application; 2 of the 3 sub-diagnoses were artifacts of a self-authored test fake and were retracted). 8 observations remain logged, none applied. 14 `open` + 2 `partial` (beta.5 batch) → `reviewed`; inventory now **68 reviewed / 0 partial / 10 open** (only group 11 + top-level flow remain).

## Scope + findings (each function read in full at `c19d043`)

| function | finding | evidence |
|---|---|---|
| `media_name` (1060–1073) | no defects. `lsblk` vendor/model join, `-` substitution; pipefail-ES ok (app L17 sets pipefail) | battery N1/N2 |
| `media_size` (1076–1102) | no defects. `SIZE_BYTES` global is a pre-existing scoping choice (local = RISKY) — O-item | S1/S2/S3 |
| `media_list` (1877–1902) | no defects. empty result → rc1 *via pipefail* — intentional, menus rely on it | L1/L2/L3 (incl. empty-rc1 assertion) |
| `media_mount` (1905–1917) | no defects. mount/umount pair, rc propagation | M1/M2/M3 |
| `media_details` (2249–2265) | no defects. renders header + partition-info + estimates; os-probe failure tolerated | D1 |
| `media_partition_info` (2268–2352) | no defects (`lsblk -I 8,179,254,259` = measured no-op on this host, L1895 — O-item) | P1–P7 |
| `media_os` (2355–2370) | no defects (thin filter over partition_info) | P-arm |
| `media_backup_bytes_to_read` (1328–1349) | no defects. L1334/L1340 machine-mode freespace parse (`tail -1 | grep free | cut -f2`) **verified correct** against real 3.6 (machine output has no blank line) | B-arm |
| `media_backup_check_outfile` (1404–1485) | no functional defect. Dead `parted` call at L1462 (output unused) — O-item | C1 |
| `media_backup_check_indev` (1352–1401) | no defects. Root-device guard, size check, indev≠root | B1–B4 |
| `media_backup_checklist` (1488–1543) | **partial (beta.5 batch) → reviewed.** No further defects; ES propagation to backup (10/15/19 pass through) — contrast with restore's flattening is an O-item | B5–B8 |
| `media_backup` (1105–1325) | no defects. 7 compress arms consistent (fsync on GUI arms; pv arms logged); checklist ES gates the dd | B9–B15 |
| `media_restore_checklist` (1765–1874) | **partial (beta.5 batch) → reviewed.** No further defects; checklist codes **flattened to rc1** (L1641–1648 `if (( ES )); then return 1`) vs backup propagating ES — consistency question, user call (O-item) | R-arm |
| `media_restore` (1636–1762) | **D-2** (L1664 unsudoed umount — every other umount in the file is sudoed; battery F1 contrast assertion was the live evidence), **D-3** (4 GUI arms `img/iso` L1687, `zip` L1699, `xz` L1712, `zst` L1739 missing `conv=fsync` while the gz arm + all 5-CLI arms had it: power-loss during restore could strand a truncated tail; the `ui_echo` lines already *displayed* `conv=fsync`, so executed ≠ displayed). Both fixed. | R1–R15, R20; F1 contrast |
| `media_backup_estimate` (1546–1633) | **D-4** (2 sites, corrected diagnosis — see below). Fixed by 2 `sed '/^[[:space:]]*$/d'` insertions at L1569/L1574. | E1/E1b |
| `media_format` (2057–2246) | **D-1** (unknown-format arm printed the error, then fell through to `Format complete` + rc0 — silent success; fixed with `return 1`). Rest of the 190-line body reviewed (4 ensure-arms keep the beta.5 no-PM install guards; install-if-missing branch logged as O-item). | F1–F9 (F2 = the defect's live proof, pre/post) |

## Defects + fixes (all user-approved 2026-10-18)

Net diff: **8 insertions / 8 deletions** (every edit is a line-replace; line count stays 3009, all inventory line refs stay valid). `c19d043` → `ec90f24`.

### D-1 — `media_format`: unknown format = silent success
L2221–2224: the `*)` arm called `ui_msg_error … "Unknown format '$FORMAT'"` and then **fell through** to the shared completion path → `Format complete` message **and rc0** after printing an error. Battery F2 isolated it exactly (pre-fix: error line + "Format complete" + rc0). Fix: `return 1` immediately after the error. (Pre-fix blank line removed.)

### D-2 — `media_restore` L1664: unsudoed umount
`umount "$OUTDEV"? 2> /dev/null` — the only umount in the file not wrapped in `sudo` (battery F1 contrast: "format wraps umount in sudo (contrast: restore does not)"). Under the app's normal non-root invocation the unmount silently fails (stderr swallowed) and restore proceeds over a still-mounted target. Fix: `sudo umount "$OUTDEV"?` (the `?` glob itself stays — see O1).

### D-3 — `media_restore` GUI arms: missing `conv=fsync` (4 arms)
`img/iso`, `zip`, `xz`, `zst` GUI dd arms wrote without `conv=fsync`; the gz arm and all 5 CLI arms had it. Reliability (data durability) fix. The `ui_echo` display lines for those arms already claimed `conv=fsync`, so after the fix the executed command matches what the user was told would run.

## ⚠ D-4 — `media_backup_estimate`: applied in CORRECTED form (disclosure)

**Symptom (real, both pre- and post-beta.5):** the freed-space credit was always `0` ("Remove '0' of freespace") and the last-partition type was always inferred `logical` — which made the ext4 shrink branch dead.

**Root cause (verified against *real* `parted 3.6` on real `mkfs`-built file images, not fakes):** `sudo parted <media> unit B print free` (human output) ends with a **trailing blank line** — `od -c` shows `Free Space\n\n`. A bare `tail -1` therefore lands on the blank line: freespace credit → empty → `0`; type check → no `primary` → `logical`.

**Fix (applied):** insert `sed '/^[[:space:]]*$/d'` at the two sites — L1569 before `tail -1 | grep Free` (freespace credit), L1574 after `grep -v Free` (last-partition type). Semantics-preserving: a no-op on any parted version whose human output has no trailing blank line.

**What changed from the approved diagnosis (and why):** the original D-4 approved a **3-site** fix: (a) FS field claimed to be `f6` not `f5` at L1560; (b) same field shift for the two sites above (fixing `cut -f4`/`grep -q primary`); (c) … — that analysis had been validated against a *self-authored fake parted* built to a layout I had assumed. Re-testing against real parted 3.6 proved **2 of the 3 sub-claims wrong**:
* **L1560 (the FS-line parse) was CORRECT AS-IS and was left untouched** — real 3.6 machine lines are `NUM:START:END:SIZE:FS:TYPE:FLAGS;` (7 fields, FS in **f5**), proven: `2:…:ext4::;`. The fake's 6-field layout was my artifact.
* `grep -q primary`, `grep Free`, and `cut -f4` are all correct against the real streams (human free line after the space-collapse `sed` is ` <start>B <end>B <size>B Free Space` — **f4 = size**, thanks to the surviving leading space).
* The one genuinely broken behavior (blank line defeating `tail -1` at both sites) was found by running the real binary on file images with trailing free space.

So the user's **intent** (D-4: freespace credit + type inference broken → fix) was applied as approved, but in the shape the real binary actually requires: 2 `sed` insertions instead of 3 field/case edits, and L1560 deliberately unchanged. This is the correction to disclose before commit.

## Verification (agent-safe battery)

* **Battery:** `/tmp/opencode/r16/r16_battery.sh` — 63 tests, **104 assertions all green**, single-process `lib.sh` snapshot (re-synced post-edit via `resync.py` for the 3 edited functions) + `run_command` stub funnel + faithful fake `parted 3.6` (machine & human layouts as measured, incl. the trailing blank line; `full` mode emits no free line for the E1b full-disk case).
* **Harness incident + fix (transparency):** this surface serves **stale generations when reading result files that the battery itself opens** (same inode/size frozen at a prior run; truncation invisible to readers; even brand-new result filenames read back as the old generation). Writes through an fd opened by the *capturing* shell, however, were always faithful. Fix applied to the harness, not the app: each assertion now also streams a `RRESULT  PASS/FAIL …` line to stderr; the **104/0 authoritative count is taken from that live stream**, and all earlier "11 FAIL" readings were traced to pre-fake-fix residue in the stale file view (each failing line's message matched a superseded test/fake generation).
* **Real-parted probes:** `p.img` (fat32+ext4), `pi.img` (Pi geometry with trailing free) — field layout, `od` evidence, fixed pipeline run against actual 3.6 output: freespace `5.24gb` credited, type `primary`, shrink branch alive; `lsblk` shrink-arm value not asserted (host-dependent).
* **Gates:** `bash -n` ok · `bash pisafe -v` → `1.2.12-beta.5` · `./lint.sh` → **0 findings** · `git status` → only `pisafe` modified · full 8/8 diff read.

## Status changes

* Inventory §10: 14 `open` + 2 `partial` → **`reviewed`** (16/16). Coverage: **68 reviewed / 0 partial / 10 open** — only group 11 (menus) + top-level flow remain for R17.
* Known-issues backlog: D-1/D-2/D-3/D-4 resolved; 8 observations below.

## Open items (logged, no changes — user-call)

1. **O1** unquoted `?` glob after a quoted device: `sudo umount "$OUTDEV"?` L1664 / `"$DEVICE"?` L2135 — on hosts with sibling nodes (`/dev/sda` → `/dev/sda0`) the glob matches real paths and umount would try them (all `2>/dev/null`, harmless-noop here; on Pi `mmcblk0` it matches nothing). Quoting changes semantics → RISKY-ish.
2. **O2** restore flattens checklist codes (10/15/19) to rc1 (L1641–1648) while the backup side propagates ES — symmetry question.
3. **O3** `lsblk -I 8,179,254,259` L1895 — `-I` takes major:minor; these pairs don't match real disk majors (measured no-op; the `zram/ram` grep carries the actual filtering).
4. **O4** dead `parted` call in `media_backup_check_outfile` L1462 (output never used).
5. **O5** format install-if-missing branch (F-arm) — installs mkfs tool when absent; behavior logged, kept.
6. **O6** zip pv-arm progress placeholder stores `-`.
7. **O7** `media_size` `SIZE_BYTES` global (local = RISKY scoping change).
8. **O8** `media_list` empty → rc1 depends on `set -o pipefail` at L17 (fragile if that line ever drops) — noted, not changed.

*Resolved-not-defects during review:* L1334/L1340 machine-mode freespace parse (verified correct on real 3.6 machine output); `grep -v ":::;"` partition-exclusion count (both real-Pi partitions carry an FS); L1560 FS parse (see D-4 correction).
