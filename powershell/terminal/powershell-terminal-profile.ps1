### As a reminder, to enable unsigned script execution of local scripts on client Windows,
### you need to run this line (or similar) from an elevated PowerShell prompt:
###   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned

# Prerequesites
#
# Scoop
# iwr -useb get.scoop.sh | iex
# Fzf
#

### Import Modules

# Improved command line editing experience for PowerShell
Import-Module -Name PSReadLine

# Command line auto-completion plugin for PSReadLine
Import-Module -Name CompletionPredictor

# Command line 'fuzzy' finder using FZF for PowerShell
Import-Module -Name PSFzf

# Show file and folder icons in the terminal
Import-Module -Name Terminal-Icons

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


New-Alias -Scope Global -Name fe -Value Invoke-FuzzyEdit -ErrorAction Ignore


# Find out if the current user identity is elevated (has admin rights)
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal $identity
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# If so and the current host is a command line, then change to red color
# as warning to user that they are operating in an elevated context



# Useful shortcuts for traversing directories
function cd... { Set-Location ..\.. }
function cd.... { Set-Location ..\..\.. }

# Quick shortcut to start notepad
function note { notepad $args }


### Custom Commands

# Lists functions in this profile
Function Get-MyCommands {
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
Set-Alias -Name iscmd -Value Get-MyCommands


# Finds items in the current directory and subdirectories containing the input string
function Find-Items {
    if ($args.Count -gt 0) {
        Get-ChildItem -Recurse -Include "*${args}*" | Foreach-Object FullName
    } else {
        Get-ChildItem -Recurse | Foreach-Object FullName
    }
}

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

# Set UNIX-like aliases for the admin command, so sudo <command> will run the command
# with elevated rights.
Set-Alias -Name su -Value Start-Elevated
Set-Alias -Name sudo -Value Start-Elevated
Set-Alias -Name admin -Value Start-Elevated

# We don't need these any more; they were just temporary variables to get to $isAdmin.
# Delete them to prevent cluttering up the user profile.
Remove-Variable identity
Remove-Variable principal

# Shortcut for listing files
function la { Get-ChildItem -Path $pwd }
function lf { Get-ChildItem -Path $pwd -File }
function ld { Get-ChildItem -Path $pwd -Directory }

function flf { Get-ChildItem -Path $pwd -File | Invoke-Fzf | % { code $_ } }
function fld { Get-ChildItem -Path $pwd -Directory | Invoke-Fzf | Set-Location }


function Get-PubIP {
    (Invoke-WebRequest http://ifconfig.me/ip ).Content
}


# Reload a the PS profile
function reload-profile {
    & $profile
}



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


# Creates drive shortcut for Work Folders, if current user account is using it
if (Test-Path "$env:USERPROFILE\Work Folders") {

    New-PSDrive -Name Work -PSProvider FileSystem -Root "$env:USERPROFILE\Work Folders" -Description "Work Folders"

    function Work: { Set-Location Work: }

}

Set-Alias -Name clr -Value clear