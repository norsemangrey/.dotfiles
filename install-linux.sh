#!/bin/bash

# Set external logger- and error handling script paths
externalLogger="./utils/bash/logging-and-output-function.sh"
externalErrorHandler="./utils/bash/error-handling-function.sh"

# Source external logger and error handler (but allow execution without them)
source "${externalErrorHandler}" "Test script failed" || true
source "${externalLogger}" || true

# Verify if logger function exists or sett fallback
if [[ $(type -t logMessage) != function ]]; then

    # Fallback minimalistic logger function
    logMessage() {

        local level="${2:-INFO}"
        echo "[$level] $1"

    }

fi

# Set dotfiles directory and log file
DOTFILES_DIR="$HOME/.dotfiles"

# Function to expand environment variables in paths
expandPath() {
    eval echo "$1"
}

# Find and process all paths.txt files in subdirectories
find "$DOTFILES_DIR" -type f -name "paths.txt" | while IFS= read -r pathsFile; do

    # Set current app directory
    appDirectory=$(dirname "$pathsFile")

    logMessage "Processing ${pathsFile}..."

    # Process only lines starting with "l "
    grep '^l' "${pathsFile}" | while IFS= read -r line; do

        # Extract source and target paths (remove the "l " prefix)
        sourcePath=$(echo "$line" | awk '{print $2}')
        targetPath=$(echo "$line" | awk '{print $3}')

        # Expand environment variables and resolve full paths
        expandedSource=$(expandPath "${appDirectory}/${sourcePath}")
        expandedTarget=$(expandPath "${targetPath}")

        # Create parent directory for target if necessary
        mkdir -p "$(dirname "${expandedTarget}")"

        # Create symlink, handling existing files
        if [[ -e "${expandedTarget}" || -L "${expandedTarget}" ]]; then

            logMessage "The target path (${expandedTarget}) exists. Skipping..."

        else

            ln -s "${expandedSource}" "${expandedTarget}"

            logMessage "Linked ${expandedSource} -> ${expandedTarget}"

        fi

    done

done

logMessage "Symlink creation completed."