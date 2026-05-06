#!/bin/bash

REQUIRED_PACKAGES=(php git wget)

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
    PROP_FILE="$HOME/.termux/termux.properties"

    if [ ! -f "$PROP_FILE" ] || ! grep -q "allow-external-apps = true" "$PROP_FILE"; then
        echo "allow-external-apps = true" >> "$PROP_FILE"
        chmod 755 "$PROP_FILE"
    fi
}

Check_And_Install_Packages() {
    missing_pkgs=()

    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            missing_pkgs+=("$pkg")
        fi
    done

    if [ ${#missing_pkgs[@]} -gt 0 ]; then
        echo -e "\n${C_CHERRY}[!] Installing missing dependencies: ${missing_pkgs[*]}${C_RESET}"
        pkg update -y
        pkg install -y "${missing_pkgs[@]}"

        echo -e "\n${C_SOFT_GREEN}[✓] Packages installed. Starting new Termux session...${C_RESET}"

        termux-reload-settings
        sleep 2

        rm -f $HOME/.termux/termux.properties
        touch $HOME/.termux/termux.properties
        chmod 755 $HOME/.termux/termux.properties
        echo "allow-external-apps = true" >> $HOME/.termux/termux.properties

        am startservice \
          -n com.termux/.app.TermuxService \
          -a com.termux.service_execute \
          --es com.termux.execute.cwd "$HOME" \
          --es com.termux.execute.command "/data/data/com.termux/files/usr/bin/bash" \
          --ez com.termux.execute.background false
    fi
}

Run_Plugins() {
    PLUGIN_DIR="$HOME/plugins"

    [ ! -d "$PLUGIN_DIR" ] && return

    plugin_dirs=$(find "$PLUGIN_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
    [ -z "$plugin_dirs" ] && return

    echo -e "\n${C_DEEP_PINK}🌸 Starting Plugin Servers...${C_RESET}\n"

    # Subtle cycling colors for list items
    colors=( "$C_SAKURA_PINK" "$C_SOFT_BLUE" "$C_WHITE" )
    i=0
    started_count=0

    echo "$plugin_dirs" | while read -r dir; do
        port=$(basename "$dir")

        [[ ! "$port" =~ ^[0-9]+$ ]] && continue

        script="$dir/$port.sh"

        # Skip if script not found
        [ ! -f "$script" ] && continue

        # Skip if already running
        if lsof -i :$port >/dev/null 2>&1; then
            echo -e "${C_SOFT_GREEN}  [✓] Port $port is already active.${C_RESET}"
            continue
        fi

        # Pick color (cycle)
        color=${colors[$((i % ${#colors[@]}))]}
        url="http://localhost:$port"

        # Output terminal hyperlink with raw URL
        echo -e "${color}[+] Plugin Active | \e]8;;$url\a$url\e]8;;\a${C_RESET}"

        # Run script silently in background
        (cd "$dir" && bash "$script" > /dev/null 2>&1 &)

        ((i++))
        ((started_count++))
    done
    
    if [ "$started_count" -eq 0 ]; then
        echo "" # Spacing
        echo -e "${C_SOFT_BLUE}[*] All plugins are currently running.${C_RESET}"
    fi
    
    # Create launch flag
    touch "$HOME/.launch"
}

# Always reset launch flag on start
rm -f "$HOME/.launch"

termux-wake-lock

Setup_Prerequisites
Check_And_Install_Packages

echo -e "${C_DEEP_PINK}--READY-- ${C_RESET}"

Run_Plugins
