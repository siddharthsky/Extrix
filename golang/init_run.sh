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
            
            if [ $attempt -eq 3 ]; then
                echo -e "${C_CHERRY}[!] Mirror change attempt: Cleaning repository sources to fix mirrors...${C_RESET}"
                echo "" > "$PREFIX/etc/apt/sources.list"
                rm -rf "$PREFIX/etc/apt/sources.list.d/"*
            fi

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
        echo -e "${C_SOFT_GREEN}[✓] Packages installed successfully.${C_RESET}"
        echo -e "${C_SOFT_GREEN}[✓] Open ${C_SAKURA_PINK}Plugin Manager${C_SOFT_GREEN} to install plugins.${C_RESET}"
        echo -e "${C_SOFT_GREEN}[✓] Add plugins to get started.${C_RESET}"

        termux-reload-settings
        Wait_For_Apt_Stable
        hash -r 
        
        touch "$HOME/.CTxEngine"
        
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
    
    # ---
    local init_dir="$HOME/init"
    local init_script="$init_dir/5789.sh"
    
    if [ ! -f "$init_script" ]; then
        mkdir -p "$init_dir"
        
        echo -e "#!/bin/bash\nawk 'BEGIN { Server = \"/inet/tcp/5789/0/0\"; while (1) { Server |& getline; print \"Ping received\"; close(Server) } }'" > "$init_script"
        
        chmod +x "$init_script"
    fi
    
    if ! lsof -i :5789 >/dev/null 2>&1; then
        (cd "$init_dir" && bash "5789.sh" >/dev/null 2>&1 &)
    fi
    # ----
    
    touch "$HOME/.launch"
}

Wait_For_Apt_Stable() {
    while pgrep -f "apt|dpkg" >/dev/null 2>&1; do
        echo "[*] Waiting for package manager to stabilize..."
        sleep 2
    done

    sleep 2
}


Uninstall_Plugin_Temp_Packages() {
    local uninstall_file="$HOME/.post_uninstall_temp"
    local registry_file="$HOME/.ctx_pkgs"
    [ ! -f "$uninstall_file" ] && return

    local candidate_pkgs=()

    while IFS='=' read -r raw_key raw_val; do
        local key val
        key=$(echo "$raw_key" | xargs)
        val=$(echo "$raw_val" | xargs)
        [ -z "$key" ] && continue

        # Remove this plugin's entry from .ctx_pkgs first
        if [ -f "$registry_file" ]; then
            grep -v "^${key}[[:space:]]*=" "$registry_file" > "${registry_file}.tmp" 2>/dev/null || true
            mv "${registry_file}.tmp" "$registry_file"
        fi

        if [ -n "$val" ]; then
            local line_pkgs=()
            read -ra line_pkgs <<< "$val"
            for p in "${line_pkgs[@]}"; do
                candidate_pkgs+=("$p")
            done
        fi
    done < "$uninstall_file"

    # Collect all packages still needed by remaining plugins in .ctx_pkgs
    local in_use_pkgs=" ${REQUIRED_PACKAGES[*]} "
    if [ -f "$registry_file" ]; then
        while IFS='=' read -r _ r_val; do
            local clean_val
            clean_val=$(echo "$r_val" | xargs)
            [ -n "$clean_val" ] && in_use_pkgs+="${clean_val} "
        done < "$registry_file"
    fi

    # Filter packages that are safe to uninstall
    local to_uninstall=()
    for pkg in "${candidate_pkgs[@]}"; do
        if [[ "$in_use_pkgs" != *" $pkg "* ]] && dpkg -s "$pkg" >/dev/null 2>&1; then
            if [[ " ${to_uninstall[*]} " != *" $pkg "* ]]; then
                to_uninstall+=("$pkg")
            fi
        fi
    done

    if [ ${#to_uninstall[@]} -gt 0 ]; then
        echo -e "\n${C_CHERRY}[!] Uninstalling unused plugin packages: ${to_uninstall[*]}${C_RESET}"
        if DEBIAN_FRONTEND=noninteractive pkg uninstall -y "${to_uninstall[@]}"; then
            DEBIAN_FRONTEND=noninteractive apt-get autoremove -y >/dev/null 2>&1
            Wait_For_Apt_Stable
            hash -r
            echo -e "${C_SOFT_GREEN}[✓] Unused plugin packages removed.${C_RESET}"
        else
            echo -e "${C_DEEP_PINK}[✖] Failed to uninstall some packages: ${to_uninstall[*]}${C_RESET}"
        fi
    fi

    rm -f "$uninstall_file"
}

Install_Plugin_Temp_Packages() {
    local install_file="$HOME/.post_install_temp"
    local registry_file="$HOME/.ctx_pkgs"
    [ ! -f "$install_file" ] && return

    local missing_pkgs=()

    while IFS='=' read -r raw_key raw_val; do
        local key val
        key=$(echo "$raw_key" | xargs)
        val=$(echo "$raw_val" | xargs)
        [ -z "$key" ] || [ -z "$val" ] && continue

        local line_pkgs=()
        read -ra line_pkgs <<< "$val"
        for pkg in "${line_pkgs[@]}"; do
            if ! dpkg -s "$pkg" >/dev/null 2>&1; then
                if [[ " ${missing_pkgs[*]} " != *" $pkg "* ]]; then
                    missing_pkgs+=("$pkg")
                fi
            fi
        done
    done < "$install_file"

    local install_ok=true
    if [ ${#missing_pkgs[@]} -gt 0 ]; then
        echo -e "\n${C_CHERRY}[!] Installing plugin packages: ${missing_pkgs[*]}${C_RESET}"
        pkg update -y
        DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold"

        if DEBIAN_FRONTEND=noninteractive pkg install -y "${missing_pkgs[@]}"; then
            pkg clean >/dev/null 2>&1
            Wait_For_Apt_Stable
            hash -r
            echo -e "${C_SOFT_GREEN}[✓] Plugin packages installed successfully.${C_RESET}"
        else
            echo -e "${C_DEEP_PINK}[✖] Failed to install plugin packages: ${missing_pkgs[*]}${C_RESET}"
            install_ok=false
        fi
    fi

    if [ "$install_ok" = true ]; then
        touch "$registry_file"
        while IFS='=' read -r raw_key raw_val; do
            local key val
            key=$(echo "$raw_key" | xargs)
            val=$(echo "$raw_val" | xargs)
            [ -z "$key" ] || [ -z "$val" ] && continue

            # Replace existing entry for this plugin if present, then append
            grep -v "^${key}[[:space:]]*=" "$registry_file" > "${registry_file}.tmp" 2>/dev/null || true
            mv "${registry_file}.tmp" "$registry_file"
            echo "${key} = ${val}" >> "$registry_file"
        done < "$install_file"

        rm -f "$install_file"
    fi
}


# Always reset launch flag on start
rm -f "$HOME/.launch"

termux-wake-lock

Setup_Prerequisites
Check_And_Install_Packages
Uninstall_Plugin_Temp_Packages
Install_Plugin_Temp_Packages

echo -e "${C_DEEP_PINK}--READY-- ${C_RESET}"

Run_Plugins
