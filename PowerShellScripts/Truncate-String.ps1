<#
.SYNOPSIS
    Truncates a string to a specified length.
.DESCRIPTION
    Truncates the given string to the given length, if the string is shorter than the length the full string is returned
.EXAMPLE
    Truncate-String.ps1 -Length 5 -String "Hello World"
    Returns "Hello"

    Truncate-String.ps1 -Length 5 -String "Hi"
    Returns "Hi"

    "Hello World" | Truncate-String.ps1 -Length 5
    Returns "Hello"
.PARAMETER Length
    The length to truncate the string to.
.PARAMETER Append
    The string to append to the truncated string if it was truncated.
.PARAMETER FromFront
    If set to true the string will be truncated from the front instead of the back.
.PARAMETER String
    The string to truncate.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true,Position=0)]
    [int]
    $Length,
    [Parameter(Position=1)]
    [string]
    $Append,
    [Parameter(Position=2)]
    [switch]
    $FromFront,
    [Parameter(Mandatory=$true,Position=3,ValueFromPipeline=$true)]
    [String]
    $String
)

begin {
}

process {
    if ($String.Length -gt $Length) {
        if ($FromFront) {
            Write-Output ($Append + $String.Substring($String.Length - $Length))
        }
        else {
            Write-Output ($String.Substring(0, $Length) + $Append)
        }
    }
    else {
        Write-Output $String
    }
}

end {
}