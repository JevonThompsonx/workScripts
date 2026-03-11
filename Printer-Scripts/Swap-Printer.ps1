#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Swaps one printer definition for another using sanitized config values.

.DESCRIPTION
    Removes the old queue, clears queued jobs, optionally removes the old driver
    package, stages replacement files locally, and creates the replacement queue.

.NOTES
    Author: Jevon Thompson
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath 'PrinterConfig.psd1'),

    [Parameter()]
    [string]$DriverSharePath,

    [Parameter()]
    [string]$LocalStageRoot,

    [Parameter(Mandatory = $true)]
    [string]$OldPrinterName,

    [Parameter(Mandatory = $true)]
    [string]$OldDriverName,

    [Parameter()]
    [string]$OldPublishedInfName,

    [Parameter(Mandatory = $true)]
    [string]$NewPrinterKey
)

$ErrorActionPreference = 'Stop'
. (Join-Path -Path $PSScriptRoot -ChildPath 'PrinterCommon.ps1')

try {
    $configData = Get-PrinterRepositoryConfig -ConfigPath $ConfigPath
    $resolvedDriverSharePath = Resolve-DriverSharePathValue -ConfigData $configData -DriverSharePath $DriverSharePath
    $resolvedLocalStageRoot = Resolve-LocalStageRootValue -ConfigData $configData -LocalStageRoot $LocalStageRoot
    $logRoot = [string]$configData.LogRoot
    if ([string]::IsNullOrWhiteSpace($logRoot)) {
        $logRoot = Join-Path -Path $env:TEMP -ChildPath 'PrinterScripts'
    }

    $logPath = Start-PrinterTranscript -LogRoot $logRoot -FilePrefix 'SwapPrinter'
    Write-PrinterBanner -Message 'Swap Printer'
    Write-Host ("Log file: {0}" -f $logPath)

    Assert-PrinterScriptAdministrator

    $newPrinterConfig = Get-SelectedPrinterConfigs -ConfigData $configData -PrinterKeys @($NewPrinterKey)
    if ($newPrinterConfig.Count -ne 1) {
        throw 'NewPrinterKey must resolve to exactly one printer entry.'
    }
    $newPrinterConfig = $newPrinterConfig[0]

    if (-not (Test-Path -Path $resolvedLocalStageRoot)) {
        New-Item -Path $resolvedLocalStageRoot -ItemType Directory -Force | Out-Null
    }

    $localStagePath = Join-Path -Path $resolvedLocalStageRoot -ChildPath $newPrinterConfig.Key
    $driverSource = Resolve-SwapDriverSource -DriverSharePath $resolvedDriverSharePath -DriverFolder $newPrinterConfig.DriverFolder -InfFile $newPrinterConfig.InfFile -LocalStagePath $localStagePath
    if ($driverSource.Mode -eq 'Network') {
        $stageResult = Copy-DriverFilesToLocalStage -SourceDriverPath $driverSource.DriverPath -DestinationDriverPath $localStagePath -InfFileName $newPrinterConfig.InfFile
        Write-Host ("Local staging: {0}" -f $stageResult) -ForegroundColor Green
    }

    $localInfPath = Join-Path -Path $localStagePath -ChildPath $newPrinterConfig.InfFile
    if (-not (Test-Path -Path $localInfPath)) {
        $localInfPath = $driverSource.InfPath
    }

    $cleanupIssues = New-Object 'System.Collections.Generic.List[string]'
    $rebootRequired = $false

    try {
        $jobResult = Remove-PrintJobsForPrinter -PrinterName $OldPrinterName
        Write-Host ("Old print jobs: {0}" -f $jobResult)
    }
    catch {
        $cleanupIssues.Add(("Failed to clear print jobs: {0}" -f $PSItem.Exception.Message)) | Out-Null
    }

    try {
        if (Test-PrinterExists -PrinterName $OldPrinterName) {
            Remove-Printer -Name $OldPrinterName -ErrorAction Stop
            Write-Host 'Old printer queue: Removed' -ForegroundColor Green
        }
        else {
            Write-Host 'Old printer queue: Already absent' -ForegroundColor Yellow
        }
    }
    catch {
        $cleanupIssues.Add(("Failed to remove old printer queue: {0}" -f $PSItem.Exception.Message)) | Out-Null
    }

    try {
        $driverUsers = @(Get-Printer -ErrorAction SilentlyContinue | Where-Object { $PSItem.DriverName -eq $OldDriverName })
        if ($driverUsers.Count -eq 0 -and (Test-PrinterDriverExists -DriverName $OldDriverName)) {
            Remove-PrinterDriver -Name $OldDriverName -ErrorAction Stop
            Write-Host 'Old printer driver: Removed' -ForegroundColor Green
        }
        else {
            Write-Host 'Old printer driver: Skipped' -ForegroundColor Yellow
        }
    }
    catch {
        $cleanupIssues.Add(("Failed to remove old driver: {0}" -f $PSItem.Exception.Message)) | Out-Null
    }

    try {
        $publishedInf = Resolve-PrinterDriverPublishedInfName -DriverName $OldDriverName -PublishedInfName $OldPublishedInfName
        if (-not [string]::IsNullOrWhiteSpace($publishedInf)) {
            $driverStoreExit = Remove-DriverStorePackage -PublishedInfName $publishedInf
            if ($driverStoreExit -eq 3010) {
                $rebootRequired = $true
            }
            Write-Host 'Old driver store package: Removed' -ForegroundColor Green
        }
        else {
            Write-Host 'Old driver store package: Skipped' -ForegroundColor Yellow
        }
    }
    catch {
        $cleanupIssues.Add(("Failed to remove old driver store package: {0}" -f $PSItem.Exception.Message)) | Out-Null
    }

    $driverResult = Install-PrinterDriverFromInf -InfPath $localInfPath -DriverName $newPrinterConfig.DriverName
    Write-Host ("New driver: {0}" -f $driverResult) -ForegroundColor Green

    $portName = 'IP_{0}' -f $newPrinterConfig.IPAddress
    $portResult = Ensure-TcpIpPrinterPort -PortName $portName -IPAddress $newPrinterConfig.IPAddress
    Write-Host ("Printer port: {0}" -f $portResult) -ForegroundColor Green

    $queueResult = Ensure-PrinterQueue -PrinterName $newPrinterConfig.PrinterName -DriverName $newPrinterConfig.DriverName -PortName $portName
    Write-Host ("New printer queue: {0}" -f $queueResult) -ForegroundColor Green

    if ($cleanupIssues.Count -gt 0) {
        Write-Host ''
        Write-Host 'Partial cleanup issues:' -ForegroundColor Yellow
        foreach ($issue in $cleanupIssues) {
            Write-Host ("  - {0}" -f $issue) -ForegroundColor Yellow
        }
    }

    if ($cleanupIssues.Count -gt 0) {
        exit 1
    }

    if ($rebootRequired) {
        exit 3010
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
