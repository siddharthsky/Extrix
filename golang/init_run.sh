
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
    echo "Checking required packages..."

    # Update package list first (optional but recommended)
    pkg update -y

    for pkg_name in php git wget; do
        if ! command -v "$pkg_name" >/dev/null 2>&1; then
            echo "$pkg_name not found. Installing..."
            pkg install -y "$pkg_name"
        else
            echo "$pkg_name already installed."
        fi
    done
}

echo "Running Setup_repo2"

Setup_Prerequisites

Check_And_Install_Packages
