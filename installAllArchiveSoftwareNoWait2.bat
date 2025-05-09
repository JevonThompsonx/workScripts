REM filepath: c:\Users\Jevon\Documents\scripts\installAllArchiveSoftwareNoWait.bat
@echo off
REM Set the directory containing the installation files
set "INSTALL_DIR=C:\Archive"

REM Check if the directory exists
if not exist "%INSTALL_DIR%" (
    echo Error: Directory "%INSTALL_DIR%" not found.
    pause
    exit /b 1
)

echo Starting installation process from "%INSTALL_DIR%"...
echo.

REM Loop through all .exe files in the directory
echo --- Processing Executable Files (.exe) ---
for %%F in ("%INSTALL_DIR%\*.exe") do (
    echo Launching: "%%~nxF"
    REM Launch exe with default UI
    start "" "%%F"
    echo Launched: "%%~nxF"
    echo.
)

echo.
echo --- Processing MSI Files (.msi) ---
REM Loop through all .msi files in the directory
for %%F in ("%INSTALL_DIR%\*.msi") do (
    echo Launching: "%%~nxF"
    REM Launch msi with default UI
    start "" msiexec /i "%%F"
    echo Launched: "%%~nxF"
    echo.
)

echo.
echo All installations have been launched.
echo Note: Installations are running in the background.
pause