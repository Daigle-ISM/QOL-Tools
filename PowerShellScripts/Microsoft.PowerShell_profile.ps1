#region functions
Function Enable-PoshGit {
    <#
    .SYNOPSIS
        Loads the posh-git module, installs it if necessary
    .DESCRIPTION
        Loads the posh-git module a module for working with git. Installs it if necessary.

        Is unfortunately very slow
    .NOTES
        If the shell is not running as an admin, gsudo isn't installed, and posh-git isn't installed, posh-git will have to be installed as an administrator
    #>
    
    Write-Progress -Activity "Posh-Git" -Status "Configuring Posh-Git"
    if (Get-Module -ListAvailable posh-git) {
        Write-Progress -Activity "Posh-Git" -Status "Importing Module"
        Import-Module posh-git
    }
    # If running as an administrator
    elseif (([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")  {
        Write-Progress -Activity "Posh-Git" -Status "Installing Posh-Git"
        Write-Progress -Activity "Posh-Git" -Status "Setting PSGallery to trusted"
        Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
        Write-Progress -Activity "Posh-Git" -Status "Installing Nuget package provider"
        Install-PackageProvider -Name Nuget -Force
    }
    # Sudo is available to get admin perms
    elseif (Get-Command sudo -ErrorAction SilentlyContinue) {
        Write-Progress -Activity "Posh-Git" -Status "Installing Posh-Git with sudo"
        sudo 'Write-Progress -Activity "Posh-Git" -Status "Setting PSGallery to trusted"; Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted; Write-Progress -Activity "Posh-Git" -Status "Installing Nuget package provider"; Install-PackageProvider -Name Nuget -Force; Write-Progress -Activity "Posh-Git" -Status "Installing module"; Install-Module posh-git -Force'
    }
    # Everything else has failed
    else {
        throw "Unable to enable posh-git. Please run Install-Module posh-git as admin"
    }
    Write-Progress -Activity "Posh-Git" -Status "Importing Module"
    Import-Module posh-git
    Write-Progress -Activity "Posh-Git" -Completed
}
function Get-RandomString {
    <#
    .SYNOPSIS
        Generates a random string
    .DESCRIPTION
        Generates a random string using System.Security.Cryptography.RNGCryptoServiceProvider to ensure that it is cryptographically random
    .NOTES
        Character set is letters (upper and lower case) and numbers
        If using this to generate secrets or passwords use the -AsSecureString switch
    .PARAMETER Length
        The length of the string that is returned. By default a (pseudo) random length between 5 and 20 is chosen
    .PARAMETER AsSecureString
        Returns the string as a securestring instead of plain text
    .PARAMETER Characters
        Specifies named character sets that are used to build the output. AlphaNumeric is default
    .PARAMETER CharacterSet
        Specifies an explicit set of characters to use to generate the random string.
        This is cast as an array of characters, passing an array of integers will result in the characters that correspond to those integers, not the integers themselves. Please see the examples for more details
    .EXAMPLE
        Get-RandomString -Characters LowerLetters, Symbols
        :a?c<b?c:fylq{>gut=
        Any combination of the named charactersets can be used, separated by commas
    .EXAMPLE
        Get-RandomString -CharacterSet "ABCDEF"
        ADFAFDDFCAACE
        For custom charactersets, strings can be cast as character arrays just fine:
    .EXAMPLE
        Get-RandomString -CharacterSet "12345"
        2555411421545253
        Integers are where you have to be careful. In a string they are cast as the expected characters
    .EXAMPLE
        Get-RandomString -CharacterSet (1..5)
        ☺♣♦☻☻
        But passed as an integer or an array of integers (int[]) the integers refer to specific characters
    #>
    [CmdletBinding(DefaultParameterSetName="Named")]
    param (
        [Parameter(Position=1)]
        [ValidateScript({
            # OUT OF RANGE. Secure strings have a maximum length of 65536
            $_ -gt 1 -and $_ -le 1000000000 -and !($AsSecureString -and $_ -gt 65536)
        })]
        [int]
        $Length = (Get-Random -Minimum 5 -Maximum 20),
        [Parameter(Position=2)]
        [switch]
        $AsSecureString,
        [Parameter(ParameterSetName="Named")]
        # If I wasn't making this compatible with PowerShell 5 I would be using IValidateSetValuesGenerator, see more info here: https://adamtheautomator.com/powershell-validateset/
        # I'm instead doing everything the hard way, as per https://stackoverflow.com/a/74778399
        [ValidateScript({return [bool]([CharMap]::GetValidValues().Contains($_))})]
        [ArgumentCompleter({ 
            param($cmd, $param, $wordToComplete) 
            [CharMap]::GetValidValues() | Where-Object {$_.ToLower().StartsWith($WordToComplete.ToLower())}
        })]
        [string[]]
        $Characters = "AlphaNumeric",
        [Parameter(ParameterSetName="Explicit")]
        [char[]]
        $CharacterSet = @()
    )
    begin {
        # Give warnings for long strings
        if ($Length -gt 100000) {
            Write-Warning "Generating long strings will take a long time and be CPU intensive"
            if ($Length -gt 10000000) {
                Write-Warning "This is an excessive amount of data, you may run into memory limitations"
            }
        }
        # Provides a basic map of characters
        class CharMap {
            static $Numbers = (48..57)
            static $LowerLetters = (97..122)
            static $UpperLetters = (65..90)
            static $Symbols = (33..47) + (58..64) + (91..96) + (123..126)
            static $Letters = [CharMap]::LowerLetters + [CharMap]::UpperLetters
            static $AlphaNumeric = [CharMap]::Numbers + [CharMap]::Letters
            static $All = [CharMap]::AlphaNumeric + [CharMap]::Symbols

            static [String[]] GetValidValues() {
                return [CharMap] | Get-Member -Static | Where-Object MemberType -eq "Property" | Select-Object -ExpandProperty Name
            }
        }

        # Build the character map with named sets
        if ($PSCmdlet.ParameterSetName -eq "Named") {
            Write-Verbose "Using named character sets"
            foreach ($Type in $Characters) {
                Write-Verbose "Adding $Type to character set"
                $CharacterSet += [CharMap]::$Type
            }
        }

        # In case someone passes an empty array of characters
        if ($CharacterSet.Length -le 1) {
            Write-Warning "Not enough characters supplied; using AlphaNumeric set"
            $CharacterSet = [CharMap]::AlphaNumeric
        }
        
        # This is the array of bytes that will get randomized
        $Bytes = [Byte[]]::New($Length)
        
        # The securestring that will eventually be returned
        if ($AsSecureString){
            Write-Verbose "Creating secure string"
            $Output = [securestring]::New()
        }
        else {
            Write-Verbose "Creating plaintext string"
            $Output = [string]::New("")
        }

        # Create a crypto RNG provider
        # In my tests this thing is significantly faster than System.Random
        # Completely counter-intuitive to me, I suppose that's what dedicated crypto hardware can do
        $RNG = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    }
    # In the process block we randomize the bytes then use them to create the string
    process {
        #Randomize the bytes
        Write-Verbose "Generating random data"
        $RNG.GetBytes($Bytes) | Out-Null

        # Choose characters based on the bytes in the set
        Write-Verbose "Converting data to characters"
        # Believe it or not, this is where all the performance problems come from
        # Generating several megabytes of crypto-secure random numbers is nearly instant
        # Appending that data to an array is much slower
        # Appending that data to a string or securestring is a nightmare

        # SecureString has a limitation of uint16.MaxValue anyway, no optimization necessary
        if ($Output.GetType() -eq [securestring]) {
            foreach ($Byte in $Bytes) {
                $Output.AppendChar([char]($CharacterSet[$Byte%$CharacterSet.Length]))
            }
        }
        elseif ($Output.GetType() -eq [string]) {
            # Using a char array for performance. This is significantly faster than appending to a string
            $ca = [char[]]::new($Bytes.Count)
            for ($i = 0; $i -lt $Bytes.Count; $i++) {
                $ca[$i] = [char]($CharacterSet[$Bytes[$i]%$CharacterSet.Length])
            }
            Write-Verbose "Building string"
            # RIP our memory footprint
            $Output = [string]::new($ca)
            # We need to clean this up as soon as possible
            $ca.Clear()
        }
    }
    end {
        # Probably completely unnecessary disposal
        # But I don't want to find out that someone could find a seed 
        # or something like that from that object if it doesn't get disposed
        Write-Verbose "Disposing of objects"
        $RNG.Dispose()
        $Bytes.Clear()
        $CharacterSet.Clear()

        return $Output
    }
}

function Time {
    <#
    .SYNOPSIS
        Re-creates the basic functionality of the nix time command
    .NOTES
        This is just here so if you try to run time it runs as expected. If this isn't already a habit, see instead Measure-Command.
        
        Commands that include piping or other flow control methods may cause issues, simply wrap them in quotes.
    #>
    $ScriptBlock = [scriptblock]::Create(($args -Join " ") + " | Out-Default")
    Measure-Command $ScriptBlock
}
function Clean-Branches {
    <#
    .SYNOPSIS
        Deletes any local branches for which the remote has been deleted
    .DESCRIPTION
        Switches you to your main branch, runs a git pull, and deletes any local branches for which the remote has been deleted
    .NOTES
        Assumes it is being run in a git repository
        
        Assumes the remote is named 'origin'
    .PARAMETER Force
        Uses git branch -D to permanently delete branches whether or not git finds them to be fully merged

        This can result in the loss of data if you're not careful!
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [Switch]
        $Force
    )
    if ($Force) {
        $d = "-D"
    }
    else {
        $d = "-d"
    }
        $DefaultBranch = [System.Text.RegularExpressions.Regex]::Matches((git symbolic-ref refs/remotes/origin/HEAD), "[^/]+$").Value
        git checkout $DefaultBranch 2>&1
        git pull --prune 2>&1
        (git branch -vv 2>&1).Split("`n") -replace "^\* "| Where-Object {$_ -match '\[.*gone\]'} | Foreach-Object {git branch $d $_.Trim().Split(" ")[0] 2>&1}
    }
}
function rode {
    <#
    .SYNOPSIS
        Recursively opens all files in the current directory that match the given pattern
    .DESCRIPTION
        Recursive code, recursively searches the current directory for files matching the provided RegEx expressions and opens them in code. Useful for repos with deep folder hierarchies where you know the name of the script you want to edit.
    .NOTES
        Assumes 'code' for vscode is added to your PATH
    .EXAMPLE
        rode .*settings\.xml$
        Recursively opens any files ending with settings.xml
    #>
	foreach ($arg in $args) {
		code (Get-ChildItem -Recurse | Where-Object Name -match $arg | Select-Object -ExpandProperty Fullname)
	}
}
function helpmsg {
    <#
    .SYNOPSIS
        Looks up the net helpmsg error code for a given hex number
    .DESCRIPTION
        Treats the last four characters of a given string as a hexidecimal word, converts it to decimal, and runs net helpmsg on it.
    .EXAMPLE
        helpmsg 5
        Access is denied.
    .EXAMPLE
        helpmsg 0x80070005
        Access is denied.
    .EXAMPLE
        helpmsg 0x8007232A
        DNS server failure.
    .PARAMETER Hex
        A string representing the hex error code you were given
    .NOTES
        This converts hex to decimal. Don't use this with decimal errors, if you are entering the decimal error code directly and it has more than one digit you will get the wrong result. For example:
        
        > helpmsg 53

        Fail on INT 24.

        > net helpmsg 53

        The network path was not found.

        This is because 53 in hex is 83 in decimal. If you are looking for the helpmsg but already have the integer, use net helpmsg
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position=1,Mandatory=$true)]
        [string]
        $Hex
    )
    # Add leading 0's until the string is at least 4 characters long
    $Hex = $Hex.PadLeft(4,"0")

    # Strip anything before the last four characters and convert to an unsigned integer
    $Dec = [uint32]("0x" + $Hex.Substring($Hex.Length - 4, 4))

    # Get the helpmsg
    net helpmsg $Dec
}
function Tail {
    <#
    .SYNOPSIS
        Print the lines at the end of a file
    .DESCRIPTION
        Prints the last (default: 10) lines of a given file to the console host (using write-host). Similar to the Unix/Linux command tail

        This function provides the -Follow option, which is missing from Get-Content -Tail
    .NOTES
        This function may return the entire file if it is unable to identify any line endings. It looks for `n and `r

        When using -Follow and -OutputToPipeline together you must send the 'q' key to stop following, if you use CTRL+C you will receive no output
    .EXAMPLE
        tail C:\var\log\program.log
        Shows the last 10 lines of the program.log file
    .EXAMPLE
        tail C:\var\log\program.log -Follow
        Shows the last 10 lines of the program.log file, then monitors the file for changes and prints any new lines appended until q is pressed
    #>

    [CmdletBinding()]
    param (
        # The path of the file to tail
        [Parameter(Mandatory=$true,ParameterSetName="Path",Position=1)]
        [string]
        $Path,
        # The number of lines to read
        [Parameter(Position=2)]
        [int]
        $Lines = 10,
        # Output appended data as the file grows
        [Parameter()]
        [switch]
        $Follow,
        # Output to the pipeline instead of standard output (equivalent of write-output instead of write-host)
        [Parameter()]
        [switch]
        $OutputToPipeline
    )

    begin {
        # Get the file handle
        $File = Get-Item $Path -Force
        
        if ($Follow) {
            Write-Progress -Activity "Press q to exit" -Status "Following $File"
        }

        # Create the file stream
        $FS = [System.IO.FileStream]::new($File, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)

        # Create a stream reader
        $SR = [System.IO.StreamReader]::new($FS)

        # Set the current position to the end of the stream -1 so the ReadByte() can read the last byte
        $FS.Position = $FS.Length - 1

        $Prev = $false
        for ($i = 0; $i -lt $Lines;) {
            try {
                if ($FS.Position -eq 0) {# We are at the beginning of the file
                    break
                }
                # Move to the previous byte
                $FS.Position-=1
                # If the current character is a return character increment the counter
                $Char = $FS.ReadByte()
                # ReadByte() advances the position by a byte, move back to the current byte
                $FS.Position-=1
                if ($Char -eq 13 -and $Prev -eq $false) {
                    $i++
                }
                elseif ($Char -eq "`0") {
                    $i++
                }
                if ($Char -eq 10) {
                    $i++
                    $Prev = $true
                }
                else {
                    $Prev = $false
                }
            }
            catch {
                break
            }
        }
        # If it stopped on a linebreak (and not at the beginning of the file) do not read that break
        if ($SR.BaseStream.Position -ne 0) {
            $SR.BaseStream.Position+=1
        }
    }
    process {
        try {
            do {
                # Using ctrl+c to kill this loop means we can't get output to the pipeline, so we need another option
                if ([Console]::KeyAvailable)
                {
                    if ([Console]::ReadKey($true).KeyChar -eq "q") {
                        break
                    }
                }

                [string]$Lines = $SR.ReadToEnd()

                if ($OutputToPipeline) {
                    [string]$RetVal += $Lines
                }
                else {
                    Write-Host $Lines -NoNewline
                }

                # We need to sleep to avoid eating all the CPU cycles 
                if ($Follow) {
                    Start-Sleep -Milliseconds 200
                }
            }
            # Only actually loop if -Follow was specified
            while ($Follow)
        }
        finally {
            # Leaving these open means the file will be locked
            # This finally block will run even if there's an exception or if CTRL+C is used to close the loop
            # I would like to use a clean block instead of this, but it doesn't exist in .NET Framework PowerShell
            $SR.Dispose()
            $FS.Dispose()
        }
    }
    end {
        return $RetVal
    }
}

function Link-DotFiles {
    <#
    .SYNOPSIS
        Creates hardlinks to your dotfiles in the specified directory
    .DESCRIPTION
        Used for tracking your dotfiles in a git repository. This function will create hardlinks to your dotfiles in the specified directory, allowing you to track them in a git repository without having to move them out of or creating a repo in your home directory
    .NOTES
        Hardlinks are used so git tracks your files correctly. Git can only track files anyway.

        Edit the $ExcludedFiles variable to exclude files from being linked
    .EXAMPLE
        Link-Dotfiles C:\Users\Daigle-ISM\source\dotfiles\
        Creates hardlinks to your dotfiles in the specified directory
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,Position=1)]
        [System.IO.DirectoryInfo]
        $Destination
    )
    begin {
        $ExcludedFiles = @(
            ".lesshst"
            ".viminfo"
            ".directory"
            ".vscode-insiders"
        )
        # I thought I could just use Get-ChildItem -Path ~ -Filter ".*" -Exclude $ExcludedFiles
        # This doesn't work. It returns nothing, and I am convinced that is incorrect behaviour
        # So whatever, we're using RegEx. The only thing that works around here
        [array]$DotFiles = Get-ChildItem ~ -Exclude $ExcludedFiles | Where-Object Name -Match "^\."
    }
    
    process {
        foreach ($File in $DotFiles) {
            # You would think that you could do this together with the above Get-ChildItem
            # But after trying to figure out the filter syntax and all that nonsense
            # I realized I was better off doing this myself
            $Link = Join-Path $Destination.FullName $File.Name
            if ($File.PSIsContainer) {
                if (!(Test-Path $Link)) {
                    New-Item -ItemType Directory -Path $Link
                }

                foreach ($ChildFile in Get-ChildItem $File -Recurse -File)
                {
                    $ChildLink = Join-Path $Link $ChildFile.Name
                    if (!(Test-Path $ChildLink)) {
                        New-Item -ItemType HardLink -Path $ChildLink  -Target $ChildFile.FullName
                    }
                }
            }
            elseif (!(Test-Path $Link)) {
                    New-Item -ItemType HardLink -Path $Link -Target $File.FullName
            }
        }
    }
    
    end {
        
    }
}
#endregion

#region actions

# Attempts to install and enable the Posh-Git add-on
Enable-PoshGit 
# Diff is by default an alias for compare-item. However diff.exe from vim behaves differently, and is part of my PATH
# I remove this alias so I can choose what method I use to compare things
Remove-Item alias:diff -Force
# Less is much better than more. It lets you use j and k or the arrow keys to scroll up and down through content (which should sound familiar if you use vim)
# and you can use / and ? to search for RegEx patterns
# This of course won't work if your git install path is somewhere else
# I'm generally avoiding using the exes from this folder, but if you want a lot of POSIX-like functionality, you could add it to your PATH
New-Alias -Name Less -Value "C:\Program Files\Git\usr\bin\less.exe"
# Touch is a POSIX tool that I'm in the habit of using to create new, empty files. I don't care about updating timestamps on existing files, or I would use
# touch.exe from the above git folder
New-Alias -Name touch -Value New-Item
# Maps HKEY_USERS to hku:\
New-Psdrive -name hku -PSProvider Registry -Root HKEY_USERS | Out-Null
# Maps HKEY_CLASSES_ROOT to hkcr:\
New-Psdrive -name hkcr -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null
# Create hard links to dotfiles
Link-DotFiles -Destination "~\source\dotfiles\"
#endregion
