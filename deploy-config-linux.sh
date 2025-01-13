#!/bin/bash

# Usage function.
usage() {
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --debug             Turns on debug output messages."
    echo "  -t, --dry-run           Simulates actions without making changes."
    echo "  -v, --verbose           Shows standards output from commands."
    echo "  -h, --help              Show this help message and exit."
    echo ""
    echo "This script reads environment variables from a .env file and creates symbolic links for"
    echo "configuration files based on paths specified in each subfolder's "paths.txt" file."
    echo "Symbolic links allow the configurations to be used without copying files directly,"
    echo "facilitating easy updates and management using Git."
    echo ""
}

# Parsed from command line arguments.
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--debug)
            debug=true
            shift
            ;;
        -t|--dry-run)
            dryRun=true
            shift
            ;;
        -v|--verbose)
            verbose=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Invalid option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

# Set external logger- and error handling script paths
# Getting absolute path as script might be called from another script
externalLogger=$(dirname "${BASH_SOURCE[0]}")"/utils/bash/logging-and-output-function.sh"
externalErrorHandler=$(dirname "${BASH_SOURCE[0]}")"/utils/bash/error-handling-function.sh"

# Source external logger and error handler (but allow execution without them)
source "${externalErrorHandler}" "Dotfiles scrip failed" || true
source "${externalLogger}" || true

# Verify if logger function exists or sett fallback
if [[ $(type -t logMessage) != function ]]; then

    # Fallback minimalistic logger function
    logMessage() {

        local level="${2:-INFO}"
        echo "[$level] $1"

    }

fi

# Redirect output functions if not debug enabled
run() {

    if [[ "${verbose}" == "true" ]]; then

        "$@"

    else

        "$@" > /dev/null

    fi

}

# Check if the script is running in WSL
isWsl() {

    # Check /proc/version for WSL-specific terms
    grep -qEi "microsoft.*(subsystem|standard)" /proc/version

}

# Set dotfiles directory and log file
dotfilesDirectory=$(dirname "${BASH_SOURCE[0]}")

# Function to expand environment variables in paths
expandPath() {
    eval echo "$1"
}

# Set environment variable file path
if isWsl; then

    # Set environment variable file path for WSL
    $envFile = "${dotfilesDirectory}/wsl.env"

else

    # Set environment variable file path for Linux
    $envFile = "${dotfilesDirectory}/linux.env"

fi

# Load environment variables
if [ -f "${envFile}" ]; then

    logMessage "Loading environment variables from file (${envFile})..." "INFO"

    # Read each line from the file and export it
    while IFS='=' read -r key value; do

        # Skip empty lines and comments
        [[ -z "$key" || "$key" =~ ^# ]] && continue

        logMessage "Setting environment variable: ${key}=${value}" "DEBUG"

        # Export the variable
        export "$key=$value"

    done < "${envFile}"

else

    logMessage "Environment file (${envFile}) not found." "ERROR"

    exit 1

fi

# Find and process all paths.txt files in subdirectories
find "${dotfilesDirectory}" -type f -name "paths.txt" | while IFS= read -r pathsFile; do

    # Set current app directory
    appDirectory=$(dirname "$pathsFile")

    logMessage "Processing ${pathsFile}..." "INFO"

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

            logMessage "The target path (${expandedTarget}) exists. Skipping..." "DEBUG"

        else

            [[ "${dryRun}" != "true" ]] && ln -s "${expandedSource}" "${expandedTarget}"

            logMessage "Linked ${expandedSource} -> ${expandedTarget}" "INFO"

        fi

    done

done

logMessage "Symlink creation completed." "INFO"