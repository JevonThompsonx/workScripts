#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Repairs common Windows Update and feature update cache issues that can block a Windows 11 upgrade.

.DESCRIPTION
    This enterprise-safe remediation script targets common causes of Windows 11 updates or feature upgrades
    stalling partway through setup, including stale Windows Update caches, Delivery Optimization cache residue,
    BITS queue corruption, servicing stack issues, and pending upgrade staging folders.

    The script is built for PowerShell 5.1 and NinjaOne deployment. It is idempotent, uses Write-Host output for
    the Activities feed, supports Script Variables through both parameters and environment variables, and returns
    explicit exit codes.

    Safety choices:
    - The script does not delete pending.xml or manually remove servicing registry keys because those actions can
      worsen component store corruption.
    - Legacy ACL reset and DLL reregistration steps are available but disabled by default because Microsoft treats
      them as later-stage recovery steps, not first-line remediation.
    - SetupDiag is only executed when present locally. The script does not download unsigned or unverified tooling.

.PARAMETER Mode
    Remediate or Diagnose. Diagnose performs read-only checks and optional log capture without clearing caches.

.PARAMETER RunComponentRepair
    Checkbox-style string. When true, runs DISM RestoreHealth after cache remediation.

.PARAMETER RunSystemFileChecker
    Checkbox-style string. When true, runs SFC /SCANNOW after DISM.

.PARAMETER ClearDeliveryOptimizationCache
    Checkbox-style string. When true, clears Delivery Optimization cache content.

.PARAMETER ClearFeatureUpdateStaging
    Checkbox-style string. When true, archives then clears stale feature update staging folders such as
    C:\$WINDOWS.~BT and C:\$WINDOWS.~WS.

.PARAMETER ResetWinsock
    Checkbox-style string. When true, runs netsh winsock reset. This usually requires a reboot.

.PARAMETER ResetWinHttpProxy
    Checkbox-style string. When true, runs netsh winhttp reset proxy. Use carefully in environments that rely on
    a configured WinHTTP proxy or PAC workflow.

.PARAMETER TriggerUpdateScan
    Checkbox-style string. When true, attempts to trigger a post-remediation scan using UsoClient or wuauclt.

.PARAMETER CollectSetupDiag
    Checkbox-style string. When true, runs SetupDiag if present and archives update setup logs when found.

.PARAMETER AggressiveServiceAclReset
    Checkbox-style string. When true, resets default service security descriptors for BITS and Windows Update.

.PARAMETER LegacyDllReregistration
    Checkbox-style string. When true, attempts legacy regsvr32 registration for classic Windows Update DLLs.

.PARAMETER MinFreeSpaceGB
    Minimum recommended free space on the system drive before remediation or upgrade retry.

.PARAMETER ResultFieldName
    Optional NinjaOne custom field name for a short result summary.

.PARAMETER DetailsFieldName
    Optional NinjaOne custom field name for a longer diagnostic summary.

.PARAMETER ExitCodeMode
    Strict returns warning and reboot-specific exit codes. NinjaFriendly returns 0 for handled warnings or
    reboot-required outcomes so automation wrappers that only treat 0 as success do not mislabel the run.

.EXAMPLE
    .\Invoke-WindowsUpdateRemediation.ps1 -Mode Remediate

.EXAMPLE
    .\Invoke-WindowsUpdateRemediation.ps1 -Mode Diagnose -CollectSetupDiag true

.NOTES
    Author:       OpenCode
    Version:      1.0.0
    Date:         2026-03-18
    Run As:       Administrator or SYSTEM
    Architecture: All
    PS Version:   5.1 baseline
    Timeout:      3600s recommended for full remediation
    Exit Codes:   0=Success, 1=Partial, 2=Critical, 100=Nothing to do, 3010=Reboot required

    NinjaOne Script Variables:
        - Mode (String): Remediate or Diagnose
        - RunComponentRepair (Checkbox)
        - RunSystemFileChecker (Checkbox)
        - ClearDeliveryOptimizationCache (Checkbox)
        - ClearFeatureUpdateStaging (Checkbox)
        - ResetWinsock (Checkbox)
        - ResetWinHttpProxy (Checkbox)
        - TriggerUpdateScan (Checkbox)
        - CollectSetupDiag (Checkbox)
        - AggressiveServiceAclReset (Checkbox)
        - LegacyDllReregistration (Checkbox)
        - MinFreeSpaceGB (Integer)
        - ResultFieldName (String)
        - DetailsFieldName (String)

    NinjaOne Custom Fields Required:
        - None. Optional only if ResultFieldName and DetailsFieldName are supplied.

    Changelog:
        1.0.0 - Initial release
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Remediate', 'Diagnose', IgnoreCase = $true)]
    [string]$Mode = 'Remediate',

    [Parameter(Mandatory = $false)]
    [string]$RunComponentRepair = 'true',

    [Parameter(Mandatory = $false)]
    [string]$RunSystemFileChecker = 'true',

    [Parameter(Mandatory = $false)]
    [string]$ClearDeliveryOptimizationCache = 'true',

    [Parameter(Mandatory = $false)]
    [string]$ClearFeatureUpdateStaging = 'true',

    [Parameter(Mandatory = $false)]
    [string]$ResetWinsock = 'false',

    [Parameter(Mandatory = $false)]
    [string]$ResetWinHttpProxy = 'false',

    [Parameter(Mandatory = $false)]
    [string]$TriggerUpdateScan = 'true',

    [Parameter(Mandatory = $false)]
    [string]$CollectSetupDiag = 'true',

    [Parameter(Mandatory = $false)]
    [string]$AggressiveServiceAclReset = 'false',

    [Parameter(Mandatory = $false)]
    [string]$LegacyDllReregistration = 'false',

    [Parameter(Mandatory = $false)]
    [ValidateRange(5, 200)]
    [int]$MinFreeSpaceGB = 20,

    [Parameter(Mandatory = $false)]
    [ValidateLength(0, 128)]
    [string]$ResultFieldName = '',

    [Parameter(Mandatory = $false)]
    [ValidateLength(0, 128)]
    [string]$DetailsFieldName = '',

    [Parameter(Mandatory = $false)]
    [ValidateSet('Strict', 'NinjaFriendly', IgnoreCase = $true)]
    [string]$ExitCodeMode = 'NinjaFriendly'
)

$ErrorActionPreference = 'Stop'

$SCRIPT_VERSION = '1.0.0'
$SCRIPT_NAME = 'Invoke-WindowsUpdateRemediation'
$script:transcriptStarted = $false
$script:logPath = $null

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
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = '[{0}] [{1}] {2}' -f $timestamp, $Level, $Message

    if (-not [string]::IsNullOrWhiteSpace($script:logPath)) {
        try {
            Add-Content -Path $script:logPath -Value $line -Encoding UTF8 -ErrorAction Stop
        } catch {
            $currentError = $_
            Write-Host ('[WARN] Failed to write to log file: {0}' -f $currentError.Exception.Message) -ForegroundColor Yellow
        }
    }

    switch ($Level) {
        'ERROR' {
            Write-Host $line -ForegroundColor Red
        }
        'WARN' {
            Write-Host $line -ForegroundColor Yellow
        }
        'SUCCESS' {
            Write-Host $line -ForegroundColor Green
        }
        default {
            Write-Host $line -ForegroundColor Gray
        }
    }
}

function New-ResultTracker {
    [CmdletBinding()]
    param()

    return @{
        Success = New-Object 'System.Collections.Generic.List[string]'
        Skipped = New-Object 'System.Collections.Generic.List[string]'
        Warning = New-Object 'System.Collections.Generic.List[string]'
        Failed  = New-Object 'System.Collections.Generic.List[string]'
    }
}

function Add-ResultEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Tracker,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Success', 'Skipped', 'Warning', 'Failed')]
        [string]$Bucket,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $Tracker[$Bucket].Add($Message) | Out-Null
    switch ($Bucket) {
        'Success' { Write-Log -Message $Message -Level 'SUCCESS' }
        'Skipped' { Write-Log -Message $Message -Level 'INFO' }
        'Warning' { Write-Log -Message $Message -Level 'WARN' }
        'Failed'  { Write-Log -Message $Message -Level 'ERROR' }
    }
}

function Test-IsAdministrator {
    [CmdletBinding()]
    param()

    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Initialize-LogPaths {
    [CmdletBinding()]
    param()

    $logRoot = 'C:\ProgramData\Scripts\Logs\WindowsUpdateRemediation'
    if (-not (Test-Path -LiteralPath $logRoot)) {
        New-Item -Path $logRoot -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }

    $runStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $runRoot = Join-Path -Path $logRoot -ChildPath $runStamp
    New-Item -Path $runRoot -ItemType Directory -Force -ErrorAction Stop | Out-Null

    $artifactsRoot = Join-Path -Path $runRoot -ChildPath 'Artifacts'
    New-Item -Path $artifactsRoot -ItemType Directory -Force -ErrorAction Stop | Out-Null

    $script:logPath = Join-Path -Path $runRoot -ChildPath ($SCRIPT_NAME + '.log')
    New-Item -Path $script:logPath -ItemType File -Force -ErrorAction Stop | Out-Null

    $existingRunFolders = Get-ChildItem -LiteralPath $logRoot -Directory -ErrorAction Stop
    foreach ($existingRunFolder in $existingRunFolders) {
        if ($existingRunFolder.LastWriteTime -lt (Get-Date).AddDays(-30)) {
            try {
                Remove-Item -LiteralPath $existingRunFolder.FullName -Recurse -Force -ErrorAction Stop
            } catch {
                $currentError = $_
                Write-Host ('[WARN] Could not prune old log folder {0}: {1}' -f $existingRunFolder.FullName, $currentError.Exception.Message) -ForegroundColor Yellow
            }
        }
    }

    return [PSCustomObject]@{
        LogRoot      = $logRoot
        RunRoot      = $runRoot
        ArtifactsRoot = $artifactsRoot
        LogPath      = $script:logPath
    }
}

function Start-RunTranscript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TranscriptPath
    )

    try {
        Start-Transcript -Path $TranscriptPath -Force -ErrorAction Stop | Out-Null
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
            $currentError = $_
            Write-Host ('[WARN] Transcript could not be stopped cleanly: {0}' -f $currentError.Exception.Message) -ForegroundColor Yellow
        }
    }
}

function Invoke-NativeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [string]$ArgumentList = '',

        [Parameter(Mandatory = $false)]
        [int]$TimeoutMilliseconds = 1800000
    )

    $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processStartInfo.FileName = $FilePath
    $processStartInfo.Arguments = $ArgumentList
    $processStartInfo.UseShellExecute = $false
    $processStartInfo.RedirectStandardOutput = $true
    $processStartInfo.RedirectStandardError = $true
    $processStartInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processStartInfo

    [void]$process.Start()
    $standardOutput = $process.StandardOutput.ReadToEnd()
    $standardError = $process.StandardError.ReadToEnd()
    $completed = $process.WaitForExit($TimeoutMilliseconds)

    if (-not $completed) {
        try {
            $process.Kill()
        } catch {
        }

        return [PSCustomObject]@{
            FilePath = $FilePath
            Arguments = $ArgumentList
            ExitCode = -1
            TimedOut = $true
            StandardOutput = $standardOutput
            StandardError = $standardError
        }
    }

    return [PSCustomObject]@{
        FilePath = $FilePath
        Arguments = $ArgumentList
        ExitCode = $process.ExitCode
        TimedOut = $false
        StandardOutput = $standardOutput
        StandardError = $standardError
    }
}

function Test-FreeSpace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$MinimumGB
    )

    $systemDrive = $env:SystemDrive
    if ([string]::IsNullOrWhiteSpace($systemDrive)) {
        $systemDrive = 'C:'
    }

    $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter ("DeviceID='{0}'" -f $systemDrive) -ErrorAction Stop
    $freeSpaceGB = [math]::Round(($disk.FreeSpace / 1GB), 2)

    return [PSCustomObject]@{
        Drive = $systemDrive
        FreeSpaceGB = $freeSpaceGB
        MeetsMinimum = ($freeSpaceGB -ge $MinimumGB)
    }
}

function Get-ServiceIfPresent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return Get-Service -Name $Name -ErrorAction SilentlyContinue
}

function Stop-ServiceSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $service = Get-ServiceIfPresent -Name $Name
    if ($null -eq $service) {
        return [PSCustomObject]@{ Name = $Name; Changed = $false; Message = 'Service not present' }
    }

    if ($service.Status -eq 'Stopped') {
        return [PSCustomObject]@{ Name = $Name; Changed = $false; Message = 'Already stopped' }
    }

    Stop-Service -Name $Name -Force -ErrorAction Stop
    $service.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(30))
    return [PSCustomObject]@{ Name = $Name; Changed = $true; Message = 'Stopped' }
}

function Start-ServiceSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $service = Get-ServiceIfPresent -Name $Name
    if ($null -eq $service) {
        return [PSCustomObject]@{ Name = $Name; Changed = $false; Message = 'Service not present' }
    }

    if ($service.Status -eq 'Running') {
        return [PSCustomObject]@{ Name = $Name; Changed = $false; Message = 'Already running' }
    }

    Start-Service -Name $Name -ErrorAction Stop
    $service.WaitForStatus('Running', [TimeSpan]::FromSeconds(30))
    return [PSCustomObject]@{ Name = $Name; Changed = $true; Message = 'Running' }
}

function Save-PathArtifact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationRoot,

        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $SourcePath)) {
        return $null
    }

    $safeLabel = $Label -replace '[\\/:*?"<>| ]', '_'
    $destinationPath = Join-Path -Path $DestinationRoot -ChildPath $safeLabel
    Copy-Item -Path $SourcePath -Destination $destinationPath -Recurse -Force -ErrorAction Stop
    return $destinationPath
}

function Reset-FolderWithBackup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetPath,

        [Parameter(Mandatory = $true)]
        [string]$BackupSuffix
    )

    $parentPath = Split-Path -Path $TargetPath -Parent
    $leafName = Split-Path -Path $TargetPath -Leaf
    $backupPath = Join-Path -Path $parentPath -ChildPath ($leafName + '.' + $BackupSuffix)

    if (Test-Path -LiteralPath $backupPath) {
        Remove-Item -LiteralPath $backupPath -Recurse -Force -ErrorAction Stop
    }

    if (Test-Path -LiteralPath $TargetPath) {
        Rename-Item -Path $TargetPath -NewName ($leafName + '.' + $BackupSuffix) -ErrorAction Stop
    }

    New-Item -Path $TargetPath -ItemType Directory -Force -ErrorAction Stop | Out-Null

    return [PSCustomObject]@{
        TargetPath = $TargetPath
        BackupPath = $backupPath
    }
}

function Clear-DirectoryContents {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetPath
    )

    if (-not (Test-Path -LiteralPath $TargetPath)) {
        return [PSCustomObject]@{ TargetPath = $TargetPath; ItemCount = 0; Existed = $false }
    }

    $items = Get-ChildItem -LiteralPath $TargetPath -Force -ErrorAction Stop
    $itemCount = @($items).Count
    foreach ($item in $items) {
        Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
    }

    return [PSCustomObject]@{ TargetPath = $TargetPath; ItemCount = $itemCount; Existed = $true }
}

function Clear-FilesByPattern {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath,

        [Parameter(Mandatory = $true)]
        [string]$Filter
    )

    if (-not (Test-Path -LiteralPath $DirectoryPath)) {
        return 0
    }

    $files = Get-ChildItem -Path $DirectoryPath -Filter $Filter -Force -ErrorAction Stop
    $count = 0
    foreach ($file in $files) {
        Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
        $count++
    }

    return $count
}

function Reset-ServiceAclsIfRequested {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Enabled
    )

    if (-not $Enabled) {
        return [PSCustomObject]@{ Performed = $false; Message = 'Disabled by configuration' }
    }

    $bitsCommand = 'sdset bits D:(A;CI;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)'
    $wuauservCommand = 'sdset wuauserv D:(A;;CCLCSWRPLORC;;;AU)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)'

    $bitsResult = Invoke-NativeCommand -FilePath 'sc.exe' -ArgumentList $bitsCommand -TimeoutMilliseconds 120000
    $wuauservResult = Invoke-NativeCommand -FilePath 'sc.exe' -ArgumentList $wuauservCommand -TimeoutMilliseconds 120000

    if ($bitsResult.ExitCode -ne 0 -or $wuauservResult.ExitCode -ne 0) {
        throw 'Service ACL reset failed.'
    }

    return [PSCustomObject]@{ Performed = $true; Message = 'Service ACL reset complete' }
}

function Invoke-LegacyDllRegistration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Enabled
    )

    if (-not $Enabled) {
        return [PSCustomObject]@{ Performed = $false; Registered = 0; Failed = 0 }
    }

    $dllList = @(
        'atl.dll',
        'urlmon.dll',
        'mshtml.dll',
        'shdocvw.dll',
        'browseui.dll',
        'jscript.dll',
        'vbscript.dll',
        'scrrun.dll',
        'msxml.dll',
        'msxml3.dll',
        'msxml6.dll',
        'actxprxy.dll',
        'softpub.dll',
        'wintrust.dll',
        'dssenh.dll',
        'rsaenh.dll',
        'gpkcsp.dll',
        'sccbase.dll',
        'slbcsp.dll',
        'cryptdlg.dll',
        'oleaut32.dll',
        'ole32.dll',
        'shell32.dll',
        'initpki.dll',
        'wuapi.dll',
        'wuaueng.dll',
        'wuaueng1.dll',
        'wucltui.dll',
        'wups.dll',
        'wups2.dll',
        'wuweb.dll',
        'qmgr.dll',
        'qmgrprxy.dll',
        'wucltux.dll',
        'muweb.dll',
        'wuwebv.dll'
    )

    $registeredCount = 0
    $failedCount = 0
    foreach ($dllName in $dllList) {
        $dllPath = Join-Path -Path $env:WINDIR -ChildPath ('System32\' + $dllName)
        if (-not (Test-Path -LiteralPath $dllPath)) {
            continue
        }

        $result = Invoke-NativeCommand -FilePath (Join-Path -Path $env:WINDIR -ChildPath 'System32\regsvr32.exe') -ArgumentList ('/s "{0}"' -f $dllPath) -TimeoutMilliseconds 120000
        if ($result.ExitCode -eq 0) {
            $registeredCount++
        } else {
            $failedCount++
        }
    }

    return [PSCustomObject]@{ Performed = $true; Registered = $registeredCount; Failed = $failedCount }
}

function Invoke-DismRestoreHealth {
    [CmdletBinding()]
    param()

    return Invoke-NativeCommand -FilePath (Join-Path -Path $env:WINDIR -ChildPath 'System32\dism.exe') -ArgumentList '/Online /Cleanup-Image /RestoreHealth' -TimeoutMilliseconds 3600000
}

function Invoke-SfcScan {
    [CmdletBinding()]
    param()

    return Invoke-NativeCommand -FilePath (Join-Path -Path $env:WINDIR -ChildPath 'System32\sfc.exe') -ArgumentList '/scannow' -TimeoutMilliseconds 3600000
}

function Get-SetupDiagPath {
    [CmdletBinding()]
    param()

    $candidatePaths = @(
        'C:\$WINDOWS.~BT\Sources\SetupDiag.exe',
        'C:\Windows.old\$WINDOWS.~BT\Sources\SetupDiag.exe',
        'C:\Windows\System32\SetupDiag.exe'
    )

    foreach ($candidatePath in $candidatePaths) {
        if (Test-Path -LiteralPath $candidatePath) {
            return $candidatePath
        }
    }

    $command = Get-Command -Name 'SetupDiag.exe' -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return $command.Source
    }

    return $null
}

function Invoke-SetupDiagIfPresent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArtifactsRoot
    )

    $setupDiagPath = Get-SetupDiagPath
    if ([string]::IsNullOrWhiteSpace($setupDiagPath)) {
        return [PSCustomObject]@{ Found = $false; ExitCode = 100; OutputPath = $null }
    }

    $outputPath = Join-Path -Path $ArtifactsRoot -ChildPath 'SetupDiagResults.log'
    $arguments = '/Output:"{0}" /NoTel' -f $outputPath
    $result = Invoke-NativeCommand -FilePath $setupDiagPath -ArgumentList $arguments -TimeoutMilliseconds 900000

    return [PSCustomObject]@{ Found = $true; ExitCode = $result.ExitCode; OutputPath = $outputPath }
}

function Test-PendingReboot {
    [CmdletBinding()]
    param()

    $reasons = New-Object 'System.Collections.Generic.List[string]'

    if (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
        $reasons.Add('CBS RebootPending') | Out-Null
    }

    if (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
        $reasons.Add('Windows Update RebootRequired') | Out-Null
    }

    $sessionManagerPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
    try {
        $sessionManager = Get-ItemProperty -Path $sessionManagerPath -Name 'PendingFileRenameOperations' -ErrorAction Stop
        if ($null -ne $sessionManager.PendingFileRenameOperations) {
            $reasons.Add('PendingFileRenameOperations') | Out-Null
        }
    } catch {
    }

    return [PSCustomObject]@{
        IsPending = ($reasons.Count -gt 0)
        Reasons = $reasons
    }
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

    $command = Get-Command -Name 'Ninja-Property-Set' -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        return $false
    }

    try {
        Ninja-Property-Set $FieldName $Value
        return $true
    } catch {
        return $false
    }
}

function Get-OperatingSystemSummary {
    [CmdletBinding()]
    param()

    $operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    return [PSCustomObject]@{
        Caption = $operatingSystem.Caption
        Version = $operatingSystem.Version
        BuildNumber = $operatingSystem.BuildNumber
        LastBootUpTime = $operatingSystem.LastBootUpTime
    }
}

function Invoke-UpdateScanTrigger {
    [CmdletBinding()]
    param()

    $usoClientPath = Join-Path -Path $env:WINDIR -ChildPath 'System32\UsoClient.exe'
    if (Test-Path -LiteralPath $usoClientPath) {
        $result = Invoke-NativeCommand -FilePath $usoClientPath -ArgumentList 'StartScan' -TimeoutMilliseconds 120000
        return [PSCustomObject]@{ Tool = 'UsoClient'; ExitCode = $result.ExitCode }
    }

    $wuaucltPath = Join-Path -Path $env:WINDIR -ChildPath 'System32\wuauclt.exe'
    if (Test-Path -LiteralPath $wuaucltPath) {
        $result = Invoke-NativeCommand -FilePath $wuaucltPath -ArgumentList '/resetauthorization /detectnow' -TimeoutMilliseconds 120000
        return [PSCustomObject]@{ Tool = 'wuauclt'; ExitCode = $result.ExitCode }
    }

    return [PSCustomObject]@{ Tool = 'None'; ExitCode = 100 }
}

function Remove-KnownStagingFolder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetPath
    )

    if (-not (Test-Path -LiteralPath $TargetPath)) {
        return [PSCustomObject]@{
            Removed = $false
            RetryUsed = $false
            Message = 'Path not present'
        }
    }

    try {
        Remove-Item -LiteralPath $TargetPath -Recurse -Force -ErrorAction Stop
        return [PSCustomObject]@{
            Removed = $true
            RetryUsed = $false
            Message = 'Removed directly'
        }
    } catch {
        $currentError = $_
        Write-Log -Message ('Direct removal failed for {0}: {1}. Retrying with ownership reset for known staging path.' -f $TargetPath, $currentError.Exception.Message) -Level 'WARN'
    }

    $takeOwnResult = Invoke-NativeCommand -FilePath (Join-Path -Path $env:WINDIR -ChildPath 'System32\takeown.exe') -ArgumentList ('/F "{0}" /A /R /D Y' -f $TargetPath) -TimeoutMilliseconds 300000
    $icaclsResult = Invoke-NativeCommand -FilePath (Join-Path -Path $env:WINDIR -ChildPath 'System32\icacls.exe') -ArgumentList ('"{0}" /grant Administrators:F /T /C' -f $TargetPath) -TimeoutMilliseconds 300000

    if ($takeOwnResult.ExitCode -ne 0 -or $icaclsResult.ExitCode -ne 0) {
        return [PSCustomObject]@{
            Removed = $false
            RetryUsed = $true
            Message = ('Ownership retry failed. takeown={0}, icacls={1}' -f $takeOwnResult.ExitCode, $icaclsResult.ExitCode)
        }
    }

    $attribResult = Invoke-NativeCommand -FilePath (Join-Path -Path $env:WINDIR -ChildPath 'System32\attrib.exe') -ArgumentList ('-R -S -H "{0}" /S /D' -f $TargetPath) -TimeoutMilliseconds 300000
    if ($attribResult.ExitCode -ne 0) {
        Write-Log -Message ('attrib returned exit code {0} for {1}. Continuing with delete retry.' -f $attribResult.ExitCode, $TargetPath) -Level 'WARN'
    }

    try {
        Remove-Item -LiteralPath $TargetPath -Recurse -Force -ErrorAction Stop
        return [PSCustomObject]@{
            Removed = $true
            RetryUsed = $true
            Message = 'Removed after ownership reset'
        }
    } catch {
        $currentError = $_
        return [PSCustomObject]@{
            Removed = $false
            RetryUsed = $true
            Message = $currentError.Exception.Message
        }
    }
}

function Get-WindowsUpdatePolicySummary {
    [CmdletBinding()]
    param()

    $policyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    $auPath = Join-Path -Path $policyPath -ChildPath 'AU'
    $summary = New-Object 'System.Collections.Generic.List[string]'

    if (Test-Path -LiteralPath $policyPath) {
        $summary.Add('Windows Update policy path present') | Out-Null
        try {
            $policyValues = Get-ItemProperty -Path $policyPath -ErrorAction Stop
            if ($null -ne $policyValues.WUServer) {
                $summary.Add(('WUServer={0}' -f $policyValues.WUServer)) | Out-Null
            }
            if ($null -ne $policyValues.WUStatusServer) {
                $summary.Add(('WUStatusServer={0}' -f $policyValues.WUStatusServer)) | Out-Null
            }
            if ($null -ne $policyValues.DisableWindowsUpdateAccess) {
                $summary.Add(('DisableWindowsUpdateAccess={0}' -f $policyValues.DisableWindowsUpdateAccess)) | Out-Null
            }
        } catch {
        }
    }

    if (Test-Path -LiteralPath $auPath) {
        try {
            $auValues = Get-ItemProperty -Path $auPath -ErrorAction Stop
            if ($null -ne $auValues.UseWUServer) {
                $summary.Add(('UseWUServer={0}' -f $auValues.UseWUServer)) | Out-Null
            }
            if ($null -ne $auValues.NoAutoRebootWithLoggedOnUsers) {
                $summary.Add(('NoAutoRebootWithLoggedOnUsers={0}' -f $auValues.NoAutoRebootWithLoggedOnUsers)) | Out-Null
            }
        } catch {
        }
    }

    return $summary
}

$Mode = Get-ResolvedStringValue -EnvironmentName 'Mode' -CurrentValue $Mode
$RunComponentRepair = Get-ResolvedStringValue -EnvironmentName 'RunComponentRepair' -CurrentValue $RunComponentRepair
$RunSystemFileChecker = Get-ResolvedStringValue -EnvironmentName 'RunSystemFileChecker' -CurrentValue $RunSystemFileChecker
$ClearDeliveryOptimizationCache = Get-ResolvedStringValue -EnvironmentName 'ClearDeliveryOptimizationCache' -CurrentValue $ClearDeliveryOptimizationCache
$ClearFeatureUpdateStaging = Get-ResolvedStringValue -EnvironmentName 'ClearFeatureUpdateStaging' -CurrentValue $ClearFeatureUpdateStaging
$ResetWinsock = Get-ResolvedStringValue -EnvironmentName 'ResetWinsock' -CurrentValue $ResetWinsock
$ResetWinHttpProxy = Get-ResolvedStringValue -EnvironmentName 'ResetWinHttpProxy' -CurrentValue $ResetWinHttpProxy
$TriggerUpdateScan = Get-ResolvedStringValue -EnvironmentName 'TriggerUpdateScan' -CurrentValue $TriggerUpdateScan
$CollectSetupDiag = Get-ResolvedStringValue -EnvironmentName 'CollectSetupDiag' -CurrentValue $CollectSetupDiag
$AggressiveServiceAclReset = Get-ResolvedStringValue -EnvironmentName 'AggressiveServiceAclReset' -CurrentValue $AggressiveServiceAclReset
$LegacyDllReregistration = Get-ResolvedStringValue -EnvironmentName 'LegacyDllReregistration' -CurrentValue $LegacyDllReregistration
$ResultFieldName = Get-ResolvedStringValue -EnvironmentName 'ResultFieldName' -CurrentValue $ResultFieldName
$DetailsFieldName = Get-ResolvedStringValue -EnvironmentName 'DetailsFieldName' -CurrentValue $DetailsFieldName
$ExitCodeMode = Get-ResolvedStringValue -EnvironmentName 'ExitCodeMode' -CurrentValue $ExitCodeMode
$MinFreeSpaceGB = Get-ResolvedIntValue -EnvironmentName 'MinFreeSpaceGB' -CurrentValue $MinFreeSpaceGB -Minimum 5 -Maximum 200

$bRunComponentRepair = Convert-ToBoolean -Value $RunComponentRepair
$bRunSystemFileChecker = Convert-ToBoolean -Value $RunSystemFileChecker
$bClearDeliveryOptimizationCache = Convert-ToBoolean -Value $ClearDeliveryOptimizationCache
$bClearFeatureUpdateStaging = Convert-ToBoolean -Value $ClearFeatureUpdateStaging
$bResetWinsock = Convert-ToBoolean -Value $ResetWinsock
$bResetWinHttpProxy = Convert-ToBoolean -Value $ResetWinHttpProxy
$bTriggerUpdateScan = Convert-ToBoolean -Value $TriggerUpdateScan
$bCollectSetupDiag = Convert-ToBoolean -Value $CollectSetupDiag
$bAggressiveServiceAclReset = Convert-ToBoolean -Value $AggressiveServiceAclReset
$bLegacyDllReregistration = Convert-ToBoolean -Value $LegacyDllReregistration

$results = New-ResultTracker
$rebootRequired = $false

try {
    $paths = Initialize-LogPaths
    Start-RunTranscript -TranscriptPath (Join-Path -Path $paths.RunRoot -ChildPath 'Transcript.txt')

    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host ('  Script: {0} v{1}' -f $SCRIPT_NAME, $SCRIPT_VERSION) -ForegroundColor Cyan
    Write-Host ('  Device: {0}' -f $env:COMPUTERNAME) -ForegroundColor Cyan
    Write-Host ('  Time:   {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -ForegroundColor Cyan
    Write-Host '========================================' -ForegroundColor Cyan

    if (-not (Test-IsAdministrator)) {
        throw 'This script requires Administrator or SYSTEM privileges.'
    }

    $operatingSystemSummary = Get-OperatingSystemSummary
    Write-Log -Message ('Operating system: {0} ({1}, build {2})' -f $operatingSystemSummary.Caption, $operatingSystemSummary.Version, $operatingSystemSummary.BuildNumber)
    Write-Log -Message ('Execution mode: {0}' -f $Mode)
    Write-Log -Message ('Exit code mode: {0}' -f $ExitCodeMode)

    $policySummary = Get-WindowsUpdatePolicySummary
    if (@($policySummary).Count -gt 0) {
        foreach ($policyLine in $policySummary) {
            Write-Log -Message ('Policy: {0}' -f $policyLine)
        }
    } else {
        Write-Log -Message 'No explicit Windows Update policy override detected.'
    }

    $freeSpaceResult = Test-FreeSpace -MinimumGB $MinFreeSpaceGB
    if ($freeSpaceResult.MeetsMinimum) {
        Add-ResultEntry -Tracker $results -Bucket 'Success' -Message ('System drive {0} has {1} GB free.' -f $freeSpaceResult.Drive, $freeSpaceResult.FreeSpaceGB)
    } else {
        Add-ResultEntry -Tracker $results -Bucket 'Warning' -Message ('System drive {0} has only {1} GB free. Windows 11 feature updates often need at least {2} GB.' -f $freeSpaceResult.Drive, $freeSpaceResult.FreeSpaceGB, $MinFreeSpaceGB)
    }

    $pendingRebootBefore = Test-PendingReboot
    if ($pendingRebootBefore.IsPending) {
        Add-ResultEntry -Tracker $results -Bucket 'Warning' -Message ('Pending reboot detected before remediation: {0}' -f ($pendingRebootBefore.Reasons -join ', '))
    } else {
        Add-ResultEntry -Tracker $results -Bucket 'Success' -Message 'No pending reboot markers detected before remediation.'
    }

    if ($bCollectSetupDiag) {
        $pantherPaths = @(
            'C:\$WINDOWS.~BT\Sources\Panther',
            'C:\$WINDOWS.~BT\Sources\Rollback',
            'C:\Windows\Panther',
            'C:\Windows\Panther\NewOS',
            'C:\Windows\Logs\SetupDiag'
        )

        foreach ($pantherPath in $pantherPaths) {
            if (Test-Path -LiteralPath $pantherPath) {
                $savedArtifact = Save-PathArtifact -SourcePath $pantherPath -DestinationRoot $paths.ArtifactsRoot -Label $pantherPath
                if ($null -ne $savedArtifact) {
                    Add-ResultEntry -Tracker $results -Bucket 'Success' -Message ('Archived setup logs from {0} to {1}.' -f $pantherPath, $savedArtifact)
                }
            }
        }

        $setupDiagResult = Invoke-SetupDiagIfPresent -ArtifactsRoot $paths.ArtifactsRoot
        if ($setupDiagResult.Found -and $setupDiagResult.ExitCode -eq 0) {
            Add-ResultEntry -Tracker $results -Bucket 'Success' -Message ('SetupDiag completed. Results: {0}' -f $setupDiagResult.OutputPath)
        } elseif ($setupDiagResult.Found) {
            Add-ResultEntry -Tracker $results -Bucket 'Warning' -Message ('SetupDiag was present but exited with code {0}.' -f $setupDiagResult.ExitCode)
        } else {
            Add-ResultEntry -Tracker $results -Bucket 'Skipped' -Message 'SetupDiag not found locally. No download attempted.'
        }
    } else {
        Add-ResultEntry -Tracker $results -Bucket 'Skipped' -Message 'SetupDiag collection disabled by configuration.'
    }

    if ($Mode.ToLowerInvariant() -eq 'diagnose') {
        Add-ResultEntry -Tracker $results -Bucket 'Skipped' -Message 'Diagnose mode selected. No cache clearing or system mutation performed.'
    } else {
        $serviceNames = @('bits', 'wuauserv', 'cryptsvc', 'appidsvc', 'msiserver', 'dosvc')
        foreach ($serviceName in $serviceNames) {
            try {
                $stopResult = Stop-ServiceSafe -Name $serviceName
                Add-ResultEntry -Tracker $results -Bucket 'Success' -Message ('Service {0}: {1}' -f $stopResult.Name, $stopResult.Message)
            } catch {
                $currentError = $_
                Add-ResultEntry -Tracker $results -Bucket 'Warning' -Message ('Could not stop service {0}: {1}' -f $serviceName, $currentError.Exception.Message)
            }
        }

        $qmgrDirectory = Join-Path -Path $env:ALLUSERSPROFILE -ChildPath 'Microsoft\Network\Downloader'
        try {
            $removedQmgrFiles = Clear-FilesByPattern -DirectoryPath $qmgrDirectory -Filter 'qmgr*.dat'
            Add-ResultEntry -Tracker $results -Bucket 'Success' -Message ('Removed {0} BITS queue files from {1}.' -f $removedQmgrFiles, $qmgrDirectory)
        } catch {
            $currentError = $_
            Add-ResultEntry -Tracker $results -Bucket 'Warning' -Message ('Could not clear BITS queue files: {0}' -f $currentError.Exception.Message)
        }

        $foldersToReset = @(
            'C:\Windows\SoftwareDistribution\Download',
            'C:\Windows\SoftwareDistribution\DataStore',
            'C:\Windows\SoftwareDistribution\PostRebootEventCache.V2',
            'C:\Windows\System32\catroot2'
        )

        foreach ($folderToReset in $foldersToReset) {
            try {
                $resetResult = Reset-FolderWithBackup -TargetPath $folderToReset -BackupSuffix 'bak.opencode'
                Add-ResultEntry -Tracker $results -Bucket 'Success' -Message ('Reset folder {0}. Backup: {1}' -f $resetResult.TargetPath, $resetResult.BackupPath)
            } catch {
                $currentError = $_
                Add-ResultEntry -Tracker $results -Bucket 'Warning' -Message ('Could not reset folder {0}: {1}' -f $folderToReset, $currentError.Exception.Message)
            }
        }

        if ($bClearDeliveryOptimizationCache) {
            $deliveryOptimizationCache = 'C:\ProgramData\Microsoft\Windows\DeliveryOptimization\Cache'
            try {
                $deliveryResult = Clear-DirectoryContents -TargetPath $deliveryOptimizationCache
                Add-ResultEntry -Tracker $results -Bucket 'Success' -Message ('Delivery Optimization cache cleared at {0}. Removed items: {1}' -f $deliveryResult.TargetPath, $deliveryResult.ItemCount)
            } catch {
                $currentError = $_
                Add-ResultEntry -Tracker $results -Bucket 'Warning' -Message ('Could not clear Delivery Optimization cache: {0}' -f $currentError.Exception.Message)
            }
        } else {
            Add-ResultEntry -Tracker $results -Bucket 'Skipped' -Message 'Delivery Optimization cache clearing disabled by configuration.'
        }

        if ($bClearFeatureUpdateStaging) {
            $featureUpdateStagingFolders = @(
                'C:\$WINDOWS.~BT',
                'C:\$WINDOWS.~WS',
                'C:\ESD',
                'C:\Windows10Upgrade'
            )

            foreach ($stagingFolder in $featureUpdateStagingFolders) {
                if (Test-Path -LiteralPath $stagingFolder) {
                    try {
                        $stagingRemovalResult = Remove-KnownStagingFolder -TargetPath $stagingFolder
                        if ($stagingRemovalResult.Removed) {
                            Add-ResultEntry -Tracker $results -Bucket 'Success' -Message ('Cleared feature update staging folder {0}. {1}' -f $stagingFolder, $stagingRemovalResult.Message)
                        } else {
                            Add-ResultEntry -Tracker $results -Bucket 'Warning' -Message ('Could not clear staging folder {0}: {1}' -f $stagingFolder, $stagingRemovalResult.Message)
                        }
                    } catch {
                        $currentError = $_
                        Add-ResultEntry -Tracker $results -Bucket 'Warning' -Message ('Could not clear staging folder {0}: {1}' -f $stagingFolder, $currentError.Exception.Message)
                    }
                } else {
                    Add-ResultEntry -Tracker $results -Bucket 'Skipped' -Message ('Staging folder not present: {0}' -f $stagingFolder)
                }
            }
        } else {
            Add-ResultEntry -Tracker $results -Bucket 'Skipped' -Message 'Feature update staging cleanup disabled by configuration.'
        }

        try {
            $aclResetResult = Reset-ServiceAclsIfRequested -Enabled $bAggressiveServiceAclReset
            if ($aclResetResult.Performed) {
                Add-ResultEntry -Tracker $results -Bucket 'Success' -Message $aclResetResult.Message
            } else {
                Add-ResultEntry -Tracker $results -Bucket 'Skipped' -Message $aclResetResult.Message
            }
        } catch {
            $currentError = $_
            Add-ResultEntry -Tracker $results -Bucket 'Warning' -Message ('Aggressive service ACL reset failed: {0}' -f $currentError.Exception.Message)
        }

        try {
            $dllRegistrationResult = Invoke-LegacyDllRegistration -Enabled $bLegacyDllReregistration
            if ($dllRegistrationResult.Performed) {
                Add-ResultEntry -Tracker $results -Bucket 'Success' -Message ('Legacy DLL registration attempted. Registered={0}, Failed={1}' -f $dllRegistrationResult.Registered, $dllRegistrationResult.Failed)
            } else {
                Add-ResultEntry -Tracker $results -Bucket 'Skipped' -Message 'Legacy DLL reregistration disabled by configuration.'
            }
        } catch {
            $currentError = $_
            Add-ResultEntry -Tracker $results -Bucket 'Warning' -Message ('Legacy DLL registration failed: {0}' -f $currentError.Exception.Message)
        }

        if ($bResetWinsock) {
            $winsockResult = Invoke-NativeCommand -FilePath (Join-Path -Path $env:WINDIR -ChildPath 'System32\netsh.exe') -ArgumentList 'winsock reset' -TimeoutMilliseconds 120000
            if ($winsockResult.ExitCode -eq 0) {
                $rebootRequired = $true
                Add-ResultEntry -Tracker $results -Bucket 'Success' -Message 'Winsock reset completed. Reboot required.'
            } else {
                Add-ResultEntry -Tracker $results -Bucket 'Warning' -Message ('Winsock reset exited with code {0}.' -f $winsockResult.ExitCode)
            }
        } else {
            Add-ResultEntry -Tracker $results -Bucket 'Skipped' -Message 'Winsock reset disabled by configuration.'
        }

        if ($bResetWinHttpProxy) {
            $winHttpResult = Invoke-NativeCommand -FilePath (Join-Path -Path $env:WINDIR -ChildPath 'System32\netsh.exe') -ArgumentList 'winhttp reset proxy' -TimeoutMilliseconds 120000
            if ($winHttpResult.ExitCode -eq 0) {
                Add-ResultEntry -Tracker $results -Bucket 'Success' -Message 'WinHTTP proxy reset completed.'
            } else {
                Add-ResultEntry -Tracker $results -Bucket 'Warning' -Message ('WinHTTP proxy reset exited with code {0}.' -f $winHttpResult.ExitCode)
            }
        } else {
            Add-ResultEntry -Tracker $results -Bucket 'Skipped' -Message 'WinHTTP proxy reset disabled by configuration.'
        }

        foreach ($serviceName in @('cryptsvc', 'bits', 'wuauserv', 'appidsvc', 'msiserver', 'dosvc')) {
            try {
                $startResult = Start-ServiceSafe -Name $serviceName
                Add-ResultEntry -Tracker $results -Bucket 'Success' -Message ('Service {0}: {1}' -f $startResult.Name, $startResult.Message)
            } catch {
                $currentError = $_
                Add-ResultEntry -Tracker $results -Bucket 'Warning' -Message ('Could not start service {0}: {1}' -f $serviceName, $currentError.Exception.Message)
            }
        }

        if ($bRunComponentRepair) {
            Write-Log -Message 'Running DISM RestoreHealth. This can take a long time.'
            $dismResult = Invoke-DismRestoreHealth
            if ($dismResult.TimedOut) {
                Add-ResultEntry -Tracker $results -Bucket 'Warning' -Message 'DISM RestoreHealth timed out.'
            } elseif ($dismResult.ExitCode -eq 0) {
                Add-ResultEntry -Tracker $results -Bucket 'Success' -Message 'DISM RestoreHealth completed successfully.'
            } elseif ($dismResult.ExitCode -eq 3010) {
                $rebootRequired = $true
                Add-ResultEntry -Tracker $results -Bucket 'Success' -Message 'DISM RestoreHealth completed and requested a reboot.'
            } else {
                Add-ResultEntry -Tracker $results -Bucket 'Warning' -Message ('DISM RestoreHealth exited with code {0}.' -f $dismResult.ExitCode)
            }
        } else {
            Add-ResultEntry -Tracker $results -Bucket 'Skipped' -Message 'DISM component repair disabled by configuration.'
        }

        if ($bRunSystemFileChecker) {
            Write-Log -Message 'Running SFC /SCANNOW. This can take a long time.'
            $sfcResult = Invoke-SfcScan
            if ($sfcResult.TimedOut) {
                Add-ResultEntry -Tracker $results -Bucket 'Warning' -Message 'SFC scan timed out.'
            } elseif ($sfcResult.ExitCode -eq 0) {
                Add-ResultEntry -Tracker $results -Bucket 'Success' -Message 'SFC completed successfully.'
            } elseif ($sfcResult.ExitCode -eq 1) {
                Add-ResultEntry -Tracker $results -Bucket 'Warning' -Message 'SFC reported that corruption was found and addressed or needs review. Check CBS.log.'
            } elseif ($sfcResult.ExitCode -eq 2) {
                Add-ResultEntry -Tracker $results -Bucket 'Warning' -Message 'SFC could not complete. Review CBS.log and retry after reboot.'
            } else {
                Add-ResultEntry -Tracker $results -Bucket 'Warning' -Message ('SFC exited with code {0}.' -f $sfcResult.ExitCode)
            }
        } else {
            Add-ResultEntry -Tracker $results -Bucket 'Skipped' -Message 'System File Checker disabled by configuration.'
        }

        if ($bTriggerUpdateScan) {
            $scanResult = Invoke-UpdateScanTrigger
            if ($scanResult.ExitCode -eq 0 -or $scanResult.ExitCode -eq 100) {
                Add-ResultEntry -Tracker $results -Bucket 'Success' -Message ('Update detection trigger attempted with {0}. Exit code: {1}' -f $scanResult.Tool, $scanResult.ExitCode)
            } else {
                Add-ResultEntry -Tracker $results -Bucket 'Warning' -Message ('Update detection trigger via {0} exited with code {1}.' -f $scanResult.Tool, $scanResult.ExitCode)
            }
        } else {
            Add-ResultEntry -Tracker $results -Bucket 'Skipped' -Message 'Post-remediation update scan disabled by configuration.'
        }
    }

    $pendingRebootAfter = Test-PendingReboot
    if ($pendingRebootAfter.IsPending) {
        $rebootRequired = $true
        Add-ResultEntry -Tracker $results -Bucket 'Warning' -Message ('Pending reboot detected after remediation: {0}' -f ($pendingRebootAfter.Reasons -join ', '))
    } else {
        Add-ResultEntry -Tracker $results -Bucket 'Success' -Message 'No pending reboot markers detected after remediation.'
    }

    Write-Host '----------------------------------------' -ForegroundColor Cyan
    Write-Host ('Success: {0}' -f $results.Success.Count) -ForegroundColor Green
    Write-Host ('Skipped: {0}' -f $results.Skipped.Count) -ForegroundColor Gray
    Write-Host ('Warnings: {0}' -f $results.Warning.Count) -ForegroundColor Yellow
    Write-Host ('Failed: {0}' -f $results.Failed.Count) -ForegroundColor Red
    Write-Host ('Log Root: {0}' -f $paths.RunRoot) -ForegroundColor Cyan
    Write-Host '----------------------------------------' -ForegroundColor Cyan

    $summaryText = 'Success={0}; Skipped={1}; Warnings={2}; Failed={3}; RebootRequired={4}' -f $results.Success.Count, $results.Skipped.Count, $results.Warning.Count, $results.Failed.Count, $rebootRequired
    $detailsText = 'Mode={0}; Build={1}; LogPath={2}' -f $Mode, $operatingSystemSummary.BuildNumber, $paths.LogPath

    if ([string]::IsNullOrWhiteSpace($ResultFieldName)) {
        Write-Log -Message 'Result custom field not configured.'
    } elseif (-not (Write-NinjaField -FieldName $ResultFieldName -Value $summaryText)) {
        Write-Log -Message 'Result custom field write failed.'
    }

    if ([string]::IsNullOrWhiteSpace($DetailsFieldName)) {
        Write-Log -Message 'Details custom field not configured.'
    } elseif (-not (Write-NinjaField -FieldName $DetailsFieldName -Value $detailsText)) {
        Write-Log -Message 'Details custom field write failed.'
    }

    if ($results.Failed.Count -gt 0) {
        exit 2
    }

    if ($rebootRequired) {
        Write-Host 'REBOOT REQUIRED: Windows servicing still reports a pending reboot.' -ForegroundColor Yellow
        if ($ExitCodeMode.ToLowerInvariant() -eq 'ninjafriendly') {
            exit 0
        }

        exit 3010
    }

    if ($results.Warning.Count -gt 0) {
        Write-Host 'COMPLETED WITH WARNINGS: Review the warning lines above and the saved logs.' -ForegroundColor Yellow
        if ($ExitCodeMode.ToLowerInvariant() -eq 'ninjafriendly') {
            exit 0
        }

        exit 1
    }

    if ($Mode.ToLowerInvariant() -eq 'diagnose') {
        exit 100
    }

    exit 0
}
catch {
    $currentError = $_
    Write-Host ('FATAL ERROR: {0}' -f $currentError.Exception.Message) -ForegroundColor Red
    Write-Host ('Stack trace: {0}' -f $currentError.ScriptStackTrace) -ForegroundColor Red

    if (-not [string]::IsNullOrWhiteSpace($ResultFieldName)) {
        [void](Write-NinjaField -FieldName $ResultFieldName -Value ('FAILED: {0}' -f $currentError.Exception.Message))
    }

    exit 2
}
finally {
    Stop-RunTranscript
}
