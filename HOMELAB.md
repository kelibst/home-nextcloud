# Home NAS — Linux (DeepinOS) setup

Current, authoritative guide for this stack. `readme.md` predates this rebuild and
describes the older Windows/WSL2 deployment; treat this file as the source of truth.

## What runs

| Service | Port | Purpose |
| --- | --- | --- |
| Homepage | **7575** | Dashboard — service tiles, container status, disk/CPU/RAM |
| Nextcloud | 8090 | Files, mobile sync, photo backup |
| Uptime Kuma | 3001 | Health checks and alerting |
| Dozzle | 8082 | Live container logs |
| PostgreSQL | internal | Nextcloud database |
| Redis | internal | Nextcloud cache and file locking |
| docker-socket-proxy | internal | Read-only Docker API for the dashboards |

Postgres and Redis are deliberately not published to the host — only the four
web UIs are reachable from the LAN.

## Install

```bash
# 1. Make the 3TB drive mount permanently (one time, needs sudo)
sudo ./setup-permanent-mount.sh

# 2. Bring up the stack
./start-homelab.sh
```

`start-homelab.sh` is idempotent — re-run it any time. On the first run it
generates `.env` with random secrets and prints the Nextcloud admin password
**once**. `.env` is gitignored and holds the only copy, so save it.

## Storage layout — and why the data dir is not on the drive

The 3TB drive (`/dev/sda1`, label `DATA`) is **NTFS**, mounted through FUSE
(`ntfs-3g`). NTFS carries no POSIX ownership bits and has no working file
locking under FUSE. That rules out two things:

- **PostgreSQL** cannot run its data directory there at all — it depends on
  fsync semantics, hardlinks and permission bits that NTFS does not provide.
- **Nextcloud's primary data directory** on NTFS is an unsupported
  configuration. It produces permission errors, broken file locking, and
  failures during upgrades.

So the split is:

```
Docker named volumes (ext4, on /)     ->  postgres data, Nextcloud config,
                                          Nextcloud data dir, apps, themes
/media/Kelib/DATA/shared_drive (NTFS) ->  mounted into Nextcloud as
                                          External Storage "Shared Drive"
```

Your files still land on the 3TB drive, as plain browsable folders, and stay
readable from the desktop and over Samba. Only Nextcloud's internals live on
ext4. This is the same arrangement the previous deployment used.

### The mount itself

`setup-permanent-mount.sh` writes a UUID-based `/etc/fstab` entry:

```
UUID=01DC2091A0EF3410  /media/Kelib/DATA  ntfs-3g  uid=1000,gid=1000,umask=000,allow_other,nosuid,nodev,nofail,x-systemd.device-timeout=15  0  0
```

- `umask=000` — every file reads as `0777`. Since NTFS stores no ownership,
  this is how the container's `www-data` (uid 33) gets write access while your
  desktop user keeps it too.
- `allow_other` — without it only root can traverse the FUSE mount, and the
  Docker bind mount fails for `www-data`.
- `nofail` + `x-systemd.device-timeout=15` — a missing or slow disk will not
  hang boot.
- UUID-based — survives reboots, disk reordering and OS reinstalls. This is what
  fixed the old `DATA1`/`DATA2`/`DATA3` phantom-mount problem.

The script backs up `/etc/fstab` before touching it.

> **Performance note.** `ntfs-3g` is a single-threaded FUSE driver and is slow
> for bulk transfers. The in-kernel `ntfs3` driver is available on this system
> and is considerably faster — swap `ntfs-3g` for `ntfs3` in the fstab line to
> try it. If you ever have the chance to reformat the drive to ext4, do; that
> removes this whole class of constraint.

## Dashboard

Homepage is configured from YAML in [dashboard/homepage/](dashboard/homepage/),
so the layout is version-controlled rather than trapped in a database.

| File | Contents |
| --- | --- |
| [settings.yaml](dashboard/homepage/settings.yaml) | Theme, section layout |
| [services.yaml](dashboard/homepage/services.yaml) | Service tiles and their widgets |
| [widgets.yaml](dashboard/homepage/widgets.yaml) | Header widgets — CPU, RAM, drive space, clock |
| [docker.yaml](dashboard/homepage/docker.yaml) | Points at the socket proxy |
| [bookmarks.yaml](dashboard/homepage/bookmarks.yaml) | Reference links |

Edits are picked up live; no restart needed. `{{HOMEPAGE_VAR_*}}` placeholders
are filled from `.env` at container start, which is why no IP or port is
hardcoded in these files.

The Nextcloud tile shows free space, user count and pending background jobs.
It authenticates with a dedicated app password that `start-homelab.sh`
generates via `occ user:add-app-password` and appends to `.env` — the admin
password itself is never handed to the dashboard.

### Why a socket proxy

Bind-mounting `/var/run/docker.sock` into a container is equivalent to giving
that container root on the host. Homepage and Dozzle instead talk to
`docker-socket-proxy`, which exposes only the read endpoints they need
(`CONTAINERS`, `IMAGES`, `INFO`) with `POST=0` and `EXEC=0`. If either dashboard
is ever compromised, it cannot start, stop or exec into anything.

### Uptime Kuma

Create an admin account on first visit to `http://<lan-ip>:3001`. Suggested
monitors, using container names on the internal network:

| Monitor | Type | Target |
| --- | --- | --- |
| Nextcloud | HTTP(s) | `http://nextcloud-app:80/status.php` |
| Postgres | TCP Port | `nextcloud-db:5432` |
| Redis | TCP Port | `redis:6379` |
| Dashboard | HTTP(s) | `http://homepage:3000` |

## Networking

No host firewall is active on this machine — neither `ufw` nor `firewalld` is
installed or running — so the published ports are already reachable across the
LAN. `setup-firewall.sh` exists to define the rules if you ever enable `ufw`;
it scopes each port to the local subnet only.

Trusted domains and Homepage's allowed-hosts list are rewritten from the
detected LAN IP on every `start-homelab.sh` run, so a DHCP address change is
fixed by re-running the script. A DHCP reservation for this machine on the
router is worth setting up regardless — mobile clients store the server URL.

None of these services should be port-forwarded to the internet as-is. They
speak plain HTTP with no reverse proxy or TLS.

## Mobile setup

Server URL: `http://<lan-ip>:8090`, with the admin credentials from `.env` (or
a dedicated per-device user, which is better practice).

- **Android / iOS** — install the Nextcloud app, add the server URL, log in.
- **Photo backup** — Settings → Auto upload, pick the camera folder.
- Your 3TB drive appears in Files as **Shared Drive**.

## Phone Link — mirroring and controlling the phone

Separate from file sync: mirror the phone's screen and drive it with the
desktop keyboard and mouse, with a shared clipboard.

```bash
./setup-phone-link.sh       # one time — installs scrcpy, pinned and checksummed
./phone-link.sh mirror      # mirror and control
./phone-link.sh status      # what is connected, and how
```

Requires USB debugging on the phone. Full guide, including the wireless setup
and the optional KDE Connect build, is in [PHONE-LINK.md](PHONE-LINK.md).

> **Note on this machine's uplink.** There is no Wi-Fi hardware and no cable in
> `enp7s0`; the only connection is the phone's USB tethering, so unplugging the
> phone takes the whole homelab offline. `./phone-link.sh status` flags this.
> See *Getting off the tether* in [PHONE-LINK.md](PHONE-LINK.md).

## Desktop shortcuts

```bash
./install-desktop-shortcuts.sh    # re-run after moving the repo
```

Installs four launchers to the desktop **and** the application menu:

| Launcher | Runs | Window |
| --- | --- | --- |
| Start Home NAS | `start-homelab.sh` | terminal, stays open |
| Stop Home NAS | `stop-homelab.sh` | terminal, stays open |
| Home NAS Health Check | `health-check.sh --pause` | terminal, stays open |
| Home NAS Dashboard | opens `http://localhost:7575` | browser |

The `.desktop` files are generated, not committed, so `Exec=` always points at
wherever this repo actually lives. The three terminal launchers go through
`desktop-run.sh`, which holds the window open after the script exits —
`Terminal=true` otherwise closes it instantly and you never see the output.

If a launcher shows up as a plain text file, right-click it and choose *Allow
Launching* / *Trust this executable*; the installer sets `metadata::trusted`
but desktop environments vary.

The dashboard launcher deliberately uses `localhost` rather than the LAN IP —
see the tether note above, the LAN address moves.

## Health check

```bash
./health-check.sh
```

Exit code `0` healthy, `1` if anything failed. Warnings never fail the run —
they flag things that work now but will bite later. It covers:

- **Storage** — drive mounted, fstab entry present, mount options match fstab,
  free space (warn at 80%, fail at 90%)
- **Containers** — all eight present, running, and not `unhealthy`; flags any
  container that has restarted more than 3 times, which a plain status check
  hides
- **Endpoints** — HTTP status for all four web UIs
- **Nextcloud** — installed, not stuck in maintenance mode, no pending DB
  upgrade, external storage configured, background jobs recent
- **Write test** — actually writes a file to the shared drive *from inside the
  container*. If the drive is unmounted underneath a running container the bind
  mount goes stale and silently shows an empty directory rather than erroring,
  so nothing short of a real write catches it.
- **Network** — whether the current IP still matches `.env` and is a trusted
  domain

That last check matters on this machine: the uplink is USB tethering, so the
address changes whenever the phone reconnects, and Nextcloud starts answering
`HTTP 400` to every request. The fix is always `./start-homelab.sh`.

### Stopping safely

`stop-homelab.sh` puts Nextcloud into maintenance mode before `docker compose
down` so no write is interrupted mid-flight. That setting lives in `config.php`
and therefore survives the restart, so `start-homelab.sh` clears it immediately
after the container comes up — before any other `occ` call, since in
maintenance mode Nextcloud loads only AppAPI commands and everything else
silently does nothing.

## Everyday commands

```bash
./start-homelab.sh                       # start / reconcile everything
docker compose ps                        # what is running
docker compose logs -f nextcloud-app     # follow one service
docker compose down                      # stop (volumes are kept)
docker compose pull && docker compose up -d   # update images

# Nextcloud admin CLI
docker exec -u www-data nextcloud-app php occ status
docker exec -u www-data nextcloud-app php occ files:scan --all
docker exec -u www-data nextcloud-app php occ files_external:list
```

Run `occ files:scan --all` after adding files to `shared_drive` from outside
Nextcloud (desktop, Samba) so the index picks them up.

## Backups

The named volumes hold everything Nextcloud needs to be restored; the NTFS
drive holds your actual files.

```bash
# Database dump
docker exec nextcloud-db pg_dump -U nextcloud nextcloud \
  | gzip > backups/nextcloud-db-$(date +%F).sql.gz

# Config volume
docker run --rm -v home-nextcloud_nextcloud_config:/src -v "$PWD/backups":/dst \
  alpine tar czf /dst/nextcloud-config-$(date +%F).tar.gz -C /src .
```

Keep `.env` backed up somewhere safe too — without it the database password is
gone and the volumes are unreadable.

## Troubleshooting

**Drive missing after reboot** — `findmnt /media/Kelib/DATA`. If empty, the
fstab entry is absent or the disk moved; re-run `sudo ./setup-permanent-mount.sh`.

**"Access through untrusted domain"** — your LAN IP changed. Re-run
`./start-homelab.sh`.

**Dashboard shows "host not allowed"** — same cause; `HOMEPAGE_ALLOWED_HOSTS`
in `.env` is refreshed by the same script.

**Container tiles show no status** — check the proxy:
`docker compose logs dockerproxy`. A `403` there means the endpoint is blocked
by design; anything else means the socket mount failed.

**Permission denied writing to Shared Drive** — confirm the mount options
include `umask=000` and `allow_other`:
`findmnt -no OPTIONS /media/Kelib/DATA`.
