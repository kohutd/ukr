#!/usr/bin/env bash

set -e

VM_NAME="мвм"
INSTALL_DIR="$HOME/.$VM_NAME"
BIN_DIR="$HOME/.local/bin"
VM_SCRIPT="$INSTALL_DIR/$VM_NAME"

# URL to your mytoolvm script if hosted remotely (replace with real URL)
VM_SCRIPT_URL="https://example.com/path/to/$VM_NAME"

echo "Installing $VM_NAME..."

# Create installation directory if missing
mkdir -p "$INSTALL_DIR"

# Download or copy your mytoolvm script here
# Example: download from URL
if command -v curl >/dev/null 2>&1; then
    echo "Downloading $VM_NAME script..."
    curl -fsSL "$VM_SCRIPT_URL" -o "$VM_SCRIPT"
elif command -v wget >/dev/null 2>&1; then
    echo "Downloading $VM_NAME script..."
    wget -qO "$VM_SCRIPT" "$VM_SCRIPT_URL"
else
    echo "Error: curl or wget required to download $VM_NAME script."
    exit 1
fi

chmod +x "$VM_SCRIPT"

# Create bin dir if not exists
mkdir -p "$BIN_DIR"

# Create a shim in ~/.local/bin for easy access
SHIM_PATH="$BIN_DIR/$VM_NAME"

if [ -e "$SHIM_PATH" ]; then
    echo "Warning: $SHIM_PATH already exists, backing up."
    mv "$SHIM_PATH" "${SHIM_PATH}.bak"
fi

cat > "$SHIM_PATH" <<EOF
#!/usr/bin/env bash
"$VM_SCRIPT" "\$@"
EOF

chmod +x "$SHIM_PATH"

echo "Installed $VM_NAME executable to $SHIM_PATH"

# Check if ~/.local/bin is in PATH
if ! echo "$PATH" | grep -q "$BIN_DIR"; then
    echo "Warning: $BIN_DIR is not in your PATH."
    echo "You may want to add this line to your shell config:"
    echo "  export PATH=\"$BIN_DIR:\$PATH\""
fi

# Run init_shell to update shell config files
echo "Initializing shell config files..."
"$VM_SCRIPT" init_shell

echo ""
echo "Installation complete!"
echo "Restart your shell(s) or source your shell config files to use $VM_NAME."
echo "You can now run: $VM_NAME --help"
