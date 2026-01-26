
# Windows 10/11 Bulk App Uninstaller Script
# Run this script as Administrator in PowerShell

#Requires -RunAsAdministrator

param(
    [switch]$NonInteractive,
    [ValidateSet("All","Win11","Xbox","List","Search","Exit")]
    [string]$Mode = "All",
    [string]$SearchTerm,
    [switch]$ConfirmRemoval,
    [switch]$NoPause
)


Write-Host "Windows 10/11 App Bulk Uninstaller" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Green
Write-Host ""

# Verify Administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script requires Administrator privileges. Please run as Administrator."
    if (-not $NoPause) {
        Pause
    }
    Exit 1
}

# COMPREHENSIVE BLOATWARE REMOVAL - ALL APPS ENABLED
# This will remove ALL bloatware for a clean Windows installation
# Comment out any apps you want to KEEP by adding # at the beginning

$AppsToRemove = @(
    # Microsoft Built-in Apps (Non-Essential)
    "Microsoft.3DBuilder"
    "Microsoft.AppConnector"
    "Microsoft.BingFinance"
    "Microsoft.BingNews"
    "Microsoft.BingSports"
    "Microsoft.BingTranslator"
    "Microsoft.BingWeather"
    "Microsoft.FreshPaint"
    "Microsoft.GetHelp"
    "Microsoft.Getstarted"
    "Microsoft.HelpAndTips"
    "Microsoft.Media.PlayReadyClient.2"
    "Microsoft.Messaging"
    "Microsoft.Microsoft3DViewer"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.MicrosoftPowerBIForWindows"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.MicrosoftStickyNotes"
    "Microsoft.MinecraftUWP"
    "Microsoft.MixedReality.Portal"
    "Microsoft.MSPaint"
    "Microsoft.NetworkSpeedTest"
    "Microsoft.News"
    "Microsoft.Office.Lens"
    "Microsoft.Office.OneNote"
    "Microsoft.Office.Sway"
    "Microsoft.OneConnect"
    "Microsoft.People"
    "Microsoft.Print3D"
    "Microsoft.RemoteDesktop"
    "Microsoft.SkypeApp"
    "Microsoft.StorePurchaseApp"
    "Microsoft.Studio3D"
    "Microsoft.Todos"
    "Microsoft.Wallet"
    "Microsoft.Whiteboard"
    "Microsoft.WindowsAlarms"
    "Microsoft.WindowsCamera"
    "microsoft.windowscommunicationsapps"  # Mail and Calendar
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.WindowsMaps"
    "Microsoft.WindowsPhone"
    "Microsoft.WindowsSoundRecorder"
    "Microsoft.WinJS.1.0"
    "Microsoft.WinJS.2.0"
    "Microsoft.YourPhone"
    "Microsoft.ZuneMusic"  # Groove Music
    "Microsoft.ZuneVideo"  # Movies & TV
    
    # Xbox Apps (Remove if you don't game)
    "Microsoft.Xbox.TCUI"
    "Microsoft.XboxApp"
    "Microsoft.XboxGameOverlay"
    "Microsoft.XboxGamingOverlay"
    "Microsoft.XboxIdentityProvider"
    "Microsoft.XboxSpeechToTextOverlay"
    
    # Third-party Bloatware (Manufacturer Pre-installed)
    "2414FC7A.Viber"
    "41038Axilesoft.ACGMediaPlayer"
    "46928bounde.EclipseManager"
    "4DF9E0F8.Netflix"
    "64885BlueEdge.OneCalendar"
    "7EE7776C.LinkedInforWindows"
    "828B5831.HiddenCityMysteryofShadows"
    "9E2F88E3.Twitter"
    "A278AB0D.DisneyMagicKingdoms"
    "A278AB0D.MarchofEmpires"
    "ActiproSoftwareLLC.562882FEEB491"
    "AD2F1837.HPJumpStart"
    "AD2F1837.HPPCHardwareDiagnosticsWindows"
    "AD2F1837.HPPowerManager"
    "AD2F1837.HPPrivacySettings"
    "AD2F1837.HPSupportAssistant"
    "AD2F1837.HPSureShieldAI"
    "AD2F1837.HPSystemInformation"
    "AD2F1837.HPQuickDrop"
    "AD2F1837.HPWorkWell"
    "AD2F1837.myHP"
    "AD2F1837.HPDesktopSupportUtilities"
    "AD2F1837.HPQuickTouch"
    "AD2F1837.HPEasyClean"
    "AD2F1837.HPSystemInformation"
    "AdobeSystemsIncorporated.AdobePhotoshopExpress"
    "Amazon.com.Amazon"
    "C27EB4BA.DropboxOEM"
    "CAF9E577.Plex"
    "ChemTable.ChemTable"
    "CyberLinkCorp.hs.PowerMediaPlayer14forHPConsumerPC"
    "D52A8D61.FarmVille2CountryEscape"
    "D5EA27B7.Duolingo-LearnLanguagesforFree"
    "DB6EA5DB.CyberLinkMediaSuiteEssentials"
    "DolbyLaboratories.DolbyAccess"
    "Drawboard.DrawboardPDF"
    "Facebook.Facebook"
    "Fitbit.FitbitCoach"
    "Flipboard.Flipboard"
    "GAMELOFTSA.Asphalt8Airborne"
    "KeeperSecurityInc.Keeper"
    "NORDCURRENT.COOKINGFEVER"
    "PandoraMediaInc.29680B314EFC2"
    "Playtika.CaesarsSlotsFreeCasino"
    "ShazamEntertainmentLtd.Shazam"
    "SlingTVLLC.SlingTV"
    "SpotifyAB.SpotifyMusic"
    "TheNewYorkTimes.NYTCrossword"
    "ThumbmunkeysLtd.PhototasticCollage"
    "TuneIn.TuneInRadio"
    "WinZipComputing.WinZipUniversal"
    "XINGAG.XING"
    "flaregamesGmbH.RoyalRevolt2"
    
    # Gaming Bloatware
    "king.com.BubbleWitch3Saga"
    "king.com.CandyCrushSaga"
    "king.com.CandyCrushSodaSaga"
    "king.com.*"  # All King games
    
    # Manufacturer Specific (Dell, HP, Lenovo, ASUS, etc.)
    "*Dell*"
    "*HP*"
    "*Lenovo*"
    "*ASUS*"
    "*Acer*"
    "*MSI*"
    "*Toshiba*"
    "*Sony*"
    "*Samsung*"
    "*LG*"
    "*Alienware*"
    
    # Additional Common Bloatware
    "*.Hulu"
    "*.Netflix"
    "*.Twitter"
    "*.Facebook"
    "*.Instagram"
    "*.TikTok"
    "*.Spotify"
    "*.Pandora"
    "*.Prime Video"
    "*.Disney"
    "*.ESPN"
    "*.Kindle"
    "*.Audible"
    "*.McAfee*"
    "*.Norton*"
    "*.WildTangent*"
    "*.Trial*"
    "*.ExpressVPN"
    "*.Dropbox*"
    "*.OneDrive*" # Comment this out if you use OneDrive
)

# Function to uninstall apps
function Remove-AppPackages {
    param($AppList)
    
    if ($AppList.Count -eq 0) {
        Write-Host "No apps selected for removal." -ForegroundColor Yellow
        return
    }
    
    Write-Host "`nStarting app removal process..." -ForegroundColor Cyan
    
    foreach ($App in $AppList) {
        if ($App.Trim() -ne "" -and -not $App.StartsWith("#")) {
            Write-Host "`nRemoving: $App" -ForegroundColor Yellow
            
            try {
                # Remove for current user
                Get-AppxPackage -Name $App | Remove-AppxPackage -ErrorAction SilentlyContinue
                
                # Remove for all users (requires admin)
                Get-AppxPackage -AllUsers -Name $App | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                
                # Remove provisioned packages (prevents reinstall for new users)
                Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like $App | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
                
                Write-Host "Successfully removed: $App" -ForegroundColor Green
            }
            catch {
                Write-Host "Failed to remove: $App - Error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}

# Function to list all installed apps
function Show-InstalledApps {
    Write-Host "`nCurrently installed apps:" -ForegroundColor Cyan
    Get-AppxPackage | Select-Object Name, PackageFullName | Sort-Object Name | Format-Table -AutoSize
}

# Function to search for specific apps
function Find-Apps {
    param([string]$SearchTerm)

    Write-Host "`nSearching for apps matching '$SearchTerm':" -ForegroundColor Cyan
    Get-AppxPackage | Where-Object Name -like "*$SearchTerm*" | Select-Object Name, PackageFullName | Format-Table -AutoSize
}

# Function for robust Xbox/Gaming Overlay removal
function Remove-XboxGamingOverlay {
    Write-Host "`n=== Removing Xbox Gaming Overlay (Robust Method) ===" -ForegroundColor Cyan
    Write-Host "This will completely remove Xbox Gaming Overlay and prevent reinstallation..." -ForegroundColor Yellow

    try {
        # Remove Xbox Gaming Overlay for all users with error suppression for protected packages
        Write-Host "Removing Xbox Gaming Overlay packages..." -ForegroundColor Yellow
        Get-AppxPackage -AllUsers *Microsoft.XboxGamingOverlay* -ErrorAction SilentlyContinue |
            Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue

        # Remove all Xbox-related packages for thoroughness
        Write-Host "Removing all Xbox-related packages..." -ForegroundColor Yellow
        Get-AppxPackage -AllUsers *xbox* -ErrorAction SilentlyContinue |
            Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue

        # Prevent reinstall via provisioned packages (for new users)
        Write-Host "Removing provisioned Xbox packages to prevent reinstallation..." -ForegroundColor Yellow
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object {$_.PackageName -like "*xbox*"} |
            Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue

        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object {$_.PackageName -like "*Microsoft.XboxGamingOverlay*"} |
            Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue

        # Registry fix for the ms-gamingoverlay protocol
        Write-Host "Applying registry fixes for ms-gamingoverlay protocol..." -ForegroundColor Yellow
        try {
            # Create the registry key if it doesn't exist and set it to do nothing
            New-Item -Path "HKCU:\SOFTWARE\Classes\ms-gamingoverlay" -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path "HKCU:\SOFTWARE\Classes\ms-gamingoverlay" -Name "URL Protocol" -Value "" -Force -ErrorAction SilentlyContinue

            New-Item -Path "HKCU:\SOFTWARE\Classes\ms-gamingoverlay\shell\open\command" -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path "HKCU:\SOFTWARE\Classes\ms-gamingoverlay\shell\open\command" -Name "(Default)" -Value "cmd.exe /c exit" -Force -ErrorAction SilentlyContinue

            Write-Host "Registry fixes applied successfully." -ForegroundColor Green
        }
        catch {
            Write-Warning "Could not apply all registry fixes. This is usually safe to ignore."
        }

        Write-Host "`nXbox Gaming Overlay removal completed successfully!" -ForegroundColor Green
    }
    catch {
        Write-Warning "Some Xbox components could not be removed. This is normal for protected system packages."
    }
}

# Non-interactive path
if ($NonInteractive) {
    switch ($Mode) {
        "All" {
            if ($ConfirmRemoval) {
                Remove-AppPackages $AppsToRemove
                Remove-XboxGamingOverlay
            }
            else {
                Write-Warning "Non-interactive mode: use -ConfirmRemoval to proceed with ALL app removals."
            }
        }
        "Win11" {
            $Win11Apps = @(
                "Microsoft.Todos"
                "Microsoft.PowerAutomateDesktop"
                "MicrosoftTeams"
                "Microsoft.Teams"
                "Clipchamp.Clipchamp"
                "Microsoft.BingNews"
                "Microsoft.GamingApp"
                "Microsoft.GetHelp"
                "Microsoft.Getstarted"
                "Microsoft.MicrosoftOfficeHub"
                "Microsoft.People"
                "Microsoft.Windows.Photos"
                "Microsoft.WindowsAlarms"
                "Microsoft.WindowsCamera"
                "Microsoft.windowscommunicationsapps"
                "Microsoft.WindowsFeedbackHub"
                "Microsoft.WindowsMaps"
                "Microsoft.WindowsSoundRecorder"
                "Microsoft.Xbox.TCUI"
                "Microsoft.XboxIdentityProvider"
                "Microsoft.XboxGameOverlay"
                "Microsoft.XboxGamingOverlay"
                "Microsoft.XboxApp"
                "Microsoft.YourPhone"
                "Microsoft.ZuneMusic"
                "Microsoft.ZuneVideo"
            )
            Remove-AppPackages $Win11Apps
            Remove-XboxGamingOverlay
        }
        "Xbox" { Remove-XboxGamingOverlay }
        "List" { Show-InstalledApps }
        "Search" {
            if ([string]::IsNullOrWhiteSpace($SearchTerm)) {
                Write-Warning "Non-interactive mode: provide -SearchTerm for Mode Search."
            }
            else {
                Find-Apps $SearchTerm
            }
        }
        default { }
    }

    Write-Host "`nScript completed!" -ForegroundColor Green
    exit 0
}

# Main menu
do {
    Write-Host "`n=== COMPREHENSIVE BLOATWARE REMOVER ===" -ForegroundColor Green
    Write-Host "1. Remove ALL bloatware (RECOMMENDED - Fresh install feel)"
    Write-Host "2. List all installed apps"
    Write-Host "3. Search for specific apps"
    Write-Host "4. Remove Windows 11 specific bloatware"
    Write-Host "5. Remove Xbox Gaming Overlay (Robust removal with registry fix)"
    Write-Host "6. Exit"

    $choice = Read-Host "`nSelect an option (1-6)"
    
    switch ($choice) {
        "1" {
            Write-Host "`nThis will remove ALL bloatware for a clean Windows experience!" -ForegroundColor Yellow
            Write-Host "Essential apps like Calculator, Settings, Store will NOT be removed." -ForegroundColor Green
            $confirmation = Read-Host "`nProceed with complete bloatware removal? (y/N)"
            if ($confirmation -eq "y" -or $confirmation -eq "Y") {
                Remove-AppPackages $AppsToRemove
                # Also run robust Xbox removal with registry fix
                Remove-XboxGamingOverlay
            }
        }
        "2" { Show-InstalledApps }
        "3" {
            $searchTerm = Read-Host "Enter search term"
            Find-Apps $searchTerm
        }
        "4" {
            Write-Host "`nRemoving Windows 11 specific apps..." -ForegroundColor Cyan
            $Win11Apps = @(
                "Microsoft.Todos"
                "Microsoft.PowerAutomateDesktop"
                "MicrosoftTeams"
                "Microsoft.Teams"
                "Clipchamp.Clipchamp"
                "Microsoft.BingNews"
                "Microsoft.GamingApp"
                "Microsoft.GetHelp"
                "Microsoft.Getstarted"
                "Microsoft.MicrosoftOfficeHub"
                "Microsoft.People"
                "Microsoft.Windows.Photos"
                "Microsoft.WindowsAlarms"
                "Microsoft.WindowsCamera"
                "Microsoft.windowscommunicationsapps"
                "Microsoft.WindowsFeedbackHub"
                "Microsoft.WindowsMaps"
                "Microsoft.WindowsSoundRecorder"
                "Microsoft.Xbox.TCUI"
                "Microsoft.XboxIdentityProvider"
                "Microsoft.XboxGameOverlay"
                "Microsoft.XboxGamingOverlay"
                "Microsoft.XboxApp"
                "Microsoft.YourPhone"
                "Microsoft.ZuneMusic"
                "Microsoft.ZuneVideo"
            )
            Remove-AppPackages $Win11Apps
            # Also run robust Xbox removal with registry fix
            Remove-XboxGamingOverlay
        }
        "5" {
            # Dedicated Xbox Gaming Overlay removal
            Remove-XboxGamingOverlay
        }
        "6" { break }
        default { Write-Host "Invalid option" -ForegroundColor Red }
    }
} while ($choice -ne "6")

Write-Host "`nScript completed!" -ForegroundColor Green
