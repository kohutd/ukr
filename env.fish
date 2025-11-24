for p in $HOME/.local/share/укр/поточні/*
    if test -d "$p/bin"
        if not contains -- "$p/bin" $PATH
            set -gx PATH "$p/bin" $PATH
        end
    end
end

function укр
    bash "$HOME/.укр/укр.bash" $argv

    for p in $HOME/.local/share/укр/поточні/*
        if test -d "$p/bin"
            if not contains -- "$p/bin" $PATH
                set -gx PATH "$p/bin" $PATH
            end
        end
    end
end

# Helper functions
function __ukr_programs
    укр --raw-programs 2>/dev/null || echo ''
end

function __ukr_installed
    укр --raw-installed 2>/dev/null || echo ''
end

function __ukr_versions
    set program $argv[1]
    if test -n "$program"
        укр --raw-installed-versions $program 2>/dev/null || echo ''
    end
end

function __ukr_available_versions
    set program $argv[1]
    if test -n "$program"
        укр --raw-available-versions $program 2>/dev/null || echo ''
    end
end

# List of all subcommands
set -l subcommands встановити використовувати видалити використовується встановлені доступні

# Base subcommand completion
complete -c укр -f -r -n "not __fish_seen_subcommand_from $subcommands" \
  -a "$subcommands" \
  -d "Команди"

# встановити <програма> [версія]
complete -c укр -f -r -n '__fish_seen_subcommand_from встановити; and test (count (commandline -opc)) -eq 2' \
  -a "(__ukr_programs)" \
  -d "Доступні програми"
complete -c укр -f -r -n '__fish_seen_subcommand_from встановити; and test (count (commandline -opc)) -eq 3' \
  -a "(__ukr_available_versions (commandline -opc)[3])" \
  -d "Доступні версії"
complete -c укр -f -n '__fish_seen_subcommand_from встановити; and test (count (commandline -opc)) -ge 4' \
  -a ""

# видалити <програма> [версія]
complete -c укр -f -r -n '__fish_seen_subcommand_from видалити; and test (count (commandline -opc)) -eq 2' \
  -a "(__ukr_installed)" \
  -d "Встановлені програми"
complete -c укр -f -r -n '__fish_seen_subcommand_from видалити; and test (count (commandline -opc)) -eq 3' \
  -a "(__ukr_versions (commandline -opc)[3])" \
  -d "Встановлені версії"
complete -c укр -f -n '__fish_seen_subcommand_from видалити; and test (count (commandline -opc)) -ge 4' \
  -a ""

# використовувати <програма> <версія>
complete -c укр -f -r -n '__fish_seen_subcommand_from використовувати; and test (count (commandline -opc)) -eq 2' \
  -a "(__ukr_installed)" \
  -d "Встановлені програми"
complete -c укр -f -r -n '__fish_seen_subcommand_from використовувати; and test (count (commandline -opc)) -eq 3' \
  -a "(__ukr_versions (commandline -opc)[3])" \
  -d "Встановлені версії"
complete -c укр -f -n '__fish_seen_subcommand_from використовувати; and test (count (commandline -opc)) -ge 4' \
  -a ""

# використовується <програма>
complete -c укр -f -r -n "__fish_seen_subcommand_from використовується; and test (count (commandline -opc)) -eq 2" \
  -a "(__ukr_installed)" \
  -d "Встановлені програми"
complete -c укр -f -n "__fish_seen_subcommand_from використовується; and test (count (commandline -opc)) -ge 3" \
  -a ""

# встановлені [програма]
complete -c укр -f -r -n "__fish_seen_subcommand_from встановлені; and test (count (commandline -opc)) -eq 2" \
  -a "(__ukr_installed)" \
  -d "Встановлені програми"
complete -c укр -f -n "__fish_seen_subcommand_from встановлені; and test (count (commandline -opc)) -ge 3" \
  -a ""

# доступні [програма]
complete -c укр -f -r -n "__fish_seen_subcommand_from доступні; and test (count (commandline -opc)) -eq 2" \
  -a "(__ukr_programs)" \
  -d "Доступні програми"
complete -c укр -f -n "__fish_seen_subcommand_from доступні; and test (count (commandline -opc)) -ge 3" \
  -a ""

# Prevent fallback file suggestions when nothing should be completed
complete -c укр -f