# PowerShellScripts

## PowerShell Profile

This file provides a set of useful functions and customizations enabled for my PowerShell profile

## Test-PathIsParent

Takes a potential parent path and a potential child path and checks if the parent is a parent of the child. This script should work on any platform (regardless of directory separator), and with URLs as well as file paths.

The script does not attempt to resolve paths. Give it full path names only.

# UpdateRDPFiles

The UWP Remote Desktop app for Windows does not expose many of the options that people are used to for RDP. This script locates the .rdp files used by this tool and updates them with the required configurations.

The .rdp files this script modifies get over-written frequently, it is necessary to run this script frequently (at logon or screen unlock is a good option).

# Truncate-String

Truncates a string to a given length safely, returns the string if it is already shorter than the given length.
