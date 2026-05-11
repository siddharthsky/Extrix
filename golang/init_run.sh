#!/data/data/com.termux/files/usr/bin/bash

set -euo pipefail

# =========================================================
# Required Packages
# =========================================================
REQUIRED_PACKAGES=(php wget lsof)

# =========================================================
# Colors
# =========================================================
C_SAKURA_PINK="\e[38;2;255;183;197m"
C_DEEP_PINK="\e[38;2;255;105;180m"
C_CHERRY="\e[38;2;192;32;88m"
C_SOFT_BLUE="\e[38;2;176;224;230m"
C_SOFT_GREEN="\e[38;2;143;188;143m"
C_WHITE="\e[38;2;248;248;255m"
C_RESET="\e[0m"

# =========================================================
# Paths
# =========================================================
TERMUX_DIR="$HOME/.termux"
PROP_FILE="$TERMUX_DIR/termux.properties"
PLUGIN_DIR="$HOME/plugins"
LAUNCH_FLAG="$HOME/.launch"

# =========================================================
# Cleanup on Exit
# =========================================================
Cleanup() {
    if command -v termux-wake-unlock >/dev/null 2>&1; then
        termux-wake-unlock >/dev/null 2>&1 || true
    fi
}

trap Cleanup EXIT

# =========================================================
# Logging Helpers
# =========================================================
Info() {
    echo -e "${C_SOFT_BLUE}[*] $1${C_RESET}"
}

Success() {
    echo -e "${C_SOFT_GREEN}[✓] $1${C_RESET}"
}

Warn() {
    echo -e "${C_CHERRY}[!] $1${C_RESET}"
}

# =========================================================
# Setup Termux Prerequisites
# =========================================================
Setup_Prerequisites() {

    mkdir -p "$TERMUX_DIR"

    if [ ! -f "$PROP_FILE" ]; then
        touch "$PROP_FILE"
    fi

    if ! grep -q "^allow-external-apps *= *true" "$PROP_FILE" 2>/dev/null; then
        echo "allow-external-apps = true" >> "$PROP_FILE"
    fi

    chmod 644 "$PROP_FILE"

    if command -v termux-reload-settings >/dev/null 2>&1; then
        termux-reload-settings >/dev/null 2>&1 || true
    fi
}

# =========================================================
# Check & Install Packages
# =========================================================
Check_And_Install_Packages() {

    local missing_pkgs=()

    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            missing_pkgs+=("$pkg")
        fi
    done

    if [ ${#missing_pkgs[@]} -eq 0 ]; then
        return
    fi

    Warn "Installing missing packages: ${missing_pkgs[*]}"

    pkg update -y || {
        Warn "Failed to update package lists."
        exit 1
    }

    pkg install -y "${missing_pkgs[@]}" || {
        Warn "Package installation failed."
        exit 1
    }

    pkg clean

    Success "Packages installed successfully."

    Setup_Prerequisites

    Info "Restarting fresh Termux session..."

    am startservice \
      -n com.termux/.app.TermuxService \
      -a com.termux.service_execute \
      --es com.termux.execute.cwd "$HOME" \
      --es com.termux.execute.command "$PREFIX/bin/bash" \
      --ez com.termux.execute.background false >/dev/null 2>&1 || {
        Warn "Failed to restart Termux session."
        exit 1
    }

    # CRITICAL: Prevent duplicate execution
    exit 0
}

# =========================================================
# Validate Port
# =========================================================
Is_Valid_Port() {

    local port="$1"

    [[ "$port" =~ ^[0-9]+$ ]] || return 1

    (( port >= 1024 && port <= 65535 ))
}

# =========================================================
# Check if Port Already Active
# =========================================================
Is_Port_Running() {

    local port="$1"

    lsof -i :"$port" >/dev/null 2>&1
}

# =========================================================
# Start Single Plugin
# =========================================================
Start_Plugin() {

    local dir="$1"
    local port
    local script
    local logfile
    local url

    port="$(basename "$dir")"

    Is_Valid_Port "$port" || {
        Warn "Skipping invalid port: $port"
        return
    }

    script="$dir/$port.sh"

    [ -f "$script" ] || {
        Warn "Missing plugin script: $script"
        return
    }

    if Is_Port_Running "$port"; then
        Success "Port $port already active."
        return
    fi

    logfile="$dir/plugin.log"
    url="http://localhost:$port"

    (
        cd "$dir" || exit 1
        bash "$script" > "$logfile" 2>&1
    ) &

    local pid=$!

    # Wait for startup
    local attempts=0
    local max_attempts=10

    while [ $attempts -lt $max_attempts ]; do

        if Is_Port_Running "$port"; then
            echo -e "${C_SAKURA_PINK}[+] Plugin Active | \e]8;;$url\a$url\e]8;;\a${C_RESET}"
            return
        fi

        sleep 1
        ((attempts++))
    done

    Warn "Plugin on port $port failed to start."
    Warn "Check log: $logfile"

    kill "$pid" >/dev/null 2>&1 || true
}

# =========================================================
# Run Plugins
# =========================================================
Run_Plugins() {

    [ -d "$PLUGIN_DIR" ] || {
        Info "No plugin directory found."
        return
    }

    mapfile -t plugin_dirs < <(
        find "$PLUGIN_DIR" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d | sort
    )

    [ ${#plugin_dirs[@]} -eq 0 ] && {
        Info "No plugins found."
        return
    }

    echo
    echo -e "${C_DEEP_PINK}🌸 Starting Plugin Servers...${C_RESET}"
    echo

    local started_count=0

    for dir in "${plugin_dirs[@]}"; do
        Start_Plugin "$dir"
        ((started_count++))
    done

    echo

    if [ "$started_count" -eq 0 ]; then
        Info "All plugins are already running."
    else
        Success "$started_count plugin(s) processed."
    fi

    touch "$LAUNCH_FLAG"
}

# =========================================================
# Main
# =========================================================

rm -f "$LAUNCH_FLAG"

if command -v termux-wake-lock >/dev/null 2>&1; then
    termux-wake-lock >/dev/null 2>&1 || true
fi

Setup_Prerequisites

Check_And_Install_Packages

echo
echo -e "${C_DEEP_PINK}--READY--${C_RESET}"
echo

Run_Plugins
