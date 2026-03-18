#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Runs a safe, scheduled Windows maintenance workflow with DISM, SFC, and supporting health checks.

.DESCRIPTION
    This script is designed for daily NinjaOne maintenance on Windows endpoints. It performs pre-flight validation,
    checks servicing prerequisites, and runs a staged repair workflow using cadence controls so expensive tasks do
    not run unnecessarily every day.

    Daily-safe maintenance included:
    - Pending reboot detection
    - Disk space validation
    - Service readiness checks for servicing components
    - DISM /CheckHealth
    - Optional cadence-based DISM /ScanHealth
    - Optional cadence-based DISM /RestoreHealth
    - Optional cadence-based DISM /AnalyzeComponentStore
    - Optional cadence-based DISM /StartComponentCleanup
    - Optional cadence-based CHKDSK /scan
    - Optional cadence-based SFC /scannow
    - Optional Windows Update download cache reset for DISM retry only
    - Optional stale Delivery Optimization cache cleanup
    - Log rotation and local maintenance state tracking

    Non-obvious design decisions:
    - Cadence control is enabled by default because this script is intended for daily scheduling. Lightweight health
      checks can run daily, while heavier repair tasks run every few days unless explicitly forced.
    - Windows Update component reset remains disabled by default because resetting update caches every day is not
      appropriate routine maintenance.
    - Delivery Optimization cache cleanup is disabled by default because clearing it too often can increase WAN use.
    - ExitCodeMode defaults to NinjaFriendly so handled warnings and reboot-required states are not mislabeled as
      hard failures by wrappers that only interpret exit code 0 as success.

.PARAMETER DismTimeoutMinutes
    Maximum time to wait for each DISM operation.

.PARAMETER SfcTimeoutMinutes
    Maximum time to wait for SFC /scannow.

.PARAMETER ChkdskTimeoutMinutes
    Maximum time to wait for CHKDSK /scan.

.PARAMETER MaxRetries
    Number of retry attempts for transient repair failures.

.PARAMETER MinimumFreeSpaceGB
    Minimum free space required on the system drive before repairs continue.

.PARAMETER RepairSourcePath
    Optional DISM repair source such as:
    - D:\sources\install.wim:1
    - D:\sources\install.esd:1
    - C:\Repair\Windows

.PARAMETER UseCadenceControl
    Checkbox-style string. When true, heavy maintenance tasks are skipped until due.

.PARAMETER MediumMaintenanceCadenceDays
    Cadence for medium-cost tasks such as ScanHealth and AnalyzeComponentStore.

.PARAMETER HeavyMaintenanceCadenceDays
    Cadence for heavier tasks such as CHKDSK scan, RestoreHealth, StartComponentCleanup, and SFC.

.PARAMETER RunDeliveryOptimizationCacheCleanup
    Checkbox-style string. When true, removes stale Delivery Optimization cache content older than the configured age.

.PARAMETER DeliveryOptimizationMaxAgeDays
    Age threshold in days for stale Delivery Optimization cache entries.

.PARAMETER LogRetentionDays
    Number of days to retain old maintenance logs before pruning.

.PARAMETER ExitCodeMode
    Strict returns warning and reboot-specific exit codes. NinjaFriendly returns 0 for handled warnings or reboot-
    required outcomes to align with simple RMM wrappers.

.PARAMETER ResultFieldName
    Optional NinjaOne custom field name for a short maintenance summary.

.PARAMETER DetailsFieldName
    Optional NinjaOne custom field name for a longer maintenance detail summary.

.NOTES
    Author:       Jevon Thompson
    Updated By:   OpenCode
    Version:      5.0.0
    Date:         2026-03-18
    Run As:       System or Administrator
    Timeout:      Up to several hours depending on servicing state
    Exit Codes:   0=Success, 1=Partial, 2=Critical, 100=Nothing to do, 3010=Reboot needed

    NinjaOne Script Variables:
        - DismTimeoutMinutes (Integer)
        - SfcTimeoutMinutes (Integer)
        - ChkdskTimeoutMinutes (Integer)
        - MaxRetries (Integer)
        - MinimumFreeSpaceGB (Integer)
        - RunChkdskScan (Checkbox)
        - RunCheckHealth (Checkbox)
        - RunScanHealth (Checkbox)
        - RunRestoreHealth (Checkbox)
        - RunAnalyzeComponentStore (Checkbox)
        - RunStartComponentCleanup (Checkbox)
        - RunSfc (Checkbox)
        - ResetWindowsUpdateComponents (Checkbox)
        - LimitAccess (Checkbox)
        - RepairSourcePath (String)
        - UseCadenceControl (Checkbox)
        - MediumMaintenanceCadenceDays (Integer)
        - HeavyMaintenanceCadenceDays (Integer)
        - RunDeliveryOptimizationCacheCleanup (Checkbox)
        - DeliveryOptimizationMaxAgeDays (Integer)
        - LogRetentionDays (Integer)
        - ExitCodeMode (String)
        - ResultFieldName (String)
        - DetailsFieldName (String)

    NinjaOne Custom Fields Required:
        - None. Optional only if ResultFieldName and DetailsFieldName are supplied.
#>

[CmdletBinding()]
param(
    [ValidateRange(30, 240)]
    [int]$DismTimeoutMinutes = 120,

    [ValidateRange(15, 180)]
    [int]$SfcTimeoutMinutes = 90,

    [ValidateRange(15, 180)]
    [int]$ChkdskTimeoutMinutes = 60,

    [ValidateRange(0, 3)]
    [int]$MaxRetries = 1,

    [ValidateRange(5, 50)]
    [int]$MinimumFreeSpaceGB = 10,

    [string]$RunChkdskScan = 'true',
    [string]$RunCheckHealth = 'true',
    [string]$RunScanHealth = 'true',
    [string]$RunRestoreHealth = 'true',
    [string]$RunAnalyzeComponentStore = 'true',
    [string]$RunStartComponentCleanup = 'true',
    [string]$RunSfc = 'true',
    [string]$ResetWindowsUpdateComponents = 'false',
    [string]$LimitAccess = 'false',
    [string]$RepairSourcePath = '',
    [string]$UseCadenceControl = 'true',

    [ValidateRange(1, 30)]
    [int]$MediumMaintenanceCadenceDays = 3,

    [ValidateRange(1, 60)]
    [int]$HeavyMaintenanceCadenceDays = 7,

    [string]$RunDeliveryOptimizationCacheCleanup = 'false',

    [ValidateRange(1, 180)]
    [int]$DeliveryOptimizationMaxAgeDays = 30,

    [ValidateRange(7, 365)]
    [int]$LogRetentionDays = 30,

    [ValidateSet('Strict', 'NinjaFriendly', IgnoreCase = $true)]
    [string]$ExitCodeMode = 'NinjaFriendly',

    [ValidateLength(0, 128)]
    [string]$ResultFieldName = '',

    [ValidateLength(0, 128)]
    [string]$DetailsFieldName = ''
)

$ErrorActionPreference = 'Stop'

$SCRIPT_VERSION = '5.0.0'
$SCRIPT_NAME = 'sfcDism'
$script:transcriptStarted = $false

$Script:ExitCodeMap = @{
    Success        = 0
    Partial        = 1
    Critical       = 2
    NothingToDo    = 100
    RebootRequired = 3010
}

$Script:Config = @{
    LogDirectory        = 'C:\ProgramData\Scripts\Logs\sfcDism'
    StateDirectory      = 'C:\ProgramData\Scripts\State\sfcDism'
    LogPath             = ''
    TranscriptPath      = ''
    StatePath           = 'C:\ProgramData\Scripts\State\sfcDism\MaintenanceState.clixml'
    DismLogPath         = 'C:\Windows\Logs\DISM\dism.log'
    CbsLogPath          = 'C:\Windows\Logs\CBS\CBS.log'
    SystemDrive         = $env:SystemDrive
    DeliveryOptCache    = 'C:\ProgramData\Microsoft\Windows\DeliveryOptimization\Cache'
}

$Script:RequiredServices = @(
    @{ Name = 'TrustedInstaller'; DisplayName = 'Windows Modules Installer'; StartIfStopped = $true },
    @{ Name = 'wuauserv'; DisplayName = 'Windows Update'; StartIfStopped = $true },
    @{ Name = 'CryptSvc'; DisplayName = 'Cryptographic Services'; StartIfStopped = $true },
    @{ Name = 'BITS'; DisplayName = 'Background Intelligent Transfer Service'; StartIfStopped = $true }
)

$Script:RepairResults = New-Object 'System.Collections.Generic.List[psobject]'

function Convert-ToBoolean {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    $normalizedValue = $Value.Trim().ToLowerInvariant()
    if ($normalizedValue -eq 'true' -or
        $normalizedValue -eq '1' -or
        $normalizedValue -eq 'yes' -or
        $normalizedValue -eq 'on') {
        return $true
    }

    return $false
}

function Get-ResolvedStringValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EnvironmentName,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$CurrentValue
    )

    $environmentValue = [Environment]::GetEnvironmentVariable($EnvironmentName)
    if (-not [string]::IsNullOrWhiteSpace($environmentValue)) {
        return $environmentValue
    }

    return $CurrentValue
}

function Get-ResolvedIntValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EnvironmentName,

        [Parameter(Mandatory = $true)]
        [int]$CurrentValue,

        [Parameter(Mandatory = $true)]
        [int]$Minimum,

        [Parameter(Mandatory = $true)]
        [int]$Maximum
    )

    $environmentValue = [Environment]::GetEnvironmentVariable($EnvironmentName)
    if ([string]::IsNullOrWhiteSpace($environmentValue)) {
        return $CurrentValue
    }

    $parsedValue = 0
    if (-not [int]::TryParse($environmentValue, [ref]$parsedValue)) {
        throw "Environment value '$EnvironmentName' must be an integer. Received '$environmentValue'."
    }

    if ($parsedValue -lt $Minimum -or $parsedValue -gt $Maximum) {
        throw "Environment value '$EnvironmentName' must be between $Minimum and $Maximum. Received '$parsedValue'."
    }

    return $parsedValue
}

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = '[{0}] [{1}] {2}' -f $timestamp, $Level, $Message

    if (-not [string]::IsNullOrWhiteSpace($Script:Config.LogPath)) {
        try {
            Add-Content -Path $Script:Config.LogPath -Value $logEntry -Encoding UTF8 -ErrorAction Stop
        } catch {
        }
    }

    switch ($Level) {
        'ERROR' { Write-Host $logEntry -ForegroundColor Red }
        'WARN' { Write-Host $logEntry -ForegroundColor Yellow }
        'SUCCESS' { Write-Host $logEntry -ForegroundColor Green }
        default { Write-Host $logEntry -ForegroundColor Gray }
    }
}

function Test-IsAdministrator {
    [CmdletBinding()]
    param()

    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-IsSystem {
    [CmdletBinding()]
    param()

    return [Security.Principal.WindowsIdentity]::GetCurrent().IsSystem
}

function Initialize-Paths {
    [CmdletBinding()]
    param()

    foreach ($targetDirectory in @($Script:Config.LogDirectory, $Script:Config.StateDirectory)) {
        if (-not (Test-Path -LiteralPath $targetDirectory)) {
            New-Item -Path $targetDirectory -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
    }

    $timeStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $Script:Config.LogPath = Join-Path -Path $Script:Config.LogDirectory -ChildPath ('sfcDism_{0}.log' -f $timeStamp)
    $Script:Config.TranscriptPath = Join-Path -Path $Script:Config.LogDirectory -ChildPath ('sfcDism_Transcript_{0}.log' -f $timeStamp)

    foreach ($oldLogFile in (Get-ChildItem -Path $Script:Config.LogDirectory -File -ErrorAction Stop)) {
        if ($oldLogFile.LastWriteTime -lt (Get-Date).AddDays(-$LogRetentionDays)) {
            try {
                Remove-Item -LiteralPath $oldLogFile.FullName -Force -ErrorAction Stop
            } catch {
                $currentError = $_
                Write-Host ('[WARN] Could not prune old log file {0}: {1}' -f $oldLogFile.FullName, $currentError.Exception.Message) -ForegroundColor Yellow
            }
        }
    }
}

function Start-RunTranscript {
    [CmdletBinding()]
    param()

    try {
        Start-Transcript -Path $Script:Config.TranscriptPath -Force -ErrorAction Stop | Out-Null
        $script:transcriptStarted = $true
    } catch {
        $currentError = $_
        Write-Host ('[WARN] Transcript could not be started: {0}' -f $currentError.Exception.Message) -ForegroundColor Yellow
    }
}

function Stop-RunTranscript {
    [CmdletBinding()]
    param()

    if ($script:transcriptStarted) {
        try {
            Stop-Transcript -ErrorAction Stop | Out-Null
        } catch {
        }
    }
}

function New-StepResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$State,

        [Parameter(Mandatory = $true)]
        [bool]$Success,

        [Parameter(Mandatory = $true)]
        [int]$ExitCode,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [bool]$TimedOut = $false,

        [Parameter(Mandatory = $false)]
        [bool]$RebootRequired = $false,

        [Parameter(Mandatory = $false)]
        [bool]$Critical = $false,

        [Parameter(Mandatory = $false)]
        [bool]$Skipped = $false
    )

    return [PSCustomObject]@{
        Name           = $Name
        State          = $State
        Success        = $Success
        ExitCode       = $ExitCode
        Message        = $Message
        TimedOut       = $TimedOut
        RebootRequired = $RebootRequired
        Critical       = $Critical
        Skipped        = $Skipped
    }
}

function Add-RepairResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Result
    )

    $Script:RepairResults.Add($Result) | Out-Null
}

function Write-StepResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Result
    )

    if ($Result.Critical) {
        Write-Log -Message $Result.Message -Level 'ERROR'
        return
    }

    if ($Result.Skipped) {
        Write-Log -Message $Result.Message -Level 'INFO'
        return
    }

    if ($Result.Success) {
        Write-Log -Message $Result.Message -Level 'SUCCESS'
        return
    }

    Write-Log -Message $Result.Message -Level 'WARN'
}

function Test-CommandAvailable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $commandInfo = Get-Command -Name $Name -ErrorAction SilentlyContinue
    return ($null -ne $commandInfo)
}

function Get-OsDetails {
    [CmdletBinding()]
    param()

    $operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    $buildNumber = 0
    if (-not [int]::TryParse($operatingSystem.BuildNumber, [ref]$buildNumber)) {
        $buildNumber = 0
    }

    return [PSCustomObject]@{
        Caption          = $operatingSystem.Caption
        Version          = $operatingSystem.Version
        BuildNumber      = $buildNumber
        Manufacturer     = $computerSystem.Manufacturer
        Model            = $computerSystem.Model
        IsWindows11OrNew = ($buildNumber -ge 22000)
    }
}

function Get-SystemDriveFreeSpaceGB {
    [CmdletBinding()]
    param()

    $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter ("DeviceID='{0}'" -f $Script:Config.SystemDrive) -ErrorAction Stop
    return [math]::Round(($disk.FreeSpace / 1GB), 2)
}

function Test-PendingReboot {
    [CmdletBinding()]
    param()

    $pendingReasons = New-Object 'System.Collections.Generic.List[string]'

    if (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
        $pendingReasons.Add('CBS RebootPending') | Out-Null
    }

    if (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
        $pendingReasons.Add('Windows Update RebootRequired') | Out-Null
    }

    try {
        $sessionManager = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction Stop
        if ($null -ne $sessionManager.PendingFileRenameOperations) {
            $pendingReasons.Add('PendingFileRenameOperations') | Out-Null
        }
    } catch {
    }

    return [PSCustomObject]@{
        Pending = ($pendingReasons.Count -gt 0)
        Reasons = $pendingReasons
    }
}

function Get-CleanOutputLines {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Text,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 50)]
        [int]$MaxLines = 15
    )

    $cleanLines = New-Object 'System.Collections.Generic.List[string]'
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $cleanLines
    }

    foreach ($rawLine in ($Text -split "`r`n|`n")) {
        if ([string]::IsNullOrWhiteSpace($rawLine)) {
            continue
        }

        $cleanLine = $rawLine.Replace([char]0, [char]32).Trim()
        if ([string]::IsNullOrWhiteSpace($cleanLine)) {
            continue
        }

        while ($cleanLine.Contains('  ')) {
            $cleanLine = $cleanLine.Replace('  ', ' ')
        }

        $cleanLines.Add($cleanLine) | Out-Null
    }

    if ($cleanLines.Count -le $MaxLines) {
        return $cleanLines
    }

    $trimmedLines = New-Object 'System.Collections.Generic.List[string]'
    for ($lineIndex = $cleanLines.Count - $MaxLines; $lineIndex -lt $cleanLines.Count; $lineIndex++) {
        $trimmedLines.Add($cleanLines[$lineIndex]) | Out-Null
    }

    return $trimmedLines
}

function Write-CommandOutputSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$Output,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 50)]
        [int]$MaxLines = 12
    )

    $linesToWrite = Get-CleanOutputLines -Text $Output -MaxLines $MaxLines
    if ($linesToWrite.Count -eq 0) {
        return
    }

    Write-Log -Message ('{0} output summary:' -f $Name)
    foreach ($lineToWrite in $linesToWrite) {
        Write-Log -Message ('  {0}' -f $lineToWrite)
    }
}

function Ensure-RequiredServices {
    [CmdletBinding()]
    param()

    $allServicesReady = $true
    Write-Log -Message 'Checking servicing prerequisites...'

    foreach ($serviceDefinition in $Script:RequiredServices) {
        $serviceName = $serviceDefinition.Name
        $serviceDisplayName = $serviceDefinition.DisplayName

        try {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($null -eq $service) {
                Write-Log -Message ("Service '{0}' ({1}) not found on this device." -f $serviceDisplayName, $serviceName) -Level 'WARN'
                continue
            }

            $serviceInstance = Get-CimInstance -ClassName Win32_Service -Filter ("Name='{0}'" -f $serviceName) -ErrorAction Stop
            if ($serviceInstance.StartMode -eq 'Disabled') {
                Write-Log -Message ("Service '{0}' is disabled. Setting StartupType to Manual." -f $serviceDisplayName) -Level 'WARN'
                Set-Service -Name $serviceName -StartupType Manual -ErrorAction Stop
            }

            if ($serviceDefinition.StartIfStopped -and $service.Status -ne 'Running') {
                Write-Log -Message ("Starting service '{0}'." -f $serviceDisplayName)
                Start-Service -Name $serviceName -ErrorAction Stop
                $service.WaitForStatus('Running', [TimeSpan]::FromSeconds(30))
                Write-Log -Message ("Service '{0}' is running." -f $serviceDisplayName) -Level 'SUCCESS'
            } else {
                Write-Log -Message ("Service '{0}' status: {1}." -f $serviceDisplayName, $service.Status)
            }
        } catch {
            $currentError = $_
            Write-Log -Message ("Failed to prepare service '{0}': {1}" -f $serviceDisplayName, $currentError.Exception.Message) -Level 'ERROR'
            $allServicesReady = $false
        }
    }

    return $allServicesReady
}

function Test-RepairSourcePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $true
    }

    $normalizedPath = $Path
    if ($Path.Contains(':') -and $Path -match '^[A-Za-z]:\\') {
        $lastColonIndex = $Path.LastIndexOf(':')
        if ($lastColonIndex -gt 1) {
            $possibleIndex = $Path.Substring($lastColonIndex + 1)
            if ($possibleIndex -match '^[0-9]+$') {
                $normalizedPath = $Path.Substring(0, $lastColonIndex)
            }
        }
    }

    return (Test-Path -LiteralPath $normalizedPath)
}

function Invoke-NativeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string]$Arguments,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 240)]
        [int]$TimeoutMinutes,

        [Parameter(Mandatory = $true)]
        [string]$DisplayName
    )

    $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processStartInfo.FileName = $FilePath
    $processStartInfo.Arguments = $Arguments
    $processStartInfo.UseShellExecute = $false
    $processStartInfo.RedirectStandardOutput = $true
    $processStartInfo.RedirectStandardError = $true
    $processStartInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processStartInfo

    try {
        Write-Log -Message ('Starting {0}: {1} {2}' -f $DisplayName, $FilePath, $Arguments)

        [void]$process.Start()

        $startTime = Get-Date
        $lastProgressLog = $startTime
        $timeoutWindow = [TimeSpan]::FromMinutes($TimeoutMinutes)

        while (-not $process.HasExited) {
            Start-Sleep -Seconds 2
            $elapsedTime = (Get-Date) - $startTime

            if ($elapsedTime -ge $timeoutWindow) {
                Write-Log -Message ('{0} timed out after {1} minutes.' -f $DisplayName, $TimeoutMinutes) -Level 'ERROR'
                try {
                    $process.Kill()
                    $process.WaitForExit()
                } catch {
                }

                return [PSCustomObject]@{
                    Success         = $false
                    ExitCode        = -1
                    TimedOut        = $true
                    Output          = ''
                    Error           = ''
                    DurationMinutes = [math]::Round($elapsedTime.TotalMinutes, 2)
                }
            }

            if (((Get-Date) - $lastProgressLog).TotalMinutes -ge 5) {
                Write-Log -Message ('{0} still running after {1} minutes.' -f $DisplayName, [math]::Round($elapsedTime.TotalMinutes, 1))
                $lastProgressLog = Get-Date
            }
        }

        $process.WaitForExit()
        $standardOutput = $process.StandardOutput.ReadToEnd()
        $standardError = $process.StandardError.ReadToEnd()
        $duration = (Get-Date) - $startTime
        $nativeExitCode = $process.ExitCode
        return [PSCustomObject]@{
            Success         = ($nativeExitCode -eq 0)
            ExitCode        = $nativeExitCode
            TimedOut        = $false
            Output          = $standardOutput
            Error           = $standardError
            DurationMinutes = [math]::Round($duration.TotalMinutes, 2)
        }
    } catch {
        $currentError = $_
        Write-Log -Message ('{0} failed to start or complete: {1}' -f $DisplayName, $currentError.Exception.Message) -Level 'ERROR'
        return [PSCustomObject]@{
            Success         = $false
            ExitCode        = -1
            TimedOut        = $false
            Output          = ''
            Error           = $currentError.Exception.Message
            DurationMinutes = 0
        }
    } finally {
        if ($null -ne $process) {
            $process.Dispose()
        }
    }
}

function Clear-WindowsUpdateDownloadCache {
    [CmdletBinding()]
    param()

    Write-Log -Message 'Clearing Windows Update download cache before DISM retry.' -Level 'WARN'

    foreach ($serviceName in @('BITS', 'wuauserv')) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($null -ne $service -and $service.Status -eq 'Running') {
                Stop-Service -Name $serviceName -Force -ErrorAction Stop
                Write-Log -Message ('Stopped service {0}.' -f $serviceName)
            }
        } catch {
            $currentError = $_
            Write-Log -Message ('Unable to stop service {0}: {1}' -f $serviceName, $currentError.Exception.Message) -Level 'WARN'
        }
    }

    try {
        $downloadPath = Join-Path -Path $env:SystemRoot -ChildPath 'SoftwareDistribution\Download'
        if (Test-Path -LiteralPath $downloadPath) {
            foreach ($downloadItem in (Get-ChildItem -LiteralPath $downloadPath -Force -ErrorAction Stop)) {
                Remove-Item -LiteralPath $downloadItem.FullName -Recurse -Force -ErrorAction Stop
            }
            Write-Log -Message 'Windows Update download cache cleared.' -Level 'SUCCESS'
        }
    } catch {
        $currentError = $_
        Write-Log -Message ('Unable to clear Windows Update cache: {0}' -f $currentError.Exception.Message) -Level 'WARN'
    } finally {
        foreach ($serviceName in @('BITS', 'wuauserv')) {
            try {
                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if ($null -ne $service -and $service.Status -ne 'Running') {
                    Start-Service -Name $serviceName -ErrorAction Stop
                    Write-Log -Message ('Started service {0}.' -f $serviceName)
                }
            } catch {
                $currentError = $_
                Write-Log -Message ('Unable to start service {0}: {1}' -f $serviceName, $currentError.Exception.Message) -Level 'WARN'
            }
        }
    }
}

function Invoke-DeliveryOptimizationCleanup {
    [CmdletBinding()]
    param()

    if (-not (Test-Path -LiteralPath $Script:Config.DeliveryOptCache)) {
        return (New-StepResult -Name 'Delivery Optimization Cache Cleanup' -State 'Skipped' -Success $true -ExitCode 100 -Message 'Delivery Optimization cache path not present.' -Skipped $true)
    }

    $removedCount = 0
    $removedBytes = [double]0
    $cutoffTime = (Get-Date).AddDays(-$DeliveryOptimizationMaxAgeDays)

    try {
        $service = Get-Service -Name 'dosvc' -ErrorAction SilentlyContinue
        if ($null -ne $service -and $service.Status -eq 'Running') {
            Stop-Service -Name 'dosvc' -Force -ErrorAction Stop
            Write-Log -Message 'Stopped Delivery Optimization service for cache maintenance.'
        }
    } catch {
        $currentError = $_
        Write-Log -Message ('Could not stop Delivery Optimization service: {0}' -f $currentError.Exception.Message) -Level 'WARN'
    }

    try {
        foreach ($cacheItem in (Get-ChildItem -LiteralPath $Script:Config.DeliveryOptCache -Force -ErrorAction Stop)) {
            if ($cacheItem.LastWriteTime -gt $cutoffTime) {
                continue
            }

            if (-not $cacheItem.PSIsContainer) {
                $removedBytes += [double]$cacheItem.Length
            }

            Remove-Item -LiteralPath $cacheItem.FullName -Recurse -Force -ErrorAction Stop
            $removedCount++
        }
    } catch {
        $currentError = $_
        return (New-StepResult -Name 'Delivery Optimization Cache Cleanup' -State 'Warning' -Success $false -ExitCode 1 -Message ('Delivery Optimization cache cleanup encountered an issue: {0}' -f $currentError.Exception.Message))
    } finally {
        try {
            $service = Get-Service -Name 'dosvc' -ErrorAction SilentlyContinue
            if ($null -ne $service -and $service.Status -ne 'Running') {
                Start-Service -Name 'dosvc' -ErrorAction Stop
                Write-Log -Message 'Restarted Delivery Optimization service after cache maintenance.'
            }
        } catch {
            $currentError = $_
            Write-Log -Message ('Could not restart Delivery Optimization service: {0}' -f $currentError.Exception.Message) -Level 'WARN'
        }
    }

    return (New-StepResult -Name 'Delivery Optimization Cache Cleanup' -State 'Success' -Success $true -ExitCode 0 -Message ('Delivery Optimization cleanup removed {0} stale item(s), reclaiming approximately {1} MB.' -f $removedCount, [math]::Round(($removedBytes / 1MB), 2)))
}

function Invoke-DismOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Arguments,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 240)]
        [int]$TimeoutMinutes,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 3)]
        [int]$RetryCount = 0,

        [Parameter(Mandatory = $false)]
        [bool]$AllowCacheResetRetry = $false
    )

    $attemptNumber = $RetryCount + 1
    $maxAttempts = $MaxRetries + 1
    Write-Log -Message ('Running {0} (attempt {1} of {2}).' -f $Name, $attemptNumber, $maxAttempts)

    $commandResult = Invoke-NativeCommand -FilePath 'dism.exe' -Arguments $Arguments -TimeoutMinutes $TimeoutMinutes -DisplayName $Name
    Write-CommandOutputSummary -Name $Name -Output $commandResult.Output -MaxLines 15
    if (-not [string]::IsNullOrWhiteSpace($commandResult.Error)) {
        Write-CommandOutputSummary -Name ('{0} stderr' -f $Name) -Output $commandResult.Error -MaxLines 8
    }

    if ($commandResult.TimedOut) {
        if ($RetryCount -lt $MaxRetries) {
            Write-Log -Message ('{0} timed out and will be retried.' -f $Name) -Level 'WARN'
            return Invoke-DismOperation -Name $Name -Arguments $Arguments -TimeoutMinutes $TimeoutMinutes -RetryCount ($RetryCount + 1) -AllowCacheResetRetry $AllowCacheResetRetry
        }

        return (New-StepResult -Name $Name -State 'Critical' -Success $false -ExitCode -1 -Message ('{0} timed out.' -f $Name) -TimedOut $true -Critical $true)
    }

    if ($commandResult.ExitCode -eq 0) {
        return (New-StepResult -Name $Name -State 'Success' -Success $true -ExitCode 0 -Message ('{0} completed successfully.' -f $Name))
    }

    if ($commandResult.ExitCode -eq 3010) {
        return (New-StepResult -Name $Name -State 'Success' -Success $true -ExitCode 3010 -Message ('{0} completed and a reboot is required.' -f $Name) -RebootRequired $true)
    }

    if ($commandResult.ExitCode -eq 1726 -and $RetryCount -lt $MaxRetries) {
        Write-Log -Message ('{0} returned RPC error 1726 and will be retried.' -f $Name) -Level 'WARN'
        Start-Sleep -Seconds 15
        return Invoke-DismOperation -Name $Name -Arguments $Arguments -TimeoutMinutes $TimeoutMinutes -RetryCount ($RetryCount + 1) -AllowCacheResetRetry $AllowCacheResetRetry
    }

    if ($AllowCacheResetRetry -and (Convert-ToBoolean -Value $ResetWindowsUpdateComponents) -and $RetryCount -lt $MaxRetries) {
        Write-Log -Message ('{0} failed with exit code {1}. Clearing Windows Update cache and retrying once.' -f $Name, $commandResult.ExitCode) -Level 'WARN'
        Clear-WindowsUpdateDownloadCache
        return Invoke-DismOperation -Name $Name -Arguments $Arguments -TimeoutMinutes $TimeoutMinutes -RetryCount ($RetryCount + 1) -AllowCacheResetRetry $false
    }

    return (New-StepResult -Name $Name -State 'Critical' -Success $false -ExitCode $commandResult.ExitCode -Message ('{0} failed with exit code {1}. Review {2}.' -f $Name, $commandResult.ExitCode, $Script:Config.DismLogPath) -Critical $true)
}

function Invoke-ChkdskScanStep {
    [CmdletBinding()]
    param()

    $commandResult = Invoke-NativeCommand -FilePath 'chkdsk.exe' -Arguments ('{0} /scan' -f $Script:Config.SystemDrive) -TimeoutMinutes $ChkdskTimeoutMinutes -DisplayName 'CHKDSK'
    Write-CommandOutputSummary -Name 'CHKDSK' -Output $commandResult.Output -MaxLines 12

    if ($commandResult.TimedOut) {
        return (New-StepResult -Name 'CHKDSK /scan' -State 'Critical' -Success $false -ExitCode -1 -Message 'CHKDSK timed out.' -TimedOut $true -Critical $true)
    }

    $outputLower = $commandResult.Output.ToLowerInvariant()
    if ($outputLower.Contains('found no problems')) {
        return (New-StepResult -Name 'CHKDSK /scan' -State 'Success' -Success $true -ExitCode $commandResult.ExitCode -Message 'CHKDSK found no file system problems.')
    }

    if ($outputLower.Contains('successfully scanned the file system') -or $outputLower.Contains('successfully repaired')) {
        return (New-StepResult -Name 'CHKDSK /scan' -State 'Success' -Success $true -ExitCode $commandResult.ExitCode -Message 'CHKDSK completed successfully.')
    }

    if ($outputLower.Contains('cannot run because the volume is in use') -or $outputLower.Contains('run chkdsk /f')) {
        return (New-StepResult -Name 'CHKDSK /scan' -State 'Warning' -Success $false -ExitCode 3010 -Message 'CHKDSK indicates an offline repair may be required after reboot.' -RebootRequired $true)
    }

    if ($commandResult.ExitCode -eq 0) {
        return (New-StepResult -Name 'CHKDSK /scan' -State 'Success' -Success $true -ExitCode 0 -Message 'CHKDSK completed.')
    }

    return (New-StepResult -Name 'CHKDSK /scan' -State 'Critical' -Success $false -ExitCode $commandResult.ExitCode -Message ('CHKDSK returned exit code {0}.' -f $commandResult.ExitCode) -Critical $true)
}

function Invoke-SfcStep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 3)]
        [int]$RetryCount = 0
    )

    $attemptNumber = $RetryCount + 1
    $maxAttempts = $MaxRetries + 1
    Write-Log -Message ('Running SFC /scannow (attempt {0} of {1}).' -f $attemptNumber, $maxAttempts)

    $trustedInstaller = Get-Service -Name 'TrustedInstaller' -ErrorAction SilentlyContinue
    if ($null -ne $trustedInstaller -and $trustedInstaller.Status -ne 'Running') {
        try {
            Start-Service -Name 'TrustedInstaller' -ErrorAction Stop
            Write-Log -Message 'Started TrustedInstaller before SFC.'
        } catch {
            $currentError = $_
            Write-Log -Message ('Unable to start TrustedInstaller before SFC: {0}' -f $currentError.Exception.Message) -Level 'WARN'
        }
    }

    $commandResult = Invoke-NativeCommand -FilePath 'sfc.exe' -Arguments '/scannow' -TimeoutMinutes $SfcTimeoutMinutes -DisplayName 'SFC'
    Write-CommandOutputSummary -Name 'SFC' -Output $commandResult.Output -MaxLines 12

    if ($commandResult.TimedOut) {
        if ($RetryCount -lt $MaxRetries) {
            Write-Log -Message 'SFC timed out and will be retried.' -Level 'WARN'
            return Invoke-SfcStep -RetryCount ($RetryCount + 1)
        }

        return (New-StepResult -Name 'SFC /scannow' -State 'Critical' -Success $false -ExitCode -1 -Message 'SFC timed out.' -TimedOut $true -Critical $true)
    }

    $outputLower = $commandResult.Output.ToLowerInvariant()
    if ($outputLower.Contains('did not find any integrity violations')) {
        return (New-StepResult -Name 'SFC /scannow' -State 'Success' -Success $true -ExitCode 0 -Message 'SFC found no integrity violations.')
    }

    if ($outputLower.Contains('found corrupt files and successfully repaired them')) {
        return (New-StepResult -Name 'SFC /scannow' -State 'Success' -Success $true -ExitCode 0 -Message 'SFC repaired corrupt files.')
    }

    if ($outputLower.Contains('found corrupt files but was unable to fix some of them')) {
        return (New-StepResult -Name 'SFC /scannow' -State 'Warning' -Success $false -ExitCode 1 -Message ('SFC found unrepairable corruption. Review {0}.' -f $Script:Config.CbsLogPath))
    }

    if ($outputLower.Contains('could not perform the requested operation') -or $outputLower.Contains('could not start the repair service')) {
        if ($RetryCount -lt $MaxRetries) {
            Write-Log -Message 'SFC could not access the repair service. Re-preparing services and retrying.' -Level 'WARN'
            [void](Ensure-RequiredServices)
            Start-Sleep -Seconds 10
            return Invoke-SfcStep -RetryCount ($RetryCount + 1)
        }

        return (New-StepResult -Name 'SFC /scannow' -State 'Critical' -Success $false -ExitCode 2 -Message 'SFC could not access the repair service.' -Critical $true)
    }

    if ($commandResult.ExitCode -eq 0) {
        return (New-StepResult -Name 'SFC /scannow' -State 'Success' -Success $true -ExitCode 0 -Message 'SFC completed successfully.')
    }

    return (New-StepResult -Name 'SFC /scannow' -State 'Warning' -Success $false -ExitCode $commandResult.ExitCode -Message ('SFC failed with exit code {0}.' -f $commandResult.ExitCode))
}

function Write-CbsSummary {
    [CmdletBinding()]
    param()

    if (-not (Test-Path -LiteralPath $Script:Config.CbsLogPath)) {
        return
    }

    try {
        $cbsTail = Get-Content -Path $Script:Config.CbsLogPath -Tail 250 -ErrorAction Stop
        $srLines = New-Object 'System.Collections.Generic.List[string]'
        foreach ($cbsLine in $cbsTail) {
            if ($cbsLine.Contains('[SR]')) {
                $srLines.Add($cbsLine.Trim()) | Out-Null
            }
        }

        if ($srLines.Count -eq 0) {
            return
        }

        Write-Log -Message 'CBS [SR] summary:' -Level 'WARN'
        $startIndex = 0
        if ($srLines.Count -gt 10) {
            $startIndex = $srLines.Count - 10
        }

        for ($lineIndex = $startIndex; $lineIndex -lt $srLines.Count; $lineIndex++) {
            Write-Log -Message ('  {0}' -f $srLines[$lineIndex]) -Level 'WARN'
        }
    } catch {
        $currentError = $_
        Write-Log -Message ('Unable to summarize CBS.log: {0}' -f $currentError.Exception.Message) -Level 'WARN'
    }
}

function Get-DismRestoreArguments {
    [CmdletBinding()]
    param()

    $argumentText = '/Online /Cleanup-Image /RestoreHealth'
    if (-not [string]::IsNullOrWhiteSpace($RepairSourcePath)) {
        $argumentText = '{0} /Source:"{1}"' -f $argumentText, $RepairSourcePath
        if (Convert-ToBoolean -Value $LimitAccess) {
            $argumentText = '{0} /LimitAccess' -f $argumentText
        }
    }

    return $argumentText
}

function Write-NinjaField {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FieldName,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($FieldName)) {
        return $false
    }

    $commandInfo = Get-Command -Name 'Ninja-Property-Set' -ErrorAction SilentlyContinue
    if ($null -eq $commandInfo) {
        return $false
    }

    try {
        Ninja-Property-Set $FieldName $Value
        return $true
    } catch {
        return $false
    }
}

function Get-NewMaintenanceState {
    [CmdletBinding()]
    param()

    return [PSCustomObject]@{
        Version = 1
        Steps   = @{}
    }
}

function Get-MaintenanceState {
    [CmdletBinding()]
    param()

    if (-not (Test-Path -LiteralPath $Script:Config.StatePath)) {
        return (Get-NewMaintenanceState)
    }

    try {
        $loadedState = Import-Clixml -Path $Script:Config.StatePath -ErrorAction Stop
        if ($null -eq $loadedState -or $null -eq $loadedState.Steps) {
            return (Get-NewMaintenanceState)
        }

        return $loadedState
    } catch {
        $currentError = $_
        Write-Log -Message ('State file could not be read. Starting fresh: {0}' -f $currentError.Exception.Message) -Level 'WARN'
        return (Get-NewMaintenanceState)
    }
}

function Save-MaintenanceState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$State
    )

    Export-Clixml -Path $Script:Config.StatePath -InputObject $State -Force -ErrorAction Stop
}

function Get-StepLastSuccess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$State,

        [Parameter(Mandatory = $true)]
        [string]$StepName
    )

    if ($null -eq $State.Steps) {
        return $null
    }

    if (-not $State.Steps.ContainsKey($StepName)) {
        return $null
    }

    $rawValue = $State.Steps[$StepName]
    if ($null -eq $rawValue) {
        return $null
    }

    $parsedDate = Get-Date
    if ([datetime]::TryParse([string]$rawValue, [ref]$parsedDate)) {
        return $parsedDate
    }

    return $null
}

function Set-StepLastSuccess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$State,

        [Parameter(Mandatory = $true)]
        [string]$StepName
    )

    if ($null -eq $State.Steps) {
        $State.Steps = @{}
    }

    $State.Steps[$StepName] = (Get-Date).ToString('o')
}

function Test-StepDue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$State,

        [Parameter(Mandatory = $true)]
        [string]$StepName,

        [Parameter(Mandatory = $true)]
        [bool]$UseCadence,

        [Parameter(Mandatory = $true)]
        [int]$CadenceDays
    )

    if (-not $UseCadence) {
        return [PSCustomObject]@{
            Due = $true
            Message = 'Cadence control disabled'
        }
    }

    $lastSuccess = Get-StepLastSuccess -State $State -StepName $StepName
    if ($null -eq $lastSuccess) {
        return [PSCustomObject]@{
            Due = $true
            Message = 'No prior success recorded'
        }
    }

    $nextDueTime = $lastSuccess.AddDays($CadenceDays)
    if ((Get-Date) -ge $nextDueTime) {
        return [PSCustomObject]@{
            Due = $true
            Message = ('Cadence met; last success {0}' -f $lastSuccess)
        }
    }

    return [PSCustomObject]@{
        Due = $false
        Message = ('Skipped by cadence; last success {0}, next due {1}' -f $lastSuccess, $nextDueTime)
    }
}

function Get-SkippedStepResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StepName,

        [Parameter(Mandatory = $true)]
        [string]$Reason
    )

    return (New-StepResult -Name $StepName -State 'Skipped' -Success $true -ExitCode 100 -Message ('{0} skipped. {1}.' -f $StepName, $Reason) -Skipped $true)
}

function Invoke-Main {
    [CmdletBinding()]
    param()

    $runChkdskScanBool = Convert-ToBoolean -Value $RunChkdskScan
    $runCheckHealthBool = Convert-ToBoolean -Value $RunCheckHealth
    $runScanHealthBool = Convert-ToBoolean -Value $RunScanHealth
    $runRestoreHealthBool = Convert-ToBoolean -Value $RunRestoreHealth
    $runAnalyzeComponentStoreBool = Convert-ToBoolean -Value $RunAnalyzeComponentStore
    $runStartComponentCleanupBool = Convert-ToBoolean -Value $RunStartComponentCleanup
    $runSfcBool = Convert-ToBoolean -Value $RunSfc
    $resetWindowsUpdateComponentsBool = Convert-ToBoolean -Value $ResetWindowsUpdateComponents
    $limitAccessBool = Convert-ToBoolean -Value $LimitAccess
    $useCadenceControlBool = Convert-ToBoolean -Value $UseCadenceControl
    $runDeliveryOptimizationCacheCleanupBool = Convert-ToBoolean -Value $RunDeliveryOptimizationCacheCleanup

    Write-Log -Message '========================================'
    Write-Log -Message ('Scheduled Windows Maintenance {0}' -f $SCRIPT_VERSION)
    Write-Log -Message '========================================'
    Write-Log -Message ('Computer: {0}' -f $env:COMPUTERNAME)
    Write-Log -Message ('Identity: {0}' -f ([Security.Principal.WindowsIdentity]::GetCurrent().Name))
    Write-Log -Message ('SYSTEM: {0} | Admin: {1}' -f (Test-IsSystem), (Test-IsAdministrator))
    Write-Log -Message ('DISM Timeout: {0} min | SFC Timeout: {1} min | CHKDSK Timeout: {2} min' -f $DismTimeoutMinutes, $SfcTimeoutMinutes, $ChkdskTimeoutMinutes)
    Write-Log -Message ('Max Retries: {0} | Minimum Free Space: {1} GB' -f $MaxRetries, $MinimumFreeSpaceGB)
    Write-Log -Message ('Cadence Control: {0} | Medium Days: {1} | Heavy Days: {2}' -f $useCadenceControlBool, $MediumMaintenanceCadenceDays, $HeavyMaintenanceCadenceDays)
    Write-Log -Message ('Selected Steps: CHKDSK={0}, CheckHealth={1}, ScanHealth={2}, RestoreHealth={3}, AnalyzeStore={4}, StartCleanup={5}, SFC={6}, DOCache={7}' -f $runChkdskScanBool, $runCheckHealthBool, $runScanHealthBool, $runRestoreHealthBool, $runAnalyzeComponentStoreBool, $runStartComponentCleanupBool, $runSfcBool, $runDeliveryOptimizationCacheCleanupBool)

    $repairSourceSummary = 'Windows Update default'
    if (-not [string]::IsNullOrWhiteSpace($RepairSourcePath)) {
        $repairSourceSummary = $RepairSourcePath
    }

    Write-Log -Message ('Repair Source: {0} | LimitAccess: {1} | ResetWindowsUpdateComponents: {2} | ExitCodeMode: {3}' -f $repairSourceSummary, $limitAccessBool, $resetWindowsUpdateComponentsBool, $ExitCodeMode)

    if (-not (Test-IsAdministrator) -and -not (Test-IsSystem)) {
        Write-Log -Message 'Script requires Administrator or SYSTEM privileges.' -Level 'ERROR'
        return $Script:ExitCodeMap.Critical
    }

    $selectedStepCount = 0
    foreach ($selectedStep in @($runChkdskScanBool, $runCheckHealthBool, $runScanHealthBool, $runRestoreHealthBool, $runAnalyzeComponentStoreBool, $runStartComponentCleanupBool, $runSfcBool, $runDeliveryOptimizationCacheCleanupBool)) {
        if ($selectedStep) {
            $selectedStepCount++
        }
    }

    if ($selectedStepCount -eq 0) {
        Write-Log -Message 'No maintenance steps were selected.' -Level 'WARN'
        if ($ExitCodeMode.ToLowerInvariant() -eq 'ninjafriendly') {
            return $Script:ExitCodeMap.Success
        }

        return $Script:ExitCodeMap.NothingToDo
    }

    foreach ($requiredCommand in @('dism.exe', 'sfc.exe', 'chkdsk.exe')) {
        if (-not (Test-CommandAvailable -Name $requiredCommand)) {
            Write-Log -Message ('Required command not found: {0}' -f $requiredCommand) -Level 'ERROR'
            return $Script:ExitCodeMap.Critical
        }
    }

    if (-not (Test-RepairSourcePath -Path $RepairSourcePath)) {
        Write-Log -Message ('Repair source path not found: {0}' -f $RepairSourcePath) -Level 'ERROR'
        return $Script:ExitCodeMap.Critical
    }

    $osDetails = Get-OsDetails
    Write-Log -Message ('OS: {0} | Version: {1} | Build: {2}' -f $osDetails.Caption, $osDetails.Version, $osDetails.BuildNumber)
    Write-Log -Message ('Hardware: {0} {1}' -f $osDetails.Manufacturer, $osDetails.Model)
    if ($osDetails.IsWindows11OrNew) {
        Write-Log -Message 'Detected Windows 11 or newer servicing baseline.' -Level 'SUCCESS'
    } else {
        Write-Log -Message 'Device is not Windows 11. Continuing because DISM/SFC workflow is still supported.' -Level 'WARN'
    }

    $freeSpaceGB = Get-SystemDriveFreeSpaceGB
    Write-Log -Message ('Free space on {0}: {1} GB' -f $Script:Config.SystemDrive, $freeSpaceGB)
    if ($freeSpaceGB -lt $MinimumFreeSpaceGB) {
        Write-Log -Message ('Insufficient free space. Required: {0} GB. Available: {1} GB.' -f $MinimumFreeSpaceGB, $freeSpaceGB) -Level 'ERROR'
        return $Script:ExitCodeMap.Critical
    }

    $pendingRebootBefore = Test-PendingReboot
    if ($pendingRebootBefore.Pending) {
        foreach ($pendingReason in $pendingRebootBefore.Reasons) {
            Write-Log -Message ('Pending reboot detected before maintenance: {0}' -f $pendingReason) -Level 'WARN'
        }
    } else {
        Write-Log -Message 'No pending reboot state detected before maintenance.'
    }

    $servicesReady = Ensure-RequiredServices
    if (-not $servicesReady) {
        Write-Log -Message 'One or more servicing prerequisites could not be prepared.' -Level 'WARN'
    }

    $maintenanceState = Get-MaintenanceState

    if ($runChkdskScanBool) {
        $dueStatus = Test-StepDue -State $maintenanceState -StepName 'CHKDSK /scan' -UseCadence $useCadenceControlBool -CadenceDays $HeavyMaintenanceCadenceDays
        if ($dueStatus.Due) {
            $chkdskResult = Invoke-ChkdskScanStep
            Add-RepairResult -Result $chkdskResult
            Write-StepResult -Result $chkdskResult
            if ($chkdskResult.Success) {
                Set-StepLastSuccess -State $maintenanceState -StepName 'CHKDSK /scan'
            }
        } else {
            $chkdskSkipResult = Get-SkippedStepResult -StepName 'CHKDSK /scan' -Reason $dueStatus.Message
            Add-RepairResult -Result $chkdskSkipResult
            Write-StepResult -Result $chkdskSkipResult
        }
    }

    if ($runCheckHealthBool) {
        $checkHealthResult = Invoke-DismOperation -Name 'DISM CheckHealth' -Arguments '/Online /Cleanup-Image /CheckHealth' -TimeoutMinutes $DismTimeoutMinutes
        Add-RepairResult -Result $checkHealthResult
        Write-StepResult -Result $checkHealthResult
        if ($checkHealthResult.Success) {
            Set-StepLastSuccess -State $maintenanceState -StepName 'DISM CheckHealth'
        }
    }

    if ($runScanHealthBool) {
        $dueStatus = Test-StepDue -State $maintenanceState -StepName 'DISM ScanHealth' -UseCadence $useCadenceControlBool -CadenceDays $MediumMaintenanceCadenceDays
        if ($dueStatus.Due) {
            $scanHealthResult = Invoke-DismOperation -Name 'DISM ScanHealth' -Arguments '/Online /Cleanup-Image /ScanHealth' -TimeoutMinutes $DismTimeoutMinutes
            Add-RepairResult -Result $scanHealthResult
            Write-StepResult -Result $scanHealthResult
            if ($scanHealthResult.Success) {
                Set-StepLastSuccess -State $maintenanceState -StepName 'DISM ScanHealth'
            }
        } else {
            $scanHealthSkipResult = Get-SkippedStepResult -StepName 'DISM ScanHealth' -Reason $dueStatus.Message
            Add-RepairResult -Result $scanHealthSkipResult
            Write-StepResult -Result $scanHealthSkipResult
        }
    }

    if ($runRestoreHealthBool) {
        $dueStatus = Test-StepDue -State $maintenanceState -StepName 'DISM RestoreHealth' -UseCadence $useCadenceControlBool -CadenceDays $HeavyMaintenanceCadenceDays
        if ($dueStatus.Due) {
            $restoreHealthResult = Invoke-DismOperation -Name 'DISM RestoreHealth' -Arguments (Get-DismRestoreArguments) -TimeoutMinutes $DismTimeoutMinutes -AllowCacheResetRetry $true
            Add-RepairResult -Result $restoreHealthResult
            Write-StepResult -Result $restoreHealthResult
            if ($restoreHealthResult.Success) {
                Set-StepLastSuccess -State $maintenanceState -StepName 'DISM RestoreHealth'
            }
        } else {
            $restoreHealthSkipResult = Get-SkippedStepResult -StepName 'DISM RestoreHealth' -Reason $dueStatus.Message
            Add-RepairResult -Result $restoreHealthSkipResult
            Write-StepResult -Result $restoreHealthSkipResult
        }
    }

    if ($runAnalyzeComponentStoreBool) {
        $dueStatus = Test-StepDue -State $maintenanceState -StepName 'DISM AnalyzeComponentStore' -UseCadence $useCadenceControlBool -CadenceDays $MediumMaintenanceCadenceDays
        if ($dueStatus.Due) {
            $analyzeStoreResult = Invoke-DismOperation -Name 'DISM AnalyzeComponentStore' -Arguments '/Online /Cleanup-Image /AnalyzeComponentStore' -TimeoutMinutes $DismTimeoutMinutes
            Add-RepairResult -Result $analyzeStoreResult
            Write-StepResult -Result $analyzeStoreResult
            if ($analyzeStoreResult.Success) {
                Set-StepLastSuccess -State $maintenanceState -StepName 'DISM AnalyzeComponentStore'
            }
        } else {
            $analyzeStoreSkipResult = Get-SkippedStepResult -StepName 'DISM AnalyzeComponentStore' -Reason $dueStatus.Message
            Add-RepairResult -Result $analyzeStoreSkipResult
            Write-StepResult -Result $analyzeStoreSkipResult
        }
    }

    if ($runStartComponentCleanupBool) {
        $dueStatus = Test-StepDue -State $maintenanceState -StepName 'DISM StartComponentCleanup' -UseCadence $useCadenceControlBool -CadenceDays $HeavyMaintenanceCadenceDays
        if ($dueStatus.Due) {
            $cleanupResult = Invoke-DismOperation -Name 'DISM StartComponentCleanup' -Arguments '/Online /Cleanup-Image /StartComponentCleanup' -TimeoutMinutes $DismTimeoutMinutes
            Add-RepairResult -Result $cleanupResult
            Write-StepResult -Result $cleanupResult
            if ($cleanupResult.Success) {
                Set-StepLastSuccess -State $maintenanceState -StepName 'DISM StartComponentCleanup'
            }
        } else {
            $cleanupSkipResult = Get-SkippedStepResult -StepName 'DISM StartComponentCleanup' -Reason $dueStatus.Message
            Add-RepairResult -Result $cleanupSkipResult
            Write-StepResult -Result $cleanupSkipResult
        }
    }

    if ($runSfcBool) {
        $dueStatus = Test-StepDue -State $maintenanceState -StepName 'SFC /scannow' -UseCadence $useCadenceControlBool -CadenceDays $HeavyMaintenanceCadenceDays
        if ($dueStatus.Due) {
            $sfcResult = Invoke-SfcStep
            Add-RepairResult -Result $sfcResult
            Write-StepResult -Result $sfcResult
            if ($sfcResult.Success) {
                Set-StepLastSuccess -State $maintenanceState -StepName 'SFC /scannow'
            } else {
                Write-CbsSummary
            }
        } else {
            $sfcSkipResult = Get-SkippedStepResult -StepName 'SFC /scannow' -Reason $dueStatus.Message
            Add-RepairResult -Result $sfcSkipResult
            Write-StepResult -Result $sfcSkipResult
        }
    }

    if ($runDeliveryOptimizationCacheCleanupBool) {
        $dueStatus = Test-StepDue -State $maintenanceState -StepName 'Delivery Optimization Cache Cleanup' -UseCadence $useCadenceControlBool -CadenceDays $HeavyMaintenanceCadenceDays
        if ($dueStatus.Due) {
            $doCleanupResult = Invoke-DeliveryOptimizationCleanup
            Add-RepairResult -Result $doCleanupResult
            Write-StepResult -Result $doCleanupResult
            if ($doCleanupResult.Success -and -not $doCleanupResult.Skipped) {
                Set-StepLastSuccess -State $maintenanceState -StepName 'Delivery Optimization Cache Cleanup'
            }
        } else {
            $doCleanupSkipResult = Get-SkippedStepResult -StepName 'Delivery Optimization Cache Cleanup' -Reason $dueStatus.Message
            Add-RepairResult -Result $doCleanupSkipResult
            Write-StepResult -Result $doCleanupSkipResult
        }
    }

    Save-MaintenanceState -State $maintenanceState

    $pendingRebootAfter = Test-PendingReboot

    Write-Log -Message '========================================'
    Write-Log -Message 'Maintenance Summary'
    Write-Log -Message '========================================'

    $criticalCount = 0
    $warningCount = 0
    $successCount = 0
    $skippedCount = 0
    $rebootRequired = $pendingRebootAfter.Pending

    foreach ($repairResult in $Script:RepairResults) {
        Write-Log -Message ('{0}: State={1}, Success={2}, ExitCode={3}, RebootRequired={4}, Message={5}' -f $repairResult.Name, $repairResult.State, $repairResult.Success, $repairResult.ExitCode, $repairResult.RebootRequired, $repairResult.Message)

        if ($repairResult.Critical) {
            $criticalCount++
        } elseif ($repairResult.Skipped) {
            $skippedCount++
        } elseif ($repairResult.Success) {
            $successCount++
        } else {
            $warningCount++
        }

        if ($repairResult.RebootRequired) {
            $rebootRequired = $true
        }
    }

    if ($pendingRebootAfter.Pending) {
        foreach ($pendingReason in $pendingRebootAfter.Reasons) {
            Write-Log -Message ('Pending reboot detected after maintenance: {0}' -f $pendingReason) -Level 'WARN'
        }
    } else {
        Write-Log -Message 'No pending reboot state detected after maintenance.'
    }

    Write-Log -Message ('Summary counts: Success={0}, Skipped={1}, Warnings={2}, Critical={3}, RebootRequired={4}' -f $successCount, $skippedCount, $warningCount, $criticalCount, $rebootRequired)
    Write-Log -Message ('DISM log: {0}' -f $Script:Config.DismLogPath)
    Write-Log -Message ('CBS log: {0}' -f $Script:Config.CbsLogPath)

    $summaryText = 'Success={0}; Skipped={1}; Warnings={2}; Critical={3}; RebootRequired={4}' -f $successCount, $skippedCount, $warningCount, $criticalCount, $rebootRequired
    $detailsText = 'Mode=Maintenance; Build={0}; Cadence={1}; LogPath={2}' -f $osDetails.BuildNumber, $useCadenceControlBool, $Script:Config.LogPath

    if ([string]::IsNullOrWhiteSpace($ResultFieldName)) {
        Write-Log -Message 'Result custom field not configured.'
    } elseif (-not (Write-NinjaField -FieldName $ResultFieldName -Value $summaryText)) {
        Write-Log -Message 'Result custom field write failed.' -Level 'WARN'
    }

    if ([string]::IsNullOrWhiteSpace($DetailsFieldName)) {
        Write-Log -Message 'Details custom field not configured.'
    } elseif (-not (Write-NinjaField -FieldName $DetailsFieldName -Value $detailsText)) {
        Write-Log -Message 'Details custom field write failed.' -Level 'WARN'
    }

    if ($criticalCount -gt 0) {
        Write-Log -Message 'One or more critical maintenance steps failed.' -Level 'ERROR'
        return $Script:ExitCodeMap.Critical
    }

    if ($rebootRequired) {
        Write-Host 'REBOOT REQUIRED: Windows servicing still reports a pending reboot.' -ForegroundColor Yellow
        if ($ExitCodeMode.ToLowerInvariant() -eq 'ninjafriendly') {
            return $Script:ExitCodeMap.Success
        }

        return $Script:ExitCodeMap.RebootRequired
    }

    if ($warningCount -gt 0) {
        Write-Host 'COMPLETED WITH WARNINGS: Review the warning lines above and the saved logs.' -ForegroundColor Yellow
        if ($ExitCodeMode.ToLowerInvariant() -eq 'ninjafriendly') {
            return $Script:ExitCodeMap.Success
        }

        return $Script:ExitCodeMap.Partial
    }

    if ($successCount -eq 0 -and $skippedCount -gt 0) {
        Write-Log -Message 'All selected steps were skipped by cadence.'
        if ($ExitCodeMode.ToLowerInvariant() -eq 'ninjafriendly') {
            return $Script:ExitCodeMap.Success
        }

        return $Script:ExitCodeMap.NothingToDo
    }

    Write-Log -Message 'Maintenance workflow completed successfully.' -Level 'SUCCESS'
    return $Script:ExitCodeMap.Success
}

$DismTimeoutMinutes = Get-ResolvedIntValue -EnvironmentName 'DismTimeoutMinutes' -CurrentValue $DismTimeoutMinutes -Minimum 30 -Maximum 240
$SfcTimeoutMinutes = Get-ResolvedIntValue -EnvironmentName 'SfcTimeoutMinutes' -CurrentValue $SfcTimeoutMinutes -Minimum 15 -Maximum 180
$ChkdskTimeoutMinutes = Get-ResolvedIntValue -EnvironmentName 'ChkdskTimeoutMinutes' -CurrentValue $ChkdskTimeoutMinutes -Minimum 15 -Maximum 180
$MaxRetries = Get-ResolvedIntValue -EnvironmentName 'MaxRetries' -CurrentValue $MaxRetries -Minimum 0 -Maximum 3
$MinimumFreeSpaceGB = Get-ResolvedIntValue -EnvironmentName 'MinimumFreeSpaceGB' -CurrentValue $MinimumFreeSpaceGB -Minimum 5 -Maximum 50
$MediumMaintenanceCadenceDays = Get-ResolvedIntValue -EnvironmentName 'MediumMaintenanceCadenceDays' -CurrentValue $MediumMaintenanceCadenceDays -Minimum 1 -Maximum 30
$HeavyMaintenanceCadenceDays = Get-ResolvedIntValue -EnvironmentName 'HeavyMaintenanceCadenceDays' -CurrentValue $HeavyMaintenanceCadenceDays -Minimum 1 -Maximum 60
$DeliveryOptimizationMaxAgeDays = Get-ResolvedIntValue -EnvironmentName 'DeliveryOptimizationMaxAgeDays' -CurrentValue $DeliveryOptimizationMaxAgeDays -Minimum 1 -Maximum 180
$LogRetentionDays = Get-ResolvedIntValue -EnvironmentName 'LogRetentionDays' -CurrentValue $LogRetentionDays -Minimum 7 -Maximum 365

$RunChkdskScan = Get-ResolvedStringValue -EnvironmentName 'RunChkdskScan' -CurrentValue $RunChkdskScan
$RunCheckHealth = Get-ResolvedStringValue -EnvironmentName 'RunCheckHealth' -CurrentValue $RunCheckHealth
$RunScanHealth = Get-ResolvedStringValue -EnvironmentName 'RunScanHealth' -CurrentValue $RunScanHealth
$RunRestoreHealth = Get-ResolvedStringValue -EnvironmentName 'RunRestoreHealth' -CurrentValue $RunRestoreHealth
$RunAnalyzeComponentStore = Get-ResolvedStringValue -EnvironmentName 'RunAnalyzeComponentStore' -CurrentValue $RunAnalyzeComponentStore
$RunStartComponentCleanup = Get-ResolvedStringValue -EnvironmentName 'RunStartComponentCleanup' -CurrentValue $RunStartComponentCleanup
$RunSfc = Get-ResolvedStringValue -EnvironmentName 'RunSfc' -CurrentValue $RunSfc
$ResetWindowsUpdateComponents = Get-ResolvedStringValue -EnvironmentName 'ResetWindowsUpdateComponents' -CurrentValue $ResetWindowsUpdateComponents
$LimitAccess = Get-ResolvedStringValue -EnvironmentName 'LimitAccess' -CurrentValue $LimitAccess
$RepairSourcePath = Get-ResolvedStringValue -EnvironmentName 'RepairSourcePath' -CurrentValue $RepairSourcePath
$UseCadenceControl = Get-ResolvedStringValue -EnvironmentName 'UseCadenceControl' -CurrentValue $UseCadenceControl
$RunDeliveryOptimizationCacheCleanup = Get-ResolvedStringValue -EnvironmentName 'RunDeliveryOptimizationCacheCleanup' -CurrentValue $RunDeliveryOptimizationCacheCleanup
$ExitCodeMode = Get-ResolvedStringValue -EnvironmentName 'ExitCodeMode' -CurrentValue $ExitCodeMode
$ResultFieldName = Get-ResolvedStringValue -EnvironmentName 'ResultFieldName' -CurrentValue $ResultFieldName
$DetailsFieldName = Get-ResolvedStringValue -EnvironmentName 'DetailsFieldName' -CurrentValue $DetailsFieldName

$exitCode = $Script:ExitCodeMap.Critical

try {
    Initialize-Paths
    Start-RunTranscript
    $exitCode = Invoke-Main
} catch {
    $currentError = $_
    Write-Log -Message ('FATAL ERROR: {0}' -f $currentError.Exception.Message) -Level 'ERROR'
    Write-Log -Message ('Stack trace: {0}' -f $currentError.ScriptStackTrace) -Level 'ERROR'

    if (-not [string]::IsNullOrWhiteSpace($ResultFieldName)) {
        [void](Write-NinjaField -FieldName $ResultFieldName -Value ('FAILED: {0}' -f $currentError.Exception.Message))
    }

    $exitCode = $Script:ExitCodeMap.Critical
} finally {
    Stop-RunTranscript
    Write-Log -Message '----------------------------------------'
    Write-Log -Message ('Script log: {0}' -f $Script:Config.LogPath)
    Write-Log -Message ('Transcript: {0}' -f $Script:Config.TranscriptPath)
    exit $exitCode
}
