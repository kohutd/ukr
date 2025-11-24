#!/usr/bin/env bash

UKR_VERSION="0.3.0"
UKR_DIR="$HOME/.укр"
UKR_PROGRAMS_DIR="$HOME/.local/share/укр"
UKR_INSTALLED_PROGRAMS_DIR="$UKR_PROGRAMS_DIR/встановлені"
UKR_CURRENT_LINKS="$UKR_PROGRAMS_DIR/поточні"
UKR_PROGRAMS_META="$UKR_DIR/програми"

UKR_OS=$(uname -s)
case "$UKR_OS" in
    Linux)
        UKR_OS="лінукс"
        ;;
    Darwin)
        UKR_OS="макос"
        ;;
    CYGWIN* | MINGW* | MSYS*)
        UKR_OS="віндовс"
        ;;
    *)
        echo "Операційна система не підтримується: $UKR_OS"
        exit 1
        ;;
esac

UKR_ARCH=$(uname -m)
case "$UKR_ARCH" in
    x86_64 | amd64)
        UKR_ARCH="ікс86_64"
        ;;
    aarch64 | arm64)
        UKR_ARCH="аарч64"
        ;;
    i386 | i686)
        UKR_ARCH="ікс86"
        ;;
    *)
        echo "Архітектура не підтримується: $UKR_ARCH"
        exit 1
        ;;
esac

mkdir -p "$UKR_INSTALLED_PROGRAMS_DIR"
mkdir -p "$UKR_CURRENT_LINKS"

usage() {
    echo "Використання: укр <команда> [програма] [версія]"
    echo ""
    echo "Команди:"
    echo "  встановити       <програма> [версія]"
    echo "  видалити         <програма> [версія]"
    echo "  використовувати  <програма> <версія>"
    echo "  використовується [програма]"
    echo "  встановлені      [програма]"
    echo "  доступні         [програма]"
    echo ""
    echo "Приклади:"
    echo "  укр встановити ціль"
    echo "  укр встановити мавка 0.123.0"
}

usage_1() {
    usage
    exit 1
}

info() {
    echo "укр $UKR_VERSION"
    echo ""
    usage
    exit 0
}

install_version() {
    PROGRAM="$1"
    VERSION="$2"
    PROGRAM_META_DIR="$UKR_PROGRAMS_META/$PROGRAM"
    URL_FILE="$PROGRAM_META_DIR/url.txt"
    KEY_FILE="$PROGRAM_META_DIR/public_key.asc"

    if [ ! -f "$URL_FILE" ] || [ ! -f "$KEY_FILE" ]; then
        echo "ПОМИЛКА: Програму '$PROGRAM' не знайдено або метадані відсутні."
        exit 1
    fi

    PROGRAM_BASE_URL=$(< "$URL_FILE")

    if [ -z "$VERSION" ]; then
        echo "Версію не задано. Отримуємо останню доступну версію..."
        VERSION=$(list_available_versions "$PROGRAM" | tail -n 1)
        if [ -z "$VERSION" ]; then
            echo "ПОМИЛКА: Не вдалося отримати останню версію для '$PROGRAM'."
            exit 1
        fi
        echo "Остання доступна версія: $VERSION"
    fi

    mkdir -p "$UKR_INSTALLED_PROGRAMS_DIR/$PROGRAM"
    TARGET_DIR="$UKR_INSTALLED_PROGRAMS_DIR/$PROGRAM/$VERSION"

    if [ -d "$TARGET_DIR" ]; then
        echo "Програму '$PROGRAM' версії $VERSION вже встановлено."
        return
    fi

    TMPFILE=$(mktemp)
    TMPCHECKSUM=$(mktemp)
    TMPDIR=$(mktemp -d)

    FILENAME="${PROGRAM}-${VERSION}-${UKR_OS}-${UKR_ARCH}.tar.xz"
    URL="${PROGRAM_BASE_URL}/${VERSION}/${FILENAME}"
    CHECKSUM_URL="${URL}.sha256.signed"

    echo "Встановлюємо $PROGRAM $VERSION:"
    echo "- Завантажуємо з $URL"
    if ! curl --progress-bar -fSL "$URL" -o "$TMPFILE"; then
        echo "  ПОМИЛКА: Не вдалося завантажити $FILENAME"
        rm -f "$TMPFILE" "$TMPCHECKSUM"
        rm -rf "$TMPDIR"
        exit 1
    fi

    echo "- Завантажуємо контрольну суму з $CHECKSUM_URL"
    if ! curl --silent -fSL "$CHECKSUM_URL" -o "$TMPCHECKSUM"; then
        echo "  ПОМИЛКА: Не вдалося завантажити файл .sha256.signed"
        rm -f "$TMPFILE" "$TMPCHECKSUM"
        rm -rf "$TMPDIR"
        exit 1
    fi

    echo "- Перевіряємо підпис..."
    GPG_TEMP_DIR=$(mktemp -d)
    chmod 700 "$GPG_TEMP_DIR"

    if ! gpg --homedir "$GPG_TEMP_DIR" --quiet --import "$KEY_FILE" &>/dev/null; then
        echo "  ПОМИЛКА: Не вдалося імпортувати публічний ключ."
        rm -rf "$GPG_TEMP_DIR" "$TMPFILE" "$TMPCHECKSUM" "$TMPDIR"
        exit 1
    fi

    if ! gpg --homedir "$GPG_TEMP_DIR" --verify "$TMPCHECKSUM" &>/dev/null; then
        echo "  ПОМИЛКА: Підпис недійсний або пошкоджений."
        rm -rf "$GPG_TEMP_DIR" "$TMPFILE" "$TMPCHECKSUM" "$TMPDIR"
        exit 1
    fi

    CHECKSUM_LINE=$(gpg --homedir "$GPG_TEMP_DIR" --decrypt "$TMPCHECKSUM" 2>/dev/null | grep "$FILENAME")
    EXPECTED_HASH=$(echo "$CHECKSUM_LINE" | awk '{print $1}')
    FILE_HASH=$(sha256sum "$TMPFILE" | awk '{print $1}')

    if [ "$EXPECTED_HASH" != "$FILE_HASH" ]; then
        echo "  ПОМИЛКА: Контрольна сума не збігається!"
        echo "  Очікувалась: $EXPECTED_HASH"
        echo "  Отримана:    $FILE_HASH"
        rm -rf "$GPG_TEMP_DIR" "$TMPFILE" "$TMPCHECKSUM" "$TMPDIR"
        exit 1
    fi

    echo "- Контрольна сума перевірена."

    echo "- Розпаковуємо..."
    if ! tar -xJf "$TMPFILE" -C "$TMPDIR"; then
        echo "  ПОМИЛКА: Не вдалося розпакувати архів."
        rm -rf "$GPG_TEMP_DIR" "$TMPFILE" "$TMPCHECKSUM" "$TMPDIR"
        exit 1
    fi

    EXTRACTED_DIR=$(find "$TMPDIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)
    if [ -z "$EXTRACTED_DIR" ]; then
        echo "  ПОМИЛКА: Не вдалося знайти розпаковану директорію."
        rm -rf "$GPG_TEMP_DIR" "$TMPFILE" "$TMPCHECKSUM" "$TMPDIR"
        exit 1
    fi

    mv "$EXTRACTED_DIR" "$TARGET_DIR"

    rm -rf "$GPG_TEMP_DIR" "$TMPFILE" "$TMPCHECKSUM" "$TMPDIR"

    echo "- Встановлено в $TARGET_DIR"

    use_version "$PROGRAM" "$VERSION"
}

use_version() {
    PROGRAM="$1"
    VERSION="$2"
    TARGET_DIR="$UKR_INSTALLED_PROGRAMS_DIR/$PROGRAM/$VERSION"
    LINK_PATH="$UKR_CURRENT_LINKS/$PROGRAM"

    if [ ! -d "$TARGET_DIR" ]; then
        echo "ПОМИЛКА: Версія $VERSION для $PROGRAM не встановлена."
        exit 1
    fi

    mkdir -p "$UKR_CURRENT_LINKS"

    ln -sfn "$TARGET_DIR" "$LINK_PATH"

    echo "Програма $PROGRAM тепер використовує версію $VERSION."
}

current_version() {
    PROGRAM="$1"
    LINK_PATH="$UKR_CURRENT_LINKS/$PROGRAM"

    if [ ! -L "$LINK_PATH" ]; then
        return
    fi

    TARGET_PATH=$(readlink "$LINK_PATH")
    VERSION=$(basename "$TARGET_PATH")

    echo "$VERSION"
}

list_installed() {
    if [ -z "$1" ]; then
        if [ ! -d "$UKR_INSTALLED_PROGRAMS_DIR" ]; then
            return
        fi

        PROGRAMS=($(ls -1 "$UKR_INSTALLED_PROGRAMS_DIR"))
        if [ ${#PROGRAMS[@]} -eq 0 ]; then
            return
        fi

        for prog in "${PROGRAMS[@]}"; do
            echo "$prog"
        done
    else
        PROGRAM="$1"
        PROG_DIR="$UKR_INSTALLED_PROGRAMS_DIR/$PROGRAM"

        if [ ! -d "$PROG_DIR" ]; then
            return
        fi

        VERSIONS=($(ls -1 "$PROG_DIR"))
        if [ ${#VERSIONS[@]} -eq 0 ]; then
            return
        fi

        for ver in "${VERSIONS[@]}"; do
            echo "$ver"
        done
    fi
}

list_available_versions() {
    PROGRAM="$1"
    URL_FILE="$UKR_PROGRAMS_META/$PROGRAM/url.txt"

    if [ ! -f "$URL_FILE" ]; then
        return
    fi

    PROGRAM_BASE_URL=$(< "$URL_FILE")

    AV=$(curl -fsSL "$PROGRAM_BASE_URL/доступні-версії-$UKR_OS-$UKR_ARCH.txt" || echo "")
    if [ "$AV" == "" ]
    then
        echo -en ""
    elif [[ "$AV" != *$'\n' ]]; then
        echo -en "$AV\n"
    else
        echo -n "$AV"
    fi
}

init_shells() {
    echo "Додаємо PATH..."

    updated=0

    BASH_RC="$HOME/.bashrc"
    if [ -f "$BASH_RC" ] && ! grep -q '.укр/env.bash' "$BASH_RC"; then
        echo '' >> "$BASH_RC"
        echo '. "$HOME/.укр/env.bash"' >> "$BASH_RC"
        echo '' >> "$BASH_RC"
        echo "  -> Додано в $BASH_RC"
        updated=1
    fi

    FISH_RC="$HOME/.config/fish/config.fish"
    if [ -f "$FISH_RC" ] && ! grep -q '.укр/env.fish' "$FISH_RC"; then
        echo '' >> "$FISH_RC"
        echo 'source "$HOME/.укр/env.fish"' >> "$FISH_RC"
        echo '' >> "$FISH_RC"
        echo "  -> Додано в $FISH_RC"
        updated=1
    fi

    if [ $updated -eq 0 ]; then
      echo "Ініціалізацію завершено. Жоден файл конфігурації shell не було змінено."
    else
      echo "Ініціалізацію завершено. Перезапустіть ваш shell або виконайте source на файли вище."
    fi
}

delete_version() {
    PROGRAM="$1"
    VERSION="$2"
    FORCE="$3"

    if [ -z "$PROGRAM" ]; then
        echo "ПОМИЛКА: Не вказано програму."
        usage_1
    fi

    if [ -n "$VERSION" ]; then
        TARGET_DIR="$UKR_INSTALLED_PROGRAMS_DIR/$PROGRAM/$VERSION"

        if [ ! -d "$TARGET_DIR" ]; then
            echo "ПОМИЛКА: Версія $VERSION для $PROGRAM не знайдена."
            exit 1
        fi

        if [ "$FORCE" != "--force" ]; then
            echo -n "Ви дійсно хочете видалити $PROGRAM $VERSION? [т/Н] "
            read -r CONFIRM
            if [[ "$CONFIRM" != "т" && "$CONFIRM" != "Т" ]]; then
                echo "Скасовано."
                exit 0
            fi
        fi

        rm -rf "$TARGET_DIR"
        echo "Видалено $PROGRAM $VERSION."

        # Clean up current symlink if it pointed to the deleted version
        LINK_PATH="$UKR_CURRENT_LINKS/$PROGRAM"
        if [ -L "$LINK_PATH" ] && [ "$(readlink "$LINK_PATH")" = "$TARGET_DIR" ]; then
            rm -f "$LINK_PATH"
            echo "Поточне посилання для $PROGRAM видалено."
        fi

    else
        TARGET_DIR="$UKR_INSTALLED_PROGRAMS_DIR/$PROGRAM"

        if [ ! -d "$TARGET_DIR" ]; then
            echo "ПОМИЛКА: Програма $PROGRAM не знайдена."
            exit 1
        fi

        if [ "$FORCE" != "--force" ]; then
            echo -n "Ви дійсно хочете повністю видалити $PROGRAM і всі її версії? [т/Н] "
            read -r CONFIRM
            if [[ "$CONFIRM" != "т" && "$CONFIRM" != "Т" ]]; then
                echo "Скасовано."
                exit 0
            fi
        fi

        rm -rf "$TARGET_DIR"
        rm -f "$UKR_CURRENT_LINKS/$PROGRAM"
        echo "Вся програма $PROGRAM видалена разом з версіями і поточним посиланням."
    fi
}

list_programs() {
    for prog_dir in "$UKR_PROGRAMS_META/"*; do
        [ -d "$prog_dir" ] || continue
        basename "$prog_dir"
    done
}

case "$1" in
    встановити)
        [ -z "$2" ] && usage_1
        install_version "$2" "$3"
        ;;
    видалити)
        [ -z "$2" ] && usage_1
        delete_version "$2" "$3" "$4"
        ;;
    використовувати)
        [ -z "$2" ] && usage_1
        [ -z "$3" ] && usage_1
        use_version "$2" "$3"
        ;;
    використовується)
        [ -z "$2" ] && usage_1
        current_version "$2"
        ;;
    встановлені)
        list_installed "$2"
        ;;
    доступні)
        if [ -z "$2" ]; then
            list_programs
        else
            list_available_versions "$2"
        fi
        ;;
    ініціалізувати)
        init_shells
        ;;
    *)
        info
        ;;
esac
