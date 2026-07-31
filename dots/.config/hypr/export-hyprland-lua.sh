#!/usr/bin/env bash
#
# export-hyprland-lua.sh
#
# Extracts every ```lua fenced code block from a markdown file and writes it
# to the target path that is given (as a single backtick-quoted path, e.g.
# `~/.config/hypr/hyprland/vars.lua`) on the line(s) immediately preceding
# the fence. Existing files are backed up before being overwritten. If a
# lua interpreter is available, every written file is syntax-checked
# (parsed only, not executed) with `luaX.Y -p` / `luac -p`.
#
# Usage:
#   ./export-hyprland-lua.sh /path/to/hyprland-lua.md
#
set -euo pipefail

# ---------------------------------------------------------------------------
# 0. Args & sanity checks
# ---------------------------------------------------------------------------
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <markdown-file>" >&2
    exit 1
fi

MD_FILE=$1

if [[ ! -f "$MD_FILE" ]]; then
    echo "Error: markdown file not found: $MD_FILE" >&2
    exit 1
fi
if [[ ! -r "$MD_FILE" ]]; then
    echo "Error: markdown file is not readable: $MD_FILE" >&2
    exit 1
fi

if ! command -v realpath >/dev/null 2>&1; then
    echo "Error: 'realpath' (GNU coreutils) is required but was not found on PATH." >&2
    exit 1
fi

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$HOME/.config/hypr-backup-$TIMESTAMP"

# Only allow lua files to land inside ~/.config/hypr (defense in depth: a
# malformed/malicious path in the markdown can never write outside of it).
#
# ~/.config/hypr is frequently a symlink (e.g. a dotfiles repo checked out
# elsewhere and symlinked in). realpath -m follows symlinks for every path
# component that already exists, so BOTH sides of the later containment
# check must be run through the same realpath -m normalization, or a
# symlinked hypr dir causes every legitimate target to be rejected.
ALLOWED_ROOT="$(realpath -m -- "$HOME/.config/hypr")"

declare -a WRITTEN_FILES=()
declare -a SKIPPED_BLOCKS=()
declare -i BLOCK_COUNT=0

# Path marker line looks like:  `~/.config/hypr/hyprland/vars.lua`
# shellcheck disable=SC2016  # intentional regex literal, not meant to expand
path_regex='^[[:space:]]*`(~/\.config/hypr/[A-Za-z0-9_./-]+\.lua)`[[:space:]]*$'

current_path=""
in_block=0        # 0 = outside, 1 = capturing a mapped block, 2 = skipping an unmapped block
block_content=""
line_no=0

# ---------------------------------------------------------------------------
# 1. Parse the markdown and extract blocks
# ---------------------------------------------------------------------------
while IFS= read -r line || [[ -n "$line" ]]; do
    line_no=$((line_no + 1))

    if [[ $in_block -eq 0 ]]; then
        if [[ $line =~ $path_regex ]]; then
            current_path="${BASH_REMATCH[1]}"
        elif [[ "$line" == '```lua' ]]; then
            BLOCK_COUNT+=1
            block_content=""
            if [[ -z "$current_path" ]]; then
                echo "Warning: line $line_no: \`\`\`lua block with no preceding target path — skipping" >&2
                SKIPPED_BLOCKS+=("line $line_no")
                in_block=2
            else
                in_block=1
            fi
        fi
    else
        if [[ "$line" == '```' ]]; then
            if [[ $in_block -eq 1 ]]; then
                target="${current_path/#\~/$HOME}"
                target="$(realpath -m -- "$target")"

                # Safety check: must resolve inside ~/.config/hypr
                if [[ "$target" != "$ALLOWED_ROOT"/* && "$target" != "$ALLOWED_ROOT" ]]; then
                    echo "Error: refusing to write outside $ALLOWED_ROOT: $target" >&2
                    exit 1
                fi

                mkdir -p -- "$(dirname -- "$target")"

                if [[ -f "$target" ]]; then
                    rel="${target#"$HOME"/}"
                    mkdir -p -- "$(dirname -- "$BACKUP_DIR/$rel")"
                    cp -p -- "$target" "$BACKUP_DIR/$rel"
                fi

                printf '%s' "$block_content" > "$target"
                WRITTEN_FILES+=("$target")
                echo "Wrote: $target"
            fi
            in_block=0
            current_path=""
            block_content=""
        else
            block_content+="$line"$'\n'
        fi
    fi
done < "$MD_FILE"

if [[ $in_block -ne 0 ]]; then
    echo "Error: markdown file ended while still inside a code fence (unterminated \`\`\`). Aborting." >&2
    exit 1
fi

if [[ ${#WRITTEN_FILES[@]} -eq 0 ]]; then
    echo "No lua code blocks with a recognizable target path were found in $MD_FILE." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# 2. Syntax-check every written file (parse only, does not execute/require)
# ---------------------------------------------------------------------------
LUA_BIN=""
for candidate in luac luac5.4 luac5.3 luac5.1 lua lua5.4 lua5.3 lua5.1; do
    if command -v "$candidate" >/dev/null 2>&1; then
        LUA_BIN="$candidate"
        break
    fi
done

echo
if [[ -n "$LUA_BIN" ]]; then
    echo "Syntax-checking generated files with '$LUA_BIN'..."
    FAILED=0
    for f in "${WRITTEN_FILES[@]}"; do
        if [[ "$LUA_BIN" == luac* ]]; then
            if ! "$LUA_BIN" -p "$f" 2>/tmp/luacheck.err; then
                echo "  SYNTAX ERROR in $f:" >&2
                sed 's/^/    /' /tmp/luacheck.err >&2
                FAILED=1
            fi
        else
            # lua interpreter: loadfile() only parses, it does not run the chunk
            if ! "$LUA_BIN" -e "assert(loadfile('$f'))" 2>/tmp/luacheck.err; then
                echo "  SYNTAX ERROR in $f:" >&2
                sed 's/^/    /' /tmp/luacheck.err >&2
                FAILED=1
            fi
        fi
    done
    if [[ $FAILED -eq 1 ]]; then
        echo "One or more files failed syntax validation. Review the errors above." >&2
        exit 1
    fi
    echo "All ${#WRITTEN_FILES[@]} files passed syntax validation."
else
    echo "Note: no lua/luac interpreter found on PATH, skipping syntax validation." >&2
    echo "      Install one (e.g. 'sudo apt install lua5.4') to enable this check." >&2
fi

# ---------------------------------------------------------------------------
# 3. Summary
# ---------------------------------------------------------------------------
echo
echo "Done. ${#WRITTEN_FILES[@]} file(s) written:"
for f in "${WRITTEN_FILES[@]}"; do
    echo "  - $f"
done
if [[ -d "$BACKUP_DIR" ]]; then
    echo "Existing files were backed up to: $BACKUP_DIR"
fi
if [[ ${#SKIPPED_BLOCKS[@]} -gt 0 ]]; then
    echo "Skipped ${#SKIPPED_BLOCKS[@]} lua block(s) with no target path: ${SKIPPED_BLOCKS[*]}"
fi
