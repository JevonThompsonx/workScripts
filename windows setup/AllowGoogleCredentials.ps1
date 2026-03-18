#Requires -Version 5.1

<#
.SYNOPSIS
    Installs and configures Google Credential Provider for Windows (GCPW).

.DESCRIPTION
    Production-grade GCPW installation script with six phases:
      1. Detect current state (idempotent early-exit if healthy)
      2. Full purge of broken/stale installs (including CP CLSIDs)
      3. Pre-stage registry configuration
      4. Download (if needed) and install MSI
      5. Validate DLL extraction and credential provider registration
         (with automatic retry on DLL extraction failure)
      6. Structured result output with exit codes

    Designed to run as SYSTEM or Administrator. Can be invoked directly,
    via remote IEX, or integrated into any RMM/MDM tool.

    Handles the known 1603/SecureRepair failure mode by scrubbing stale
    Windows Installer product keys before reinstalling.

.PARAMETER DomainsAllowedToLogin
    Domain(s) permitted to authenticate via GCPW.

.PARAMETER MsiPath
    Local path where the GCPW MSI resides or will be downloaded.

.PARAMETER MsiUrl
    URL to download the GCPW standalone enterprise MSI.

.PARAMETER LogPath
    Path for the MSI verbose install log.

.PARAMETER TranscriptPath
    Path for the PowerShell transcript.

.EXAMPLE
    .\gcpw.ps1

.EXAMPLE
    .\gcpw.ps1 -DomainsAllowedToLogin 'contoso.com' -Verbose

.EXAMPLE
    powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/.../gcpw.ps1')"

.NOTES
    Author:     Jevon Thompson
    Run As:     System / Administrator
    Exit Codes: 0 = Success, 1 = Partial/Remediated, 2 = Failed
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$DomainsAllowedToLogin = 'ashleyvance.com',

    [Parameter()]
    [string]$MsiPath = 'C:\Archive\gcpwstandaloneenterprise64.msi',

    [Parameter()]
    [string]$MsiUrl = 'https://dl.google.com/credentialprovider/gcpwstandaloneenterprise64.msi',

    [Parameter()]
    [string]$LogPath = 'C:\Windows\Temp\gcpw_install.log',

    [Parameter()]
    [string]$TranscriptPath = 'C:\Windows\Temp\gcpw_install_transcript.log'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Constants ────────────────────────────────────────────────────────────────

$script:CP_CLSID         = '{0B5BFDF0-4594-47AC-940A-CFC69ABC561C}'
$script:FILTER_CLSID     = '{AEC62FFE-6617-4685-A080-B11A848A0607}'
$script:CRED_PROV_BASE   = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\CredentialProviders'
$script:GCPW_REG_PATH    = 'HKLM:\SOFTWARE\Google\GCPW'
$script:INSTALL_DIR      = 'C:\Program Files\Google\Credential Provider'
$script:MAIN_DLL         = 'Gaia1_0.dll'
$script:MIN_DLL_BYTES    = 10485760  # 10 MB — real DLL is ~81 MB

# ── Helpers ──────────────────────────────────────────────────────────────────

function New-TerminatingError {
    <#
    .SYNOPSIS  Throws a terminating ErrorRecord from an advanced function.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCmdlet]$Cmdlet,

        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter(Mandatory)]
        [string]$ErrorId,

        [Parameter()]
        [System.Management.Automation.ErrorCategory]$Category = [System.Management.Automation.ErrorCategory]::InvalidResult
    )

    $exception   = New-Object -TypeName System.Exception -ArgumentList $Message
    $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList @(
        $exception, $ErrorId, $Category, $null
    )
    $Cmdlet.ThrowTerminatingError($errorRecord)
}

# Uses .NET RegistryKey to write the (Default) value.
# Set-ItemProperty -Name '(Default)' does NOT work for this purpose.
function Set-RegistryDefaultValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RegistryPath,

        [Parameter(Mandatory)]
        [string]$Value
    )

    $prefix = 'HKLM:\'
    if (-not $RegistryPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw ('Unsupported registry path: {0}' -f $RegistryPath)
    }

    $subKey = $RegistryPath.Substring($prefix.Length)
    $hklm   = [Microsoft.Win32.Registry]::LocalMachine.CreateSubKey($subKey)
    if ($null -eq $hklm) { throw ('Unable to open/create: {0}' -f $RegistryPath) }

    try   { $hklm.SetValue('', $Value, [Microsoft.Win32.RegistryValueKind]::String) }
    finally { $hklm.Close() }
}

# ── Phase 1: Detect ─────────────────────────────────────────────────────────

function Test-GcpwFullyFunctional {
    <#
    .SYNOPSIS  Returns current GCPW health: DLL, CP registration, and config.
    #>
    [CmdletBinding()]
    param()

    $dllPath    = Join-Path -Path $script:INSTALL_DIR -ChildPath $script:MAIN_DLL
    $dllPresent = $false

    if (Test-Path -LiteralPath $dllPath) {
        $item = Get-Item -LiteralPath $dllPath -ErrorAction Stop
        if ($item.Length -ge $script:MIN_DLL_BYTES) { $dllPresent = $true }
    }

    $cpRegistered = Test-Path -LiteralPath (Join-Path -Path $script:CRED_PROV_BASE -ChildPath $script:CP_CLSID)

    $configSet = $false
    if (Test-Path -LiteralPath $script:GCPW_REG_PATH) {
        try {
            $prop = Get-ItemProperty -LiteralPath $script:GCPW_REG_PATH -Name 'domains_allowed_to_login' -ErrorAction Stop
            if ($null -ne $prop -and $prop.domains_allowed_to_login -eq $DomainsAllowedToLogin) {
                $configSet = $true
            }
        }
        catch { $null = $_ }
    }

    [PSCustomObject]@{
        DllPresent      = $dllPresent
        CpRegistered    = $cpRegistered
        ConfigSet       = $configSet
        FullyFunctional = ($dllPresent -and $cpRegistered -and $configSet)
    }
}

# ── Phase 2: Purge ──────────────────────────────────────────────────────────

function Invoke-GcpwPurge {
    <#
    .SYNOPSIS  Removes all traces of a broken or partial GCPW installation.
    .DESCRIPTION
        Uninstalls via product GUID, scrubs stale Windows Installer product keys
        (fixes 1603/SecureRepair), deletes program files, removes stale CP
        CLSID registrations, and verifies no uninstall entry remains.
    #>
    [CmdletBinding()]
    param()

    Write-Verbose -Message 'Phase 2: Starting full GCPW purge'

    # Step 1: Uninstall via GUID
    $uninstallBases = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )

    foreach ($basePath in $uninstallBases) {
        if (-not (Test-Path -LiteralPath $basePath)) { continue }
        foreach ($subKey in @(Get-ChildItem -LiteralPath $basePath -ErrorAction Stop)) {
            try   { $props = Get-ItemProperty -LiteralPath $subKey.PSPath -ErrorAction Stop }
            catch { continue }
            if ($null -eq $props.DisplayName) { continue }
            if ($props.DisplayName -notlike '*Google Credential Provider*') { continue }

            $guid = $subKey.PSChildName
            Write-Verbose -Message "Found GCPW uninstall entry: $guid"

            $procParams = @{
                FilePath     = 'msiexec.exe'
                ArgumentList = @('/x', $guid, '/qn', '/norestart')
                Wait         = $true
                PassThru     = $true
                NoNewWindow  = $true
            }
            $proc = Start-Process @procParams

            if ($proc.ExitCode -notin @(0, 1605, 3010)) {
                Write-Verbose -Message "msiexec /x exited with code $($proc.ExitCode) -- continuing purge"
            }
            else {
                Write-Verbose -Message "msiexec /x exited with code $($proc.ExitCode)"
            }
        }
    }

    # Step 2: Scrub stale Windows Installer product keys
    $installerProductsPath = 'HKLM:\SOFTWARE\Classes\Installer\Products'
    if (Test-Path -LiteralPath $installerProductsPath) {
        foreach ($key in @(Get-ChildItem -LiteralPath $installerProductsPath -ErrorAction Stop)) {
            try   { $pProps = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction Stop }
            catch { continue }
            if ($null -eq $pProps.ProductName) { continue }
            if ($pProps.ProductName -notlike '*Google Credential Provider*') { continue }

            Write-Verbose -Message "Removing stale Installer\Products key: $($key.PSChildName)"
            $removeParams = @{ LiteralPath = $key.PSPath; Recurse = $true; Force = $true; ErrorAction = 'Stop' }
            Remove-Item @removeParams
        }
    }

    $userDataPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products'
    if (Test-Path -LiteralPath $userDataPath) {
        foreach ($udKey in @(Get-ChildItem -LiteralPath $userDataPath -ErrorAction Stop)) {
            $installPropsPath = Join-Path -Path $udKey.PSPath -ChildPath 'InstallProperties'
            try   { $iProp = Get-ItemProperty -LiteralPath $installPropsPath -ErrorAction Stop }
            catch { continue }
            if ($null -eq $iProp.DisplayName) { continue }
            if ($iProp.DisplayName -notlike '*Google Credential Provider*') { continue }

            Write-Verbose -Message "Removing stale UserData\Products key: $($udKey.PSChildName)"
            $removeParams = @{ LiteralPath = $udKey.PSPath; Recurse = $true; Force = $true; ErrorAction = 'Stop' }
            Remove-Item @removeParams
        }
    }

    # Step 3: Delete leftover program files
    if (Test-Path -LiteralPath $script:INSTALL_DIR) {
        Write-Verbose -Message "Removing install directory: $($script:INSTALL_DIR)"
        $removeParams = @{ LiteralPath = $script:INSTALL_DIR; Recurse = $true; Force = $true; ErrorAction = 'Stop' }
        Remove-Item @removeParams
    }

    # Step 4: Remove stale credential provider registrations
    $cpKeyPath     = Join-Path -Path $script:CRED_PROV_BASE -ChildPath $script:CP_CLSID
    $filterKeyPath = Join-Path -Path $script:CRED_PROV_BASE -ChildPath $script:FILTER_CLSID

    foreach ($path in @($cpKeyPath, $filterKeyPath)) {
        if (Test-Path -LiteralPath $path) {
            Write-Verbose -Message "Removing stale CLSID: $path"
            $removeParams = @{ LiteralPath = $path; Recurse = $true; Force = $true; ErrorAction = 'Stop' }
            Remove-Item @removeParams
        }
    }

    # Step 5: Remove cached MSI
    if (Test-Path -LiteralPath $MsiPath) {
        Remove-Item -LiteralPath $MsiPath -Force -ErrorAction Stop
        Write-Verbose -Message "Removed cached MSI: $MsiPath"
    }

    # Step 6: Post-purge verification
    $stillPresent = $false
    foreach ($basePath in $uninstallBases) {
        if (-not (Test-Path -LiteralPath $basePath)) { continue }
        foreach ($subKey in @(Get-ChildItem -LiteralPath $basePath -ErrorAction Stop)) {
            try   { $props = Get-ItemProperty -LiteralPath $subKey.PSPath -ErrorAction Stop }
            catch { continue }
            if ($null -eq $props.DisplayName) { continue }
            if ($props.DisplayName -like '*Google Credential Provider*') { $stillPresent = $true }
        }
    }

    if ($stillPresent) {
        Write-Verbose -Message 'WARNING: GCPW uninstall entry still present after purge'
    }
    else {
        Write-Verbose -Message 'Purge verified -- no GCPW entries remain'
    }
}

# ── Phase 3: Registry Config ────────────────────────────────────────────────

function Set-GcpwRegistryConfig {
    <#
    .SYNOPSIS  Creates/updates the GCPW registry key with domain and HW accel settings.
    #>
    [CmdletBinding()]
    param()

    Write-Verbose -Message 'Phase 3: Pre-staging registry configuration'

    if (-not (Test-Path -LiteralPath $script:GCPW_REG_PATH)) {
        $newKeyParams = @{ Path = $script:GCPW_REG_PATH; Force = $true; ErrorAction = 'Stop' }
        $null = New-Item @newKeyParams
        Write-Verbose -Message "Created key: $($script:GCPW_REG_PATH)"
    }

    $domainParams = @{
        LiteralPath  = $script:GCPW_REG_PATH
        Name         = 'domains_allowed_to_login'
        Value        = $DomainsAllowedToLogin
        PropertyType = 'String'
        Force        = $true
        ErrorAction  = 'Stop'
    }
    $null = New-ItemProperty @domainParams
    Write-Verbose -Message "Set domains_allowed_to_login = $DomainsAllowedToLogin"

    $hwAccelParams = @{
        LiteralPath  = $script:GCPW_REG_PATH
        Name         = 'enable_hw_acceleration'
        Value        = 0
        PropertyType = 'DWord'
        Force        = $true
        ErrorAction  = 'Stop'
    }
    $null = New-ItemProperty @hwAccelParams
    Write-Verbose -Message 'Set enable_hw_acceleration = 0'
}

# ── Phase 4: Install ────────────────────────────────────────────────────────

function Install-GcpwMsi {
    <#
    .SYNOPSIS  Downloads (if needed) and installs the GCPW MSI.
    #>
    [CmdletBinding()]
    param()

    Write-Verbose -Message 'Phase 4: Installing GCPW'

    # Download if not present
    if (-not (Test-Path -LiteralPath $MsiPath)) {
        Write-Verbose -Message "MSI not found at $MsiPath -- downloading"
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

        $parentDir = Split-Path -Path $MsiPath -Parent
        if (-not (Test-Path -LiteralPath $parentDir)) {
            $newDirParams = @{ Path = $parentDir; ItemType = 'Directory'; Force = $true; ErrorAction = 'Stop' }
            $null = New-Item @newDirParams
        }

        $dlParams = @{ Uri = $MsiUrl; OutFile = $MsiPath; UseBasicParsing = $true; ErrorAction = 'Stop' }
        Invoke-WebRequest @dlParams
        Write-Verbose -Message 'Download complete'
    }
    else {
        Write-Verbose -Message "MSI found at $MsiPath"
    }

    # Ensure log directory exists
    $logDir = Split-Path -Path $LogPath -Parent
    if (($null -ne $logDir) -and ($logDir.Length -gt 0) -and (-not (Test-Path -LiteralPath $logDir))) {
        $null = New-Item -Path $logDir -ItemType 'Directory' -Force -ErrorAction Stop
    }

    # Run MSI
    $msiArgs = @('/i', "`"$MsiPath`"", '/qn', '/norestart', "/l*v `"$LogPath`"")

    $procParams = @{
        FilePath     = 'msiexec.exe'
        ArgumentList = $msiArgs
        Wait         = $true
        PassThru     = $true
        NoNewWindow  = $true
    }

    Write-Verbose -Message "Running: msiexec.exe $($msiArgs -join ' ')"
    $proc = Start-Process @procParams

    if ($proc.ExitCode -notin @(0, 3010)) {
        $msg = "MSI install failed with exit code $($proc.ExitCode). See log: $LogPath"
        New-TerminatingError -Cmdlet $PSCmdlet -Message $msg -ErrorId 'MsiInstallFailed'
    }

    Write-Verbose -Message "MSI exited with code $($proc.ExitCode)"
    Write-Verbose -Message 'Waiting 10 seconds for post-install processes to settle'
    Start-Sleep -Seconds 10
}

# ── Phase 5: Validate + Register ────────────────────────────────────────────

function Register-GcpwCredentialProvider {
    <#
    .SYNOPSIS  Validates DLL and registers CP CLSIDs if missing.
    #>
    [CmdletBinding()]
    param()

    Write-Verbose -Message 'Phase 5: Validating DLL and credential provider registration'

    # ── Validate main DLL ──
    $dllPath = Join-Path -Path $script:INSTALL_DIR -ChildPath $script:MAIN_DLL
    if (-not (Test-Path -LiteralPath $dllPath)) {
        # Retry: full purge + fresh download + reinstall
        Write-Verbose -Message 'Main DLL not found -- retrying with fresh download'
        Invoke-GcpwPurge
        Set-GcpwRegistryConfig
        Install-GcpwMsi

        if (-not (Test-Path -LiteralPath $dllPath)) {
            $msg = "Main DLL not found at $dllPath after retry -- MSI extraction failed"
            New-TerminatingError -Cmdlet $PSCmdlet -Message $msg -ErrorId 'DllNotFound'
        }
    }

    $dllItem = Get-Item -LiteralPath $dllPath -ErrorAction Stop
    if ($dllItem.Length -lt $script:MIN_DLL_BYTES) {
        # Retry on undersized DLL too
        Write-Verbose -Message "Main DLL is only $([math]::Round($dllItem.Length / 1MB, 2)) MB -- retrying"
        Invoke-GcpwPurge
        Set-GcpwRegistryConfig
        Install-GcpwMsi

        $dllItem = Get-Item -LiteralPath $dllPath -ErrorAction Stop
        if ($dllItem.Length -lt $script:MIN_DLL_BYTES) {
            $sizeMB = [math]::Round($dllItem.Length / 1MB, 2)
            $msg = "Main DLL is only ${sizeMB} MB after retry -- extraction incomplete."
            New-TerminatingError -Cmdlet $PSCmdlet -Message $msg -ErrorId 'DllTooSmall'
        }
    }

    $sizeMB = [math]::Round($dllItem.Length / 1MB, 1)
    Write-Verbose -Message "Main DLL verified: $dllPath ($sizeMB MB)"

    # ── Register CP CLSID if missing (uses .NET for default value) ──
    $cpKeyPath = Join-Path -Path $script:CRED_PROV_BASE -ChildPath $script:CP_CLSID
    if (-not (Test-Path -LiteralPath $cpKeyPath)) {
        Write-Verbose -Message 'CP CLSID not registered -- writing manually'
        $null = New-Item -Path $cpKeyPath -Force -ErrorAction Stop
        Set-RegistryDefaultValue -RegistryPath $cpKeyPath -Value 'Google Credential Provider Class'
        Write-Verbose -Message "Registered CP CLSID: $($script:CP_CLSID)"
    }
    else {
        Write-Verbose -Message 'CP CLSID already registered'
    }

    # ── Register Filter CLSID if missing ──
    $filterKeyPath = Join-Path -Path $script:CRED_PROV_BASE -ChildPath $script:FILTER_CLSID
    if (-not (Test-Path -LiteralPath $filterKeyPath)) {
        Write-Verbose -Message 'Filter CLSID not registered -- writing manually'
        $null = New-Item -Path $filterKeyPath -Force -ErrorAction Stop
        Set-RegistryDefaultValue -RegistryPath $filterKeyPath -Value 'Google Credential Provider Filter Class'
        Write-Verbose -Message "Registered filter CLSID: $($script:FILTER_CLSID)"
    }
    else {
        Write-Verbose -Message 'Filter CLSID already registered'
    }
}

# ── Init ─────────────────────────────────────────────────────────────────────

# Manual admin/SYSTEM check (#Requires -RunAsAdministrator is not enforced via IEX)
$currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal       = New-Object -TypeName System.Security.Principal.WindowsPrincipal -ArgumentList $currentIdentity
if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Verbose -Message 'ERROR: This script must run as Administrator or SYSTEM'
    exit 2
}

# ── Main ─────────────────────────────────────────────────────────────────────

try {
    try { Start-Transcript -Path $TranscriptPath -Force -ErrorAction Stop } catch { $null = $_ }

    Write-Verbose -Message '=== GCPW Install Script Started ==='
    Write-Verbose -Message "Timestamp : $(Get-Date -Format 'o')"
    Write-Verbose -Message "Identity  : $($currentIdentity.Name)"
    Write-Verbose -Message "Host      : $env:COMPUTERNAME"

    # ── Phase 1: Detect ──
    Write-Verbose -Message 'Phase 1: Detecting current GCPW state'
    $state = Test-GcpwFullyFunctional

    Write-Verbose -Message "  DLL present  : $($state.DllPresent)"
    Write-Verbose -Message "  CP registered: $($state.CpRegistered)"
    Write-Verbose -Message "  Config set   : $($state.ConfigSet)"

    if ($state.FullyFunctional) {
        Write-Verbose -Message 'GCPW is fully functional -- no action needed (idempotent exit)'

        [PSCustomObject]@{
            Status       = 'AlreadyInstalled'
            DllPresent   = $true
            CpRegistered = $true
            ConfigSet    = $true
            Timestamp    = (Get-Date -Format 'o')
        }

        try { Stop-Transcript -ErrorAction Stop } catch { $null = $_ }
        exit 0
    }

    # ── Determine scope ──
    $needsInstall = -not $state.DllPresent

    if ($needsInstall) {
        Invoke-GcpwPurge       # Phase 2
    }

    Set-GcpwRegistryConfig     # Phase 3 (always — ensures config is correct)

    if ($needsInstall) {
        Install-GcpwMsi        # Phase 4
    }

    Register-GcpwCredentialProvider  # Phase 5 (validate + remediate)

    # ── Phase 6: Final validation ──
    Write-Verbose -Message 'Phase 6: Final validation'
    $finalState = Test-GcpwFullyFunctional

    $status = if ($finalState.FullyFunctional) { 'Success' } else { 'PartialFailure' }

    $result = [PSCustomObject]@{
        Status       = $status
        DllPresent   = $finalState.DllPresent
        CpRegistered = $finalState.CpRegistered
        ConfigSet    = $finalState.ConfigSet
        Timestamp    = (Get-Date -Format 'o')
    }
    $result

    if (-not $finalState.FullyFunctional) {
        Write-Verbose -Message 'FAILED: Not all validation checks passed'
        try { Stop-Transcript -ErrorAction Stop } catch { $null = $_ }
        exit 1
    }

    Write-Verbose -Message '=== GCPW Install Script Completed Successfully ==='
    try { Stop-Transcript -ErrorAction Stop } catch { $null = $_ }
    exit 0
}
catch {
    $caughtError = $_
    Write-Verbose -Message "FATAL: $($caughtError.Exception.Message)"
    Write-Verbose -Message "Stack: $($caughtError.ScriptStackTrace)"

    [PSCustomObject]@{
        Status       = 'Failed'
        Error        = $caughtError.Exception.Message
        DllPresent   = $false
        CpRegistered = $false
        ConfigSet    = $false
        Timestamp    = (Get-Date -Format 'o')
    }

    try { Stop-Transcript -ErrorAction Stop } catch { $null = $_ }
    exit 2
}
