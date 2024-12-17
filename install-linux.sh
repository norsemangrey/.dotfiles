#!/bin/bash

# Set dotfiles directory and log file
DOTFILES_DIR="$HOME/.dotfiles"
LOG_FILE="$HOME/symlink_manager.log"

# Clear log file at the start
> "$LOG_FILE"

# Function to expand environment variables in paths
expand_path() {
    eval echo "$1"
}

# Find and process all paths.txt files in subdirectories
find "$DOTFILES_DIR" -type f -name "paths.txt" | while IFS= read -r paths_file; do
    app_dir=$(dirname "$paths_file")
    echo "Processing $paths_file..." | tee -a "$LOG_FILE"

    # Process only lines starting with "l "
    grep '^l' "$paths_file" | while IFS= read -r line; do
        # Extract source and target paths (remove the "l " prefix)
        source_path=$(echo "$line" | awk '{print $2}')
        target_path=$(echo "$line" | awk '{print $3}')

        # Expand environment variables and resolve full paths
        expanded_source=$(expand_path "$app_dir/$source_path")
        expanded_target=$(expand_path "$target_path")

        # Create parent directory for target if necessary
        mkdir -p "$(dirname "$expanded_target")"

        # Create symlink, handling existing files
        if [[ -e "$expanded_target" || -L "$expanded_target" ]]; then
            echo "Warning: $expanded_target exists. Skipping..." | tee -a "$LOG_FILE"
        else
            ln -s "$expanded_source" "$expanded_target" && echo "Linked $expanded_source -> $expanded_target" | tee -a "$LOG_FILE"
        fi
    done
done

echo "Symlink creation completed. See $LOG_FILE for details."