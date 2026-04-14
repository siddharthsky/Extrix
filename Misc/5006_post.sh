#!/bin/bash

PORT=0

# 🔹 Parse arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --port) PORT="$2"; shift ;;
  esac
  shift
done

echo "Port is: $PORT"

# ❌ Safety check
if [ "$PORT" -eq 0 ]; then
  echo "Port not provided!"
  exit 1
fi

echo "Installing Script..."
curl -fsSL https://jiotv_go.rabil.me/install.sh | bash

mv "$HOME/.jiotv_go" .

if [ -f "run.bin" ]; then
    echo "run.bin exists → keeping existing $PORT.sh"
else
    echo "run.bin not found → recreating script"

    rm -f "$PORT.sh"

    cat > "$PORT.sh" <<EOF
#!/bin/bash

cd "$(pwd)"
./run.bin --port $PORT

# END
EOF

    chmod +x "$PORT.sh"
    echo "Created new script: $PORT.sh"
fi

echo "Re-run server to launch"
sleep 3

