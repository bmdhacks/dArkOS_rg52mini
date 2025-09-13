#!/usr/bin/env bash
set -euo pipefail

# --- Defaults (can be overridden by CLI args) ---
SRC_SUFFIX="353m"
DST_SUFFIX="rgb30"

# --- Parse arguments ---
DRYRUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
    DRYRUN=1
    shift
fi

if [[ $# -ge 2 ]]; then
    SRC_SUFFIX="$1"
    DST_SUFFIX="$2"
    shift 2
fi

# --- Info ---
if [[ $DRYRUN -eq 1 ]]; then
    echo "Running in DRY-RUN mode"
fi
echo "Mapping: $SRC_SUFFIX → $DST_SUFFIX"

# --- Prune top-level Ark_devenv* and Arkbuild* ---
PRUNE=""
for d in ./Ark_devenv* ./Arkbuild*; do
    if [[ -d "$d" ]]; then
        PRUNE="$PRUNE -path '$d' -prune -o"
    fi
done

# --- Main find loop ---
eval "find . $PRUNE \( -type d -name '*$SRC_SUFFIX' -o -type f -name '*.$SRC_SUFFIX' \) -print" |
while read -r item; do
    dir=$(dirname "$item")
    base=$(basename "$item")

    if [[ -d "$item" ]]; then
        # Replace suffix at end of directory name
        newbase="${base%$SRC_SUFFIX}$DST_SUFFIX"
        target="$dir/$newbase"
        if [[ -e "$target" ]]; then
            echo "⚠️  Skipping: $target already exists"
        else
            if [[ $DRYRUN -eq 1 ]]; then
                echo "[dry-run] ln -s \"$base\" \"$target\""
            else
                ln -s "$base" "$target"
                echo "Created symlink: $target -> $base"
            fi
        fi
    elif [[ -f "$item" ]]; then
        # Replace file extension
        newbase="${base%.$SRC_SUFFIX}.$DST_SUFFIX"
        target="$dir/$newbase"
        if [[ -e "$target" ]]; then
            echo "⚠️  Skipping: $target already exists"
        else
            if [[ $DRYRUN -eq 1 ]]; then
                echo "[dry-run] ln -s \"$base\" \"$target\""
            else
                ln -s "$base" "$target"
                echo "Created symlink: $target -> $base"
            fi
        fi
    fi
done
