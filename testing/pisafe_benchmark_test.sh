#!/bin/bash
# pisafe compression benchmark: run one SD card through a matrix of
# compressors (zip gz xz zst) x levels and print a compare table.
#   defaults: compressors "zip gz xz zst"   levels "1 5 9"
#
#   how it works (matches pisafe itself):
#     - compressor = the output file's extension; level = the config's
#       compression_level, sed'd into each run and restored on exit
#     - the card is only ever READ
#     - old benchmark_* files with the names this run will create are removed
#       up front (pisafe refuses to overwrite), and each successful run's
#       .img + compression are deleted again afterwards (~4GB per run won't
#       fit on an 8gb card)
#     - every report number comes from the PISAFE LOG (no screen capture),
#       so the config needs log=on (checked before running)
#
#   the report (also saved to benchmark_results_<timestamp>.txt) looks like:
#
#     =========================
#      Pisafe benchmark testing
#     =========================
#
#     compressor     level     size(mb)  time(sec)  mb removed per second
#     sd card                      ...          ...     --
#     img                          ...          ...     ...
#
#     zip              1          ...          ...     ...
#     (blank line between level groups; failed rows show FAILED; then a
#      notes: section with DESC + your NOTES lines)
#
#   columns:  size(mb) = result size in the log ("reduced to ...mb")
#             time(sec) = Step 1+2+3 ("Step N took ... sec")
#             mb removed per second = (sd card mb - size) / time(sec)
#             img row = shrunken image of the first successful run + its
#             Step 1+2 times; sd card row = blockdev size of the device
#             (in notes, __CARD_MB__ is replaced with the measured card size)
#
#   usage:
#     bash pisafe_benchmark_test.sh [-h] [-c COMPRESSORS] [-l LEVELS] [-d DESC]
#       -c  compressors from: zip gz xz zst   (space- or comma-separated)
#       -l  levels, plain numbers (e.g. 1 5 9); env COMPRESSORS / LEVELS
#          act as the built-in defaults
#       -d  the description line shown first under 'notes:'
#          (default: auto-detected hardware - model, cores, ram, OS)
#
#   caveats:
#     - gz: cards with a post-shrink size >= ~3.9 GiB are refused by pisafe
#       before backup - that row shows FAILED, which is the right outcome
#     - 9 is the max zip/gz/xz take; zstd goes to 19. Run zst-19 alone
#       (-c zst -l 19) - xz/zip silently take the last digit (xz -19 == -9)
#       and would print mislabelled rows

set -euo pipefail

find_pisafe() {
    command -v pisafe 2> /dev/null && return
    local c
    for c in /usr/local/bin/pisafe /mnt/dev/pisafe/pisafe; do
        [[ -x $c ]] && { echo "$c"; return; }
    done
}

PISAFE=${PISAFE:-$(find_pisafe || true)}
[[ -n $PISAFE ]] || {
    echo "ERROR: can't find pisafe - rerun as:  PISAFE=/path/to/pisafe bash testing/pisafe_benchmark_test.sh"
    exit 1
}
DEVICE=${DEVICE:-/dev/sda}
OUTDIR=${OUTDIR:-/home/pi/Downloads}
CONFIG=${CONFIG:-/home/$USER/.config/pisafe/pisafe.conf}
# pisafe's log (same directory as its config) - the report's data source
LOGFILE=${LOGFILE:-$(dirname "$CONFIG")/pisafe.log}
# which runs: space-separated lists (env vars act as defaults; -c/-l override)
COMPRESSORS=${COMPRESSORS:-zip gz xz zst}
LEVELS=${LEVELS:-1 5 9}

usage() {
    cat <<EOF
usage: bash pisafe_benchmark_test.sh [-h] [-c COMPRESSORS] [-l LEVELS] [-d DESC]

  -c   compressors to run, space- or comma-separated (from: zip gz xz zst)
  -l   compression levels to run, space- or comma-separated (e.g. 1 5 9)
  -d   the description line shown first under 'notes:'
       (default: auto-detected hardware - model, cores, ram, OS)
  -h   this help

  env: COMPRESSORS LEVELS (defaults for -c / -l) and
       PISAFE DEVICE OUTDIR CONFIG LOGFILE DESC
EOF
}

if [[ ${1:-} == -h || ${1:-} == --help ]]; then
    usage
    exit 0
fi
while getopts ':c:l:d:h' opt; do
    case $opt in
        c) COMPRESSORS=${OPTARG//,/ } ;;
        l) LEVELS=${OPTARG//,/ } ;;
        d) DESC=${OPTARG} ;;
        h) usage; exit 0 ;;
        \?) echo "unknown option: -${OPTARG:-?}" >&2; usage >&2; exit 1 ;;
    esac
done

[[ -n ${COMPRESSORS// /} ]] || { echo "ERROR: no compressors selected." >&2; exit 1; }
[[ -n ${LEVELS// /} ]]     || { echo "ERROR: no levels selected." >&2; exit 1; }
for c in $COMPRESSORS; do
    case $c in
        zip|gz|xz|zst) ;;
        *) echo "ERROR: unknown compressor '$c' (choose from: zip gz xz zst)." >&2; exit 1 ;;
    esac
done
for l in $LEVELS; do
    [[ $l =~ ^[0-9]+$ && $l -gt 0 ]] \
        || { echo "ERROR: invalid compression level '$l' (use plain numbers, e.g. 1 5 9)." >&2; exit 1; }
done

# one-line description of the hardware we are running on (used for the
# 'notes:' line unless -d / DESC is given)
hw_desc() {
    local DT MODEL="" CORES RAM OS P L=""
    DT=$(tr -d '\0' < /sys/firmware/devicetree/base/model 2> /dev/null | head -n 1 || true)
    if [[ $DT == Raspberry\ Pi* ]]; then
        MODEL="pi-${DT#"Raspberry Pi "}"
        MODEL=${MODEL%% *}    # "Raspberry Pi 5 Model B Rev 1.0" -> pi-5
    else
        MODEL=$(grep -m1 '^model name' /proc/cpuinfo 2> /dev/null | cut -d: -f2- \
                | sed 's/^[ \t]*//; s/,.*//' | tr '[:upper:]' '[:lower:]' || true)
    fi
    CORES=$(nproc 2> /dev/null || true)
    RAM=$(awk '/^MemTotal:/ {printf "%.0f", $2/1048576}' /proc/meminfo 2> /dev/null || true)
    OS=$(sed -n 's/^PRETTY_NAME=//p' /etc/os-release 2> /dev/null \
         | tr -d '"' | tr '[:upper:]' '[:lower:]' | sed 's/gnu\/linux //' || true)
    for P in "$MODEL" "$CORES cores" "${RAM}gb ram" "$OS"; do
        [[ -n ${P// /} ]] || continue        # skip anything that came up empty
        L+="${L:+, }${P}"
    done
    echo "${L:-hardware unknown}"
}

# description line: -d / env DESC win; otherwise the detected hardware
DESC=${DESC:-$(hw_desc)}

# notes block shown at the bottom (edit or extend as you like)
# __CARD_MB__ is replaced at runtime with the measured card size (mb)
NOTES="zip set the standard years ago
gz is limited to < 4g, so is not recommended.
zst is the fastest
xz is the smallest
mb removed per second = (sd card __CARD_MB__mb - size) / time(sec)
xz-1 will be pisafe's new default."

# ---- card size, read once up front (the card is never written) ----
CARD_BYTES=
if command -v blockdev > /dev/null 2>&1; then
    CARD_BYTES=$(blockdev --getsize64 "$DEVICE" 2> /dev/null || true)
fi
if [[ -z ${CARD_BYTES:-} ]] && command -v lsblk > /dev/null 2>&1; then
    CARD_BYTES=$(lsblk "$DEVICE" -dnbo SIZE 2> /dev/null | head -n 1 | tr -dc '0-9' || true)
fi
CARD_MB=0
if [[ ${CARD_BYTES:-} =~ ^[0-9]+$ ]] && [[ ${CARD_BYTES:-0} -gt 0 ]]; then
    CARD_MB=$(( (CARD_BYTES + 500000) / 1000000 ))
fi

echo
echo "================================================================"
echo "  PiSafe compression benchmark"
echo "================================================================"
echo
echo "  PREPARE: put a trixie-lite image on an 8GB SD card, card in $DEVICE"
echo

N_RUNS=0
for _c in $COMPRESSORS; do
    for _l in $LEVELS; do
        N_RUNS=$((N_RUNS + 1))
    done
done

echo "  What this script will do:"
echo "    1. back up $DEVICE to $OUTDIR $N_RUNS times"
echo "       ($N_RUNS FULL READS of the card - the card is never written to)"
echo "    2. compressors: $COMPRESSORS   (picked by the output extension)"
echo "    3. levels:      $LEVELS        (set in $CONFIG,"
echo "                                       your original level is restored at the end)"
echo "    4. each image is measured, then deleted to keep the disk clear"
echo "    5. the report is built from the new lines of the pisafe log:"
echo "         $LOGFILE"
echo "    6. the results table is also saved to:"
echo "         $PWD/benchmark_results_$(date +%Y%m%d_%H%M).txt"
echo
echo "  Expected duration: ~30-90 minutes depending on the card and the Pi."
echo
echo "  PiSafe in use: $PISAFE"
echo
read -r -p "Proceed? [y/N] " ANSWER || { echo; echo "aborted."; exit 0; }
[[ $ANSWER =~ ^[Yy]$ ]] || { echo "aborted."; exit 0; }

# ---- pre-flight checks ----
[[ -x $PISAFE ]]   || { echo "ERROR: cannot execute $PISAFE."; exit 1; }
[[ -f $CONFIG ]]   || { echo "ERROR: $CONFIG not found - run pisafe once first, or set CONFIG=..."; exit 1; }
[[ -b $DEVICE ]]   || { echo "ERROR: $DEVICE is not a block device - is the card in?"; exit 1; }
[[ -d $OUTDIR ]]   || { echo "ERROR: $OUTDIR does not exist."; exit 1; }
grep -q '^log=on' "$CONFIG" \
    || { echo "ERROR: the report is built from the pisafe log, but log is off in $CONFIG.";
         echo "       set  log=on  there first (turn it back off afterwards if you like)."; exit 1; }
if [[ $CARD_MB -eq 0 ]]; then
    echo "WARNING: could not read the size of $DEVICE - the 'sd card' and rate rows will show less."
fi

# remember the user's level so we don't silently leave it at '9'
ORIG_LEVEL=$(grep -oP '^compression_level=\K.*' "$CONFIG" 2> /dev/null || true)
restore_level() {
    [[ -n $ORIG_LEVEL ]] && sed -i "s/^compression_level=.*/compression_level=$ORIG_LEVEL/" "$CONFIG"
    return 0
}
trap restore_level EXIT

# where in the log this benchmark's lines start
LOG_START=$(wc -l < "$LOGFILE" 2> /dev/null | tr -dc '0-9' || true)
LOG_START=${LOG_START:-0}

# ---- helper: run one backup straight to the terminal ----
run_one() {
    local comp=$1 lvl=$2 outfile=$3
    echo "=== $comp level $lvl -> $outfile ==="
    "$PISAFE" backup "$DEVICE" "$outfile" -y
}

# ---- drop our own leftovers from an earlier run of this matrix ----
# pisafe refuses to overwrite an existing output file, and ~4GB per run
# won't fit on the card - so only the exact benchmark_* names we are
# about to (re)create get removed; everything else is left alone
for LEVEL in $LEVELS; do
    for COMPRESSOR in $COMPRESSORS; do
        for F in "$OUTDIR/benchmark_${COMPRESSOR}_L${LEVEL}.img" \
                 "$OUTDIR/benchmark_${COMPRESSOR}_L${LEVEL}.img.${COMPRESSOR}"; do
            if [[ -e $F ]]; then
                echo "removing old benchmark file: $F"
                rm -f -- "$F"
            fi
        done
    done
done

# ---- the runs ----
for LEVEL in $LEVELS; do
    sed -i "s/^compression_level=.*/compression_level=$LEVEL/" "$CONFIG"
    for COMPRESSOR in $COMPRESSORS; do
        OUTFILE="$OUTDIR/benchmark_${COMPRESSOR}_L${LEVEL}.img.${COMPRESSOR}"
        if run_one "$COMPRESSOR" "$LEVEL" "$OUTFILE"; then
            # report data is already in the log - make room for the next run
            echo "run ok - removing $OUTFILE (and the .img) to keep the disk clear"
            rm -f -- "$OUTFILE" "${OUTFILE%.*}"
        else
            echo "run FAILED for $COMPRESSOR level $LEVEL (see $LOGFILE) - continuing"
        fi
    done
done

# ---- build the report from the new lines of the pisafe log ----
echo
echo "all runs done - building the report from $LOGFILE (lines $((LOG_START + 1))+) ..."
echo "note: your original compression_level (${ORIG_LEVEL:-n/a}) is restored on exit"

RESULTS_FILE="$PWD/benchmark_results_$(date +%Y%m%d_%H%M).txt"

NEWLOG=$(mktemp)
if [[ -f $LOGFILE ]]; then
    tail -n +$((LOG_START + 1)) -- "$LOGFILE" > "$NEWLOG" 2> /dev/null || :
fi
trap 'restore_level; rm -f "$NEWLOG"' EXIT

# the attempt list, in run order, "compressor|level|image-base-path"
ATTEMPTS=
for LEVEL in $LEVELS; do
    for COMPRESSOR in $COMPRESSORS; do
        ATTEMPTS+="${COMPRESSOR}|${LEVEL}|${OUTDIR}/benchmark_${COMPRESSOR}_L${LEVEL}.img;"
    done
done

{
    awk -v DESC="$DESC" -v NOTES="$NOTES" -v CARD_MB="$CARD_MB" \
        -v ATTEMPTS="$ATTEMPTS" -v Q="'" '
        function round1(x) { if (x >= 0) return int(x + 0.5) + 0; return 0 - int(0.5 - x) + 0 }

        # --- a backup run begins with its step-1 banner; grab the .img base ---
        /Step 1 of 3 - Copying/ {
            b++
            for (i = 1; i < NF; i++)
                if ($i == "to") {
                    tok = $(i + 1)
                    if (substr(tok, 1, 1) == Q) tok = substr(tok, 2)          # leading quote
                    if (substr(tok, length(tok), 1) == Q) tok = substr(tok, 1, length(tok) - 1)  # trailing
                    img[b] = tok
                }
            next
        }
        b == 0 { next }

        # --- step durations: "Step N took X min Y sec" (logged by pisafe) ---
        {
            for (i = 1; i + 2 <= NF; i++) {
                if ($i == "Step" && $(i + 1) ~ /^[123]$/ && $(i + 2) == "took") {
                    n = $(i + 1) + 0; mn = 0; sc = 0
                    for (j = i + 3; j <= NF; j++)
                        if ($j == "min") mn = $(j - 1) + 0
                        else if ($j ~ /^sec\.?$/) sc = $(j - 1) + 0   # "sec" or trailing "sec."
                    t[n, b] = mn * 60 + sc
                    next
                }
            }
        }

        # --- shrunken image: "Shrunken image: <path> N bytes (<human>)" ---
        /Shrunken image:/ {
            for (i = 1; i < NF; i++)
                if ($i == "bytes" && $(i - 1) ~ /^[0-9]+$/) bytes[b] = $(i - 1) + 0
            next
        }

        # --- result size + total: "... reduced to <n.nn>mb in X min Y sec." ---
        {
            for (i = 1; i < NF; i++)
                if ($i == "to" && $(i - 1) == "reduced" && size[b] == "") {
                    tok = $(i + 1)
                    if (match(tok, /^[0-9.]+/)) {
                        v = substr(tok, 1, RLENGTH) + 0
                        if (tok ~ /[gG]/) v = v * 1024
                        size[b] = v
                    }
                }
            for (i = 1; i < NF; i++)
                if ($i == "in" && $(i + 2) == "min" && $(i + 4) ~ /^sec\.?$/ && total[b] == "")
                    total[b] = ($(i + 1) + 0) * 60 + ($(i + 3) + 0)
        }

        END {
            title = " Pisafe benchmark testing"
            n = length(title)
            rule = ""
            for (i = 0; i < n; i++) rule = rule "="

            fm = "%-14s %-9s %8s  %9s  %s\n"
            print rule
            print title
            print rule
            print ""
            printf fm, "compressor", "level", "size(mb)", "time(sec)", "mb removed per second"
            if (CARD_MB + 0 > 0) printf fm, "sd card", "", CARD_MB, "0", "--"

            # img row: shrunken image size of the first run + its copy/shrink time
            did_img = 0
            if (b > 0 && bytes[1] + 0 > 0) {
                it = (t[1, 1] + 0) + (t[2, 1] + 0)
                if (it > 0) {
                    s = round1(bytes[1] / 1000000)
                    r = (CARD_MB + 0) > s ? sprintf("%.1f", (CARD_MB - s) / it) : "--"
                    printf fm, "img", "", s, it, r
                    did_img = 1
                }
            }
            if (did_img) print ""

            # match each attempt to its log block via the .img base path
            natt = 0; ok = 0; printed = 0; prev_lvl = ""
            while ((k = index(ATTEMPTS, ";")) > 0) {
                at = substr(ATTEMPTS, 1, k - 1)
                ATTEMPTS = substr(ATTEMPTS, k + 1)
                if (at == "") continue
                split(at, f, "|")
                base = f[3]
                bb = 0
                for (j = 1; j <= b; j++)
                    if (img[j] == base || \
                        (length(img[j]) > length(base) && \
                         substr(img[j], length(img[j]) - length(base) + 1) == base) || \
                        (length(base) > length(img[j]) && \
                         substr(base, length(base) - length(img[j]) + 1) == img[j])) { bb = j; break }

                if (printed > 0 && f[2] != prev_lvl) print ""
                prev_lvl = f[2]
                printed++; natt++

                tsum = 0; has_size = 0
                if (bb) {
                    tsum = (t[1, bb] + 0) + (t[2, bb] + 0) + (t[3, bb] + 0)
                    if (tsum == 0) tsum = total[bb] + 0
                    has_size = (size[bb] != "")
                }
                if (!bb || !has_size) {
                    printf fm, f[1], f[2], "FAILED", (tsum > 0 ? tsum : "-"), "-"
                } else {
                    ok++
                    s = round1(size[bb])
                    r = (tsum > 0 && CARD_MB > s) ? sprintf("%.1f", (CARD_MB - s) / tsum) : "--"
                    printf fm, f[1], f[2], s, (tsum > 0 ? tsum : "-"), r
                }
            }
            print ""
            card_show = (CARD_MB + 0 > 0) ? CARD_MB : "n/a"
            print "notes:"
            if (DESC != "") print "  " DESC
            m = split(NOTES, ln, "\n")
            for (i = 1; i <= m; i++) {
                line = ln[i]
                gsub(/__CARD_MB__/, card_show, line)
                print "  " line
            }
            if (ok < natt) print "  ! " ok " of " natt " runs succeeded - see the pisafe log"
        }
    ' "$NEWLOG"
} | tee "$RESULTS_FILE"

rm -f "$NEWLOG"

echo
echo "results saved to: $RESULTS_FILE"
