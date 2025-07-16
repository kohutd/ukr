#!/bin/bash

# Define variables
ZIP_URL="https://github.com/kohutd/ukr/archive/refs/heads/main.zip"
INSTALL_DIR="$HOME/.укр"
ZIP_FILE="/tmp/укр.zip"

install_dependencies() {
    # Визначення UKR_OS, якщо не встановлено
    if [ -z "$UKR_OS" ]; then
        case "$(uname -s)" in
            Linux) UKR_OS="linux" ;;
            Darwin) UKR_OS="darwin" ;;
            CYGWIN*|MINGW*|MSYS*) UKR_OS="windows" ;;
            *) echo "Операційна система не підтримується: $(uname -s)"; return 1 ;;
        esac
    fi

    # Перевірка наявності команд
    missing_deps=()
    for dep in curl gpg tar sha256sum unzip; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -eq 0 ]; then
        echo "Усі необхідні залежності встановлені."
        return 0
    fi

    echo "Відсутні необхідні залежності: ${missing_deps[*]}"
    echo "Щоб встановити їх вручну для ОС $UKR_OS, виконайте відповідні команди:"

    if [ "$UKR_OS" = "linux" ]; then
        if [ -f /etc/debian_version ]; then
            echo "Debian/Ubuntu-подібна система:"
            echo "sudo apt update"
            echo "sudo apt install -y curl gnupg tar coreutils unzip"
        elif [ -f /etc/arch-release ]; then
            echo "Arch Linux-подібна система:"
            echo "sudo pacman -Sy --needed --noconfirm curl gnupg tar coreutils unzip"
        elif [ -f /etc/alpine-release ]; then
            echo "Alpine Linux:"
            echo "sudo apk add curl gnupg tar coreutils unzip"
        else
            echo "Невідома Linux-система. Будь ласка, встановіть вручну: curl, gnupg, tar, coreutils, unzip"
        fi
    elif [ "$UKR_OS" = "darwin" ]; then
        echo "macOS:"
        echo "brew install curl gnupg tar coreutils unzip"
    else
        echo "Автоматичне встановлення залежностей не підтримується для цієї ОС: $UKR_OS"
    fi
}

# Check if install directory already exists
if [ -d "$INSTALL_DIR" ]; then
  echo "Директорія $INSTALL_DIR вже існує."
  exit 0
fi

install_dependencies

# Create install directory
mkdir -p "$INSTALL_DIR"

# Download the ZIP file
echo "Завантажуємо $ZIP_URL..."
curl -L "$ZIP_URL" -o "$ZIP_FILE"

# Check if download succeeded
if [ $? -ne 0 ]; then
  echo "Завантаження не вдалось. Виходимо."
  exit 1
fi

# Unzip to install directory
echo "Розпаковуємо $INSTALL_DIR..."
unzip -q "$ZIP_FILE" -d "$INSTALL_DIR"

# Flatten directory if needed
TOP_DIR=$(find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)
if [ "$(find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 | wc -l)" -eq 1 ] && [ -d "$TOP_DIR" ]; then
  mv "$TOP_DIR"/* "$INSTALL_DIR"
  mv "$TOP_DIR"/.* "$INSTALL_DIR"
  rmdir "$TOP_DIR"
fi

# Run initialization
"$HOME/.укр/укр.bash" ініціалізувати