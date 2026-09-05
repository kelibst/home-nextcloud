# Phone Link on Deepin

Connect the phone to this desktop the way Windows' Phone Link does — mirror the
screen, control it with the keyboard and mouse, share the clipboard, move files
— using only local, self-hosted pieces.

## What you get, and what provides it

| Phone Link feature | Here | Provided by |
| --- | --- | --- |
| Screen mirroring | ✅ | scrcpy |
| Keyboard/mouse control of the phone | ✅ | scrcpy |
| Two-way clipboard | ✅ | scrcpy (built in) |
| Reading/sending SMS | ✅ | through the mirrored screen |
| Photos and files | ✅ | Nextcloud, already in this repo |
| Calls from the desktop | ✅ | through the mirrored screen |
| Native desktop notification popups | ➖ | needs KDE Connect — see below |
| App launching as separate windows | ➖ | scrcpy `--new-display` (experimental) |

scrcpy covers everything that matters through one low-latency window. The only
real gap is *native* notification popups, since notifications on the mirrored
screen only appear while the window is open.

## Install

```bash
./setup-phone-link.sh
```

It installs scrcpy 4.1 from the upstream prebuilt release, pinned by version and
verified against upstream's published SHA-256. That binary is statically linked
against SDL and ffmpeg and needs only `libc`, `libudev` and `libcap`, so **it
pulls in no apt packages** and cannot disturb Deepin's own libraries.

Everything lands in `~/.local`, so the single sudo prompt is for one udev rule
that lets ADB reach the phone without root.

To reproduce on another machine, the script is the whole story — same pinned
version, same checksum, same result. Re-running it is safe; it reconciles each
step rather than redoing it.

### Enable USB debugging first

The script cannot do this part, and nothing works without it. On the phone:

1. **Settings → About phone → Software information**
2. Tap **Build number** seven times to unlock Developer options
3. **Settings → Developer options → USB debugging** → on
4. Replug the cable, then accept **Allow USB debugging?** — tick *Always allow
   from this computer*

Leave USB tethering on. Android runs tethering and debugging over the same
cable simultaneously, so enabling debugging will not cost you the internet
connection.

## Everyday use

```bash
./phone-link.sh status      # what is connected, and how
./phone-link.sh mirror      # mirror and control the phone
./phone-link.sh desk        # mirror with the phone's own screen off
./phone-link.sh shell       # a shell on the phone
```

There is also a **Phone Screen** entry in the application launcher.

Useful inside the mirror window:

| Shortcut | Action |
| --- | --- |
| `Ctrl`+`C` / `Ctrl`+`V` | clipboard, shared with the desktop |
| `Alt`+`f` (or `F11`) | fullscreen |
| `Alt`+`b`, or right-click | Back |
| `Alt`+`h`, or middle-click | Home |
| `Alt`+`s` | App switcher |
| `Alt`+`o` | turn the phone's screen off, keep mirroring |
| `Alt`+`Left` / `Alt`+`Right` | rotate the display |

`Alt` is the default modifier; `Super` works too.

Any extra arguments are passed to scrcpy, so `./phone-link.sh mirror --max-size 1024`
works when you want to spend less USB bandwidth.

## Getting off the tether

Worth understanding, because it shapes everything else.

This desktop has **no Wi-Fi hardware**, and `enp7s0` has no cable in it. The
only uplink is the phone itself in USB tethering mode:

```
enxee2c8b1a801e   10.153.121.93/24   →   gateway 10.153.121.33  (the phone)
```

Two consequences:

- Phone and desktop genuinely are on one subnet, so everything here works
  **today, over the cable**.
- Unplugging the phone takes the desktop offline — and the homelab with it.
  Nextcloud, the dashboards and Uptime Kuma all become unreachable.

`./phone-link.sh status` warns when it detects this.

To fix it properly, in rough order of preference:

1. **Run ethernet from the Starlink router to `enp7s0`.** Best option by far —
   the NAS stops depending on a phone, and gets a stable address for the
   trusted-domains config.
2. **A USB Wi-Fi adapter.** Pick one with an in-kernel driver (MediaTek
   `mt7921u` or Realtek `rtw88`-supported parts) so Deepin's kernel needs no
   out-of-tree module.

Until one of those is in place, wireless ADB cannot work — there is no shared
network to be wireless *on*.

### Wireless ADB, once you have a real network

```bash
./phone-link.sh wireless    # bootstrap over USB, then unplug
./phone-link.sh usb         # go back to the cable
```

`wireless` reads the phone's own Wi-Fi address, switches ADB to TCP mode and
reconnects over the network. It refuses to run and explains why if the phone
has no Wi-Fi address, which is exactly the situation on the tether today.

On networks that block plain TCP mode, use the Android 11+ pairing flow
instead — **Developer options → Wireless debugging → Pair device with pairing
code** — and feed the values to:

```bash
./phone-link.sh pair
```

Note that many routers isolate wireless clients from each other; if pairing
succeeds but connecting fails, look for "AP isolation" or "client isolation" in
the router settings.

## KDE Connect (optional)

KDE Connect is the usual answer for native notification mirroring, but on this
system it is a genuine build project rather than an install:

- It is **not packaged for Deepin 25** — the repos have only GSConnect, which is
  a GNOME Shell extension and will not run on DDE.
- It is **not on Flathub** either; the desktop side has never been published
  there.
- Deepin *does* ship KDE Frameworks 6.6 and Qt 6.8, but three required
  components are missing from the repos: **KContacts**, **KPeople** and
  **Kirigami Addons**.

So the only clean route is building four components from source against
Deepin's own KF6:

```bash
./setup-kdeconnect.sh
```

Budget ~1 GB of build dependencies and 20–45 minutes of compiling. Every URL,
checksum and package name in that script is verified against upstream, but the
compile has not been run end-to-end here — treat the first run as an
experiment. It installs only under `/usr/local`, so it backs out cleanly.

Given that scrcpy already covers mirroring, control, clipboard and SMS, and
Nextcloud already covers files, the honest gain is native notification popups.
Decide whether that is worth the build.

## Troubleshooting

**`no ADB device detected`** — USB debugging is still off, or the authorisation
prompt was dismissed. Walk back through *Enable USB debugging* above.

**`unauthorized`** — unlock the phone; the *Allow USB debugging?* dialog is
waiting on the phone's screen.

**Device disappears after replugging** — the udev rule did not reload. Run
`sudo udevadm control --reload-rules && sudo udevadm trigger`, or just re-run
`./setup-phone-link.sh`.

**Mirror is laggy or the internet slows while mirroring** — the video shares the
USB link with your tethered connection. Lower it:
`./phone-link.sh mirror --max-size 1024 --video-bit-rate 4M`.

**Black window, audio only** — some devices need a different encoder:
`./phone-link.sh mirror --video-codec=h265`.

**`adb` conflicts with another copy** — this repo's wrapper in `~/.local/bin`
shadows any system `adb`. Check with `which -a adb`; run `adb kill-server` if
two servers are fighting.

## Uninstalling

```bash
rm -rf ~/.local/opt/scrcpy-4.1 ~/.local/bin/scrcpy ~/.local/bin/adb
rm -f  ~/.local/share/applications/scrcpy.desktop
sudo rm -f /etc/udev/rules.d/51-android.rules && sudo udevadm control --reload-rules
```

If you also built KDE Connect:

```bash
sudo rm -f /etc/profile.d/kdeconnect-local.sh /etc/ld.so.conf.d/kdeconnect-local.conf
rm -f ~/.config/autostart/kdeconnectd.desktop
sudo ldconfig
rm -rf ~/.cache/kdeconnect-build
```

The installed files under `/usr/local` can be removed with
`sudo ninja -C ~/.cache/kdeconnect-build/<component>/build uninstall` before
deleting the build directory, if you want them gone precisely.
