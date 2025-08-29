# 🚀 Nexus Manager

A comprehensive bash script for managing Nexus node containers with Docker. This tool provides an intuitive interface for deploying, monitoring, and managing multiple Nexus node instances with performance optimization and advanced configuration options.

## ✨ Features

### 🎯 Core Features
- **Interactive Docker Image Building** - Build and manage Docker images for Nexus nodes
- **Multi-Instance Management** - Run multiple Nexus node containers simultaneously
- **High-Performance Optimization** - Automatically optimize resource allocation based on hardware
- **Environment Configuration** - Support for production, devnet, and custom environments
- **Real-time Log Monitoring** - Advanced log viewer with color-coded output
- **Backup & Restore** - Configuration and data backup/restore functionality
- **Health Monitoring** - Built-in health checks for all running containers

### ⚡ Performance Features
- **Auto Hardware Detection** - Automatically detects CPU cores and RAM for optimal resource allocation
- **Smart Container Distribution** - Distributes containers across available resources efficiently
- **Resource Limits** - Configurable memory and CPU limits per container
- **Auto Restart Policies** - Configurable restart behavior for containers

### 🛠️ Management Features
- **Node Control Center** - Start, stop, restart, and manage individual nodes
- **Batch Operations** - Perform operations on multiple nodes at once
- **Configuration Management** - Easy configuration file management
- **Log Analysis** - Search and analyze logs across all nodes
- **Instance Optimization** - Automatically create optimally configured instances

## 📋 Requirements

- **Operating System**: Linux, macOS, or Windows (WSL/Cygwin)
- **Docker**: Docker Engine (will be auto-installed if not present)
- **Bash**: Bash shell (version 4.0+ recommended)
- **System Resources**: 
  - Minimum: 4GB RAM, 2 CPU cores
  - Recommended: 8GB+ RAM, 4+ CPU cores for optimal performance

## 🚀 Quick Start

### 1. Download the Script

```bash
# Clone the repository
git clone https://github.com/ndahmpus/nexus-manager.git
cd nexus-manager
chmod +x nexus-manager.sh
```

### 2. Run the Manager

```bash
./nexus-manager.sh
```

The script will automatically:
- Install Docker if not present
- Create necessary directories
- Initialize configuration files
- Display the interactive dashboard

### 3. First-Time Setup

On first run, the script will guide you through:
1. Docker installation (if needed)
2. Initial configuration setup
3. Hardware optimization analysis
4. First node deployment

## 📖 Usage Guide

### Main Menu Options

1. **🏗️ Build Image (Interactive)** - Build Docker image with interactive prompts
2. **⚡ Build Latest Image** - Quick build with default settings
3. **📦 Manage Instances** - Create, start, stop, and manage node instances
4. **🎮 Node Control Center** - Advanced node management and optimization
5. **🌐 Environment & Config** - Configure environments and settings
6. **📜 View Logs** - Advanced log viewing and analysis
7. **💾 Backup & Restore** - Backup and restore configurations


### Configuration

Configuration is stored in `~/nexus-node/nexus.conf` with these key settings:

```bash
NEXUS_ENVIRONMENT="production"          # Environment mode
NEXUS_DEFAULT_WALLET="0x..."            # Default wallet address
NEXUS_MEMORY_LIMIT="4096m"              # Memory limit per container
NEXUS_CPU_LIMIT="4"                     # CPU cores per container
NEXUS_AUTO_RESTART="true"               # Auto-restart containers
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


## 🆘 Support

For support and questions:

- Create an issue on GitHub
- Check the [Troubleshooting](#-troubleshooting) section
- Review the logs using the built-in log viewer

## 🔄 Version History

- **v1.0.0** - Initial release with basic functionality
- **v1.1.0** - Added performance optimization features
- **v1.2.0** - Enhanced log viewing and analysis
- **v1.3.0** - Added backup/restore functionality



### Optimization Tips

1. **Use SSD storage** for better I/O performance
2. **Monitor resource usage** through the dashboard
3. **Adjust thread counts** based on your hardware
4. **Enable auto-restart** for production environments
5. **Regular backups** of configurations and data

---

**Made with ❤️ for the Nexus community**
