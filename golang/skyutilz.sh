#!/bin/bash

export SHELL=/bin/bash

Run_Plugins() {
    export SHELL=/bin/bash
    PLUGIN_DIR="$HOME/plugins"

    if [ ! -d "$PLUGIN_DIR" ]; then
        echo "No plugin directory found."
        return
    fi

    mapfile -t plugin_dirs < <(find "$PLUGIN_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)

    if [ ${#plugin_dirs[@]} -eq 0 ]; then
        echo "No plugins found."
        return
    fi

    echo -e "\e[1;37mStarting plugin servers...\e[0m"

    colors=(
        "\e[1;31m"
        "\e[1;32m"
        "\e[1;33m"
        "\e[1;34m"
        "\e[1;35m"
        "\e[1;36m"
    )

    reset="\e[0m"
    i=0

    for dir in "${plugin_dirs[@]}"; do
        port="$(basename "$dir")"

        # only numeric folders = ports
        [[ ! "$port" =~ ^[0-9]+$ ]] && continue

        script="$dir/$port.sh"

        # skip missing script
        [ ! -f "$script" ] && continue

        # skip if port already used
        if lsof -i :"$port" >/dev/null 2>&1; then
            continue
        fi

        color="${colors[$((i % ${#colors[@]}))]}"

        echo -e "${color}➜ Plugin running on http://localhost:$port${reset}"

        log_file="$dir/plugin.log"

        (
            cd "$dir" || exit
            nohup bash "$script" > "$log_file" 2>&1 &
        )

        ((i++))
    done
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
