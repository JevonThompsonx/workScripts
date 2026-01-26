#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Non-interactive RMM runner for workScripts (NinjaOne-friendly).

.DESCRIPTION
    Runs the main setup tasks without any interactive prompts. This script does NOT
    download anything from RMM. It executes the GitHub-hosted scripts in-memory and
    explicitly skips C:\Archive installs (use a separate part 2).

    It also enables the built-in Administrator account and sets the password provided
    via -AdministratorPassword.

.NOTES
    Use in RMM with parameters; avoid logging sensitive values.
#>

param(
    [string]$AdministratorPassword,
    [string]$AdministratorPasswordBase64,

    [string]$DomainsAllowedToLogin = "ashleyvance.com",

    [switch]$SkipSetup,
    [switch]$SkipDriveClone,
    [switch]$SkipEgnyteInstall,

    [switch]$RunRaphireDebloat,
    [switch]$RunEngineeringDebloat,
    [switch]$ConfirmEngineeringDebloat
)

Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host "        STARTING MASTER WORK SCRIPT (RMM MODE)"
Write-Host "===========================================================" -ForegroundColor Cyan

if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "[ERROR] This script requires Administrator privileges."
    exit 1
}

if (-not [string]::IsNullOrWhiteSpace($AdministratorPasswordBase64)) {
    try {
        $AdministratorPassword = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($AdministratorPasswordBase64))
    }
    catch {
        Write-Error "[ERROR] AdministratorPasswordBase64 is invalid."
        exit 1
    }
}

if ([string]::IsNullOrWhiteSpace($AdministratorPassword)) {
    Write-Error "[ERROR] Provide -AdministratorPassword or -AdministratorPasswordBase64."
    exit 1
}

try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
}
catch {
    Write-Error "[ERROR] Failed to set execution policy."
    exit 1
}

function Set-BuiltinAdminPassword {
    try {
        $enable = Start-Process -FilePath "net" -ArgumentList @("user", "administrator", "/active:yes") -NoNewWindow -Wait -PassThru
        if ($enable.ExitCode -ne 0) {
            Write-Error "[ERROR] Failed to enable Administrator account."
            exit 1
        }

        $setPwd = Start-Process -FilePath "net" -ArgumentList @("user", "administrator", $AdministratorPassword) -NoNewWindow -Wait -PassThru
        if ($setPwd.ExitCode -ne 0) {
            Write-Error "[ERROR] Failed to set Administrator password."
            exit 1
        }

        Write-Host "[OK] Administrator account enabled and password updated." -ForegroundColor Green
    }
    catch {
        Write-Error "[ERROR] Failed to set Administrator password: $($_.Exception.Message)"
        exit 1
    }
}

if (-not $SkipSetup) {
    Set-BuiltinAdminPassword

    Write-Host "[STEP] Windows settings script..." -ForegroundColor Cyan
    try {
        & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/windows%20setup/setup_script_windows_settings1_3.ps1"))) -NoPause
    }
    catch {
        Write-Error "[ERROR] Windows settings script failed."
    }

    Write-Host "[STEP] Google Credential Provider settings..." -ForegroundColor Cyan
    try {
        & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/windows%20setup/AllowGoogleCred.ps1"))) -DomainsAllowedToLogin $DomainsAllowedToLogin
    }
    catch {
        Write-Error "[ERROR] Google Credential Provider script failed."
    }
}
else {
    Write-Host "[SKIP] Setup steps skipped." -ForegroundColor Yellow
}

if (-not $SkipDriveClone) {
    Write-Host "[STEP] Clone Egnyte drive mapping scripts..." -ForegroundColor Cyan
    try {
        & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/drives/cloneDrives.ps1")))
    }
    catch {
        Write-Error "[ERROR] Drive clone script failed."
    }
}
else {
    Write-Host "[SKIP] Drive clone skipped." -ForegroundColor Yellow
}

if (-not $SkipEgnyteInstall) {
    Write-Host "[STEP] Egnyte install/update..." -ForegroundColor Cyan
    try {
        & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/updatingSoftware/Update-Egnyte-v1.5.ps1"))) -NoPause
    }
    catch {
        Write-Error "[ERROR] Egnyte update script failed."
    }
}
else {
    Write-Host "[SKIP] Egnyte install/update skipped." -ForegroundColor Yellow
}

Write-Host "[SKIP] C:\Archive installs skipped by design." -ForegroundColor Yellow

if ($RunEngineeringDebloat) {
    Write-Host "[STEP] Engineering debloat..." -ForegroundColor Cyan
    if ($ConfirmEngineeringDebloat) {
        try {
            & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/windows%20setup/engineeringDebloat.ps1"))) -NonInteractive -Mode All -ConfirmRemoval -NoPause
        }
        catch {
            Write-Error "[ERROR] Engineering debloat failed."
        }
    }
    else {
        Write-Host "[SKIP] Engineering debloat not confirmed. Set -ConfirmEngineeringDebloat to proceed." -ForegroundColor Yellow
    }
}
elseif ($RunRaphireDebloat) {
    Write-Host "[STEP] Raphire debloat..." -ForegroundColor Cyan
    try {
        & ([scriptblock]::Create((irm "https://debloat.raphi.re/")))
    }
    catch {
        Write-Error "[ERROR] Raphire debloat failed."
    }
}

Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host "               RMM SCRIPT FINISHED"
Write-Host "===========================================================" -ForegroundColor Cyan
