@echo off
setlocal enabledelayedexpansion

:: Default Egnyte username is the Windows username
set EGNYTE_USER=%USERNAME%

:: --- EXCEPTION LIST START ---
:: Check for specific user/computer combinations and override the Egnyte username

if /I "%USERNAME%"=="jsmith" if /I "%COMPUTERNAME%"=="LAPT-FIN-01" set EGNYTE_USER=jsmith2
if /I "%USERNAME%"=="jsmith" if /I "%COMPUTERNAME%"=="DESK-ACC-05" set EGNYTE_USER=john.smith
if /I "%USERNAME%"=="mchen" if /I "%COMPUTERNAME%"=="LAPT-HR-12" set EGNYTE_USER=mchen_hr

:: --- EXCEPTION LIST END ---


:: --- SCRIPT EXECUTION ---
echo Mapping drive for Egnyte user: !EGNYTE_USER!

cd "C:\Program Files (x86)\Egnyte Connect"

:: The -d "ashleyvance" part might need to be dynamic too, but based on the original script we'll keep it static.
:: Note the use of !EGNYTE_USER! instead of %EGNYTE_USER% because of delayed expansion.

EgnyteClient.exe -command add -l "Private" -d "ashleyvance" -sso use_sso -t P -m "/Private/!EGNYTE_USER!" -c connect_immediately

:: You would do the same for your other drive mappings if needed

endlocal