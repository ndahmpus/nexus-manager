#!/bin/bash
set -e

if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    BASE_DIR="$HOME/nexus-node"
else
    if [[ $EUID -eq 0 ]]; then
        BASE_DIR="/root/nexus-node"
    else
        BASE_DIR="$HOME/nexus-node"
    fi
fi
CONFIG_FILE="${BASE_DIR}/nexus.conf"

init_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "🔧 Configuration file not found. Creating new '$CONFIG_FILE'..."
        mkdir -p "$BASE_DIR"
        cat > "$CONFIG_FILE" <<'EOF'
BASE_DIR="$HOME/nexus-node"
NEXUS_IMAGE_NAME="nexus-node:latest"
NEXUS_ENVIRONMENT="production"
NEXUS_ORCHESTRATOR_URL=""
NEXUS_DEFAULT_THREADS="4"
NEXUS_CHECK_MEMORY="false"
NEXUS_DEFAULT_WALLET=""
NEXUS_MEMORY_LIMIT=""
NEXUS_CPU_LIMIT=""
NEXUS_AUTO_RESTART="false"
NEXUS_AUTO_REFRESH="true"
NEXUS_REFRESH_INTERVAL="180"
NEXUS_MAX_DIFFICULTY="AUTO"
NEXUS_MAX_TASKS="UNLIMITED"

EOF
    fi
    source "$CONFIG_FILE"
    
    # Ensure variables are properly set with defaults if empty
    export NEXUS_DEFAULT_THREADS="${NEXUS_DEFAULT_THREADS:-4}"
    export NEXUS_MEMORY_LIMIT="${NEXUS_MEMORY_LIMIT:-}"  # Empty = unlimited RAM
    export NEXUS_CPU_LIMIT="${NEXUS_CPU_LIMIT:-}"
    export NEXUS_AUTO_RESTART="${NEXUS_AUTO_RESTART:-false}"
    export NEXUS_AUTO_REFRESH="${NEXUS_AUTO_REFRESH:-true}"
    export NEXUS_REFRESH_INTERVAL="${NEXUS_REFRESH_INTERVAL:-180}"
    export NEXUS_MAX_DIFFICULTY="${NEXUS_MAX_DIFFICULTY:-AUTO}"  # AUTO = server decides
    export NEXUS_MAX_TASKS="${NEXUS_MAX_TASKS:-UNLIMITED}"      # UNLIMITED = no limit
}

# Create official nexus config for container
create_nexus_config() {
    local node_id="$1"
    local wallet_address="$2"
    local config_dir="$3"
    local environment="${4:-production}"
    
    mkdir -p "$config_dir/.nexus"
    
    # Generate UUID for user_id (simple approach)
    local user_id="managed-$(date +%s)-$(shuf -i 1000-9999 -n 1)"
    
    cat > "$config_dir/.nexus/config.json" <<JSON_EOF
{
  "user_id": "$user_id",
  "wallet_address": "$wallet_address",
  "node_id": "$node_id",
  "environment": "$environment"
}
JSON_EOF
    
    log_info "Created nexus config: node_id=$node_id, wallet=$wallet_address, env=$environment"
}

# Panggil inisialisasi konfigurasi di awal
init_config

readonly BASE_DIR="${BASE_DIR}"
readonly IMAGE_NAME="${NEXUS_IMAGE_NAME:-nexus-node:latest}"
readonly DEFAULT_THREADS="4"

readonly BUILD_DIR="$BASE_DIR/build"
readonly LOG_DIR="$BASE_DIR/logs"
readonly CONFIG_DIR="$BASE_DIR/config"
readonly BACKUP_DIR="$BASE_DIR/backups"
readonly HEALTH_CHECK_DIR="$BASE_DIR/health"
readonly PID_FILE="$BASE_DIR/nexus-manager.pid"

readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_PURPLE='\033[0;35m'
readonly COLOR_RESET='\033[0m'

log_info() { echo -e "${COLOR_CYAN} ℹ️  Info        >${COLOR_RESET} $1"; }
log_success() { echo -e "${COLOR_GREEN} ✔️  Success     >${COLOR_RESET} $1"; }
log_warn() { echo -e "${COLOR_YELLOW} ⚠️  Warning     >${COLOR_RESET} $1"; }
log_error() { >&2 echo -e "${COLOR_RED} ❌ Error       >${COLOR_RESET} $1"; }
prompt_user() { read -rp "$(echo -e "${COLOR_PURPLE} ❔ Question    >${COLOR_RESET} $1")" "$2"; }
prompt_confirm() {
    local prompt_message="$1"
    read -rp "$(echo -e "${COLOR_YELLOW} 🤔 Confirm     >${COLOR_RESET} ${prompt_message} [y/N] ")" choice
    [[ "$choice" =~ ^[yY]$ ]]
}

# ╭───────────────────────────────────────────────────────────────────╮
# │ 🛠️ FUNGSI INTI & PEMBANTU                                          │
# ╰───────────────────────────────────────────────────────────────────╯

# High-performance resource optimization
optimize_for_high_performance() {
    local total_cores
    total_cores=$(nproc 2>/dev/null || echo "4")
    
    log_info "Detected hardware: $total_cores CPU cores"
    
    # Calculate optimal container distribution
    local optimal_containers
    local cores_per_container
    
    if [[ $total_cores -ge 24 ]]; then
        # High-end hardware: maximize parallelization
        optimal_containers=8
        cores_per_container=$((total_cores / optimal_containers))
        log_info "High-performance mode: $optimal_containers containers, $cores_per_container cores each"
    elif [[ $total_cores -ge 16 ]]; then
        optimal_containers=6
        cores_per_container=$((total_cores / optimal_containers))
        log_info "Performance mode: $optimal_containers containers, $cores_per_container cores each"
    elif [[ $total_cores -ge 8 ]]; then
        optimal_containers=4
        cores_per_container=$((total_cores / optimal_containers))
        log_info "Standard mode: $optimal_containers containers, $cores_per_container cores each"
    else
        optimal_containers=2
        cores_per_container=$((total_cores / optimal_containers))
        log_info "Basic mode: $optimal_containers containers, $cores_per_container cores each"
    fi
    
    # Update config untuk resource optimization
    update_config_value "NEXUS_OPTIMAL_CONTAINERS" "$optimal_containers"
    update_config_value "NEXUS_CORES_PER_CONTAINER" "$cores_per_container"
    # Note: NEXUS_DEFAULT_THREADS kept for compatibility but CLI will auto-detect
    update_config_value "NEXUS_DEFAULT_THREADS" "4"
    
    # Memory optimization - Set unlimited by default
    log_info "Setting memory to unlimited for optimal performance"
    
    # Set memory limit to unlimited (empty string)
    update_config_value "NEXUS_MEMORY_LIMIT" ""
    update_config_value "NEXUS_CPU_LIMIT" "$cores_per_container"
    
    log_success "Performance optimization applied: $optimal_containers containers, auto-threading (CLI optimized), unlimited memory"
    
    # Reload config
    source "$CONFIG_FILE"
}

# Auto-generate multiple instances with optimal settings
auto_generate_optimal_instances() {
    local base_node_id="$1"
    local target_containers="${NEXUS_OPTIMAL_CONTAINERS:-4}"
    local wallet="${NEXUS_DEFAULT_WALLET:-}"
    
    if [[ -z "$wallet" ]]; then
        prompt_user "Enter wallet address for all instances: " wallet
        if [[ ! "$wallet" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
            log_error "Invalid wallet format"
            return 1
        fi
        update_config_value "NEXUS_DEFAULT_WALLET" "$wallet"
    fi
    
    log_info "Creating $target_containers optimized instances starting from Node ID $base_node_id"
    
    for i in $(seq 1 "$target_containers"); do
        local container_name="nexus-node-$i"
        local node_id=$((base_node_id + i - 1))
        
        log_info "Creating container $i/$target_containers: $container_name (Node ID: $node_id)"
        
        # Stop existing container if exists
        if docker inspect "$container_name" &>/dev/null; then
            log_warn "Stopping existing container $container_name"
            docker rm -f "$container_name" &>/dev/null || true
        fi
        
        # Start with optimized resources
        _run_node_container "$container_name" "$node_id" "${NEXUS_CORES_PER_CONTAINER:-$DEFAULT_THREADS}" "$wallet"
        
        # Brief pause to stagger startup
        sleep 2
    done
    
    log_success "Created $target_containers optimized instances"
}

init_dirs() {
    mkdir -p "$BUILD_DIR" "$LOG_DIR" "$CONFIG_DIR" "$BACKUP_DIR" "$HEALTH_CHECK_DIR"
    chmod 755 "$LOG_DIR" "$HEALTH_CHECK_DIR" 2>/dev/null || true
    # Tidak perlu sudo jika menggunakan home directory
    if [[ "$BASE_DIR" =~ ^/root/ ]] && [[ $EUID -ne 0 ]]; then
        log_warn "Running as non-root user but BASE_DIR points to /root. Using $HOME/nexus-node instead."
        BASE_DIR="$HOME/nexus-node"
        CONFIG_FILE="${BASE_DIR}/nexus.conf"
    fi
}


check_dependencies() {
    log_info "🔍 Checking system dependencies..."
    
    # Check jq - SIMPLIFIED
    if ! command -v jq &>/dev/null; then
        log_error "❌ jq is required but not installed"
        echo
        echo "Please install jq first:"
        if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
            echo "  sudo apt install jq"
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            echo "  brew install jq"
        elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
            echo "  Download from: https://jqlang.github.io/jq/download/"
        else
            echo "  sudo apt install jq  # Ubuntu/Debian"
            echo "  sudo yum install jq  # CentOS/RHEL"
        fi
        exit 1
    fi
    log_success "✅ jq is available"
    
    # Check Docker - SIMPLIFIED
    if ! command -v docker &>/dev/null; then
        log_error "❌ Docker is required but not installed"
        echo
        echo "Please install Docker first:"
        if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
            echo "  🔗 Install Docker Desktop: https://docs.docker.com/desktop/install/windows-install/"
            echo "  📋 Enable WSL 2 integration in Docker Desktop settings"
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            echo "  🔗 Download Docker Desktop: https://docs.docker.com/desktop/install/mac-install/"
        elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
            echo "  🔗 Download Docker Desktop: https://docs.docker.com/desktop/install/windows-install/"
        else
            echo "  🔗 Install script: curl -fsSL https://get.docker.com | sh"
        fi
        exit 1
    fi
    log_success "✅ Docker command is available"
    
    # Test Docker daemon - SIMPLIFIED
    if ! docker info &>/dev/null 2>&1; then
        log_error "❌ Docker is installed but not running"
        echo
        if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
            echo "WSL Users - Please:"
            echo "  1. Start Docker Desktop on Windows"
            echo "  2. Enable WSL 2 integration in Docker Desktop"
            echo "  3. Wait for Docker to fully start, then run this script again"
            echo
            echo "💡 Tips:"
            echo "  - Make sure 'Use WSL 2 based engine' is enabled"
            echo "  - Enable integration for your WSL distro: ${WSL_DISTRO_NAME:-current}"
        else
            echo "Please start Docker service:"
            echo "  Linux: sudo systemctl start docker"
            echo "  Windows/Mac: Start Docker Desktop"
        fi
        exit 1
    fi
    log_success "✅ Docker is running"
    
    log_success "🎉 All dependencies ready!"
}


prepare_build_files() {
    log_info "Mempersiapkan file build di $BUILD_DIR..."
    mkdir -p "$BUILD_DIR"

    # Modern lightweight build menggunakan official binary
    cat > "$BUILD_DIR/Dockerfile" <<'EOF'
FROM alpine:3.22.0

# Install dependencies
RUN apk update && apk add --no-cache curl ca-certificates jq

# Download nexus-cli binary directly based on architecture
RUN ARCH=$(uname -m) && \
    case "$ARCH" in \
        x86_64) NEXUS_URL="https://github.com/nexus-xyz/nexus-cli/releases/download/v0.10.11/nexus-network-linux-x86_64" ;; \
        aarch64|arm64) NEXUS_URL="https://github.com/nexus-xyz/nexus-cli/releases/download/v0.10.11/nexus-network-linux-arm64" ;; \
        *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac && \
    echo "Downloading from: $NEXUS_URL" && \
    curl -L -o /usr/local/bin/nexus-cli "$NEXUS_URL" && \
    chmod +x /usr/local/bin/nexus-cli && \
    # Create symlink for compatibility
    ln -s /usr/local/bin/nexus-cli /usr/local/bin/nexus-network && \
    # Verify installation
    /usr/local/bin/nexus-cli --version && \
    # Cleanup
    apk del curl && \
    rm -rf /var/cache/apk/*

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Health check untuk monitoring
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD nexus-cli --help > /dev/null 2>&1 || exit 1

ENTRYPOINT ["/entrypoint.sh"]
EOF

    cat > "$BUILD_DIR/entrypoint.sh" <<'EOF'
#!/bin/sh
set -e

# Handle help/version commands
if [ "$1" = "--version" ] || [ "$1" = "--help" ] || [ "$1" = "version" ] || [ "$1" = "help" ]; then
    exec nexus-cli "$@"
fi

# Validate required environment variables
if [ -z "$NODE_ID" ]; then
    echo "❌ Error: NODE_ID environment variable is required"
    exit 1
fi

if [ -z "$MAX_THREADS" ]; then
    echo "⚠️ Warning: MAX_THREADS not set, using auto-detection"
    MAX_THREADS=""
fi

# Setup directories
readonly DATA_DIR="/nexus-data"
readonly CONFIG_DIR="/nexus-config" 
readonly LOG_FILE="${DATA_DIR}/nexus-${NODE_ID}.log"

mkdir -p "$DATA_DIR" "$CONFIG_DIR"
touch "$LOG_FILE"

echo "🚀 Starting Nexus Node ${NODE_ID} (Optimized Headless Mode)"
echo "📊 Threads: AUTO-DETECTED by CLI (4 threads legacy kept)"
echo "📁 Data: ${DATA_DIR}"
echo "⚙️  Config: ${CONFIG_DIR}"
echo "📝 Log: ${LOG_FILE}"
echo "🎯 Difficulty: ${MAX_DIFFICULTY:-AUTO} (Server Optimized)"
echo "📋 Max Tasks: ${MAX_TASKS:-UNLIMITED} (No Limit)"
echo "💧 Memory: UNLIMITED (Docker Optimized)"
echo "🌐 Binary: $(nexus-cli --version 2>/dev/null || echo 'nexus-cli not found')"

# Build command arguments - Always use headless for Docker optimization
CMD_ARGS="start --headless"

if [ -n "$NODE_ID" ]; then
    CMD_ARGS="$CMD_ARGS --node-id $NODE_ID"
fi

# Note: max-threads is now DEPRECATED and will be ignored
# Nexus CLI will auto-detect optimal threading
if [ -n "$MAX_THREADS" ]; then
    echo "⚠️  Warning: --max-threads is deprecated and will be ignored by CLI"
fi

if [ -n "$ORCHESTRATOR_URL" ]; then
    CMD_ARGS="$CMD_ARGS --orchestrator-url $ORCHESTRATOR_URL"
fi

if [ "$CHECK_MEMORY" = "true" ]; then
    CMD_ARGS="$CMD_ARGS --check-memory"
fi

# Add max-difficulty if specified (skip if AUTO for server-side optimization)
if [ -n "$MAX_DIFFICULTY" ] && [ "$MAX_DIFFICULTY" != "AUTO" ]; then
    CMD_ARGS="$CMD_ARGS --max-difficulty $MAX_DIFFICULTY"
fi

# Add max-tasks if specified (skip if UNLIMITED for no limit)
if [ -n "$MAX_TASKS" ] && [ "$MAX_TASKS" != "UNLIMITED" ]; then
    CMD_ARGS="$CMD_ARGS --max-tasks $MAX_TASKS"
fi

# Create nexus config if wallet provided
if [ -n "$WALLET_ADDRESS" ]; then
    mkdir -p "$CONFIG_DIR/.nexus"
    cat > "$CONFIG_DIR/.nexus/config.json" <<JSON_EOF
{
  "user_id": "managed-user",
  "wallet_address": "$WALLET_ADDRESS",
  "node_id": "$NODE_ID",
  "environment": "${ENVIRONMENT:-production}"
}
JSON_EOF
    export HOME="$CONFIG_DIR"
fi

echo "🏁 Executing: nexus-cli $CMD_ARGS"

# Execute with logging
exec nexus-cli $CMD_ARGS 2>&1 | tee -a "$LOG_FILE"
EOF
    chmod +x "$BUILD_DIR/entrypoint.sh"
}

_build_image() {
    # Check Docker availability before building
    if ! command -v docker &>/dev/null; then
        log_error "Docker tidak ditemukan. Silakan install Docker terlebih dahulu."
        if prompt_confirm "Install Docker sekarang?"; then
            install_docker_ce
        else
            log_error "Docker dibutuhkan untuk build image."
            return 1
        fi
    elif ! docker info &>/dev/null 2>&1; then
        log_error "Docker terinstal tapi tidak berjalan. Silakan start Docker service."
        return 1
    fi
    
    local build_args=("$@")
    log_info "Memulai build image Docker: $IMAGE_NAME..."
    if ! docker build "${build_args[@]}" -t "$IMAGE_NAME" "$BUILD_DIR"; then
        log_error "Build image gagal. Periksa output di atas untuk detailnya."
        return 1
    fi
    log_success "Build image selesai."
    log_info "Memeriksa versi image..."
    docker run --rm "$IMAGE_NAME" --version
    return 0
}

build_image_interactive() {
    # Check Docker availability before checking existing images
    if ! command -v docker &>/dev/null; then
        log_error "Docker tidak ditemukan. Silakan install Docker terlebih dahulu."
        if prompt_confirm "Install Docker sekarang?"; then
            install_docker_ce
        else
            log_error "Docker dibutuhkan untuk build image."
            return 1
        fi
    elif ! docker info &>/dev/null 2>&1; then
        log_error "Docker terinstal tapi tidak berjalan. Silakan start Docker service."
        return 1
    fi
    
    if docker image inspect "$IMAGE_NAME" &>/dev/null; then
        ! prompt_confirm "Image '$IMAGE_NAME' sudah ada. Bangun ulang?" && return 1
    fi
    prepare_build_files
    _build_image --no-cache
}

build_image_latest() {
    prepare_build_files
    _build_image
}

_run_node_container() {
    local name="$1"
    local node_id="$2"
    local threads="$3"
    local wallet_address="${4:-}"

    log_info "Memulai kontainer '$name' dengan ID Node: $node_id..."
    mkdir -p "${CONFIG_DIR}/${node_id}"

    # Prepare environment variables
    local env_vars=()
    env_vars+=("-e" "NODE_ID=$node_id")
    env_vars+=("-e" "MAX_THREADS=$threads")
    env_vars+=("-e" "ENVIRONMENT=${NEXUS_ENVIRONMENT:-production}")
    
    if [[ "${NEXUS_CHECK_MEMORY:-false}" == "true" ]]; then
        env_vars+=("-e" "CHECK_MEMORY=true")
    fi
    
    if [[ -n "${NEXUS_ORCHESTRATOR_URL:-}" && "${NEXUS_ENVIRONMENT}" == "custom" ]]; then
        env_vars+=("-e" "ORCHESTRATOR_URL=${NEXUS_ORCHESTRATOR_URL}")
    fi
    
    # Use provided wallet or default
    local final_wallet="${wallet_address:-${NEXUS_DEFAULT_WALLET:-}}"
    if [[ -n "$final_wallet" ]]; then
        env_vars+=("-e" "WALLET_ADDRESS=$final_wallet")
    fi
    
    # Add max difficulty if set (always set with default AUTO)
    env_vars+=("-e" "MAX_DIFFICULTY=${NEXUS_MAX_DIFFICULTY:-AUTO}")
    
    # Add max tasks if set (always set with default UNLIMITED)
    env_vars+=("-e" "MAX_TASKS=${NEXUS_MAX_TASKS:-UNLIMITED}")

    # Resource limits - ensure clean values
    local resource_args=()
    
    # Clean and validate memory limit
    local clean_memory_limit="${NEXUS_MEMORY_LIMIT:-}"
    # Remove any unwanted strings like "unlimited"
    if [[ "$clean_memory_limit" == "unlimited" || "$clean_memory_limit" == "auto" || "$clean_memory_limit" == "none" ]]; then
        clean_memory_limit=""
    fi
    
    if [[ -n "$clean_memory_limit" ]]; then
        resource_args+=("--memory" "$clean_memory_limit")
        log_info "Applied memory limit: $clean_memory_limit"
    fi
    
    # Clean and validate CPU limit  
    local clean_cpu_limit="${NEXUS_CPU_LIMIT:-}"
    # Remove any unwanted strings
    if [[ "$clean_cpu_limit" == "unlimited" || "$clean_cpu_limit" == "auto" || "$clean_cpu_limit" == "none" ]]; then
        clean_cpu_limit=""
    fi
    
    if [[ -n "$clean_cpu_limit" ]]; then
        resource_args+=("--cpus" "$clean_cpu_limit")
        log_info "Applied CPU limit: $clean_cpu_limit"
    fi

    # Restart policy
    local restart_policy="no"
    if [[ "${NEXUS_AUTO_RESTART:-true}" == "true" ]]; then
        restart_policy="unless-stopped"
    fi

    # Create nexus config if wallet provided
    if [[ -n "$final_wallet" ]]; then
        create_nexus_config "$node_id" "$final_wallet" "${CONFIG_DIR}/${node_id}" "${NEXUS_ENVIRONMENT:-production}"
    fi

    log_info "Starting optimized container: wallet=${final_wallet:-none}, env=${NEXUS_ENVIRONMENT:-production}, difficulty=${NEXUS_MAX_DIFFICULTY:-AUTO}, tasks=${NEXUS_MAX_TASKS:-UNLIMITED}, memory=UNLIMITED, mode=HEADLESS"

    if ! docker run -dit \
        --name "$name" \
        --restart "$restart_policy" \
        "${env_vars[@]}" \
        "${resource_args[@]}" \
        -v "$LOG_DIR":/nexus-data \
        -v "${CONFIG_DIR}/${node_id}":/nexus-config \
        --health-cmd "nexus-cli --version >/dev/null 2>&1 || exit 1" \
        --health-interval=30s \
        --health-timeout=10s \
        --health-retries=3 \
        "$IMAGE_NAME"; then
        log_error "Gagal memulai kontainer $name."
        return 1
    fi
    
    log_success "Instance '$name' dimulai (Node: $node_id, Threads: $threads, Wallet: ${final_wallet:-none})."
    return 0
}

# ╭───────────────────────────────────────────────────────────────────╮
# │ 🌐 ENVIRONMENT & CONFIG MANAGEMENT                                │
# ╰───────────────────────────────────────────────────────────────────╯

# Update config file with new values
update_config_value() {
    local key="$1"
    local value="$2"
    
    if grep -q "^${key}=" "$CONFIG_FILE"; then
        sed -i "s/^${key}=.*/${key}=\"${value}\"/" "$CONFIG_FILE"
    else
        echo "${key}=\"${value}\"" >> "$CONFIG_FILE"
    fi
    
    log_info "Updated config: $key=$value"
}

environment_config_menu() {
    while true; do
        clear
        echo -e "${COLOR_CYAN}---[ 🌐 Environment & Configuration ]---${COLOR_RESET}"
        echo
        echo -e "  ${COLOR_YELLOW}CURRENT CONFIGURATION${COLOR_RESET}"
        echo -e "    Environment      : ${COLOR_GREEN}${NEXUS_ENVIRONMENT:-production}${COLOR_RESET}"
        echo -e "    Orchestrator URL : ${COLOR_GREEN}${NEXUS_ORCHESTRATOR_URL:-default}${COLOR_RESET}"
        echo -e "    Memory Limit     : ${COLOR_GREEN}${NEXUS_MEMORY_LIMIT:-UNLIMITED}${COLOR_RESET} (Optimal)"
        echo -e "    CPU Limit        : ${COLOR_GREEN}${NEXUS_CPU_LIMIT:-UNLIMITED}${COLOR_RESET}"
        echo -e "    Default Wallet   : ${COLOR_GREEN}${NEXUS_DEFAULT_WALLET:-none}${COLOR_RESET}"
        echo -e "    Max Difficulty   : ${COLOR_GREEN}${NEXUS_MAX_DIFFICULTY:-AUTO}${COLOR_RESET} (Server Optimized)"
        echo -e "    Max Tasks        : ${COLOR_GREEN}${NEXUS_MAX_TASKS:-UNLIMITED}${COLOR_RESET} (No Limit)"
        echo -e "    Check Memory     : ${COLOR_GREEN}${NEXUS_CHECK_MEMORY:-false}${COLOR_RESET}"
        echo -e "    Auto Restart     : ${COLOR_GREEN}${NEXUS_AUTO_RESTART:-false}${COLOR_RESET}"
        echo -e "    Auto Refresh     : ${COLOR_GREEN}${NEXUS_AUTO_REFRESH:-true}${COLOR_RESET}"
        echo -e "    Refresh Interval : ${COLOR_GREEN}${NEXUS_REFRESH_INTERVAL:-180}s${COLOR_RESET}"
        echo
        echo -e "  ${COLOR_CYAN}CONFIGURATION OPTIONS${COLOR_RESET}"
        echo -e "    ${COLOR_CYAN}1.${COLOR_RESET} 🌐 Change Environment (production/devnet/custom)"
        echo -e "    ${COLOR_CYAN}2.${COLOR_RESET} 🔗 Set Custom Orchestrator URL"
        echo -e "    ${COLOR_CYAN}3.${COLOR_RESET} 💾 Set Memory Limit per Container"
        echo -e "    ${COLOR_CYAN}4.${COLOR_RESET} ⚙️ Set CPU Limit per Container"
        echo -e "    ${COLOR_CYAN}5.${COLOR_RESET} 💰 Set Default Wallet Address"
        echo -e "    ${COLOR_CYAN}6.${COLOR_RESET} 🎯 Set Max Difficulty Level"
        echo -e "    ${COLOR_CYAN}7.${COLOR_RESET} 📋 Set Max Tasks Limit"
        echo -e "    ${COLOR_CYAN}8.${COLOR_RESET} 🧠 Toggle Memory Checking"
        echo -e "    ${COLOR_CYAN}9.${COLOR_RESET} 🔄 Toggle Auto Restart"
        echo -e "    ${COLOR_CYAN}10.${COLOR_RESET} 🔄 Auto-Refresh Settings"
        echo -e "    ${COLOR_CYAN}11.${COLOR_RESET} 📄 View Full Config File"
        echo
        echo -e "    ${COLOR_CYAN}0.${COLOR_RESET} 🔙 Back to Main Menu"
        echo
        
        local choice
        prompt_user "Select Option: " choice
        echo
        
        local should_pause=false
        case "$choice" in
            1) change_environment && should_pause=true ;;
            2) set_orchestrator_url && should_pause=true ;;
            3) set_memory_limit && should_pause=true ;;
            4) set_cpu_limit && should_pause=true ;;
            5) set_default_wallet && should_pause=true ;;
            6) set_max_difficulty && should_pause=true ;;
            7) set_max_tasks && should_pause=true ;;
            8) toggle_memory_checking && should_pause=true ;;
            9) toggle_auto_restart && should_pause=true ;;
            10) auto_refresh_settings && should_pause=true ;;
            11) view_config_file && should_pause=true ;;
            0) return ;;
            *) log_error "Invalid option." ; should_pause=true ;;
        esac
        
        if [ "$should_pause" = true ]; then
            echo
            prompt_user "Press Enter to continue..." "dummy_var"
        fi
    done
}

change_environment() {
    log_info "Current environment: ${NEXUS_ENVIRONMENT:-production}"
    echo
    echo -e "  ${COLOR_CYAN}[1]${COLOR_RESET} Production (default)"
    echo -e "  ${COLOR_CYAN}[2]${COLOR_RESET} Devnet"
    echo -e "  ${COLOR_CYAN}[3]${COLOR_RESET} Custom"
    echo
    
    local choice
    prompt_user "Select environment: " choice
    
    case "$choice" in
        1) 
            update_config_value "NEXUS_ENVIRONMENT" "production"
            NEXUS_ENVIRONMENT="production"
            log_success "Environment set to production"
            ;;
        2) 
            update_config_value "NEXUS_ENVIRONMENT" "devnet"
            NEXUS_ENVIRONMENT="devnet"
            log_success "Environment set to devnet"
            ;;
        3) 
            update_config_value "NEXUS_ENVIRONMENT" "custom"
            NEXUS_ENVIRONMENT="custom"
            log_success "Environment set to custom"
            log_warn "Don't forget to set custom orchestrator URL!"
            ;;
        *) 
            log_error "Invalid choice"
            return 1
            ;;
    esac
}

set_orchestrator_url() {
    local current_url="${NEXUS_ORCHESTRATOR_URL:-}"
    log_info "Current orchestrator URL: ${current_url:-default}"
    
    local new_url
    prompt_user "Enter new orchestrator URL (or press Enter to clear): " new_url
    
    update_config_value "NEXUS_ORCHESTRATOR_URL" "$new_url"
    NEXUS_ORCHESTRATOR_URL="$new_url"
    
    if [[ -n "$new_url" ]]; then
        log_success "Orchestrator URL set to: $new_url"
    else
        log_success "Orchestrator URL cleared (using default)"
    fi
}

set_memory_limit() {
    local current_limit="${NEXUS_MEMORY_LIMIT:-}"
    log_info "Current memory limit: ${current_limit:-unlimited}"
    log_info "Examples: 1g, 512m, 2g, etc."
    
    local new_limit
    prompt_user "Enter new memory limit (or press Enter to clear): " new_limit
    
    update_config_value "NEXUS_MEMORY_LIMIT" "$new_limit"
    NEXUS_MEMORY_LIMIT="$new_limit"
    
    if [[ -n "$new_limit" ]]; then
        log_success "Memory limit set to: $new_limit"
    else
        log_success "Memory limit cleared (unlimited)"
    fi
}

set_cpu_limit() {
    local current_limit="${NEXUS_CPU_LIMIT:-}"
    log_info "Current CPU limit: ${current_limit:-unlimited}"
    log_info "Examples: 1.0, 2.5, 0.5, etc."
    
    local new_limit
    prompt_user "Enter new CPU limit (or press Enter to clear): " new_limit
    
    update_config_value "NEXUS_CPU_LIMIT" "$new_limit"
    NEXUS_CPU_LIMIT="$new_limit"
    
    if [[ -n "$new_limit" ]]; then
        log_success "CPU limit set to: $new_limit"
    else
        log_success "CPU limit cleared (unlimited)"
    fi
}

set_default_wallet() {
    local current_wallet="${NEXUS_DEFAULT_WALLET:-}"
    log_info "Current default wallet: ${current_wallet:-none}"
    
    local new_wallet
    prompt_user "Enter default wallet address (or press Enter to clear): " new_wallet
    
    if [[ -n "$new_wallet" && ! "$new_wallet" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        log_error "Invalid wallet address format. Should be 0x followed by 40 hex characters."
        return 1
    fi
    
    update_config_value "NEXUS_DEFAULT_WALLET" "$new_wallet"
    NEXUS_DEFAULT_WALLET="$new_wallet"
    
    if [[ -n "$new_wallet" ]]; then
        log_success "Default wallet set to: $new_wallet"
    else
        log_success "Default wallet cleared"
    fi
}

set_max_difficulty() {
    local current_difficulty="${NEXUS_MAX_DIFFICULTY:-}"
    log_info "Current max difficulty: ${current_difficulty:-AUTO}"
    log_info "Available difficulty levels:"
    echo -e "  ${COLOR_CYAN}[0]${COLOR_RESET} ${COLOR_GREEN}AUTO (RECOMMENDED - Server Optimized)${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}[1]${COLOR_RESET} SMALL"
    echo -e "  ${COLOR_CYAN}[2]${COLOR_RESET} SMALL_MEDIUM"
    echo -e "  ${COLOR_CYAN}[3]${COLOR_RESET} MEDIUM"
    echo -e "  ${COLOR_CYAN}[4]${COLOR_RESET} LARGE"
    echo -e "  ${COLOR_CYAN}[5]${COLOR_RESET} EXTRA_LARGE"
    echo
    
    local choice
    prompt_user "Select difficulty level: " choice
    
    local new_difficulty="AUTO"
    case "$choice" in
        1) new_difficulty="SMALL" ;;
        2) new_difficulty="SMALL_MEDIUM" ;;
        3) new_difficulty="MEDIUM" ;;
        4) new_difficulty="LARGE" ;;
        5) new_difficulty="EXTRA_LARGE" ;;
        0) new_difficulty="AUTO" ;;
        *) log_error "Invalid choice"; return 1 ;;
    esac
    
    update_config_value "NEXUS_MAX_DIFFICULTY" "$new_difficulty"
    NEXUS_MAX_DIFFICULTY="$new_difficulty"
    
    if [[ "$new_difficulty" == "AUTO" ]]; then
        log_success "Max difficulty set to: AUTO (Server will optimize task assignment)"
    else
        log_success "Max difficulty set to: $new_difficulty"
    fi
}

set_max_tasks() {
    local current_tasks="${NEXUS_MAX_TASKS:-UNLIMITED}"
    log_info "Current max tasks: ${current_tasks:-UNLIMITED}"
    log_info "${COLOR_GREEN}UNLIMITED (default)${COLOR_RESET} - Optimal for continuous running"
    log_info "Custom number - Useful for controlled/testing runs"
    log_info "Examples: 10, 100, 1000, etc."
    echo
    
    local new_tasks
    prompt_user "Enter max tasks (or press Enter for UNLIMITED - recommended): " new_tasks
    
    # If empty, set to UNLIMITED (default optimal)
    if [[ -z "$new_tasks" ]]; then
        new_tasks="UNLIMITED"
    elif [[ ! "$new_tasks" =~ ^[0-9]+$ ]]; then
        log_error "Invalid format. Please enter a positive number or leave empty for UNLIMITED."
        return 1
    fi
    
    update_config_value "NEXUS_MAX_TASKS" "$new_tasks"
    NEXUS_MAX_TASKS="$new_tasks"
    
    if [[ "$new_tasks" == "UNLIMITED" ]]; then
        log_success "Max tasks set to: UNLIMITED (Optimal for continuous operation)"
    else
        log_success "Max tasks set to: $new_tasks (Will stop after this many tasks)"
    fi
}

toggle_memory_checking() {
    local current="${NEXUS_CHECK_MEMORY:-false}"
    
    if [[ "$current" == "true" ]]; then
        update_config_value "NEXUS_CHECK_MEMORY" "false"
        NEXUS_CHECK_MEMORY="false"
        log_success "Memory checking disabled"
    else
        update_config_value "NEXUS_CHECK_MEMORY" "true"
        NEXUS_CHECK_MEMORY="true"
        log_success "Memory checking enabled"
    fi
}

toggle_auto_restart() {
    local current="${NEXUS_AUTO_RESTART:-true}"
    
    if [[ "$current" == "true" ]]; then
        update_config_value "NEXUS_AUTO_RESTART" "false"
        NEXUS_AUTO_RESTART="false"
        log_success "Auto restart disabled"
    else
        update_config_value "NEXUS_AUTO_RESTART" "true"
        NEXUS_AUTO_RESTART="true"
        log_success "Auto restart enabled"
    fi
}

auto_refresh_settings() {
    while true; do
        clear
        echo -e "${COLOR_CYAN}---[ 🔄 Auto-Refresh Settings ]---${COLOR_RESET}"
        echo
        
        echo -e "  ${COLOR_YELLOW}CURRENT SETTINGS${COLOR_RESET}"
        echo -e "    Auto Refresh     : ${COLOR_GREEN}${NEXUS_AUTO_REFRESH:-true}${COLOR_RESET}"
        echo -e "    Refresh Interval : ${COLOR_GREEN}${NEXUS_REFRESH_INTERVAL:-180} seconds${COLOR_RESET}"
        echo
        
        local running_count
        running_count=$(docker ps --filter "name=nexus-node-" --format "{{.Names}}" 2>/dev/null | wc -l)
        
        echo -e "  ${COLOR_CYAN}STATUS${COLOR_RESET}"
        if [[ "${NEXUS_AUTO_REFRESH:-true}" == "true" && $running_count -gt 0 ]]; then
            echo -e "    Current Mode     : ${COLOR_GREEN}ACTIVE${COLOR_RESET} (${running_count} running nodes)"
        elif [[ "${NEXUS_AUTO_REFRESH:-true}" == "true" ]]; then
            echo -e "    Current Mode     : ${COLOR_YELLOW}IDLE${COLOR_RESET} (no running nodes)"
        else
            echo -e "    Current Mode     : ${COLOR_RED}DISABLED${COLOR_RESET}"
        fi
        echo
        
        echo -e "  ${COLOR_CYAN}REFRESH OPTIONS${COLOR_RESET}"
        echo -e "    ${COLOR_CYAN}1.${COLOR_RESET} 🔄 Toggle Auto-Refresh (ON/OFF)"
        echo -e "    ${COLOR_CYAN}2.${COLOR_RESET} ⏱️ Set Refresh Interval"
        echo -e "    ${COLOR_CYAN}3.${COLOR_RESET} 📊 Quick Settings"
        echo
        echo -e "    ${COLOR_CYAN}0.${COLOR_RESET} 🔙 Back to Environment Config"
        echo
        
        local choice
        prompt_user "Select Option: " choice
        echo
        
        case "$choice" in
            1) toggle_auto_refresh ;;
            2) set_refresh_interval ;;
            3) quick_refresh_settings ;;
            0) return ;;
            *) log_error "Invalid option." ;;
        esac
        
        echo
        prompt_user "Press Enter to continue..." "dummy_var"
    done
}

toggle_auto_refresh() {
    local current="${NEXUS_AUTO_REFRESH:-true}"
    
    if [[ "$current" == "true" ]]; then
        update_config_value "NEXUS_AUTO_REFRESH" "false"
        NEXUS_AUTO_REFRESH="false"
        log_success "Auto-refresh disabled"
    else
        update_config_value "NEXUS_AUTO_REFRESH" "true"
        NEXUS_AUTO_REFRESH="true"
        log_success "Auto-refresh enabled"
    fi
}

set_refresh_interval() {
    local current_interval="${NEXUS_REFRESH_INTERVAL:-180}"
    log_info "Current refresh interval: ${current_interval} seconds"
    log_info "Recommended: 60-300 seconds (1-5 minutes)"
    echo
    
    local new_interval
    prompt_user "Enter refresh interval in seconds (or press Enter to keep current): " new_interval
    
    if [[ -n "$new_interval" ]]; then
        if [[ ! "$new_interval" =~ ^[0-9]+$ ]] || [[ $new_interval -lt 30 ]] || [[ $new_interval -gt 3600 ]]; then
            log_error "Invalid interval. Please enter a number between 30-3600 seconds."
            return 1
        fi
        
        update_config_value "NEXUS_REFRESH_INTERVAL" "$new_interval"
        NEXUS_REFRESH_INTERVAL="$new_interval"
        log_success "Refresh interval set to ${new_interval} seconds"
    else
        log_info "Refresh interval unchanged"
    fi
}

quick_refresh_settings() {
    log_info "Quick Auto-Refresh Settings:"
    echo
    echo -e "  ${COLOR_CYAN}[1]${COLOR_RESET} Fast Refresh (60s)"
    echo -e "  ${COLOR_CYAN}[2]${COLOR_RESET} Normal Refresh (180s) - Default"
    echo -e "  ${COLOR_CYAN}[3]${COLOR_RESET} Slow Refresh (300s)"
    echo -e "  ${COLOR_CYAN}[4]${COLOR_RESET} Disable Auto-Refresh"
    echo
    
    local choice
    prompt_user "Select quick setting: " choice
    
    case "$choice" in
        1)
            update_config_value "NEXUS_AUTO_REFRESH" "true"
            update_config_value "NEXUS_REFRESH_INTERVAL" "60"
            NEXUS_AUTO_REFRESH="true"
            NEXUS_REFRESH_INTERVAL="60"
            log_success "Fast refresh enabled (60 seconds)"
            ;;
        2)
            update_config_value "NEXUS_AUTO_REFRESH" "true"
            update_config_value "NEXUS_REFRESH_INTERVAL" "180"
            NEXUS_AUTO_REFRESH="true"
            NEXUS_REFRESH_INTERVAL="180"
            log_success "Normal refresh enabled (180 seconds)"
            ;;
        3)
            update_config_value "NEXUS_AUTO_REFRESH" "true"
            update_config_value "NEXUS_REFRESH_INTERVAL" "300"
            NEXUS_AUTO_REFRESH="true"
            NEXUS_REFRESH_INTERVAL="300"
            log_success "Slow refresh enabled (300 seconds)"
            ;;
        4)
            update_config_value "NEXUS_AUTO_REFRESH" "false"
            NEXUS_AUTO_REFRESH="false"
            log_success "Auto-refresh disabled"
            ;;
        *)
            log_error "Invalid choice"
            return 1
            ;;
    esac
}

view_config_file() {
    log_info "Configuration file: $CONFIG_FILE"
    echo
    if [[ -f "$CONFIG_FILE" ]]; then
        cat "$CONFIG_FILE"
    else
        log_error "Configuration file not found!"
    fi
}



# High Performance Mode menu
high_performance_menu() {
    while true; do
        clear
        echo -e "${COLOR_CYAN}---[ ⚡ High Performance Mode ]---${COLOR_RESET}"
        echo
        
        # Show current hardware specs
        local total_cores total_ram_gb
        total_cores=$(nproc 2>/dev/null || echo "4")
        
        if command -v free &>/dev/null; then
            total_ram_gb=$(free -g | awk '/^Mem:/{print $2}')
        else
            # Windows fallback
            total_ram_gb=$(powershell.exe -Command "[math]::Round((Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum).Sum / 1GB)" 2>/dev/null || echo "8")
        fi
        
        echo -e "  ${COLOR_YELLOW}HARDWARE DETECTED${COLOR_RESET}"
        echo -e "    CPU Cores        : ${COLOR_GREEN}$total_cores cores${COLOR_RESET}"
        echo -e "    Total RAM        : ${COLOR_GREEN}${total_ram_gb}GB${COLOR_RESET}"
        echo -e "    Optimal Containers: ${COLOR_GREEN}${NEXUS_OPTIMAL_CONTAINERS:-auto-detect}${COLOR_RESET}"
        echo -e "    Cores per Container: ${COLOR_GREEN}${NEXUS_CORES_PER_CONTAINER:-auto-detect}${COLOR_RESET}"
        echo
        
        echo -e "  ${COLOR_CYAN}PERFORMANCE OPTIONS${COLOR_RESET}"
        echo -e "    ${COLOR_CYAN}1.${COLOR_RESET} 🔍 Auto-Detect Optimal Settings"
        echo -e "    ${COLOR_CYAN}2.${COLOR_RESET} 🚀 Launch Optimized Multi-Instances"
        echo -e "    ${COLOR_CYAN}3.${COLOR_RESET} ⚙️ Manual Resource Configuration"
        echo -e "    ${COLOR_CYAN}4.${COLOR_RESET} 📊 View Current Resource Usage"
        echo -e "    ${COLOR_CYAN}5.${COLOR_RESET} 🧪 Test Performance"
        echo
        echo -e "    ${COLOR_CYAN}0.${COLOR_RESET} 🔙 Back to Main Menu"
        echo
        
        local choice
        prompt_user "Select Option: " choice
        echo
        
        local should_pause=false
        case "$choice" in
            1) optimize_for_high_performance && should_pause=true ;;
            2) launch_optimized_instances && should_pause=true ;;
            3) manual_resource_config && should_pause=true ;;
            4) view_resource_usage && should_pause=true ;;
            5) test_performance && should_pause=true ;;
            0) return ;;
            *) log_error "Invalid option." ; should_pause=true ;;
        esac
        
        if [ "$should_pause" = true ]; then
            echo
            prompt_user "Press Enter to continue..." "dummy_var"
        fi
    done
}

# Launch optimized instances based on detected hardware
launch_optimized_instances() {
    # Run optimization first if not done
    if [[ -z "${NEXUS_OPTIMAL_CONTAINERS:-}" ]]; then
        log_info "Running auto-detection first..."
        optimize_for_high_performance
    fi
    
    local base_node_id
    prompt_user "Enter starting Node ID for the sequence: " base_node_id
    
    if [[ ! "$base_node_id" =~ ^[0-9]+$ ]]; then
        log_error "Invalid Node ID format"
        return 1
    fi
    
    auto_generate_optimal_instances "$base_node_id"
}

# Manual resource configuration
manual_resource_config() {
    log_info "Current Settings:"
    echo -e "  Containers: ${COLOR_GREEN}${NEXUS_OPTIMAL_CONTAINERS:-auto}${COLOR_RESET}"
    echo -e "  Cores each: ${COLOR_GREEN}${NEXUS_CORES_PER_CONTAINER:-auto}${COLOR_RESET}"
    echo -e "  Memory each: ${COLOR_GREEN}${NEXUS_MEMORY_LIMIT:-auto}${COLOR_RESET}"
    echo
    
    local containers cores memory
    prompt_user "Enter number of containers to create: " containers
    prompt_user "Enter CPU cores per container: " cores  
    prompt_user "Enter memory limit per container (e.g., 2g, 1024m): " memory
    
    if [[ ! "$containers" =~ ^[0-9]+$ ]] || [[ ! "$cores" =~ ^[0-9]+$ ]]; then
        log_error "Invalid input. Numbers only for containers and cores."
        return 1
    fi
    
    update_config_value "NEXUS_OPTIMAL_CONTAINERS" "$containers"
    update_config_value "NEXUS_CORES_PER_CONTAINER" "$cores"
    # Always use 4 threads as default
    update_config_value "NEXUS_DEFAULT_THREADS" "4"
    
    if [[ -n "$memory" ]]; then
        update_config_value "NEXUS_MEMORY_LIMIT" "$memory"
        update_config_value "NEXUS_CPU_LIMIT" "$cores"
    else
        # Set unlimited memory as default
        update_config_value "NEXUS_MEMORY_LIMIT" ""
    fi
    
    # Reload config
    source "$CONFIG_FILE"
    
    log_success "Manual configuration applied: $containers containers, $cores cores each, ${memory:-unlimited} memory"
}

# View current resource usage across all containers
view_resource_usage() {
    log_info "Current System Resource Usage"
    echo
    
    # System overview
    local total_cores used_containers
    total_cores=$(nproc 2>/dev/null || echo "4")
    used_containers=$(docker ps --filter "name=nexus-node-" --format "{{.Names}}" | wc -l)
    
    echo -e "  ${COLOR_YELLOW}SYSTEM OVERVIEW${COLOR_RESET}"
    echo -e "    Total CPU Cores  : ${COLOR_GREEN}$total_cores${COLOR_RESET}"
    echo -e "    Active Containers: ${COLOR_GREEN}$used_containers${COLOR_RESET}"
    echo -e "    Configured Limit : ${COLOR_GREEN}${NEXUS_OPTIMAL_CONTAINERS:-none}${COLOR_RESET}"
    echo
    
    if [[ $used_containers -eq 0 ]]; then
        log_warn "No active containers to show resource usage"
        return 1
    fi
    
    echo -e "  ${COLOR_YELLOW}CONTAINER RESOURCE USAGE${COLOR_RESET}"
    printf "  ${COLOR_CYAN}%-20s %-10s %-15s %-10s${COLOR_RESET}\n" "CONTAINER" "CPU%" "MEMORY" "THREADS"
    printf "  %55s\n" | tr ' ' '-'
    
    docker ps --filter "name=nexus-node-" --format "{{.Names}}" | while read -r container; do
        if [[ -n "$container" ]]; then
            local stats cpu_perc mem_usage threads
            
            # Get resource stats
            if stats=$(docker stats --no-stream --format "{{.CPUPerc}},{{.MemUsage}}" "$container" 2>/dev/null); then
                cpu_perc=$(echo "$stats" | cut -d',' -f1)
                mem_usage=$(echo "$stats" | cut -d',' -f2 | awk '{print $1}')
            else
                cpu_perc="0.00%"
                mem_usage="0MiB"
            fi
            
            # Get thread config
            threads=$(docker inspect "$container" --format '{{range .Config.Env}}{{if eq (index (split . "=") 0) "MAX_THREADS"}}{{(index (split . "=") 1)}}{{end}}{{end}}' 2>/dev/null || echo "auto")
            
            printf "  ${COLOR_GREEN}%-20s${COLOR_RESET} ${COLOR_YELLOW}%-10s${COLOR_RESET} ${COLOR_CYAN}%-15s${COLOR_RESET} ${COLOR_PURPLE}%-10s${COLOR_RESET}\n" \
                   "$container" "$cpu_perc" "$mem_usage" "$threads"
        fi
    done
    
    echo
    
    # Total resource calculation
    local total_cpu_usage total_memory_mb
    total_cpu_usage=$(docker stats --no-stream --format "{{.CPUPerc}}" 2>/dev/null | sed 's/%//' | awk '{sum+=$1} END {printf "%.1f", sum}')
    total_memory_mb=$(docker stats --no-stream --format "{{.MemUsage}}" 2>/dev/null | awk '{gsub(/MiB/, ""); sum+=$1} END {printf "%.0f", sum}')
    
    echo -e "  ${COLOR_YELLOW}TOTAL UTILIZATION${COLOR_RESET}"
    echo -e "    Total CPU Usage  : ${COLOR_GREEN}${total_cpu_usage:-0.0}%${COLOR_RESET}"
    echo -e "    Total Memory Used: ${COLOR_GREEN}${total_memory_mb:-0}MB${COLOR_RESET}"
    
    # Calculate efficiency
    local cpu_efficiency
    if [[ -n "$total_cpu_usage" && "$total_cpu_usage" != "0.0" ]]; then
        cpu_efficiency=$(awk "BEGIN {printf \"%.1f\", ($total_cpu_usage / $total_cores)}")
        echo -e "    CPU Efficiency   : ${COLOR_CYAN}${cpu_efficiency}% per core${COLOR_RESET}"
    fi
}

# Test performance of current setup
test_performance() {
    local containers
    mapfile -t containers < <(docker ps --filter "name=nexus-node-" --format "{{.Names}}" | sort)
    
    if [[ ${#containers[@]} -eq 0 ]]; then
        log_warn "No running containers to test"
        return 1
    fi
    
    log_info "Running performance test on ${#containers[@]} containers..."
    echo
    
    # Test each container for 30 seconds
    for container in "${containers[@]}"; do
        local node_id
        node_id=$(docker inspect "$container" --format '{{range .Config.Env}}{{if eq (index (split . "=") 0) "NODE_ID"}}{{(index (split . "=") 1)}}{{end}}{{end}}')
        
        echo -e "  ${COLOR_CYAN}Testing $container (Node ID: $node_id)${COLOR_RESET}"
        
        # Sample resource usage over 30 seconds
        local cpu_samples=0
        local cpu_total=0
        local memory_total=0
        
        for i in {1..6}; do  # 6 samples over 30 seconds
            if stats=$(docker stats --no-stream --format "{{.CPUPerc}},{{.MemUsage}}" "$container" 2>/dev/null); then
                local cpu mem
                cpu=$(echo "$stats" | cut -d',' -f1 | sed 's/%//')
                mem=$(echo "$stats" | cut -d',' -f2 | awk '{print $1}' | sed 's/MiB//')
                
                if [[ "$cpu" =~ ^[0-9.]+$ ]]; then
                    cpu_total=$(awk "BEGIN {print $cpu_total + $cpu}")
                    ((cpu_samples++))
                fi
                
                if [[ "$mem" =~ ^[0-9.]+$ ]]; then
                    memory_total=$(awk "BEGIN {print $memory_total + $mem}")
                fi
            fi
            
            sleep 5
            printf "    Progress: [$(printf '%*s' $i '' | tr ' ' '█')] %d/6\r" $i
        done
        
        echo
        
        if [[ $cpu_samples -gt 0 ]]; then
            local avg_cpu avg_memory
            avg_cpu=$(awk "BEGIN {printf \"%.1f\", $cpu_total / $cpu_samples}")
            avg_memory=$(awk "BEGIN {printf \"%.0f\", $memory_total / 6}")
            
            echo -e "    Average CPU : ${COLOR_GREEN}${avg_cpu}%${COLOR_RESET}"
            echo -e "    Average RAM : ${COLOR_GREEN}${avg_memory}MB${COLOR_RESET}"
            
            # Performance rating
            local rating="Good"
            local rating_color="${COLOR_GREEN}"
            
            if awk "BEGIN {exit ($avg_cpu > 90) ? 0 : 1}"; then
                rating="Excellent"; rating_color="${COLOR_GREEN}"
            elif awk "BEGIN {exit ($avg_cpu > 70) ? 0 : 1}"; then
                rating="Very Good"; rating_color="${COLOR_CYAN}"
            elif awk "BEGIN {exit ($avg_cpu > 50) ? 0 : 1}"; then
                rating="Good"; rating_color="${COLOR_YELLOW}"
            else
                rating="Low"; rating_color="${COLOR_RED}"
            fi
            
            echo -e "    Performance: ${rating_color}${rating}${COLOR_RESET}"
        else
            echo -e "    ${COLOR_RED}❌ Failed to collect performance data${COLOR_RESET}"
        fi
        
        echo
    done
    
    log_success "Performance test completed"
}

# ╭───────────────────────────────────────────────────────────────────╮
# │ 💻 AKSI MENU                                                      │
# ╰───────────────────────────────────────────────────────────────────╯

_select_container() {
    local prompt_message="$1"
    local selected_container_var="$2"
    local all_containers_flag="${3:-false}"
    local containers
    
    if [ "$all_containers_flag" = true ]; then
        mapfile -t containers < <(docker ps -a --filter "name=nexus-node-" --format "{{.Names}}" | sort)
    else
        mapfile -t containers < <(docker ps --filter "name=nexus-node-" --format "{{.Names}}" | sort)
    fi
    
    if [ ${#containers[@]} -eq 0 ]; then
        log_warn "Tidak ada instance yang ditemukan."
        return 1
    fi

    log_info "$prompt_message"
    for i in "${!containers[@]}"; do
        echo -e "  ${COLOR_CYAN}[$((i+1))]${COLOR_RESET} ${containers[i]}"
    done
    echo -e "  ${COLOR_CYAN}[0]${COLOR_RESET} Batal"

    local choice
    prompt_user "Masukkan pilihan Anda: " choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -gt 0 ] && [ "$choice" -le "${#containers[@]}" ]; then
        eval "$selected_container_var='${containers[$((choice-1))]}'"
        return 0
    else
        return 1
    fi
}

# Unified backup and restore menu
backup_restore_menu() {
    while true; do
        clear
        echo -e "${COLOR_CYAN}---[ 💿 Backup & Restore Management ]---${COLOR_RESET}"
        echo
        
        # Show existing backups
        local backups
        mapfile -t backups < <(find "$BACKUP_DIR" -name "nexus-node-*.tar.gz" 2>/dev/null | sort -r)
        
        echo -e "  ${COLOR_YELLOW}EXISTING BACKUPS${COLOR_RESET}"
        if [ ${#backups[@]} -eq 0 ]; then
            echo -e "    ${COLOR_RED}❌ No backups found in $BACKUP_DIR${COLOR_RESET}"
        else
            echo -e "    ${COLOR_GREEN}📁 Found ${#backups[@]} backup files:${COLOR_RESET}"
            for i in "${!backups[@]}"; do
                if [[ $i -lt 5 ]]; then  # Show only first 5 backups
                    local backup_name=$(basename "${backups[i]}")
                    local backup_size=$(ls -lh "${backups[i]}" | awk '{print $5}')
                    echo -e "    ${COLOR_CYAN}├─${COLOR_RESET} $backup_name (${backup_size})"
                fi
            done
            if [[ ${#backups[@]} -gt 5 ]]; then
                echo -e "    ${COLOR_CYAN}└─${COLOR_RESET} ... and $((${#backups[@]} - 5)) more backups"
            fi
        fi
        echo
        
        echo -e "  ${COLOR_CYAN}BACKUP & RESTORE OPTIONS${COLOR_RESET}"
        echo -e "    ${COLOR_CYAN}1.${COLOR_RESET} 💾 Create New Backup - Backup node configuration"
        echo -e "    ${COLOR_CYAN}2.${COLOR_RESET} 📦 Restore from Backup - Restore node from backup"
        echo -e "    ${COLOR_CYAN}3.${COLOR_RESET} 🗑️ Delete Old Backups - Clean up backup files"
        echo -e "    ${COLOR_CYAN}4.${COLOR_RESET} 📊 View Backup Details - Show backup information"
        echo
        echo -e "    ${COLOR_CYAN}0.${COLOR_RESET} 🔙 Back to Main Menu"
        echo
        
        local choice
        prompt_user "Select Option: " choice
        echo
        
        local should_pause=false
        case "$choice" in
            1) perform_backup && should_pause=true ;;
            2) perform_restore && should_pause=true ;;
            3) delete_old_backups && should_pause=true ;;
            4) view_backup_details && should_pause=true ;;
            0) return ;;
            *) log_error "Invalid option." ; should_pause=true ;;
        esac
        
        if [ "$should_pause" = true ]; then
            echo
            prompt_user "Press Enter to continue..." "dummy_var"
        fi
    done
}

perform_backup() {
    local container
    if ! _select_container "Pilih node untuk di-backup:" container; then return 1; fi

    local node_id
    node_id=$(docker inspect "$container" --format '{{range .Config.Env}}{{if eq (index (split . "=") 0) "NODE_ID"}}{{(index (split . "=") 1)}}{{end}}{{end}}')
    local source_dir="${CONFIG_DIR}/${node_id}"

    if [ ! -d "$source_dir" ]; then
        log_error "Direktori config untuk Node ID $node_id tidak ditemukan di '$source_dir'."
        return 1
    fi
    
    local backup_file="${BACKUP_DIR}/nexus-node-${node_id}-$(date +%Y%m%d-%H%M%S).tar.gz"
    log_info "Mem-backup '$source_dir' ke '$backup_file'..."

    if ! tar -czf "$backup_file" -C "${CONFIG_DIR}" "${node_id}"; then
        log_error "Backup gagal."
        return 1
    fi
    log_success "Backup selesai: $backup_file"
    return 0
}

perform_restore() {
    local backups
    mapfile -t backups < <(find "$BACKUP_DIR" -name "nexus-node-*.tar.gz" | sort -r)

    if [ ${#backups[@]} -eq 0 ]; then
        log_warn "Tidak ada file backup di '$BACKUP_DIR'."
        return 1
    fi
    
    log_info "Pilih file backup untuk dipulihkan:"
    for i in "${!backups[@]}"; do
        echo -e "  ${COLOR_CYAN}[$((i+1))]${COLOR_RESET} $(basename "${backups[i]}")"
    done
    echo -e "  ${COLOR_CYAN}[0]${COLOR_RESET} Batal"

    local choice
    prompt_user "Masukkan pilihan Anda: " choice

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -eq 0 ] || [ "$choice" -gt "${#backups[@]}" ]; then
        return 1
    fi
    
    local backup_file="${backups[$((choice-1))]}"
    local target_node_id
    prompt_user "Masukkan ID Node tujuan untuk restore: " target_node_id
    [[ "$target_node_id" =~ ^[0-9]+$ ]] || { log_error "ID Node tidak valid."; return 1; }

    if ! prompt_confirm "Ini akan MENIMPA semua data config untuk ID Node $target_node_id. Lanjutkan?"; then
        return 1
    fi

    local target_dir="${CONFIG_DIR}/${target_node_id}"
    log_info "Menghentikan kontainer yang menggunakan ID Node $target_node_id..."
    local container_to_stop
    container_to_stop=$(docker ps -q --filter "name=nexus-node-" | xargs -r docker inspect --format '{{.Name}} {{range .Config.Env}}{{if eq (index (split . "=") 0) "NODE_ID"}}{{(index (split . "=") 1)}}{{end}}{{end}}' | awk -v id="$target_node_id" '$2==id {print $1}' | sed 's/^\///')
    
    if [ -n "$container_to_stop" ]; then
        if ! docker stop "$container_to_stop" >/dev/null; then
            log_warn "Gagal menghentikan kontainer, proses restore tetap dilanjutkan."
        else
            log_info "Kontainer '$container_to_stop' dihentikan."
        fi
    fi

    log_info "Memulihkan '$backup_file' ke '$target_dir'..."
    rm -rf "$target_dir"
    mkdir -p "$target_dir"
    if ! tar -xzf "$backup_file" -C "${CONFIG_DIR}"; then
        log_error "Restore gagal."
        return 1
    fi
    log_success "Restore selesai. Silakan mulai ulang atau buat instance untuk ID Node $target_node_id."
    return 0
}

delete_old_backups() {
    local backups
    mapfile -t backups < <(find "$BACKUP_DIR" -name "nexus-node-*.tar.gz" | sort -r)
    
    if [ ${#backups[@]} -eq 0 ]; then
        log_warn "No backup files found to delete"
        return 1
    fi
    
    log_info "Select backup files to delete:"
    for i in "${!backups[@]}"; do
        local backup_name=$(basename "${backups[i]}")
        local backup_size=$(ls -lh "${backups[i]}" | awk '{print $5}')
        echo -e "  ${COLOR_CYAN}[$((i+1))]${COLOR_RESET} $backup_name (${backup_size})"
    done
    echo -e "  ${COLOR_CYAN}[a]${COLOR_RESET} Delete All Backups"
    echo -e "  ${COLOR_CYAN}[0]${COLOR_RESET} Cancel"
    echo
    
    local choice
    prompt_user "Enter choice (separate multiple with spaces): " choice
    
    if [[ "$choice" == "0" ]]; then
        return 1
    fi
    
    local targets=()
    if [[ "$choice" =~ ^[aA]$ ]]; then
        targets=("${backups[@]}")
    else
        for num in $choice; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -gt 0 ] && [ "$num" -le "${#backups[@]}" ]; then
                targets+=("${backups[$((num-1))]}")
            else
                log_error "Invalid input: '$num'"
                return 1
            fi
        done
    fi
    
    if [ ${#targets[@]} -eq 0 ]; then
        log_warn "No backups selected"
        return 1
    fi
    
    echo
    log_warn "You will PERMANENTLY delete ${#targets[@]} backup files:"
    for target in "${targets[@]}"; do
        echo -e "  - ${COLOR_YELLOW}$(basename "$target")${COLOR_RESET}"
    done
    echo
    
    if ! prompt_confirm "Are you sure you want to delete these backups?"; then
        return 1
    fi
    
    for target in "${targets[@]}"; do
        if rm -f "$target" 2>/dev/null; then
            log_success "Deleted: $(basename "$target")"
        else
            log_error "Failed to delete: $(basename "$target")"
        fi
    done
    
    log_success "Backup cleanup completed"
}

view_backup_details() {
    local backups
    mapfile -t backups < <(find "$BACKUP_DIR" -name "nexus-node-*.tar.gz" | sort -r)
    
    if [ ${#backups[@]} -eq 0 ]; then
        log_warn "No backup files found"
        return 1
    fi
    
    log_info "Backup Files Details:"
    echo
    
    printf "  ${COLOR_CYAN}%-35s %-8s %-20s${COLOR_RESET}\n" "BACKUP FILE" "SIZE" "DATE CREATED"
    printf "  %65s\n" | tr ' ' '-'
    
    for backup in "${backups[@]}"; do
        local backup_name=$(basename "$backup")
        local backup_size=$(ls -lh "$backup" | awk '{print $5}')
        local backup_date
        
        # Cross-platform date formatting
        if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
            backup_date=$(stat -c %Y "$backup" 2>/dev/null | xargs -I {} date -d @{} '+%Y-%m-%d %H:%M' 2>/dev/null || echo "Unknown")
        else
            backup_date=$(stat -f %Sm -t '%Y-%m-%d %H:%M' "$backup" 2>/dev/null || stat -c %y "$backup" 2>/dev/null | cut -d' ' -f1-2 | cut -c1-16 || echo "Unknown")
        fi
        
        printf "  ${COLOR_GREEN}%-35s${COLOR_RESET} ${COLOR_YELLOW}%-8s${COLOR_RESET} ${COLOR_CYAN}%-20s${COLOR_RESET}\n" \
               "$backup_name" "$backup_size" "$backup_date"
    done
    
    echo
    
    # Calculate total backup size
    local total_size_bytes=0
    for backup in "${backups[@]}"; do
        local size_bytes
        size_bytes=$(stat -f %z "$backup" 2>/dev/null || stat -c %s "$backup" 2>/dev/null || echo "0")
        total_size_bytes=$((total_size_bytes + size_bytes))
    done
    
    # Convert bytes to human readable
    local total_size_mb=$((total_size_bytes / 1024 / 1024))
    
    echo -e "  ${COLOR_YELLOW}SUMMARY${COLOR_RESET}"
    echo -e "    Total Backups: ${COLOR_GREEN}${#backups[@]}${COLOR_RESET}"
    echo -e "    Total Size   : ${COLOR_GREEN}${total_size_mb}MB${COLOR_RESET}"
    echo -e "    Directory    : ${COLOR_CYAN}$BACKUP_DIR${COLOR_RESET}"
}

start_multiple_instances() {
    local instance_count
    while true; do
        prompt_user "Masukkan jumlah instance (atau [0] untuk kembali): " instance_count
        if [[ "$instance_count" == "0" ]]; then log_info "Operasi dibatalkan."; return 1; fi
        if [[ "$instance_count" =~ ^[1-9][0-9]*$ ]]; then break; else log_error "Jumlah tidak valid. Harap masukkan angka lebih dari 0."; fi
    done

    for i in $(seq 1 "$instance_count"); do
        local node_id
        while true; do
            prompt_user "Masukkan ID Node untuk instance #$i (atau [0] untuk batal): " node_id
            if [[ "$node_id" == "0" ]]; then log_info "Operasi dibatalkan."; return 1; fi
            if [[ "$node_id" =~ ^[0-9]+$ ]]; then break; else log_error "ID Node harus berupa angka."; fi
        done

        local container_name="nexus-node-$i"
        if docker inspect "$container_name" &>/dev/null; then
            if prompt_confirm "Kontainer '$container_name' sudah ada. Ganti?"; then
                log_info "Menghapus kontainer lama..."
                if ! docker rm -f "$container_name" &>/dev/null; then
                    log_warn "Gagal menghapus kontainer lama, mungkin sudah berhenti."
                fi
            else
                log_warn "Melewatkan instance $i."
                continue
            fi
        fi
        _run_node_container "$container_name" "$node_id" "$DEFAULT_THREADS"
    done
}

add_one_instance() {
    local max_id
    max_id=$(docker ps -a --filter "name=nexus-node-" --format '{{.Names}}' |
             awk -F'-' '{if($NF ~ /^[0-9]+$/) print $NF}' |
             sort -nr | head -n 1)
    local next_idx=$(( ${max_id:-0} + 1 ))
    local container_name="nexus-node-$next_idx"
    local node_id
    while true; do
        prompt_user "Masukkan ID Node untuk instance baru (atau [0] untuk kembali): " node_id
        if [[ "$node_id" == "0" ]]; then log_info "Operasi dibatalkan."; return 1; fi
        if [[ "$node_id" =~ ^[0-9]+$ ]]; then break; else log_error "ID Node harus berupa angka."; fi
    done
    _run_node_container "$container_name" "$node_id" "$DEFAULT_THREADS"
}

# ╭───────────────────────────────────────────────────────────────────╮
# │ 🎮 FUNGSI KONTROL NODE - START, STOP, RESTART, DELETE             │
# ╰───────────────────────────────────────────────────────────────────╯

# Fungsi untuk menjalankan node yang sudah ada (tanpa membuat baru)
start_existing_nodes() {
    local containers
    mapfile -t containers < <(docker ps -a --filter "name=nexus-node-" --filter "status=exited" --format "{{.Names}}" | sort)
    
    if [ ${#containers[@]} -eq 0 ]; then
        log_warn "Tidak ada node yang berhenti untuk dijalankan."
        return 1
    fi
    
    log_info "Pilih node yang akan dijalankan:"
    for i in "${!containers[@]}"; do
        local node_id
        node_id=$(docker inspect "${containers[i]}" --format '{{range .Config.Env}}{{if eq (index (split . "=") 0) "NODE_ID"}}{{(index (split . "=") 1)}}{{end}}{{end}}' 2>/dev/null || echo "N/A")
        echo -e "  ${COLOR_CYAN}[$((i+1))]${COLOR_RESET} ${containers[i]} (Node ID: ${node_id})"
    done
    echo -e "  ${COLOR_CYAN}[a]${COLOR_RESET} Jalankan Semua"
    echo -e "  ${COLOR_CYAN}[0]${COLOR_RESET} Kembali"
    echo
    
    local choice
    prompt_user "Pilihan: " choice
    
    local targets=()
    case "$choice" in
        0) return 1 ;;
        [aA]) targets=("${containers[@]}") ;;
        *) 
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -gt 0 ] && [ "$choice" -le "${#containers[@]}" ]; then
                targets=("${containers[$((choice-1))]}")
            else
                log_error "Pilihan tidak valid."
                return 1
            fi
            ;;
    esac
    
    for container in "${targets[@]}"; do
        log_info "Menjalankan $container..."
        if docker start "$container" >/dev/null 2>&1; then
            log_success "Container $container berhasil dijalankan."
        else
            log_error "Gagal menjalankan container $container."
        fi
    done
    
    log_success "Proses start node selesai."
    return 0
}

# Fungsi untuk menghentikan node yang berjalan
stop_running_nodes() {
    local containers
    mapfile -t containers < <(docker ps --filter "name=nexus-node-" --format "{{.Names}}" | sort)
    
    if [ ${#containers[@]} -eq 0 ]; then
        log_warn "Tidak ada node yang berjalan untuk dihentikan."
        return 1
    fi
    
    log_info "Pilih node yang akan dihentikan:"
    for i in "${!containers[@]}"; do
        local node_id
        node_id=$(docker inspect "${containers[i]}" --format '{{range .Config.Env}}{{if eq (index (split . "=") 0) "NODE_ID"}}{{(index (split . "=") 1)}}{{end}}{{end}}' 2>/dev/null || echo "N/A")
        echo -e "  ${COLOR_CYAN}[$((i+1))]${COLOR_RESET} ${containers[i]} (Node ID: ${node_id})"
    done
    echo -e "  ${COLOR_CYAN}[a]${COLOR_RESET} Hentikan Semua"
    echo -e "  ${COLOR_CYAN}[0]${COLOR_RESET} Kembali"
    echo
    
    local choice
    prompt_user "Pilihan: " choice
    
    local targets=()
    case "$choice" in
        0) return 1 ;;
        [aA]) targets=("${containers[@]}") ;;
        *) 
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -gt 0 ] && [ "$choice" -le "${#containers[@]}" ]; then
                targets=("${containers[$((choice-1))]}")
            else
                log_error "Pilihan tidak valid."
                return 1
            fi
            ;;
    esac
    
    for container in "${targets[@]}"; do
        log_info "Menghentikan $container..."
        if docker stop "$container" >/dev/null 2>&1; then
            log_success "Container $container berhasil dihentikan."
        else
            log_error "Gagal menghentikan container $container."
        fi
    done
    
    log_success "Proses stop node selesai."
    return 0
}

# Fungsi untuk restart node (modifikasi dari fungsi yang sudah ada)
restart_nodes() {
    local containers
    mapfile -t containers < <(docker ps -a --filter "name=nexus-node-" --format "{{.Names}}" | sort)
    
    if [ ${#containers[@]} -eq 0 ]; then
        log_warn "Tidak ada instance yang ditemukan untuk di-restart."
        return 1
    fi
    
    log_info "Pilih node untuk di-restart:"
    for i in "${!containers[@]}"; do
        local status node_id
        status=$(docker inspect -f '{{.State.Status}}' "${containers[i]}")
        node_id=$(docker inspect "${containers[i]}" --format '{{range .Config.Env}}{{if eq (index (split . "=") 0) "NODE_ID"}}{{(index (split . "=") 1)}}{{end}}{{end}}' 2>/dev/null || echo "N/A")
        local status_color="${COLOR_YELLOW}"
        if [[ "$status" == "running" ]]; then status_color="${COLOR_GREEN}"; fi
        echo -e "  ${COLOR_CYAN}[$((i+1))]${COLOR_RESET} ${containers[i]} (Node ID: ${node_id}) - Status: ${status_color}${status}${COLOR_RESET}"
    done
    echo -e "  ${COLOR_CYAN}[a]${COLOR_RESET} Restart Semua"
    echo -e "  ${COLOR_CYAN}[0]${COLOR_RESET} Kembali"
    echo
    
    local choice
    prompt_user "Pilihan: " choice
    
    local targets=()
    case "$choice" in
        0) return 1 ;;
        [aA]) targets=("${containers[@]}") ;;
        *) 
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -gt 0 ] && [ "$choice" -le "${#containers[@]}" ]; then
                targets=("${containers[$((choice-1))]}")
            else
                log_error "Pilihan tidak valid."
                return 1
            fi
            ;;
    esac
    
    for container in "${targets[@]}"; do
        log_info "Me-restart $container..."
        
        # Try simple restart first
        if docker restart "$container" >/dev/null 2>&1; then
            log_success "Container $container berhasil di-restart."
            continue
        fi
        
        # If restart fails, recreate the container
        log_warn "Restart gagal, mencoba membuat ulang container $container..."
        
        # Get container configuration
        local node_id threads wallet
        node_id=$(docker inspect "$container" --format '{{range .Config.Env}}{{if eq (index (split . "=") 0) "NODE_ID"}}{{(index (split . "=") 1)}}{{end}}{{end}}' 2>/dev/null || echo "")
        threads=$(docker inspect "$container" --format '{{range .Config.Env}}{{if eq (index (split . "=") 0) "MAX_THREADS"}}{{(index (split . "=") 1)}}{{end}}{{end}}' 2>/dev/null || echo "$DEFAULT_THREADS")
        wallet=$(docker inspect "$container" --format '{{range .Config.Env}}{{if eq (index (split . "=") 0) "WALLET_ADDRESS"}}{{(index (split . "=") 1)}}{{end}}{{end}}' 2>/dev/null || echo "")
        
        if [[ -z "$node_id" ]]; then
            log_error "Tidak dapat membaca konfigurasi container $container. Lewati..."
            continue
        fi
        
        # Remove broken container
        log_info "Menghapus container rusak..."
        docker rm -f "$container" >/dev/null 2>&1
        
        # Recreate container
        log_info "Membuat ulang container dengan Node ID: $node_id"
        if _run_node_container "$container" "$node_id" "$threads" "$wallet"; then
            log_success "Container $container berhasil dibuat ulang dan dimulai."
        else
            log_error "Gagal membuat ulang container $container."
        fi
    done
    
    log_success "Proses restart selesai."
    return 0
}

# Fungsi untuk menghapus node containers (pengganti stop_all_nodes)
delete_all_nodes() {
    local containers
    mapfile -t containers < <(docker ps -a --filter "name=nexus-node-" --format "{{.Names}}" | sort)
    
    if [ ${#containers[@]} -eq 0 ]; then
        log_warn "Tidak ada instance untuk dihapus."
        return 1
    fi
    
    log_info "Pilih node yang akan dihapus:"
    for i in "${!containers[@]}"; do
        local status node_id
        status=$(docker inspect -f '{{.State.Status}}' "${containers[i]}")
        node_id=$(docker inspect "${containers[i]}" --format '{{range .Config.Env}}{{if eq (index (split . "=") 0) "NODE_ID"}}{{(index (split . "=") 1)}}{{end}}{{end}}' 2>/dev/null || echo "N/A")
        local status_color="${COLOR_YELLOW}"
        if [[ "$status" == "running" ]]; then status_color="${COLOR_GREEN}"; fi
        echo -e "  ${COLOR_CYAN}[$((i+1))]${COLOR_RESET} ${containers[i]} (Node ID: ${node_id}) - Status: ${status_color}${status}${COLOR_RESET}"
    done
    echo -e "  ${COLOR_CYAN}[a]${COLOR_RESET} Hapus Semua"
    echo -e "  ${COLOR_CYAN}[0]${COLOR_RESET} Kembali"
    echo
    
    local choice
    prompt_user "Masukkan pilihan (pisahkan spasi untuk multiple): " choice
    
    if [[ "$choice" == "0" ]]; then
        return 1
    fi
    
    local targets=()
    if [[ "$choice" =~ ^[aA]$ ]]; then
        targets=("${containers[@]}")
    else
        for num in $choice; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -gt 0 ] && [ "$num" -le "${#containers[@]}" ]; then
                if [[ ! " ${targets[*]} " =~ " ${containers[$((num-1))]} " ]]; then
                    targets+=("${containers[$((num-1))]}")
                fi
            else
                log_error "Input tidak valid: '$num'. Harap masukkan nomor yang benar."
                return 1
            fi
        done
    fi
    
    if [ ${#targets[@]} -eq 0 ]; then
        log_warn "Tidak ada target yang dipilih untuk dihapus."
        return 1
    fi
    
    echo
    log_warn "Anda akan menghapus node berikut secara PERMANEN:"
    for target in "${targets[@]}"; do
        local node_id
        node_id=$(docker inspect "$target" --format '{{range .Config.Env}}{{if eq (index (split . "=") 0) "NODE_ID"}}{{(index (split . "=") 1)}}{{end}}{{end}}' 2>/dev/null || echo "N/A")
        echo -e "  - ${COLOR_YELLOW}${target}${COLOR_RESET} (Node ID: ${node_id})"
    done
    echo
    
    if ! prompt_confirm "Apakah Anda yakin ingin menghapus ${#targets[@]} container?"; then
        log_info "Penghapusan dibatalkan."
        return 1
    fi
    
    for target in "${targets[@]}"; do
        log_info "Menghapus container '$target'..."
        if docker rm -f "$target" >/dev/null 2>&1; then
            log_success "Container '$target' berhasil dihapus."
        else
            log_error "Gagal menghapus container '$target'."
        fi
    done
    
    log_success "Proses penghapusan selesai."
    return 0
}

# Menu terpadu untuk kontrol node dengan high performance
node_control_menu() {
    while true; do
        clear
        echo -e "${COLOR_CYAN}---[ 🎮 Node Control Center ]---${COLOR_RESET}"
        echo
        
        # Show current status summary
        local total_containers running_containers stopped_containers
        total_containers=$(docker ps -a --filter "name=nexus-node-" --format "{{.Names}}" | wc -l)
        running_containers=$(docker ps --filter "name=nexus-node-" --format "{{.Names}}" | wc -l)
        stopped_containers=$((total_containers - running_containers))
        
        echo -e "  ${COLOR_YELLOW}CURRENT STATUS${COLOR_RESET}"
        echo -e "    Total Nodes     : ${COLOR_GREEN}${total_containers}${COLOR_RESET}"
        echo -e "    Running Nodes   : ${COLOR_GREEN}${running_containers}${COLOR_RESET}"
        echo -e "    Stopped Nodes   : ${COLOR_YELLOW}${stopped_containers}${COLOR_RESET}"
        echo
        
        # Quick status overview
        if [[ $total_containers -gt 0 ]]; then
            echo -e "  ${COLOR_CYAN}NODE OVERVIEW${COLOR_RESET}"
            local containers
            mapfile -t containers < <(docker ps -a --filter "name=nexus-node-" --format "{{.Names}}" | sort)
            for container in "${containers[@]}"; do
                local status node_id status_icon status_color
                status=$(docker inspect -f '{{.State.Status}}' "$container")
                node_id=$(docker inspect "$container" --format '{{range .Config.Env}}{{if eq (index (split . "=") 0) "NODE_ID"}}{{(index (split . "=") 1)}}{{end}}{{end}}' 2>/dev/null || echo "N/A")
                
                case "$status" in
                    "running") status_icon="🟢"; status_color="${COLOR_GREEN}" ;;
                    "exited") status_icon="🔴"; status_color="${COLOR_RED}" ;;
                    "paused") status_icon="🟡"; status_color="${COLOR_YELLOW}" ;;
                    *) status_icon="⚫"; status_color="${COLOR_PURPLE}" ;;
                esac
                
                echo -e "    ${status_icon} ${COLOR_CYAN}${container}${COLOR_RESET} (ID: ${node_id}) - ${status_color}${status}${COLOR_RESET}"
            done
            echo
        fi
        
        echo -e "  ${COLOR_CYAN}BASIC CONTROL OPTIONS${COLOR_RESET}"
        echo -e "    ${COLOR_CYAN}1.${COLOR_RESET} ▶️ Start Node(s) - Jalankan node yang berhenti"
        echo -e "    ${COLOR_CYAN}2.${COLOR_RESET} ⏹️ Stop Node(s) - Hentikan node yang berjalan"
        echo -e "    ${COLOR_CYAN}3.${COLOR_RESET} 🔄 Restart Node(s) - Restart node (berjalan/berhenti)"
        echo -e "    ${COLOR_CYAN}4.${COLOR_RESET} 🗑️ Delete Node(s) - Hapus container secara permanen"
        echo
        echo -e "  ${COLOR_CYAN}ADVANCED OPTIONS${COLOR_RESET}"
        echo -e "    ${COLOR_CYAN}5.${COLOR_RESET} ⚡ High Performance Mode - Optimize and launch multiple instances"
        echo
        echo -e "    ${COLOR_CYAN}0.${COLOR_RESET} 🔙 Back to Main Menu"
        echo
        
        local choice
        prompt_user "Select Control Option: " choice
        echo
        
        local should_pause=false
        case "$choice" in
            1) start_existing_nodes && should_pause=true ;;
            2) stop_running_nodes && should_pause=true ;;
            3) restart_nodes && should_pause=true ;;
            4) delete_all_nodes && should_pause=true ;;
            5) high_performance_menu ;; # No pause needed, it has its own loop
            0) return ;;
            *) log_error "Invalid option." ; should_pause=true ;;
        esac
        
        if [ "$should_pause" = true ]; then
            echo
            prompt_user "Press Enter to continue..." "dummy_var"
        fi
    done
}

delete_instances() {
    local containers
    mapfile -t containers < <(docker ps -a --filter "name=nexus-node-" --format "{{.Names}}" | sort)

    if [ ${#containers[@]} -eq 0 ]; then
        log_warn "Tidak ada instance yang ditemukan untuk dihapus."
        return 1
    fi

    log_info "Pilih instance untuk dihapus:"
    for i in "${!containers[@]}"; do
        echo -e "  ${COLOR_CYAN}[$((i+1))]${COLOR_RESET} ${containers[i]}"
    done
    echo
    echo -e "  ${COLOR_CYAN}[a]${COLOR_RESET} Hapus Semua"
    echo -e "  ${COLOR_CYAN}[0]${COLOR_RESET} Batal"
    echo

    local choice
    prompt_user "Masukkan nomor (pisahkan spasi), atau 'a' untuk semua: " choice

    if [[ "$choice" == "0" ]]; then
        log_info "Penghapusan dibatalkan."
        return 1
    fi

    local targets_to_delete=()
    if [[ "$choice" =~ ^[aA]$ ]]; then
        targets_to_delete=("${containers[@]}")
    else
        for num in $choice; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -gt 0 ] && [ "$num" -le "${#containers[@]}" ]; then
                if [[ ! " ${targets_to_delete[*]} " =~ " ${containers[$((num-1))]} " ]]; then
                    targets_to_delete+=("${containers[$((num-1))]}")
                fi
            else
                log_error "Input tidak valid: '$num'. Harap masukkan nomor yang benar dari daftar."
                return 1
            fi
        done
    fi

    if [ ${#targets_to_delete[@]} -eq 0 ]; then
        log_warn "Tidak ada target yang dipilih untuk dihapus."
        return 1
    fi

    echo
    log_warn "Anda akan menghapus instance berikut secara permanen:"
    for target in "${targets_to_delete[@]}"; do
        echo -e "  - ${COLOR_YELLOW}${target}${COLOR_RESET}"
    done
    echo

    if prompt_confirm "Apakah Anda yakin ingin melanjutkan?"; then
        for target in "${targets_to_delete[@]}"; do
            log_info "Menghapus kontainer '$target'..."
            if ! docker rm -f "$target" >/dev/null; then
                log_error "Gagal menghapus kontainer '$target'."
            else
                log_success "Kontainer '$target' berhasil dihapus."
            fi
        done
    else
        log_info "Penghapusan dibatalkan."
        return 1
    fi
    return 0
}

manage_instances_menu() {
    while true; do
        clear
        echo -e "${COLOR_CYAN}---[ Edit Instance ]---${COLOR_RESET}"
        echo
        echo -e "  ${COLOR_CYAN}1.${COLOR_RESET} ➕   Tambah Satu Instance Baru"
        echo -e "  ${COLOR_CYAN}2.${COLOR_RESET} ➕➕ Mulai Beberapa Instance"
        echo -e "  ${COLOR_CYAN}3.${COLOR_RESET} 🗑️   Hapus Instance"
        echo
        echo -e "  ${COLOR_CYAN}0.${COLOR_RESET} 🔙 Kembali ke Menu Utama"
        echo
        
        local choice
        prompt_user "Pilih Opsi: " choice

        local should_pause=false
        case "$choice" in
            1) add_one_instance && should_pause=true ;;
            2) start_multiple_instances && should_pause=true ;;
            3) delete_instances && should_pause=true ;;
            0) return ;;
            *) log_error "Pilihan tidak valid." ; should_pause=true ;;
        esac
        
        if [ "$should_pause" = true ]; then
            prompt_user "Tekan Enter untuk kembali ke menu edit..." "dummy_var"
        fi
    done
}

restart_a_node() { 
    local containers; mapfile -t containers < <(docker ps -a --filter "name=nexus-node-" --format "{{.Names}}" | sort)
    if [ ${#containers[@]} -eq 0 ]; then
        log_warn "Tidak ada instance yang ditemukan untuk di-restart."
        return 1
    fi
    
    log_info "Pilih node untuk di-restart (termasuk yang berhenti):"
    for i in "${!containers[@]}"; do
        local status; status=$(docker inspect -f '{{.State.Status}}' "${containers[i]}");
        local status_color="${COLOR_YELLOW}"; if [[ "$status" == "running" ]]; then status_color="${COLOR_GREEN}"; fi
        echo -e "  [${COLOR_CYAN}$((i+1))${COLOR_RESET}] ${containers[i]} - Status: ${status_color}${status}${COLOR_RESET}"
    done
    echo -e "  [${COLOR_CYAN}a${COLOR_RESET}] Semua"
    echo -e "  [${COLOR_CYAN}0${COLOR_RESET}] Kembali"

    local choice; prompt_user "Pilihan: " choice
    local targets=(); case "$choice" in 0) return 1 ;; [aA]) targets=("${containers[@]}");; *) if [[ "$choice" =~ ^[0-9]+$ && "$choice" -gt 0 && "$choice" -le "${#containers[@]}" ]]; then targets=("${containers[$((choice-1))]}"); else log_error "Pilihan tidak valid."; return 1; fi;; esac
    
    for container in "${targets[@]}"; do
        log_info "Me-restart/memulai $container..."
        
        # Try simple restart first
        if docker restart "$container" >/dev/null 2>&1; then
            log_success "Container $container berhasil di-restart."
            continue
        fi
        
        # If restart fails, recreate the container
        log_warn "Restart gagal, mencoba membuat ulang container $container..."
        
        # Get container configuration
        local node_id threads wallet
        node_id=$(docker inspect "$container" --format '{{range .Config.Env}}{{if eq (index (split . "=") 0) "NODE_ID"}}{{(index (split . "=") 1)}}{{end}}{{end}}' 2>/dev/null || echo "")
        threads=$(docker inspect "$container" --format '{{range .Config.Env}}{{if eq (index (split . "=") 0) "MAX_THREADS"}}{{(index (split . "=") 1)}}{{end}}{{end}}' 2>/dev/null || echo "$DEFAULT_THREADS")
        wallet=$(docker inspect "$container" --format '{{range .Config.Env}}{{if eq (index (split . "=") 0) "WALLET_ADDRESS"}}{{(index (split . "=") 1)}}{{end}}{{end}}' 2>/dev/null || echo "")
        
        if [[ -z "$node_id" ]]; then
            log_error "Tidak dapat membaca konfigurasi container $container. Lewati..."
            continue
        fi
        
        # Remove broken container
        log_info "Menghapus container rusak..."
        docker rm -f "$container" >/dev/null 2>&1
        
        # Recreate container
        log_info "Membuat ulang container dengan Node ID: $node_id"
        if _run_node_container "$container" "$node_id" "$threads" "$wallet"; then
            log_success "Container $container berhasil dibuat ulang dan dimulai."
        else
            log_error "Gagal membuat ulang container $container."
        fi
    done
    log_success "Proses restart selesai."
    return 0
}

view_node_logs() {
    while true; do
        clear
        echo -e "${COLOR_CYAN}---[ 📜 Log Viewer Options ]---${COLOR_RESET}"
        echo
        echo -e "  ${COLOR_CYAN}1.${COLOR_RESET} 📋 View Single Node Log"
        echo -e "  ${COLOR_CYAN}2.${COLOR_RESET} 🔄 View All Nodes Live (Multi-Tail)"
        echo -e "  ${COLOR_CYAN}3.${COLOR_RESET} 📊 View Recent Activity Summary"
        echo -e "  ${COLOR_CYAN}4.${COLOR_RESET} 🔍 Search Logs"
        echo
        echo -e "  ${COLOR_CYAN}0.${COLOR_RESET} 🔙 Back to Main Menu"
        echo
        
        local choice
        prompt_user "Select Log Option: " choice
        echo
        
        case "$choice" in
            1) view_single_node_log && return 1 ;;
            2) view_all_nodes_live && return 1 ;;
            3) view_activity_summary && prompt_user "Press Enter to continue..." "dummy_var" ;;
            4) search_logs && prompt_user "Press Enter to continue..." "dummy_var" ;;
            0) return ;;
            *) log_error "Invalid option." ; prompt_user "Press Enter to continue..." "dummy_var" ;;
        esac
    done
}

view_single_node_log() {
    while true; do
        local container
        if ! _select_container "Pilih kontainer untuk melihat log:" container; then 
            return 1
        fi
        
        clear
        echo -e "${COLOR_BLUE}╭─ 📜 Log Options untuk: ${COLOR_GREEN}$container${COLOR_BLUE} ─╮${COLOR_RESET}"
        echo
        echo -e "  ${COLOR_CYAN}1.${COLOR_RESET} 🔄 View Live Logs (Follow Mode)"
        echo -e "  ${COLOR_CYAN}2.${COLOR_RESET} 📄 View Recent Logs (Static)"
        echo -e "  ${COLOR_CYAN}3.${COLOR_RESET} 🔍 View Last N Lines"
        echo
        echo -e "  ${COLOR_CYAN}0.${COLOR_RESET} 🔙 Back to Log Menu"
        echo
        
        local log_choice
        prompt_user "Select Log Option: " log_choice
        echo
        
        case "$log_choice" in
            1)
                clear
                echo -e "${COLOR_BLUE}╭─ 📜 Live Log untuk: ${COLOR_GREEN}$container ${COLOR_CYAN}(Press 'q' then Enter to quit) ─╮${COLOR_RESET}"
                echo -e "${COLOR_YELLOW}💡 Tip: Type 'q' and press Enter to return to menu safely${COLOR_RESET}"
                echo
                
                # Create a background process for docker logs
                local temp_fifo
                temp_fifo=$(mktemp -u)
                mkfifo "$temp_fifo" 2>/dev/null || temp_fifo="/tmp/nexus_log_$$"
                
                # Start docker logs in background
                (docker logs -f --tail=50 "$container" 2>&1 > "$temp_fifo") &
                local docker_pid=$!
                
                # Read from fifo with user input monitoring
                (
                    while IFS= read -r line < "$temp_fifo"; do
                        case "$line" in 
                            *Error*|*error*|*ERROR*) 
                                echo -e "${COLOR_RED}${line}${COLOR_RESET}"
                                ;;
                            *"Proof submitted successfully"*) 
                                echo -e "${COLOR_GREEN}✅ ${line}${COLOR_RESET}"
                                ;;
                            *"Submitting proof"*) 
                                echo -e "${COLOR_YELLOW}📤 ${line}${COLOR_RESET}"
                                ;;
                            *"Fetching task"*|*"Waiting"*|*"ready"*) 
                                echo -e "${COLOR_CYAN}⏳ ${line}${COLOR_RESET}"
                                ;;
                            *"Task completed"*|*"Got task"*|*"Proving"*) 
                                echo -e "${COLOR_PURPLE}⚡ ${line}${COLOR_RESET}"
                                ;;
                            *) 
                                echo "$line"
                                ;;
                        esac
                    done
                ) &
                local reader_pid=$!
                
                # Monitor for user input
                while true; do
                    local user_input
                    read -r user_input
                    if [[ "$user_input" == "q" ]] || [[ "$user_input" == "Q" ]] || [[ "$user_input" == "0" ]]; then
                        break
                    fi
                done
                
                # Cleanup
                kill $docker_pid $reader_pid 2>/dev/null || true
                rm -f "$temp_fifo" 2>/dev/null || true
                echo -e "\n${COLOR_YELLOW}📜 Live log viewer stopped.${COLOR_RESET}"
                prompt_user "Press Enter to continue..." "dummy_var"
                ;;
            2)
                clear
                echo -e "${COLOR_BLUE}╭─ 📄 Recent Logs untuk: ${COLOR_GREEN}$container${COLOR_BLUE} ─╮${COLOR_RESET}"
                echo
                
                # Show last 100 lines of logs
                local logs
                logs=$(docker logs --tail=100 "$container" 2>&1)
                
                if [[ -n "$logs" ]]; then
                    echo "$logs" | while IFS= read -r line; do
                        case "$line" in 
                            *Error*|*error*|*ERROR*) 
                                echo -e "${COLOR_RED}${line}${COLOR_RESET}"
                                ;;
                            *"Proof submitted successfully"*) 
                                echo -e "${COLOR_GREEN}✅ ${line}${COLOR_RESET}"
                                ;;
                            *"Submitting proof"*) 
                                echo -e "${COLOR_YELLOW}📤 ${line}${COLOR_RESET}"
                                ;;
                            *"Fetching task"*|*"Waiting"*|*"ready"*) 
                                echo -e "${COLOR_CYAN}⏳ ${line}${COLOR_RESET}"
                                ;;
                            *"Task completed"*|*"Got task"*|*"Proving"*) 
                                echo -e "${COLOR_PURPLE}⚡ ${line}${COLOR_RESET}"
                                ;;
                            *) 
                                echo "$line"
                                ;;
                        esac
                    done
                else
                    log_warn "No logs available for $container"
                fi
                echo
                prompt_user "Press Enter to continue..." "dummy_var"
                ;;
            3)
                local num_lines
                prompt_user "Enter number of lines to show (default: 50): " num_lines
                num_lines=${num_lines:-50}
                
                if [[ ! "$num_lines" =~ ^[0-9]+$ ]]; then
                    log_error "Invalid number format"
                    continue
                fi
                
                clear
                echo -e "${COLOR_BLUE}╭─ 📄 Last $num_lines lines untuk: ${COLOR_GREEN}$container${COLOR_BLUE} ─╮${COLOR_RESET}"
                echo
                
                local logs
                logs=$(docker logs --tail="$num_lines" "$container" 2>&1)
                
                if [[ -n "$logs" ]]; then
                    echo "$logs" | while IFS= read -r line; do
                        case "$line" in 
                            *Error*|*error*|*ERROR*) 
                                echo -e "${COLOR_RED}${line}${COLOR_RESET}"
                                ;;
                            *"Proof submitted successfully"*) 
                                echo -e "${COLOR_GREEN}✅ ${line}${COLOR_RESET}"
                                ;;
                            *"Submitting proof"*) 
                                echo -e "${COLOR_YELLOW}📤 ${line}${COLOR_RESET}"
                                ;;
                            *"Fetching task"*|*"Waiting"*|*"ready"*) 
                                echo -e "${COLOR_CYAN}⏳ ${line}${COLOR_RESET}"
                                ;;
                            *"Task completed"*|*"Got task"*|*"Proving"*) 
                                echo -e "${COLOR_PURPLE}⚡ ${line}${COLOR_RESET}"
                                ;;
                            *) 
                                echo "$line"
                                ;;
                        esac
                    done
                else
                    log_warn "No logs available for $container"
                fi
                echo
                prompt_user "Press Enter to continue..." "dummy_var"
                ;;
            0)
                return 1
                ;;
            *)
                log_error "Invalid option"
                prompt_user "Press Enter to continue..." "dummy_var"
                ;;
        esac
    done
}

view_all_nodes_live() {
    local containers
    mapfile -t containers < <(docker ps --filter "name=nexus-node-" --format "{{.Names}}" | sort)
    
    if [[ ${#containers[@]} -eq 0 ]]; then
        log_warn "No running containers found"
        return 1
    fi
    
    clear
    echo -e "${COLOR_BLUE}╭─ 🔄 Live Multi-Node Log Viewer ${COLOR_CYAN}(Type 'q' and Enter to quit) ─╮${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}📊 Monitoring ${#containers[@]} nodes: ${containers[*]}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}💡 Instructions: Type 'q' then press Enter to return to menu${COLOR_RESET}"
    printf "${COLOR_BLUE}%70s${COLOR_RESET}\n" | tr ' ' '─'
    echo
    
    # Create named pipes for each container
    local temp_dir
    temp_dir=$(mktemp -d)
    local pids=()
    
    # Color mapping for containers
    local colors=("${COLOR_GREEN}" "${COLOR_CYAN}" "${COLOR_YELLOW}" "${COLOR_PURPLE}" "${COLOR_BLUE}")
    
    # Function to format log line with container info
    format_multi_log() {
        local container_name="$1"
        local container_color="$2"
        local short_name="${container_name#nexus-node-}"
        
        while IFS= read -r line; do
            local timestamp=$(date '+%H:%M:%S')
            local formatted_line
            
            # Color code different log types
            case "$line" in
                *"Error"*|*"error"*|*"ERROR"*)
                    formatted_line="${COLOR_RED}${line}${COLOR_RESET}"
                    ;;
                *"Proof submitted successfully"*)
                    formatted_line="${COLOR_GREEN}✅ ${line}${COLOR_RESET}"
                    ;;
                *"Submitting proof"*)
                    formatted_line="${COLOR_YELLOW}📤 ${line}${COLOR_RESET}"
                    ;;
                *"Fetching task"*|*"Waiting"*|*"ready"*)
                    formatted_line="${COLOR_CYAN}⏳ ${line}${COLOR_RESET}"
                    ;;
                *"Task completed"*|*"Got task"*|*"Proving"*)
                    formatted_line="${COLOR_PURPLE}⚡ ${line}${COLOR_RESET}"
                    ;;
                *)
                    formatted_line="$line"
                    ;;
            esac
            
            echo -e "${COLOR_BLUE}[$timestamp]${COLOR_RESET} ${container_color}[Node-$short_name]${COLOR_RESET} $formatted_line"
        done
    }
    
    # Start log tailing for each container in background
    for i in "${!containers[@]}"; do
        local container="${containers[$i]}"
        local color="${colors[$((i % ${#colors[@]}))]}"
        
        # Start docker logs in background with formatting
        docker logs -f --tail=10 "$container" 2>&1 | format_multi_log "$container" "$color" &
        pids+=("$!")
    done
    
    # Monitor for user input to quit
    local start_time=$(date +%s)
    while true; do
        # Check for user input with timeout
        local user_input
        if read -t 1 user_input 2>/dev/null; then
            if [[ "$user_input" == "q" ]] || [[ "$user_input" == "Q" ]] || [[ "$user_input" == "0" ]]; then
                break
            fi
        fi
        
        # Update runtime display every 5 seconds
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        local minutes=$((elapsed / 60))
        local seconds=$((elapsed % 60))
        
        if [[ $((elapsed % 5)) -eq 0 ]]; then
            printf "\r${COLOR_BLUE}📊 Runtime: %02d:%02d | Type 'q' + Enter to quit${COLOR_RESET}" "$minutes" "$seconds"
        fi
    done
    
    echo
    echo -e "${COLOR_YELLOW}🛑 Stopping live log viewer...${COLOR_RESET}"
    
    # Cleanup background processes
    for pid in "${pids[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    rm -rf "$temp_dir" 2>/dev/null || true
    
    echo -e "${COLOR_GREEN}✅ Live log viewer stopped.${COLOR_RESET}"
    prompt_user "Press Enter to continue..." "dummy_var"
    return 0
}

view_activity_summary() {
    log_info "Recent Activity Summary (Last 24 Hours)"
    echo
    
    local containers
    mapfile -t containers < <(docker ps --filter "name=nexus-node-" --format "{{.Names}}" | sort)
    
    if [[ ${#containers[@]} -eq 0 ]]; then
        log_warn "No running containers found"
        return 1
    fi
    
    local total_proofs=0
    local total_errors=0
    local total_tasks=0
    
    for container in "${containers[@]}"; do
        local node_id
        node_id=$(docker inspect "$container" --format '{{range .Config.Env}}{{if eq (index (split . "=") 0) "NODE_ID"}}{{(index (split . "=") 1)}}{{end}}{{end}}')
        local short_name="${container#nexus-node-}"
        
        echo -e "  ${COLOR_GREEN}● Node-$short_name${COLOR_RESET} (ID: ${node_id:-N/A})"
        
        # Get logs from last 24 hours
        local logs
        logs=$(docker logs --since="24h" "$container" 2>&1 || echo "")
        
        if [[ -n "$logs" ]]; then
            local proofs_count
            local errors_count
            local tasks_count
            local last_activity
            
            # Safe counting with proper fallback
            proofs_count=$(echo "$logs" | grep -c "Proof submitted successfully" 2>/dev/null || echo "0")
            errors_count=$(echo "$logs" | grep -c -i "error\|failed" 2>/dev/null || echo "0")
            tasks_count=$(echo "$logs" | grep -c "Got task\|Task completed" 2>/dev/null || echo "0")
            last_activity=$(echo "$logs" | tail -1 | head -c 80 2>/dev/null || echo "No recent activity")
            
            # Validate numbers before arithmetic
            [[ "$proofs_count" =~ ^[0-9]+$ ]] || proofs_count=0
            [[ "$errors_count" =~ ^[0-9]+$ ]] || errors_count=0
            [[ "$tasks_count" =~ ^[0-9]+$ ]] || tasks_count=0
            
            total_proofs=$((total_proofs + proofs_count))
            total_errors=$((total_errors + errors_count))
            total_tasks=$((total_tasks + tasks_count))
            
            echo -e "    ${COLOR_BLUE}├─ Proofs Submitted : ${COLOR_GREEN}${proofs_count}${COLOR_RESET}"
            echo -e "    ${COLOR_BLUE}├─ Tasks Processed  : ${COLOR_CYAN}${tasks_count}${COLOR_RESET}"
            echo -e "    ${COLOR_BLUE}├─ Errors/Warnings  : ${COLOR_RED}${errors_count}${COLOR_RESET}"
            echo -e "    ${COLOR_BLUE}└─ Last Activity    : ${COLOR_YELLOW}${last_activity}...${COLOR_RESET}"
        else
            echo -e "    ${COLOR_YELLOW}└─ No logs available${COLOR_RESET}"
        fi
        echo
    done
    
    printf "${COLOR_BLUE}%60s${COLOR_RESET}\n" | tr ' ' '='
    echo -e "  ${COLOR_YELLOW}📊 TOTAL SUMMARY (Last 24h)${COLOR_RESET}"
    echo -e "    ${COLOR_GREEN}✅ Total Proofs Submitted : $total_proofs${COLOR_RESET}"
    echo -e "    ${COLOR_CYAN}⚡ Total Tasks Processed  : $total_tasks${COLOR_RESET}"
    echo -e "    ${COLOR_RED}❌ Total Errors/Warnings  : $total_errors${COLOR_RESET}"
    echo -e "    ${COLOR_PURPLE}🖥️  Active Nodes          : ${#containers[@]}${COLOR_RESET}"
    printf "${COLOR_BLUE}%60s${COLOR_RESET}\n" | tr ' ' '='
}

search_logs() {
    local search_term
    prompt_user "Enter search term (regex supported): " search_term
    
    if [[ -z "$search_term" ]]; then
        log_error "Search term cannot be empty"
        return 1
    fi
    
    log_info "Searching for: '$search_term' in all node logs..."
    echo
    
    local containers
    mapfile -t containers < <(docker ps --filter "name=nexus-node-" --format "{{.Names}}" | sort)
    
    if [[ ${#containers[@]} -eq 0 ]]; then
        log_warn "No running containers found"
        return 1
    fi
    
    local total_matches=0
    
    for container in "${containers[@]}"; do
        local node_id
        node_id=$(docker inspect "$container" --format '{{range .Config.Env}}{{if eq (index (split . "=") 0) "NODE_ID"}}{{(index (split . "=") 1)}}{{end}}{{end}}')
        local short_name="${container#nexus-node-}"
        
        echo -e "${COLOR_CYAN}🔍 Searching in Node-$short_name (ID: ${node_id:-N/A})${COLOR_RESET}"
        
        local matches
        matches=$(docker logs --since="24h" "$container" 2>&1 | grep -n -i "$search_term" || echo "")
        
        if [[ -n "$matches" ]]; then
            local match_count
            match_count=$(echo "$matches" | wc -l)
            total_matches=$((total_matches + match_count))
            
            echo -e "  ${COLOR_GREEN}✅ Found $match_count matches:${COLOR_RESET}"
            echo "$matches" | head -10 | while IFS=':' read -r line_num content; do
                echo -e "    ${COLOR_YELLOW}Line $line_num:${COLOR_RESET} $content"
            done
            
            if [[ $match_count -gt 10 ]]; then
                echo -e "    ${COLOR_BLUE}... and $((match_count - 10)) more matches${COLOR_RESET}"
            fi
        else
            echo -e "  ${COLOR_RED}❌ No matches found${COLOR_RESET}"
        fi
        echo
    done
    
    printf "${COLOR_BLUE}%50s${COLOR_RESET}\n" | tr ' ' '='
    echo -e "  ${COLOR_YELLOW}📊 Search completed. Total matches: $total_matches${COLOR_RESET}"
    printf "${COLOR_BLUE}%50s${COLOR_RESET}\n" | tr ' ' '='
}

docker_prune() {
    log_warn "Perintah ini akan menghapus semua kontainer yang berhenti,"
    log_warn "semua image yang tidak terpakai, dan semua cache build."
    if prompt_confirm "Apakah Anda yakin ingin melanjutkan?"; then
        log_info "Memulai pembersihan Docker yang komprehensif..."
        
        # Step 1: Stop all nexus containers first
        local running_containers
        running_containers=$(docker ps -q --filter "name=nexus-node-" 2>/dev/null || echo "")
        if [[ -n "$running_containers" ]]; then
            log_info "Menghentikan semua container nexus yang sedang berjalan..."
            if ! echo "$running_containers" | xargs docker stop >/dev/null 2>&1; then
                log_warn "Beberapa container mungkin gagal dihentikan"
            else
                log_success "Container nexus berhasil dihentikan"
            fi
        fi
        
        # Step 2: Remove all containers (stopped and running)
        local all_containers
        all_containers=$(docker ps -aq --filter "name=nexus-node-" 2>/dev/null || echo "")
        if [[ -n "$all_containers" ]]; then
            log_info "Menghapus semua container nexus..."
            if ! echo "$all_containers" | xargs docker rm -f >/dev/null 2>&1; then
                log_warn "Beberapa container mungkin gagal dihapus"
            else
                log_success "Container nexus berhasil dihapus"
            fi
        fi
        
        # Step 3: Remove all stopped containers
        log_info "Membersihkan container yang berhenti..."
        if docker container prune -f >/dev/null 2>&1; then
            log_success "Container yang berhenti berhasil dibersihkan"
        else
            log_warn "Gagal membersihkan beberapa container"
        fi
        
        # Step 4: Remove unused images  
        log_info "Menghapus image yang tidak terpakai..."
        if docker image prune -a -f >/dev/null 2>&1; then
            log_success "Image yang tidak terpakai berhasil dihapus"
        else
            log_warn "Gagal menghapus beberapa image"
        fi
        
        # Step 5: Remove build cache
        log_info "Membersihkan build cache..."
        if docker builder prune -a -f >/dev/null 2>&1; then
            log_success "Build cache berhasil dibersihkan"
        else
            log_warn "Gagal membersihkan build cache"
        fi
        
        # Step 6: Remove unused volumes
        log_info "Membersihkan volume yang tidak terpakai..."
        if docker volume prune -f >/dev/null 2>&1; then
            log_success "Volume yang tidak terpakai berhasil dihapus"
        else
            log_warn "Gagal menghapus beberapa volume"
        fi
        
        # Step 7: Remove unused networks
        log_info "Membersihkan network yang tidak terpakai..."
        if docker network prune -f >/dev/null 2>&1; then
            log_success "Network yang tidak terpakai berhasil dihapus"
        else
            log_warn "Gagal menghapus beberapa network"
        fi
        
        # Step 8: Final comprehensive cleanup
        log_info "Menjalankan pembersihan sistem menyeluruh..."
        if docker system prune -a -f >/dev/null 2>&1; then
            log_success "Pembersihan sistem menyeluruh berhasil"
        else
            log_warn "Pembersihan sistem menyeluruh selesai dengan peringatan"
        fi
        
        # Show final status
        log_info "Menampilkan status akhir sistem Docker..."
        echo
        docker system df || log_warn "Gagal menampilkan status sistem"
        echo
        
        log_success "🧹 Pembersihan Docker selesai! Sistem sudah bersih."
        
        # Clean up nexus-manager specific directories if they exist
        if [[ -d "$LOG_DIR" ]]; then
            log_info "Membersihkan log directory..."
            rm -rf "${LOG_DIR}"/* 2>/dev/null || true
        fi
        
        if [[ -d "$HEALTH_CHECK_DIR" ]]; then
            log_info "Membersihkan health check directory..."
            rm -rf "${HEALTH_CHECK_DIR}"/* 2>/dev/null || true
        fi
        
        if [[ -f "$PID_FILE" ]]; then
            log_info "Membersihkan PID file..."
            rm -f "$PID_FILE" 2>/dev/null || true
        fi
        
        log_success "✨ Pembersihan lengkap selesai! Siap untuk memulai fresh."
        
    else
        log_info "Pembersihan dibatalkan."
        return 1
    fi
    return 0
}

# ╭───────────────────────────────────────────────────────────────────╮
# │ 📊 DASHBOARD & LOOP UTAMA (Tampilan Minimalis Baru)               │
# ╰───────────────────────────────────────────────────────────────────╯

_calculate_uptime() {
    local container="$1"
    local created started restarts now
    
    # Get container timing info
    created=$(docker inspect --format '{{.Created}}' "$container" 2>/dev/null || echo "")
    started=$(docker inspect --format '{{.State.StartedAt}}' "$container" 2>/dev/null || echo "")
    restarts=$(docker inspect --format '{{.RestartCount}}' "$container" 2>/dev/null || echo "0")
    
    # Check if we got valid data
    if [[ -z "$created" || -z "$started" ]]; then
        echo "N/A"
        return
    fi
    
    # Get current time in seconds
    now=$(date +%s 2>/dev/null || echo "0")
    
    # Convert timestamps to seconds since epoch
    local created_ts started_ts
    created_ts=$(date -d "$created" +%s 2>/dev/null || echo "0")
    started_ts=$(date -d "$started" +%s 2>/dev/null || echo "0")
    
    # Validate timestamps
    if [[ ! "$created_ts" =~ ^[0-9]+$ ]] || [[ ! "$started_ts" =~ ^[0-9]+$ ]] || [[ ! "$now" =~ ^[0-9]+$ ]]; then
        echo "N/A"
        return
    fi
    
    if [[ "$created_ts" == "0" ]] || [[ "$started_ts" == "0" ]] || [[ "$now" == "0" ]]; then
        echo "N/A"
        return
    fi
    
    # Calculate total uptime
    local total_seconds
    if [[ "$restarts" -gt 0 ]]; then
        # If container was restarted, add previous uptime
        local prev_uptime=$((created_ts - started_ts))
        local curr_uptime=$((now - started_ts))
        total_seconds=$((prev_uptime + curr_uptime))
    else
        # No restarts, simple calculation
        total_seconds=$((now - started_ts))
    fi
    
    # Validate result
    if [[ $total_seconds -lt 0 ]]; then
        echo "N/A"
        return
    fi
    
    # Format uptime
    local days hours minutes
    days=$((total_seconds / 86400))
    hours=$(((total_seconds % 86400) / 3600))
    minutes=$(((total_seconds % 3600) / 60))
    
    if [[ $days -gt 0 ]]; then
        printf "%dd%dh" "$days" "$hours"
    elif [[ $hours -gt 0 ]]; then
        printf "%dh%dm" "$hours" "$minutes"
    else
        printf "%dm" "$minutes"
    fi
}

display_dashboard() {
    clear
    
    # Title and header  
    echo -e "${COLOR_CYAN}╭─────────────────────────────────────────────────────────────────────────────╮${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│                      ${COLOR_GREEN}⚡ NEXUS NODE MANAGER DASHBOARD ⚡${COLOR_CYAN}                     │${COLOR_RESET}"
    echo -e "${COLOR_CYAN}╰─────────────────────────────────────────────────────────────────────────────╯${COLOR_RESET}"
    echo
    
    # System Information - Enhanced with more indicators
    local total_cores total_ram_gb used_ram_gb network_status system_uptime docker_version
    total_cores=$(nproc 2>/dev/null || echo "4")
    
    # Get RAM information
    if command -v free &>/dev/null; then
        total_ram_gb=$(free -g | awk '/^Mem:/{print $2}')
        used_ram_gb=$(free -g | awk '/^Mem:/{print $3}')
    else
        # Windows fallback
        total_ram_gb=$(powershell.exe -Command "[math]::Round((Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum).Sum / 1GB)" 2>/dev/null || echo "8")
        used_ram_gb=$(powershell.exe -Command "[math]::Round((Get-CimInstance Win32_OperatingSystem).TotalVirtualMemorySize/1MB - (Get-CimInstance Win32_OperatingSystem).FreeVirtualMemory/1MB)" 2>/dev/null || echo "4")
    fi
    
    # Get network status
    if command -v ping &>/dev/null; then
        if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
            network_status="✓"
        else
            network_status="✗"
        fi
    else
        # Windows fallback
        if ping -n 1 8.8.8.8 >nul 2>&1; then
            network_status="✓"
        else
            network_status="✗"
        fi
    fi
    
    # Get system uptime
    if command -v uptime &>/dev/null; then
        system_uptime=$(uptime -p 2>/dev/null | sed 's/up //' || echo "N/A")
    else
        # Windows fallback
        system_uptime=$(powershell.exe -Command "(Get-CimInstance Win32_OperatingSystem).LastBootUpTime | ForEach-Object { [math]::Round(((Get-Date) - \$_).TotalHours) }" 2>/dev/null || echo "N/A")
        if [[ "$system_uptime" =~ ^[0-9]+$ ]]; then
            system_uptime="${system_uptime}h"
        fi
    fi
    
    # Get Docker version (short)
    docker_version=$(docker --version 2>/dev/null | awk '{print $3}' | sed 's/,//' | cut -c1-6 || echo "N/A")
    
    # RAM usage color coding
    local ram_color="${COLOR_GREEN}"
    if [[ "$used_ram_gb" =~ ^[0-9]+$ ]] && [[ "$total_ram_gb" =~ ^[0-9]+$ ]] && [[ $total_ram_gb -gt 0 ]]; then
        local ram_usage_percent=$((used_ram_gb * 100 / total_ram_gb))
        if [[ $ram_usage_percent -gt 80 ]]; then
            ram_color="${COLOR_RED}"
        elif [[ $ram_usage_percent -gt 60 ]]; then
            ram_color="${COLOR_YELLOW}"
        fi
    fi
    
    # Network status color coding
    local network_color="${COLOR_GREEN}"
    if [[ "$network_status" == "✗" ]]; then
        network_color="${COLOR_RED}"
    fi
    
    # Node status summary - Initialize variables first
    local total_containers running_count stopped_count
    mapfile -t all_containers_temp < <(docker ps -a --filter "name=nexus-node-" --format "{{.Names}}" 2>/dev/null)
    mapfile -t running_containers_temp < <(docker ps --filter "name=nexus-node-" --format "{{.Names}}" 2>/dev/null)
    mapfile -t stopped_containers_temp < <(docker ps -a --filter "name=nexus-node-" --filter "status=exited" --format "{{.Names}}" 2>/dev/null)
    
    total_containers=${#all_containers_temp[@]}
    running_count=${#running_containers_temp[@]}
    stopped_count=${#stopped_containers_temp[@]}
    
    # Calculate total tasks across all nodes
    local total_tasks=0
    local task_display="0"
    local task_color="${COLOR_PURPLE}"
    
    if [[ $running_count -gt 0 ]]; then
        # Sum up tasks from all running containers
        for container in "${running_containers_temp[@]}"; do
            if [[ -n "$container" ]]; then
                # Get task count from logs (24h period)
                local container_tasks=0
                
                if container_logs=$(docker logs --since="24h" "$container" 2>/dev/null); then
                    if [[ -n "$container_logs" ]]; then
                        # Count proofs and task completions
                        local proof_count task_count
                        proof_count=$(echo "$container_logs" | grep -c "Proof submitted successfully\|Successfully submitted" 2>/dev/null || echo "0")
                        task_count=$(echo "$container_logs" | grep -c "Got task\|Task completed" 2>/dev/null || echo "0")
                        
                        # Validate numbers
                        [[ "$proof_count" =~ ^[0-9]+$ ]] || proof_count=0
                        [[ "$task_count" =~ ^[0-9]+$ ]] || task_count=0
                        
                        # Use the higher count as indicator
                        container_tasks=$(( proof_count > task_count ? proof_count : task_count ))
                    fi
                fi
                
                # Add to total
                total_tasks=$((total_tasks + container_tasks))
            fi
        done
        
        task_display="$total_tasks"
        
        # Color coding based on total tasks
        if [[ $total_tasks -ge 100 ]]; then
            task_color="${COLOR_GREEN}"
        elif [[ $total_tasks -ge 50 ]]; then
            task_color="${COLOR_CYAN}"
        elif [[ $total_tasks -ge 20 ]]; then
            task_color="${COLOR_YELLOW}"
        elif [[ $total_tasks -gt 0 ]]; then
            task_color="${COLOR_RED}"
        else
            task_color="${COLOR_PURPLE}"
        fi
    else
        task_display="0"
        task_color="${COLOR_PURPLE}"
    fi
    
    # Enhanced system info with device RAM and total tasks
    echo -e "   ${COLOR_PURPLE}💻 System:${COLOR_RESET} ${COLOR_GREEN}${total_cores} cores${COLOR_RESET} | ${ram_color}${used_ram_gb}/${total_ram_gb}GB RAM${COLOR_RESET} | ${task_color}${task_display} tasks${COLOR_RESET}"
    
    echo
    
    # Table header with title-style border
    echo -e "${COLOR_CYAN}╭─────────────────────────────────────────────────────────────────────────────╮${COLOR_RESET}"
    printf "${COLOR_CYAN}│${COLOR_RESET} ${COLOR_CYAN}%-18s%-12s %-11s%-10s %-9s   %-4s${COLOR_RESET} ${COLOR_CYAN}     │${COLOR_RESET}\n" \
           "CONTAINER" "NODE ID" "UPTIME" "CPU%" "RAM" "TASKS" 
    echo -e "${COLOR_CYAN}╰─────────────────────────────────────────────────────────────────────────────╯${COLOR_RESET}"
    echo
    
    # Container info - Simple format
    local containers=()
    
    # Check Docker availability before executing commands
    if ! command -v docker &>/dev/null; then
        echo -e "${COLOR_RED}❌ No running Docker found. Please install Docker.${COLOR_RESET}"
        echo -e "${COLOR_CYAN}💡 Install Docker first, then restart this manager.${COLOR_RESET}"
        return
    elif ! docker info &>/dev/null 2>&1; then
        echo -e "${COLOR_RED}❌ Docker is installed but not running. Please start Docker.${COLOR_RESET}"
        echo -e "${COLOR_CYAN}💡 Start Docker service and restart this manager.${COLOR_RESET}"
        return
    fi
    
    # Docker is available, now get ALL containers (running and stopped)
    local running_containers stopped_containers all_containers
    mapfile -t running_containers < <(docker ps --filter "name=nexus-node-" --format "{{.Names}}" 2>/dev/null | sort)
    mapfile -t stopped_containers < <(docker ps -a --filter "name=nexus-node-" --filter "status=exited" --format "{{.Names}}" 2>/dev/null | sort)
    mapfile -t all_containers < <(docker ps -a --filter "name=nexus-node-" --format "{{.Names}}" 2>/dev/null | sort)
    
    if [ ${#all_containers[@]} -eq 0 ]; then
        # No containers found - show helpful message
        echo -e "${COLOR_YELLOW} 🔍 No Nexus nodes found${COLOR_RESET}"
        echo -e " ${COLOR_CYAN}💡 Tip:${COLOR_RESET} Use ${COLOR_GREEN}[3] Manage Instances${COLOR_RESET} to create your first node"
    else
        # Display running containers first
        for container in "${running_containers[@]}"; do
            if [ -n "$container" ]; then
                # Get stats dengan timeout dan fallback yang lebih baik
                local stats cpu_perc mem_usage node_id uptime tasks
                
                # Fast Docker stats - simplified for performance
                local stats cpu_perc mem_usage
                
                # Try to get Docker stats with fallback for Windows
                if command -v timeout &>/dev/null; then
                    # Linux/Unix with timeout command
                    stats=$(timeout 2 docker stats --no-stream --format "{{.CPUPerc}},{{.MemUsage}}" "$container" 2>/dev/null)
                else
                    # Windows fallback - direct docker stats call
                    stats=$(docker stats --no-stream --format "{{.CPUPerc}},{{.MemUsage}}" "$container" 2>/dev/null)
                fi
                
                if [[ -n "$stats" && "$stats" != *"Error"* ]]; then
                    cpu_perc=$(echo "$stats" | cut -d',' -f1)
                    mem_usage=$(echo "$stats" | cut -d',' -f2 | awk '{print $1}')
                else
                    # Fallback: try alternative method or use default values
                    cpu_perc="0.00%"
                    mem_usage="32MiB"
                fi
                
                # Get node ID
                node_id=$(docker inspect "$container" --format '{{range .Config.Env}}{{if eq (index (split . "=") 0) "NODE_ID"}}{{(index (split . "=") 1)}}{{end}}{{end}}' 2>/dev/null)
                
                # Calculate uptime
                uptime=$(_calculate_uptime "$container")
                
                # Optimized task counting - use single most reliable source
                tasks=0
                
                # Primary method: Check container logs for recent activity (last 24h)
                if container_logs=$(docker logs --since="24h" "$container" 2>/dev/null); then
                    if [[ -n "$container_logs" ]]; then
                        # Count proofs and task completions
                        local proof_count task_count
                        proof_count=$(echo "$container_logs" | grep -c "Proof submitted successfully\|Successfully submitted" 2>/dev/null || echo "0")
                        task_count=$(echo "$container_logs" | grep -c "Got task\|Task completed" 2>/dev/null || echo "0")
                        
                        # Validate numbers
                        [[ "$proof_count" =~ ^[0-9]+$ ]] || proof_count=0
                        [[ "$task_count" =~ ^[0-9]+$ ]] || task_count=0
                        
                        # Use the higher count as primary indicator
                        tasks=$(( proof_count > task_count ? proof_count : task_count ))
                    fi
                fi
                
                # Fallback: Check if node is actively running (simple health indicator)
                if [[ $tasks -eq 0 ]]; then
                    # Check for recent activity in logs (any activity in last hour)
                    if docker logs --since="1h" "$container" 2>/dev/null | grep -q "nexus\|Waiting\|ready\|task" 2>/dev/null; then
                        tasks=1  # Indicate it's alive but no completed tasks yet
                    fi
                fi
                
                # CPU/RAM color indicators based on usage - use bash arithmetic
                local cpu_color="${COLOR_GREEN}"
                local mem_color="${COLOR_GREEN}"
                
                # Extract numeric values for comparison
                local cpu_num mem_num
                cpu_num=$(echo "$cpu_perc" | sed 's/%//' | sed 's/[^0-9.]//g')
                mem_num=$(echo "$mem_usage" | sed 's/[^0-9.]//g')
                
                # CPU color coding - convert to integer for comparison
                if [[ -n "$cpu_num" && "$cpu_num" != "." ]]; then
                    local cpu_int
                    cpu_int=$(printf "%.0f" "$cpu_num" 2>/dev/null || echo "0")
                    
                    if [[ $cpu_int -gt 80 ]]; then
                        cpu_color="${COLOR_RED}"
                    elif [[ $cpu_int -gt 50 ]]; then
                        cpu_color="${COLOR_YELLOW}"
                    fi
                fi
                
                # Memory color coding - convert to integer for comparison
                if [[ -n "$mem_num" && "$mem_num" != "." ]]; then
                    local mem_int
                    mem_int=$(printf "%.0f" "$mem_num" 2>/dev/null || echo "0")
                    
                    if [[ $mem_int -gt 1000 ]]; then
                        mem_color="${COLOR_RED}"
                    elif [[ $mem_int -gt 500 ]]; then
                        mem_color="${COLOR_YELLOW}"
                    fi
                fi
                
                # Task color coding
                local task_color="${COLOR_PURPLE}"
                if [[ $tasks -gt 100 ]]; then
                    task_color="${COLOR_GREEN}"
                elif [[ $tasks -gt 10 ]]; then
                    task_color="${COLOR_CYAN}"
                elif [[ $tasks -eq 0 ]]; then
                    task_color="${COLOR_YELLOW}"
                fi
                
                # Clean row without borders - perfect alignment (RUNNING)
                printf " ${COLOR_GREEN}🟢 %-15s${COLOR_RESET} ${COLOR_CYAN}%-12s${COLOR_RESET} ${COLOR_YELLOW}%-10s${COLOR_RESET} ${cpu_color}%-10s${COLOR_RESET} ${mem_color}%-13s${COLOR_RESET} ${task_color}%-11s${COLOR_RESET}\n" \
                       "$container" "${node_id:-N/A}" "$uptime" "${cpu_perc:-0.00%}" "${mem_usage:-0MiB}" "$tasks"
            fi
        done
        
        # Display stopped containers
        for container in "${stopped_containers[@]}"; do
            if [ -n "$container" ]; then
                # Get node ID for stopped container
                local node_id
                node_id=$(docker inspect "$container" --format '{{range .Config.Env}}{{if eq (index (split . "=") 0) "NODE_ID"}}{{(index (split . "=") 1)}}{{end}}{{end}}' 2>/dev/null)
                
                # Get when container was stopped
                local finished_at
                finished_at=$(docker inspect "$container" --format '{{.State.FinishedAt}}' 2>/dev/null)
                local stopped_time="N/A"
                if [[ -n "$finished_at" && "$finished_at" != "0001-01-01T00:00:00Z" ]]; then
                    local now finished_ts
                    now=$(date +%s 2>/dev/null || echo "0")
                    finished_ts=$(date -d "$finished_at" +%s 2>/dev/null || echo "0")
                    if [[ "$now" -gt 0 && "$finished_ts" -gt 0 ]]; then
                        local diff=$((now - finished_ts))
                        local hours=$((diff / 3600))
                        local minutes=$(((diff % 3600) / 60))
                        if [[ $hours -gt 0 ]]; then
                            stopped_time="${hours}h${minutes}m ago"
                        else
                            stopped_time="${minutes}m ago"
                        fi
                    fi
                fi
                
                # Display stopped container (STOPPED)
                printf " ${COLOR_RED}🔴 %-15s${COLOR_RESET} ${COLOR_CYAN}%-12s${COLOR_RESET} ${COLOR_RED}%-10s${COLOR_RESET} ${COLOR_RED}%-10s${COLOR_RESET} ${COLOR_RED}%-13s${COLOR_RESET} ${COLOR_RED}%-11s${COLOR_RESET}\n" \
                       "$container" "${node_id:-N/A}" "STOPPED" "0.00%" "0MiB" "0"
            fi
        done
    fi
    echo
}

display_menu() {
    # Node Running Indicator - Above Management Menu
    local running_count stopped_count total_count
    running_count=$(docker ps --filter "name=nexus-node-" --format "{{.Names}}" 2>/dev/null | wc -l)
    stopped_count=$(docker ps -a --filter "name=nexus-node-" --filter "status=exited" --format "{{.Names}}" 2>/dev/null | wc -l)
    total_count=$((running_count + stopped_count))
    
    # Display node status indicator
    if [[ $running_count -gt 0 ]]; then
        echo -e " ${COLOR_GREEN}☑️  ${running_count} Nexus node(s) running${COLOR_RESET} • ${COLOR_CYAN}${total_count} total${COLOR_RESET}"
    elif [[ $total_count -gt 0 ]]; then
        echo -e " ${COLOR_YELLOW}⚠️  All ${total_count} node(s) stopped${COLOR_RESET} • ${COLOR_CYAN}Ready to start${COLOR_RESET}"
    else
        echo -e " ${COLOR_RED}❌  No nodes created yet${COLOR_RESET} • ${COLOR_GREEN}Ready to deploy${COLOR_RESET}"
    fi
    echo
    
    echo -e "${COLOR_CYAN}╭─────────────────────────────────────────────────────────────────────────────╮${COLOR_RESET}"
    echo -e "${COLOR_CYAN}│                              ${COLOR_YELLOW}📋 MANAGEMENT MENU${COLOR_CYAN}                             │${COLOR_RESET}"
    echo -e "${COLOR_CYAN}╰─────────────────────────────────────────────────────────────────────────────╯${COLOR_RESET}"
	echo
    
    # Simple list layout - easier for Windows PowerShell
    echo -e "  ${COLOR_CYAN}[1]${COLOR_RESET} 🏠️Build/Update Image            ${COLOR_CYAN}[2]${COLOR_RESET} 🔄 Update CLI"
    echo -e "  ${COLOR_CYAN}[3]${COLOR_RESET} 📦 Manage Instances              ${COLOR_CYAN}[4]${COLOR_RESET} 🎮 Node Control"
    echo -e "  ${COLOR_CYAN}[5]${COLOR_RESET} 🌐 Environment Config            ${COLOR_CYAN}[6]${COLOR_RESET} 📜 View Logs"
    echo -e "  ${COLOR_CYAN}[7]${COLOR_RESET} 💿 Backup & Restore              ${COLOR_CYAN}[A]${COLOR_RESET} 🧹 Docker Cleanup"
    echo -e "  ${COLOR_CYAN}[0]${COLOR_RESET} 🚪 Exit Program"
	echo
    
    
    # Status Info
    echo -e "${COLOR_CYAN}ℹ️  Settings:${COLOR_RESET} Env: ${COLOR_GREEN}${NEXUS_ENVIRONMENT:-production}${COLOR_RESET} | Memory: ${COLOR_GREEN}${NEXUS_MEMORY_LIMIT:-unlimited}${COLOR_RESET} | Auto-Restart: ${COLOR_GREEN}${NEXUS_AUTO_RESTART:-true}${COLOR_RESET}"
    echo
}

# Display first-run welcome screen
display_first_run_welcome() {
    local is_first_run=false
    
    # Check if this is first run (no config or no docker)
    if [[ ! -f "$CONFIG_FILE" ]] || ! command -v docker &>/dev/null; then
        is_first_run=true
    fi
    
    if [[ "$is_first_run" == "true" ]]; then
        clear
        echo -e "${COLOR_CYAN}╭─────────────────────────────────────────────────────────────────────────────╮${COLOR_RESET}"
        echo -e "${COLOR_CYAN}│                     ${COLOR_GREEN}🎉 WELCOME TO NEXUS NODE MANAGER! 🎉${COLOR_CYAN}                    │${COLOR_RESET}"
        echo -e "${COLOR_CYAN}╰─────────────────────────────────────────────────────────────────────────────╯${COLOR_RESET}"
        echo
        
        echo -e "  ${COLOR_YELLOW}🚀 FIRST TIME SETUP${COLOR_RESET}"
        echo -e "    This script will help you manage Nexus Network nodes using Docker containers."
        echo -e "    We'll automatically check and install dependencies for you."
        echo
        
        echo -e "  ${COLOR_CYAN}📋 WHAT WE'LL DO:${COLOR_RESET}"
        echo -e "    ${COLOR_GREEN}✅${COLOR_RESET} Check system dependencies (jq, Docker)"
        echo -e "    ${COLOR_GREEN}✅${COLOR_RESET} Install missing components automatically"
        echo -e "    ${COLOR_GREEN}✅${COLOR_RESET} Create configuration files"
        echo -e "    ${COLOR_GREEN}✅${COLOR_RESET} Set up optimal hardware settings"
        echo
        
        echo -e "  ${COLOR_YELLOW}⚠️  REQUIREMENTS:${COLOR_RESET}"
        echo -e "    • Linux/macOS/Windows with WSL or MSYS2/Cygwin"
        echo -e "    • Internet connection for downloading Docker & dependencies"
        echo -e "    • Administrative privileges (for Docker installation)"
        echo
        
        if prompt_confirm "Continue with automatic setup?"; then
            log_success "Starting automatic setup..."
            echo
        else
            log_info "Setup cancelled. You can run this script again anytime."
            exit 0
        fi
    fi
}

# Verify installation was successful
verify_docker_installation() {
    local max_attempts=60
    local attempt=0
    
    log_info "🔄 Verifying Docker installation..."
    
    while [[ $attempt -lt $max_attempts ]]; do
        if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
            log_success "✅ Docker installation verified successfully!"
            
            # Show Docker version
            local docker_version
            docker_version=$(docker --version 2>/dev/null || echo "Unknown version")
            log_info "📋 Installed: $docker_version"
            
            return 0
        fi
        
        # Progress indicator
        local dots
        dots=$(printf "%*s" $((attempt % 4)) "" | tr ' ' '.')
        printf "\r  ${COLOR_YELLOW}⏳ Waiting for Docker to be ready${dots}   ${COLOR_RESET}"
        
        sleep 2
        ((attempt++))
    done
    
    echo
    log_error "❌ Docker installation verification failed"
    log_warn "⚠️ Docker may need additional time to start or require manual intervention"
    return 1
}

# Enhanced main function with first-run experience
main() {
    # Display welcome screen for first-time users
    display_first_run_welcome
    
    # Initialize directories and config
    init_dirs
    
    # Check and install dependencies with automatic Docker installation
    check_dependencies
    
    # If Docker was just installed, verify it's working
    if [[ ! -f "$BASE_DIR/.docker_verified" ]]; then
        if verify_docker_installation; then
            # Create marker file to avoid re-verification
            touch "$BASE_DIR/.docker_verified"
            log_success "✨ Setup completed! Ready to manage Nexus nodes."
            echo
            prompt_user "Press Enter to continue to the main dashboard..." "dummy_var"
        else
            log_error "⚠️ Setup incomplete. Please check Docker installation."
            exit 1
        fi
    fi
    
    # Main dashboard loop with auto-refresh
    while true; do
        display_dashboard
        display_menu
        
        # Check if auto-refresh is enabled and nodes are running
        local running_count
        running_count=$(docker ps --filter "name=nexus-node-" --format "{{.Names}}" 2>/dev/null | wc -l)
        
        local choice
        if [[ "${NEXUS_AUTO_REFRESH:-true}" == "true" && $running_count -gt 0 ]]; then
            # Auto-refresh mode - show countdown timer
            local refresh_interval="${NEXUS_REFRESH_INTERVAL:-180}"
            echo -e "${COLOR_CYAN}ℹ️  Auto-refresh:${COLOR_RESET} ${COLOR_GREEN}ON${COLOR_RESET} (${refresh_interval}s) | Running nodes: ${COLOR_GREEN}$running_count${COLOR_RESET} | ${COLOR_YELLOW}Press any key for menu${COLOR_RESET}"
            echo
            
            # Read with timeout for auto-refresh
            if read -t "$refresh_interval" -rp "$(echo -e "${COLOR_PURPLE} ❔ Question    >${COLOR_RESET} Pilih Opsi: ")" choice 2>/dev/null; then
                echo
            else
                # Timeout reached - auto refresh
                echo
                log_info "🔄 Auto-refreshing dashboard..."
                sleep 1
                continue
            fi
        else
            # Manual refresh mode
            if [[ "${NEXUS_AUTO_REFRESH:-true}" != "true" ]]; then
                echo -e "${COLOR_CYAN}ℹ️  Auto-refresh:${COLOR_RESET} ${COLOR_RED}OFF${COLOR_RESET}"
            else
                echo -e "${COLOR_CYAN}ℹ️  Auto-refresh:${COLOR_RESET} ${COLOR_YELLOW}IDLE${COLOR_RESET} (no running nodes)"
            fi
            echo
            prompt_user "Pilih Opsi: " choice
            echo
        fi

        local should_pause=false
        case "$choice" in
            1) build_image_interactive && should_pause=true ;;
            2) build_image_latest && should_pause=true ;;
            3) manage_instances_menu ;; # Menu ini menangani jeda sendiri
            4) node_control_menu ;; # Node Control Center menu with High Performance integrated
            5) environment_config_menu ;; # Environment & Config menu
            6) view_node_logs ;; # Menu ini tidak perlu jeda
            7) backup_restore_menu ;; # Unified Backup & Restore menu
            [aA]) docker_prune && should_pause=true ;;
            0) log_info "Keluar dari program."; exit 0 ;;
            "") 
                # Empty choice (just Enter pressed) - refresh dashboard
                log_info "🔄 Refreshing dashboard..." 
                sleep 1  # Brief pause to show refresh message
                ;;
            *) log_error "Opsi tidak valid. Silakan coba lagi." ; should_pause=true ;;
        esac
        
        if [ "$should_pause" = true ]; then
          echo
          prompt_user "Tekan Enter untuk melanjutkan..." "dummy_var"
        fi
    done
}

main "$@"
