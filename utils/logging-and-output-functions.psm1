# Logger.psm1

# Initialize the log file path based on the calling script's path
$Script:parentPath = ( $MyInvocation.PSScriptRoot )

# Helper function to log/write messages
function Write-Message {
    param (
        [string]$Message,
        [string]$Type = 'INFO'
    )

    # Initialize values
    $timestamp = $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    $label = $Type.ToUpper()

    # Calculate padding based on the longest label
    $maxLabelLength = 7
    $paddingLength  = $maxLabelLength - $label.Length

    if ( $paddingLength -lt 0 ) { $padding = '' } else { $padding = (' ' * $paddingLength) }

    # Construct the formatted message with padding after the label
    $formattedMessage = "[$timestamp] [$label] $padding $Message"

    # Set color based on the type and output message
    switch ($label) {

        'INFO' {
            Write-Host $formattedMessage -ForegroundColor Green
        }
        'ERROR' {
            Write-Host $formattedMessage -ForegroundColor Red
        }
        'WARNING' {
            Write-Host $formattedMessage -ForegroundColor Yellow
        }
        'DEBUG' {
            if ( $debug ) { Write-Host $formattedMessage -ForegroundColor Cyan }
        }
        default {
            Write-Host $formattedMessage -ForegroundColor White
        }

    }

    # Path to the log file
    if ( $parentPath ) { $logFilePath = (Join-Path $parentPath "log.txt") } else { $logFilePath = (Join-Path $PSScriptRoot "log.txt") }

    # Append the formatted message to the log file
    $formattedMessage | Out-File -FilePath $logFilePath -Append

}

# Export the function
Export-ModuleMember -Function Write-Message