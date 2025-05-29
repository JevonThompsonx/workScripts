@echo off
echo ----------------------------------------
echo Enabling the built-in Administrator account...
echo ----------------------------------------
net user administrator /active:yes

if %errorlevel% neq 0 (
echo There was an error enabling the Administrator account.
pause
exit /b
)

echo.
echo ----------------------------------------
echo Please enter a new password for the Administrator account.
echo (Your password will not be displayed)
echo ----------------------------------------
net user administrator *

echo.
echo Done! The Administrator account has been enabled and its password has been updated.
pause