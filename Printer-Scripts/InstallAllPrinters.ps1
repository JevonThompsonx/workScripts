#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs every printer defined in the sanitized printer configuration.

.DESCRIPTION
    Uses local driver folders and INF files to install all configured printers by
    TCP/IP address. This version is intended as a GitHub-safe template that keeps
    printer definitions in `PrinterConfig.psd1`.

.NOTES
    Author: Jevon Thompson
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$BasePath,

    [Parameter()]
    [string]$ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath 'PrinterConfig.psd1')
)

$ErrorActionPreference = 'Stop'
. (Join-Path -Path $PSScriptRoot -ChildPath 'PrinterCommon.ps1')

try {
    $configData = Get-PrinterRepositoryConfig -ConfigPath $ConfigPath
    $resolvedBasePath = Resolve-PrinterBasePath -ConfigData $configData -BasePath $BasePath
    $logRoot = [string]$configData.LogRoot
    if ([string]::IsNullOrWhiteSpace($logRoot)) {
        $logRoot = Join-Path -Path $env:TEMP -ChildPath 'PrinterScripts'
    }

    $logPath = Start-PrinterTranscript -LogRoot $logRoot -FilePrefix 'InstallAllPrinters'
    Write-PrinterBanner -Message 'Install All Printers'
    Write-Host ("Log file: {0}" -f $logPath)
    Write-Host ("Base path: {0}" -f $resolvedBasePath)

    Assert-PrinterScriptAdministrator

    if (-not (Test-Path -Path $resolvedBasePath)) {
        throw ("Printer driver folder not found: {0}" -f $resolvedBasePath)
    }

    $printerConfigs = Get-ConfiguredPrinters -ConfigData $configData
    $folderCheck = Test-DriverFoldersForConfigs -BasePath $resolvedBasePath -PrinterConfigs $printerConfigs
    $availableConfigs = @($folderCheck.Available)
    $missingConfigs = @($folderCheck.Missing)

    if ($missingConfigs.Count -gt 0) {
        Write-Host ''
        Write-Host 'Missing driver folders:' -ForegroundColor Yellow
        foreach ($missing in $missingConfigs) {
            Write-Host ("  - {0}" -f $missing.DriverFolder) -ForegroundColor Yellow
        }
    }

    if ($availableConfigs.Count -eq 0) {
        throw 'No valid printer driver folders were found.'
    }

    $results = @{
        Success = @()
        Skipped = @()
        Failed = @()
    }

    foreach ($printerConfig in $availableConfigs) {
        Write-Host ''
        Write-Host ("Processing: {0} ({1})" -f $printerConfig.PrinterName, $printerConfig.IPAddress) -ForegroundColor Cyan
        Write-Host '----------------------------------------'

        try {
            $result = Install-NetworkPrinter -PrinterConfig $printerConfig -BasePath $resolvedBasePath
        }
        catch {
            Write-Host ("  FAILED: {0}" -f $PSItem.Exception.Message) -ForegroundColor Red
            $result = 'Failed'
        }

        switch ($result) {
            'Success' { $results.Success += $printerConfig.PrinterName }
            'Skipped' { $results.Skipped += $printerConfig.PrinterName }
            default { $results.Failed += $printerConfig.PrinterName }
        }
    }

    Write-PrinterBanner -Message 'Installation Summary'
    Write-Host ("Successful: {0}" -f $results.Success.Count) -ForegroundColor Green
    foreach ($item in $results.Success) {
        Write-Host ("  - {0}" -f $item) -ForegroundColor Green
    }

    Write-Host ''
    Write-Host ("Skipped: {0}" -f $results.Skipped.Count) -ForegroundColor Yellow
    foreach ($item in $results.Skipped) {
        Write-Host ("  - {0}" -f $item) -ForegroundColor Yellow
    }

    Write-Host ''
    Write-Host ("Failed: {0}" -f $results.Failed.Count) -ForegroundColor Red
    foreach ($item in $results.Failed) {
        Write-Host ("  - {0}" -f $item) -ForegroundColor Red
    }

    if ($results.Failed.Count -gt 0 -and $results.Success.Count -gt 0) {
        exit 1
    }

    if ($results.Failed.Count -gt 0) {
        exit 2
    }

    if ($results.Success.Count -eq 0 -and $results.Skipped.Count -gt 0) {
        exit 100
    }

    exit 0
}
catch {
    Write-Host ''
    Write-Host ("FATAL ERROR: {0}" -f $PSItem.Exception.Message) -ForegroundColor Red
    exit 2
}
finally {
    Stop-PrinterTranscriptSafe
}
