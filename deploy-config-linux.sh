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


# Function to expand environment variables  and resolve the actual path
expandPath() {

    local expandedPath
    local relativeBase="$2"

    # Expand any variables in the input path
    expandedPath=$(eval echo "$1")

    # Expand ~ to the full path if it exists
    if [[ "$expandedPath" == \~* ]]; then

        expandedPath="${HOME}${expandedPath:1}"

    fi

    # Check that the path is not absolute and try to resolve it as a relative path
    if [[ "${expandedPath}" != /* ]]; then

        # Only resolve the path to its absolute form if it starts with ./ or ../
        if [[ "$expandedPath" == ./* || "$expandedPath" == ../* ]]; then

            expandedPath=$(realpath -ms "${expandedPath}")

        # Otherwise, resolve the path relative to the base path
        else

            expandedPath=$(realpath -ms "${relativeBase}/${expandedPath}")

        fi

    fi

    echo "${expandedPath}"

}

# TODO: Might need to re-think the env setup....

# Set environment variable file path
if isWsl; then

    # Set environment variable file path for WSL
    envFile="${dotfilesDirectory}/.env.wsl"

else

    # Set environment variable file path for Linux
    envFile="${dotfilesDirectory}/.env.linux"

fi

# Load deploy related environment variables
if [ -f "${envFile}" ]; then

    logMessage "Loading environment variables from file (${envFile})..." "INFO"

    # Read each line from the file and export it
    while IFS='=' read -r key value; do

        # Skip empty lines and comments
        [[ -z "$key" || "$key" =~ ^# ]] && continue

        envPath=$(expandPath "${value}")

        logMessage "Setting environment variable: ${key}=${envPath}" "DEBUG"

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
    appPath=$(dirname "$pathsFile")
    appDirectory=$(basename "$appPath")

    logMessage "Processing symlink paths for '${appDirectory}'..." "INFO"

    # Process only lines starting with "l "
    grep '^l' "${pathsFile}" | while IFS= read -r line; do

        # Extract source and target paths (remove the "l " prefix)
        targetPathRaw=$(echo "$line" | awk '{print $2}')
        symlinkPathRaw=$(echo "$line" | awk '{print $3}')

        # Resolve/expand initial absolute and relative paths
        targetPathAbsolute=$(expandPath "${targetPathRaw}" "${appPath}")

        # Verify/test target path

        # Check if the target path is an existing absolute path
        if [[ -e "${targetPathAbsolute}" ]]; then

            targetPath="${targetPathAbsolute}"

        else

            logMessage "Incorrect formatted target path (${targetPathRaw}), missing envs, or path (${targetPathAbsolute}) does not exist." "ERROR"

            continue

        fi

        # Resolve/expand symlink path
        symlinkPath=$(expandPath "${symlinkPathRaw}" "${appPath}")

        # Create parent directory for symlink if necessary
        if [[ "${dryRun}" != "true" ]]; then
            mkdir -p "$(dirname "${symlinkPath}")"
        fi

        # Check if an item already exists (file, directory, or symlink, even broken symlink)
        if [[ -e "${symlinkPath}" || -L "${symlinkPath}" ]]; then

            # Check specifically if the item is a symlink
            if [[ -L "${symlinkPath}" ]]; then

                # If it's a symlink, check if it points to the correct source
                currentTarget=$(readlink "${symlinkPath}")

                # Check if the link target path is correct
                if [[ "${currentTarget}" != "${targetPath}" ]]; then

                    logMessage "Symlink exists (${symlinkPath}), but points to a different target (${currentTarget}). Recreating..." "DEBUG"

                    # Remove the incorrect symlink
                    if [[ "${dryRun}" != "true" ]]; then
                        rm "${symlinkPath}"
                    fi

                else

                    logMessage "Symlink already exists (${symlinkPath}) and points to the correct target (${targetPath})" "INFO"

                    continue

                fi

            else

                logMessage "A file or directory exists in the symlink path (${symlinkPath}) and is not a symlink. Replacing..." "INFO"

                # It is not a symbolic link (regular file or directory)
                if [[ "${dryRun}" != "true" ]]; then
                    rm -rf "${symlinkPath}"
                fi

            fi

        fi

        # Create new symlink
        if [[ "${dryRun}" != "true" ]]; then
            ln -s "${targetPath}" "${symlinkPath}"
        fi

        logMessage "Creating new symlink: ${symlinkPath} -> ${targetPath}" "INFO"

    done

done
