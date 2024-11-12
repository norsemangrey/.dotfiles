TODO: Move git-install script to separate repo.

This repo is for configuration files for my Windows development environment and the install script will create symlink paths to the applicable locations for various programs and modules.

Sensitive files located in cloud providers and linked from there. Only symlink path are located in repo folders for these files.

Paths to cloud directories are specified in the .env file and these variables can then be used in the paths files for the applicable software sensitive config files.

Run (as admin) with:

```
`Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/norsemangrey/.dotfiles/master/git-install.ps1')`
```

...this will install Git and clone the repo and run the script

With Git already installed:

```
git clone --recurse-submodules https://github.com/norsemangrey/.dotfiles.git
Set-Location ./.dotfiles
. ./install.ps1 -dryRun $true -debug $true
```

To update:
```
Set-Location $Env:USERPROFILE/.dotfiles
git pull
. ./install.ps1 -dryRun $true -debug $true
```

Creating symlinks manually:

CMD:
```mklink <target-path> <link-path>```

PowerShell:
```New-Item -ItemType SymbolicLink -Path <link-path> -Target <target-path>```
