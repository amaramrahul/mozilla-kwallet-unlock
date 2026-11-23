#!/bin/sh
# Install or remove kwallet-unlock for Firefox or Thunderbird.
set -eu

CFG=kwallet-unlock.cfg
PREF=kwallet-unlock-autoconfig.js
SRC_DIR=$(dirname "$0")

die() { echo "Error: $*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: sudo $0 [OPTIONS] firefox|thunderbird [APP_DIR]

Install kwallet-unlock, which fills the primary password from KWallet.
APP_DIR is the folder containing application.ini; it is found automatically
for common Linux packages.

Options:
  -u, --uninstall  remove kwallet-unlock instead of installing it
  -n, --dry-run    show what would be done without changing anything
  -y, --yes        overwrite an existing install without asking
  -h, --help       show this help

Environment:
  DESTDIR          install under this root (for packaging); root is not needed
EOF
}

MODE=install
DRY=""
YES=""
while [ $# -gt 0 ]; do
  case "$1" in
    -u|--uninstall) MODE=uninstall ;;
    -n|--dry-run)   DRY=yes ;;
    -y|--yes)       YES=yes ;;
    -h|--help)      usage; exit 0 ;;
    --)             shift; break ;;
    -*)             usage >&2; exit 2 ;;
    *)              break ;;
  esac
  shift
done
[ $# -ge 1 ] && [ $# -le 2 ] || { usage >&2; exit 2; }

APP=$1
case "$APP" in
  firefox)     APP_NAME=Firefox
               CANDIDATES="/usr/lib/firefox /usr/lib64/firefox /usr/lib/firefox-esr /usr/lib64/firefox-esr /opt/firefox" ;;
  thunderbird) APP_NAME=Thunderbird
               CANDIDATES="/usr/lib/thunderbird /usr/lib64/thunderbird /opt/thunderbird" ;;
  *) usage >&2; exit 2 ;;
esac

# All paths below are real on-disk paths, including DESTDIR if one is set.
ROOT=${DESTDIR:-}
ROOT=${ROOT%/}
if [ -z "$ROOT" ] && [ -z "$DRY" ]; then
  [ "$(id -u)" -eq 0 ] || die "please run with sudo."
fi

run() {
  if [ -n "$DRY" ]; then echo "would run: $*"; else "$@"; fi
}

# Our pref file exists in $1 and really is ours.
is_our_pref() {
  [ -e "$1/$PREF" ] && grep -q '"kwallet-unlock.cfg"' "$1/$PREF"
}

if [ $# -eq 2 ]; then
  APP_DIR=$ROOT$2
  [ -n "$ROOT" ] || [ -f "$APP_DIR/application.ini" ] || die "no application.ini in $APP_DIR."
else
  APP_DIR=""
  for d in $CANDIDATES; do
    if [ -f "$ROOT$d/application.ini" ]; then APP_DIR=$ROOT$d; break; fi
  done
  [ -n "$APP_DIR" ] || die "$APP_NAME not found in: $CANDIDATES
Pass its install folder (the one containing application.ini) as a second
argument. Flatpak and Snap installs are not supported."
fi
APP_DIR=$(readlink -m "$APP_DIR")

# Preferences folder (symlinks resolved), plus Debian's /etc/<package>/pref,
# which Debian builds also read. Checked for conflicts and older installs.
[ -n "$ROOT" ] || [ -d "$APP_DIR/defaults/pref" ] || die "$APP_DIR/defaults/pref does not exist."
PREF_DIR=$(readlink -m "$APP_DIR/defaults/pref")
ALL_PREF_DIRS=$PREF_DIR
ETC_PREF_DIR=$ROOT/etc/$(basename "$APP_DIR")/pref
if [ -d "$ETC_PREF_DIR" ]; then
  ETC_PREF_DIR=$(readlink -m "$ETC_PREF_DIR")
  [ "$ETC_PREF_DIR" = "$PREF_DIR" ] || ALL_PREF_DIRS="$PREF_DIR $ETC_PREF_DIR"
fi

echo "Install folder:     $APP_DIR"
echo "Preferences folder: $PREF_DIR"

# ---------------------------------------------------------------- uninstall
if [ "$MODE" = uninstall ]; then
  found=""
  [ -e "$APP_DIR/$CFG" ] && found=yes
  for d in $ALL_PREF_DIRS; do
    [ -e "$d/$PREF" ] || continue
    found=yes
    is_our_pref "$d" || die "$d/$PREF does not look like a kwallet-unlock file; not removing it."
  done
  if [ -z "$found" ]; then
    echo "kwallet-unlock is not installed for $APP_NAME. Nothing to do."
    exit 0
  fi
  # Pref files first, so the application never points at a missing script.
  for d in $ALL_PREF_DIRS; do run rm -fv "$d/$PREF"; done
  run rm -fv "$APP_DIR/$CFG"
  [ -z "$DRY" ] || { echo "Dry run: nothing was changed."; exit 0; }
  echo "Removed. Restart $APP_NAME."
  exit 0
fi

# ------------------------------------------------------------------ install
[ -f "$SRC_DIR/$CFG" ] && [ -f "$SRC_DIR/$PREF" ] || die "$CFG or $PREF missing next to this script."

if ! command -v busctl >/dev/null 2>&1; then
  [ -n "$ROOT" ] || die "busctl not found (it comes with systemd)."
  echo "Warning: busctl not found on this system (it comes with systemd)." >&2
fi

# Only one AutoConfig file can be active; refuse to override another.
other=$(for d in $ALL_PREF_DIRS; do
          grep -ls 'general\.config\.filename' "$d"/*.js 2>/dev/null || true
        done | while read -r f; do
            real=$(readlink -f "$f")
            [ "$(basename "$real")" = "$PREF" ] && is_our_pref "$(dirname "$real")" || echo "$real"
          done | sort -u)
if [ -n "$other" ]; then
  echo "Error: another AutoConfig setup already exists:" >&2
  echo "$other" | sed 's/^/  /' >&2
  echo "Only one AutoConfig file can be active, so nothing was installed." >&2
  exit 1
fi

# Existing kwallet-unlock installation?
existing=""
[ -e "$APP_DIR/$CFG" ] && existing=yes
for d in $ALL_PREF_DIRS; do [ -e "$d/$PREF" ] && existing=yes; done
if [ -n "$existing" ] && [ -z "$YES" ] && [ -z "$DRY" ]; then
  echo "kwallet-unlock is already installed."
  [ -t 0 ] || die "not running interactively; not overwriting (use --yes)."
  printf "Overwrite it? [y/N] "
  read -r answer
  case "$answer" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Cancelled. Nothing was changed."; exit 1 ;;
  esac
fi

run install -D -m 644 "$SRC_DIR/$CFG" "$APP_DIR/$CFG"
run install -D -m 644 "$SRC_DIR/$PREF" "$PREF_DIR/$PREF"

# Remove a copy left in another preferences folder by an older install.
for d in $ALL_PREF_DIRS; do
  [ "$d" = "$PREF_DIR" ] || ! is_our_pref "$d" || run rm -fv "$d/$PREF"
done

[ -z "$DRY" ] || { echo "Dry run: nothing was changed."; exit 0; }
echo "Installed:"
echo "  $APP_DIR/$CFG"
echo "  $PREF_DIR/$PREF"
echo "Restart $APP_NAME."
