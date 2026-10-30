#!/bin/bash
#
# pisafe_test.sh v2.3 - pisafe integration test harness (2026-10-27)
#
# DESTRUCTIVE tool: it formats $DEVICE and writes backup images onto it.
# (except 'setup' mode, which only copies the pisafe pair from GitHub and, if the box has no
#  fetcher at all, installs a web-fetch tool; it never installs runtime tools or touches a device; see usage below)
# Pass the target card explicitly; never run it against a system disk.
# Human-driven only: AI agents must never execute this script.
#
# Usage:
#   pisafe_test.sh DEVICE [BASE] [--full] [-c LIST] [-l LEVEL] [-y|--yes]
#   pisafe_test.sh setup [DIR|-y]               (non-destructive bootstrap)
#   pisafe_test.sh env                          (non-destructive: prints the
#                                                 box's environment only - no
#                                                 battery, no device needed)
#   Example:  pisafe_test.sh /dev/sda --full
#
#   DEVICE    target block device to test (required), e.g. /dev/sdb.
#             must not be mounted anywhere; if it is, the script offers to
#             umount it first and refuses if it is still mounted afterwards.
#             the card is DISPOSABLE and should contain real data (an OS
#             install or random files): an empty or freshly-formatted card
#             weakens the test and can false-fail the --full "card changed"
#             check. put nothing on it that you keep.
#   BASE      prefix for the images (default: $PWD/test_<hostname>). pisafe inserts
#             '.img' into the output name, so the files actually written are
#             BASE.img.zip, BASE.img.gz, BASE.img.xz, BASE.img.zst - or only
#             the ones you select with --compress (default: all four). pisafe
#             also refuses an existing raw BASE.img. the battery removes its
#             own images at the end of the run, so a re-run starts clean.
#   --full    additionally verify bytes (slower, uses extra disk):
#                 * keeps a raw reference image of the card (harness does its own dd)
#                 * each backup is decompressed and cmp'd against that reference
#                 * after each format: first 1 MiB must have changed, FS must be vfat
#                 * after each restore: card is read back and cmp'd against reference
#             without --full (std mode): only exit status + fresh-log markers.
#   -c LIST,  test only the listed compressions: any subset of zip, gz,
#   --compress        xz, zst - comma- or space-separated (e.g. --compress=zip,zst
#             or -c "zip zst"; accepted: -c=zip,zst, --compress zip,zst).
#             Order and duplicates are ignored; the default is all four. A
#             bare flag or an empty list is a fatal error.
#   -l LEVEL, compression level for the backup step, passed to pisafe as
#   --level   --level=N (1-19; xz/zip/gz clamp to 9 with a warning). ONE level
#             per run; a list like -l=1,5,9 is refused - the level matrix is
#             the bench's job: pisafe_benchmark_test.sh -l 1 5 9
#
#   -y, --yes automatically answer every prompt "yes" (umount a mounted
#             device, delete existing image files, final confirmation);
#             nothing is ever read from stdin when set. Use only when you
#             are sure the target is disposable.
#
# Flow:
#   1  preflight         device / space / tool checks        (non-destructive)
#   2  confirm gate      single warning + ENTER (skipped with -y),
#                        plus two conditional pre-flight prompts, if needed:
#                        umount a mounted device / delete existing images
#   3  backup            the selected compressions           (card untouched)
#   4  per compression   format card (fat32) -> verify -> restore its image -> verify
#   5  cleanup           remove the images the battery wrote (only after every
#                        restore + check is done)
#   6  report            PASS/FAIL per step, tally, exit 1 if any FAIL
#
# Checks per step (std mode):
#   1. pisafe exit status == 0
#   2. the log window covered by this exact step (line-count seed just before
#      the call -- log timestamps are only minute-resolution) contains the
#      step's "complete" marker and none of the exact fatal lines pisafe logs
#      (see FAIL_RE) -- loose keywords like "error"/"exit_status" are NOT
#      used, because pisafe logs benign lines containing them (e.g. the
#      tolerated pishrink "nothing to shrink" path logs "~ Exit_Status 7 ..."
#      and then continues to backup-complete).
#
# Environment:
#   PISAFE      path to the pisafe script (default: ./pisafe in the CWD,
#               then ../pisafe, the app in the parent folder; alongside-copy
#               = setup-mode fallback)
#   PISAFE_REF  ref for setup mode downloads (default: 'dev')
#
set -u

VERSION="2.6"
EXTS=(zip gz xz zst)
# exact strings pisafe logs ONLY on fatal paths (verified against source):
#   ~ Error at line ...   ui_msg_error  (pisafe:1995, all callers abort)
#   ~ Backup canceled     backup user-abort (pisafe:1535)
#   ~ Restore stopped.    restore user-abort (pisafe:1654)
#   ~ Erase Media stopped.  erase user-abort (pisafe:2128)
#   not erased.           erase confirm rejected (pisafe:2119)
# Real failures also always trip check 1 (non-zero exit) and/or the missing
# marker check, so this scan is a supplement, not the primary signal.
FAIL_RE='~ Error at line|~ Backup canceled|~ Restore stopped|~ Erase Media stopped|not erased'
LOG_FILE="$HOME/.config/pisafe/pisafe.log"
# Resolution order (an explicit PISAFE env always wins - a bad path is a
# hard error, see the existence check below, never a silent re-default):
#   1. ./pisafe in the CWD        - run the battery from the folder holding
#                                   the copy of the app under test (repo
#                                   root, a scratch dir, straight off the share)
#   2. the app in the parent      - the repo layout: harness in testing/,
#      folder                       app one level up
#   3. alongside the harness      - the setup-mode layout: app + harness
#                                   side by side
SCRIPT_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"
if [[ -z ${PISAFE:-} ]]; then
  if [[ -f ./pisafe ]]; then
    PISAFE="$PWD/pisafe"
  else
    PISAFE="$PARENT_DIR/pisafe"
    [[ -f $PISAFE ]] || PISAFE="$SCRIPT_DIR/pisafe"
  fi
fi

# build date of a script = the file's mtime. Logged in every banner/report so
# a stale or wrong copy is obvious at a glance (the shadow-copy lesson: a
# battery can silently run a months-old script next to it - testing/punchList).
file_date(){ date -r "$1" '+%Y-%m-%d %H:%M' 2> /dev/null || echo '?unknown?'; }

# deterministic, non-interactive flags for every pisafe invocation.
# --dependencies=ON is deliberate: installing the missing runtime tools is
# pisafe's own job, and that is exactly what the battery is supposed to
# prove.  On a bare box the first step hits pisafe's own
# "Install dependencies?" prompt, the harness answers 'y' for it (see
# run_step), and pisafe installs through its own installer (apt + the
# pishrink download); the step's PASS/FAIL records how that went.
STD_FLAGS=(--log=on --updates=off --dependencies=on --sound=off)

# unquoted-on-purpose: expands to nothing when empty (running as root)
SUDO=""
[[ $EUID -ne 0 ]] && SUDO=sudo

DEVICE=""
BASE=""
FULL=0
# -y/--yes: auto-answer yes to every prompt (empty = always ask; a dead
# stdin or any other answer is treated as "no", so it fails closed)
YES=""
# -c/--compress: raw selection ("" = flag not given) and rebuilt arm list.
COMPRESS=""
HAVE_COMPRESS=0
# -l/--level: ONE compression level for the backup step ("" = not given),
# passed to pisafe as --level=N; the app clamps per compressor (xz/zip/gz max 9)
LEVEL=""
HAVE_LEVEL=0
TMPD=""
REFERENCE=""
SUCCESS_MARKER=""
PASS_CNT=0
FAIL_CNT=0
REPORT=()
SURFACE=""   # native surface capture: set before the battery, printed in the report

# ---------------------------------------------------------------- utilities --

if [[ -t 1 ]]; then
  RED=$'\e[31m'; GRN=$'\e[32m'; YLW=$'\e[33m'; CYN=$'\e[36m'; RST=$'\e[0m'
else
  RED=""; GRN=""; YLW=""; CYN=""; RST=""
fi

info()  { echo "${CYN}== $*${RST}"; }
ok()    { echo "${GRN}[PASS] ${RST}$*"; }
bad()   { echo "${RED}[FAIL] ${RST}$*"; }
warn()  { echo "${YLW}[WARN] ${RST}$*"; }
DIE()   { echo "${RED}FATAL: $*${RST}" >&2; exit 2; }

usage(){
  cat <<EOF
pisafe_test.sh v$VERSION - destructive pisafe integration test harness

Usage: pisafe_test.sh DEVICE [BASE] [--full] [-c LIST] [-l LEVEL] [-y|--yes]
       pisafe_test.sh setup [DIR|-y]
       pisafe_test.sh env

Arguments:
  DEVICE      target block device to test (required), e.g. /dev/sdb.
              must not be mounted anywhere; if it is, the script offers to
              umount it and refuses if it is still mounted afterwards.
              never point this at a system disk.
              card state: DISPOSABLE, with real data on it (an OS install
              or random files) - an empty or freshly-formatted card
              weakens the test and can false-fail the --full "card
              changed" check. put nothing on it that you keep.
  BASE        prefix for the test images (default: \$PWD/test_<hostname>). pisafe
              inserts '.img' into the output name, so the actual files are
              BASE.img.zip, BASE.img.gz, BASE.img.xz, BASE.img.zst - only the
              ones selected with --compress are tested (default: all four).
              pisafe also refuses an existing raw BASE.img. Existing files
              under those names are deleted only after an explicit yes
              (-y auto-yes). The battery removes its own images at the end
              of the run, so a re-run starts clean.
  --full      also verify bytes: keep a raw reference image of the card and
              cmp each decompressed backup, the erased card state, and the
              restored card against it. (slower, needs ~2x more free space)
  -c LIST,  test only the listed compressions: any subset of zip, gz, xz,
  --compress        zst, comma- or space-separated (quote a spaced list).
              Accepted forms: -c zip,zst | -c=zip,zst | --compress zip,zst
              | --compress=zip,zst. Order and duplicates are ignored. A
              bare flag or an empty list is a fatal error. Default: all four.
  -l LEVEL, compression level for the backup step, passed to pisafe as
  --level   --level=N (1-19; xz/zip/gz clamp to 9 with a warning - that is
              the app behavior under test). One level per run; a list such
              as -l=1,5,9 is refused - the level matrix is the bench's job:
              pisafe_benchmark_test.sh -l 1 5 9
  -y, --yes   answer every prompt "yes" without asking (umount a mounted
              device, delete existing image files, the final confirmation);
              nothing is read from stdin when set. use only on a target you
              are sure is disposable.
  -h, --help  this text

Setup mode (non-destructive, no card needed - bootstrap for a new test box):
  setup [DIR]  1. create DIR (default: ~/Downloads),
                2. copy the latest pisafe plus a fresh pisafe_test.sh from GitHub
                   into it (ref 'dev'; set PISAFE_REF to a tag, e.g.
                   v1.2.12-beta.6, to pin),
                3. leave you in DIR (prints the ready-to-paste one-line cd +
                   test command).
               Shows this plan first and waits for ENTER (-y skips the gate).
               The ONLY install it may do: 'wget', if the box has no wget/curl
               at all. Runtime tools (pv, pishrink, ...) are NOT installed
               here - pisafe's own installer does that, and the battery tests
               exactly that (the dependency check stays ON). The file running
               this command is never overwritten.

Env mode (non-destructive, no card needed - record the box without running it):
  env        print the machine header (hostname, OS, arch, kernel) plus the
             native-surface snapshot the battery report would carry (TUI
             backend, installer, terminal, editor, sound, shell/user),
             then exit. Nothing is installed, no device is touched, no battery
             is run - use it to record a box's environment row without
             re-running the backup/restore tests.

Examples:
  bash pisafe_test.sh /dev/sda --full                # all four arms + byte checks
  bash pisafe_test.sh /dev/sda --compress=zip,zst    # a subset of arms
  bash pisafe_test.sh /dev/sdb /media/pi/imgs -y     # images elsewhere, no prompts
  bash pisafe_test.sh setup                          # new box: ~/Downloads + pair
  bash pisafe_test.sh setup /opt/pisafe -y           # other dir, no prompts
  bash pisafe_test.sh env                            # record the box's env (no battery, no card)

Per step, both modes check:  pisafe exit status == 0  AND  the log window of
this exact step contains its "complete" marker and no error/abort lines.

Environment: PISAFE=/path/to/pisafe    (default: ./pisafe in the CWD, then ../pisafe)
            PISAFE_REF=REF            (setup mode; default 'dev')

Human-driven only: this script will format the target card.
EOF
}

# ------------------------------------------------------------------ helpers --

# how many lines the log has right now (0 if no log yet)
log_seed(){
  local n
  n=$(wc -l < "$LOG_FILE" 2>/dev/null | tr -dc '0-9')
  echo "${n:-0}"
}

# everything written to the log after line N
log_window(){
  tail -n +$(( $1 + 1 )) "$LOG_FILE" 2>/dev/null
}

# --------------------------------------------------------- environment probe --
# Read-only snapshot of the box's interactive surface, mirroring the exact
# chains pisafe itself resolves at runtime (same order):
#   TUI       the menus literally call the `whiptail` command
#             (pisafe:1801,2166,2223,2658); the newt install (pisafe:380-381)
#             is a fallback pisafe PULLS, not a render path - a newt-only box
#             has no working menu, so whiptail is the real gate and newt is
#             only a "present but may not render" note
#   installer (pisafe:589)   : apt pacman dnf
#   terminal  (pisafe:629-645): lxterminal xfce4-terminal mate-terminal
#                               gnome-terminal xterm terminator konsole
#                               qterminal x-terminal-emulator
#   editor    (pisafe:665)   : leafpad xed gedit featherpad kwrite pluma
#                               kate mousepad geany gnome-text-editor nano
# Deliberately built on `command -v` (bash builtin) - a read-only probe that
# never installs or changes anything, so this capture can never change
# the box.

# walk a chain: first present entry wins (that is what pisafe picks); the other
# present entries are listed too, so the report carries both the choice and the
# full shape of the box
chain_probe(){
  local first="" also="" t
  for t in "$@"; do
    command -v "$t" >/dev/null 2>&1 || continue
    if [[ -z $first ]]; then first=$t; else also="${also:+$also, }$t"; fi
  done
  if [[ -z $first ]]; then echo "none"; return 0; fi
  if [[ -n $also ]]; then echo "$first (also: $also)"; else echo "$first"; fi
  return 0
}

# ------------------------------------------------------- repo + req checks --
# Two box-level diagnostics for the report/env block that no per-step check
# can see, answering "could this box even have done that in the first place":
#   repo liveness : does the distro repo still publish updates? (buster:
#                   no - the EOL archive 404s, the installed lists are frozen
#                   and nothing new can be installed any more)
#   requirements  : are the tools pisafe declares (pisafe:28 REQUIRED_TOOLS)
#                   present, or at least installable from that repo? (the box
#                   whose repo simply has no zstd)
# Both are informational: NEVER a gate or a failure, and read-only by
# construction - bounded HTTP GETs and local package-list queries only
# (apt-cache policy / pacman -Si / dnf --cacheonly). They must stay that way:
# env mode runs on any box, including boxes the battery would not run on.
REPO_STATE=""   # online | offline | unreachable | unknown (set by repo_liveness)

# one bounded read-only HTTP GET; echoes exactly one word:
# online (2xx/3xx) | offline (404) | unreachable (network/other/timeout)
http_probe(){
  local code rc
  if command -v curl >/dev/null 2>&1; then
    code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 8 --max-time 15 "$1" 2> /dev/null) || code=000
    case $code in
      2*|3*) echo online;      return 0 ;;
      404)   echo offline;     return 0 ;;
      *)     echo unreachable; return 0 ;;
    esac
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -q -sp -O /dev/null --timeout=15 --tries=1 "$1" 2> /dev/null
    rc=$?
    case $rc in
      0) echo online;      return 0 ;;
      8) echo offline;     return 0 ;;
      *) echo unreachable; return 0 ;;
    esac
  fi
  echo unreachable
  return 0
}

# up to 4 candidate repo URLs from this box's package configuration:
#   apt    : .list lines (deb BASE DIST ...) + deb822 .sources (URIs, Suites);
#            apt's URL scheme is BASE/dists/DIST/Release
#   pacman : first Server= line of /etc/pacman.d/mirrorlist
#            ($repo -> core, $arch -> uname -m)
#   dnf    : first baseurl= under /etc/yum.repos.d
# One URL per line.
repo_urls(){
  local u arch
  if command -v apt >/dev/null 2>&1; then
    {
      grep -hE '^[[:space:]]*deb[[:space:]]' \
        /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2> /dev/null \
        | awk '{print $2 "/dists/" $3 "/Release"}'
      # deb822 keys are case-insensitive; the conventional spelling is
      # 'URIs:'/'Suites:' - match case-insensitively for both
      awk '/^[Uu][Rr][Ii][Ss]:/ { uri=$2; sub(/\/+$/, "", uri) }
           /^[Ss][Uu][Ii][Tt][Ee][Ss]:/ { if (uri != "") print uri "/dists/" $2 "/Release"; uri="" }
           ' /etc/apt/sources.list.d/*.sources 2> /dev/null
    } | sort -u | head -n 4
  elif command -v pacman >/dev/null 2>&1; then
    if [[ -f /etc/pacman.d/mirrorlist ]]; then
      arch=$(uname -m)
      u=$(grep -m1 '^Server[[:space:]]*=' /etc/pacman.d/mirrorlist | cut -d= -f2- | sed 's/[[:space:]]*$//') || u=""
      u=${u//\$repo/core}
      u=${u//\$arch/$arch}
      [[ -n $u ]] && printf '%s\n' "$u"
    fi
  elif command -v dnf >/dev/null 2>&1; then
    u=$(grep -hE '^[[:space:]]*baseurl[[:space:]]*=' /etc/yum.repos.d/*.repo 2> /dev/null | head -n 1 | cut -d= -f2- | sed 's/[[:space:]]*$//') || u=""
  fi
  return 0
}

# probe the box's repos and print the report lines; sets REPO_STATE
repo_liveness(){
  local u st online=0 offline=0 unreach=0 n=0
  REPO_STATE="unknown"
  echo "  package repos : (bounded read-only probe)"
  while IFS= read -r u; do
    [[ -n $u ]] || continue
    st=$(http_probe "$u")
    n=$((n+1))
    case $st in
      online)  online=$((online+1)) ;;
      offline) offline=$((offline+1)) ;;
      *)       unreach=$((unreach+1)) ;;
    esac
    echo "     $u -> $st"
  done < <(repo_urls)
  if [[ $n -eq 0 ]]; then
    echo "     (no repository URLs found to probe - check the box's repo config)"
  elif [[ $online -gt 0 ]]; then
    REPO_STATE="online"
    echo "     liveness  : ONLINE ($online/$n sources answering; $offline 404, $unreach unreachable) - the box can still be updated"
  elif [[ $offline -gt 0 ]]; then
    REPO_STATE="offline"
    echo "     liveness  : OFFLINE ($offline/$n sources 404 - EOL distro? the installed lists are frozen and nothing new can be installed)"
  else
    REPO_STATE="unreachable"
    echo "     liveness  : UNREACHABLE ($unreach/$n - network or DNS? treat the repo state as unknown)"
  fi
  return 0
}

# for one missing tool: a human word on whether the box's repo can supply it
req_installable(){   # tool -> single word
  local t=$1 pkg=$1 out
  case $t in
    pishrink.sh) echo "not a distro package - ships with the pisafe pair (setup mode provides it)"; return 0 ;;
    dd)          pkg=coreutils ;;
    xz)          if command -v apt-cache >/dev/null 2>&1; then pkg=xz-utils; fi ;;
  esac
  if command -v apt-cache >/dev/null 2>&1; then
    out=$(apt-cache policy "$pkg" 2> /dev/null | sed -n 's/^[[:space:]]*Candidate:[[:space:]]*//p' | head -n 1)
    if [[ -n $out && $out != "(none)" ]]; then
      echo "installable (apt lists: $out)"
    else
      echo "NOT obtainable - no such package in the box's apt lists"
    fi
    return 0
  fi
  if command -v pacman >/dev/null 2>&1; then
    if pacman -Si "$pkg" >/dev/null 2>&1; then
      echo "installable (pacman database)"
    else
      echo "NOT obtainable - no such package in the pacman database"
    fi
    return 0
  fi
  if command -v dnf >/dev/null 2>&1; then
    if dnf --cacheonly list --available "$pkg" 2> /dev/null | grep -qE "^$pkg([[:space:]]|\$)"; then
      echo "installable (dnf cached metadata)"
    else
      echo "NOT obtainable - no such package in the dnf metadata"
    fi
    return 0
  fi
  echo "unknown - no apt-cache/pacman/dnf on this box to ask"
  return 0
}

# present now vs installable (see req_installable); never fatal
check_requirements(){
  # (named req_tools - a bare 'tools' would collide with the setup-mode
  # string variable of the same name and trip shellcheck SC2128/SC2178)
  local req_tools=(dd pishrink.sh zip unzip pv whiptail file nano)
  local t w present=() missing=() n_inst=0 stale=""
  for t in "${req_tools[@]}"; do
    if command -v "$t" >/dev/null 2>&1; then
      present+=("$t")
    else
      missing+=("$t")
    fi
  done
  echo "  requirements  : pisafe's REQUIRED_TOOLS (pisafe:28)"
  if [[ ${#missing[@]} -eq 0 ]]; then
    echo "     all present (${#req_tools[@]}/${#req_tools[@]}): $(IFS=,; echo "${present[*]}")"
    return 0
  fi
  if [[ $REPO_STATE == offline ]]; then
    stale="  [caution: repo probe said OFFLINE - the lists are stale, installing may still fail]"
  elif [[ $REPO_STATE != online ]]; then
    stale="  [note: repo state $REPO_STATE - availability was read from this box's local lists only]"
  fi
  local plist=""
  [[ ${#present[@]} -gt 0 ]] && plist=": $(IFS=,; echo "${present[*]}")"
  echo "     present (${#present[@]}/${#req_tools[@]}):$plist"
  for t in "${missing[@]}"; do
    w=$(req_installable "$t")
    case $w in installable*) n_inst=$((n_inst+1)) ;; esac
    echo "     MISSING        $t -> $w$stale"
  done
  echo "     summary        : ${#missing[@]} missing, $n_inst installable via this box's repo"
  return 0
}

# the four compressors the backup step runs (zip, pigz, xz, zstd): installed
# now, or installable from this box's repo (same read-only list checks as
# check_requirements; xz -> xz-utils on apt). Never fatal: STD_FLAGS keeps
# --dependencies=on, so a missing one follows pisafe's own install path and
# the step record shows how that went.
compressor_check(){   # $1: "env" (env-mode / report block) or "banner" (confirm screen)
  local cmds=(zip pigz xz zstd)
  local t w present=() missing=() n_inst=0 stale="" sec det
  case ${1:-env} in
    banner) sec="   compressors   :" det="                   " ;;
    *)      sec="  compressors   :" det="     " ;;
  esac
  for t in "${cmds[@]}"; do
    if command -v "$t" >/dev/null 2>&1; then present+=("$t")
    else missing+=("$t")
    fi
  done
  if [[ ${#missing[@]} -eq 0 ]]; then
    echo "$sec all present (${#cmds[@]}/${#cmds[@]}): $(IFS=,; echo "${present[*]}")"
    return 0
  fi
  if [[ $REPO_STATE == offline ]]; then
    stale="  [caution: repo probe said OFFLINE - the lists are stale, installing may still fail]"
  elif [[ $REPO_STATE != online ]]; then
    stale="  [note: repo state ${REPO_STATE:-unknown} - availability was read from this box's local lists only]"
  fi
  local plist=""
  [[ ${#present[@]} -gt 0 ]] && plist=" ($(IFS=,; echo "${present[*]}"))"
  echo "$sec ${#present[@]}/${#cmds[@]} present$plist"
  for t in "${missing[@]}"; do
    w=$(req_installable "$t")
    case $w in installable*) n_inst=$((n_inst+1)) ;; esac
    echo "$det MISSING        $t -> $w$stale"
  done
  echo "$det summary        : ${#missing[@]} missing, $n_inst installable via this box's repo"
  echo "$det (the first step that needs one runs pisafe's own install path - the harness auto-answers that prompt)"
  return 0
}

native_surface(){
  # xte starts empty: on a box without x-terminal-emulator the var is never
  # assigned, and an unset local dies under set -u (log 10-23, Manjaro env)
  local tui inst t ed snd xte=""
  # a box with no whiptail passes the CLI battery yet cannot open a menu - the
  # single most important "does it actually work" fact to record per box
  if command -v whiptail >/dev/null 2>&1; then
    tui="whiptail"
  elif command -v newt >/dev/null 2>&1; then
    tui="MISSING - newt present, but the menus need the whiptail command"
  else
    tui="MISSING - no TUI found, menus cannot render"
  fi
  inst=$(chain_probe apt pacman dnf)
  t=$(chain_probe lxterminal xfce4-terminal mate-terminal gnome-terminal xterm terminator konsole qterminal x-terminal-emulator)
  ed=$(chain_probe leafpad xed gedit featherpad kwrite pluma kate mousepad geany gnome-text-editor nano)
  if command -v speaker-test >/dev/null 2>&1; then snd="speaker-test"
  else snd="absent (beeps are a no-op)"; fi
  # name the real terminal behind Debian's x-terminal-emulator symlink (pisafe:648)
  if command -v x-terminal-emulator >/dev/null 2>&1; then
    xte=$(readlink -f "$(command -v x-terminal-emulator)" 2>/dev/null)
    xte=${xte:-?}
  fi

  echo "  ---- native surface (measured before the battery) ----"
  echo "  TUI backend  : $tui"
  echo "  installer    : $inst"
  echo "  terminal     : $t"
  echo "  editor       : $ed"
  [[ -n $xte ]] && echo "  x-term-emul  : -> $xte"
  echo "  sound tool   : $snd"
  echo "  shell/user   : $(id -un 2>/dev/null || echo ?) (EUID $(id -u 2>/dev/null || echo ?))"
  repo_liveness
  check_requirements
  compressor_check env
  echo "  -------------------------------------------------------"
  return 0
}

# 'env' mode: the report header plus the native-surface snapshot, printed and
# done - no device, no battery, no installs, no prompts. Gives the box's
# environment block on demand (e.g. to record a box's environment row)
# without paying for the backup/restore run.
env_mode(){
  local pver os_stamp
  pver=$(grep -m1 '^[[:space:]]*SCRIPTVER=' "$PISAFE" 2>/dev/null | cut -d'"' -f2)
  # sourced inside $( ): /etc/os-release defines its own VERSION=, and the
  # subshell confines that assignment - the harness's own VERSION stays intact
  os_stamp=$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-} [ID=${ID:-?}]")
  echo "============================= ENV ====================================="
  echo "  machine  : $(hostname 2>/dev/null || uname -n 2>/dev/null || echo unknown)${os_stamp:+ - $os_stamp}"
  echo "  arch     : $(uname -m 2>/dev/null || echo unknown) (kernel $(uname -r 2>/dev/null || echo unknown))"
  echo "  date     : $(date '+%Y-%m-%d %H:%M:%S')"
  echo "  pisafe   : $PISAFE${pver:+ ($pver)}  [build: $(file_date "$PISAFE")]"
  echo "  harness  : v$VERSION  [build: $(file_date "${BASH_SOURCE[0]}")]"
  native_surface
  echo "========================================================================"
  return 0
}

# bookkeeping: one report row + tally
record(){   # label status duration detail
  local label=$1 status=$2 dur=${3:-0} detail=${4:-}
  if [[ $status == PASS ]]; then PASS_CNT=$((PASS_CNT+1)); else FAIL_CNT=$((FAIL_CNT+1)); fi
  REPORT+=("$(printf '%-22s %-5s %7ss  %s' "$label" "$status" "$dur" "$detail")")
}

# run one pisafe command, checking exit status + fresh log window
run_step(){   # label pisafe-args...
  local label=$1; shift
  local seed es dur reason="" win hit t0=$SECONDS
  local comp="" rawsize="" gzes="" imgnote=""   # size notes, backup steps only
  seed=$(log_seed)
  # feed the child ONE 'y' on stdin. The battery passes -y, which pisafe
  # honors on every prompt EXCEPT one: the "Install dependencies?" prompt
  # (pisafe:363) reads a key from stdin - only the 'install -y' subcommand
  # auto-approves it. So the harness supplies that key: the install is
  # allowed to happen, pisafe's own installer does all the work, and its
  # outcome (success or failure) lands in this step's record. If no prompt
  # fires, the 'y' is simply unread; and any UNEXPECTED later prompt gets
  # EOF (answered 'n', fails closed) instead of hanging the battery.
  if [[ -x $PISAFE ]]; then
    printf 'y' | "$PISAFE" "$@"
  else
    printf 'y' | bash "$PISAFE" "$@"
  fi
  es=$?
  dur=$(( SECONDS - t0 ))
  win=$(log_window "$seed")

  if (( es != 0 )); then reason="exit status $es"; fi
  if ! grep -qF -- "$SUCCESS_MARKER" <<<"$win"; then
    [[ -n $reason ]] && reason+=", "
    reason+="missing log marker '$SUCCESS_MARKER'"
  fi
  # NB: test grep's own exit status. `grep ... | head -1` would make the
  # condition depend on head (always exit 0), failing *every* step with an
  # empty "log says: ". -m1 stops grep at the first match; no pipe, no SIGPIPE.
  if hit=$(grep -Eim 1 -- "$FAIL_RE" <<<"$win") && [[ -n $hit ]]; then
    [[ -n $reason ]] && reason+=", "
    reason+="log says: $hit"
  fi

  # record the produced backup image's size in the report line, so a report is
  # self-contained and the size no longer has to be noted by hand. For gz the
  # raw (post-shrink) size is the number the guard gates on (must stay
  # <3.9 GiB) - it now sits right in the report next to the compressed size.
  # The erase/restore windows have none of these lines, so this is a no-op
  # for those steps.
  comp=$(sed -nE   's/.*reduced to ([0-9.]+[a-z]+b).*/\1/p'            <<<"$win" | head -n1)
  rawsize=$(sed -nE 's/.*bytes \(([0-9.]+[a-z]+b)\).*/\1/p'             <<<"$win" | head -n1)
  gzes=$(sed -nE   's/.*gz image is *~?([0-9.]+[a-z]+b) raw.*/\1/p'    <<<"$win" | head -n1)

  if [[ -z $reason ]]; then
    ok "$label"
    [[ -n $comp ]] && imgnote="image $comp"
    [[ -n $comp && -n $rawsize ]] && imgnote="image $comp (raw $rawsize)"
    record "$label" PASS "$dur" "$imgnote"
  else
    [[ -n $gzes ]] && { [[ -n $reason ]] && reason+=", "; reason+="gz image raw ~$gzes (guard: >~3.9 GiB)"; }
    bad "$label - $reason"
    echo "  | ---- log window (seed line $seed, $(wc -l <<<"$win") lines) ----"
    sed 's/^/  | /' <<<"$win"
    record "$label" FAIL "$dur" "$reason"
  fi
  return 0
}

# run a byte-level verification function, record the outcome
run_verify(){   # label verify-fn verify-args...
  local label=$1; shift
  local out
  if out=$("$@" 2>&1); then
    ok "$label"
    record "$label" PASS 0
  else
    bad "$label - ${out:-no detail}"
    record "$label" FAIL 0 "${out:-no detail}"
  fi
  return 0
}

# -------------------------------------------------------- prompts & naming --

# Confirmation prompt; returns 0 for "yes". If YES (-y/--yes) is set the
# answer is implied without asking. Never asks (and defaults to no).
ask_yes(){   # question-text
  if [[ -n $YES ]]; then
    echo "  auto-yes (-y): $*"
    return 0
  fi
  local ans=""
  printf '%s (y/N) ' "$*"
  IFS= read -r ans || return 1
  [[ $ans =~ ^[Yy] ]]
}

# The full path pisafe will actually write for a given compression extension.
# Pisafe inserts '.img' into any output name that lacks one (pisafe:1428-1434)
# and its file_base cuts the basename at the FIRST dot (pisafe:883-894) - so
# with BASE=/cwd/test and ext=zip it writes /cwd/test.img.zip, NOT
# /cwd/test.zip. Every file reference in this harness must go through here.
img_path(){   # EXT
  local ext=$1 dir base
  if [[ $BASE == *".img"* || $BASE == *".iso"* ]]; then
    echo "$BASE.$ext"
    return 0
  fi
  dir=$(dirname -- "$BASE"); base=$(basename -- "$BASE")
  base=${base%%.*}
  echo "$dir/$base.img.$ext"
}

# The raw image pisafe also refuses to overwrite if present (pisafe:1455-1458):
# file_base(OUTFILE) + '.img' - the same name minus the compression extension.
raw_img(){
  local p=$(img_path zip)
  echo "${p%.zip}"
}

# ------------------------------------------------------------- verification --

# (re)decompress a backup into a raw image. reason on stdout, rc != 0 on error.
decompress(){   # ext backup-file raw-out
  local ext=$1 file=$2 out=$3
  case $ext in
    zip) unzip -p "$file" > "$out" || return 1 ;;
    gz)  { command -v pigz >/dev/null && pigz -dc "$file" || gzip -dc "$file"; } > "$out" || return 1 ;;
    xz)  xz -dc "$file" > "$out" || return 1 ;;
    zst) zstd -dc "$file" > "$out" || return 1 ;;
    *)   echo "unknown backup type '$ext'"; return 9 ;;
  esac
  return 0
}

# the decompressed backup must equal the raw reference image
check_backup(){   # ext backup-file
  local ext=$1 file=$2
  local img="$TMPD/verify_$ext.img" size
  if [[ ! -f $file ]]; then echo "image '$file' does not exist"; return 1; fi
  if ! decompress "$ext" "$file" "$TMPD/_decompress_$ext"; then
    echo "decompressing '$file' failed"; return 1
  fi
  mv -f "$TMPD/_decompress_$ext" "$img"
  size=$(stat -c%s "$img")
  if ! cmp -s "$img" <(head -c "$size" "$REFERENCE"); then
    echo "backup content differs from reference image"; return 1
  fi
  return 0
}

# erased card: first 1 MiB must differ from the reference, and the FS must be vfat
check_erase(){
  local ref1="$TMPD/erase_ref_1mb" card1="$TMPD/erase_card_1mb" ftype
  head -c 1048576 "$REFERENCE" > "$ref1" 2>/dev/null || { echo "cannot read reference"; return 1; }
  if ! $SUDO head -c 1048576 "$DEVICE" > "$card1" 2>/dev/null; then
    echo "cannot read the first 1 MiB of $DEVICE"; return 1
  fi
  if cmp -s "$ref1" "$card1"; then
    echo "card looks unchanged after format (first 1 MiB identical to before)"; return 1
  fi
  ftype=$($SUDO blkid -o value -s TYPE "$DEVICE" 2>/dev/null)
  if [[ -n $ftype && $ftype != vfat ]]; then
    echo "blkid reports filesystem '$ftype' on $DEVICE, expected vfat"; return 1
  fi
  return 0
}

# restored card: first <image size> bytes must equal the reference image
check_restore(){   # ext backup-file
  local ext=$1 file=$2
  local img="$TMPD/verify_$ext.img" raw="$TMPD/readback_$ext" size
  if [[ ! -f $img ]]; then
    if ! decompress "$ext" "$file" "$img"; then
      echo "decompressing '$file' failed"; return 1
    fi
  fi
  size=$(stat -c%s "$img")
  if ! $SUDO head -c "$size" "$DEVICE" > "$raw" 2>/dev/null; then
    echo "cannot read back $size bytes from $DEVICE"; return 1
  fi
  if ! cmp -s "$raw" "$img"; then
    echo "restored card differs from the backup image"; return 1
  fi
  return 0
}

# -------------------------------------------------------------- gate & start --

# Print the mount point of every filesystem mounted from $DEVICE or any
# partition of it (one per line; nothing if none). Matches by resolved
# source path so symlinks (/dev/disk/...) and partitions are both handled.
mounted_targets(){
  local devres mp src sr
  devres=$(readlink -f "$DEVICE" 2>/dev/null || echo "$DEVICE")
  while IFS= read -r mp src; do
    [[ -z $src ]] && continue
    sr=$(readlink -f "$src" 2>/dev/null || echo "$src")
    if [[ $sr == "$devres" || $sr == "$devres"[0-9]* || $sr == "$devres"p[0-9]* ]]; then
      echo "$mp"
    fi
  done < <(findmnt -no TARGET SOURCE 2>/dev/null)
  return 0
}

# ------------------------------------------------------------------- compress --

# Validate the -c/--compress selection and rebuild EXTS in canonical order.
# No-op when the flag was not given (EXTS already holds all four arms).
# Unknown tokens and an empty selection are fatal (exit 2) BEFORE any
# preflight / state change, so a bad selection can never reach a step.
validate_compress(){
  (( HAVE_COMPRESS )) || return 0
  local toks=() selected t
  IFS=', ' read -r -a toks <<< "$COMPRESS"     # comma- or space-separated
  selected=" "
  for t in "${toks[@]}"; do
    t=${t//[[:space:]]/}               # trim: " zip , zst " == "zip,zst"
    [[ -z $t ]] && continue            # empty slot: "zip,,zst" is fine
    case $t in
      zip|gz|xz|zst) ;;
      *) DIE "unknown compression '$t' in --compress (valid: zip, gz, xz, zst)" ;;
    esac
    case $selected in
      *" $t "*) ;;                    # already picked (dedupe)
      *) selected+="$t " ;;
    esac
  done
  EXTS=()
  for t in zip gz xz zst; do           # rebuild in canonical order
    case $selected in
      *" $t "*) EXTS+=("$t") ;;
    esac
  done
  (( ${#EXTS[@]} > 0 )) || DIE "empty compress selection (valid: zip, gz, xz, zst)"
  return 0
}

# Validate -l/--level: ONE level, a plain number 1-19. Lists are refused
# and pointed at the bench; >19 is refused (the app clamps per compressor,
# xz/zip/gz max 9, but 19 is the biggest level any compressor can take).
validate_level(){
  (( HAVE_LEVEL )) || return 0
  if [[ $LEVEL == *,* || $LEVEL == *" "* ]]; then
    DIE "-l takes ONE level per battery run (e.g. -l=9) - a level matrix like 1 5 9 is the bench's job: pisafe_benchmark_test.sh DEVICE -l 1 5 9"
  fi
  [[ $LEVEL =~ ^[0-9]+$ ]] || DIE "level must be a plain number (1-19), got '$LEVEL'"
  LEVEL=$((10#$LEVEL))
  (( LEVEL >= 1 && LEVEL <= 19 )) || DIE "level out of range (1-19): $LEVEL"
  return 0
}

preflight(){
  local t mp mounts f e existing cardsize avail slots base_dir need

  [[ -f $PISAFE ]] || DIE "pisafe script not found at '$PISAFE' (set PISAFE=/full/path)"
  [[ -r $PISAFE ]] || DIE "pisafe script not readable: '$PISAFE'"

  [[ $DEVICE =~ ^/dev/[a-zA-Z0-9._-]+$ ]] || DIE "device '$DEVICE' does not look like a block device (expected /dev/xxx)"
  [[ -b $DEVICE ]]                        || DIE "device '$DEVICE' is not found or not a block device"

  # the mounted-disk guard below depends on findmnt; without it the guard
  # would silently pass (fail-open) - refuse instead (fail-closed)
  command -v findmnt >/dev/null 2>&1 || DIE "findmnt not found - cannot verify '$DEVICE' is unmounted"

  # if any filesystem on this device (or its partitions) is mounted, ask.
  # this catches the root disk no matter which partition the system is booted from.
  mounts=$(mounted_targets)
  if [[ -n $mounts ]]; then
    echo
    while IFS= read -r mp; do
      [[ -n $mp ]] && warn "'$mp' is mounted from '$DEVICE' (or a partition of it)"
    done <<<"$mounts"
    echo
    if ask_yes "Unmount and continue?"; then
      # $SUDO unquoted on purpose: expands to nothing when running as root
      while IFS= read -r mp; do
        [[ -z $mp ]] && continue
        $SUDO umount "$mp" 2>/dev/null || warn "umount failed for '$mp'"
      done <<<"$mounts"
      if mounts=$(mounted_targets) && [[ -n $mounts ]]; then
        DIE "'$DEVICE' is STILL mounted after the unmount attempt - refusing to test a mounted device"
      fi
      info "unmount verified: '$DEVICE' is no longer mounted"
    else
      DIE "refusing to test '$DEVICE' while any part of it is mounted"
    fi
  fi

  if [[ $EUID -ne 0 ]]; then
    command -v sudo >/dev/null 2>&1 || DIE "need sudo (or run this script as root)"
  fi

  # tooling for the selected arms + common steps. Missing tools are not
  # fatal: pisafe installs them itself on the first step (the dependency
  # check is ON in STD_FLAGS, and that is the product behavior under test);
  # the warn just surfaces it early
  local e need="dd md5sum"
  for e in "${EXTS[@]}"; do
    case $e in
      zip) need+=" zip unzip" ;;
      gz)  need+=" pigz" ;;
      xz)  need+=" xz" ;;
      zst) need+=" zstd" ;;
    esac
  done
  for t in $need; do
    command -v "$t" >/dev/null 2>&1 \
      || warn "tool '$t' not found in PATH - pisafe will install it during the first step (auto-approved); the step's record shows how that goes"
  done

  base_dir=$(dirname -- "$BASE")
  [[ -d $base_dir ]] || DIE "base directory '$base_dir' does not exist"
  [[ -w $base_dir ]] || DIE "base directory '$base_dir' is not writable"

  # pisafe refuses to write over image files that already exist
  # (rc 16: the compressed image it writes; rc 17: the raw .img derived
  # from the same name), so leftovers from a previous run must go first
  existing=""
  f=$(raw_img)
  [[ -f $f ]] && existing+="$f"$'\n'
  for e in "${EXTS[@]}"; do
    f=$(img_path "$e")
    [[ -f $f ]] && existing+="$f"$'\n'
  done
  existing=${existing%$'\n'}
  if [[ -n $existing ]]; then
    echo
    while IFS= read -r f; do
      [[ -n $f ]] && warn "image file already exists: '$f'"
    done <<<"$existing"
    echo
    if ask_yes "Delete the existing image files and continue?"; then
      while IFS= read -r f; do
        [[ -n $f ]] && rm -f -- "$f"
      done <<<"$existing"
      info "existing image files removed"
    else
      DIE "existing image files must be removed before re-running (or pass -y)"
    fi
  fi

  # free-space sanity: worst case ~1 image slot per selected compression, +1 reference, +1 scratch
  cardsize=$(stat -c%s "$DEVICE" 2>/dev/null || echo 0)
  avail=$(df -B1 --output=avail "$base_dir" 2>/dev/null | tail -1 | tr -dc '0-9')
  if (( cardsize > 0 && avail > 0 )); then
    slots=${#EXTS[@]}; (( FULL )) && slots=$((slots + 2))
    if (( avail < cardsize * slots )); then
      warn "free space in '$base_dir' ($avail B) may be tight: card is $cardsize B, planning for $slots image slot(s)"
    fi
    if (( avail < cardsize * 2 )); then
      DIE "not enough free space in '$base_dir' (have $avail B, need at least ~$(( cardsize * 2 )) B)"
    fi
  fi
}

confirm(){
  local desc e files n times
  if (( FULL )); then
    desc="std checks + byte-level verification (reference image)"
  else
    desc="exit status + log markers only (fast mode)"
  fi
  files=""
  for e in "${EXTS[@]}"; do
    files+=" $(img_path "$e")"
  done
  n=${#EXTS[@]}
  times=TIME; (( n > 1 )) && times=TIMES
  echo
  echo "=========================================================================="
  echo " PISAFE test harness v$VERSION - DESTRUCTIVE"
  echo "   target device : $DEVICE"
  echo "   compressions  : ${EXTS[*]}   ($n arm(s))"
  if (( HAVE_LEVEL )); then
    echo "   level         : --level=$LEVEL (backup step; the app clamps it per compressor)"
  fi
  compressor_check banner
  echo "   images        :$files"
  echo "   (the images are REMOVED after the run - the report and log are kept)"
  echo "   pisafe        : $PISAFE  [build: $(file_date "$PISAFE")]"
  echo "   harness build : $(file_date "${BASH_SOURCE[0]}")"
  echo "   log file      : $LOG_FILE"
  echo "   mode          : $desc"
  echo "   the card will be FORMATED $n $times (fat32) and restored $n $times"
  echo "   ALL CURRENT DATA ON $DEVICE WILL BE DESTROYED"
  echo "=========================================================================="
  if [[ -n $YES ]]; then
    echo "  -y set: confirmation skipped (all prompts auto-answered)"
  else
    echo
    echo "Press ENTER to start, or Ctrl-C to abort."
    read -r _ || { echo "FATAL: no confirmation input (stdin closed?)" >&2; exit 2; }
  fi
}

# ------------------------------------------------------------------ setup --

# 'bash pisafe_test.sh setup [DIR]': bootstrap a new test machine. Non-destructive:
# no device is ever touched. Creates DIR (default: ~/Downloads), shows a plan
# and waits for one ENTER to confirm (-y bypasses), then copies the latest
# pisafe plus a fresh pisafe_test.sh from GitHub ref SETUP_REF into it.
# The file running THIS command is never overwritten, because bash reads its
# script incrementally.
SETUP_BASE="https://raw.githubusercontent.com/RichardMidnight/pi-safe"
SETUP_REF="${PISAFE_REF:-dev}"

# The ONLY install setup may do on its own: a web-fetch tool, needed to
# download the pair. Every other runtime tool (pv, pishrink, xz, ...) is
# installed by pisafe's own installer - and the battery proving that works is
# the point (STD_FLAGS keeps the dependency check ON); setup must not
# pre-empt it.

# download URL to FILE with whichever of wget/curl exists (rc != 0 on failure)
setup_fetch(){   # URL FILE
  local url=$1 out=$2
  if command -v wget >/dev/null 2>&1; then
    wget --quiet --show-progress "$url" -O "$out"
  elif command -v curl >/dev/null 2>&1; then
    curl -fsSL --progress-bar "$url" -o "$out"
  else
    return 1
  fi
}

# a box with NO fetcher at all (no wget, no curl): install wget via apt.
# Runs ONLY after the confirm gate, and only in that one situation.
ensure_fetcher(){
  command -v apt-get >/dev/null 2>&1 \
    || DIE "no wget/curl here and no apt-get to install one - add a fetcher manually and re-run setup"
  $SUDO apt-get update -qq
  $SUDO apt-get install -y wget \
    || DIE "could not install 'wget' - run it manually ($SUDO apt-get install wget) and re-run setup"
}

setup_mode(){   # [DIR]
  local dest=${1:-$HOME/Downloads}
  local self out f tmp pver t fetch_need plan_a plan_b
  local tools="dd unzip zip pigz xz zstd pv findmnt"

  [[ $dest == /* ]] || dest="$PWD/$dest"
  mkdir -p -- "$dest" || DIE "cannot create '$dest'"
  [[ -d $dest && -w $dest ]] || DIE "directory '$dest' is not writable"
  dest=$(cd -P -- "$dest" && pwd)   # absolute, no trailing '/.' for clean output

  # the fully-resolved path of the file running this script (if resolvable)
  self=$(readlink -f -- "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")

  # ---- plan (described below, BEFORE anything happens) ----
  if [[ -f $dest/pisafe ]]; then
    plan_a="replace (existing file)"
  else
    plan_a="fetch (new)"
  fi
  if [[ -f $dest/pisafe_test.sh ]]; then
    if [[ $(readlink -f -- "$dest/pisafe_test.sh" 2>/dev/null) == "$self" ]]; then
      plan_b="keep (this is the running harness)"
    else
      plan_b="replace (existing file)"
    fi
  else
    plan_b="fetch (new)"
  fi
  fetch_need=0
  command -v wget >/dev/null 2>&1 || command -v curl >/dev/null 2>&1 || fetch_need=1

  echo
  echo "=========================================================================="
  echo " PISAFE_TEST setup (non-destructive - no device is ever touched)"
  echo "   this will:"
  echo "     1. create the directory : $dest"
  echo "     2. copy from GitHub into it:"
  echo "          pisafe          : $plan_a"
  echo "          pisafe_test.sh  : $plan_b"
  echo "          ref: $SETUP_REF @ $SETUP_BASE"
  if [[ $SETUP_REF == dev ]]; then
    echo "          'dev' is the LIVE beta branch - set PISAFE_REF to a tag to pin"
  fi
  echo "     3. leave you in that directory (see the cd line at the end)"
  if (( fetch_need )); then
    echo "     +  install 'wget' (web fetch tool - this box has no wget/curl)"
  fi
  echo "   runtime tools (pv, pishrink, ...) are NOT installed by setup:"
  echo "   pisafe's own installer does that, and the battery tests exactly that."
  echo "   this command only downloads - it does NOT run the test battery;"
  echo "   the battery (the NEXT command) is DESTRUCTIVE and formats the card."
  echo "=========================================================================="
  if [[ -n $YES ]]; then
    echo "  -y set: confirmation skipped (all prompts auto-answered)"
  else
    echo
    echo "Press ENTER to start, or Ctrl-C to abort."
    read -r _ || DIE "no confirmation input (stdin closed?) - setup did not run"
  fi

  # ---- execute ----
  if (( fetch_need )); then
    info "Installing web fetch tool 'wget' ..."
    ensure_fetcher
  fi
  # 'remote repo path : local file name' - the harness now lives in testing/
  # on GitHub, so its remote path is no longer the bare root file name
  for pair in "pisafe:pisafe" "testing/pisafe_test.sh:pisafe_test.sh"; do
    f=${pair%%:*}
    o=${pair##*:}
    out="$dest/$o"
    if [[ $o == pisafe_test.sh ]]; then
      # refuse to replace the very script that is executing right now
      if [[ -f $out && $(readlink -f -- "$out" 2>/dev/null) == "$self" ]]; then
        info "keeping the running harness: '$out'"
        continue
      fi
    fi
    info "Fetching ${f} (ref ${SETUP_REF}) ..."
    tmp="$dest/.$o.setup.tmp"
    if ! setup_fetch "$SETUP_BASE/${SETUP_REF}/${f}" "$tmp" || [[ ! -s $tmp ]]; then
      rm -f -- "$tmp"
      DIE "download of '${f}' failed (ref '${SETUP_REF}')"
    fi
    if ! bash -n "$tmp" 2>/dev/null; then
      rm -f -- "$tmp"
      DIE "downloaded '${f}' does not parse - bad download or unknown ref '${SETUP_REF}'"
    fi
    mv -f -- "$tmp" "$out"
    chmod +x -- "$out"
  done

  echo
  echo "============================= SETUP =================================="
  echo "  dir     : $dest"
  ls -l -- "$dest/pisafe" "$dest/pisafe_test.sh" 2>/dev/null | sed 's/^/  /'
  # 'pisafe -v' is the safe, non-interactive version probe (prints and exits)
  pver=$(bash "$dest/pisafe" -v 2>/dev/null | head -1)
  echo "  version : ${pver:-unknown}"
  echo "  tools   :  (informational only - not installed by setup)"
  for t in $tools; do
    if command -v "$t" >/dev/null 2>&1; then
      echo "            ok      ${t}"
    else
      echo "            missing ${t}   (fine - pisafe installs it on the first battery run)"
    fi
  done
  echo "========================================================================"
  echo
  # leave the session in the test folder (persists for sourced callers; a child
  # process cannot move its parent shell's CWD, hence the printed command too)
  cd -- "$dest" 2>/dev/null || :
  warn "test mode is DESTRUCTIVE - it formats the target card"
  echo "  when ready (paste as one line):"
  echo "    cd ${dest} && bash pisafe_test.sh /dev/sdX [--full]"
  echo
}

# --------------------------------------------------------------------- main --

main(){
  local POSITIONAL=() a ext F FILE R

  # 'setup' as first argument = non-destructive bootstrap mode:
  # setup [DIR] [-y]  (order-insensitive; anything else is an error)
  if [[ ${1:-} == setup ]]; then
    local sd=""
    for a in "${@:2}"; do
      case $a in
        -y|--yes) YES=1 ;;
        -*)       echo "error: unknown option '$a' after 'setup' (allowed: a DIR and -y)" >&2; exit 2 ;;
        "")       : ;;
        *)        [[ -n $sd ]] && { echo "error: 'setup' takes at most one DIR argument" >&2; exit 2; }; sd=$a ;;
      esac
    done
    setup_mode "$sd"
    exit 0
  fi

  # 'env' as first argument = environment-only mode: print the report header
  # and the native-surface snapshot, then exit - no device, no battery, no
  # installs, nothing read from stdin
  if [[ ${1:-} == env ]]; then
    if (( ${#@} != 1 )); then
      echo "error: 'env' takes no arguments" >&2
      exit 2
    fi
    env_mode
    exit 0
  fi

  while (( $# )); do
    case $1 in
      -h|--help)    usage; exit 0 ;;
      --full)       FULL=1; shift ;;
      -y|--yes)     YES=1; shift ;;
      -c|--compress)
        [[ -n ${2:-} ]] || { echo "${RED}missing value for -c (e.g. -c=zip,zst)${RST}" >&2; exit 2; }
        COMPRESS=$2; HAVE_COMPRESS=1; shift 2 ;;
      -c=*)         COMPRESS=${1#-c=}; HAVE_COMPRESS=1; shift ;;
      --compress=*) COMPRESS=${1#--compress=}; HAVE_COMPRESS=1; shift ;;
      -l|--level)
        [[ -n ${2:-} ]] || { echo "${RED}missing value for -l (e.g. -l=9)${RST}" >&2; exit 2; }
        LEVEL=$2; HAVE_LEVEL=1; shift 2 ;;
      -l=*)         LEVEL=${1#-l=}; HAVE_LEVEL=1; shift ;;
      --level=*)    LEVEL=${1#--level=}; HAVE_LEVEL=1; shift ;;
      -*)           echo "${RED}unknown option '$1' (try -h)${RST}" >&2; exit 2 ;;
      *)            POSITIONAL+=("$1"); shift ;;
    esac
  done

  if (( ${#POSITIONAL[@]} < 1 )); then
    usage
    echo >&2
    echo "${RED}error: DEVICE is required${RST}" >&2
    exit 2
  fi
  DEVICE=${POSITIONAL[0]}
  # hostname in the default BASE keeps per-machine runs from colliding on the
  # same image names when the pair is run from a shared directory
  BASE=${POSITIONAL[1]:-$(pwd)/test_$(hostname 2>/dev/null || uname -n 2>/dev/null || echo unknown)}
  if (( ${#POSITIONAL[@]} > 2 )); then
    echo "${RED}error: too many positional arguments (see -h)${RST}" >&2
    exit 2
  fi

  validate_compress
  validate_level

  preflight
  confirm

  # snapshot the box's native interactive surface NOW - before any battery step
  # can install tools - so the report records what the box actually ships
  SURFACE=$(native_surface)

  TMPD=$(mktemp -d "${TMPDIR:-/tmp}/pisafe_test.XXXXXX") || DIE "could not create temp dir"
  trap 'rm -rf "$TMPD"' EXIT

  if (( FULL )); then
    REFERENCE="$TMPD/reference.img"
    info "Creating reference image of $DEVICE (raw copy - may take a while)..."
    # $SUDO unquoted on purpose: expands to nothing when empty (root)
    $SUDO dd if="$DEVICE" of="$REFERENCE" bs=4M status=none \
      || DIE "could not create reference image from $DEVICE"
  else
    REFERENCE=""
  fi

  info "Phase 1/2: backups of $DEVICE (${EXTS[*]}) - card is not modified in this phase"
  for ext in "${EXTS[@]}"; do
    F=$(img_path "$ext")
    SUCCESS_MARKER='~ Backup complete.'
    if (( HAVE_LEVEL )); then
      run_step "backup [$ext]" backup "$DEVICE" "$F" -y --level="$LEVEL" "${STD_FLAGS[@]}"
    else
      run_step "backup [$ext]" backup "$DEVICE" "$F" -y "${STD_FLAGS[@]}"
    fi
    if (( FULL )); then
      run_verify "backup bytes [$ext]" check_backup "$ext" "$F"
    fi
  done

  info "Phase 2/2: per compression (${EXTS[*]}) - erase card, then restore that backup"
  for ext in "${EXTS[@]}"; do
    FILE=$(img_path "$ext")

    SUCCESS_MARKER='~ Format complete.'
    run_step "erase [$ext]" format "$DEVICE" fat32 -y "${STD_FLAGS[@]}"
    if (( FULL )); then
      run_verify "erase bytes [$ext]" check_erase
    fi

    if [[ ! -f $FILE ]]; then
      bad "restore [$ext] - image '$FILE' missing (its backup step failed)"
      record "restore [$ext]" FAIL 0 "image missing"
      if (( FULL )); then
        bad "restore bytes [$ext] - skipped (image missing)"
        record "restore bytes [$ext]" FAIL 0 "skipped, image missing"
      fi
      continue
    fi

    SUCCESS_MARKER='~ Restore complete.'
    run_step "restore [$ext]" restore "$FILE" "$DEVICE" -y "${STD_FLAGS[@]}"
    if (( FULL )); then
      run_verify "restore bytes [$ext]" check_restore "$ext" "$FILE"
    fi
  done

  # ---------------------------------------------------------- image cleanup --
  # The battery's images have served their purpose: every selected backup has
  # been restored and (in --full mode) checked. Remove the compressed images
  # and any raw .img a failed step left behind, so the next run does not trip
  # the "delete existing images" prompt. The report (pisafe_test-report.txt)
  # and the pisafe log remain as the record of what happened.
  info "Cleaning up: removing the test images..."
  for ext in "${EXTS[@]}"; do
    F=$(img_path "$ext")
    if [[ -f $F ]]; then rm -f -- "$F"; info "  removed '$F'"; fi
  done
  R=$(raw_img)
  if [[ -f $R ]]; then rm -f -- "$R"; info "  removed '$R'"; fi

  # ------------------------------------------------------------------ report --
  local pver os_stamp rep rf
  pver=$(grep -m1 '^[[:space:]]*SCRIPTVER=' "$PISAFE" 2>/dev/null | cut -d'"' -f2)
  # sourced inside $( ): /etc/os-release defines its own VERSION=, and the
  # subshell confines that assignment - the harness's own VERSION stays intact
  os_stamp=$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-} [ID=${ID:-?}]")
  rep=$(
    echo "============================= REPORT ================================="
    echo "  machine  : $(hostname 2>/dev/null || uname -n 2>/dev/null || echo unknown)${os_stamp:+ - $os_stamp}"
    # uname -m = userland architecture of the running pisafe (the 32/64-bit
    # answer); uname -r = kernel - together they split identical PRETTY_NAMEs
    # (e.g. 32-bit userland on an aarch64 kernel)
    echo "  arch     : $(uname -m 2>/dev/null || echo unknown) (kernel $(uname -r 2>/dev/null || echo unknown))"
    echo "  date     : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "  pisafe   : $PISAFE${pver:+ ($pver)}  [build: $(file_date "$PISAFE")]"
    echo "  harness  : v$VERSION  [build: $(file_date "${BASH_SOURCE[0]}")]"
    printf '%s\n' "$SURFACE"
    for a in "${REPORT[@]}"; do
      printf '  %s\n' "$a"
    done
    printf '  totals: %d passed, %d failed\n' "$PASS_CNT" "$FAIL_CNT"
    echo "========================================================================"
  )
  printf '%s\n' "$rep"
  # the report is saved in the directory the test was RUN FROM (the CWD),
  # same place the image files default to
  rf="$PWD/pisafe_test-report.txt"
  if printf '%s\n' "$rep" > "$rf" 2>/dev/null; then
    echo "  report saved: $rf"
  else
    warn "could not save report to '$rf' (directory not writable?)"
  fi
  if (( FAIL_CNT > 0 )); then
    bad "OVERALL: FAIL ($FAIL_CNT step(s) failed)"
    exit 1
  fi
  ok "OVERALL: PASS (all $PASS_CNT steps succeeded)"
  exit 0
}

main "$@"