
Setup_Prerequisites() {
    mkdir -p "$HOME/.termux"

    # Check if termux.properties exists and if the desired string is missing
    if ! grep -q "allow-external-apps = true" "$HOME/.termux/termux.properties" 2>/dev/null; then
        # Append the required string, creating the file if it doesn't exist
        echo "allow-external-apps = true" >> "$HOME/.termux/termux.properties"
        chmod 755 "$HOME/.termux/termux.properties"
    fi
}

echo "Running Setpup _repo"

Setup_Prerequisites
