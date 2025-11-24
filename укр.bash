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
# Кольори та стилі
# ============================================================================

# Check if terminal supports colors
if [[ -t 1 ]] && command -v tput &>/dev/null && tput colors &>/dev/null && [[ $(tput colors) -ge 8 ]]; then
    readonly COLOR_RESET='\033[0m'
    readonly COLOR_BOLD='\033[1m'
    readonly COLOR_DIM='\033[2m'

    readonly COLOR_RED='\033[0;31m'
    readonly COLOR_GREEN='\033[0;32m'
    readonly COLOR_YELLOW='\033[0;33m'
    readonly COLOR_BLUE='\033[0;34m'
    readonly COLOR_MAGENTA='\033[0;35m'
    readonly COLOR_CYAN='\033[0;36m'
    readonly COLOR_WHITE='\033[0;37m'

    readonly COLOR_BRED='\033[1;31m'
    readonly COLOR_BGREEN='\033[1;32m'
    readonly COLOR_BYELLOW='\033[1;33m'
    readonly COLOR_BBLUE='\033[1;34m'
    readonly COLOR_BMAGENTA='\033[1;35m'
    readonly COLOR_BCYAN='\033[1;36m'
    readonly COLOR_BWHITE='\033[1;37m'
else
    readonly COLOR_RESET=''
    readonly COLOR_BOLD=''
    readonly COLOR_DIM=''
    readonly COLOR_RED=''
    readonly COLOR_GREEN=''
    readonly COLOR_YELLOW=''
    readonly COLOR_BLUE=''
    readonly COLOR_MAGENTA=''
    readonly COLOR_CYAN=''
    readonly COLOR_WHITE=''
    readonly COLOR_BRED=''
    readonly COLOR_BGREEN=''
    readonly COLOR_BYELLOW=''
    readonly COLOR_BBLUE=''
    readonly COLOR_BMAGENTA=''
    readonly COLOR_BCYAN=''
    readonly COLOR_BWHITE=''
fi

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
    echo -e "${COLOR_BRED}[!] ПОМИЛКА:${COLOR_RESET} $*" >&2
}

print_success() {
    echo -e "${COLOR_BGREEN}[+]${COLOR_RESET} $*"
}

print_info() {
    echo -e "${COLOR_BCYAN}[i]${COLOR_RESET} $*"
}

print_warning() {
    echo -e "${COLOR_BYELLOW}[!]${COLOR_RESET} $*"
}

print_step() {
    echo -e "${COLOR_BBLUE}>>${COLOR_RESET} $*"
}

print_header() {
    echo ""
    echo -e "${COLOR_BOLD}${COLOR_BMAGENTA}===============================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}  $*${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_BMAGENTA}===============================================${COLOR_RESET}"
    echo ""
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

show_spinner() {
    local pid=$1
    local message=$2
    local spinstr='|/-\'
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr:i++%${#spinstr}:1}
        printf "\r${COLOR_BCYAN}%s${COLOR_RESET} %s" "$temp" "$message"
        sleep 0.1
    done
    printf "\r"
}
# ============================================================================
# Функції для виводу інформації
# ============================================================================

show_usage() {
    echo ""
    echo -e "${COLOR_BOLD}${COLOR_BMAGENTA}УКР${COLOR_RESET} ${COLOR_DIM}v${UKR_VERSION}${COLOR_RESET} - Менеджер версій програм"
    echo ""
    echo -e "${COLOR_BOLD}Використання:${COLOR_RESET}"
    echo -e "  ${COLOR_BCYAN}укр${COLOR_RESET} ${COLOR_YELLOW}<команда>${COLOR_RESET} ${COLOR_DIM}[програма] [версія]${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_BOLD}Команди:${COLOR_RESET}"
    echo -e "  ${COLOR_BGREEN}встановити${COLOR_RESET}       ${COLOR_DIM}<програма> [версія]${COLOR_RESET}  Встановити програму"
    echo -e "  ${COLOR_BRED}видалити${COLOR_RESET}          ${COLOR_DIM}<програма> [версія]${COLOR_RESET}  Видалити програму"
    echo -e "  ${COLOR_BBLUE}використовувати${COLOR_RESET}   ${COLOR_DIM}<програма> <версія>${COLOR_RESET}  Переключитися на версію"
    echo -e "  ${COLOR_BCYAN}використовується${COLOR_RESET}  ${COLOR_DIM}[програма]${COLOR_RESET}           Показати поточну версію"
    echo -e "  ${COLOR_BMAGENTA}встановлені${COLOR_RESET}       ${COLOR_DIM}[програма]${COLOR_RESET}           Список встановлених"
    echo -e "  ${COLOR_BYELLOW}доступні${COLOR_RESET}          ${COLOR_DIM}[програма]${COLOR_RESET}           Список доступних"
    echo -e "  ${COLOR_BWHITE}ініціалізувати${COLOR_RESET}                         Налаштувати shell"
    echo ""
    echo -e "${COLOR_BOLD}Приклади:${COLOR_RESET}"
    echo -e "  ${COLOR_DIM}# Встановити останню версію${COLOR_RESET}"
    echo -e "  ${COLOR_BCYAN}укр${COLOR_RESET} встановити ціль"
    echo ""
    echo -e "  ${COLOR_DIM}# Встановити конкретну версію${COLOR_RESET}"
    echo -e "  ${COLOR_BCYAN}укр${COLOR_RESET} встановити мавка 0.123.0"
    echo ""
}

show_info() {
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

    print_step "Перевіряємо цифровий підпис..."

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

    print_success "Підпис перевірено"

    print_step "Перевіряємо контрольну суму..."

    checksum_line=$(gpg --homedir "$gpg_temp_dir" --decrypt "$checksum_file" 2>/dev/null | grep "$filename")
    expected_hash=$(echo "$checksum_line" | awk '{print $1}')
    file_hash=$(compute_sha256 "$archive_file")

    if [[ "$expected_hash" != "$file_hash" ]]; then
        print_error "Контрольна сума не збігається!"
        echo -e "  ${COLOR_DIM}Очікувалась:${COLOR_RESET} ${COLOR_YELLOW}$expected_hash${COLOR_RESET}" >&2
        echo -e "  ${COLOR_DIM}Отримана:${COLOR_RESET}    ${COLOR_RED}$file_hash${COLOR_RESET}" >&2
        cleanup_temp_files "$gpg_temp_dir"
        return 1
    fi

    print_success "Контрольна сума перевірена"
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

    print_step "Завантажуємо $description..."

    if ! curl --progress-bar -fSL "$url" -o "$output_file" 2>&1 | \
        while IFS= read -r line; do
            if [[ "$line" =~ ([0-9]+\.[0-9]+)% ]]; then
                local percent="${BASH_REMATCH[1]}"
                printf "\r  ${COLOR_BCYAN}▓${COLOR_RESET} Прогрес: ${COLOR_BGREEN}%s%%${COLOR_RESET}" "$percent"
            fi
        done; then
        printf "\r"
        print_error "Не вдалося завантажити $description"
        return 1
    fi

    printf "\r"
    print_success "Завантажено $description"
    return 0
}

extract_archive() {
    local archive_file="$1"
    local target_dir="$2"

    print_step "Розпаковуємо архів..."

    if ! tar -xJf "$archive_file" -C "$target_dir" 2>&1; then
        print_error "Не вдалося розпакувати архів."
        return 1
    fi

    print_success "Архів розпаковано"
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
        print_info "Версію не задано. Отримуємо останню доступну версію..."
        version=$(get_latest_version "$program")

        if [[ -z "$version" ]]; then
            print_error "Не вдалося отримати останню версію для '$program'."
            exit 1
        fi

        print_success "Остання доступна версія: ${COLOR_BWHITE}$version${COLOR_RESET}"
    fi

    # Check if already installed
    target_dir=$(get_installed_dir "$program" "$version")

    if [[ -d "$target_dir" ]]; then
        print_warning "Програму ${COLOR_BWHITE}$program${COLOR_RESET} версії ${COLOR_BWHITE}$version${COLOR_RESET} вже встановлено."
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

    print_header "Встановлення ${COLOR_BWHITE}$program${COLOR_RESET} ${COLOR_BGREEN}$version${COLOR_RESET}"

    # Download archive
    if ! download_file "$url" "$tmpfile" "архів"; then
        cleanup_temp_files "$tmpfile" "$tmpchecksum" "$tmpdir"
        exit 1
    fi

    # Download checksum
    print_step "Завантажуємо контрольну суму..."
    if ! curl --silent -fSL "$checksum_url" -o "$tmpchecksum" 2>&1; then
        print_error "Не вдалося завантажити файл контрольної суми"
        cleanup_temp_files "$tmpfile" "$tmpchecksum" "$tmpdir"
        exit 1
    fi
    print_success "Контрольну суму завантажено"

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
    print_step "Встановлюємо файли..."
    if ! extracted_dir=$(find_extracted_directory "$tmpdir"); then
        cleanup_temp_files "$tmpfile" "$tmpchecksum" "$tmpdir"
        exit 1
    fi

    mv "$extracted_dir" "$target_dir"

    # Cleanup
    cleanup_temp_files "$tmpfile" "$tmpchecksum" "$tmpdir"

    print_success "Файли встановлено в ${COLOR_DIM}$target_dir${COLOR_RESET}"

    # Automatically use this version
    echo ""
    cmd_use "$program" "$version"

    echo ""
    print_header "${COLOR_BGREEN}Встановлення завершено!${COLOR_RESET}"
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

    print_success "Програма ${COLOR_BWHITE}$program${COLOR_RESET} тепер використовує версію ${COLOR_BGREEN}$version${COLOR_RESET}"
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
        local programs
        programs=($(list_installed_programs))

        if [[ ${#programs[@]} -eq 0 ]]; then
            print_info "Немає встановлених програм"
            return 0
        fi

        echo ""
        echo -e "${COLOR_BOLD}Встановлені програми:${COLOR_RESET}"
        echo ""

        for prog in "${programs[@]}"; do
            local current_ver
            current_ver=$(cmd_current "$prog")

            if [[ -n "$current_ver" ]]; then
                echo -e "  ${COLOR_BGREEN}*${COLOR_RESET} ${COLOR_BWHITE}$prog${COLOR_RESET} ${COLOR_DIM}(поточна: $current_ver)${COLOR_RESET}"
            else
                echo -e "  ${COLOR_DIM}-${COLOR_RESET} ${COLOR_WHITE}$prog${COLOR_RESET}"
            fi
        done
        echo ""
    else
        local versions
        versions=($(list_installed_versions "$program"))

        if [[ ${#versions[@]} -eq 0 ]]; then
            print_info "Немає встановлених версій для ${COLOR_BWHITE}$program${COLOR_RESET}"
            return 0
        fi

        local current_ver
        current_ver=$(cmd_current "$program")

        echo ""
        echo -e "${COLOR_BOLD}Встановлені версії ${COLOR_BWHITE}$program${COLOR_RESET}:"
        echo ""

        for ver in "${versions[@]}"; do
            if [[ "$ver" == "$current_ver" ]]; then
                echo -e "  ${COLOR_BGREEN}*${COLOR_RESET} ${COLOR_BGREEN}$ver${COLOR_RESET} ${COLOR_DIM}(поточна)${COLOR_RESET}"
            else
                echo -e "  ${COLOR_DIM}-${COLOR_RESET} ${COLOR_WHITE}$ver${COLOR_RESET}"
            fi
        done
        echo ""
    fi
}

cmd_list_available() {
    local program="$1"

    if [[ -z "$program" ]]; then
        local programs
        programs=($(list_all_programs))

        if [[ ${#programs[@]} -eq 0 ]]; then
            print_info "Немає доступних програм"
            return 0
        fi

        echo ""
        echo -e "${COLOR_BOLD}Доступні програми:${COLOR_RESET}"
        echo ""

        for prog in "${programs[@]}"; do
            echo -e "  ${COLOR_BCYAN}>>${COLOR_RESET} ${COLOR_BWHITE}$prog${COLOR_RESET}"
        done
        echo ""
    else
        local versions
        versions=$(list_available_versions "$program")

        if [[ -z "$versions" ]]; then
            print_info "Немає доступних версій для ${COLOR_BWHITE}$program${COLOR_RESET}"
            return 0
        fi

        echo ""
        echo -e "${COLOR_BOLD}Доступні версії ${COLOR_BWHITE}$program${COLOR_RESET}:"
        echo ""

        while IFS= read -r ver; do
            echo -e "  ${COLOR_BCYAN}>>${COLOR_RESET} ${COLOR_WHITE}$ver${COLOR_RESET}"
        done <<< "$versions"
        echo ""
    fi
}

cmd_init_shells() {
    local bash_rc="$HOME/.bashrc"
    local fish_rc="$HOME/.config/fish/config.fish"
    local updated=0

    print_header "Ініціалізація shell"

    if [[ -f "$bash_rc" ]] && ! grep -q '.укр/env.bash' "$bash_rc"; then
        {
            echo ''
            echo '. "$HOME/.укр/env.bash"'
            echo ''
        } >> "$bash_rc"
        print_success "Додано в ${COLOR_DIM}$bash_rc${COLOR_RESET}"
        updated=1
    fi

    if [[ -f "$fish_rc" ]] && ! grep -q '.укр/env.fish' "$fish_rc"; then
        {
            echo ''
            echo 'source "$HOME/.укр/env.fish"'
            echo ''
        } >> "$fish_rc"
        print_success "Додано в ${COLOR_DIM}$fish_rc${COLOR_RESET}"
        updated=1
    fi

    echo ""
    if [[ $updated -eq 0 ]]; then
        print_info "Ініціалізацію завершено. Жоден файл конфігурації shell не було змінено."
    else
        print_success "Ініціалізацію завершено!"
        echo ""
        print_info "Перезапустіть ваш shell або виконайте:"
        echo ""
        echo -e "  ${COLOR_DIM}source ~/.bashrc${COLOR_RESET}  ${COLOR_DIM}# для bash${COLOR_RESET}"
        echo -e "  ${COLOR_DIM}source ~/.config/fish/config.fish${COLOR_RESET}  ${COLOR_DIM}# для fish${COLOR_RESET}"
        echo ""
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
            print_error "Версія ${COLOR_BWHITE}$version${COLOR_RESET} для ${COLOR_BWHITE}$program${COLOR_RESET} не знайдена."
            exit 1
        fi

        if [[ "$force" != "--force" ]]; then
            echo ""
            print_warning "Ви дійсно хочете видалити ${COLOR_BWHITE}$program${COLOR_RESET} ${COLOR_BWHITE}$version${COLOR_RESET}?"
            echo -n "  Підтвердіть [т/Н]: "
            read -r confirm

            if [[ "$confirm" != "т" && "$confirm" != "Т" ]]; then
                echo ""
                print_info "Скасовано."
                exit 0
            fi
        fi

        echo ""
        rm -rf "$target_dir"
        print_success "Видалено ${COLOR_BWHITE}$program${COLOR_RESET} ${COLOR_BWHITE}$version${COLOR_RESET}"

        # Clean up current symlink if it pointed to the deleted version
        link_path=$(get_current_link_path "$program")

        if [[ -L "$link_path" && "$(readlink "$link_path")" == "$target_dir" ]]; then
            rm -f "$link_path"
            print_info "Поточне посилання видалено"
        fi
        echo ""
    else
        # Delete entire program
        target_dir="$UKR_INSTALLED_PROGRAMS_DIR/$program"

        if [[ ! -d "$target_dir" ]]; then
            print_error "Програма ${COLOR_BWHITE}$program${COLOR_RESET} не знайдена."
            exit 1
        fi

        if [[ "$force" != "--force" ]]; then
            echo ""
            print_warning "Ви дійсно хочете повністю видалити ${COLOR_BWHITE}$program${COLOR_RESET} і всі її версії?"
            echo -n "  Підтвердіть [т/Н]: "
            read -r confirm

            if [[ "$confirm" != "т" && "$confirm" != "Т" ]]; then
                echo ""
                print_info "Скасовано."
                exit 0
            fi
        fi

        echo ""
        rm -rf "$target_dir"
        rm -f "$(get_current_link_path "$program")"
        print_success "Вся програма ${COLOR_BWHITE}$program${COLOR_RESET} видалена разом з усіма версіями"
        echo ""
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
            version=$(cmd_current "$2")
            if [[ -n "$version" ]]; then
                echo -e "${COLOR_BWHITE}$2${COLOR_RESET} ${COLOR_DIM}->${COLOR_RESET} ${COLOR_BGREEN}$version${COLOR_RESET}"
            else
                print_warning "Програма ${COLOR_BWHITE}$2${COLOR_RESET} не активна"
            fi
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
        # Hidden commands for autocompletion (no styling)
        --raw-programs|програми)
            list_all_programs
            ;;
        --raw-installed)
            list_installed_programs
            ;;
        --raw-installed-versions)
            if [[ -n "$2" ]]; then
                list_installed_versions "$2"
            fi
            ;;
        --raw-available-versions)
            if [[ -n "$2" ]]; then
                list_available_versions "$2"
            fi
            ;;
        --raw-current)
            if [[ -n "$2" ]]; then
                cmd_current "$2"
            fi
            ;;
        *)
            show_info
            ;;
    esac
}

main "$@"
