#!/bin/bash
# pisafe compression benchmark, two phases:
#   1. ONE full backup of the card with pisafe -> the shrunken raw .img
#      (the card is read once, and only once)
#   2. compress THAT image with each compressor x level pair, repeated
#      REPEATS times, recording each run's time and size
#   defaults: compressors "zip gz xz zst"   levels "1 5 9"   repeats 1
#
#   why two phases (testing/punchList, 2026-10-26): the old design ran a FULL
#   backup (copy + shrink + compress) for every level, so the card was re-read
#   and re-shrunk 12+ times.  The copy+shrink cost is the same for every
#   level, so measuring it once and then benchmarking the pure compression of
#   the one shrunken image is both faster and a cleaner measure of the tools.
#
#   how the runs work (matches pisafe itself):
#     - compressors = zip gz xz zst (picked by name); level per run
#     - the tool and flags are the ones pisafe uses on its no-pv path
#       (zip -j -N / xz -z -c -T0 -N / pigz -N -c / zstd -T0 -N); display
#       flags (-v) are dropped - they don't change speed or output
#     - levels above a compressor's max are clamped the same way pisafe
#       clamps them (zip/xz/gz: 9, zst: 19) and the row shows the level used
#     - gz parity: if the shrunken image is >= ~3.9 GiB raw the gz rows show
#       FAILED (guard) - exactly what a 'pisafe backup ...gz' would do
#     - the card is only ever READ
#     - each compression result is measured, then deleted to keep $OUTDIR
#       clear; the shared .img is removed at the end (re-run leftovers with
#       benchmark_ names are removed up front)
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
#     zip -1 #1                 ...        ...  ...
#     zip -1 #2                 ...        ...  ...
#     (blank line between level groups; failed rows show FAILED + reason;
#      then a notes: section with the auto-detected description + your
#      NOTES lines)
#
#   columns:  size(mb) = result size of that run, in mb
#             time(sec) = that run's wall time (the img rows: the pisafe
#                         log's step times, as before)
#             mb removed per second = (stage input mb - size) / time(sec):
#               img rows  - input is the sd card (copy removes nothing: 0.0)
#               comp rows - input is the shrunken img (e.g. 3367 -> 776 mb)
#             item column   = the row: sd card, the two img pipeline steps
#                             (from the one backup, logged by pisafe), or a
#                             compressor/level with its run number
#                             (e.g. "zip -1 #2")
#             sd card row = blockdev size of the device
#
#   usage:
#     bash pisafe_benchmark_test.sh DEVICE [-h] [-c COMPRESSORS] [-l LEVELS] [-r REPEATS]
#       DEVICE  target block device to read (required), e.g. /dev/sdb
#               (the DEVICE env still works as a fallback)
#       -c  compressors from: zip gz xz zst   (comma- or space-separated, quote
#          a spaced list). accepted forms: -c, -c=, --compress, --compress=
#          (e.g. -c "xz zst", -c=xz,zst, --compress=zip,zst,xz)
#       -l  levels, plain numbers (e.g. 1 5 9). accepted forms:
#          -l, -l=, --levels, --levels= (e.g. -l 1 5 9, -l=1,5,9)
#       -r  repeat each (compressor, level) pair this many times (default 1).
#          accepted forms: -r, -r=, --repeats, --repeats= (e.g. -r=3)
#
#   the 'notes:' description is always auto-detected: host model, cores,
#   ram, OS; the boot drive (nvme/emmc/usb/ssd + name + size); and the
#   test card's vendor, model and measured size
#
#   caveats:
#     - a box needs the compression tools the runs use (zip, pigz, xz,
#       zstd) - a missing tool shows a FAILED row for its compressor
#     - gz: see the 'gz parity' note above
#     - the config still needs log=on (the two img rows come from the
#       one pisafe backup's log lines)

set -euo pipefail

find_pisafe() {
    local c parent sd
    # resolution order (an explicit PISAFE env always wins):
    #   1. ./pisafe in the CWD  - run the bench from the folder holding the
    #                             copy of the app under test (repo root, a
    #                             scratch dir, straight off the share)
    #   2. the app in the       - the repo layout: harness in testing/, app
    #      parent folder           one level up
    #   3. alongside the        - the setup-mode layout: app + harness side
    #      harness                 by side
    #   4. a system install or  - last resort
    #      a PATH lookup
    sd=$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
    parent=$(cd "$sd/.." && pwd -P 2> /dev/null) || parent="$sd/.."
    for c in "$PWD/pisafe" "$parent/pisafe" "$sd/pisafe" /usr/local/bin/pisafe; do
        if [[ -f $c ]]; then
            echo "$c"
            return 0
        fi
    done
    c=$(command -v pisafe 2> /dev/null) || c=
    if [[ -n $c ]]; then
        echo "$c"
        return 0
    fi
    return 1
}

PISAFE=${PISAFE:-$(find_pisafe || true)}
[[ -n $PISAFE ]] || {
    echo "ERROR: can't find pisafe - rerun as:  PISAFE=/path/to/pisafe bash testing/pisafe_benchmark_test.sh"
    exit 1
}
# build date = the file's mtime. Stamped in the banner so a stale or wrong
# copy of the app (or of this bench) is obvious at a glance - testing/punchList
file_date(){ date -r "$1" '+%Y-%m-%d %H:%M' 2> /dev/null || echo '?unknown?'; }
# the target device: the positional DEVICE (see usage) takes precedence;
# the DEVICE env is the fallback - no silent /dev/sda default anymore
DEVICE=${DEVICE:-}
OUTDIR=${OUTDIR:-/home/pi/Downloads}
CONFIG=${CONFIG:-/home/$USER/.config/pisafe/pisafe.conf}
# pisafe's log (same directory as its config) - data source for the img rows
LOGFILE=${LOGFILE:-$(dirname "$CONFIG")/pisafe.log}
# which runs: space-separated lists + a repeat count (env vars act as
# defaults; -c/-l/-r override)
COMPRESSORS=${COMPRESSORS:-zip gz xz zst}
LEVELS=${LEVELS:-1 5 9}
REPEATS=${REPEATS:-1}

usage() {
    cat <<EOF
usage: bash pisafe_benchmark_test.sh DEVICE [-h] [-c COMPRESSORS] [-l LEVELS] [-r REPEATS]

  DEVICE  target block device to read (required), e.g. /dev/sdb;
          the DEVICE env still works as a fallback
  -c   compressors to run (from: zip gz xz zst), comma- or space-separated;
       a spaced list must be quoted. Accepted forms:
       -c "xz zst" | -c xz,zst | -c=xz,zst | --compress xz,zst | --compress=xz,zst
  -l   compression levels to run (e.g. 1 5 9); the card is never re-read
       per level - every run compresses the ONE shrunken image from the
       single phase-1 backup. Accepted forms:
       -l 1 5 9 | -l=1,5,9 | --levels 1 5 9 | --levels=1,5,9
  -r   repeat each (compressor, level) pair this many times (default 1);
       the report shows one row per run. Accepted forms:
       -r 3 | -r=3 | --repeats 3 | --repeats=3
  -h   this help

  the 'notes:' description is always auto-detected: host model, cores,
  ram, OS; the boot drive (nvme/emmc/usb/ssd + name + size); and the test
  card's vendor, model and measured size

  env: COMPRESSORS LEVELS REPEATS (defaults for -c / -l / -r) and
       PISAFE DEVICE OUTDIR CONFIG LOGFILE
EOF
}

# the device is the one positional argument (similar to pisafe_test.sh);
# options may appear in any order; the DEVICE env still works as a fallback
POSITIONAL=()
while (( $# )); do
    case $1 in
        -h|--help) usage; exit 0 ;;
        -c|--compress)
            [[ -n ${2:-} ]] || { echo "ERROR: missing value for -c (e.g. -c \"xz zst\")" >&2; exit 1; }
            COMPRESSORS=${2//,/ }; shift 2 ;;
        -l|--levels)
            [[ -n ${2:-} ]] || { echo "ERROR: missing value for -l (e.g. -l \"1 5 9\")" >&2; exit 1; }
            LEVELS=${2//,/ }; shift 2 ;;
        -r|--repeats)
            [[ -n ${2:-} ]] || { echo "ERROR: missing value for -r (e.g. -r 3)" >&2; exit 1; }
            REPEATS=$2; shift 2 ;;
        -c=*)
            COMPRESSORS=${1#-c=}; COMPRESSORS=${COMPRESSORS//,/ }; shift ;;
        --compress=*)
            COMPRESSORS=${1#--compress=}; COMPRESSORS=${COMPRESSORS//,/ }; shift ;;
        -l=*)
            LEVELS=${1#-l=}; LEVELS=${LEVELS//,/ }; shift ;;
        --levels=*)
            LEVELS=${1#--levels=}; LEVELS=${LEVELS//,/ }; shift ;;
        -r=*)
            REPEATS=${1#-r=}; shift ;;
        --repeats=*)
            REPEATS=${1#--repeats=}; shift ;;
        -*)   echo "ERROR: unknown option: $1" >&2; usage >&2; exit 1 ;;
        *)    POSITIONAL+=("$1"); shift ;;
    esac
done

if (( ${#POSITIONAL[@]} == 1 )); then
    DEVICE=${POSITIONAL[0]}
elif (( ${#POSITIONAL[@]} == 0 )) && [[ -n ${DEVICE:-} ]]; then
    :   # no positional - the DEVICE env (if any) is the fallback
elif (( ${#POSITIONAL[@]} == 0 )); then
    usage >&2
    echo
    echo "ERROR: DEVICE is required (one positional argument, e.g. /dev/sda - or the DEVICE env)" >&2
    exit 2
else
    echo "ERROR: too many positional arguments - only the DEVICE is expected." >&2
    echo "       (quote multi-word lists, e.g. -c \"xz zst\")" >&2
    exit 2
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
# range (and clamp) is applied per run, mirroring pisafe
for l in $LEVELS; do
    [[ $l =~ ^[0-9]+$ ]] \
        || { echo "ERROR: invalid compression level '$l' (use plain numbers, e.g. 1 5 9)." >&2; exit 1; }
done
if ! [[ $REPEATS =~ ^[0-9]+$ ]] || ! (( REPEATS >= 1 )); then
    echo "ERROR: invalid repeats '$REPEATS' (use a plain number >= 1, e.g. 3)." >&2
    exit 1
fi

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
mb removed per second = (input mb - size) / time(sec)  [img rows: input = sd card __CARD_MB__; comp rows: the shrunken img]
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
        N_RUNS=$((N_RUNS + REPEATS))
    done
done

echo "  What this script will do:"
echo "    1. back up $DEVICE ONCE (one full read of the card - it is never"
echo "       written to), keeping the shrunken raw image:"
echo "         $OUTDIR/benchmark_img.img"
echo "    2. compress THAT image: ($COMPRESSORS) x levels ($LEVELS),"
echo "       each pair $REPEATS time(s) = $N_RUNS runs; each run's time and size"
echo "       are recorded, then its output is deleted to keep the disk clear"
echo "    3. the compare table is printed and saved to:"
echo "         $PWD/benchmark_results_$(date +%Y%m%d_%H%M).txt"
echo
echo "  (the old design ran a FULL backup per level - this measures the"
echo "   compression tools directly on the one shrunken image)"
echo
echo "  Expected duration: one full card read + the $N_RUNS compressions."
echo
echo "  PiSafe in use: $PISAFE  [build: $(file_date "$PISAFE")]"
echo "  bench harness : $(file_date "${BASH_SOURCE[0]}")"
echo
read -r -p "Proceed? [y/N] " ANSWER || { echo; echo "aborted."; exit 0; }
[[ $ANSWER =~ ^[Yy]$ ]] || { echo "aborted."; exit 0; }
T_START=$(date +%s)    # total-runtime clock: the whole run, both phases

# ---- pre-flight checks ----
[[ -x $PISAFE ]]   || { echo "ERROR: cannot execute $PISAFE."; exit 1; }
[[ -f $CONFIG ]]   || { echo "ERROR: $CONFIG not found - run pisafe once first, or set CONFIG=..."; exit 1; }
[[ -b $DEVICE ]]   || { echo "ERROR: $DEVICE is not a block device - is the card in?"; exit 1; }
[[ -d $OUTDIR ]]   || { echo "ERROR: $OUTDIR does not exist."; exit 1; }
grep -q '^log=on' "$CONFIG" \
    || { echo "ERROR: the img rows come from the pisafe log, but log is off in $CONFIG.";
         echo "       set  log=on  there first (turn it back off afterwards if you like)."; exit 1; }
if [[ $CARD_MB -eq 0 ]]; then
    echo "WARNING: could not read the size of $DEVICE - the 'sd card' and rate rows will show less."
fi

# where in the log this run's phase-1 lines start
LOG_START=$(wc -l < "$LOGFILE" 2> /dev/null | tr -dc '0-9' || true)
LOG_START=${LOG_START:-0}

# ---- drop our own leftovers from earlier runs of this bench ----
# (pisafe refuses to overwrite; the compressors' outputs are ours to clean)
IMG="$OUTDIR/benchmark_img.img"
if [[ -e $IMG ]]; then
    echo "removing old benchmark image: $IMG"
    rm -f -- "$IMG"
fi
for F in "$OUTDIR"/benchmark_*_L*_run*.* "$OUTDIR"/benchmark_*_L*_run*.*.tmp; do
    [[ -e $F ]] && { echo "removing old benchmark file: $F"; rm -f -- "$F"; }
done

# ---- phase 1/2: the one full backup (raw .img - pisafe skips the compress) ----
echo
echo "=== phase 1/2: backup $DEVICE -> $IMG (one full read; step 1+2 timed by pisafe) ==="
"$PISAFE" backup "$DEVICE" "$IMG" -y \
    || { echo "ERROR: the phase-1 backup failed - see $LOGFILE"; exit 1; }
[[ -f $IMG ]] || { echo "ERROR: expected $IMG after the backup - not found."; exit 1; }
IMG_BYTES=$(stat -c%s -- "$IMG" 2> /dev/null) || IMG_BYTES=0
[[ ${IMG_BYTES:-0} =~ ^[0-9]+$ ]] || IMG_BYTES=0

# the step times come from pisafe's log window for this backup
WIN=$(tail -n +$((LOG_START + 1)) -- "$LOGFILE" 2> /dev/null || true)
STEP_TIMES=$(awk '
    { for (i = 1; i + 2 <= NF; i++)
        if ($i == "Step" && $(i + 1) ~ /^[12]$/ && $(i + 2) == "took") {
            n = $(i + 1) + 0; mn = 0; sc = 0
            for (j = i + 3; j <= NF; j++)
                if ($j == "min") mn = $(j - 1) + 0
                else if ($j ~ /^sec\.?$/) sc = $(j - 1) + 0
            t[n] = mn * 60 + sc
        }
    }
    END { print t[1] + 0, t[2] + 0 }
' <<<"$WIN")
IMG_T1=${STEP_TIMES%% *}; IMG_T2=${STEP_TIMES##* }
echo "  shrunken image: $IMG_BYTES bytes  (step 1: ${IMG_T1}s, step 2: ${IMG_T2}s)"

# ---- phase 2/2: compress THAT image, comp x level x repeat ----
# the one place a compression is actually run - the tool + flags pisafe uses
# on its no-pv path, so the numbers are comparable to production behavior
run_compressor(){    # comp level out img
    case $1 in
        zip) zip  -j -"$2" "$3" "$4" ;;
        xz)  xz   -z -c -T0 -"$2" "$4" > "$3" ;;
        gz)  pigz -"$2" -c "$4" > "$3" ;;
        zst) zstd -T0 -"$2" -c "$4" > "$3" ;;    # no display flag (-v/-q): not a timing variable
    esac
}
comp_tool(){    # comp -> the binary the run needs (gz = pigz, as pisafe uses)
    case $1 in
        zip) echo zip ;;  gz) echo pigz ;;  xz) echo xz ;;  zst) echo zstd ;;
    esac
}
# human size for the failure reasons (1024-based, like pisafe's get_bytes)
human_b(){ awk -v b="$1" 'BEGIN { split(" kb mb gb tb", u, " "); i = 0; b += 0
            while (b >= 1024 && i < 4) { b /= 1024; i++ }
            if (i == 0)          printf "%d", b
            else if (i == 1)     printf "%d%s", b, u[i]
            else                 printf "%.2f%s", b, u[i] }' 2> /dev/null || echo "n/a"; }

RESULTS=()     # "comp|efflvl|run|time|bytes|ok|reason"
N_OK=0
for LEVEL in $LEVELS; do
    for COMPRESSOR in $COMPRESSORS; do
        # pisafe's per-compressor max (zip/xz/gz: 9, zst: 19) - the same
        # clamp it applies with a warning; the row shows the level used
        MAXL=9
        [[ $COMPRESSOR == zst ]] && MAXL=19
        EFL=$LEVEL
        (( LEVEL > MAXL )) && EFL=$MAXL
        TOOL=$(comp_tool "$COMPRESSOR")
        for (( RUN = 1; RUN <= REPEATS; RUN++ )); do
            ITEM="$COMPRESSOR -$EFL #$RUN"
            OUTF="$OUTDIR/benchmark_${COMPRESSOR}_L${EFL}_run${RUN}.img.${COMPRESSOR}"
            T=0; BYTES=0; REASON=""
            if [[ $COMPRESSOR == gz ]] && (( IMG_BYTES >= 1073741824 * 39 / 10 )); then
                # parity with pisafe's pre-backup gz guard (same 3.9 GiB
                # constant): a real 'backup ...gz' would refuse this raw size
                REASON="guard: $(human_b "$IMG_BYTES") raw (>= ~3.9 GiB) - pisafe refuses gz this large"
            elif ! command -v "$TOOL" > /dev/null 2>&1; then
                REASON="tool missing ($TOOL)"
            else
                rm -f -- "$OUTF"     # zip appends to an existing archive; start clean for all
                T0=$(date +%s)
                RC=0
                run_compressor "$COMPRESSOR" "$EFL" "$OUTF" "$IMG" 2> /dev/null || RC=$?
                T=$(( $(date +%s) - T0 ))
                if (( RC == 0 )); then
                    BYTES=$(stat -c%s -- "$OUTF" 2> /dev/null) || BYTES=0
                    RESULTS+=("$COMPRESSOR|$EFL|$RUN|$T|$BYTES|ok|")
                    N_OK=$((N_OK + 1))
                    echo "  ok    $ITEM  ${T}s  $(( (BYTES + 500000) / 1000000 ))mb"
                else
                    RESULTS+=("$COMPRESSOR|$EFL|$RUN|$T|0|failed|exit $RC")
                    echo "  FAILED $ITEM  (exit $RC)"
                fi
                rm -f -- "$OUTF"     # keep the disk clear; the table is the record
            fi
            if [[ -n $REASON ]]; then
                RESULTS+=("$COMPRESSOR|$EFL|$RUN|0|0|failed|$REASON")
                echo "  FAILED $ITEM  ($REASON)"
            fi
        done
    done
done
N_ATT=${#RESULTS[@]}

# ---- the report (built from the measurements above) ----
echo
echo "all runs done - building the report ..."

RESULTS_FILE="$PWD/benchmark_results_$(date +%Y%m%d_%H%M).txt"
# bytes -> rounded mb (the report's size column)
r1(){ echo $(( ($1 + 500000) / 1000000 )); }
# stage rate in mb/sec, one decimal: (in - out) bytes over t seconds
rate(){ awk -v i="$1" -v o="$2" -v t="$3" 'BEGIN {
        d = (i + 0) - (o + 0); if (d < 0) d = 0
        if (t + 0 <= 0) { print "0.0" } else printf "%.1f", d / 1000000 / t }'; }

{
    title=" Pisafe benchmark testing"
    rule=""
    printf -v rule '=%.0s' $(seq 1 "${#title}")
    printf '%s\n' "$rule"
    printf '%s\n' "$title"
    printf '%s\n' "$rule"
    echo
    printf '%-22s %8s  %9s  %s\n' "item" "size(mb)" "time(sec)" "mb removed per second"
    if (( CARD_MB > 0 )); then
        printf '%-22s %8s  %9s  %s\n' "sd card" "$CARD_MB" 0 "--"
    fi

    # img rows (the one backup): the two pipeline stages, as before - the
    # copy removes nothing (0.0); the shrink is timed and rated against the
    # card -> shrunken delta
    if (( IMG_T1 > 0 )) && (( CARD_MB > 0 )); then
        printf '%-22s %8s  %9s  %s\n' "img (step 1 - copy)" "$CARD_MB" "$IMG_T1" "0.0"
    fi
    if (( IMG_BYTES > 0 )) && (( IMG_T2 > 0 )); then
        s=$(r1 "$IMG_BYTES")
        r=$(rate "$CARD_BYTES" "$IMG_BYTES" "$IMG_T2")
        printf '%-22s %8s  %9s  %s\n' "img (step 2 - shrink)" "$s" "$IMG_T2" "$r"
    fi
    echo

    # comp rows, in run order (level outer, compressor inner, repeats inner);
    # a blank line between level groups, as before
    prev_lvl=""
    for ROW in "${RESULTS[@]}"; do
        IFS='|' read -r comp eff run t bytes status reason <<<"$ROW"
        if [[ $eff != "$prev_lvl" ]]; then
            [[ -n $prev_lvl ]] && echo
            prev_lvl=$eff
        fi
        if [[ $status == ok && $bytes =~ ^[0-9]+$ && $bytes -gt 0 ]]; then
            printf '%-22s %8s  %9s  %s\n' "$comp -$eff #$run" "$(r1 "$bytes")" "$t" "$(rate "$IMG_BYTES" "$bytes" "$t")"
        else
            printf '%-22s %8s  %9s  %s\n' "$comp -$eff #$run" FAILED "${t:-0}" "${reason:-failed}"
        fi
    done
    echo
    card_show="$CARD_MB mb"
    (( CARD_MB > 0 )) || card_show="n/a"
    echo "notes:"
    printf '  %-80s\n' "$DESC_LINE"
    while IFS= read -r ln; do
        ln=${ln//__CARD_MB__/$card_show}
        printf '  %s\n' "$ln"
    done <<<"$NOTES"
    if (( N_OK < N_ATT )); then
        echo "  ! $N_OK of $N_ATT compression runs succeeded - reasons above"
    fi
    echo "  design: one backup (steps timed by pisafe), then pure tool x level x repeat"
    echo "          compressions of that one shrunken image - one card read total"
} | tee "$RESULTS_FILE"

echo
echo "removing the shared image: $IMG"
rm -f -- "$IMG"
echo
# total runtime: from the Proceed gate (both phases, report + cleanup) to here
TOTAL_S=$(( $(date +%s) - T_START ))
if   (( TOTAL_S >= 3600 )); then DUR="$(( TOTAL_S / 3600 ))h $(( TOTAL_S % 3600 / 60 ))m $(( TOTAL_S % 60 ))s"
elif (( TOTAL_S >= 60   )); then DUR="$(( TOTAL_S / 60 ))m $(( TOTAL_S % 60 ))s"
else                            DUR="${TOTAL_S}s";
fi
echo "total run time: $DUR (${TOTAL_S}s)"
echo "results saved to: $RESULTS_FILE"
