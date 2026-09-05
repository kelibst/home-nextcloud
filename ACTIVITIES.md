# Activities

## Wednesday, September 10, 2025

- Troubleshooted issue with accessing the Nextcloud app via IP address.
- Verified that the Docker containers are running correctly.
- Checked the `trusted_domains` configuration in `config.php`.
- Confirmed that the app is accessible via `http://localhost:8080`.
- Identified the issue as a WSL networking problem.
- Recommended using `http://localhost:8080` for accessing the app.
- Assisted with configuring access from the Android client by:
    - Instructing the user to create a Windows Firewall rule.
    - Adding the Windows host IP address to the `trusted_domains` configuration.
    - Added the WSL vEthernet IP address to the `trusted_domains` configuration as an alternative.
    - Instructed the user to disable the Windows Firewall for the public profile for testing.
    - Recommended enabling the mirrored networking mode in WSL as a potential solution.

## Friday, September 12, 2025

- Created a `.gitignore` file and populated it with the right things to ignore.

## Wednesday, September 18, 2025

### Major Feature: Complete Shared Folder Mounting Solution
- **Problem Solved**: Eliminated persistent issues with shared folder mounting after Linux reboots
- **Root Cause**: udisks2 auto-mounting creating random mount points (DATA1, DATA2, DATA3) instead of consistent paths
- **Solution Implemented**:
  - Created permanent UUID-based mounting in `/etc/fstab` for `/dev/sda1` → `/media/Kelib/DATA`
  - Disabled udisks2 auto-mounting via rules to prevent phantom mount clones
  - Set up Samba network sharing for cross-platform access (Windows, Android, iPhone)
  - Updated Nextcloud `.env` configuration to use clean `/media/Kelib/DATA` path
  - Created automated setup scripts for easy deployment and future reinstalls

### Scripts Created:
- `setup-complete-solution.sh` - Master script for full deployment
- `cleanup-mounts.sh` - Removes phantom directories and old mounts
- `setup-permanent-mount.sh` - Configures `/etc/fstab` with UUID-based mounting
- `disable-auto-mount.sh` - Prevents udisks2 auto-mounting conflicts
- `setup-samba-share.sh` - Installs and configures network sharing

### Benefits Achieved:
- ✅ Consistent `/media/Kelib/DATA` mount point (no more DATA1, DATA2, DATA3 clones)
- ✅ Survives reboots and OS reinstalls (UUID-based mounting)
- ✅ Network accessible from all devices via Samba share
- ✅ Integrated with Nextcloud Docker containers
- ✅ Zero manual intervention required after setup

## Saturday, August 16, 2026

### Rebuild on the new OS, plus a monitoring dashboard

Reinstalled the homelab from scratch on the fresh DeepinOS install, using
`/media/Kelib/DATA/shared_drive` as the storage target, and added a dashboard
for tracking activity. Full documentation now lives in `HOMELAB.md`; `readme.md`
is retained but flagged as describing the old Windows/WSL2 deployment.

**Constraint discovered**: the 3TB drive is NTFS (`/dev/sda1`, fuseblk via
ntfs-3g), not ext4. NTFS has no POSIX ownership and no working file locking
under FUSE, which rules it out for both the PostgreSQL data directory and the
Nextcloud primary data directory. Kept Nextcloud internals on ext4 named
volumes and exposed the drive as Nextcloud External Storage instead — the same
arrangement the previous deployment used, now documented with the reasoning.

Also found the drive was being auto-mounted by udisks2 with no `/etc/fstab`
entry on the new OS, so the mount would not have survived a reboot.

**Stack** (`docker-compose.yml`, rewritten):
- Nextcloud `stable-apache` on **8090** + a dedicated cron container for
  background jobs (previously fell back to AJAX cron)
- PostgreSQL 16 and Redis, both unpublished — internal network only
- Homepage dashboard on **7575**
- Uptime Kuma on **3001**, Dozzle on **8082**
- `docker-socket-proxy` so the dashboards get read-only Docker access instead of
  a raw `docker.sock` bind mount, which would be host root

**Scripts**:
- `start-homelab.sh` — idempotent installer: detects the LAN IP, generates
  `.env` secrets, checks the mount and port conflicts, brings up the stack,
  configures external storage, and mints a Nextcloud app password for the
  dashboard widget so the admin password is never given to Homepage
- `setup-permanent-mount.sh` — rewritten for NTFS: UUID-based fstab entry with
  `umask=000,allow_other` so the container's `www-data` can write, plus
  `nofail` so a missing disk cannot hang boot
- `setup-firewall.sh` — LAN-scoped `ufw` rules; a no-op today since no host
  firewall is installed or running on this machine

**Secrets**: all passwords are now generated at install time into a gitignored
`.env`, replacing the hardcoded `nextcloudpassword` / `adminpassword` /
`redispassword` values that were committed in the old compose file.

**Gotcha worth remembering**: `NEXTCLOUD_TRUSTED_DOMAINS` is only honoured
during the *initial* install, so the container name `nextcloud-app` must be
added to `trusted_domains` via `occ` — otherwise Nextcloud answers the
dashboard's internal API calls with its "untrusted domain" HTML page instead of
JSON, and the widget silently shows nothing. `start-homelab.sh` now reapplies
trusted domains through `occ` on every run, which also makes a DHCP address
change recoverable by just re-running the script.

**Verified end to end**: Nextcloud 34.0.3 installed; all four web UIs
responding; `www-data` can write to the NTFS drive through the bind mount;
`files:scan` indexed 2,575 files / 322 folders from `shared_drive` with 0
errors; Homepage reads container status and stats through the socket proxy and
pulls live server info from Nextcloud.

### Permanent mount, desktop shortcuts and health check

**Mount made permanent.** `setup-permanent-mount.sh` failed twice before
working. First failure: udisks2 deletes the mount directory it created when the
volume is unmounted, and the script only did `mkdir -p` *before* the unmount, so
`mount` hit ENOENT. Second failure, after adding a `mkdir` afterwards: udisks2
does that cleanup *asynchronously*, so it deleted the freshly recreated
directory in the gap before `mount` ran. Fixed by waiting for the cleanup to
land, then mounting through the systemd unit generated from the fstab entry
(`media-Kelib-DATA.mount`), which creates the mount point as part of mounting
and leaves no window to lose. Retries three times with `mkdir` + `mount` as a
non-systemd fallback. `findmnt --verify` confirms the fstab entry is valid.

**Added**:
- `stop-homelab.sh` — maintenance mode, then `docker compose down`; volumes kept
- `health-check.sh` — storage, containers, endpoints, Nextcloud state, network;
  exit 0/1, warnings do not fail
- `install-desktop-shortcuts.sh` — generates four launchers to the desktop and
  the app menu; generated rather than committed so `Exec=` follows the repo
- `desktop-run.sh` — keeps the terminal window open after a launcher finishes
- `open-dashboard.sh` — opens the dashboard via `localhost`

**Three bugs the work surfaced, all fixed**:
1. `start-homelab.sh` detected the LAN IP into a variable named `LAN_IP`, then
   sourced `.env` — which overwrote it with the *stored* address, so every
   rewrite wrote the stale value back. Renamed to `DETECTED_IP`.
2. Maintenance mode was cleared in the tuning step, which runs *after* external
   storage configuration. In maintenance mode Nextcloud loads only AppAPI
   commands, so those `occ` calls silently did nothing. Moved the clear to
   immediately after the install wait.
3. `.desktop` files used `Categories=System;Utility;`, which makes launchers
   appear twice in the menu. Now `System;` only.

**The health check earned its keep immediately** — on its first run it caught
that the USB-tethered IP had moved from `10.153.121.93` to `10.152.7.37`,
leaving Nextcloud and Homepage returning `HTTP 400` to everything. This will
recur every time the phone reconnects; the fix is always `./start-homelab.sh`.

**Known benign warning**: the health check reports the live mount options differ
from fstab (`user_id=0` vs `uid=1000`) because the current mount predates the
fstab entry. Permissions are `0777` either way and the container writes fine; a
reboot will remount from fstab.
