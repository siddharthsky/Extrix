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

MIRRORS=(
"https://packages.termux.dev/apt/termux-main"
"https://mirrors.in.sahilister.net/termux/termux-main/ stable main"
"https://linux.domainesia.com/applications/termux/termux-main"
"http://mirror.mephi.ru/termux/termux-main"
)

# --------------------------------------------------------
# Mirror Selection
measure_latency() {
    local base_url="$1"
    local host=$(echo "$base_url" | awk -F/ '{print $3}')

    local t
    t=$(curl -o /dev/null -s -w "%{time_total}" \
        --max-time 5 "$base_url/dists/stable/Release")

    if [[ $? -eq 0 && -n "$t" ]]; then
        echo "$t $base_url"
        return
    fi

    local ping_avg
    ping_avg=$(ping -c 2 -W 2 "$host" 2>/dev/null \
        | tail -1 | awk -F '/' '{print $5}')

    if [[ -n "$ping_avg" ]]; then
        awk "BEGIN {print $ping_avg/1000 \" $base_url\"}"
        return
    fi

    echo "999 $base_url"
}

select_best_mirror() {
    local tmp
    tmp=$(mktemp)

    for m in "${MIRRORS[@]}"; do
        measure_latency "$m" >> "$tmp"
    done

    sort -n "$tmp" | head -n 1 | awk '{print $2}'
    rm -f "$tmp"
}

apply_mirror() {
    local mirror="$1"

    echo "deb $mirror stable main" > "$PREFIX/etc/apt/sources.list"
    rm -rf "$PREFIX/etc/apt/sources.list.d/"*
}

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
        
            best_mirror=$(select_best_mirror)
            apply_mirror "$best_mirror"
        
            echo -e "${C_WHITE}[+] Using mirror: $best_mirror${C_RESET}"
        
            pkg update -y
        
            if pkg install -y "${missing_pkgs[@]}"; then
                success=true
                pkg clean >/dev/null 2>&1
                break
            else
                echo -e "${C_CHERRY}[!] Failed with selected mirror. Switching next best...${C_RESET}"
                sleep 2
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
