
Setup_Prerequisites() {
    mkdir -p "$HOME/.termux"

    # Check if termux.properties exists and if the desired string is missing
    if ! grep -q "allow-external-apps = true" "$HOME/.termux/termux.properties" 2>/dev/null; then
        # Append the required string, creating the file if it doesn't exist
        echo "allow-external-apps = true" >> "$HOME/.termux/termux.properties"
        chmod 755 "$HOME/.termux/termux.properties"
    fi
}

echo "Running Setpup _repo2"

Check_And_Install_Packages() {
    FLAG="$HOME/.custtermux_pkgs_installed"

    if [ -f "$FLAG" ]; then
        return
    fi

    missing_pkgs=""
    for pkg_name in php git wget; do
        if ! command -v "$pkg_name" >/dev/null 2>&1; then
            missing_pkgs="$missing_pkgs $pkg_name"
        fi
    done

    if [ -n "$missing_pkgs" ]; then
        echo "Installing:$missing_pkgs"
        pkg install -y $missing_pkgs
    fi

    touch "$FLAG"
}

echo "Running Setup_repo2"

Setup_Prerequisites

Check_And_Install_Packages
