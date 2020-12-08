#### Dependencies ####
# 1. PowerShell
# 2. MEGAcmd: mega-whoami (.bat), mega-login (.bat), mega-df (.bat), mega-transfers (.bat),
#    mega-export (.bat), mega-put.

#################################################################
# Detect the OS and try to set the environment variables for MEGAcmd.
# This is a little workaround for PowerShell < 6, which still ships with Windows...
# Linux and macOS have PowerShell 6+ by default when installed from Microsoft's site
if ( ($PSVersionTable.PSVersion.Major -lt 6) -And !([string]::IsNullOrEmpty($env:OS)) -And ([string]::IsNullOrEmpty($IsWindows)) ) {
    $IsWindows = $True
}
if ($IsWindows) {
    $MEGApath = "$env:LOCALAPPDATA\MEGAcmd"
    $OS = "Windows"
    $PathVarSeparator = ";"
    $PathSeparator = "\"
}
elseif ($IsMacOS) {
    $MEGApath = "/Applications/MEGAcmd.app/Contents/MacOS"
    $OS = "macOS"
    $PathVarSeparator = ":"
    $PathSeparator = "/"
}
elseif ($isLinux) {
    $MEGApath = "/usr/bin"
    $OS = "Linux"
    $PathVarSeparator = ":"
    $PathSeparator = "/"
}
else {
    Write-Error "Unknown OS! Bailing..."
    Exit
}

#################################################################
# Check if MEGAcmd is already installed and in the PATH
# This gives access to the MEGAcmd executables and wrapper scripts.
$deps = "mega-whoami","mega-login","mega-df","mega-transfers","mega-export","mega-put","mega-logout"
foreach ($dep in $deps) {
    Write-Host -NoNewline "Checking for $dep..."
    if (Get-Command $dep -ErrorAction SilentlyContinue) { 
        Write-Host "found!"
    }
    else {
        Write-Host "not found! I'm going to try and fix this by setting PATH..."
        Write-Host "$OS detected! Assuming MEGAcmd lives under $MEGApath."
        Write-Host "Checking for MEGAcmd and setting paths. If this hangs, exit and retry." -ForegroundColor Yellow
        if (Test-Path $MEGApath) {
            $env:PATH += "$PathVarSeparator$MEGApath"
        }
        else {
            Write-Error "MEGAcmd doesn't seem to exist under $MEGApath! Please install" +
            "MEGAcmd and/or update this script accordingly."
            Exit
        }
    }
}

#Test to see if MEGAcmd is running and if not start it
$ProcessActive = Get-Process MEGAcmdServer -ErrorAction SilentlyContinue
if($null -eq $ProcessActive)
{
    Write-Host "If this hangs, close the script and restart" -ForegroundColor Magenta
    Write-host "MegaCMD is not running. Starting MegaCMD" -ForegroundColor Magenta
    #MEGAcmdShell
}
else
{
    Write-host "MegaCMD already running" -ForegroundColor  green
}
#################################################################
Write-Host "---------------------------------------------------------------------------" -ForegroundColor white
Write-Host "Welcome to the Mega account usage checker" -ForegroundColor Yellow
Write-Host "This script will tell you how if your acccount is close or out of space."


#This will prompt the user for the file path to the list of accounts then put the list into a variable.
$accountPrompt = Read-Host -Prompt "Please enter the path to the imput file. Make sure the format is USERNAME:PASSWORD"
$accountList = Get-Content $accountPrompt

#This will create a new file in the path and serve as the output file. It will override any file with the same name
New-Item -Name AccountSizeOutput.txt -ItemType File -Force

#This logs out any users that might already be logged in 
Write-Host "Loging out any users"
mega-logout.bat


Foreach($account in $accountList)
{
    #This will grab the current account in the list and break it into two variables one for the username and one for the password. It then logs the user into the account.
    $CurrentUserName = $account.Split(":",2)[0]
    $currentPassword = $account.Split(":",2)[1]
    mega-login $CurrentUserName $currentPassword -EA SilentlyContinue

    #This then gets the current size and then breaks it down into something useable.
    mega-du.bat -h 
    $RawcurrentAccountUsage = $GetAccountSize.split("                                                    ")
    $currentAccountUsage = $RawcurrentAccountUsage[194] + "GB"
    
    #This writes the output to the output file and displays it to the user
    $Output = "$CurrentUserName is using $currentAccountUsage"
    Add-Content -Path AccountSizeOutput.txt -Value $Output
    
    #This determines if the account is using 14 or more GB. If so it outputs it in black with a yellow background.
    if($RawcurrentAccountUsage[194] -ge 14)
    {
        Write-Host $Output -ForegroundColor black -BackgroundColor Yellow
    }
    else
    {
        Write-Host $Output
    }
 
    #This then logs the user out so the script can start over
    mega-logout.bat
}

#################################################################
#Ask for a user input before closing just in case there is an error that needs to be read before PowerShell closes
Read-Host -Prompt "Press Enter to exit"

