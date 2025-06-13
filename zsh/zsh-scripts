# Set the base directory where all plugins will be stored
zshPluginDir="${HOME}/.config/zsh/plugins"

# Ensure the plugin directory exists
mkdir -p "$zshPluginDir"

# Function to clone or update a Zsh plugin from a Git repository
cloneOrUpdatePlugin() {

    local repoUrl="$1"
    local pluginName
    local pluginPath

    # Extract the plugin name from the URL
    pluginName="$(basename "$repoUrl" .git)"

    # Full path to where the plugin will be stored
    pluginPath="${zshPluginDir}/${pluginName}"

    # Check if plugin exists
    if [[ -d "$pluginPath/.git" ]]; then

        # Attempt to update the existing plugin silently
        if ! git -C "$pluginPath" pull --ff-only --quiet 2>/dev/null; then

        echo "❌ Failed to update plugin: $pluginName" >&2

        fi

    else

        # Attempt to clone the plugin silently
        if ! git clone --depth=1 --quiet "$repoUrl" "$pluginPath" 2>/dev/null; then

        echo "❌ Failed to clone plugin: $pluginName" >&2

        fi

    fi

}
