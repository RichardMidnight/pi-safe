# Review Round 1 — Safe Cleanup Pass

**Baseline:** tag `v1.2.11` (the `pisafe` script on branch `dev` is byte-identical to it).
**Goal:** apply all SAFE-class, behavior-preserving cleanup to `pisafe`, fix the approved math bug, and produce a change report. **Zero behavior changes** are the success bar — the user will test functionally before approval.

Read `AGENTS.md` first. It defines SAFE vs RISKY, the verification playbook, and the Git rules (commit only with approval, never push).

## Scope

### 1. Math fixes (approved)

* `pisafe`:844 — `t|T|tb|TB)  echo $(($BASE*1024*1024*1024*2014))` → `*1024`. The `2014` is a stray-key typo for `1024`; every other branch (lines 841–843) multiplies by 1024 per digit-group.
* Sweep **every** arithmetic site afterwards for similar typos: all `$(( ))`, `bc` pipelines, and `let` in the file (notable: `get_bytes` 800–848, `file_image_size` 924/980, `media_*` 1096, `get_ver_to_int` 714). Report what was checked even if clean.

### 2. Variable quoting (SAFE subset only)

Quote expansions that stand for a single token (paths, filenames, device names, command args):

* File tests: `[[ -f $CONFIG ]]` → `[[ -f "$CONFIG" ]]`
* Command words: `file_path $CONFIG` → `file_path "$CONFIG"`
* `echo $SCRIPTVER`, `echo $BYTES`, `echo $BLK_DEV` and similar single-result echoes
* `$(...)` results used as a single token

Hard rules:

* **Never quote** contexts where the shell must word-split lists: `for TOOL in $REQUIRED_TOOLS`, `for INSTALLER in $INSTALLERS`, `for TEXT_EDITOR in $TEXT_EDITORS`, etc.
* **Never change quoting** on the RHS of `=~` (quoting converts to literal match), on glob-pattern RHS of `==`/`!=`, or on expansions that feed `echo` and could start with `-`/`\` (could reinterpret echo flags) — log those as judgment calls instead.
* Inside `[[ ]]`, quoting the LHS and plain string-equality operands is safe; where in doubt, leave it and log it.
* Log **every** non-obvious quoting decision in the report.

### 3. Bash syntax standardization

* `[ ...; then` → `[[ ... ]]; then` (simple tests only, e.g. lines 569–590)
* `;then` → `; then`; collapsed one-line `if …; then …; fi` → multi-line
* `if[[` → `if [[`; make `[[ ]]` interior spacing consistent (e.g. `[[ $x=y ]]` → `[[ $x = y ]]`)
* Align the `;;` terminators within each `case` block
* No changes to expression interiors beyond what's listed here

### 4. Spacing and indentation

* Strip all trailing whitespace
* Convert tab indentation to 4 spaces (`get_ver_to_int`, lines 710–717, is the main block)
* Fix double-space clutter at construct boundaries; **do not** reflow spaces inside expressions or string literals

## Strictly NOT in this round (log as RISKY candidates only)

* Any logic change, refactor, or dead-code removal
* Any rename (functions, variables, CLI options)
* Adding or moving `local`
* Any change to user-visible output, prompts, exit codes, or help text
* Version, copyright, README, or `test_pisafe` changes
* Commits or pushes

## Verification (must actually run; paste real output in the report)

1. Baseline: `bash -n pisafe` → passes
2. Baseline: `bash pisafe -v` → prints `1.2.11`
3. **Before** editing: isolate `get_bytes` (lines 775–848) into `/tmp/opencode/get_bytes_test.sh` with a stub for `ui_msg_error` and `BASE/SUFFIX/OUTPUT` settable, and record the output of `kb m g tb` × `2`-style inputs. The `t|tb` input must be demonstrably **wrong** (×19× too small vs true 1024⁴×BASE).
4. Apply changes.
5. **After:** `bash -n pisafe`; `bash pisafe -v` → `1.2.11`
6. Re-run the isolated `get_bytes` test: `tb` output must now equal `BASE*1024*1024*1024*1024`; all other outputs identical to step 3.
7. `git diff --stat pisafe` and a full read-through of `git diff` classifying every hunk as one of the four scope areas (anything else → revert and log).
8. `git diff -w pisafe` — review the non-whitespace hunks; confirm each is in scope 1–3.

## Deliverables

1. `pisafe` modified per scope above.
2. `REVIEW_ROUNDS.md` created, containing: Round 1 status, per-category change counts (e.g. "N lines trailing whitespace, N expansions quoted, N syntax normalizations"), lines touched, verbatim verification output, **judgment calls** (quoting left alone, RISKY candidates for Round 2).
3. A concise change report in chat, ending with: "Waiting for user functional testing. On approval, commit `pisafe` + `AGENTS.md` + `REVIEW_ROUNDS.md` + `REVIEW_ROUND_1.md` as `review R1: <summary>`. No push."
4. **Stop** and wait for the user.
