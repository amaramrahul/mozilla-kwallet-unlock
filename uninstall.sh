#!/bin/sh
# Remove kwallet-unlock from Firefox or Thunderbird.
# Usage: sudo ./uninstall.sh firefox|thunderbird [INSTALL_DIR]
set -eu
cd "$(dirname "$0")"
. ./common.sh

found=""
[ -e "$APP_DIR/$CFG" ] && found=yes
for d in $ALL_PREF_DIRS; do
  [ -e "$d/$PREF" ] || continue
  found=yes
  # Only remove the pref file if it is ours (points at kwallet-unlock.cfg).
  is_our_pref "$d" || fail "$d/$PREF does not look like a kwallet-unlock file; not removing it."
done
if [ -z "$found" ]; then
  echo "kwallet-unlock is not installed for $APP_NAME. Nothing to do."
  exit 0
fi

# Pref files first, so the application never points at a missing script.
for d in $ALL_PREF_DIRS; do rm -fv "$d/$PREF"; done
rm -fv "$APP_DIR/$CFG"
echo "Removed. Restart $APP_NAME."
