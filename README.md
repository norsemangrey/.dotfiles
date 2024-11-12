TODO: Move git install script to separate repo.

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

Creating symlinks manually:

CMD:
```mklink <target-path> <link-path>```

PowerShell:
```New-Item -ItemType SymbolicLink -Path <link-path> -Target <target-path>```
