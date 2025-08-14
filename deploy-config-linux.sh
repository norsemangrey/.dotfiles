#!/bin/bash

# Usage function.
usage() {
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -D, --debug             Turns on debug output messages."
    echo "  -d, --dry-run           Simulates actions without making changes."
    echo "  -t, --test              Runs in test mode (only process 'test' directory)."
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
        -D|--debug)
            debug=true
            shift
            ;;
        -d|--dry-run)
            dryRun=true
            shift
            ;;
        -t|--test)
            testMode=true
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

# Use verbose logging
logVerbose() {

    # Check if verbose flag is set
    if [[ "${verbose}" == "true" ]]; then

        # Call logger and pass message
        logMessage "$1" "${2:-INFO}"

    fi

}

# Redirect output functions if not debug enabled
run() {

    # Check if verbose flag is set
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

# Function to handle either secure copy or symlink creation
processItem() {

    local targetPath="$1"
    local destinationPath="$2"
    local symlinkPath="$2"
    local copyMode="$3"

    # Check if secure copy mode
    if [[ "${copyMode}" == "true" ]]; then

        # In copy mode, check read permission on source before copying
        if [[ ! -r "${targetPath}" ]]; then

            logMessage "No read permission on source '${targetPath}'. Skipping copy." "ERROR"

            return

        fi

        # If target is a directory, check execute permission as well (to access contents)
        if [[ -d "${targetPath}" && ! -x "${targetPath}" ]]; then

            logMessage "No execute permission on directory '${targetPath}'. Skipping copy." "ERROR"

            return

        fi

        # If destination already exists, skip copy and permission changes
        if [[ -e "${destinationPath}" ]]; then

            logVerbose "Destination already exists (${destinationPath}). Skipping copy." "INFO"

        # Otherwise copy and set restrictive permissions
        else

            logMessage "Copying with user-only permissions: ${destinationPath} <- ${targetPath}" "INFO"

            # Copy and set permissions
            if [[ "${dryRun}" != "true" ]]; then

                # TODO: Consider rsync instead of copy

                # Copy target file to destination
                cp -a "${targetPath}" "${destinationPath}"

                # Set permissions (user read/write only)
                if [[ -d "${destinationPath}" ]]; then

                    # Set directory permissions
                    chmod -R 700 "${destinationPath}"

                else

                    # Set file permissions
                    chmod 600 "${destinationPath}"

                fi

            fi

        fi

    else

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

                    logVerbose "Symlink already exists (${symlinkPath}) and points to the correct target (${targetPath})" "INFO"

                    return

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

        logMessage "Creating new symlink: ${symlinkPath} => ${targetPath}" "INFO"

    fi

}

# Check if in test mode
if [[ "${testMode}" == "true" ]]; then

    # Set search path to test directory
    searchPath="${dotfilesDirectory}/test"

    logMessage "Running in test mode. Only processing paths in: ${testDirectory}" "INFO"

else

    # Use normal search path
    searchPath="${dotfilesDirectory}"

fi

# Find and process all paths.txt files in subdirectories
find "${searchPath}" -type f -name "paths.txt" | while IFS= read -r pathsFile; do

    # Get the application path by stripping the filename
    appPath=$(dirname "$pathsFile")

    # Extract the last directory name from the application path
    appDirectory=$(basename "$appPath")

    # If not in test mode, skip the test directory
    if [[ "${testMode}" != "true" && "${appDirectory}" == "test" ]]; then
        continue
    fi

    logMessage "Processing paths for '${appDirectory}'..." "INFO"

    # Process only lines starting with "l "
    grep '^l' "${pathsFile}" | while IFS= read -r line; do

        # Extract target, destination, and mode columns from the line
        targetPathRaw=$(echo "${line}" | awk '{print $2}')
        symlinkPathRaw=$(echo "${line}" | awk '{print $3}')
        mode=$(echo "${line}" | awk '{print $4}')

        # Set secure copy mode if the mode column is "*" (copy and set permissions instead of symlink)
        copySecureMode=false
        [[ "${mode}" == "*" ]] && copySecureMode=true

        # TODO: Consider a filter option instead of all folder content (e.g. <string>* or *<string>)

        # Handle wildcard target paths (i.e. handle directory contents only, not parent directory)
        handleContentOnly=false
        [[ "${targetPathRaw}" == *"*" ]] && handleContentOnly=true

        # Resolve/expand initial absolute and relative paths (stripping trailing '*' only if present)
        targetPathAbsolute=$(expandPath "${targetPathRaw%\*}" "${appPath}")
        symlinkPath=$(expandPath "${symlinkPathRaw}" "${appPath}")

        # Verify/test target path

        # Check if the target path is an existing absolute path
        if [[ -e "${targetPathAbsolute}" ]]; then

            targetPath="${targetPathAbsolute}"

        else

            logMessage "Incorrect formatted target path (${targetPathRaw}), missing envs, or path (${targetPathAbsolute}) does not exist." "ERROR"

            continue

        fi

        # Set parent directory based on directory handling method
        parentDirectory=$([[ "$handleContentOnly" == "true" ]] && echo "$symlinkPath" || echo "$(dirname "$symlinkPath")")

        # Check if parent directory exists
        if [[ ! -e "${parentDirectory}" ]]; then

            logMessage "Creating parent directory '${parentDirectory}'..." "INFO"

            # Ensure that parent directory exists
            if [[ "${dryRun}" != "true" ]]; then
                mkdir -p "${parentDirectory}"
            fi

        fi

        # Handle wildcard target paths
        if [[ "${handleContentOnly}" == "true" ]]; then

            # Check read and execute permission on directory before listing
            if [[ ! -r "$targetPathAbsolute" || ! -x "$targetPathAbsolute" ]]; then

                logMessage "No read/execute permission on directory '${targetPathAbsolute}'. Skipping its contents." "ERROR"

            else

                # Process each file/item in the expanded directory
                for item in "$targetPathAbsolute"/*; do

                    # Process item
                    processItem "${item}" "${symlinkPath}/$(basename "${item}")" "${copySecureMode}"

                done

            fi

        else

            # Process the single item
            processItem "${targetPathAbsolute}" "${symlinkPath}" "${copySecureMode}"

        fi

    done

done
