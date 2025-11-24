for p in "$HOME/.local/share/укр/поточні/"*; do
  if [ -d "$p/bin" ]; then
    case ":$PATH:" in
      *":$p/bin:"*) ;;
      *) PATH="$p/bin:$PATH" ;;
    esac
  fi
done

укр() {
  bash "$HOME/.укр/укр.bash" "$@"

  for p in "$HOME/.local/share/укр/поточні/"*; do
    if [ -d "$p/bin" ]; then
      case ":$PATH:" in
        *":$p/bin:"*) ;;
        *) PATH="$p/bin:$PATH" ;;
      esac
    fi
  done
}

if declare -F _init_completion >/dev/null || declare -F _completion_loader >/dev/null; then
  _укр_programs() {
    укр --raw-programs 2>/dev/null || echo ''
  }

  _укр_installed() {
    укр --raw-installed 2>/dev/null || echo ''
  }

  _укр_versions() {
    if [[ -n $1 ]]; then
      укр --raw-installed-versions "$1" 2>/dev/null || echo ''
    fi
  }

  _укр_available_versions() {
    if [[ -n $1 ]]; then
      укр --raw-available-versions "$1" 2>/dev/null || echo ''
    fi
  }

  _укр_completions() {
    local cur prev words cword
    _get_comp_words_by_ref -n =: cur prev words cword

    local subcommands=(встановити використовувати видалити використовується встановлені доступні)

    # Top-level subcommand suggestions
    if [[ $cword -eq 1 ]]; then
      COMPREPLY=( $(compgen -W "${subcommands[*]}" -- "$cur") )
      return 0
    fi

    local subcommand="${words[1]}"

    case "$subcommand" in
      встановити)
        if [[ $cword -eq 2 ]]; then
          COMPREPLY=( $(compgen -W "$(_укр_programs)" -- "$cur") )
        elif [[ $cword -eq 3 ]]; then
          COMPREPLY=( $(compgen -W "$(_укр_available_versions "${words[2]}")" -- "$cur") )
        fi
        ;;
      видалити)
        if [[ $cword -eq 2 ]]; then
          COMPREPLY=( $(compgen -W "$(_укр_installed)" -- "$cur") )
        elif [[ $cword -eq 3 ]]; then
          COMPREPLY=( $(compgen -W "$(_укр_versions "${words[2]}")" -- "$cur") )
        fi
        ;;
      використовувати)
        if [[ $cword -eq 2 ]]; then
          COMPREPLY=( $(compgen -W "$(_укр_installed)" -- "$cur") )
        elif [[ $cword -eq 3 ]]; then
          COMPREPLY=( $(compgen -W "$(_укр_versions "${words[2]}")" -- "$cur") )
        fi
        ;;
      використовується)
        if [[ $cword -eq 2 ]]; then
          COMPREPLY=( $(compgen -W "$(_укр_installed)" -- "$cur") )
        fi
        ;;
      встановлені)
        if [[ $cword -eq 2 ]]; then
          COMPREPLY=( $(compgen -W "$(_укр_installed)" -- "$cur") )
        fi
        ;;
      доступні)
        if [[ $cword -eq 2 ]]; then
          COMPREPLY=( $(compgen -W "$(_укр_programs)" -- "$cur") )
        fi
        ;;
    esac
  }

  complete -F _укр_completions укр
fi