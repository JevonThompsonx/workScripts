#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Removes matching printers, ports, and drivers, then reinstalls selected printers.

.DESCRIPTION
    Useful when printer objects are broken or when driver refresh is needed. This
    version uses the sanitized config file and supports key-based selection.

.NOTES
    Author: Jevon Thompson
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$BasePath,

    [Parameter()]
    [string]$ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath 'PrinterConfig.psd1'),

    [Parameter()]
    [string]$InstallAll = 'false',

    [Parameter()]
    [string[]]$PrinterKeys = @()
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

    if (-not [string]::IsNullOrWhiteSpace($env:InstallAll)) {
        $InstallAll = $env:InstallAll
    }
    if (-not [string]::IsNullOrWhiteSpace($env:PrinterKeys)) {
        $PrinterKeys += $env:PrinterKeys
    }

    $installAllSelected = ConvertTo-PrinterScriptBoolean -Value $InstallAll
    $selectedConfigs = Get-SelectedPrinterConfigs -ConfigData $configData -PrinterKeys $PrinterKeys -InstallAll:$installAllSelected
    $logPath = Start-PrinterTranscript -LogRoot $logRoot -FilePrefix 'DeleteAndReinstallPrinters'

    Write-PrinterBanner -Message 'Delete And Reinstall Selected Printers'
    Write-Host ("Log file: {0}" -f $logPath)
    Write-Host ("Base path: {0}" -f $resolvedBasePath)

    Assert-PrinterScriptAdministrator

    if ($selectedConfigs.Count -eq 0) {
        Write-Host 'No printers selected.' -ForegroundColor Yellow
        exit 100
    }

    if (-not (Test-Path -Path $resolvedBasePath)) {
        throw ("Printer driver folder not found: {0}" -f $resolvedBasePath)
    }

    $folderCheck = Test-DriverFoldersForConfigs -BasePath $resolvedBasePath -PrinterConfigs $selectedConfigs
    $availableConfigs = @($folderCheck.Available)
    $missingConfigs = @($folderCheck.Missing)

    if ($missingConfigs.Count -gt 0) {
        Write-Host ''
        Write-Host 'Missing selected driver folders:' -ForegroundColor Yellow
        foreach ($missing in $missingConfigs) {
            Write-Host ("  - {0}" -f $missing.DriverFolder) -ForegroundColor Yellow
        }
    }

    if ($availableConfigs.Count -eq 0) {
        throw 'No selected printer driver folders were found.'
    }

    Write-Host ''
    Write-Host 'Removing matching printers, ports, and drivers...' -ForegroundColor Cyan
    $cleanupResults = Remove-ConflictingPrintersAndDrivers -PrinterConfigs $availableConfigs

    $results = @{
        Success = @()
        Skipped = @()
        Failed = @()
    }

    foreach ($printerConfig in $availableConfigs) {
        Write-Host ''
        Write-Host ("Reinstalling: {0} ({1})" -f $printerConfig.PrinterName, $printerConfig.IPAddress) -ForegroundColor Cyan
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

    Write-PrinterBanner -Message 'Cleanup Summary'
    Write-Host ("Removed printers: {0}" -f $cleanupResults.RemovedPrinters.Count) -ForegroundColor Yellow
    foreach ($item in $cleanupResults.RemovedPrinters) {
        Write-Host ("  - {0}" -f $item) -ForegroundColor Yellow
    }
    Write-Host ("Failed printer removals: {0}" -f $cleanupResults.FailedPrinters.Count) -ForegroundColor Red
    foreach ($item in $cleanupResults.FailedPrinters) {
        Write-Host ("  - {0}" -f $item) -ForegroundColor Red
    }
    Write-Host ("Removed ports: {0}" -f $cleanupResults.RemovedPorts.Count) -ForegroundColor Yellow
    Write-Host ("Removed drivers: {0}" -f $cleanupResults.RemovedDrivers.Count) -ForegroundColor Yellow

    Write-PrinterBanner -Message 'Installation Summary'
    Write-Host ("Successful: {0}" -f $results.Success.Count) -ForegroundColor Green
    foreach ($item in $results.Success) {
        Write-Host ("  - {0}" -f $item) -ForegroundColor Green
    }
    Write-Host ("Skipped: {0}" -f $results.Skipped.Count) -ForegroundColor Yellow
    foreach ($item in $results.Skipped) {
        Write-Host ("  - {0}" -f $item) -ForegroundColor Yellow
    }
    Write-Host ("Failed: {0}" -f $results.Failed.Count) -ForegroundColor Red
    foreach ($item in $results.Failed) {
        Write-Host ("  - {0}" -f $item) -ForegroundColor Red
    }

    $cleanupFailed = ($cleanupResults.FailedPrinters.Count -gt 0 -or $cleanupResults.FailedPorts.Count -gt 0 -or $cleanupResults.FailedDrivers.Count -gt 0)

    if ($results.Failed.Count -gt 0 -or $cleanupFailed) {
        if ($results.Success.Count -gt 0 -or $results.Skipped.Count -gt 0) {
            exit 1
        }

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
