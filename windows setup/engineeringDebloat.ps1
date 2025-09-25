# Complete Engineering Software Uninstaller
# Run this script as Administrator in PowerShell
# This script performs DEEP removal including registry, temp files, and services

Write-Host "Engineering Software Complete Removal Tool" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "WARNING: This will COMPLETELY remove engineering software and all data!" -ForegroundColor Red
Write-Host "Make sure to backup any important project files first!" -ForegroundColor Yellow

# Engineering software to remove - ALL VERSIONS INCLUDED
$EngineeringSoftware = @{
    "Autodesk" = @(
        # AutoCAD (All Versions)
        "AutoCAD*"
        "Autodesk AutoCAD*"
        "AutoCAD 2024"
        "AutoCAD 2023"
        "AutoCAD 2022"
        "AutoCAD 2021"
        "AutoCAD 2020"
        "AutoCAD 2019"
        "AutoCAD 2018"
        "AutoCAD 2017"
        "AutoCAD 2016"
        "AutoCAD 2015"
        "AutoCAD 2014"
        "AutoCAD LT*"
        "AutoCAD Architecture*"
        "AutoCAD Electrical*"
        "AutoCAD Mechanical*"
        "AutoCAD MEP*"
        "AutoCAD Plant 3D*"
        "AutoCAD Civil 3D*"
        
        # Civil 3D (All Versions)
        "Autodesk Civil 3D*"
        "Civil 3D 2024"
        "Civil 3D 2023"
        "Civil 3D 2022"
        "Civil 3D 2021"
        "Civil 3D 2020"
        "Civil 3D 2019"
        "Civil 3D 2018"
        "Civil 3D 2017"
        
        # Other Autodesk Products
        "Autodesk 3ds Max*"
        "Autodesk Maya*"
        "Autodesk Inventor*"
        "Autodesk Revit*"
        "Autodesk Fusion 360*"
        "Autodesk Navisworks*"
        "Autodesk Vault*"
        "Autodesk Robot Structural Analysis*"
        "Autodesk Infraworks*"
        "Autodesk Advance Steel*"
        "Autodesk Alias*"
        "Autodesk VRED*"
        "Autodesk Moldflow*"
        "Autodesk PowerMill*"
        "Autodesk FeatureCAM*"
        "Autodesk HSMWorks*"
        "Autodesk Mudbox*"
        "Autodesk MotionBuilder*"
        "Autodesk Smoke*"
        "Autodesk Flame*"
        
        # Autodesk Supporting Software
        "Autodesk Desktop App*"
        "Autodesk Application Manager*"
        "Autodesk Content Service*"
        "Autodesk Material Library*"
        "Autodesk Shared*"
        "Autodesk DirectConnect*"
        "Autodesk ReCap*"
        "Autodesk A360*"
        "Autodesk Communication Center*"
        "Autodesk Network License Manager*"
        "Autodesk Backburner*"
        "Autodesk FBX*"
        "Autodesk DWF Viewer*"
        "Autodesk Design Review*"
        "Autodesk True View*"
    )
    
    "Vectorworks" = @(
        # Vectorworks (All Versions)
        "Vectorworks*"
        "Vectorworks 2024"
        "Vectorworks 2023"
        "Vectorworks 2022"
        "Vectorworks 2021"
        "Vectorworks 2020"
        "Vectorworks 2019"
        "Vectorworks 2018"
        "Vectorworks 2017"
        "Vectorworks Architect*"
        "Vectorworks Landmark*"
        "Vectorworks Spotlight*"
        "Vectorworks Designer*"
        "Vectorworks Fundamentals*"
        "Vectorworks Viewer*"
        "Vectorworks Cloud Services*"
        "Nemetschek Vectorworks*"
    )
    
    "Bluebeam" = @(
        # Bluebeam Revu (All Versions)
        "Bluebeam*"
        "Bluebeam Revu*"
        "Bluebeam Revu eXtreme*"
        "Bluebeam Revu CAD*"
        "Bluebeam Revu Standard*"
        "Bluebeam Revu 21*"
        "Bluebeam Revu 20*"
        "Bluebeam Revu 2019*"
        "Bluebeam Revu 2018*"
        "Bluebeam Revu 2017*"
        "Bluebeam Revu 17*"
        "Bluebeam Revu 16*"
        "Bluebeam PDF Revu*"
        "Bluebeam Administrator*"
        "Bluebeam Gateway*"
        "Bluebeam Studio*"
    )
    
    "HydroCad" = @(
        # HydroCad (All Versions)
        "HydroCAD*"
        "HydroCad*"
        "HydroCAD Stormwater*"
        "HydroCAD"
        "Applied Microcomputer Systems*"
    )
    
    "BentleyMicrostation" = @(
        # Bentley MicroStation and Related
        "MicroStation*"
        "Bentley MicroStation*"
        "Bentley View*"
        "Bentley Navigator*"
        "Bentley PowerDraft*"
        "Bentley AECOsim*"
        "Bentley OpenRoads*"
        "Bentley OpenRail*"
        "Bentley OpenBuildings*"
        "Bentley OpenPlant*"
        "Bentley STAAD*"
        "Bentley RAM*"
        "Bentley MAXSURF*"
        "Bentley MOSES*"
        "Bentley AutoPIPE*"
        "Bentley CivilStorm*"
        "Bentley SewerGEMS*"
        "Bentley WaterGEMS*"
        "Bentley HAMMER*"
        "Bentley PondPack*"
        "Bentley CulvertMaster*"
        "Bentley FlowMaster*"
        "Bentley LumenRT*"
        "Bentley Pointools*"
        "Bentley ProjectWise*"
        "Bentley AssetWise*"
        "Bentley ContextCapture*"
    )
    
    "SolidWorks" = @(
        # SolidWorks (All Versions)
        "SolidWorks*"
        "SOLIDWORKS*"
        "SolidWorks 2024*"
        "SolidWorks 2023*"
        "SolidWorks 2022*"
        "SolidWorks 2021*"
        "SolidWorks 2020*"
        "SolidWorks 2019*"
        "SolidWorks 2018*"
        "SolidWorks Premium*"
        "SolidWorks Professional*"
        "SolidWorks Standard*"
        "SolidWorks Simulation*"
        "SolidWorks Flow Simulation*"
        "SolidWorks Plastics*"
        "SolidWorks Electrical*"
        "SolidWorks PDM*"
        "SolidWorks Composer*"
        "SolidWorks Visualize*"
        "SolidWorks CAM*"
        "SolidWorks Inspection*"
        "SolidWorks MBD*"
        "eDrawings*"
        "3DEXPERIENCE*"
    )
    
    "SketchUp" = @(
        # SketchUp (All Versions)
        "SketchUp*"
        "Google SketchUp*"
        "Trimble SketchUp*"
        "SketchUp Pro*"
        "SketchUp Make*"
        "SketchUp Viewer*"
        "LayOut*"
        "Style Builder*"
    )
    
    "Rhino" = @(
        # Rhino 3D
        "Rhino*"
        "Rhinoceros*"
        "Rhino 7*"
        "Rhino 6*"
        "Rhino 5*"
        "Grasshopper*"
        "RhinoCAM*"
        "Brazil for Rhino*"
        "Flamingo*"
        "Penguin*"
        "Bongo*"
    )
    
    "ANSYS" = @(
        # ANSYS Suite
        "ANSYS*"
        "Ansys*"
        "ANSYS Workbench*"
        "ANSYS Fluent*"
        "ANSYS CFX*"
        "ANSYS Mechanical*"
        "ANSYS Electronics*"
        "ANSYS HFSS*"
        "ANSYS Maxwell*"
        "ANSYS Icepak*"
        "ANSYS LS-DYNA*"
        "ANSYS Discovery*"
        "ANSYS SpaceClaim*"
        "ANSYS DesignModeler*"
    )
    
    "MATLAB" = @(
        # MATLAB and Simulink
        "MATLAB*"
        "Simulink*"
        "MathWorks*"
    )
    
    "ArcGIS" = @(
        # ESRI ArcGIS Suite
        "ArcGIS*"
        "ArcMap*"
        "ArcCatalog*"
        "ArcScene*"
        "ArcGlobe*"
        "ArcGIS Pro*"
        "ArcGIS Desktop*"
        "ArcReader*"
        "ArcGIS Explorer*"
        "ESRI*"
    )
    
    "ETABS_SAP" = @(
        # Structural Analysis Software
        "ETABS*"
        "SAP2000*"
        "CSiBridge*"
        "SAFE*"
        "Perform-3D*"
        "Computers and Structures*"
    )
    
    "Tekla" = @(
        # Tekla Structures
        "Tekla*"
        "Tekla Structures*"
        "Tekla Warehouse*"
        "Tekla Model Sharing*"
        "Tekla BIMsight*"
    )
    
    "MathCAD" = @(
        # PTC Mathcad
        "Mathcad*"
        "MathCAD*"
        "PTC Mathcad*"
        "Mathcad Prime*"
    )
    
    "Additional" = @(
        # Additional Engineering Software
        "RISA*"
        "Robot Structural Analysis*"
        "Prokon*"
        "ADAPT*"
        "Limcon*"
        "RAM Connection*"
        "RAM Elements*"
        "ProtaStructure*"
        "Advance Design*"
        "SCIA Engineer*"
        "Dlubal RFEM*"
        "Dlubal RSTAB*"
        "CSC Fastrak*"
        "Oasys*"
        "LUSAS*"
        "MSC*"
        "Nastran*"
        "Patran*"
        "Adams*"
        "HyperWorks*"
        "Altair*"
        "FARO*"
        "Leica*"
        "Topcon*"
        "Trimble*"
        "Carlson*"
        "Eagle Point*"
        "InRoads*"
        "GEOPAK*"
        "Land Desktop*"
        "Survey*"
        "12d Model*"
        "Microsurvey*"
        "TBC*"
        "Business Center*"
        "Terramodel*"
        "Surfer*"
        "Global Mapper*"
        "Quick Terrain*"
        "Virtual Surveyor*"
        "Pix4D*"
        "Agisoft*"
        "ContextCapture*"
        "PhotoScan*"
        "Metashape*"
        "DroneDeploy*"
        "Recap*"
        "CloudCompare*"
        "MeshLab*"
        "Pointfuse*"
        "ClearEdge3D*"
        "FARO Scene*"
        "Leica Cyclone*"
        "Riegl RiSCAN*"
        "Topcon ScanMaster*"
        "Trimble RealWorks*"
    )
}

# Function to stop related services
function Stop-EngineeringServices {
    Write-Host "`nStopping engineering software services..." -ForegroundColor Cyan
    
    $ServicesToStop = @(
        "*Autodesk*"
        "*Vectorworks*"
        "*Bluebeam*"
        "*Bentley*"
        "*SolidWorks*"
        "*ANSYS*"
        "*FlexNet*"
        "*FLEXlm*"
        "*Sentinel*"
        "*SafeNet*"
        "*CodeMeter*"
        "*WIBU*"
        "*RLM*"
        "*Reprise*"
        "*MathWorks*"
        "*ESRI*"
        "*Tekla*"
        "*RISA*"
        "*SCIA*"
        "*Dlubal*"
    )
    
    foreach ($ServicePattern in $ServicesToStop) {
        try {
            Get-Service | Where-Object {$_.Name -like $ServicePattern -or $_.DisplayName -like $ServicePattern} | 
            ForEach-Object {
                Write-Host "Stopping service: $($_.DisplayName)" -ForegroundColor Yellow
                Stop-Service $_.Name -Force -ErrorAction SilentlyContinue
                Set-Service $_.Name -StartupType Disabled -ErrorAction SilentlyContinue
            }
        }
        catch {
            Write-Host "Could not stop service $ServicePattern" -ForegroundColor Red
        }
    }
}

# Function to remove software using Windows Installer
function Remove-EngineeringSoftware {
    param($SoftwareCategories)
    
    Write-Host "`nRemoving engineering software..." -ForegroundColor Cyan
    
    foreach ($Category in $SoftwareCategories.Keys) {
        Write-Host "`nProcessing $Category software..." -ForegroundColor Yellow
        
        foreach ($SoftwareName in $SoftwareCategories[$Category]) {
            try {
                # Remove via WMI (Windows Management Instrumentation)
                $Products = Get-WmiObject -Class Win32_Product | Where-Object {$_.Name -like $SoftwareName}
                foreach ($Product in $Products) {
                    Write-Host "Uninstalling: $($Product.Name)" -ForegroundColor Green
                    $Product.Uninstall() | Out-Null
                }
                
                # Remove via Registry (Uninstall strings)
                $UninstallKeys = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" |
                    Get-ItemProperty | Where-Object {$_.DisplayName -like $SoftwareName}
                
                foreach ($Key in $UninstallKeys) {
                    if ($Key.UninstallString) {
                        Write-Host "Removing: $($Key.DisplayName)" -ForegroundColor Green
                        try {
                            if ($Key.UninstallString -match "msiexec") {
                                $GUID = ($Key.UninstallString -split "/I")[1] -replace "[{}]", ""
                                Start-Process "msiexec.exe" -ArgumentList "/X$GUID /quiet /norestart" -Wait -NoNewWindow
                            } else {
                                $UninstallCmd = $Key.UninstallString -replace '"', ''
                                Start-Process $UninstallCmd -ArgumentList "/S /quiet" -Wait -NoNewWindow -ErrorAction SilentlyContinue
                            }
                        }
                        catch {
                            Write-Host "Manual uninstall required for: $($Key.DisplayName)" -ForegroundColor Red
                        }
                    }
                }
            }
            catch {
                Write-Host "Could not remove $SoftwareName - May not be installed" -ForegroundColor Yellow
            }
        }
    }
}

# Function to clean registry entries
function Remove-RegistryEntries {
    Write-Host "`nCleaning registry entries..." -ForegroundColor Cyan
    
    $RegistryPaths = @(
        "HKLM:\SOFTWARE\Autodesk"
        "HKLM:\SOFTWARE\Vectorworks"
        "HKLM:\SOFTWARE\Bluebeam"
        "HKLM:\SOFTWARE\Bentley"
        "HKLM:\SOFTWARE\SolidWorks*"
        "HKLM:\SOFTWARE\Dassault*"
        "HKLM:\SOFTWARE\SketchUp"
        "HKLM:\SOFTWARE\Google\SketchUp"
        "HKLM:\SOFTWARE\Trimble"
        "HKLM:\SOFTWARE\McNeel"
        "HKLM:\SOFTWARE\ANSYS*"
        "HKLM:\SOFTWARE\MathWorks"
        "HKLM:\SOFTWARE\ESRI"
        "HKLM:\SOFTWARE\Tekla"
        "HKLM:\SOFTWARE\RISA"
        "HKLM:\SOFTWARE\Computers and Structures"
        "HKLM:\SOFTWARE\PTC"
        "HKLM:\SOFTWARE\FlexNet*"
        "HKLM:\SOFTWARE\FLEXlm*"
        "HKLM:\SOFTWARE\SafeNet*"
        "HKLM:\SOFTWARE\Sentinel*"
        "HKLM:\SOFTWARE\CodeMeter*"
        "HKLM:\SOFTWARE\WIBU*"
        "HKCU:\SOFTWARE\Autodesk"
        "HKCU:\SOFTWARE\Vectorworks"
        "HKCU:\SOFTWARE\Bluebeam"
        "HKCU:\SOFTWARE\SolidWorks*"
        "HKCU:\SOFTWARE\SketchUp"
        "HKCU:\SOFTWARE\McNeel"
    )
    
    foreach ($RegPath in $RegistryPaths) {
        try {
            if (Test-Path $RegPath) {
                Write-Host "Removing registry key: $RegPath" -ForegroundColor Yellow
                Remove-Item -Path $RegPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        catch {
            Write-Host "Could not remove registry key: $RegPath" -ForegroundColor Red
        }
    }
}

# Function to remove leftover folders
function Remove-LeftoverFolders {
    Write-Host "`nRemoving leftover folders..." -ForegroundColor Cyan
    
    $FoldersToRemove = @(
        "C:\Program Files\Autodesk"
        "C:\Program Files (x86)\Autodesk"
        "C:\Program Files\Vectorworks*"
        "C:\Program Files (x86)\Vectorworks*"
        "C:\Program Files\Bluebeam*"
        "C:\Program Files (x86)\Bluebeam*"
        "C:\Program Files\Bentley"
        "C:\Program Files (x86)\Bentley"
        "C:\Program Files\SolidWorks*"
        "C:\Program Files\SOLIDWORKS*"
        "C:\Program Files\Common Files\SolidWorks*"
        "C:\Program Files\SketchUp"
        "C:\Program Files (x86)\SketchUp"
        "C:\Program Files\Google\Google SketchUp*"
        "C:\Program Files (x86)\Google\Google SketchUp*"
        "C:\Program Files\McNeel"
        "C:\Program Files (x86)\McNeel"
        "C:\Program Files\ANSYS*"
        "C:\Program Files\MathWorks"
        "C:\Program Files\ArcGIS"
        "C:\Program Files (x86)\ArcGIS"
        "C:\Program Files\Tekla*"
        "C:\Program Files\RISA*"
        "C:\Program Files\Computers and Structures"
        "C:\Program Files (x86)\Computers and Structures"
        "C:\Program Files\PTC"
        "C:\Program Files (x86)\PTC"
        "C:\ProgramData\Autodesk"
        "C:\ProgramData\Vectorworks"
        "C:\ProgramData\Bluebeam"
        "C:\ProgramData\Bentley"
        "C:\ProgramData\SolidWorks"
        "C:\ProgramData\SOLIDWORKS"
        "C:\ProgramData\SketchUp"
        "C:\ProgramData\McNeel"
        "C:\ProgramData\ANSYS"
        "C:\ProgramData\MathWorks"
        "C:\ProgramData\ESRI"
        "C:\ProgramData\Tekla"
        "C:\ProgramData\FlexNet*"
        "C:\ProgramData\FLEXlm*"
        "C:\ProgramData\SafeNet*"
        "C:\ProgramData\Sentinel*"
        "C:\ProgramData\CodeMeter*"
        "C:\Users\$env:USERNAME\AppData\Roaming\Autodesk"
        "C:\Users\$env:USERNAME\AppData\Local\Autodesk"
        "C:\Users\$env:USERNAME\AppData\Roaming\Vectorworks"
        "C:\Users\$env:USERNAME\AppData\Roaming\Bluebeam*"
        "C:\Users\$env:USERNAME\AppData\Roaming\SolidWorks"
        "C:\Users\$env:USERNAME\AppData\Roaming\SOLIDWORKS"
        "C:\Users\$env:USERNAME\AppData\Local\SolidWorks"
        "C:\Users\$env:USERNAME\AppData\Roaming\SketchUp"
        "C:\Users\$env:USERNAME\AppData\Roaming\McNeel"
        "C:\Users\$env:USERNAME\AppData\Local\McNeel"
        "C:\Users\$env:USERNAME\Documents\Autodesk"
        "C:\Users\$env:USERNAME\Documents\SolidWorks*"
        "C:\Users\$env:USERNAME\Documents\My Games\*CAD*"
    )
    
    foreach ($Folder in $FoldersToRemove) {
        try {
            $ExpandedPaths = Get-ChildItem -Path (Split-Path $Folder -Parent) -Directory -Filter (Split-Path $Folder -Leaf) -ErrorAction SilentlyContinue
            foreach ($Path in $ExpandedPaths) {
                if (Test-Path $Path.FullName) {
                    Write-Host "Removing folder: $($Path.FullName)" -ForegroundColor Yellow
                    Remove-Item -Path $Path.FullName -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
            
            # Direct path removal
            if (Test-Path $Folder) {
                Write-Host "Removing folder: $Folder" -ForegroundColor Yellow
                Remove-Item -Path $Folder -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        catch {
            Write-Host "Could not remove folder: $Folder" -ForegroundColor Red
        }
    }
}

# Function to clean temporary files
function Remove-TempFiles {
    Write-Host "`nCleaning temporary files..." -ForegroundColor Cyan
    
    $TempPaths = @(
        "$env:TEMP\Autodesk*"
        "$env:TEMP\Vectorworks*"
        "$env:TEMP\Bluebeam*"
        "$env:TEMP\SolidWorks*"
        "$env:TEMP\SOLIDWORKS*"
        "$env:TEMP\McNeel*"
        "$env:TEMP\ANSYS*"
        "$env:TEMP\MathWorks*"
        "C:\Windows\Temp\Autodesk*"
        "C:\Windows\Temp\Vectorworks*"
        "C:\Windows\Temp\Bluebeam*"
        "C:\Windows\Temp\SolidWorks*"
    )
    
    foreach ($TempPath in $TempPaths) {
        try {
            if (Test-Path $TempPath) {
                Write-Host "Cleaning temp files: $TempPath" -ForegroundColor Yellow
                Remove-Item -Path $TempPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        catch {
            Write-Host "Could not clean temp files: $TempPath" -ForegroundColor Red
        }
    }
}

# Main execution menu
do {
    Write-Host "`n=== ENGINEERING SOFTWARE REMOVAL MENU ===" -ForegroundColor Green
    Write-Host "1. Complete removal (ALL engineering software)"
    Write-Host "2. Remove Autodesk products only"
    Write-Host "3. Remove Vectorworks only"
    Write-Host "4. Remove Bluebeam only"
    Write-Host "5. Remove SolidWorks only"
    Write-Host "6. Remove Bentley products only"
    Write-Host "7. List installed engineering software"
    Write-Host "8. Clean registry and leftover files only"
    Write-Host "9. Exit"
    
    $choice = Read-Host "`nSelect an option (1-9)"
    
    switch ($choice) {
        "1" { 
            Write-Host "`nThis will completely remove ALL engineering software!" -ForegroundColor Red
            Write-Host "This includes ALL versions of AutoCAD, Civil 3D, Vectorworks, Bluebeam, SolidWorks, etc." -ForegroundColor Yellow
            $confirmation = Read-Host "`nAre you absolutely sure? This cannot be undone! (yes/no)"
            if ($confirmation -eq "yes") {
                Stop-EngineeringServices
                Remove-EngineeringSoftware $EngineeringSoftware
                Remove-RegistryEntries
                Remove-LeftoverFolders
                Remove-TempFiles
                Write-Host "`nComplete removal finished! Restart your computer to finalize." -ForegroundColor Green
            }
        }
        "2" { 
            $AutodeskOnly = @{"Autodesk" = $EngineeringSoftware["Autodesk"]}
            Stop-EngineeringServices
            Remove-EngineeringSoftware $AutodeskOnly
            Remove-RegistryEntries
            Remove-LeftoverFolders
            Remove-TempFiles
        }
        "3" { 
            $VectorworksOnly = @{"Vectorworks" = $EngineeringSoftware["Vectorworks"]}
            Remove-EngineeringSoftware $VectorworksOnly
        }
        "4" { 
            $BluebeamOnly = @{"Bluebeam" = $EngineeringSoftware["Bluebeam"]}
            Remove-EngineeringSoftware $BluebeamOnly
        }
        "5" { 
            $SolidWorksOnly = @{"SolidWorks" = $EngineeringSoftware["SolidWorks"]}
            Remove-EngineeringSoftware $SolidWorksOnly
        }
        "6" { 
            $BentleyOnly = @{"BentleyMicrostation" = $EngineeringSoftware["BentleyMicrostation"]}
            Remove-EngineeringSoftware $BentleyOnly
        }
        "7" { 
            Write-Host "`nScanning for installed engineering software..." -ForegroundColor Cyan
            $InstalledSoftware = Get-WmiObject -Class Win32_Product | Where-Object {
                $_.Name -like "*AutoCAD*" -or $_.Name -like "*Autodesk*" -or 
                $_.Name -like "*Vectorworks*" -or $_.Name -like "*Bluebeam*" -or
                $_.Name -like "*SolidWorks*" -or $_.Name -like "*Civil 3D*" -or
                $_.Name -like "*Bentley*" -or $_.Name -like "*MicroStation*" -or
                $_.Name -like "*ANSYS*" -or $_.Name -like "*MATLAB*" -or
                $_.Name -like "*ArcGIS*" -or $_.Name -like "*SketchUp*"
            } | Select-Object Name, Version | Sort-Object Name
            
            if ($InstalledSoftware.Count -gt 0) {
                $InstalledSoftware | Format-Table -AutoSize
            } else {
                Write-Host "No engineering software found." -ForegroundColor Green
            }
        }
        "8" { 
            Write-Host "`nCleaning registry and leftover files only..." -ForegroundColor Cyan
            Remove-RegistryEntries
            Remove-LeftoverFolders
            Remove-TempFiles
        }
        "9" { break }
        default { Write-Host "Invalid option" -ForegroundColor Red }
    }
} while ($choice -ne "9")

Write-Host "`nEngineering software removal completed!" -ForegroundColor Green
Write-Host "It's recommended to restart your computer to complete the cleanup." -ForegroundColor Yellow
