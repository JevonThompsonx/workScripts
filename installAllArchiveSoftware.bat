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
echo --- Processing Batch Files (.exe) ---
for %%F in ("%INSTALL_DIR%\*.exe") do (
    echo Executing: "%%~nxF"
    REM Use 'call' to execute the batch script and return here afterwards
    call "%%F"
    echo Finished executing: "%%~nxF"
    echo.
)

echo.
echo --- Processing PowerShell Files (.msi) ---
REM Loop through all .msi files in the directory
for %%F in ("%INSTALL_DIR%\*.msi") do (
    echo Executing: "%%~nxF"
    REM Execute the PowerShell script
    REM -ExecutionPolicy Bypass: Temporarily bypasses execution policy for this command
    REM -File: Specifies the script file to run
    powershell.exe -ExecutionPolicy Bypass -File "%%F"
    echo Finished executing: "%%~nxF"
    echo.
)

echo.
echo Installation process completed.
pause
