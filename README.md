# 🚀 Nexus Node Manager Dashboard

> **Version 2.0** - Enhanced Dashboard & Real-time Monitoring

A powerful bash script for managing Nexus node containers with Docker. Features a beautiful real-time dashboard, intelligent resource monitoring, and comprehensive node management capabilities.

## 🎆 What's New in v2.0

- **📊 Real-time Dashboard** - Live system monitoring with color-coded indicators
- **💾 Smart Resource Tracking** - Device RAM usage and total task completion monitoring  
- **⚡ Performance Indicators** - Color-coded system status with intelligent thresholds
- **🔥 Task Analytics** - Real-time tracking of completed tasks across all nodes
- **🎨 Enhanced UI** - Cleaner interface with better visual feedback
- **🚀 Optimized Performance** - Faster dashboard updates and improved Windows compatibility

## 📸 Dashboard Preview

```
╭─────────────────────────────────────────────────────────────────────────────╮
│                      ⚡ NEXUS NODE MANAGER DASHBOARD ⚡                     │
╰─────────────────────────────────────────────────────────────────────────────╯

   💻 System: 28 cores | 1/15GB RAM | 85 tasks

╭─────────────────────────────────────────────────────────────────────────────╮
│ CONTAINER         NODE ID      UPTIME     CPU%       RAM         TASKS      │
╰─────────────────────────────────────────────────────────────────────────────╯

 🟢 nexus-node-1    35939692     17m        0.00%      11.72MiB      61         
 🟢 nexus-node-10   34754081     17m        0.00%      1.891MiB      6          
 🟢 nexus-node-2    23034123     17m        0.00%      1.98MiB       2          
 🟢 nexus-node-3    19750626     17m        0.00%      1.809MiB      2          
 🟢 nexus-node-4    23280743     17m        0.00%      1.863MiB      0          
 🟢 nexus-node-5    25691477     17m        0.00%      1.859MiB      6          
 🟢 nexus-node-6    34751599     17m        0.00%      1.859MiB      4          
 🟢 nexus-node-7    34724476     17m        0.00%      1.824MiB      4          
 🟢 nexus-node-8    36090618     17m        0.00%      1.977MiB      1          
 🟢 nexus-node-9    35050761     18m        0.00%      1.875MiB      0          

 ☑️  10 Nexus node(s) running • 10 total

╭─────────────────────────────────────────────────────────────────────────────╮
│                              📋 MANAGEMENT MENU                             │
╰─────────────────────────────────────────────────────────────────────────────╯

  [1] 🏠️Build/Update Image            [2] 🔄 Update CLI
  [3] 📦 Manage Instances              [4] 🎮 Node Control
  [5] 🌐 Environment Config            [6] 📜 View Logs
  [7] 💿 Backup & Restore              [A] 🧹 Docker Cleanup
  [0] 🚪 Exit Program

ℹ️  Settings: Env: production | Memory: unlimited | Auto-Restart: false
ℹ️  Auto-refresh: ON (60s) | Running nodes: 10
```

### Dashboard Features:
- **System Monitoring**: CPU cores, RAM usage, and total completed tasks
- **Node Status**: Real-time view of all containers with status indicators
- **Resource Usage**: Live CPU%, memory usage, and task completion per node
- **Color-coded Status**: Green (running), Red (stopped), with performance indicators
- **Auto-refresh**: Configurable real-time updates

## ✨ Core Features

### 🎯 Management Features
- **Interactive Dashboard** - Real-time monitoring with beautiful UI
- **Multi-Instance Management** - Run multiple Nexus node containers simultaneously
- **High-Performance Optimization** - Automatically optimize resource allocation
- **Smart Task Tracking** - Monitor completed tasks across all nodes
- **Resource Monitoring** - Real-time system and container resource usage

- **Environment Configuration** - Support for production, devnet, and custom environments
- **Advanced Log Monitoring** - Color-coded log viewer with real-time updates
- **Backup & Restore** - Complete configuration and data backup/restore

### 📊 Dashboard Indicators

**System Information Bar:**
- **💻 CPU Cores** - Total available CPU cores
- **💾 RAM Usage** - Device memory usage (Used/Total)
- **🏆 Total Tasks** - Cumulative completed tasks (24h)

**Color Coding:**
- **🟢 Green**: Excellent performance (RAM <60%, Tasks >100)
- **🟡 Yellow**: Good performance (RAM 60-80%, Tasks 20-100)
- **🔴 Red**: Attention needed (RAM >80%, Tasks <20)
- **🟣 Purple**: Idle/No activity

### ⚡ Performance Features
- **Real-time Monitoring** - Live CPU, RAM, and task completion tracking
- **Auto Hardware Detection** - Optimal resource allocation based on system specs
- **Smart Resource Management** - Intelligent memory and CPU distribution
- **Performance Analytics** - Task completion tracking and performance insights

## 📋 Requirements

- **Operating System**: Linux, macOS, or Windows (WSL/Cygwin)
- **Docker**: Docker Engine (will be auto-installed if not present)
- **Bash**: Bash shell (version 4.0+ recommended)
- **System Resources**: 
  - Minimum: 4GB RAM, 2 CPU cores
  - Recommended: 8GB+ RAM, 4+ CPU cores for optimal performance
  - **Note**: Script defaults to unlimited memory usage - ensure adequate RAM

## 🚀 Quick Start

### 1. Download & Setup

```bash
# Clone the repository
git clone https://github.com/ndahmpus/nexus-manager.git
cd nexus-manager
chmod +x nexus-manager.sh
```

### 2. Launch Dashboard

**For Linux/macOS:**
```bash
./nexus-manager.sh
```

**For Windows (Git Bash/WSL):**
```bash
bash ./nexus-manager.sh
```

**For Windows (PowerShell):**
```powershell
# Install Git Bash or WSL first, then use:
bash .\nexus-manager.sh
```

### 📊 What Happens on Launch:

The enhanced dashboard will automatically:
- **📊 Display real-time system metrics** - CPU cores, device RAM, total tasks
- **🔧 Auto-configure optimal settings** - 4 threads per container, unlimited memory
- **🎨 Show color-coded status** - Green (healthy), Yellow (warning), Red (critical)
- **⚡ Enable auto-refresh** - Live updates every 60 seconds (configurable)
- **🛠️ Initialize Docker environment** - Auto-install Docker if needed
- **🚀 Hardware detection** - Optimize based on your system specs

### 3. First-Time Setup

On first run, the script will guide you through:
1. **Docker installation** (if needed) - Automatic detection and installation
2. **Initial configuration** - Optimized settings based on your hardware
3. **Hardware optimization** - CPU cores and RAM analysis
4. **First node deployment** - Guided setup with wallet configuration

## 🛠️ Platform-Specific Instructions

### 🐧 Windows Users

**Recommended Setup:**
1. Install [Git for Windows](https://git-scm.com/download/win) (includes Git Bash)
2. Or install [Windows Subsystem for Linux (WSL)](https://docs.microsoft.com/en-us/windows/wsl/install)
3. Open Git Bash or WSL terminal
4. Run the script using: `bash ./nexus-manager.sh`

**Alternative (PowerShell):**
```powershell
# Enable Windows Subsystem for Linux
wsl --install
# Then run in WSL environment
bash ./nexus-manager.sh
```

### 🐧 Linux Users

```bash
# Make executable and run
chmod +x nexus-manager.sh
./nexus-manager.sh
```

### 🍎 macOS Users

```bash
# Install Homebrew if needed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Make executable and run
chmod +x nexus-manager.sh
./nexus-manager.sh
```

## 🔄 Upgrading from v1.x

If you're upgrading from a previous version:

```bash
# Backup your current configuration
cp ~/nexus-node/nexus.conf ~/nexus-node/nexus.conf.backup

# Pull latest version
git pull origin main

# Run the updated script
./nexus-manager.sh
```

**New in v2.0:**
- 📊 Enhanced dashboard with real-time monitoring
- 💾 Smart resource tracking (system RAM + total tasks)
- 🎨 Improved visual indicators and color coding
- ⚡ Better Windows compatibility and performance
- 🚀 Faster dashboard refresh and updates

## 📖 Usage Guide

### Main Menu Options

1. **🏗️ Build Image (Interactive)** - Build Docker image with interactive prompts
2. **⚡ Build Latest Image** - Quick build with default settings
3. **📦 Manage Instances** - Create, start, stop, and manage node instances
4. **🎮 Node Control Center** - Advanced node management and optimization
5. **🌐 Environment & Config** - Configure environments and settings
6. **📜 View Logs** - Advanced log viewing and analysis
7. **💾 Backup & Restore** - Backup and restore configurations

### Performance Optimization

The script automatically optimizes based on your hardware:

- **24+ cores**: 8 containers, high-performance mode
- **16+ cores**: 6 containers, performance mode  
- **8+ cores**: 4 containers, standard mode
- **4+ cores**: 2 containers, basic mode

### Default Settings

The script is pre-configured with the following default settings for optimal performance:

```bash
# Resource Configuration
Memory Limit     : UNLIMITED        # No memory restrictions (empty string)
Default Threads  : 4                # Fixed at 4 threads per container
CPU Limit        : UNLIMITED        # No CPU core restrictions

# Container Configuration
Environment      : production       # Default environment mode
Auto Restart     : false            # Manual restart control
Memory Check     : false            # Disabled for unlimited memory
Default Wallet   : (empty)          # Must be configured by user
```

### Configuration File

All settings are stored in `~/nexus-node/nexus.conf`:

```bash
NEXUS_ENVIRONMENT="production"           # Environment mode
NEXUS_DEFAULT_THREADS="4"               # Default threads per container
NEXUS_DEFAULT_WALLET="0x..."            # Default wallet address
NEXUS_MEMORY_LIMIT=""                   # Memory limit (empty = unlimited)
NEXUS_CPU_LIMIT=""                      # CPU cores limit (empty = unlimited)
NEXUS_AUTO_RESTART="false"              # Auto-restart containers
NEXUS_CHECK_MEMORY="false"              # Memory checking enabled/disabled
```

## 🔧 Advanced Features

### Multi-Instance Deployment

Create multiple optimized instances:

```bash
# Run the script and select option 4 (Node Control Center)
# Then select "Auto-Generate Optimal Instances"
```

### Custom Environment Setup

For custom orchestrator URLs:

```bash
# Select option 5 (Environment & Config)
# Choose "Change Environment" -> "Custom"
# Set your custom orchestrator URL
```

### Log Analysis

Advanced log viewing features:
- Live log following with color-coded output
- Multi-node log tailing
- Log searching and filtering
- Activity summaries

## 📁 Directory Structure

```
~/nexus-node/
├── nexus.conf              # Main configuration file
├── build/                  # Docker build files
├── logs/                   # Container logs
├── config/                 # Node configurations
├── backups/                # Configuration backups
└── health/                 # Health check files
```

## 🔍 Troubleshooting

### Common Issues

**Docker not starting:**
```bash
# Check Docker service
sudo systemctl status docker
sudo systemctl start docker
```

**Permission errors:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER
# Then logout and login again
```

**Container startup failures:**
- Check available system resources
- Verify wallet address format (0x + 40 hex characters)
- Check Docker logs for specific error messages

### Log Analysis

Use the built-in log viewer to identify issues:
1. Select option 6 (View Logs)
2. Choose "Search Logs" to find specific errors
3. Look for color-coded entries (red = errors, green = success)

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### Development Guidelines

- Follow existing code style and conventions
- Add comments for complex functions
- Test on multiple environments (Linux, macOS, WSL)
- Update documentation for new features

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For support and questions:

- Create an issue on GitHub
- Check the [Troubleshooting](#-troubleshooting) section
- Review the logs using the built-in log viewer

## 🔄 Version History

- **v2.0.0** - 🎆 **Enhanced Dashboard & Real-time Monitoring**
  - Real-time system resource monitoring (CPU, RAM)
  - Total task completion tracking across all nodes
  - Color-coded performance indicators
  - Improved Windows compatibility
  - Cleaner UI with better visual feedback
  - Optimized dashboard refresh performance
- **v1.0.0** - Added backup/restore functionality and node management
- **v0.9.0** - Enhanced log viewing and analysis features
- **v0.8.0** - Performance optimization and multi-instance support
- **v0.7.0** - Initial release with basic Docker container management


### Optimization Tips

1. **Monitor resource usage** through the dashboard
2. **Adjust thread counts** based on your hardware
3. **Enable auto-restart** for production environments
4. **Regular backups** of configurations and data

---

**Made with ❤️ for the Nexus community**
