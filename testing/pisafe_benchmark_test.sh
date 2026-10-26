#!/bin/bash
# pisafe compression benchmark: run one SD card through a matrix of
# compressors (zip gz xz zst) x levels and print a compare table.
#   defaults: compressors "zip gz xz zst"   levels "1 5 9"
#
#   how it works (matches pisafe itself):
#     - compressor = the output file's extension; level = passed per run to
#       pisafe as --level=<n> (config is never modified)
#     - the card is only ever READ
#     - old benchmark_* files with the names this run will create are removed
#       up front (pisafe refuses to overwrite), and each successful run's
#       .img + compressed result are deleted again afterwards to keep $OUTDIR
#       clear for the next run
#     - every report number comes from the PISAFE LOG (no screen capture),
#       so the config needs log=on (checked before running)
#
#   the report (also saved to benchmark_results_<timestamp>.txt) looks like:
#
#     =========================
#      Pisafe benchmark testing
#     =========================
#
#     item                   size(mb)  time(sec)  mb removed per second
#     sd card                     ...        ...  --
#     img (step 1 - copy)         ...        ...  0.0
#     img (step 2 - shrink)       ...        ...  ...
#
#     zip -1                      ...        ...  ...
#     (blank line between level groups; failed rows show FAILED; then a
#      notes: section with the auto-detected description + your NOTES lines)
#
#   columns:  size(mb) = result size in the log ("reduced to ...mb")
#             time(sec) = Step 1+2+3 ("Step N took ... sec")
#             mb removed per second = (sd card mb - size) / time(sec)
#             item column   = the row: sd card, the two img pipeline steps,
#                             or a compressor with its level (e.g. "zip -1");
#                             the level shown is the one the run used (the
#                             log's "Compression set to level N", so a clamp
#                             by pisafe is reflected)
#             img (step 1 - copy)   = the full card copy: device size,
#                                   copy time (step 1), 0 mb removed;
#                                   from the first run
#             img (step 2 - shrink) = the pishrink-ed image: its size
#                                   (log line "Shrunken image: ..."), the
#                                   shrink time (step 2) and the rate
#                                   measured over that same time
#             sd card row = blockdev size of the device
#             (in notes, __CARD_MB__ is replaced with the measured size,
#              e.g. "7948 mb" - or "n/a" if the card size could not be read)
#
#   usage:
#     bash pisafe_benchmark_test.sh [-h] [-c COMPRESSORS] [-l LEVELS]
#       -c  compressors from: zip gz xz zst   (space- or comma-separated,
#          quoted if several, e.g. -c "xz zst")
#       -l  levels, plain numbers (e.g. 1 5 9); env COMPRESSORS / LEVELS
#          act as the built-in defaults; each run is passed to pisafe as
#          --level=<n> (config untouched)
#
#   the 'notes:' description is always auto-detected: host model, cores,
#   ram, OS; the boot drive (nvme/emmc/usb/ssd + name + size); and the
#   test card's vendor, model and measured size
#
#   caveats:
#     - gz: cards with a post-shrink size >= ~3.9 GiB are refused by pisafe
#       before backup - that row shows FAILED, which is the right outcome
#     - levels above a compressor's max (xz/zip/gz go to 9, zst to 19) are
#       clamped down by pisafe with a warning - e.g. a single level 19 run
#       does 9 for zip/xz/gz and 19 for zst; the row name (e.g. "xz -9")
#       shows the level each run actually used

set -euo pipefail

find_pisafe() {
    local c
    c=$(command -v pisafe 2> /dev/null) || c=
    if [[ -n $c ]]; then
        echo "$c"
        return 0
    fi
    for c in /usr/local/bin/pisafe /mnt/dev/pisafe/pisafe; do
        if [[ -f $c ]]; then
            echo "$c"
            return 0
        fi
    done
    return 1
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
usage: bash pisafe_benchmark_test.sh [-h] [-c COMPRESSORS] [-l LEVELS]

  -c   compressors to run, space- or comma-separated (from: zip gz xz zst);
       quote a multi-word list, e.g. -c "xz zst"
  -l   compression levels to run, space- or comma-separated (e.g. 1 5 9);
       each run is passed to pisafe as --level=<n> (your config is
       untouched); levels above a compressor's max are clamped by pisafe
       (xz/zip/gz: 9, zst: 19)
  -h   this help

  the 'notes:' description is always auto-detected: host model, cores,
  ram, OS; the boot drive (nvme/emmc/usb/ssd + name + size); and the test
  card's vendor, model and measured size

  env: COMPRESSORS LEVELS (defaults for -c / -l) and
       PISAFE DEVICE OUTDIR CONFIG LOGFILE
EOF
}

if [[ ${1:-} == -h || ${1:-} == --help ]]; then
    usage
    exit 0
fi
while getopts ':c:l:h' opt; do
    case $opt in
        c) COMPRESSORS=${OPTARG//,/ } ;;
        l) LEVELS=${OPTARG//,/ } ;;
        h) usage; exit 0 ;;
        \?) echo "unknown option: -${OPTARG:-?}" >&2; usage >&2; exit 1 ;;
    esac
done
# getopts stops at the first non-option (e.g. -c xz zst unquoted) - make that loud
if (( OPTIND - 1 < $# )); then
    shift $((OPTIND - 1))
    echo "ERROR: unexpected argument(s): $*" >&2
    echo "       (quote multi-word lists, e.g. -c \"xz zst\")" >&2
    exit 1
fi

[[ -n ${COMPRESSORS// /} ]] || { echo "ERROR: no compressors selected." >&2; exit 1; }
[[ -n ${LEVELS// /} ]]     || { echo "ERROR: no levels selected." >&2; exit 1; }
for c in $COMPRESSORS; do
    case $c in
        zip|gz|xz|zst) ;;
        *) echo "ERROR: unknown compressor '$c' (choose from: zip gz xz zst)." >&2; exit 1 ;;
    esac
done
# level values here are just validated as numbers; each compressor's own
# range (and clamp) is enforced by pisafe at the compress step
for l in $LEVELS; do
    [[ $l =~ ^[0-9]+$ ]] \
        || { echo "ERROR: invalid compression level '$l' (use plain numbers, e.g. 1 5 9)." >&2; exit 1; }
done

# one-line description of the hardware we are running on (the 'notes:' line)
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

# notes block shown at the bottom (edit or extend as you like)
# __CARD_MB__ is replaced at runtime with the measured size ("7948 mb")
# or "n/a"
NOTES="zip set the standard years ago
gz is limited to < 4g, so is not recommended.
zst is the fastest
xz is the smallest
mb removed per second = (sd card __CARD_MB__ - size) / time(sec)
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

# card vendor + model, read-only from sysfs (empty if the device has none)
CARD_NAME=
BNAME=${DEVICE##*/}
if [[ -r /sys/block/$BNAME/device/model ]]; then
    CV=$(tr -d '\0' < "/sys/block/$BNAME/device/vendor" 2> /dev/null | head -n 1 \
         | tr '[:upper:]' '[:lower:]' | sed 's/[[:space:]]*$//' || true)
    CM=$(tr -d '\0' < "/sys/block/$BNAME/device/model" 2> /dev/null | head -n 1 \
         | tr '[:upper:]' '[:lower:]' | sed 's/[[:space:]]*$//' || true)
    CARD_NAME="${CV:+$CV }$CM"
fi

# which disk the OS runs from: type, vendor/model (when present), size
# sets BOOT_LINE ("boot: ...") and BOOT_DISK (disk name, e.g. nvme0n1)
boot_desc() {
    local SRC DISK T R V="" M="" BYTES MB SZ="" L="" P
    BOOT_LINE=""
    BOOT_DISK=""
    SRC=$(findmnt -n -o SOURCE / 2> /dev/null | head -n 1 || true)
    [[ $SRC == /dev/* ]] || return 0
    DISK=$(lsblk -no PKNAME "$SRC" 2> /dev/null | head -n 1 || true)
    [[ -n $DISK ]] || return 0
    T=""
    case $DISK in
        nvme*)   T="nvme" ;;
        mmcblk*) T="emmc" ;;
        sd*)     if [[ -r /sys/block/$DISK/device/transport ]]; then
                     T=$(tr -d '[:space:]' < "/sys/block/$DISK/device/transport" | head -n 1 || true)
                 fi
                 [[ -n $T ]] || T="sd"
                 R=$(cat "/sys/block/$DISK/queue/rotational" 2> /dev/null || true)
                 if [[ $R == 0 ]]; then T="$T ssd"; fi ;;
    esac
    if [[ -r /sys/block/$DISK/device/vendor ]]; then
        V=$(tr -d '\0' < "/sys/block/$DISK/device/vendor" | head -n 1 \
             | tr '[:upper:]' '[:lower:]' | sed 's/[[:space:]]*$//' || true)
    fi
    if [[ -r /sys/block/$DISK/device/model ]]; then
        M=$(tr -d '\0' < "/sys/block/$DISK/device/model" | head -n 1 \
             | tr '[:upper:]' '[:lower:]' | sed 's/[[:space:]]*$//' || true)
    fi
    BYTES=$(blockdev --getsize64 "/dev/$DISK" 2> /dev/null || true)
    if [[ ${BYTES:-} =~ ^[0-9]+$ ]]; then
        MB=$(( (BYTES + 500000) / 1000000 ))
        if (( MB >= 1000 )); then SZ="$((MB / 1000))gb"; else SZ="${MB}mb"; fi
    fi
    for P in "$T" "$V $M" "$SZ"; do
        [[ -n ${P// /} ]] || continue
        L+="${L:+ }$P"
    done
    BOOT_DISK=$DISK
    [[ -n $L ]] && BOOT_LINE="boot: $L"
    return 0
}

# the 'notes:' description: the hardware we run on, what the OS booted
# from, and the test card (name + measured size); if the card IS the boot
# disk it says so. Set after the card size above is read, so it can be named.
DESC_LINE=$(hw_desc)
boot_desc
CARD=""
[[ -n $CARD_NAME ]] && CARD+="$CARD_NAME"
[[ $CARD_MB -gt 0 ]] && CARD+="${CARD:+ }${CARD_MB}mb"

SAME_BOOT=0
if [[ -n ${BOOT_DISK:-} && $BOOT_DISK == "$BNAME" ]]; then
    SAME_BOOT=1
fi
if (( SAME_BOOT )); then
    [[ -n $CARD ]] && CARD+=" (boot)"
    [[ -z $CARD ]] && DESC_LINE+=", ${BOOT_LINE}"
else
    [[ -n ${BOOT_LINE:-} ]] && DESC_LINE+=", ${BOOT_LINE}"
fi
[[ -n $CARD ]] && DESC_LINE+=", against $CARD"

echo
echo "================================================================"
echo "  PiSafe compression benchmark"
echo "================================================================"
echo
CARD_HINT=""
[[ $CARD_MB -gt 0 ]] && CARD_HINT=" ($CARD_MB mb)"
echo "  PREPARE: put a trixie-lite image on an SD card${CARD_HINT}, card in $DEVICE"
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
echo "    3. levels:      $LEVELS        (passed to pisafe per run, --level=<n>;"
echo "                                       your config is never modified)"
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

# where in the log this benchmark's lines start
LOG_START=$(wc -l < "$LOGFILE" 2> /dev/null | tr -dc '0-9' || true)
LOG_START=${LOG_START:-0}

# the one place the benchmark's output file names are built
benchmark_name() {   # comp lvl -> full name (e.g. benchmark_zst_L1.img.zst)
    echo "benchmark_${1}_L${2}.img.${1}"
}

run_one() {
    local comp=$1 lvl=$2 outfile=$3
    echo "=== $comp level $lvl -> $outfile ==="
    "$PISAFE" backup "$DEVICE" "$outfile" -y --level="$lvl"
}

# ---- drop our own leftovers from an earlier run of this matrix ----
# pisafe refuses to overwrite an existing output file - so only the exact
# benchmark_* names we are about to (re)create get removed; everything
# else is left alone
for LEVEL in $LEVELS; do
    for COMPRESSOR in $COMPRESSORS; do
        N=$(benchmark_name "$COMPRESSOR" "$LEVEL")
        for F in "$OUTDIR/$N" "$OUTDIR/${N%.*}"; do
            if [[ -e $F ]]; then
                echo "removing old benchmark file: $F"
                rm -f -- "$F"
            fi
        done
    done
done

# ---- the runs ---- (level is passed per run with --level=<n>; config untouched)
for LEVEL in $LEVELS; do
    for COMPRESSOR in $COMPRESSORS; do
        OUTFILE="$OUTDIR/$(benchmark_name "$COMPRESSOR" "$LEVEL")"
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

RESULTS_FILE="$PWD/benchmark_results_$(date +%Y%m%d_%H%M).txt"

NEWLOG=$(mktemp)
if [[ -f $LOGFILE ]]; then
    tail -n +$((LOG_START + 1)) -- "$LOGFILE" > "$NEWLOG" 2> /dev/null || :
fi
trap 'rm -f "$NEWLOG"' EXIT

# the attempt list, in run order, "compressor|level|image-base-path"
ATTEMPTS=
for LEVEL in $LEVELS; do
    for COMPRESSOR in $COMPRESSORS; do
        N=$(benchmark_name "$COMPRESSOR" "$LEVEL")
        ATTEMPTS+="${COMPRESSOR}|${LEVEL}|${OUTDIR}/${N%.*};"
    done
done

{
    awk -v DESC="$DESC_LINE" -v NOTES="$NOTES" -v CARD_MB="$CARD_MB" \
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

        # --- effective level: "Compression set to level N of M" (logged by
        # --- pisafe after any clamp; the row shows the level actually used) ---
        {
            for (i = 1; i + 4 <= NF; i++)
                if ($i == "Compression" && $(i + 1) == "set" && \
                    $(i + 2) == "to" && $(i + 3) == "level" && lvl[b] == "")
                    lvl[b] = $(i + 4) + 0
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

            fm = "%-22s %8s  %9s  %s\n"   # 22 = "img (step 2 - shrink)" + gap
            print rule
            print title
            print rule
            print ""
            printf fm, "item", "size(mb)", "time(sec)", "mb removed per second"
            if (CARD_MB + 0 > 0) printf fm, "sd card", CARD_MB, "0", "--"

            # img rows (first run): the two pipeline stages, each timed by
            # its own step: the copy (step 1) removes nothing; the shrink
            # (step 2) times and rates against the step-2 duration; 0.0 when
            # a stage removed nothing
            did_img = 0
            it1 = (t[1, 1] + 0)
            it2 = (t[2, 1] + 0)
            if (b > 0 && it1 > 0 && CARD_MB + 0 > 0) {
                printf fm, "img (step 1 - copy)", CARD_MB, it1, "0.0"
                did_img = 1
            }
            if (b > 0 && bytes[1] + 0 > 0 && it2 > 0) {
                s = round1(bytes[1] / 1000000)
                r = (CARD_MB + 0) > s ? sprintf("%.1f", (CARD_MB - s) / it2) : "0.0"
                printf fm, "img (step 2 - shrink)", s, it2, r
                did_img = 1
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
                shlvl = (bb && lvl[bb] + 0 > 0) ? lvl[bb] : f[2]
                if (!bb || !has_size) {
                    printf fm, f[1] " -" shlvl, "FAILED", (tsum > 0 ? tsum : "-"), "-"
                } else {
                    ok++
                    s = round1(size[bb])
                    r = (tsum > 0 && CARD_MB > s) ? sprintf("%.1f", (CARD_MB - s) / tsum) : "--"
                    printf fm, f[1] " -" shlvl, s, (tsum > 0 ? tsum : "-"), r
                }
            }
            print ""
            card_show = (CARD_MB + 0 > 0) ? CARD_MB " mb" : "n/a"
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
