<#
.SYNOPSIS
    Checks if a path is a parent of another path.
.DESCRIPTION
    Takes a potential parent path and a potential child path and checks if the parent is a parent of the child.
.NOTES
    For best results use the full paths for the parent and child.

    This function is case-insensitive on Windows by default, but is case-sensitive on other platforms
.EXAMPLE
    Test-MyTestFunction -Verbose
    Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
.PARAMETER PotentialParent
    The potential parent directory. This must be a directory. Ideally the full path should be provided.
.PARAMETER PotentialChild
    The potential child item. This can be a file or directory. Ideally the full path should be provided.
.PARAMETER DirectorySeparatorChar
    The directory separator character to use. If not specified, the function will attempt to determine the correct character to use based on the childpath.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [System.IO.DirectoryInfo]$PotentialParent,
    [Parameter(Mandatory = $true)]
    [System.IO.DirectoryInfo]$PotentialChild,
    [char]
    $DirectorySeparatorChar = 0,
    [bool]
    # Default to case insensitive on Windows. Non-core is only available on Windows, and doesn't have the $IsWindows variable
    $CaseSensitive = $PSEdition -eq 'Core' -and !($IsWindows)
)
# If the character has not been provided, chooses the alternate directory character only if it is found in the child path, but the primary directory character is not
if ($DirectorySeparatorChar -eq 0) {
    if (-not $PotentialParent.FullName.Contains([System.IO.Path]::DirectorySeparatorChar) -and $PotentialChild.FullName.Contains([System.IO.Path]::AltDirectorySeparatorChar)) {
        $DirectorySeparatorChar = [System.IO.Path]::AltDirectorySeparatorChar;
    }
    else {
        $DirectorySeparatorChar = [System.IO.Path]::DirectorySeparatorChar;
    }
}
$ParentSegments = $PotentialParent.FullName.Split($DirectorySeparatorChar)
$ChildSegments = $PotentialChild.FullName.Split($DirectorySeparatorChar)
# If all the parent segments equal the child segments, the path is a match
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