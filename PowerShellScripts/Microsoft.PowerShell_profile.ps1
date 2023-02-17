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
        Any combination of the named charactersets can be used, separated by commas:
        Get-RandomString -Characters LowerLetters, Symbols
        :a?c<b?c:fylq{>gut=

        For custom charactersets, strings can be cast as character arrays just fine:
        Get-RandomString -CharacterSet "ABCDEF"
        ADFAFDDFCAACE

        Integers are where you have to be careful. In a string they are cast as the expected characters:
        Get-RandomString -CharacterSet "12345"
        2555411421545253

        But passed as an integer or an array of integers (int[]) the integers refer to specific characters:
        Get-RandomString -CharacterSet (1..5)
        ☺♣♦☻☻
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
        [ValidateSet("Numbers","LowerLetters","UpperLetters","Letters","AlphaNumeric","Symbols","All")]
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
            $Numbers = (48..57)
            $LowerLetters = (97..122)
            $UpperLetters = (65..90)
            $Symbols = (33..47) + (58..64) + (91..96) + (123..126)
            $Letters = $this.LowerLetters + $this.UpperLetters
            $AlphaNumeric = $this.Numbers + $this.Letters
            $All = $this.AlphaNumeric + $this.Symbols
        }
        Write-Verbose "Building character map"
        $CharMap = New-Object CharMap

        # Build the character map with named sets
        if ($PSCmdlet.ParameterSetName -eq "Named") {
            Write-Verbose "Using named character sets"
            foreach ($Type in $Characters) {
                Write-Verbose "Adding $Type to character set"
                $CharacterSet += $CharMap.$Type
            }
        }

        # In case someone passes an empty array of characters
        if ($CharacterSet.Length -le 1) {
            Write-Warning "Not enough characters supplied; using AlphaNumeric set"
            $CharacterSet = $CharMap.AlphaNumeric
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

# Re-creates the basic functionality of the nix time command
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

# Removes orphaned branches, does not affect branches that never had remotes
function Clean-Branches {
    <#
    .SYNOPSIS
    Deletes any local branches for which the remote has been deleted
    .DESCRIPTION
    Switches you to your main branch (master or main)
    .NOTES
    Assumes it is being run in a git repository

    Assumes that your default branch is either master or main. If you have non-default branches with these names it may check out the wrong branch

    Uses git branch -d, not git branch -D. If a branch is not fully merged, you will receive a warning
    #>
    git fetch --prune
    git checkout ((git branch -vv).Split("`n") -replace "^\* " | Foreach-Object {$_.Trim().Split(" ")[0]} | Where-Object {$_ -eq "main" -or $_ -eq "master"})
    git pull
    (git branch -vv).Split("`n") -replace "^\* "| Where-Object {$_ -match '\[.*gone\]'} | Foreach-Object {git branch -d $_.Trim().Split(" ")[0]}
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

#endregion