REQUIRED_PACKAGES=(php git wget)

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
        echo "Installing: ${missing_pkgs[*]}"
        pkg update -y
        pkg install -y "${missing_pkgs[@]}"

        echo "Packages installed. Starting new Termux session..."

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

    else
        echo "All required packages are already installed."
    fi
}

Run_Plugins() {
    PLUGIN_DIR="$HOME/plugins"

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
}

echo "Acquiring wake lock"
termux-wake-lock
echo "Checking requirements"



Setup_Prerequisites
Check_And_Install_Packages

echo "--READY--"

Run_Plugins


case "$1" in
    setup)
        Setup_Prerequisites
        ;;
    install)
        Check_And_Install_Packages
        ;;
    plugins)
        Run_Plugins
        ;;
    all|"")
        Setup_Prerequisites
        Check_And_Install_Packages
        echo "--READY--"
        Run_Plugins
        ;;
    *)
        echo "Usage: $0 {setup|install|plugins|all}"
        exit 1
        ;;
esac
