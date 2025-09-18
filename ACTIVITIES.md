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
