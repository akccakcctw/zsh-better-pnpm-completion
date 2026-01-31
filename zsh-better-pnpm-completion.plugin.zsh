_zbpc_pnpm_command() {
  echo "${words[2]}"
}

_zbpc_pnpm_command_arg() {
  echo "${words[3]}"
}

_zbpc_no_of_pnpm_args() {
  echo "$#words"
}

_zbpc_list_cached_modules() {
  local store_path
  store_path="$(pnpm store path 2>/dev/null)" || return
  [[ "$store_path" = "" ]] && return

  local metadata_dir="$store_path/metadata"
  if [[ -d "$metadata_dir" ]]; then
    local -a files packages
    files=(${(f)"$(find "$metadata_dir" -mindepth 2 -maxdepth 3 -type f 2>/dev/null)"})
    [[ "$#files" -eq 0 ]] && return
    local file rel
    for file in "${files[@]}"; do
      rel="${file#$metadata_dir/}"
      rel="${rel#*/}"
      rel="${rel%.json}"
      if [[ "$rel" == */*/* ]]; then
        local maybe_version="${rel##*/}"
        if [[ "$maybe_version" == [0-9]* ]]; then
          rel="${rel%/*}"
        fi
      fi
      [[ "$rel" = "" ]] && continue
      packages+=("$rel")
    done
    print -rl -- ${packages[@]} | sort -u
    return
  fi

  ls "$store_path" 2>/dev/null
}

_zbpc_recursively_look_for() {
  local filename="$1"
  local dir=$PWD
  while [ ! -e "$dir/$filename" ]; do
    dir=${dir%/*}
    [[ "$dir" = "" ]] && break
  done
  [[ ! "$dir" = "" ]] && echo "$dir/$filename"
}

_zbpc_get_package_json_property_object() {
  local package_json="$1"
  local property="$2"
  if command -v node >/dev/null 2>&1; then
    node -e '
      const fs = require("fs");
      const file = process.argv[1];
      const prop = process.argv[2];
      try {
        const data = JSON.parse(fs.readFileSync(file, "utf8"));
        const obj = data && data[prop];
        if (!obj || typeof obj !== "object") process.exit(0);
        for (const [k, v] of Object.entries(obj)) {
          const value = typeof v === "string" ? v : JSON.stringify(v);
          console.log(`${k}=>${value}`);
        }
      } catch {}
    ' "$package_json" "$property" 2>/dev/null
    return
  fi

  cat "$package_json" |
    sed -nE "/^  \"$property\": \{$/,/^  \},?$/p" | # Grab scripts object
    sed '1d;$d' |                                   # Remove first/last lines
    sed -E 's/    "([^"]+)": "(.+)",?/\1=>\2/'      # Parse into key=>value
}

_zbpc_get_package_json_property_object_keys() {
  local package_json="$1"
  local property="$2"
  _zbpc_get_package_json_property_object "$package_json" "$property" | cut -f 1 -d "="
}

_zbpc_parse_package_json_for_script_suggestions() {
  local package_json="$1"
  _zbpc_get_package_json_property_object "$package_json" scripts |
    sed -E 's/(.+)=>(.+)/\1:$ \2/' |  # Parse commands into suggestions
    sed 's/\(:\)[^$]/\\&/g' |         # Escape ":" in commands
    sed 's/\(:\)$[^ ]/\\&/g'          # Escape ":$" without a space in commands
}

_zbpc_parse_package_json_for_deps() {
  local package_json="$1"
  _zbpc_get_package_json_property_object_keys "$package_json" dependencies
  _zbpc_get_package_json_property_object_keys "$package_json" devDependencies
  _zbpc_get_package_json_property_object_keys "$package_json" optionalDependencies
  _zbpc_get_package_json_property_object_keys "$package_json" peerDependencies
}

_zbpc_list_workspace_packages() {
  local workspace_file
  workspace_file="$(_zbpc_recursively_look_for pnpm-workspace.yaml)"
  [[ "$workspace_file" = "" ]] && return

  local workspace_root="${workspace_file%/*}"
  local json
  json="$(pnpm -C "$workspace_root" list -r --depth -1 --json 2>/dev/null)" || return
  [[ "$json" = "" ]] && return

  if command -v node >/dev/null 2>&1; then
    echo "$json" | node -e '
      const fs = require("fs");
      const input = fs.readFileSync(0, "utf8").trim();
      if (!input) process.exit(0);
      let data;
      try { data = JSON.parse(input); } catch { process.exit(0); }
      if (!Array.isArray(data)) data = [data];
      const names = new Set();
      for (const pkg of data) {
        if (pkg && pkg.name) names.add(pkg.name);
      }
      console.log([...names].join("\n"));
    ' 2>/dev/null
  fi
}

_zbpc_pnpm_filter_completion() {
  local prev="${words[$((CURRENT-1))]}"
  local cur="${words[$CURRENT]}"
  local -a options

  case "$prev" in
    --filter|-F)
      options=(${(f)"$(_zbpc_list_workspace_packages)"})
      [[ "$#options" -eq 0 ]] && return
      _values $options
      custom_completion=true
      return
      ;;
  esac

  case "$cur" in
    --filter=*)
      options=(${(f)"$(_zbpc_list_workspace_packages)"})
      [[ "$#options" -eq 0 ]] && return
      compadd -P '--filter=' -- ${options[@]}
      custom_completion=true
      return
      ;;
    -F=*)
      options=(${(f)"$(_zbpc_list_workspace_packages)"})
      [[ "$#options" -eq 0 ]] && return
      compadd -P '-F=' -- ${options[@]}
      custom_completion=true
      return
      ;;
  esac
}

_zbpc_pnpm_install_completion() {

  # Only run on `pnpm install ?`
  [[ ! "$(_zbpc_no_of_pnpm_args)" = "3" ]] && return

  # Return if we don't have any cached modules
  [[ "$(_zbpc_list_cached_modules)" = "" ]] && return

  # If we do, recommend them
  _values $(_zbpc_list_cached_modules)

  # Make sure we don't run default completion
  custom_completion=true
}

_zbpc_pnpm_uninstall_completion() {

  # Use default pnpm completion to recommend global modules
  [[ "$(_zbpc_pnpm_command_arg)" = "-g" ]] || [[ "$(_zbpc_pnpm_command_arg)" = "--global" ]] && return

  # Look for a package.json file
  local package_json="$(_zbpc_recursively_look_for package.json)"

  # Return if we can't find package.json
  [[ "$package_json" = "" ]] && return

  _values $(_zbpc_parse_package_json_for_deps "$package_json")

  # Make sure we don't run default completion
  custom_completion=true
}

_zbpc_pnpm_run_completion() {

  # Only run on `pnpm run ?`
  [[ ! "$(_zbpc_no_of_pnpm_args)" = "3" ]] && return

  # Look for a package.json file
  local package_json="$(_zbpc_recursively_look_for package.json)"

  # Return if we can't find package.json
  [[ "$package_json" = "" ]] && return

  # Parse scripts in package.json
  local -a options
  options=(${(f)"$(_zbpc_parse_package_json_for_script_suggestions $package_json)"})

  # Return if we can't parse it
  [[ "$#options" = 0 ]] && return

  # Load the completions
  _describe 'values' options

  # Make sure we don't run default completion
  custom_completion=true
}

_zbpc_format_pnpm_completions() {
  local -a formatted
  local item

  for item in "$@"; do
    if [[ "$item" == -* ]]; then
      formatted+=("\\${item}")
    else
      formatted+=("${item}")
    fi
  done

  print -rl -- "${(i)formatted[@]}"
}

_zbpc_list_pnpm_commands_from_help() {
  local help
  help="$(pnpm help -a 2>/dev/null)"
  [[ "$help" = "" ]] && help="$(pnpm --help 2>/dev/null)"
  [[ "$help" = "" ]] && return

  echo "$help" | awk '
    /^[[:space:]]*[a-z][a-z0-9-]*(, [a-z][a-z0-9-]*)*[[:space:]]{2,}/ {
      line=$0
      sub(/^[[:space:]]*/, "", line)
      split(line, parts, /  +/)
      cmds=parts[1]
      gsub(/, /, "\n", cmds)
      print cmds
    }
  ' | sort -u
}

_zbpc_pnpm_root_command_completion() {
  local -a options
  options=(${(f)"$(_zbpc_list_pnpm_commands_from_help)"})
  [[ "$#options" -eq 0 ]] && return 1
  _describe 'commands' options
  return 0
}

_zbpc_pnpm_complete_options_or_commands() {
  local current_word="${words[CURRENT]}"
  local stop_parse_index=$words[(Ie)--]
  local -a formatted
  local type

  # Skip completion after "--"
  if [[ $stop_parse_index != 0 && $CURRENT > stop_parse_index ]]; then
    return 1
  fi

  formatted=(${(f)"$(_zbpc_format_pnpm_completions "$@")"})
  [[ "$#formatted" -eq 0 ]] && return 1

  if [[ $current_word == -* ]]; then
    type="options"
  else
    type="commands"
  fi

  _describe $type formatted
}

_zbpc_default_pnpm_completion() {
  local reply
  local si=$IFS
  IFS=$'\n' reply=($(COMP_CWORD="$((CURRENT-1))" \
    COMP_LINE="$BUFFER" \
    COMP_POINT="$CURSOR" \
    SHELL=zsh \
    pnpm completion-server -- "${words[@]}" 2>/dev/null))
  IFS=$si

  if [[ "$#reply" -eq 1 && "$reply[1]" = "__tabtab_complete_files__" ]]; then
    if [[ "$(_zbpc_no_of_pnpm_args)" = "2" && "${words[CURRENT]}" != -* ]]; then
      _zbpc_pnpm_root_command_completion && return
    fi
    _files
    return
  fi

  if [[ "$#reply" -gt 0 ]]; then
    _zbpc_pnpm_complete_options_or_commands "${reply[@]}" && return
  fi

  if [[ "$(_zbpc_no_of_pnpm_args)" = "2" && "${words[CURRENT]}" != -* ]]; then
    _zbpc_pnpm_root_command_completion && return
  fi

  compadd -- $(COMP_CWORD=$((CURRENT-1)) \
    COMP_LINE=$BUFFER \
    COMP_POINT=$CURSOR \
    pnpm completion -- "${words[@]}" 2>/dev/null)
}

_zbpc_zsh_better_pnpm_completion() {

  # Store custom completion status
  local custom_completion=false

  # Complete workspace filters like --filter/-F
  _zbpc_pnpm_filter_completion
  [[ $custom_completion = true ]] && return

  # Load custom completion commands
  case "$(_zbpc_pnpm_command)" in
    i|install)
      _zbpc_pnpm_install_completion
      ;;
    remove|uninstall)
      _zbpc_pnpm_uninstall_completion
      ;;
    run)
      _zbpc_pnpm_run_completion
      ;;
  esac

  # Fall back to default completion if we haven't done a custom one
  [[ $custom_completion = false ]] && _zbpc_default_pnpm_completion
}

compdef _zbpc_zsh_better_pnpm_completion pnpm
