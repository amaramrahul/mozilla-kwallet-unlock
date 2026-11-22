#!/bin/sh
# Install kwallet-unlock for Firefox or Thunderbird.
# Usage: sudo ./install.sh firefox|thunderbird [INSTALL_DIR]
set -eu
cd "$(dirname "$0")"
. ./common.sh

[ -x /usr/bin/busctl ] || fail "/usr/bin/busctl not found (it comes with systemd)."
[ -f "$CFG" ] && [ -f "$PREF" ] || fail "$CFG or $PREF missing next to this script."

echo "Install folder:     $APP_DIR"
echo "Preferences folder: $PREF_DIR"

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
if [ -n "$existing" ]; then
  echo "kwallet-unlock is already installed."
  [ -t 0 ] || fail "not running interactively; not overwriting."
  printf "Overwrite it? [y/N] "
  read -r answer
  case "$answer" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Cancelled. Nothing was changed."; exit 1 ;;
  esac
fi

install -m 644 "$CFG" "$APP_DIR/$CFG"
install -m 644 "$PREF" "$PREF_DIR/$PREF"

# Remove a copy left in another preferences folder by an older install.
for d in $ALL_PREF_DIRS; do
  [ "$d" = "$PREF_DIR" ] || ! is_our_pref "$d" || rm -fv "$d/$PREF"
done

echo "Installed:"
echo "  $APP_DIR/$CFG"
echo "  $PREF_DIR/$PREF"
echo "Restart $APP_NAME."
