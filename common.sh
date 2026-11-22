# Shared by install.sh and uninstall.sh. Not meant to be run directly.
#
# Sets APP (firefox|thunderbird), APP_NAME (Firefox|Thunderbird),
# APP_DIR (the install folder, containing application.ini),
# PREF_DIR (its defaults/pref folder, symlinks resolved; files are installed
# here) and ALL_PREF_DIRS (PREF_DIR plus Debian's /etc/<package>/pref if it
# exists, which Debian builds also read; checked for conflicts and for older
# kwallet-unlock installs).

CFG=kwallet-unlock.cfg
PREF=kwallet-unlock-autoconfig.js

fail() { echo "Error: $*" >&2; exit 1; }

usage() {
  echo "Usage: sudo $0 firefox|thunderbird [INSTALL_DIR]" >&2
  echo "INSTALL_DIR is the folder containing application.ini; it is found" >&2
  echo "automatically for common Linux packages." >&2
  exit 2
}

[ $# -ge 1 ] && [ $# -le 2 ] || usage
APP=$1
case "$APP" in
  firefox)     APP_NAME=Firefox
               CANDIDATES="/usr/lib/firefox /usr/lib64/firefox /usr/lib/firefox-esr /usr/lib64/firefox-esr /opt/firefox" ;;
  thunderbird) APP_NAME=Thunderbird
               CANDIDATES="/usr/lib/thunderbird /usr/lib64/thunderbird /opt/thunderbird" ;;
  *) usage ;;
esac

[ "$(id -u)" -eq 0 ] || fail "please run with sudo."

if [ $# -eq 2 ]; then
  APP_DIR=$2
  [ -f "$APP_DIR/application.ini" ] || fail "no application.ini in $APP_DIR."
else
  APP_DIR=""
  for d in $CANDIDATES; do
    if [ -f "$d/application.ini" ]; then APP_DIR=$d; break; fi
  done
  [ -n "$APP_DIR" ] || fail "$APP_NAME not found in: $CANDIDATES
Pass its install folder (the one containing application.ini) as a second
argument. Flatpak and Snap installs are not supported."
fi
APP_DIR=$(readlink -f "$APP_DIR")

[ -d "$APP_DIR/defaults/pref" ] || fail "$APP_DIR/defaults/pref does not exist."
PREF_DIR=$(readlink -f "$APP_DIR/defaults/pref")

ALL_PREF_DIRS=$PREF_DIR
ETC_PREF_DIR=/etc/$(basename "$APP_DIR")/pref
if [ -d "$ETC_PREF_DIR" ]; then
  ETC_PREF_DIR=$(readlink -f "$ETC_PREF_DIR")
  [ "$ETC_PREF_DIR" = "$PREF_DIR" ] || ALL_PREF_DIRS="$PREF_DIR $ETC_PREF_DIR"
fi

# Our pref file exists in $1 and really is ours.
is_our_pref() {
  [ -e "$1/$PREF" ] && grep -q '"kwallet-unlock.cfg"' "$1/$PREF"
}
