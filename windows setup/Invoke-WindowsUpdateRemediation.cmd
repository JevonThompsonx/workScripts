@ECHO OFF
SETLOCAL ENABLEEXTENSIONS

SET "me=%~n0"
SET "mypath=%~dp0"
SET "script=%mypath%Invoke-WindowsUpdateRemediation.ps1"

IF NOT EXIST "%script%" (
    ECHO [ERROR] PowerShell script not found: "%script%"
    EXIT /B 2
)

PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "%script%" %*
SET "exitCode=%ERRORLEVEL%"

IF %exitCode% NEQ 0 (
    ECHO.
    ECHO [WARN] Script exited with code %exitCode%.
    PAUSE
)

EXIT /B %exitCode%
