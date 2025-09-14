# 🚀 Nexus Node Manager

Advanced bash script for managing multiple Nexus node containers with Docker. Features real-time dashboard, optimal production defaults, and comprehensive node management.

## ✨ Key Features

- **📊 Real-time Dashboard** - Live system monitoring with auto-refresh
- **🎯 Production Optimized** - AUTO difficulty, UNLIMITED tasks, headless mode default
- **⚡ Latest CLI Support** - Full compatibility with Nexus CLI v0.10.11 (latest)
- **🔥 Multi-Instance Management** - Run multiple nodes with optimal resource allocation
- **🎮 Smart Controls** - Start/stop/restart all nodes with one command
- **📜 Advanced Logging** - Real-time log monitoring with search capabilities
- **💾 Backup/Restore** - Complete configuration backup and restore
- **🚀 Docker Optimized** - Headless mode, unlimited memory, lightweight containers

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

  [1] 🏠️Build/Update Image             [2] 🔄 Update CLI
  [3] 📦 Manage Instances              [4] 🎮 Node Control
  [5] 🌐 Environment Config            [6] 📜 View Logs
  [7] 💿 Backup & Restore              [A] 🧹 Docker Cleanup
  [0] 🚪 Exit Program

ℹ️  Settings: Env: production | Memory: UNLIMITED | Difficulty: AUTO | Tasks: UNLIMITED
ℹ️  Mode: HEADLESS (Optimized) | Auto-refresh: ON (60s) | Running nodes: 10
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

## 📍 Requirements

- **Docker Desktop** (Windows/Mac) or Docker Engine (Linux)
- **Bash shell** (Git Bash, WSL, or native Linux/Mac terminal)
- **4GB+ RAM** recommended (8GB+ for multiple nodes)
- **Nexus CLI v0.10.11** (automatically downloaded)

## 🚀 Quick Start

```bash
# Download
git clone https://github.com/ndahmpus/nexus-manager.git
cd nexus-manager
chmod +x nexus-manager.sh

# Run (Linux/Mac)
./nexus-manager.sh

# Run (Windows - Git Bash/WSL/PowerShell)
bash ./nexus-manager.sh
```

## 🔄 Usage

1. **First Run**: Script auto-configures Docker and optimal production settings
2. **Dashboard**: Real-time monitoring with color-coded status and performance metrics
3. **Production Ready**: AUTO difficulty, UNLIMITED tasks, headless mode enabled
4. **Menu Options**: Build/manage instances, view logs, backup/restore, environment config
5. **Multi-Instance**: Automatically optimizes based on your CPU cores

## 🏁 Performance

### **🎯 Optimal Production Defaults:**
- **🚀 Headless Mode**: Always enabled for Docker optimization
- **🎯 AUTO Difficulty**: Server-optimized task assignment
- **📋 UNLIMITED Tasks**: Continuous operation, maximum earning
- **💧 Unlimited Memory**: Docker-optimized, prevents crashes
- **📊 Auto Threading**: CLI auto-detects optimal CPU usage

### **🔥 Multi-Instance Auto-Optimization:**
- **24+ cores**: 8 containers with optimal resource distribution
- **16+ cores**: 6 containers with performance tuning
- **8+ cores**: 4 containers with balanced allocation
- **4+ cores**: 2 containers with efficient resource usage

## 📁 Files

- Configuration: `~/nexus-node/nexus.conf`
- Logs: `~/nexus-node/logs/`
- Backups: `~/nexus-node/backups/`

## 🔧 Troubleshooting

**Docker issues:**
```bash
# Linux: Start Docker service
sudo systemctl start docker

# Add user to docker group
sudo usermod -aG docker $USER
```

**Windows Docker restart issues:** 
- Use Docker Management menu (option A)
- Fixed instant restart functionality

**Container issues:**
- Check wallet format: `0x` + 40 hex characters
- View logs via menu option 6
- Ensure Nexus CLI v0.10.11+ (auto-updated in containers)
- Use AUTO difficulty for optimal server assignment
- Keep UNLIMITED tasks for continuous earning

## 🔄 Updates

```bash
git pull origin main
./nexus-manager.sh
```

## 📝 **Changelog**

### **v2.1.0** (Latest - September 2025)
- 🎯 **Production Optimized Defaults**: AUTO difficulty, UNLIMITED tasks, headless mode
- ⚡ **Nexus CLI v0.10.11 Support**: Full compatibility with latest features
- 🚀 **Docker Optimization**: Unlimited memory, lightweight headless containers
- 📋 **Enhanced Environment Config**: New difficulty levels and task limits
- 🔧 **Deprecated Threading Handling**: CLI auto-detection with warning messages
- 💡 **Better UX**: GREEN highlighting for optimal settings, clear recommendations

### **v2.0.0** (Previous)
- ⚡ Fixed Windows Docker restart (no waiting times)
- 📊 Enhanced real-time dashboard with performance metrics
- 🔥 Better multi-instance management with resource optimization
- 🛠️ Improved error handling and stability
- 🎮 Advanced node control center with comprehensive options

### **v1.0.0** (Initial)
- 📊 Real-time dashboard with system monitoring
- 🔥 Multi-instance Docker management
- 📜 Advanced logging with search capabilities
- 💾 Backup and restore functionality

---
**Made for Nexus community** 🚀
