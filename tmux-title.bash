case $- in
  *i*) ;;
  *) return 0 2>/dev/null || exit 0 ;;
esac

[ -n "${TMUX:-}" ] || return 0 2>/dev/null || exit 0

__tmux_set_pane_title() {
  local title="$1"
  [ -n "$title" ] || return 0

  tmux select-pane -T "$title" 2>/dev/null || true
}

__tmux_idle_title() {
  if [ "$PWD" = "$HOME" ]; then
    printf '%s\n' '~'
  else
    basename -- "$PWD"
  fi
}

__tmux_command_title() {
  local raw="$1"
  local token cmd arg1 arg2
  local -a words=()
  local idx=0

  read -r -a words <<<"$raw"

  while [ "$idx" -lt "${#words[@]}" ]; do
    token="${words[$idx]}"

    case "$token" in
      *=*)
        if [[ "$token" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
          idx=$((idx + 1))
          continue
        fi
        ;;
      sudo|command|builtin|nocorrect|noglob|time)
        idx=$((idx + 1))
        continue
        ;;
      env)
        idx=$((idx + 1))
        while [ "$idx" -lt "${#words[@]}" ] && [[ "${words[$idx]}" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; do
          idx=$((idx + 1))
        done
        continue
        ;;
      \||\|\||\&|\&\&|\;)
        break
        ;;
    esac

    break
  done

  cmd="${words[$idx]##*/}"
  if [ -z "$cmd" ]; then
    __tmux_idle_title
    return 0
  fi

  arg1="${words[$((idx + 1))]:-}"
  arg2="${words[$((idx + 2))]:-}"

  case "$cmd" in
    claude|codex|opencode)
      printf '%s\n' "$cmd"
      ;;
    npm|pnpm|yarn|bun)
      if [ "$arg1" = "run" ] && [ -n "$arg2" ]; then
        printf '%s\n' "$cmd:$arg2"
      elif [ -n "$arg1" ]; then
        printf '%s\n' "$cmd:$arg1"
      else
        printf '%s\n' "$cmd"
      fi
      ;;
    make|just)
      if [ -n "$arg1" ]; then
        printf '%s\n' "$cmd:$arg1"
      else
        printf '%s\n' "$cmd"
      fi
      ;;
    docker)
      if [ "$arg1" = "compose" ] && [ -n "$arg2" ]; then
        printf 'docker:compose %s\n' "$arg2"
      elif [ -n "$arg1" ]; then
        printf '%s\n' "$cmd:$arg1"
      else
        printf '%s\n' "$cmd"
      fi
      ;;
    docker-compose)
      if [ -n "$arg1" ]; then
        printf '%s\n' "docker:$arg1"
      else
        printf '%s\n' "docker"
      fi
      ;;
    python|python3)
      if [ "$arg1" = "-m" ] && [ -n "$arg2" ]; then
        printf '%s\n' "$arg2"
      elif [ -n "$arg1" ]; then
        printf '%s\n' "$cmd:${arg1##*/}"
      else
        printf '%s\n' "$cmd"
      fi
      ;;
    uv|uvx)
      if [ "$arg1" = "run" ] && [ -n "$arg2" ]; then
        if [ "$arg2" = "python" ] || [ "$arg2" = "python3" ]; then
          if [ "${words[$((idx + 3))]:-}" = "-m" ] && [ -n "${words[$((idx + 4))]:-}" ]; then
            printf '%s\n' "${words[$((idx + 4))]}"
          else
            printf '%s\n' "uv:$arg2"
          fi
        else
          printf '%s\n' "uv:${arg2##*/}"
        fi
      elif [ -n "$arg1" ]; then
        printf '%s\n' "uv:$arg1"
      else
        printf '%s\n' "$cmd"
      fi
      ;;
    node|deno|go)
      if [ -n "$arg1" ]; then
        printf '%s\n' "$cmd:${arg1##*/}"
      else
        printf '%s\n' "$cmd"
      fi
      ;;
    cargo)
      if [ -n "$arg1" ]; then
        printf '%s\n' "cargo:$arg1"
      else
        printf '%s\n' "cargo"
      fi
      ;;
    ssh|mosh)
      if [ -n "$arg1" ]; then
        printf '%s\n' "$cmd:$arg1"
      else
        printf '%s\n' "$cmd"
      fi
      ;;
    git)
      if [ -n "$arg1" ]; then
        printf '%s\n' "git:$arg1"
      else
        printf '%s\n' "git"
      fi
      ;;
    nvim|vim|vi|less|tail|top|htop|btop|lazygit)
      printf '%s\n' "$cmd"
      ;;
    *)
      printf '%s\n' "$cmd"
      ;;
  esac
}

__tmux_preexec_title() {
  [ "${__TMUX_TITLE_IN_PROGRESS:-0}" -eq 0 ] || return 0
  [ -n "${COMP_LINE:-}" ] && return 0

  case "$BASH_COMMAND" in
    __tmux_preexec_title*|__tmux_precmd_title*|__tmux_set_pane_title*|trap*|history*|fc*)
      return 0
      ;;
  esac

  __TMUX_TITLE_IN_PROGRESS=1
  __tmux_set_pane_title "$(__tmux_command_title "$BASH_COMMAND")"
  __TMUX_TITLE_IN_PROGRESS=0
}

__tmux_precmd_title() {
  [ "${__TMUX_TITLE_IN_PROGRESS:-0}" -eq 0 ] || return 0
  __TMUX_TITLE_IN_PROGRESS=1
  __tmux_set_pane_title "$(__tmux_idle_title)"
  __TMUX_TITLE_IN_PROGRESS=0
}

if [[ ";${PROMPT_COMMAND:-};" != *";__tmux_precmd_title;"* ]]; then
  PROMPT_COMMAND="__tmux_precmd_title${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi

trap '__tmux_preexec_title' DEBUG
