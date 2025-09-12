# Nextcloud Docker NAS Setup Project

## Project Overview
Set up a home NAS solution using Nextcloud in Docker containers to manage data and documents across multiple devices (Android and iPhone) using existing desktop hardware with 3TB storage space.

**Current Status**: Project is deployed and running. Nextcloud is accessible via Docker containers with PostgreSQL database backend. Network access has been configured for local and mobile device connectivity.

## System Environment
- **Operating Systems**: Windows and DeepinOS dual boot
- **Network**: Starlink internet connection
- **Storage**: ~3TB available space on current desktop
- **Target Devices**: Android phones, iPhones, desktop computers
- **Database**: PostgreSQL (preferred over MySQL/MariaDB)
- **Deployment**: Docker containers for portability

## Technical Requirements

### Core Components
- **Nextcloud**: Latest stable version via official Docker image
- **PostgreSQL**: Version 13+ for database backend
- **Docker & Docker Compose**: Container orchestration
- **Network Access**: Local network access with mobile device support

### Storage Configuration
- Map 3TB local storage to Nextcloud data directory
- Separate volumes for:
  - Nextcloud application data
  - PostgreSQL database
  - User files and documents
  - Configuration files

### Access Requirements
- Web interface accessible via local network
- Mobile apps connectivity (Android/iOS)
- File sharing and synchronization
- Photo backup from mobile devices

## Project Structure
```
nextcloud-nas/
├── docker-compose.yml
├── .env
├── data/
│   ├── nextcloud-config/
│   ├── nextcloud-data/
│   └── postgres-data/
└── backups/
```

## Docker Services Architecture

### Service 1: PostgreSQL Database (`nextcloud-db`)
- **Image**: postgres:13-alpine
- **Purpose**: Store Nextcloud metadata and user information
- **Persistent Volume**: `./data/postgres-data`
- **Environment**: Database credentials and configuration
- **Status**: Running and configured

### Service 2: Nextcloud Application (`nextcloud-app`)
- **Image**: nextcloud:latest
- **Purpose**: Main NAS application server
- **Ports**: 8080:80
- **Volumes**: `./data/nextcloud-config`, `./data/nextcloud-data`
- **Dependencies**: PostgreSQL database service
- **Status**: Running and accessible

### Service 3: Redis Cache (`redis`)
- **Image**: redis:alpine
- **Purpose**: Performance optimization for Nextcloud
- **Configuration**: Memory caching for better response times
- **Status**: Optional service available

## Configuration Priorities

### Security Considerations
- Strong database passwords
- Trusted domains configuration
- Local network firewall rules
- Secure file permissions

### Performance Optimization
- PHP memory limits and upload sizes
- PostgreSQL tuning for file operations
- Redis caching integration
- Efficient volume mounting

### Mobile Device Integration
- Automatic photo upload configuration
- File synchronization settings
- Mobile app connection parameters
- Network discovery setup

## Expected Deliverables

### Docker Configuration
- ✅ Complete docker-compose.yml with PostgreSQL
- ✅ Environment variables file (.env)
- ✅ Volume mapping for storage (`./data/` directory structure)
- ✅ Network configuration for local access

### Setup Documentation
- Step-by-step installation guide
- Mobile device configuration instructions
- Troubleshooting common issues
- Backup and maintenance procedures

### Testing Checklist
- [x] Docker containers start successfully
- [x] Web interface accessible locally (`http://localhost:8080`)
- [x] Database connection established (PostgreSQL)
- [x] Basic network configuration verified
- [x] Trusted domains configured for local and mobile access
- [ ] File upload/download functionality
- [ ] Android device connection and sync
- [ ] iPhone device connection and sync
- [ ] Photo backup from mobile devices
- [ ] Cross-device file sharing

## Specific Implementation Notes

### PostgreSQL Configuration
- Use PostgreSQL instead of MariaDB/MySQL
- Optimize for file metadata operations
- Configure appropriate connection limits
- Set up database initialization scripts

### Storage Path Mapping
- Map 3TB local storage to appropriate container paths
- Ensure proper permissions for Docker access
- Consider symbolic links if needed for storage location
- Plan for future storage expansion

### Network Configuration
- Configure for local network access (192.168.x.x)
- Set up port forwarding if external access needed
- Document firewall rules for Windows/Linux
- Plan for Starlink network considerations
- **Implementation Notes**:
  - Access configured via `http://localhost:8080`
  - Trusted domains configured in `config.php`
  - WSL networking considerations addressed
  - Windows Firewall rules created for external access
  - Mobile device access via Windows host IP address

### Mobile App Setup
- Document server URL format for local network
- Configure automatic photo upload settings
- Set up file synchronization preferences
- Test offline/online sync behavior

## Implementation Status & Next Steps

### Completed
- ✅ Docker containers deployed and running
- ✅ PostgreSQL database backend configured
- ✅ Local network access established
- ✅ WSL networking issues resolved
- ✅ Windows Firewall configuration for mobile access
- ✅ Trusted domains configuration completed

### Remaining Tasks
1. Complete file upload/download testing
2. Configure mobile device connectivity (Android/iPhone)
3. Set up automatic photo backup from mobile devices
4. Test cross-device file sharing functionality
5. Implement backup strategy for critical data
6. Document mobile app connection procedures

### Known Issues Resolved
- WSL networking problem with IP address access
- Trusted domains configuration for mobile device access
- Windows Firewall rules for external connectivity

## Success Criteria
- Nextcloud accessible via web browser on local network
- Mobile apps can connect and sync files
- Photo backup working automatically from phones
- File sharing between devices functional
- System stable and performant with 3TB storage
- Easy backup and maintenance procedures documented