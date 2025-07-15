#!/bin/bash

# Define variables
ZIP_URL="https://github.com/kohutd/ukr/archive/refs/heads/main.zip"
INSTALL_DIR="$HOME/.укр"
ZIP_FILE="/tmp/укр.zip"

# Check if the install directory already exists
if [ -d "$INSTALL_DIR" ]; then
  echo "The directory $INSTALL_DIR already exists."
  read -p "Do you want to reinstall the program? (y/N): " choice
  case "$choice" in
    y|Y )
      echo "Reinstalling..."
      rm -rf "$INSTALL_DIR"
      ;;
    * )
      echo "Installation cancelled."
      exit 0
      ;;
  esac
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

# Optional: flatten directory if ZIP contains a top-level folder
# Detect if top-level directory exists and move files up one level
TOP_DIR=$(find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)
if [ "$(find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 | wc -l)" -eq 1 ] && [ -d "$TOP_DIR" ]; then
  echo "Flattening directory structure..."
  mv "$TOP_DIR"/* "$INSTALL_DIR"
  rmdir "$TOP_DIR"
fi

# Run initialization
echo "Running initialization script..."
"$HOME/.укр.sh" ініціалізувати

# Check if init succeeded
if [ $? -ne 0 ]; then
  echo "Initialization failed. Exiting."
  exit 1
fi

echo "Installation and initialization completed successfully."
