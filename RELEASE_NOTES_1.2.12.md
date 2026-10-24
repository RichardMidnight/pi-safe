# PiSafe 1.2.12 — release notes (for beta.7 / release time)

Position doc, not code. The **headline block below is user-approved** (2026-10-24: "document that, we will use it").
Body bullets are sourced from `REVIEW_ROUNDS.md` + the known-issues backlog; verify wording against the
final harness pass before the tag. Release = the `v1.2.12-beta.7` line (beta.6 does **not** carry the
final gz sizing or the 2026-10-24 install/default rounds — those ride in beta.7).

---

## Headline (approved)

> **1.2.12 — a pure hardening release.**
> Same defaults (`zip 1`), same interface, same dependencies as 1.2.11 — no new features.
> About 30 reliability, standards, and bug fixes from the review campaign, including the crash on
> version strings like `1.2.12rc1`, settings-file read/write robustness, and device-list noise.
>
> **One deliberate behavior change:** PiSafe now refuses to *create* gz images ≥ ~3.9 GiB.
> 1.2.11 silently produced images whose size could not be verified (gz's 32-bit footer),
> which broke restore for them.

Short variants:
- **Tag line:** `1.2.12: hardening only — everything works as in 1.2.11` — approved 2026-10-24; shows as the dev **file-listing tagline** (last-commit message on the `pisafe` row), not app copy
- **README version-history line:** `1.2.12 — extensive hardening, no new features, no default changes`

## What did NOT change (state it so it isn't misread)

- Default compression: `zip 1` — identical to 1.2.11 (`xz 1` was the short-lived beta default, reverted 2026-10-24)
- Dependencies: `xz` remains an **optional** tool, installed on demand when you pick `.xz` — same as 1.2.11's optional-tools scheme; `xz 8` still available when you want smallest files
- All five output formats remain: `.img` `.zip` `.xz` `.gz` `.zst`
- `install` installs the running script (1.2.11 semantics restored — the beta's "pull newest beta" fetch was removed 2026-10-24); `update` checks for a newer stable, as before

## Bug fixes (user-visible)

- **Size display:** the terabyte multiplier in `get_bytes` was ~2× too large (typo `2014` for `1024`)
  → TB-magnitude sizes, estimates and free-space figures corrected
- **Crash:** version strings like `1.2.12rc1` broke `get_ver_to_int` (bash arithmetic error,
  "value too great for base") — now resolves to the numeric prefix
- **Settings file:** reading could return comment-line garbage (a `# log=off` comment once leaked as
  the value of `log`); in-place updates could rewrite an unrelated value; `clear` could clobber
  other lines — all fixed and anchored
- **Backup-estimate text** got clobbered / fused (ui_echo stream issue; stray ANSI codes on some
  boxes) — fixed
- **Device list** now hides RAM disks — `zram0` reported as a "disk" on the Pi, cluttering the
  list and all four pickers (`lsblk` major 254)
- **GitHub #55:** "Media '' can't be blank" with nothing selectable — now explains that a lone
  boot disk is hidden by design (`hide_root_device`) and gives the explicit-device workaround
  (`pisafe backup /dev/sda`)
- **Restore of gz images:** the spurious size-based refusal is gone — one uniform, trusted
  size-reading path for every format (paired with the creation-side gate below)
- `set -o pipefail` enabled — a failing stage inside a pipe no longer masquerades as success

## Hardening & standards (not usually visible — verified, R1→R17, shellcheck locked at 0 findings)

- Quoting discipline, `[[ ]]` tests, `local` scoping, consistent indentation
  (`lint.sh` keeps shellcheck at 0 findings)
- Guarded downloads (non-empty + parse check before use), consistent `--backup=numbered`,
  package-manager install guards
- `get_elapsed_time` no longer shadows bash's special `$SECONDS` variable
- Text-editor chain widened with `gnome-text-editor` (Ubuntu coverage — the former editor
  fallbacks all predate it)
- Estimation/tables, menus and help copy brought to match actual behavior

## Behavior change (one, by design)

- **Creation refused for gz ≥ ~3.9 GiB** (all interaction paths: interactive, `-y`, no-TTY):
  1.2.11 made such images, then could not read back a verifiable size (gz carries the raw size
  mod 2^32) — i.e. it shipped files it couldn't restore confidently. Refusal at ≈3.9 GiB (headroom
  under 2^32) removes the bad class of file entirely; `.xz` remains the unrestricted large-image
  path, `.zip` `.img` `.zst` were never affected.

## Distribution / repo (GitHub-side, not in the binary)

- Standard layout: `main` = stable (1.2.11), `dev` = betas, `archive/` = pinned older versions
  (1.2.6 / 1.2.9 / 1.2.11 / beta.6); README install blocks download **pinned** copies — the
  "Old Stable (escape hatch)" flow now actually installs 1.2.9
- Harness (v2.2) + fleet test plan moved under `testing/`; `setup` mode fetches the paired
  `dev` files correctly after the branch rename

## Gate before tag

- Destructive harness pass on **current dev HEAD** (last 12/12 was 2026-10-23 10:57 — predates
  `05c13ac`, `fe47be2`, and the two 2026-10-24 rounds: install semantics, zip-default revert).
  Ladder: code green → *user's* destructive pass on that exact code → tag + push (each remote
  action with its own explicit GO).
