# Review Round 9 — verification round: pv/compression syntax (user item #3) + global-leak audit

**Baseline:** `dev` at R8 (`c4aca2b`), 2918 lines, **26 findings / 8 codes**, `1.2.12.beta1`.
**Nature:** **verification first** (user `things to fix.md` item #3: "confirm syntax for pv on backup and restore"), plus closure of the R7/R8 follow-up audit (other variables with the `ROOTREADONLY` class). Code changes only if approved.

## A — pv / compression / decompression syntax audit (empirically verified, xz 5.8.1 / pv on this box)

### A.1 — `xz -z` in the compress path is CORRECT (initial suspicion refuted)

`pisafe:1199`: `pv '$OUTFILE_BASE.img' | xz -z -T0 -$COMPRESSION_LEVEL > '$OUTFILE'`

Initial suspicion: `-z` = decompress → broken compress path. **Refuted** — `xz --help`:
`-z, --compress — force compression` (xz's `-z` is *not* the classic `-z` = zlib/decompress; decompress is `-d`). Empirical proof (2 MB urandom sample, byte-identical roundtrip):

```
pv sample.img | xz -z -T0 -5 > out.xz      → rc 0, xz -t VALID, cmp roundtrip IDENTICAL
```

**No change. Do not "clean up" a verified working command.**

### A.2 — all compress arms verified correct

| arm | command | verdict |
|---|---|---|
| zip | `pv IMG \| zip -N OUT -` | ✓ stdin `-` ✓ |
| xz | `pv IMG \| xz -z -T0 -N > OUT` | ✓ (A.1) |
| gz | `pv IMG \| pigz -N > OUT` | ✓ (no decomp flag) |
| zst | `zstd -T0 -N --rm IMG` | ✓ output lands at `IMG.zst`; `IMG = $OUTFILE_BASE.img` and `OUTFILE_BASE = file_base(OUTFILE)` strips to first dot → `IMG.zst == OUTFILE` **only because** `media_backup_check_outfile` enforces the `.img.<EXT>` convention (L1359–1368) — verified `file_base` (`${BASE%%.*}`) + `file_ext` against the enforced pattern. Consistent today; fragile if the convention ever changes (noted, no action) |
| raw | `dd … of='$OUTFILE_BASE.img' conv=fsync \| pv -s` | ✓ |

### A.3 — all restore decompress arms verified correct

`unzip -p` ✓ · `xz -d -c` ✓ · `pigz -d -k -c` ✓ · `zstd -d -c` ✓ · raw `pv | dd of=DEV bs=4M conv=fsync` ✓. `pv -s $RESTORE_BYTES` gives the total to pv correctly at every compressed arm.

### A.4 — Discrepancies found (each RISKY-class — user decides per item)

* **R9.1 — L1659 restore log message is wrong**:
  ```
  ui_echo "~ Running: pigz -p -k -c '$INFILE' | …"      # says -p
  (pigz -d -k -c "$INFILE" | … )                          # actually runs -d -k -c
  ```
  The log line shown to the user misstates the command (`-p` = pigz *processor count*, not decompress; `-d` is correct). Fix = one token in the message string. (Changing user-visible strings = RISKY per campaign rules.)
* **R9.2 — raw img/iso restore has no `-s`** (L1618 cli, L1622 tui):
  `pv '$INFILE' | sudo dd …` and `(pv -n "$INFILE" | sudo dd …)` — **no `-s $RESTORE_BYTES`**, while all four compressed restore arms pass it. Effect: raw-image restores get no percentage/ETA denominator. Both `$RESTORE_BYTES` (L1613) and the size are already computed before the case — adding `-s "$RESTORE_BYTES"` to both arms is the consistent form. (Display/behavior change = RISKY-class: pv progress semantics change for the user.) **→ deferred by user 2026-09-25.**
* **R9.3 (minor, subsumed if R9.2 is done) — L1621 message** claims `sudo pv -n …` but the actual command runs `pv -n` without sudo. Cosmetic log text.
* **R9.1b — user-authored SAFE quotes (included in R9 by user approval)**: `menu_cli` case arms — `backup/restore` `$4`, `install` `$2`, `update` `$2`, `uninstall` `$2`, `details` `$2`, `erase|format` `$3 $4` → all quoted. Resolves exactly the 9 SC2086 keep-list sites for that cluster (pre-R9 2467, 2469, 2473, 2475, 2477, 2488, 2490×3). Single-token expansions — provably equivalent; A/B dispatch-identical.

### A.5 — `pv -n` (no bar) on the four TUI restore arms vs `pv -s` bar on the zip arm (L1630/1634)

Deliberate-looking (gauge display differs: whiptail gauge vs inline bar); inconsistent but each works. **Leave unless user wants unification** (out of campaign scope — UX work).

## B — global-leak audit (ROOTREADONLY class, R7/R8 follow-up)

Systematic scan (every function: names **read** in the function but **only conditionally written** and **not `local`** — the exact stale-bleed signature that R8 fixed). 27 function/name pairs flagged on first pass; all triaged:

* **No further stale-value bugs exist.** Every other flagged name is either unconditionally set before each read within the same call, early-returns before any read (e.g. `file_image_size` `*)` arm), or is an intentional cross-step global (`ES`, `INDEV`, `OUTFILE`, `MSG`, `SELECTION`, `ROOT_FILTER` — case arms cover all paths). Spot-verified `SIZE_BYTES` (file_image_size 922–940: every arm assigns or returns; stale-value path impossible since `$(…)` assignment always overwrites), `ROOT_FILTER` (case `y/n/*` each sets), `START_OF_FREESPACE` (write+read both inside the `SKIP_FREESPACE` if), `MEDIA_LAST_PARTITION_TYPE` (if/else covers), `PI_SHRINK_OPTS` (unconditionally `=` at L1138), `TIME3` (both if/else arms complete before L1157).
* **`media_partition_info` was the one real instance — fixed in R8.**
* **Hygiene residual (no behavior impact)**: per-item functions still use bare globals (`SIZE_BYTES` in file_size/file_image_size/media_size; `OS`, `PARTED_OUTPUT`, `MEDIA_PARTITIONS` in media_os; `FILE_NS` in file_list_image_files; `BYTES_TO_READ`/`START_OF_FREESPACE` in media_backup_bytes_to_read). Adding `local` to each = RISKY class per campaign rules and consumer-verification work per name; behavior would not change (all provably set-before-read). **Candidate backlog round if user wants belt-and-braces; I recommend against churn.**

## Scope decision (user)

* **R9.0 — docs-only**: record A.1–A.5 + B findings in campaign log as the closure of user item #3 and the leak audit. Zero code change.
* **R9.1 — fix L1659 message** (`-p` → `-d`): 1-token log-text correction. [RISKY: user-visible string]
* **R9.2 (+R9.3) — add `-s "$RESTORE_BYTES"` to both raw-img restore arms** and align the L1621 log message: consistent progress with the other four arms. [RISKY: display behavior change]

## Expected result

| Approved | Findings | Lines |
|---|---|---|
| docs only | 26 / 8 (unchanged) | 2918 |
| + R9.1 | 26 / 8 (unchanged) | 2918 (1 rewrite) |
| + R9.2 | 26 / 8 (unchanged) | 2918 (2 rewrites + 1 msg) |

## Verification (agent-safe)

1. If code changed: `bash -n`; `-v`; diff read-through (exactly the approved lines).
2. R9.2 equivalence proof (safe: temp files + `/dev/null` sink): `pv -s N f | dd of=/dev/null bs=4M` vs `pv f | dd of=/dev/null bs=4M` — both consume identically; `-s` only affects pv's display (verified: `xz`-style output byte-identical to disk with/without `-s`).
3. `git diff` = exactly the approved lines.

## Deliverables

1. `pisafe` changes **only if approved**.
2. `REVIEW_ROUNDS.md` — R9 section (verification verdicts A.1–A.5 + B audit) + open items ("confirm pv syntax" closed; leak audit closed; zst-fragility note logged).
3. Chat report → **stop, wait for user functional test + commit approval**.

## Commit

Pending user approval. Candidate message: `review R9: verify pv/tool syntax (item #3 closure), fix pigz log -p→-d, quote menu_cli args (26→17 findings)` (staged: `pisafe`, `REVIEW_ROUNDS.md`, `REVIEW_ROUND_9.md`; untracked user files excluded). **No push, no tag, no version bump.**

**Status: APPLIED + VERIFIED — R9.0 (docs) + R9.1 (log fix) + R9.1b (user menu_cli quotes) applied; R9.2 deferred by user. Changes on `dev`, uncommitted (commit pending user approval).**
