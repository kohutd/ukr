#!/usr/bin/env bash

set -eo pipefail

# ============================================================================
# Константи та глобальні змінні
# ============================================================================

readonly UKR_VERSION="0.3.0"
readonly UKR_DIR="$HOME/.укр"
readonly UKR_PROGRAMS_DIR="$HOME/.local/share/укр"
readonly UKR_INSTALLED_PROGRAMS_DIR="$UKR_PROGRAMS_DIR/встановлені"
readonly UKR_CURRENT_LINKS="$UKR_PROGRAMS_DIR/поточні"
readonly UKR_PROGRAMS_META="$UKR_DIR/програми"

# ============================================================================
# Визначення системи та архітектури
# ============================================================================

detect_os() {
    local os
    os=$(uname -s)

    case "$os" in
        Linux)
            echo "лінукс"
            ;;
        Darwin)
            echo "макос"
            ;;
        CYGWIN* | MINGW* | MSYS*)
            echo "віндовс"
            ;;
        *)
            echo "Операційна система не підтримується: $os" >&2
            exit 1
            ;;
    esac
}

detect_arch() {
    local arch
    arch=$(uname -m)

    case "$arch" in
        x86_64 | amd64)
            echo "ікс86_64"
            ;;
        aarch64 | arm64)
            echo "аарч64"
            ;;
        i386 | i686)
            echo "ікс86"
            ;;
        *)
            echo "Архітектура не підтримується: $arch" >&2
            exit 1
            ;;
    esac
}

readonly UKR_OS=$(detect_os)
readonly UKR_ARCH=$(detect_arch)

# ============================================================================
# Ініціалізація директорій
# ============================================================================

init_directories() {
    mkdir -p "$UKR_INSTALLED_PROGRAMS_DIR"
    mkdir -p "$UKR_CURRENT_LINKS"
}

init_directories

# ============================================================================
# Допоміжні функції
# ============================================================================

print_error() {
    echo "ПОМИЛКА: $*" >&2
}

cleanup_temp_files() {
    local -a files=("$@")
    rm -rf "${files[@]}" 2>/dev/null || true
}

compute_sha256() {
    local file="$1"

    if command -v sha256sum &>/dev/null; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v shasum &>/dev/null; then
        shasum -a 256 "$file" | awk '{print $1}'
    else
        print_error "Не знайдено утиліту для обчислення SHA256"
        return 1
    fi
}


# ============================================================================
# Функції для виводу інформації
# ============================================================================

show_usage() {
    cat <<-'EOF'
	Використання: укр <команда> [програма] [версія]

	Команди:
	  встановити       <програма> [версія]
	  видалити         <програма> [версія]
	  використовувати  <програма> <версія>
	  використовується [програма]
	  встановлені      [програма]
	  доступні         [програма]

	Приклади:
	  укр встановити ціль
	  укр встановити мавка 0.123.0
	EOF
}

show_info() {
    echo "укр $UKR_VERSION"
    echo ""
    show_usage
    exit 0
}

# ============================================================================
# Функції для роботи з метаданими програм
# ============================================================================

get_program_meta_dir() {
    local program="$1"
    echo "$UKR_PROGRAMS_META/$program"
}

validate_program_meta() {
    local program="$1"
    local meta_dir
    local url_file
    local key_file

    meta_dir=$(get_program_meta_dir "$program")
    url_file="$meta_dir/url.txt"
    key_file="$meta_dir/public_key.asc"

    if [[ ! -f "$url_file" || ! -f "$key_file" ]]; then
        print_error "Програму '$program' не знайдено або метадані відсутні."
        return 1
    fi

    return 0
}

get_program_base_url() {
    local program="$1"
    local meta_dir
    local url_file

    meta_dir=$(get_program_meta_dir "$program")
    url_file="$meta_dir/url.txt"

    cat "$url_file"
}

get_program_public_key() {
    local program="$1"
    local meta_dir

    meta_dir=$(get_program_meta_dir "$program")
    echo "$meta_dir/public_key.asc"
}

# ============================================================================
# Функції для роботи з версіями
# ============================================================================

get_installed_dir() {
    local program="$1"
    local version="$2"
    echo "$UKR_INSTALLED_PROGRAMS_DIR/$program/$version"
}

get_current_link_path() {
    local program="$1"
    echo "$UKR_CURRENT_LINKS/$program"
}

list_available_versions() {
    local program="$1"
    local url_file
    local base_url
    local versions

    url_file="$UKR_PROGRAMS_META/$program/url.txt"

    if [[ ! -f "$url_file" ]]; then
        return 0
    fi

    base_url=$(cat "$url_file")
    versions=$(curl -fsSL "$base_url/доступні-версії-$UKR_OS-$UKR_ARCH.txt" 2>/dev/null || echo "")

    if [[ -z "$versions" ]]; then
        return 0
    fi

    # Ensure output ends with newline
    if [[ "$versions" != *$'\n' ]]; then
        echo "$versions"
    else
        echo -n "$versions"
    fi
}

get_latest_version() {
    local program="$1"
    list_available_versions "$program" | tail -n 1
}

list_installed_programs() {
    if [[ ! -d "$UKR_INSTALLED_PROGRAMS_DIR" ]]; then
        return 0
    fi

    local programs
    programs=($(ls -1 "$UKR_INSTALLED_PROGRAMS_DIR" 2>/dev/null || true))

    if [[ ${#programs[@]} -eq 0 ]]; then
        return 0
    fi

    printf '%s\n' "${programs[@]}"
}

list_installed_versions() {
    local program="$1"
    local prog_dir="$UKR_INSTALLED_PROGRAMS_DIR/$program"

    if [[ ! -d "$prog_dir" ]]; then
        return 0
    fi

    local versions
    versions=($(ls -1 "$prog_dir" 2>/dev/null || true))

    if [[ ${#versions[@]} -eq 0 ]]; then
        return 0
    fi

    printf '%s\n' "${versions[@]}"
}

list_all_programs() {
    local prog_dir

    for prog_dir in "$UKR_PROGRAMS_META/"*; do
        [[ -d "$prog_dir" ]] || continue
        basename "$prog_dir"
    done
}

# ============================================================================
# Функції для перевірки підпису та контрольної суми
# ============================================================================

verify_signature_and_checksum() {
    local program="$1"
    local version="$2"
    local archive_file="$3"
    local checksum_file="$4"
    local filename="$5"

    local gpg_temp_dir
    local key_file
    local checksum_line
    local expected_hash
    local file_hash

    echo "- Перевіряємо підпис..."

    gpg_temp_dir=$(mktemp -d)
    chmod 700 "$gpg_temp_dir"

    key_file=$(get_program_public_key "$program")

    if ! gpg --homedir "$gpg_temp_dir" --quiet --import "$key_file" &>/dev/null; then
        print_error "Не вдалося імпортувати публічний ключ."
        cleanup_temp_files "$gpg_temp_dir"
        return 1
    fi

    if ! gpg --homedir "$gpg_temp_dir" --verify "$checksum_file" &>/dev/null; then
        print_error "Підпис недійсний або пошкоджений."
        cleanup_temp_files "$gpg_temp_dir"
        return 1
    fi

    checksum_line=$(gpg --homedir "$gpg_temp_dir" --decrypt "$checksum_file" 2>/dev/null | grep "$filename")
    expected_hash=$(echo "$checksum_line" | awk '{print $1}')
    file_hash=$(compute_sha256 "$archive_file")

    if [[ "$expected_hash" != "$file_hash" ]]; then
        print_error "Контрольна сума не збігається!"
        echo "  Очікувалась: $expected_hash" >&2
        echo "  Отримана:    $file_hash" >&2
        cleanup_temp_files "$gpg_temp_dir"
        return 1
    fi

    echo "- Контрольна сума перевірена."
    cleanup_temp_files "$gpg_temp_dir"

    return 0
}

# ============================================================================
# Функції для завантаження та розпакування
# ============================================================================

download_file() {
    local url="$1"
    local output_file="$2"
    local description="$3"

    echo "- Завантажуємо $description з $url"

    if ! curl --progress-bar -fSL "$url" -o "$output_file"; then
        print_error "Не вдалося завантажити $description"
        return 1
    fi

    return 0
}

extract_archive() {
    local archive_file="$1"
    local target_dir="$2"

    echo "- Розпаковуємо..."

    if ! tar -xJf "$archive_file" -C "$target_dir"; then
        print_error "Не вдалося розпакувати архів."
        return 1
    fi

    return 0
}

find_extracted_directory() {
    local temp_dir="$1"
    local extracted_dir

    extracted_dir=$(find "$temp_dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)

    if [[ -z "$extracted_dir" ]]; then
        print_error "Не вдалося знайти розпаковану директорію."
        return 1
    fi

    echo "$extracted_dir"
    return 0
}


# ============================================================================
# Основні функції команд
# ============================================================================

cmd_install() {
    local program="$1"
    local version="$2"
    local base_url
    local target_dir
    local tmpfile
    local tmpchecksum
    local tmpdir
    local filename
    local url
    local checksum_url
    local extracted_dir

    # Validate program metadata
    if ! validate_program_meta "$program"; then
        exit 1
    fi

    base_url=$(get_program_base_url "$program")

    # Determine version to install
    if [[ -z "$version" ]]; then
        echo "Версію не задано. Отримуємо останню доступну версію..."
        version=$(get_latest_version "$program")

        if [[ -z "$version" ]]; then
            print_error "Не вдалося отримати останню версію для '$program'."
            exit 1
        fi

        echo "Остання доступна версія: $version"
    fi

    # Check if already installed
    target_dir=$(get_installed_dir "$program" "$version")

    if [[ -d "$target_dir" ]]; then
        echo "Програму '$program' версії $version вже встановлено."
        return 0
    fi

    # Prepare directories
    mkdir -p "$(dirname "$target_dir")"

    # Create temporary files
    tmpfile=$(mktemp)
    tmpchecksum=$(mktemp)
    tmpdir=$(mktemp -d)

    # Construct URLs
    filename="${program}-${version}-${UKR_OS}-${UKR_ARCH}.tar.xz"
    url="${base_url}/${version}/${filename}"
    checksum_url="${url}.sha256.signed"

    echo "Встановлюємо $program $version:"

    # Download archive
    if ! download_file "$url" "$tmpfile" "архів"; then
        cleanup_temp_files "$tmpfile" "$tmpchecksum" "$tmpdir"
        exit 1
    fi

    # Download checksum
    echo "- Завантажуємо контрольну суму з $checksum_url"
    if ! curl --silent -fSL "$checksum_url" -o "$tmpchecksum"; then
        print_error "Не вдалося завантажити файл .sha256.signed"
        cleanup_temp_files "$tmpfile" "$tmpchecksum" "$tmpdir"
        exit 1
    fi

    # Verify signature and checksum
    if ! verify_signature_and_checksum "$program" "$version" "$tmpfile" "$tmpchecksum" "$filename"; then
        cleanup_temp_files "$tmpfile" "$tmpchecksum" "$tmpdir"
        exit 1
    fi

    # Extract archive
    if ! extract_archive "$tmpfile" "$tmpdir"; then
        cleanup_temp_files "$tmpfile" "$tmpchecksum" "$tmpdir"
        exit 1
    fi

    # Find and move extracted directory
    if ! extracted_dir=$(find_extracted_directory "$tmpdir"); then
        cleanup_temp_files "$tmpfile" "$tmpchecksum" "$tmpdir"
        exit 1
    fi

    mv "$extracted_dir" "$target_dir"

    # Cleanup
    cleanup_temp_files "$tmpfile" "$tmpchecksum" "$tmpdir"

    echo "- Встановлено в $target_dir"

    # Automatically use this version
    cmd_use "$program" "$version"
}

cmd_use() {
    local program="$1"
    local version="$2"
    local target_dir
    local link_path

    target_dir=$(get_installed_dir "$program" "$version")

    if [[ ! -d "$target_dir" ]]; then
        print_error "Версія $version для $program не встановлена."
        exit 1
    fi

    link_path=$(get_current_link_path "$program")
    mkdir -p "$(dirname "$link_path")"

    ln -sfn "$target_dir" "$link_path"

    echo "Програма $program тепер використовує версію $version."
}

cmd_current() {
    local program="$1"
    local link_path
    local target_path
    local version

    link_path=$(get_current_link_path "$program")

    if [[ ! -L "$link_path" ]]; then
        return 0
    fi

    target_path=$(readlink "$link_path")
    version=$(basename "$target_path")

    echo "$version"
}

cmd_list_installed() {
    local program="$1"

    if [[ -z "$program" ]]; then
        list_installed_programs
    else
        list_installed_versions "$program"
    fi
}

cmd_list_available() {
    local program="$1"

    if [[ -z "$program" ]]; then
        list_all_programs
    else
        list_available_versions "$program"
    fi
}

cmd_init_shells() {
    local bash_rc="$HOME/.bashrc"
    local fish_rc="$HOME/.config/fish/config.fish"
    local updated=0

    echo "Додаємо PATH..."

    if [[ -f "$bash_rc" ]] && ! grep -q '.укр/env.bash' "$bash_rc"; then
        {
            echo ''
            echo '. "$HOME/.укр/env.bash"'
            echo ''
        } >> "$bash_rc"
        echo "  -> Додано в $bash_rc"
        updated=1
    fi

    if [[ -f "$fish_rc" ]] && ! grep -q '.укр/env.fish' "$fish_rc"; then
        {
            echo ''
            echo 'source "$HOME/.укр/env.fish"'
            echo ''
        } >> "$fish_rc"
        echo "  -> Додано в $fish_rc"
        updated=1
    fi

    if [[ $updated -eq 0 ]]; then
        echo "Ініціалізацію завершено. Жоден файл конфігурації shell не було змінено."
    else
        echo "Ініціалізацію завершено. Перезапустіть ваш shell або виконайте source на файли вище."
    fi
}

cmd_delete() {
    local program="$1"
    local version="$2"
    local force="$3"
    local target_dir
    local link_path
    local confirm

    if [[ -z "$program" ]]; then
        print_error "Не вказано програму."
        show_usage
        exit 1
    fi

    if [[ -n "$version" ]]; then
        # Delete specific version
        target_dir=$(get_installed_dir "$program" "$version")

        if [[ ! -d "$target_dir" ]]; then
            print_error "Версія $version для $program не знайдена."
            exit 1
        fi

        if [[ "$force" != "--force" ]]; then
            echo -n "Ви дійсно хочете видалити $program $version? [т/Н] "
            read -r confirm

            if [[ "$confirm" != "т" && "$confirm" != "Т" ]]; then
                echo "Скасовано."
                exit 0
            fi
        fi

        rm -rf "$target_dir"
        echo "Видалено $program $version."

        # Clean up current symlink if it pointed to the deleted version
        link_path=$(get_current_link_path "$program")

        if [[ -L "$link_path" && "$(readlink "$link_path")" == "$target_dir" ]]; then
            rm -f "$link_path"
            echo "Поточне посилання для $program видалено."
        fi
    else
        # Delete entire program
        target_dir="$UKR_INSTALLED_PROGRAMS_DIR/$program"

        if [[ ! -d "$target_dir" ]]; then
            print_error "Програма $program не знайдена."
            exit 1
        fi

        if [[ "$force" != "--force" ]]; then
            echo -n "Ви дійсно хочете повністю видалити $program і всі її версії? [т/Н] "
            read -r confirm

            if [[ "$confirm" != "т" && "$confirm" != "Т" ]]; then
                echo "Скасовано."
                exit 0
            fi
        fi

        rm -rf "$target_dir"
        rm -f "$(get_current_link_path "$program")"
        echo "Вся програма $program видалена разом з версіями і поточним посиланням."
    fi
}

# ============================================================================
# Головна логіка програми
# ============================================================================

main() {
    local command="$1"


    case "$command" in
        встановити)
            if [[ -z "$2" ]]; then
                show_usage
                exit 1
            fi
            cmd_install "$2" "$3"
            ;;
        видалити)
            if [[ -z "$2" ]]; then
                show_usage
                exit 1
            fi
            cmd_delete "$2" "$3" "$4"
            ;;
        використовувати)
            if [[ -z "$2" || -z "$3" ]]; then
                show_usage
                exit 1
            fi
            cmd_use "$2" "$3"
            ;;
        використовується)
            if [[ -z "$2" ]]; then
                show_usage
                exit 1
            fi
            cmd_current "$2"
            ;;
        встановлені)
            cmd_list_installed "$2"
            ;;
        доступні)
            cmd_list_available "$2"
            ;;
        ініціалізувати)
            cmd_init_shells
            ;;
        *)
            show_info
            ;;
    esac
}

main "$@"
