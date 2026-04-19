#!/bin/bash

export SHELL=/bin/bash

Run_Plugins() {
    export SHELL=/bin/bash
    PLUGIN_DIR="$HOME/plugins"

    termux-wake-lock

    [ ! -d "$PLUGIN_DIR" ] && return

    plugin_dirs=$(find "$PLUGIN_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
    [ -z "$plugin_dirs" ] && return

    echo -e "\e[1;37mStarting plugin servers...\e[0m"

    # Color list
    colors=(
        "\e[1;31m" # red
        "\e[1;32m" # green
        "\e[1;33m" # yellow
        "\e[1;34m" # blue
        "\e[1;35m" # magenta
        "\e[1;36m" # cyan
    )

    i=0

    echo "$plugin_dirs" | while read -r dir; do
        port=$(basename "$dir")

        [[ ! "$port" =~ ^[0-9]+$ ]] && continue

        script="$dir/$port.sh"

        # Skip if script not found
        [ ! -f "$script" ] && continue

        # Skip if already running
        if lsof -i :$port >/dev/null 2>&1; then
            continue
        fi

        # Pick color (cycle)
        color=${colors[$((i % ${#colors[@]}))]}
        reset="\e[0m"

        echo -e "${color}➜ Plugin running on http://localhost:$port${reset}"

        # Run script silently in background
        (cd "$dir" && bash "$script" > /dev/null 2>&1 &)

        ((i++))
    done

     # Create launch flag
    touch "$HOME/.launch"
}

Boot_System() {
    echo -e "\e[1;36m[BOOT] Initializing system...\e[0m"


    Run_Plugins

    echo -e "\e[1;32m[BOOT] System started successfully.\e[0m"
}

case "$1" in
    --run)
        case "$2" in
            boot)
                Boot_System
                ;;
            plugins)
                Run_Plugins
                ;;
            *)
                echo "Usage: $0 --run {boot|plugins}"
                ;;
        esac
        ;;
    *)
        echo "Usage: $0 --run {boot|plugins}"
        ;;
esac
