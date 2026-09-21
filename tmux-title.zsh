# Keep tmux window names aligned with the active shell command.
[[ -o interactive ]] || return 0
[[ -n "${TMUX:-}" ]] || return 0

autoload -Uz add-zsh-hook

__tmux_set_pane_title() {
  emulate -L zsh

  local title="$1"
  [[ -n "$title" ]] || return 0

  tmux select-pane -T "$title" 2>/dev/null || true
}

__tmux_idle_title() {
  emulate -L zsh

  if [[ "$PWD" == "$HOME" ]]; then
    print -r -- "~"
    return 0
  fi

  print -r -- "${PWD:t}"
}

__tmux_command_title() {
  emulate -L zsh -o extended_glob

  local raw="$1"
  local token cmd arg1 arg2
  local idx=1
  local next_idx next_next_idx
  local -a lexed words

  lexed=("${(z)raw}")

  for token in "${lexed[@]}"; do
    case "$token" in
      '|'|'||'|';'|'&'|'&&')
        break
        ;;
      *)
        words+=("$token")
        ;;
    esac
  done

  while (( idx <= ${#words[@]} )); do
    token="${words[idx]}"

    if [[ "$token" == [A-Za-z_][A-Za-z0-9_]#=* ]]; then
      (( idx++ ))
      continue
    fi

    case "$token" in
      sudo|command|builtin|nocorrect|noglob|time)
        (( idx++ ))
        continue
        ;;
      env)
        (( idx++ ))
        while (( idx <= ${#words[@]} )) && [[ "${words[idx]}" == [A-Za-z_][A-Za-z0-9_]#=* ]]; do
          (( idx++ ))
        done
        continue
        ;;
    esac

    break
  done

  cmd="${words[idx]:t}"
  [[ -n "$cmd" ]] || {
    __tmux_idle_title
    return 0
  }

  next_idx=$((idx + 1))
  next_next_idx=$((idx + 2))
  arg1="${words[next_idx]:-}"
  arg2="${words[next_next_idx]:-}"

  case "$cmd" in
    claude|codex|opencode)
      print -r -- "$cmd"
      ;;
    npm|pnpm|yarn|bun)
      if [[ "$arg1" == "run" && -n "$arg2" ]]; then
        print -r -- "$cmd:$arg2"
      elif [[ -n "$arg1" ]]; then
        print -r -- "$cmd:$arg1"
      else
        print -r -- "$cmd"
      fi
      ;;
    make|just)
      if [[ -n "$arg1" ]]; then
        print -r -- "$cmd:$arg1"
      else
        print -r -- "$cmd"
      fi
      ;;
    docker)
      if [[ "$arg1" == "compose" && -n "$arg2" ]]; then
        print -r -- "docker:compose $arg2"
      elif [[ -n "$arg1" ]]; then
        print -r -- "docker:$arg1"
      else
        print -r -- "docker"
      fi
      ;;
    docker-compose)
      if [[ -n "$arg1" ]]; then
        print -r -- "docker:$arg1"
      else
        print -r -- "docker"
      fi
      ;;
    python|python3)
      if [[ "$arg1" == "-m" && -n "$arg2" ]]; then
        print -r -- "$arg2"
      elif [[ -n "$arg1" ]]; then
        print -r -- "$cmd:${arg1:t}"
      else
        print -r -- "$cmd"
      fi
      ;;
    uv|uvx)
      if [[ "$arg1" == "run" && -n "$arg2" ]]; then
        if [[ "$arg2" == "python" || "$arg2" == "python3" ]]; then
          if [[ "${words[idx + 3]:-}" == "-m" && -n "${words[idx + 4]:-}" ]]; then
            print -r -- "${words[idx + 4]}"
          else
            print -r -- "uv:${arg2}"
          fi
        else
          print -r -- "uv:${arg2:t}"
        fi
      elif [[ -n "$arg1" ]]; then
        print -r -- "uv:$arg1"
      else
        print -r -- "$cmd"
      fi
      ;;
    node|deno|go)
      if [[ -n "$arg1" ]]; then
        print -r -- "$cmd:${arg1:t}"
      else
        print -r -- "$cmd"
      fi
      ;;
    cargo)
      if [[ -n "$arg1" ]]; then
        print -r -- "cargo:$arg1"
      else
        print -r -- "cargo"
      fi
      ;;
    ssh|mosh)
      if [[ -n "$arg1" ]]; then
        print -r -- "$cmd:$arg1"
      else
        print -r -- "$cmd"
      fi
      ;;
    git)
      if [[ -n "$arg1" ]]; then
        print -r -- "git:$arg1"
      else
        print -r -- "git"
      fi
      ;;
    nvim|vim|vi|less|tail|top|htop|btop|lazygit)
      print -r -- "$cmd"
      ;;
    *)
      print -r -- "$cmd"
      ;;
  esac
}

__tmux_precmd_title() {
  __tmux_set_pane_title "$(__tmux_idle_title)"
}

__tmux_preexec_title() {
  __tmux_set_pane_title "$(__tmux_command_title "$1")"
}

add-zsh-hook precmd __tmux_precmd_title
add-zsh-hook preexec __tmux_preexec_title
add-zsh-hook chpwd __tmux_precmd_title
