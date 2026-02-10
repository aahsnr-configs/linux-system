{ pkgs, ... }:

let
  # Reusable Bash function for Fedora immutable distros dependency checking
  # Uses rpm-ostree with --apply-live for immediate availability
  checkDepFunc = ''
    check_dependency() {
        local cmd="$1"
        local pkg="''${2:-$1}"
        
        if ! command -v "$cmd" &> /dev/null; then
            echo "Error: Required command '$cmd' is not installed." >&2
            read -r -p "Install '$pkg' using rpm-ostree? [y/N] " -n 1 -r
            echo
            
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "Installing $pkg..."
                echo "Note: Using --apply-live for immediate availability."
                
                # Determine privilege escalation command
                local priv_cmd=""
                if command -v sudo &>/dev/null; then
                    priv_cmd="sudo"
                elif command -v run0 &>/dev/null; then
                    priv_cmd="run0"
                else
                    echo "Error: No privilege escalation tool found (sudo or run0)" >&2
                    exit 1
                fi
                
                # Install with apply-live for immediate availability
                if $priv_cmd rpm-ostree install --apply-live "$pkg"; then
                    echo "✓ Package installed and available immediately."
                    echo "⚠ Reboot recommended to finalize changes."
                else
                    echo "Error: Failed to install $pkg" >&2
                    exit 1
                fi
            else
                echo "Missing dependency: $pkg. Exiting." >&2
                exit 1
            fi
        fi
    }
  '';

  # Helper function for creating shell scripts
  mkScript = name: text: pkgs.writeShellScriptBin name text;

in
{
  home.packages = [

    # ========================================================================
    # Fast File Finder
    # ========================================================================

    (mkScript "ff" ''
            #!/usr/bin/env bash
            set -euo pipefail

            readonly SCRIPT_VERSION="1.0"
            readonly SCRIPT_NAME="$(basename "$0")"

            if [[ -t 1 ]]; then
                readonly RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
                readonly BLUE='\033[0;34m' CYAN='\033[0;36m' NC='\033[0m'
            else
                readonly RED="" GREEN="" YELLOW="" BLUE="" CYAN="" NC=""
            fi

            print_error() { echo -e "''${RED}Error: $*''${NC}" >&2; }
            print_info() { echo -e "''${BLUE}→ $*''${NC}"; }

            usage() {
                cat <<EOF
      ''${CYAN}$SCRIPT_NAME''${NC} - Fast File Finder v$SCRIPT_VERSION

      Usage: $SCRIPT_NAME [OPTIONS] <pattern> [directory]

      Options:
          -t, --type TYPE         Filter by type: f (file), d (directory), l (symlink)
          -e, --extension EXT     Filter by file extension
          -i, --ignore-case       Case-insensitive search
          -H, --hidden            Include hidden files
          -d, --max-depth NUM     Maximum search depth
          -s, --size SIZE         Filter by size (e.g., +100k, -1M)
          -x, --exec COMMAND      Execute command on results (use {} for filename)
          -c, --count             Count matches
          -0, --print0            Null-separated output
          -h, --help              Show help
          -v, --version           Show version

      Examples:
          $SCRIPT_NAME "*.sh" /usr/local/bin
          $SCRIPT_NAME -i readme
          $SCRIPT_NAME -t d config
          $SCRIPT_NAME -e txt ~/Documents

      EOF
                exit 0
            }

            version() {
                echo "$SCRIPT_NAME version $SCRIPT_VERSION"
                if command -v fd &>/dev/null; then
                    echo "Using: fd (fast mode)"
                else
                    echo "Using: find (fallback mode)"
                fi
                exit 0
            }

            parse_args() {
                local pattern="" directory="." file_type="" extension=""
                local ignore_case=0 hidden=0 max_depth="" size_filter=""
                local exec_cmd="" count_only=0 print_null=0

                while [[ $# -gt 0 ]]; do
                    case "$1" in
                        -h|--help) usage ;;
                        -v|--version) version ;;
                        -t|--type) shift; file_type="$1"; shift ;;
                        -e|--extension) shift; extension="$1"; shift ;;
                        -i|--ignore-case) ignore_case=1; shift ;;
                        -H|--hidden) hidden=1; shift ;;
                        -d|--max-depth) shift; max_depth="$1"; shift ;;
                        -s|--size) shift; size_filter="$1"; shift ;;
                        -x|--exec) shift; exec_cmd="$1"; shift ;;
                        -c|--count) count_only=1; shift ;;
                        -0|--print0) print_null=1; shift ;;
                        --) shift; break ;;
                        -*) print_error "Unknown option: $1"; exit 1 ;;
                        *) [[ -z "$pattern" ]] && pattern="$1" || directory="$1"; shift ;;
                    esac
                done

                [[ -z "$pattern" ]] && { print_error "Missing pattern"; exit 1; }
                [[ ! -d "$directory" ]] && { print_error "Directory not found: $directory"; exit 1; }

                if command -v fd &>/dev/null; then
                    search_with_fd "$pattern" "$directory" "$file_type" "$extension" \
                                   "$ignore_case" "$hidden" "$max_depth" "$size_filter" \
                                   "$exec_cmd" "$count_only" "$print_null"
                else
                    search_with_find "$pattern" "$directory" "$file_type" "$extension" \
                                     "$ignore_case" "$hidden" "$max_depth" "$size_filter" \
                                     "$exec_cmd" "$count_only" "$print_null"
                fi
            }

            search_with_fd() {
                local -a fd_args=("$1" "$2")
                [[ -n "$3" ]] && fd_args+=(--type "$3")
                [[ -n "$4" ]] && fd_args+=(--extension "$4")
                [[ "$5" -eq 1 ]] && fd_args+=(--ignore-case)
                [[ "$6" -eq 1 ]] && fd_args+=(--hidden)
                [[ -n "$7" ]] && fd_args+=(--max-depth "$7")
                [[ -n "$8" ]] && fd_args+=(--size "$8")
                [[ -n "$9" ]] && fd_args+=(--exec sh -c "$9")
                [[ "''${11}" -eq 1 ]] && fd_args+=(--print0)
                
                if [[ "''${10}" -eq 1 ]]; then
                    fd "''${fd_args[@]}" | wc -l
                else
                    fd "''${fd_args[@]}"
                fi
            }

            search_with_find() {
                local -a find_args=("$2")
                [[ -n "$7" ]] && find_args+=(-maxdepth "$7")
                [[ -n "$3" ]] && find_args+=(-type "$3")
                [[ "$5" -eq 1 ]] && find_args+=(-iname "$1") || find_args+=(-name "$1")
                [[ -n "$8" ]] && find_args+=(-size "$8")
                
                if [[ -n "$9" ]]; then
                    find_args+=(-exec sh -c "$9" \;)
                elif [[ "''${11}" -eq 1 ]]; then
                    find_args+=(-print0)
                else
                    find_args+=(-print)
                fi

                if [[ "''${10}" -eq 1 ]]; then
                    find "''${find_args[@]}" 2>/dev/null | wc -l
                else
                    find "''${find_args[@]}" 2>/dev/null
                fi
            }

            [[ $# -eq 0 ]] && usage
            parse_args "$@"
    '')

    # ========================================================================
    # Fedora Silverblue/Kinoite COPR Management
    # ========================================================================

    (mkScript "copr-silverblue" ''
            #!/usr/bin/env bash
            set -euo pipefail

            readonly SCRIPT_VERSION="3.1"
            readonly COPR_BASE_URL="https://copr.fedorainfracloud.org/coprs"
            readonly REPO_DIR="/etc/yum.repos.d"
            readonly BACKUP_DIR="''${HOME}/.local/share/copr-backups"

            if [[ -t 1 ]]; then
                readonly RED='\033[0;31m' GREEN='\033[0;32m'
                readonly YELLOW='\033[1;33m' BLUE='\033[0;34m' NC='\033[0m'
            else
                readonly RED="" GREEN="" YELLOW="" BLUE="" NC=""
            fi

            readonly COPR_WARNING="Enabling a Copr repository. Please note that this repository is not part
      of the main distribution, and quality may vary."

            print_error() { echo -e "''${RED}Error: $*''${NC}" >&2; }
            print_success() { echo -e "''${GREEN}✓ $*''${NC}"; }
            print_warning() { echo -e "''${YELLOW}Warning: $*''${NC}"; }
            print_info() { echo -e "''${BLUE}→ $*''${NC}"; }

            usage() {
                cat <<EOF
      Usage: $(basename "$0") <command> [arguments]

      Commands:
          enable <author/reponame> [version]    Enable a COPR repository
          disable <author/reponame>             Disable a COPR repository
          remove <author/reponame>              Remove a COPR repository
          list                                  List enabled repositories
          search <query>                        Search COPR repositories
          help                                  Show this help

      Version: $SCRIPT_VERSION (Optimized for Fedora Silverblue 43)
      EOF
                exit 0
            }

            check_immutable_system() {
                if ! command -v rpm-ostree &>/dev/null; then
                    print_warning "rpm-ostree not found."
                    read -rp "Continue? (y/N): " response
                    [[ "$response" =~ ^[Yy]$ ]] || exit 1
                fi
            }

            get_priv_cmd() {
                command -v sudo &>/dev/null && echo "sudo" && return
                command -v run0 &>/dev/null && echo "run0" && return
                print_error "Neither 'sudo' nor 'run0' found"
                exit 1
            }

            cache_credentials() {
                [[ "$1" == "sudo" ]] && sudo -v
            }

            validate_copr_repo() {
                [[ "$1" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$ ]] || {
                    print_error "Invalid format: $1"
                    return 1
                }
            }

            detect_fedora_version() {
                local version
                version=$(rpm -E '%{fedora}' 2>/dev/null)
                [[ "$version" =~ ^[0-9]+$ ]] && echo "$version" && return 0
                [[ -f /etc/os-release ]] && source /etc/os-release
                [[ "''${VERSION_ID:-}" =~ ^[0-9]+$ ]] && echo "$VERSION_ID" && return 0
                print_error "Could not detect Fedora version"
                return 1
            }

            enable_copr() {
                local author="$1" reponame="$2" version="$3"
                local repo_url="''${COPR_BASE_URL}/''${author}/''${reponame}/repo/fedora-''${version}/''${author}-''${reponame}-fedora-''${version}.repo"
                local repo_file="''${REPO_DIR}/_copr_''${author}-''${reponame}.repo"
                local priv_cmd
                priv_cmd=$(get_priv_cmd)

                print_info "Enabling: ''${author}/''${reponame} (Fedora ''${version})"
                echo ""
                echo "$COPR_WARNING"
                echo ""
                read -rp "Enable? [y/N]: " response
                [[ "$response" =~ ^[Yy]$ ]] || { print_info "Cancelled"; return 0; }

                cache_credentials "$priv_cmd"

                if [[ -f "$repo_file" ]]; then
                    print_info "Enabling existing repository..."
                    if [[ "$priv_cmd" == "run0" ]]; then
                        $priv_cmd sh -c "sed -i 's/enabled=0/enabled=1/g' '$repo_file' && \
                            chmod 644 '$repo_file' && \
                            rpm-ostree refresh-md 2>&1" || true
                    else
                        $priv_cmd sed -i 's/enabled=0/enabled=1/g' "$repo_file"
                        $priv_cmd chmod 644 "$repo_file"
                        rpm-ostree refresh-md 2>&1 || $priv_cmd rpm-ostree refresh-md 2>&1 || true
                    fi
                else
                    print_info "Downloading: ''${repo_url}"
                    local temp_file
                    temp_file=$(mktemp)
                    if ! curl -fsSL "$repo_url" -o "$temp_file" 2>/dev/null; then
                        rm -f "$temp_file"
                        print_error "Download failed"
                        return 1
                    fi
                    if [[ "$priv_cmd" == "run0" ]]; then
                        $priv_cmd sh -c "cp '$temp_file' '$repo_file' && \
                            chmod 644 '$repo_file' && \
                            rpm-ostree refresh-md 2>&1" || true
                    else
                        $priv_cmd cp "$temp_file" "$repo_file"
                        $priv_cmd chmod 644 "$repo_file"
                        rpm-ostree refresh-md 2>&1 || $priv_cmd rpm-ostree refresh-md 2>&1 || true
                    fi
                    rm -f "$temp_file"
                fi
                print_success "Enabled successfully"
            }

            disable_copr() {
                local repo_file="''${REPO_DIR}/_copr_$1-$2.repo"
                local priv_cmd
                priv_cmd=$(get_priv_cmd)
                [[ ! -f "$repo_file" ]] && { print_error "Not found"; return 1; }
                cache_credentials "$priv_cmd"
                $priv_cmd sed -i 's/enabled=1/enabled=0/g' "$repo_file"
                print_success "Disabled"
            }

            remove_copr() {
                local repo_file="''${REPO_DIR}/_copr_$1-$2.repo"
                local priv_cmd
                priv_cmd=$(get_priv_cmd)
                [[ ! -f "$repo_file" ]] && {
                    repo_file=$(find "$REPO_DIR" -name "*$2*.repo" 2>/dev/null | head -n1)
                    [[ -z "$repo_file" ]] && { print_error "Not found"; return 1; }
                }
                cache_credentials "$priv_cmd"
                mkdir -p "$BACKUP_DIR"
                local backup="''${BACKUP_DIR}/$(basename "$repo_file").$(date +%Y%m%d-%H%M%S)"
                $priv_cmd cp "$repo_file" "$backup"
                $priv_cmd rm "$repo_file"
                print_success "Removed (backup: $backup)"
            }

            list_copr() {
                print_info "Installed COPR repositories:"
                while IFS= read -r -d "" file; do
                    local name
                    name=$(basename "$file" .repo)
                    name="''${name#_copr_}"
                    grep -q "enabled=1" "$file" && echo "  ''${name} [enabled]" || echo "  ''${name} [disabled]"
                done < <(find "$REPO_DIR" -name "_copr_*.repo" -print0 2>/dev/null)
            }

            search_copr() {
                local url="https://copr.fedorainfracloud.org/coprs/fulltext/?fulltext=$1"
                print_info "Opening: $url"
                if command -v xdg-open &>/dev/null; then
                    xdg-open "$url" &>/dev/null &
                elif command -v open &>/dev/null; then
                    open "$url" &>/dev/null &
                else
                    echo "$url"
                fi
            }

            [[ $# -eq 0 || "$1" =~ ^(-h|--help|help)$ ]] && usage
            check_immutable_system
            command="$1"; shift

            case "$command" in
                enable)
                    validate_copr_repo "$1"
                    IFS='/' read -r author reponame <<< "$1"
                    version="''${2:-$(detect_fedora_version)}"
                    enable_copr "$author" "$reponame" "$version" ;;
                disable)
                    validate_copr_repo "$1"
                    IFS='/' read -r author reponame <<< "$1"
                    disable_copr "$author" "$reponame" ;;
                remove)
                    validate_copr_repo "$1"
                    IFS='/' read -r author reponame <<< "$1"
                    remove_copr "$author" "$reponame" ;;
                list) list_copr ;;
                search) search_copr "$1" ;;
                *) print_error "Unknown command: $command"; exit 1 ;;
            esac
    '')

    # ========================================================================
    # Fuzzy Finder Scripts
    # ========================================================================

    (mkScript "fconf" ''
      #!/usr/bin/env bash
      set -euo pipefail
      ${checkDepFunc}
      check_dependency "fd"
      check_dependency "fzf"
      check_dependency "bat"

      SELECTED=$(fd --type f --hidden . "$HOME" "$HOME/.config" 2>/dev/null | fzf \
          --height "60%" --layout "reverse" --border "rounded" \
          --prompt="Edit Config > " --no-multi \
          --preview 'bat --style=numbers --color=always {}')

      [[ -n "$SELECTED" ]] && "''${EDITOR:-vim}" "$SELECTED"
    '')

    (mkScript "fe" ''
      #!/usr/bin/env bash
      set -euo pipefail
      ${checkDepFunc}
      check_dependency "fd"
      check_dependency "fzf"
      check_dependency "bat"

      SELECTED=$(fd --type f --hidden --follow --exclude .git . | fzf \
          --height "80%" --layout "reverse" --info "inline" --border "rounded" \
          --preview 'bat --style=numbers --color=always --line-range :500 {}' \
          --query="''${1:-}" --select-1 --exit-0 --no-multi)

      [[ -n "$SELECTED" ]] && "''${EDITOR:-vim}" "$SELECTED"
    '')

    (mkScript "fkill" ''
      #!/usr/bin/env bash
      set -euo pipefail
      ${checkDepFunc}
      check_dependency "fzf"
      check_dependency "ps" "procps-ng"

      PID=$(ps -ef | sed 1d | grep -v "$$" | fzf --height "40%" --layout "reverse" --no-multi | awk '{print $2}')
      [[ -z "$PID" ]] && exit 0

      PROCESS_NAME=$(ps -p "$PID" -o comm=)
      read -r -p "Kill $PID ($PROCESS_NAME)? [y/N] " -n 1 REPLY
      echo
      [[ "$REPLY" =~ ^[Yy]$ ]] && kill -9 "$PID" && echo "Killed." || echo "Cancelled."
    '')

    (mkScript "fp" ''
      #!/usr/bin/env bash
      set -euo pipefail
      ${checkDepFunc}
      check_dependency "fd"
      check_dependency "fzf"
      check_dependency "bat"

      fd --hidden --follow --exclude .git | fzf \
          --height "80%" --layout "reverse" --border "rounded" \
          --preview-window "right:50%:wrap" \
          --preview 'if [ -d {} ]; then ls -lF --color=always {}; else bat --style=numbers --color=always {}; fi'
    '')

    (mkScript "fssh" ''
      #!/usr/bin/env bash
      set -euo pipefail
      ${checkDepFunc}
      check_dependency "fzf"
      check_dependency "ssh" "openssh"

      [[ ! -f "$HOME/.ssh/config" ]] && { echo "Error: ~/.ssh/config not found" >&2; exit 1; }

      HOST=$(grep '^Host ' "$HOME/.ssh/config" | awk '{print $2}' | grep -v '*' | \
          fzf --height "20%" --layout "reverse" --border "rounded" --prompt="SSH to > " --no-multi)

      [[ -n "$HOST" ]] && ssh "$HOST"
    '')

    (mkScript "se" ''
      #!/usr/bin/env bash
      set -euo pipefail
      ${checkDepFunc}
      check_dependency "rg" "ripgrep"
      check_dependency "fzf"
      check_dependency "bat"

      [[ $# -eq 0 ]] && { echo "Usage: se <pattern>" >&2; exit 1; }

      SELECTION=$(rg --line-number --no-heading --smart-case "$1" | fzf \
          --height "80%" --layout "reverse" --info "inline" --border "rounded" \
          --delimiter ':' --no-multi \
          --preview 'bat --style=numbers --color=always --highlight-line {2} {1}' \
          --preview-window 'up,60%,border-bottom,+{2}+3/3,~3')

      [[ -z "$SELECTION" ]] && exit 0
      FILE=$(echo "$SELECTION" | cut -d: -f1)
      LINE=$(echo "$SELECTION" | cut -d: -f2)
      "''${EDITOR:-vim}" "$FILE" "+$LINE"
    '')

    # ========================================================================
    # System Maintenance Scripts
    # ========================================================================

    (mkScript "safe-rm" ''
      #!/usr/bin/env bash
      set -euo pipefail

      readonly TRASH_DIR="$HOME/.local/share/trash/files"
      [[ $# -eq 0 ]] && { echo "Usage: $(basename "$0") <file1> [file2...]" >&2; exit 1; }

      targets=()
      for item in "$@"; do
          [[ ! -e "$item" ]] && { echo "Warning: '$item' not found" >&2; continue; }
          mkdir -p "$TRASH_DIR"
          [[ "$(realpath "$item")" == "$(realpath "$TRASH_DIR")" ]] && continue
          targets+=("$item")
      done

      [[ ''${#targets[@]} -eq 0 ]] && { echo "No valid items"; exit 0; }

      echo "Moving to trash:"
      printf "  - %s\n" "''${targets[@]}"
      read -r -p "Continue? [y/N]: " REPLY
      [[ ! "$REPLY" =~ ^[Yy]$ ]] && { echo "Cancelled"; exit 0; }

      for item in "''${targets[@]}"; do
          name="$(basename "$item")-$(date +%s)-$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 5)"
          mv "$item" "$TRASH_DIR/$name"
      done
      echo "✅ Complete"
    '')

    (mkScript "nuke-nvim" ''
      #!/usr/bin/env bash
      set -euo pipefail

      dirs=("$HOME/.config/nvim" "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim")

      echo "⚠️  WARNING: Will delete:"
      printf "  - %s\n" "''${dirs[@]}"
      read -r -p "Continue? [y/N]: " REPLY
      [[ ! "$REPLY" =~ ^[Yy]$ ]] && { echo "Cancelled"; exit 0; }

      for dir in "''${dirs[@]}"; do
          [[ -d "$dir" ]] && rm -rf "$dir" && echo "Removed: $dir"
      done
      echo "✅ Complete"
    '')

    # ========================================================================
    # Development & Git Scripts
    # ========================================================================

    (mkScript "setup-github-keys" ''
      #!/usr/bin/env bash
      set -euo pipefail
      ${checkDepFunc}
      check_dependency "ssh-keygen" "openssh"
      check_dependency "gh" "github-cli"

      mkdir -p ~/.ssh
      chmod 700 ~/.ssh

      generate_key() {
          local key_path="$HOME/.ssh/id_rsa_$1"
          [[ -f "$key_path" ]] && echo "→ Exists: $key_path" && return
          ssh-keygen -t rsa -b 4096 -C "$2" -f "$key_path" -N ""
          chmod 600 "$key_path"
          chmod 644 "$key_path.pub"
          echo "→ Generated: $key_path"
      }

      generate_key "aahsnr_configs" "ahsanur041@proton.me"
      generate_key "aahsnr_personal" "ahsanur041@gmail.com"
      generate_key "aahsnr_work" "aahsnr041@proton.me"
      generate_key "aahsnr_common" "ahsan.05rahman@gmail.com"

      echo "✅ Complete"
    '')

    # ========================================================================
    # Wayland/Screenshot Script
    # ========================================================================

    (mkScript "niri-screenshot" ''
            #!/usr/bin/env bash
            set -uo pipefail

            ${checkDepFunc}

            usage() {
                cat <<EOF
      Usage: $(basename "$0") [OPTION]

      Options:
          -r, --region        Capture region (default)
          -f, --fullscreen    Capture fullscreen
          -w, --window        Capture window
          -h, --help          Show help
      EOF
                exit 0
            }

            check_wayland() {
                if [[ -z "''${WAYLAND_DISPLAY:-}" && ( -z "''${XDG_SESSION_TYPE:-}" || "''${XDG_SESSION_TYPE}" != "wayland" ) ]]; then
                    echo "Warning: Not in Wayland session" >&2
                    read -r -p "Continue? [y/N] " -n 1 -r REPLY
                    echo
                    [[ "$REPLY" =~ ^[Yy]$ ]] || exit 0
                fi
            }

            capture_region() {
                check_dependency "grim"
                check_dependency "slurp"
                check_dependency "swappy"
                check_wayland
                
                selection=$(slurp 2>&1) || {
                    [[ $? -eq 1 ]] && exit 0
                    echo "Error: slurp failed" >&2
                    exit 1
                }
                [[ -z "$selection" ]] && exit 1
                grim -g "$selection" - | swappy -f -
            }

            capture_fullscreen() {
                check_dependency "grim"
                check_dependency "swappy"
                check_wayland
                grim - | swappy -f -
            }

            capture_window() {
                check_dependency "grim"
                check_dependency "swappy"
                check_dependency "swaymsg" "sway"
                check_dependency "jq"
                check_wayland
                
                geometry=$(swaymsg -t get-tree | jq -r '.. | select(.type?) | select(.focused==true) | .rect | "\(.x),\(.y) \(.width)x\(.height)"')
                [[ -z "$geometry" ]] && { echo "Error: No focused window" >&2; exit 1; }
                grim -g "$geometry" - | swappy -f -
            }

            [[ $# -eq 0 ]] && { capture_region; exit 0; }

            case "$1" in
                -r|--region) capture_region ;;
                -f|--fullscreen) capture_fullscreen ;;
                -w|--window) capture_window ;;
                -h|--help) usage ;;
                *) echo "Error: Unknown option '$1'" >&2; exit 1 ;;
            esac
    '')
  ];
}
