#!/bin/bash
# sync-package-rules.sh
# Scans Xcode DerivedData checkouts AND sibling repos for .claude/*-rules.md files
# and copies them into this project's .claude/rules/synced/ directory.
# DerivedData is scanned first; local sibling repos override if the same file exists.
# Runs automatically via SessionStart hook.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PARENT_DIR="$(cd "$PROJECT_ROOT/.." && pwd)"
SYNCED_DIR="$PROJECT_ROOT/.claude/rules/synced"
PROJECT_NAME="$(basename "$PROJECT_ROOT")"
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"

mkdir -p "$SYNCED_DIR"

synced=0

# 1. Scan Xcode DerivedData checkouts (covers all packages used by the project)
for checkouts_dir in "$DERIVED_DATA/$PROJECT_NAME-"*/SourcePackages/checkouts/; do
    [ -d "$checkouts_dir" ] || continue

    for pkg_dir in "$checkouts_dir"*/; do
        [ -d "$pkg_dir" ] || continue

        for rules_file in "$pkg_dir".claude/*-rules.md; do
            [ -f "$rules_file" ] || continue
            cp "$rules_file" "$SYNCED_DIR/$(basename "$rules_file")"
            ((synced++))
        done
    done
done

# 2. Scan sibling repos (local clones override DerivedData versions)
for dir in "$PARENT_DIR"/*/; do
    [ "$(cd "$dir" && pwd)" = "$PROJECT_ROOT" ] && continue

    for rules_file in "$dir".claude/*-rules.md; do
        [ -f "$rules_file" ] || continue
        cp "$rules_file" "$SYNCED_DIR/$(basename "$rules_file")"
        ((synced++))
    done
done

echo "Package rules sync: $synced rules copied to .claude/rules/synced/"
