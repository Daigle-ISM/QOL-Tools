<#
.SYNOPSIS
    Checks if a path is a parent of another path.
.DESCRIPTION
    Takes a potential parent path and a potential child path and checks if the parent is a parent of the child.
.NOTES
    For best results use the full paths for the parent and child.

    Testing Windows paths on a non-windows system does work but the paths it ends up comparing are relative to your home folder which may cause unexpected behaviour.
    e.g.: C:\Test becomes /home/user/C:/Test.

    This does with with URLS, smb:// and https:// urls, for example.

    This function is case-insensitive on Windows by default, but is case-sensitive on other platforms
.EXAMPLE
    Test-PathIsParent -PotentialParent C:\Test -PotentialChild C:\Test\Child
    Returns True, as C:\Test is a parent of C:\Test\Child
.EXAMPLE
    Test-PathIsParent -PotentialParent C:\Test -PotentialChild C:\TestChild
    Returns False, as C:\Test is not a parent of C:\TestChild
.PARAMETER PotentialParent
    The potential parent directory. This must be a directory, or the script will always return $false.
.PARAMETER PotentialChild
    The potential child item. This can be a file or directory.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [System.IO.DirectoryInfo]$PotentialParent,
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [System.IO.DirectoryInfo]$PotentialChild,
    # Default to case insensitive on Windows. Non-core is only available on Windows, and doesn't have the $IsWindows variable
    [bool]
    $CaseSensitive = $PSEdition -eq 'Core' -and !($IsWindows)
)

begin {
    if (!($PotentialParent.Exists)) {
        Write-Warning "Parent path '$($PotentialParent.FullName)' is not a folder or does not exist."
    }
    Write-Debug "Directory Separator: $([System.IO.Path]::DirectorySeparatorChar)"
    Write-Verbose "Case Sensitive: $CaseSensitive"
}

process {
    Write-Verbose "Processing '$($PotentialChild.FullName)'"
    # Using TrimEnd instead of TrimEndingDirectorySeparator() because the latter will not trim from a root directory
    $ParentSegments = ($PotentialParent.FullName).TrimEnd([System.IO.Path]::DirectorySeparatorChar).Split([System.IO.Path]::DirectorySeparatorChar)
    Write-Debug ("ParentSegments:`n" + ($ParentSegments | Format-Table | Out-String))
    $ChildSegments = ($PotentialChild.FullName).TrimEnd([System.IO.Path]::DirectorySeparatorChar).Split([System.IO.Path]::DirectorySeparatorChar)
    Write-Debug ("ChildSegments:`n" + ($ChildSegments | Format-Table | Out-String))

    # If all the parent segments equal the corresponding child segments the path is a match
    for ($i = 0; $i -lt $ParentSegments.Count; $i++) {
        if ($CaseSensitive) {
            if ($ParentSegments[$i] -cne $ChildSegments[$i]) {
                return $false
            }
        }
        else {
            if ($ParentSegments[$i] -ine $ChildSegments[$i]) {
                return $false
            }
        }
    }
    return $true
}