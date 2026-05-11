#!/bin/bash

# Required packages
REQUIRED_PACKAGES=(php wget lsof)

C_SAKURA_PINK="\e[38;2;255;183;197m"
C_DEEP_PINK="\e[38;2;255;105;180m"
C_CHERRY="\e[38;2;192;32;88m"
C_SOFT_BLUE="\e[38;2;176;224;230m"
C_SOFT_GREEN="\e[38;2;143;188;143m"
C_WHITE="\e[38;2;248;248;255m"
C_RESET="\e[0m"
# --------------------------------------------------------

Setup_Prerequisites() {
    mkdir -p "$HOME/.termux"
    local PROP_FILE="$HOME/.termux/termux.properties"

    if [ ! -f "$PROP_FILE" ] || ! grep -q "allow-external-apps = true" "$PROP_FILE"; then
        echo "allow-external-apps = true" >> "$PROP_FILE"
        chmod 755 "$PROP_FILE"
    fi
}

Check_And_Install_Packages() {
    local missing_pkgs=()

    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            missing_pkgs+=("$pkg")
        fi
    done

    if [ ${#missing_pkgs[@]} -gt 0 ]; then
        echo -e "\n${C_CHERRY}[!] Installing missing dependencies: ${missing_pkgs[*]}${C_RESET}"
        
        local max_retries=3
        local attempt=1
        local success=false

        while [ $attempt -le $max_retries ]; do
            echo -e "${C_SOFT_BLUE}[*] Installation attempt $attempt of $max_retries...${C_RESET}\n"
            
            pkg update -y
            if pkg install -y "${missing_pkgs[@]}"; then
                success=true
                
                pkg clean >/dev/null 2>&1
                break
            else
                echo -e "\n${C_CHERRY}[!] Installation failed. Retrying in 3 seconds...${C_RESET}"
                sleep 3
                ((attempt++))
            fi
        done

        if [ "$success" = false ]; then
            echo -e "\n${C_DEEP_PINK}[✖] Fatal Error: Could not install packages. Check internet connection. Aborting.${C_RESET}"
            exit 1
        fi

        clear

        echo -e "${C_SOFT_GREEN}[✓] Packages installed and cache cleared successfully. Applying settings...${C_RESET}"

        termux-reload-settings
        Wait_For_Apt_Stable
        hash -r 
        sleep 1
    fi
}

Run_Plugins() {
    local PLUGIN_DIR="$HOME/plugins"

    [ ! -d "$PLUGIN_DIR" ] && return

    local plugin_dirs=$(find "$PLUGIN_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -n)
    [ -z "$plugin_dirs" ] && return

    echo -e "\n${C_DEEP_PINK}🌸 Starting Plugin Servers...${C_RESET}\n"

    local colors=( "$C_SAKURA_PINK" "$C_SOFT_BLUE" "$C_WHITE" )
    local i=0
    local started_count=0

    echo "$plugin_dirs" | while read -r dir; do
        local port=$(basename "$dir")

        [[ ! "$port" =~ ^[0-9]+$ ]] && continue

        if (( port < 1024 || port > 65535 )); then
            echo -e "${C_CHERRY}  [!] Invalid port directory ($port). Must be 1024-65535. Skipping.${C_RESET}"
            continue
        fi

        local script="$dir/$port.sh"
        local log_file="$dir/$port.log"

        [ ! -f "$script" ] && continue

        if lsof -i :$port >/dev/null 2>&1; then
            echo -e "${C_SOFT_GREEN}  [✓] Port $port is already active.${C_RESET}"
            continue
        fi

        local color=${colors[$((i % ${#colors[@]}))]}
        local url="http://localhost:$port"

        echo -e "${color}[+] Plugin Active | \e]8;;$url\a$url\e]8;;\a${C_RESET}"
        
        rm -f "$log_file"

        (cd "$dir" && bash "$script" > "$log_file" 2>&1 &)

        ((i++))
        ((started_count++))
    done
    
    if [ "$started_count" -eq 0 ]; then
        echo ""
        echo -e "${C_SOFT_BLUE}[*] All plugins are currently running.${C_RESET}"
    fi
    
    touch "$HOME/.launch"
}

Wait_For_Apt_Stable() {
    while pgrep -f "apt|dpkg" >/dev/null 2>&1; do
        echo "[*] Waiting for package manager to stabilize..."
        sleep 2
    done

    sleep 2
}


# Always reset launch flag on start
rm -f "$HOME/.launch"

termux-wake-lock

Setup_Prerequisites
Check_And_Install_Packages

echo -e "${C_DEEP_PINK}--READY-- ${C_RESET}"

Run_Plugins
