NOTE: CURRENTLY NOT FUNCTIONING --- WORK IN PROGRESS

Run with:
`Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/norsemangrey/.dotfiles/master/git-install.ps1')`

Creating symlinks manually:

CMD:
mklink <target-path> <link-path>

PowerShell:
New-Item -ItemType SymbolicLink -Path <link-path> -Target <target-path>