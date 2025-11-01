# Nextcloud Home NAS Activities Log

This file tracks major features and changes implemented in the Nextcloud Home NAS project.

## 2025-10-28

### Updated Documentation for External Storage
**Time:** Evening
**Description:** Comprehensively updated project documentation to include troubleshooting steps for external storage mount errors.

**Changes Made:**
1. **docs/STORAGE.md**:
   - Added dedicated section for "External mount error" message
   - Enhanced troubleshooting steps with detailed diagnostic commands
   - Added explanation of the root cause (www-data permissions)
   - Included permanent fix solution using `user: "33:33"` in docker-compose.yml

2. **docs/TROUBLESHOOTING.md**:
   - Expanded "External Storage Not Showing" section into "External Storage Mount Error"
   - Added root cause analysis
   - Included step-by-step diagnostic procedures
   - Added multiple solution paths (quick fix, alternative fixes, permanent fix)

3. **README.md**:
   - Added external mount error to Quick Fixes section
   - Included one-line fix command for easy reference

**Documentation Links:**
- [Storage Configuration Guide](../docs/STORAGE.md)
- [Troubleshooting Guide](../docs/TROUBLESHOOTING.md)
- [Main README](../README.md)

---

### Fixed External Storage Mount Error
**Time:** Evening
**Description:** Resolved "External mount error" for the external storage configuration in Nextcloud. The issue was caused by incorrect permissions on the mounted directory.

**Technical Details:**
- **Root Cause**: The `/mnt/external_storage` directory inside the container was owned by root (UID 0) with permissions `drwxr-xr-x` (755). The Nextcloud process runs as `www-data` (UID 33), which only had read/execute permissions but not write permissions.
- **Solution**: Changed ownership of `/mnt/external_storage` to `www-data:www-data` using `chown -R www-data:www-data /mnt/external_storage`
- **Verification**: Tested write permissions and verified external storage with `occ files_external:verify 1` - status returned "ok"

**Configuration Details:**
- Mount ID: 1
- Mount Point: `/Shared Drive`
- Storage Type: Local
- Host Path: `/media/Kelib/DATA` (mounted as `/mnt/external_storage` in container)
- Applicable Users: All

**Commands Used:**
```bash
# Check external storage configuration
docker exec -u www-data nextcloud-app php /var/www/html/occ files_external:list

# Fix permissions
docker exec nextcloud-app chown -R www-data:www-data /mnt/external_storage

# Verify the mount
docker exec -u www-data nextcloud-app php /var/www/html/occ files_external:verify 1
```
