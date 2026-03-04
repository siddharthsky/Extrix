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
    else
        echo "All required packages are already installed."
    fi
}

echo "Acquiring wake lock"
termux-wake-lock
echo "Checking requirements"



Setup_Prerequisites
Check_And_Install_Packages

echo "--READY--"
