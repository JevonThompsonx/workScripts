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
    echo Executing: "%%~nxF"
    REM Use 'start /wait' for .exe files to wait for completion and handle spaces in path
    REM You might want to add silent install switches specific to each .exe if available
    start "" /wait "%%F"
    echo Finished executing: "%%~nxF"
    echo.
)

echo.
echo --- Processing Windows Installer Packages (.msi) ---
REM Loop through all .msi files in the directory
for %%F in ("%INSTALL_DIR%\*.msi") do (
    echo Executing: "%%~nxF"
    REM Use msiexec to install .msi files
    REM /i: Installs or configures a product
    REM /qn: No UI (silent install). You can change this to /qb for basic UI or remove it for full UI.
    msiexec.exe /i "%%F" /qn /L*V "%TEMP%\msi_install_%%~nxF.log"
    echo Finished executing: "%%~nxF"
    echo.
)

echo.
echo Installation process completed.
pause