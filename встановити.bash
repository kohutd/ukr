#!/bin/bash

# Define variables
ZIP_URL="https://github.com/kohutd/ukr/archive/refs/heads/main.zip"
INSTALL_DIR="$HOME/.укр"
ZIP_FILE="/tmp/укр.zip"

# Check if install directory already exists
if [ -d "$INSTALL_DIR" ]; then
  echo "The directory $INSTALL_DIR already exists."
  exit 0
fi

# Create install directory
mkdir -p "$INSTALL_DIR"

# Download the ZIP file
echo "Downloading program from $ZIP_URL..."
curl -L "$ZIP_URL" -o "$ZIP_FILE"

# Check if download succeeded
if [ $? -ne 0 ]; then
  echo "Download failed. Exiting."
  exit 1
fi

# Unzip to install directory
echo "Unzipping to $INSTALL_DIR..."
unzip -q "$ZIP_FILE" -d "$INSTALL_DIR"

# Flatten directory if needed
TOP_DIR=$(find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)
if [ "$(find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 | wc -l)" -eq 1 ] && [ -d "$TOP_DIR" ]; then
  echo "Flattening directory structure..."
  mv "$TOP_DIR"/* "$INSTALL_DIR"
  mv "$TOP_DIR"/.* "$INSTALL_DIR"
  rmdir "$TOP_DIR"
fi

# Run initialization
echo "Running initialization script..."
"$HOME/.укр/укр.bash" ініціалізувати

if [ $? -ne 0 ]; then
  echo "Initialization failed. Exiting."
  exit 1
fi

echo "Installation and initialization completed successfully."
