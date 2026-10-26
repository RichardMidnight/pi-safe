pisafe review campaign — high level status (updated 2026-10-26 — final position)
Full log: REVIEW_ROUNDS.md (complete through the 2026-10-26 rounds incl. ladder state)

position
  started:   v1.2.11 (fresh branch dev)
  now:       1.2.12-beta.7 code on dev (SCRIPTVER=1.2.12-beta.7); stable = 1.2.11 on main
  stance:    1.2.12 = a PURE HARDENING release — same defaults (zip 1), same interface,
             same dependencies as 1.2.11, no new features (headline approved 2026-10-24;
             RELEASE_NOTES_1.2.12.md)
  repos:     main @ e8432d4 = clean stable — pisafe (1.2.11), archive/ (1.2.6, 1.2.9, 1.2.11, beta.6, beta.7),
             README (Default: zip 1; install blocks → main + main/archive/…),
             pisafe_icon.png, screenshot.png, LICENSE
             dev @ a842113 = campaign branch — beta pipeline (install = the running script),
             lint.sh, AGENTS.md, REVIEW_* docs, RELEASE_NOTES_1.2.12.md,
             testing/ harness v2.2 + plan + punchlist, screenshot.png
  releases:  beta.2, beta.3, beta.4, beta.6, beta.7 tagged + on GitHub (beta.5 retracted 2026-10-18);
             beta.7 shipped 2026-10-26 (tag v1.2.12-beta.7 → a842113; main e8432d4 = archive + README);
             v1.2.11 tag pushed 2026-10-24 (stable marker); local v1.3.0-beta.1 experiment tag deleted
  branches:  dev + main only (stale remote dev and development merged away 2026-10-24, R2)
  ladder:    (a) code done + agent battery green ✓ · (b) destructive pass GREEN — 12/12 × 2
             (2026-10-23 10:57 Manjaro RPi; 2026-10-24 08:44 Debian-trixie RPi) + beta.7 pass
             (2026-10-26 12:09 LMDE 7 (gigi): 10/12, the 2 gz steps refused by design — card
             raw over ~3.9 GiB = the new gate; all other 10 PASS) ✓ ·
             (c) tag + push: beta.7 DONE 2026-10-26 — stable 1.2.12 is the remaining
             ladder call (dev→main sync + SCRIPTVER + tag, each explicit)

done (beyond the 2026-10-18 position)
  R1–R17 function review (get_* leaves → menus/main) — all green, lint.sh 0 findings locked
  gz image-size saga resolved (2026-10-19 → 10-23): restore false refusal + wrong-size listings gone;
     final design (fe47be2) = refuse to make gz ≥ ~3.9 GiB (both decision points), trust the footer,
     one uniform size path on read; old measure/continue-anyway machinery removed
  install: installs the running script (1.2.11 semantics — the beta's "pull newest beta" fetch
     was removed 2026-10-24; `update` remains the stable-fetch path)
  default compression: zip 1 (xz was the beta-era default, reverted 2026-10-24; xz stays an
     on-demand option — same dependency set as 1.2.11)
  harness v2.2: setup mode, report save, native-surface capture, non-destructive env mode,
     fleet plan in testing/pisafe_test_plan.txt; punchlist now committed
     (testing/pisafe_test_punchlist.txt); last destructive passes 12/12 × 2 (2026-10-23, 2026-10-24)
  repo restructured to standard layout (R1–R4, 2026-10-24): main=stable+archive, dev=beta,
     README install URLs into archive/, screenshot.png on both branches, v1.2.11 tagged on GitHub
  gz ≥ ~3.9 GiB creation gate: machine evidence of the refusal path landed 2026-10-26 —
     bench 0018 (raw 7.9 GiB): gz FAILED all levels while zip/xz/zst completed; LMDE battery:
     gz backup refused in 1s at the pre-backup guard — punchlist "done?" closed
  bookkeeping: REVIEW_ROUNDS.md complete through 2026-10-26; RELEASE_NOTES_1.2.12.md drafted
     with the approved headline; main README Default line fixed (437374b)
  dev tagline: "1.2.12: hardening only — everything works as in 1.2.11" (file-listing tagline, 22d8595)
  harness setup mode fixed post-rename: pulls dev/pisafe + dev/testing/pisafe_test.sh (was
     404ing on the deleted 'development' ref + old root file name) — real setup run verified

real bugs fixed along the way (not only cosmetic)
  TB multiplier in get_bytes (~2× too large)
  ui_echo scope/stream clobber broke the backup-estimate text
  get_ver_to_int crashed on inputs like 1.2.12rc1
  settings-file read/write corruption (comment lines leaked into values; unanchored rewrites;
     clear could clobber other lines)
  ram-disk entries in the device list (zram0 reports as a "disk" on the Pi)
  #55: "Media '' can't be blank" → now explains hidden boot disk + explicit-device workaround
  gz ≥ 4 GiB: size unverifiable (32-bit footer) → refused on creation + uniform reader (fe47be2)
  set -o pipefail enabled (previously masked pipe failures)
  copy: "origional" → "original" + zip-default label consistency

outstanding
  user call: release v1.2.12 stable from beta.7 (dev→main sync round first; SCRIPTVER bump +
     tag as separate explicit actions per the ladder) or ship another beta
  --level over-max clamp+warn: written + lint-clean but never machine-exercised (bench drove
     levels 1–9 only) — one over-max -L run on any box closes it
  untracked bench/scratch files (10) + gitignored testing/pisafe_test_log.txt: keep, junk/
     them, or gitignore the bench outputs — user call
  dead Text*) case arm in menu_settings (pisafe ~2885) — user call (logged in R18)
  PRs #54 / #57 still open on GitHub — user to close in the browser (#54 superseded, do not merge)
  (design note, optional/legacy): `update` treats 1.2.12-beta.N ≡ 1.2.12 (numeric prefix),
     so beta users won't be offered the stable via `update` after release — intentional?

open
  nothing else tracked
