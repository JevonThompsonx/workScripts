# Windows 10 Bulk App Uninstaller Script
# Run this script as Administrator in PowerShell

Write-Host "Windows 10 App Bulk Uninstaller" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green

# Common Windows 10 apps that users often want to remove
# Uncomment the ones you want to uninstall by removing the # symbol

$AppsToRemove = @(
    # Social & Entertainment
    # "Microsoft.BingWeather"
    # "Microsoft.GetHelp"
    # "Microsoft.Getstarted"
    # "Microsoft.Messaging"
    # "Microsoft.Microsoft3DViewer"
    # "Microsoft.MicrosoftOfficeHub"
    # "Microsoft.MicrosoftSolitaireCollection"
    # "Microsoft.MicrosoftStickyNotes"
    # "Microsoft.MixedReality.Portal"
    # "Microsoft.MSPaint"
    # "Microsoft.Office.OneNote"
    # "Microsoft.People"
    # "Microsoft.Print3D"
    # "Microsoft.SkypeApp"
    # "Microsoft.Wallet"
    # "Microsoft.Windows.Photos"
    # "Microsoft.WindowsAlarms"
    # "Microsoft.WindowsCamera"
    # "microsoft.windowscommunicationsapps"  # Mail and Calendar
    # "Microsoft.WindowsFeedbackHub"
    # "Microsoft.WindowsMaps"
    # "Microsoft.WindowsSoundRecorder"
    # "Microsoft.Xbox.TCUI"
    # "Microsoft.XboxApp"
    # "Microsoft.XboxGameOverlay"
    # "Microsoft.XboxGamingOverlay"
    # "Microsoft.XboxIdentityProvider"
    # "Microsoft.XboxSpeechToTextOverlay"
    # "Microsoft.YourPhone"
    # "Microsoft.ZuneMusic"  # Groove Music
    # "Microsoft.ZuneVideo"  # Movies & TV
    
    # Third-party bloatware (commonly pre-installed)
    # "2414FC7A.Viber"
    # "41038Axilesoft.ACGMediaPlayer"
    # "46928bounde.EclipseManager"
    # "4DF9E0F8.Netflix"
    # "64885BlueEdge.OneCalendar"
    # "7EE7776C.LinkedInforWindows"
    # "828B5831.HiddenCityMysteryofShadows"
    # "9E2F88E3.Twitter"
    # "A278AB0D.DisneyMagicKingdoms"
    # "A278AB0D.MarchofEmpires"
    # "ActiproSoftwareLLC.562882FEEB491"
    # "CAF9E577.Plex"
    # "CyberLinkCorp.hs.PowerMediaPlayer14forHPConsumerPC"
    # "D52A8D61.FarmVille2CountryEscape"
    # "D5EA27B7.Duolingo-LearnLanguagesforFree"
    # "DB6EA5DB.CyberLinkMediaSuiteEssentials"
    # "DolbyLaboratories.DolbyAccess"
    # "Drawboard.DrawboardPDF"
    # "Facebook.Facebook"
    # "Fitbit.FitbitCoach"
    # "Flipboard.Flipboard"
    # "GAMELOFTSA.Asphalt8Airborne"
    # "KeeperSecurityInc.Keeper"
    # "NORDCURRENT.COOKINGFEVER"
    # "PandoraMediaInc.29680B314EFC2"
    # "Playtika.CaesarsSlotsFreeCasino"
    # "ShazamEntertainmentLtd.Shazam"
    # "SlingTVLLC.SlingTV"
    # "SpotifyAB.SpotifyMusic"
    # "TheNewYorkTimes.NYTCrossword"
    # "ThumbmunkeysLtd.PhototasticCollage"
    # "TuneIn.TuneInRadio"
    # "WinZipComputing.WinZipUniversal"
    # "XINGAG.XING"
    # "flaregamesGmbH.RoyalRevolt2"
    # "king.com.*"  # King games (Candy Crush, etc.)
    # "Minecraft"  # Note: This might remove legitimate Minecraft
)

# Function to uninstall apps
function Remove-AppPackages {
    param($AppList)
    
    if ($AppList.Count -eq 0) {
        Write-Host "No apps selected for removal. Edit the script to uncomment apps you want to remove." -ForegroundColor Yellow
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

# Main menu
do {
    Write-Host "`n=== MENU ===" -ForegroundColor Green
    Write-Host "1. Remove selected apps (edit script first)"
    Write-Host "2. List all installed apps"
    Write-Host "3. Search for specific apps"
    Write-Host "4. Exit"
    
    $choice = Read-Host "`nSelect an option (1-4)"
    
    switch ($choice) {
        "1" { 
            $confirmation = Read-Host "`nAre you sure you want to remove the selected apps? (y/N)"
            if ($confirmation -eq "y" -or $confirmation -eq "Y") {
                Remove-AppPackages $AppsToRemove
            }
        }
        "2" { Show-InstalledApps }
        "3" { 
            $searchTerm = Read-Host "Enter search term"
            Find-Apps $searchTerm
        }
        "4" { break }
        default { Write-Host "Invalid option" -ForegroundColor Red }
    }
} while ($choice -ne "4")

Write-Host "`nScript completed!" -ForegroundColor Green