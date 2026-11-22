# mozilla-kwallet-unlock

Fill in the Firefox or Thunderbird **primary password** (formerly "master
password") from KDE Wallet, so you aren't asked for it while your wallet is
open.

## Overview

When Firefox or Thunderbird asks for its primary password (at startup, or when
you view or copy a saved password), this script reads the password from your
KDE Wallet, fills it in and accepts the prompt for you. You may see the prompt
flash briefly.

It steps back and leaves the prompt to you when:

- the wallet is locked (it never asks KWallet to unlock it),
- the KWallet entry is missing, or KWallet doesn't answer within 2 seconds,
- a prompt reappears within 5 seconds of a fill. The stored password was then
  probably wrong, so it stops filling until the application is restarted.

It is an [AutoConfig](https://support.mozilla.org/kb/customizing-firefox-using-autoconfig)
script: a file the application runs with full privileges at startup, before
any add-on can. It talks to KWallet over D-Bus using `busctl`.

## Requirements

- KDE Plasma 5 or 6 with KWallet, on a systemd-based Linux distribution.
- Firefox or Thunderbird installed from a distribution or Mozilla package
  (for example `/usr/lib/firefox`, `/usr/lib64/thunderbird`, `/opt/firefox`).
  Flatpak and Snap installs are not supported.
- No other AutoConfig file in use. Only one can be active per application.
- Root access to install.

## Installing

1. Store the primary password in your default wallet (normally `kdewallet`),
   in the **Passwords** folder, as `Firefox Primary Password` or
   `Thunderbird Primary Password`. Use KWalletManager, or:

   ```sh
   kwallet-query -f Passwords -w "Firefox Primary Password" kdewallet
   ```

2. Install for each application you use:

   ```sh
   sudo ./install.sh firefox
   sudo ./install.sh thunderbird
   ```

   The install folder is found automatically for common packages. If yours is
   elsewhere, pass the folder containing `application.ini`:
   `sudo ./install.sh firefox /path/to/firefox`.

3. Restart the application. The first time, KWallet may ask whether it may be
   accessed. Choose **Allow always** to avoid being asked again.

To remove it, run `sudo ./uninstall.sh firefox` (or `thunderbird`).

The install copies two files, `kwallet-unlock.cfg` into the install folder and
`kwallet-unlock-autoconfig.js` into its `defaults/pref` folder, after checking
that no other AutoConfig setup exists. On Debian-based systems it also checks
`/etc/<package>/pref`, which those builds read too, and removes a copy left
there by an older install. It asks before overwriting an existing install.

## Usage

Nothing to do: open the application with your wallet unlocked.

Messages starting with `kwallet-unlock:` appear in the Browser Console
(Firefox) or Error Console (Thunderbird), both opened with Ctrl+Shift+J.

| Message | Meaning |
|---|---|
| `filled primary password prompt from KWallet` | Working. |
| `wallet "…" is locked; leaving it to the prompt` | Unlock the wallet, or type the password. |
| `no entry "Passwords/…" in wallet "…"` | Create the entry, see Installing. |
| `prompt reappeared right after filling; …` | The stored password is wrong; update the KWallet entry. |

If `install.sh` reports *another AutoConfig setup already exists*, something
else (often an administrator's policy) already uses AutoConfig, and this script
can't be installed alongside it.

## Security and privacy

- **Your primary password moves into KWallet.** Anyone who can open your
  wallet, or who uses your session while it is open, can unlock your saved
  passwords. Lock your screen when you step away, and consider letting KWallet
  close when idle (System Settings → KWallet).
- **Re-authentication prompts are filled too.** The prompt Firefox shows before
  revealing or copying a saved password is filled automatically, so it no
  longer proves you are present.
- **Websites can't read the password.** The script runs in the application's
  privileged main process, separate from web content, and fills only the
  primary password prompt, which web pages can't create.
- **Normal add-ons can't read it either.** Privileged add-ons, such as
  Thunderbird Experiments, can do anything the application can, with or without
  this script. Install those only from people you trust.

## License

[MIT](LICENSE)
