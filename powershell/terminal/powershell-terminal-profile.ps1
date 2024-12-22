### As a reminder, to enable unsigned script execution of local scripts on client Windows,
### you need to run this line (or similar) from an elevated PowerShell prompt:
### Set-ExecutionPolicy -ExecutionPolicy RemoteSigned


### Import Modules

# Improved command line editing experience for PowerShell
Import-Module -Name PSReadLine

# Command line auto-completion plugin for PSReadLine
Import-Module -Name CompletionPredictor

# Command line 'fuzzy' finder using FZF for PowerShell
Import-Module -Name PSFzf

# Git status for PowerShell prompts and git command tab completion
Import-Module -Name posh-git


### Configure Module Settings

## PSReadLine

# Resets any key bindings and sets editing mode to emulate Bash key bindings
Set-PSReadLineOption -EditMode Emacs

# Sets no error indication
Set-PSReadLineOption -BellStyle None

# Enables the predictive IntelliSense feature and use both history and plugin as the sources
Set-PSReadLineOption -PredictionSource HistoryAndPlugin

# Sets suggestions to be rendered in a drop down list
Set-PSReadLineOption -PredictionViewStyle ListView

# Deletes the character at the cursor position (similar to Del)
Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar


## FZF / PSFzf

# Keyboard chord shortcut to trigger file and directory selection
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+f'

# Keyboard chord shortcut to trigger history selection
Set-PsFzfOption -PSReadlineChordReverseHistory 'Ctrl+r'

# Customize FZF
$env:FZF_DEFAULT_OPTS="--color=bg+:#C61C6F,gutter:-1"

# Pick multiple files from fzf that will be launched in Visual Studio Code
# Use TAB to select an item when choosing multiple
New-Alias -Scope Global -Name fe -Value Invoke-FuzzyEdit -ErrorAction Ignore


### Admin Commands

# Find out if the current user identity is elevated (has admin rights)
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal $identity
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# We don't need these any more; they were just temporary variables to get to $isAdmin.
# Delete them to prevent cluttering up the user profile.
Remove-Variable identity
Remove-Variable principal

# Simple function to start a new elevated process. If arguments are supplied then
# a single command is started with admin rights; if not then a new admin instance
# of PowerShell is started.
function Start-Elevated {
    if ($args.Count -gt 0) {
        $argList = "& '" + $args + "'"
        Start-Process "$psHome\pwsh.exe" -Verb runAs -ArgumentList $argList
    } else {
        Start-Process "$psHome\pwsh.exe" -Verb runAs
    }
}
Set-Alias -Name su -Value Start-Elevated
Set-Alias -Name sudo -Value Start-Elevated
Set-Alias -Name admin -Value Start-Elevated


### Custom Commands

# Lists functions in this profile
function Get-MyCommands {
    Get-Content -Path $profile | Select-String -Pattern "^function.+" | ForEach-Object {
        [Regex]::Matches($_, "^function ([a-z.-]+)","IgnoreCase").Groups[1].Value
    } | Where-Object { $_ -ine "prompt" } | Sort-Object
}
Set-Alias -Name mycmd -Value Get-MyCommands


# Checks if the provided command exists
function Test-CommandExist {
    Param ($command)
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    try { if (Get-Command $command) { RETURN $true } }
    Catch { Write-Host "$command does not exist"; RETURN $false }
    Finally { $ErrorActionPreference = $oldPreference }
}
Set-Alias -Name iscmd -Value Test-CommandExist


# Finds items in the current directory and subdirectories containing the input string
function Find-Items {
    if ($args.Count -gt 0) {
        Get-ChildItem -Recurse -Include "*${args}*" | Foreach-Object FullName
    } else {
        Get-ChildItem -Recurse | Foreach-Object FullName
    }
}
Set-Alias -Name find -Value Find-Items


# Get the public ip address
function Get-PubIP {
    (Invoke-WebRequest http://ifconfig.me/ip ).Content
}
Set-Alias -Name myip -Value Get-PubIP

# Reload a the PS profile
function Reload-Profile {
    & $profile
}
Set-Alias -Name reload -Value Reload-Profile

# Extracts the contents of a specified zip file to the current working directory
function unzip($file) {
    Write-Output("Extracting", $file, "to", $pwd)
    $fullFile = Get-ChildItem -Path $pwd -Filter .\cove.zip | ForEach-Object { $_.FullName }
    Expand-Archive -Path $fullFile -DestinationPath $pwd
}

# Uploads a file to ix.io (terminal pastebin) using the curl command, which returns the URL
function post($file) {
    curl.exe -F "f:1=@$file" ix.io
}

# Searches for a regex pattern in files within a specified directory or in the pipeline input
function grep($regex, $dir) {
    if ($dir) {
        Get-ChildItem $dir | Select-String $regex
        return
    }
    $input | Select-String $regex
}

# Creates an empty file or updates the timestamp of an existing file
function touch($file) {
    "" | Out-File $file -Encoding ASCII
}

# Replaces occurrences of a specified string with another string in a file
function sed($file, $find, $replace) {
    (Get-Content $file).replace("$find", $replace) | Set-Content $file
}

# Displays the path of the executable associated with a specified command
function which($command) {
    Get-Command -Name $command -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}

# Sets an environment variable with a specified name and value
function export($name, $value) {
    Set-Item -Force -Path "env:$name" -Value $value
}

# Retrieves information about processes whit names containing the given string
function pgrep($name) {
    Get-Process "*${name}*"
}

# Opens a fuzzy search of the process list
function psearch($name) {
    Get-Process | fzf
}

# Terminates a process with a specified name
function pkill($name) {
    Get-Process $name -ErrorAction SilentlyContinue | Stop-Process
}

# Function to mimic the OpenSSH function top copy public keys found on Linux
function ssh-copy-id([string]$sshHost) {

    # Check if the host argument is provided
    if (-not $sshHost) {

        Write-Host "Error: You must provide a target host. Usage: ssh-copy-id <username>@<server_ip>"
        return

    }

    # Extract the hostname or IP address from sshHost (before '@')
    $hostname = $sshHost.Split('@')[1]

    # Verify if the SSH host is reachable by attempting to ping (optional step)
    try {

        $pingResult = Test-Connection -ComputerName $hostname -Count 1 -Quiet

        if (-not $pingResult) {

            Write-Host "Error: Unable to reach the SSH host ($sshHost). Please check the host address or network connectivity."
            return

        }

    } catch {

        Write-Host "Error: Unable to ping the host. Please check the host address or network connectivity."
        return

    }

    # Find the first .pub file in the user's .ssh directory
    $publicKeyFile = Get-ChildItem "$env:USERPROFILE\.ssh\keys" -Filter "*.pub" | Select-Object -First 1

    if ($null -eq $publicKeyFile) {

        Write-Host "Error: No public key found in ~/.ssh/keys directory. Please generate an SSH key pair first."
        return

    }

    # Read the content of the public key
    $publicKey = Get-Content $publicKeyFile.FullName

    # Use SSH to copy the public key to the remote server's authorized_keys file
    try {

        $command = "mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys && chmod -R go= ~/.ssh && echo '$publicKey' >> ~/.ssh/authorized_keys"

        ssh "$sshHost" $command

        Write-Host "Public key copied to $sshHost successfully."

    } catch {

        Write-Host "Error: Failed to copy the public key to $sshHost. Please ensure SSH is properly set up on the server."

    }

}


# Creates drive shortcut for Work Folders, if current user account is using it
if (Test-Path "$env:USERPROFILE\Work Folders") {

    New-PSDrive -Name Work -PSProvider FileSystem -Root "$env:USERPROFILE\Work Folders" -Description "Work Folders"

    function Work: { Set-Location Work: }

}


# Useful shortcuts for traversing directories
function cd... { Set-Location ..\.. }
function cd.... { Set-Location ..\..\.. }

# Quick shortcut to start notepad
function note { notepad $args }

# Shortcut for clearing terminal
Set-Alias -Name clr -Value clear

# List Items Aliases

# Shortcut for listing files and directories
function li { Get-ChildItem -Path $pwd }
function lf { Get-ChildItem -Path $pwd -File }
function ld { Get-ChildItem -Path $pwd -Directory }

# Starts fuzzy finder on file and directory search
function flf { Get-ChildItem -Path $pwd -File | Invoke-Fzf | % { code $_ } }
function fld { Get-ChildItem -Path $pwd -Directory | Invoke-Fzf | Set-Location }

# LSD Aliases

# Shortcuts for listing items using LSD
function l    { lsd --oneline --literal }
function ll   { lsd --long --literal }
function la   { lsd --all --oneline --literal --no-symlink }
function lla  { lsd --all --literal --long }
function lt   { lsd --tree --literal }
function lt1  { lsd --tree --depth 1 --literal }
function lt2  { lsd --tree --depth 2 --literal }
function lt3  { lsd --tree --depth 3 --literal }
function lt4  { lsd --tree --depth 4 --literal }
function lt5  { lsd --tree --depth 5 --literal }

# Starts fuzzy finder on 'list all' and open selecion in Visual Studio Code
function flf { la | Invoke-Fzf | % { code $_ } }


function Help-MyProfile {

    $commands = @(
        [PSCustomObject]@{ Command = 'fe';     Description = 'Launch multiple files selected with FZF in Visual Studio Code';       Usage = 'fe' }
        [PSCustomObject]@{ Command = 'su';     Description = 'Start a new elevated PowerShell process or command';                  Usage = 'su [command]' }
        [PSCustomObject]@{ Command = 'sudo';   Description = 'Alias for su';                                                        Usage = 'sudo [command]' }
        [PSCustomObject]@{ Command = 'admin';  Description = 'Alias for su';                                                        Usage = 'admin [command]' }
        [PSCustomObject]@{ Command = 'mycmd';  Description = 'List all functions defined in the profile';                           Usage = 'mycmd' }
        [PSCustomObject]@{ Command = 'iscmd';  Description = 'Check if a command exists';                                           Usage = 'iscmd <command>' }
        [PSCustomObject]@{ Command = 'find';   Description = 'Search for files and directories containing a specific string';       Usage = 'find <string>' }
        [PSCustomObject]@{ Command = 'myip';   Description = 'Get the public IP address';                                           Usage = 'myip' }
        [PSCustomObject]@{ Command = 'reload'; Description = 'Reload the PowerShell profile';                                       Usage = 'reload' }
        [PSCustomObject]@{ Command = 'clr';    Description = 'Clear the terminal';                                                  Usage = 'clr' }
        [PSCustomObject]@{ Command = 'l';      Description = 'List items using lsd in a single-line format';                        Usage = 'l' }
        [PSCustomObject]@{ Command = 'll';     Description = 'List items using lsd in a long format';                               Usage = 'll' }
        [PSCustomObject]@{ Command = 'la';     Description = 'List all items including hidden using lsd in single-line format';     Usage = 'la' }
        [PSCustomObject]@{ Command = 'lla';    Description = 'List all items in a detailed view using lsd';                         Usage = 'lla' }
        [PSCustomObject]@{ Command = 'lt';     Description = 'List items in a tree format using lsd';                               Usage = 'lt' }
        [PSCustomObject]@{ Command = 'lt1';    Description = 'List items in a tree format with depth 1 using lsd';                  Usage = 'lt1' }
        [PSCustomObject]@{ Command = 'lt2';    Description = 'List items in a tree format with depth 2 using lsd';                  Usage = 'lt2' }
        [PSCustomObject]@{ Command = 'lt3';    Description = 'List items in a tree format with depth 3 using lsd';                  Usage = 'lt3' }
        [PSCustomObject]@{ Command = 'lt4';    Description = 'List items in a tree format with depth 4 using lsd';                  Usage = 'lt4' }
        [PSCustomObject]@{ Command = 'lt5';    Description = 'List items in a tree format with depth 5 using lsd';                  Usage = 'lt5' }
        [PSCustomObject]@{ Command = 'cd...';  Description = 'Navigate two levels up the directory tree';                           Usage = 'cd...' }
        [PSCustomObject]@{ Command = 'cd....'; Description = 'Navigate three levels up the directory tree';                         Usage = 'cd....' }
        [PSCustomObject]@{ Command = 'note';   Description = 'Open Notepad';                                                        Usage = 'note [file]' }
        [PSCustomObject]@{ Command = 'li';     Description = 'List items in the current directory';                                 Usage = 'li' }
        [PSCustomObject]@{ Command = 'lf';     Description = 'List files in the current directory';                                 Usage = 'lf' }
        [PSCustomObject]@{ Command = 'ld';     Description = 'List directories in the current directory';                           Usage = 'ld' }
        [PSCustomObject]@{ Command = 'flf';    Description = 'List and open files using FZF';                                       Usage = 'flf' }
        [PSCustomObject]@{ Command = 'fld';    Description = 'List and open directories using FZF';                                 Usage = 'fld' }
    )

    $commands | Sort-Object Command | Format-Table -AutoSize
}
Set-Alias -Name helpme -Value Help-MyProfile
Set-Alias -Name aliases -Value Help-MyProfile