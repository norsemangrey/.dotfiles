fastfetch

## Final Line to set prompt
oh-my-posh init pwsh --config $Env:USERPROFILE'\AppData\Local\Programs\oh-my-posh\themes\posh-custom-theme.omp.json' | Invoke-Expression
# Enable Posh-Git auto-completion
#$env:POSH_GIT_ENABLED = $true

function simple {
    $Env:POSH_FULL_PROMPT="0"
    echo "Enabling simple prompt..."
}

function full {
    $Env:POSH_FULL_PROMPT="1"
    echo "Enabling full prompt..."
}

# Set simple prompt at startup
simple

function Set-EnvVar {
    $env:POSH_LIGHT_THEME=$(Get-ItemPropertyValue -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize -Name AppsUseLightTheme)
}
New-Alias -Name 'Set-PoshContext' -Value 'Set-EnvVar' -Scope Global -Force