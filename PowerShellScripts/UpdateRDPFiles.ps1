<#
.SYNOPSIS
    Adds custom configurations to the WPF Remote Desktop App
.DESCRIPTION
    The WPF Remote Desktop app for Windows does not expose many of the options that people are used to for RDP. This script locates the .rdp files used by this tool and updates them with the required configurations
.NOTES
    The .rdp files this script modifies get over-written frequently, it is necessary to run this script frequently (at logon or screen unlock is a good option)
#>

# Add any additional lines you want to this array
$Lines = @(
    "keyboardhook:i:0" # Windows shortcuts (any shortcut using the Windows key) get run locally instead of remotely
    )

# Find and get all the files
$Files = Get-ChildItem -Recurse (Join-Path $env:LOCALAPPDATA "rdclientwpf") -Filter "*.rdp"
foreach ($File in $Files) {
    # Read the file
    $Content = Get-Content $File.FullName -Encoding unicode
    # Check if each line is in the file, if it isn't add it to the end
    foreach ($Line in $Lines) {
        if (!($Content | Select-String $Line)) {
            Add-Content -Path $File.Fullname -Value $Line -Encoding unicode # The encoding is important. If you get gibberish or unexpected characters in your files check what encoding they're saved as and edit this accordingly
        }
    }
}