#!/bin/bash

UKR_ARCH=$(uname -m)
case "$UKR_ARCH" in
    x86_64 | amd64)
        UKR_ARCH="x86_64"
        ;;
    aarch64 | arm64)
        UKR_ARCH="aarch64"
        ;;
    i386 | i686)
        UKR_ARCH="x86"
        ;;
    *)
        echo "Архітектура не підтримується: $UKR_ARCH"
        exit 1
        ;;
esac

UKR_OS=$(uname -s)
case "$UKR_OS" in
    Linux)
        UKR_OS="linux"
        ;;
    Darwin)
        UKR_OS="darwin"
        ;;
    CYGWIN* | MINGW* | MSYS*)
        UKR_OS="windows"
        ;;
    *)
        echo "Операційна система не підтримується: $UKR_OS"
        exit 1
        ;;
esac

UKR_VERSION="0.1.0"
UKR_DIR="$HOME/.укр"
UKR_PROGRAMS_DIR="$HOME/.local/share/укр"
UKR_INSTALLED_PROGRAMS_DIR="$UKR_PROGRAMS_DIR/встановлені"
UKR_CURRENT_LINKS="$UKR_PROGRAMS_DIR/поточні"

AVAILABLE_PROGRAMS=(
  "ціль:https://github.com/tsil-ukr/files/raw/main/випуски-цілі"
  "мавка:https://github.com/mavka-ukr/files/raw/main/випуски-мавки"
)

mkdir -p "$UKR_INSTALLED_PROGRAMS_DIR"
mkdir -p "$UKR_CURRENT_LINKS"

usage() {
    echo "Використання: укр встановити <програма> <версія>"
    echo "                  використовувати <програма> <версія>"
    echo "                  видалити <програма> <версія>"
    echo "                  поточна <програма>"
    echo "                  встановлені <програма>"
    echo "                  доступні <програма>"
    echo "                  програми"
    echo "                  ініціалізувати"
    echo "                  оновитись"
    exit 1
}

info() {
    usage
}

install_version() {
    PROGRAM="$1"
    VERSION="$2"
    PROGRAM_BASE_URL=""

    for AVAILABLE_PROGRAM in "${AVAILABLE_PROGRAMS[@]}" ; do
        AVAILABLE_PROGRAM_NAME=${AVAILABLE_PROGRAM%%:*}
        AVAILABLE_PROGRAM_URL=${AVAILABLE_PROGRAM#*:}

        if [ "$PROGRAM" == "$AVAILABLE_PROGRAM_NAME" ]
        then
          PROGRAM_BASE_URL="$AVAILABLE_PROGRAM_URL"
        fi
    done

    if [ -z "$PROGRAM_BASE_URL" ]
    then
      echo "ПОМИЛКА: Програму $PROGRAM не визначено."
      exit 1
    fi

    mkdir -p "$UKR_INSTALLED_PROGRAMS_DIR/$PROGRAM"

    TARGET_DIR="$UKR_INSTALLED_PROGRAMS_DIR/$PROGRAM/$VERSION"

    if [ -d "$TARGET_DIR" ]; then
        echo "Програму $PROGRAM $VERSION вже встановлено."
        return
    fi

    TMPFILE=$(mktemp)
    TMPDIR=$(mktemp -d)
    URL="${PROGRAM_BASE_URL}/${VERSION}/${PROGRAM}-${VERSION}-${UKR_OS}-${UKR_ARCH}.tar.gz"

    echo "Встановлюємо $PROGRAM $VERSION:"
    echo "- Завантажуємо з $URL"
    if ! curl --progress-bar -fSL "$URL" -o "$TMPFILE"; then
        echo "  ПОМИЛКА: Не вдалось завантажити."
        rm -f "$TMPFILE"
        rm -rf "$TMPDIR"
        exit 1
    fi

    echo "- Розпаковуємо..."
    if ! tar -xzf "$TMPFILE" -C "$TMPDIR"; then
        echo "  ПОМИЛКА: Не вдалось розпакувати."
        rm -f "$TMPFILE"
        rm -rf "$TMPDIR"
        exit 1
    fi

    EXTRACTED_DIR=$(find "$TMPDIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)
    if [ -z "$EXTRACTED_DIR" ]; then
        echo "  ПОМИЛКА: Не вдалось знайти розпаковану директорію."
        rm -f "$TMPFILE"
        rm -rf "$TMPDIR"
        exit 1
    fi

    mv "$EXTRACTED_DIR" "$TARGET_DIR"

    rm -f "$TMPFILE"
    rm -rf "$TMPDIR"

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
    PROGRAM_BASE_URL=""

    for entry in "${AVAILABLE_PROGRAMS[@]}"; do
        name=${entry%%:*}
        url=${entry#*:}
        if [ "$PROGRAM" = "$name" ]; then
            PROGRAM_BASE_URL="$url"
            break
        fi
    done

    if [ -z "$PROGRAM_BASE_URL" ]; then
        return
    fi

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
        usage
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
    if [ "${#AVAILABLE_PROGRAMS[@]}" -eq 0 ]; then
        return
    fi

    for entry in "${AVAILABLE_PROGRAMS[@]}"; do
        name="${entry%%:*}"
        echo "$name"
    done
}

case "$1" in
    встановити)
        [ -z "$2" ] && usage
        [ -z "$3" ] && usage
        install_version "$2" "$3"
        ;;
    використовувати)
        [ -z "$2" ] && usage
        [ -z "$3" ] && usage
        use_version "$2" "$3"
        ;;
    поточна)
        [ -z "$2" ] && usage
        current_version "$2"
        ;;
    встановлені)
        list_installed "$2"
        ;;
    доступні)
        [ -z "$2" ] && usage
        list_available_versions "$2"
        ;;
    ініціалізувати)
        init_shells
        ;;
    видалити)
        [ -z "$2" ] && usage
        delete_version "$2" "$3" "$4"
        ;;
    програми)
        list_programs
        ;;
    *)
        info
        ;;
esac
