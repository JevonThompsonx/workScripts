#Requires -Version 5.1

<#
.SYNOPSIS
    Installs and configures Google Credential Provider for Windows (GCPW).

.DESCRIPTION
    Production-grade GCPW installation script with six phases:
      1. Detect current state (idempotent early-exit if healthy)
      2. Full purge of broken/stale installs
      3. Pre-stage registry configuration
      4. Download (if needed) and install MSI
      5. Validate DLL extraction and credential provider registration
      6. Structured result output with exit codes

    Designed to run as SYSTEM via NinjaOne RMM or via remote IEX invocation.
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
    .\gcpw.ps1 -Verbose

.EXAMPLE
    powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/.../gcpw.ps1')"
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
$VerbosePreference = 'Continue'

# ── Constants ────────────────────────────────────────────────────────────────

$script:GCPW_CP_CLSID     = '{0B5BFDF0-4594-47AC-940A-CFC69ABC561C}'
$script:GCPW_FILTER_CLSID  = '{AEC62FFE-6617-4685-A080-B11A848A0607}'
$script:CRED_PROV_BASE     = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\CredentialProviders'
$script:GCPW_REG_PATH      = 'HKLM:\SOFTWARE\Google\GCPW'
$script:INSTALL_DIR         = 'C:\Program Files\Google\Credential Provider'
$script:MAIN_DLL            = 'Gaia1_0.dll'
$script:MAIN_DLL_MIN_BYTES  = 1MB

# ── Functions ────────────────────────────────────────────────────────────────

function New-TerminatingError {
    <#
    .SYNOPSIS
        Creates and throws a terminating ErrorRecord from an advanced function.
    .DESCRIPTION
        Wraps the boilerplate for PSCmdlet.ThrowTerminatingError so callers
        can throw with a single line.
    .PARAMETER Cmdlet
        The calling PSCmdlet instance.
    .PARAMETER Message
        Human-readable error message.
    .PARAMETER ErrorId
        A stable string identifier for this error condition.
    .PARAMETER Category
        The ErrorCategory enum value.
    .EXAMPLE
        New-TerminatingError -Cmdlet $PSCmdlet -Message 'DLL missing' -ErrorId 'DllNotFound'
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
        $exception,
        $ErrorId,
        $Category,
        $null
    )
    $Cmdlet.ThrowTerminatingError($errorRecord)
}


function Test-GcpwFullyFunctional {
    <#
    .SYNOPSIS
        Detects whether GCPW is installed, registered, and configured.
    .DESCRIPTION
        Checks three independent conditions: main DLL present and sized
        correctly, credential provider CLSID registered in Winlogon,
        and domain configuration set in the GCPW registry key.
    .EXAMPLE
        $state = Test-GcpwFullyFunctional
    #>
    [CmdletBinding()]
    param()

    $dllPath    = Join-Path -Path $script:INSTALL_DIR -ChildPath $script:MAIN_DLL
    $dllPresent = $false

    if (Test-Path -LiteralPath $dllPath) {
        $dllItem = Get-Item -LiteralPath $dllPath -ErrorAction Stop
        if ($dllItem.Length -ge $script:MAIN_DLL_MIN_BYTES) {
            $dllPresent = $true
        }
    }

    $cpKeyPath    = Join-Path -Path $script:CRED_PROV_BASE -ChildPath $script:GCPW_CP_CLSID
    $cpRegistered = Test-Path -LiteralPath $cpKeyPath

    $configSet = $false
    if (Test-Path -LiteralPath $script:GCPW_REG_PATH) {
        try {
            $domainProp = Get-ItemProperty -LiteralPath $script:GCPW_REG_PATH -Name 'domains_allowed_to_login' -ErrorAction Stop
            if ($null -ne $domainProp -and $domainProp.domains_allowed_to_login -eq $DomainsAllowedToLogin) {
                $configSet = $true
            }
        }
        catch {
            $null = $_
            # Property does not exist yet -- configSet remains $false
        }
    }

    [PSCustomObject]@{
        DllPresent      = $dllPresent
        CpRegistered    = $cpRegistered
        ConfigSet       = $configSet
        FullyFunctional = ($dllPresent -and $cpRegistered -and $configSet)
    }
}


function Invoke-GcpwPurge {
    <#
    .SYNOPSIS
        Removes all traces of a broken or partial GCPW installation.
    .DESCRIPTION
        Uninstalls via the product GUID found in the Uninstall registry,
        scrubs stale Windows Installer product keys that cause 1603 errors,
        deletes leftover program files, and removes stale credential
        provider registrations. Verifies no uninstall entry remains.
    .EXAMPLE
        Invoke-GcpwPurge
    #>
    [CmdletBinding()]
    param()

    Write-Verbose -Message 'Phase 2: Starting full GCPW purge'

    # ── Step 1: Uninstall via GUID ──

    $uninstallBases = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )

    foreach ($basePath in $uninstallBases) {
        if (-not (Test-Path -LiteralPath $basePath)) {
            continue
        }

        $subKeys = Get-ChildItem -LiteralPath $basePath -ErrorAction Stop
        foreach ($subKey in $subKeys) {
            $props = $null
            try {
                $props = Get-ItemProperty -LiteralPath $subKey.PSPath -ErrorAction Stop
            }
            catch {
                $null = $_
                continue
            }
            if ($null -eq $props.DisplayName) { continue }
            if ($props.DisplayName -notlike '*Google Credential Provider*') { continue }

            $guid = $subKey.PSChildName
            Write-Verbose -Message "Found GCPW uninstall entry: $guid"

            $msiArgs = @('/x', $guid, '/qn', '/norestart')
            $procParams = @{
                FilePath     = 'msiexec.exe'
                ArgumentList = $msiArgs
                Wait         = $true
                PassThru     = $true
                NoNewWindow  = $true
            }
            $proc = Start-Process @procParams

            # 0 = success, 1605 = product not found (already gone), 3010 = reboot needed
            if ($proc.ExitCode -notin @(0, 1605, 3010)) {
                Write-Verbose -Message "msiexec /x exited with code $($proc.ExitCode) -- continuing purge"
            }
            else {
                Write-Verbose -Message "msiexec /x exited with code $($proc.ExitCode)"
            }
        }
    }

    # ── Step 2: Scrub stale Windows Installer product keys ──

    $installerProductsPath = 'HKLM:\SOFTWARE\Classes\Installer\Products'
    if (Test-Path -LiteralPath $installerProductsPath) {
        $productKeys = Get-ChildItem -LiteralPath $installerProductsPath -ErrorAction Stop
        foreach ($productKey in $productKeys) {
            $pProps = $null
            try {
                $pProps = Get-ItemProperty -LiteralPath $productKey.PSPath -ErrorAction Stop
            }
            catch {
                $null = $_
                continue
            }
            if ($null -eq $pProps.ProductName) { continue }
            if ($pProps.ProductName -notlike '*Google Credential Provider*') { continue }

            Write-Verbose -Message "Removing stale Installer\Products key: $($productKey.PSChildName)"
            $removeParams = @{
                LiteralPath = $productKey.PSPath
                Recurse     = $true
                Force       = $true
                ErrorAction = 'Stop'
            }
            Remove-Item @removeParams
        }
    }

    $userDataPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products'
    if (Test-Path -LiteralPath $userDataPath) {
        $udKeys = Get-ChildItem -LiteralPath $userDataPath -ErrorAction Stop
        foreach ($udKey in $udKeys) {
            $installPropsPath = Join-Path -Path $udKey.PSPath -ChildPath 'InstallProperties'
            $iProp = $null
            try {
                $iProp = Get-ItemProperty -LiteralPath $installPropsPath -ErrorAction Stop
            }
            catch {
                $null = $_
                continue
            }
            if ($null -eq $iProp.DisplayName) { continue }
            if ($iProp.DisplayName -notlike '*Google Credential Provider*') { continue }

            Write-Verbose -Message "Removing stale UserData\Products key: $($udKey.PSChildName)"
            $removeParams = @{
                LiteralPath = $udKey.PSPath
                Recurse     = $true
                Force       = $true
                ErrorAction = 'Stop'
            }
            Remove-Item @removeParams
        }
    }

    # ── Step 3: Delete leftover program files ──

    if (Test-Path -LiteralPath $script:INSTALL_DIR) {
        Write-Verbose -Message "Removing install directory: $($script:INSTALL_DIR)"
        $removeParams = @{
            LiteralPath = $script:INSTALL_DIR
            Recurse     = $true
            Force       = $true
            ErrorAction = 'Stop'
        }
        Remove-Item @removeParams
    }

    # ── Step 4: Remove stale credential provider registrations ──

    $cpKeyPath     = Join-Path -Path $script:CRED_PROV_BASE -ChildPath $script:GCPW_CP_CLSID
    $filterKeyPath = Join-Path -Path $script:CRED_PROV_BASE -ChildPath $script:GCPW_FILTER_CLSID

    if (Test-Path -LiteralPath $cpKeyPath) {
        Write-Verbose -Message 'Removing stale CP CLSID from Winlogon'
        $removeParams = @{
            LiteralPath = $cpKeyPath
            Recurse     = $true
            Force       = $true
            ErrorAction = 'Stop'
        }
        Remove-Item @removeParams
    }
    if (Test-Path -LiteralPath $filterKeyPath) {
        Write-Verbose -Message 'Removing stale filter CLSID from Winlogon'
        $removeParams = @{
            LiteralPath = $filterKeyPath
            Recurse     = $true
            Force       = $true
            ErrorAction = 'Stop'
        }
        Remove-Item @removeParams
    }

    # ── Verify no uninstall entry remains ──

    $stillPresent = $false
    foreach ($basePath in $uninstallBases) {
        if (-not (Test-Path -LiteralPath $basePath)) { continue }
        $subKeys = Get-ChildItem -LiteralPath $basePath -ErrorAction Stop
        foreach ($subKey in $subKeys) {
            $props = $null
            try {
                $props = Get-ItemProperty -LiteralPath $subKey.PSPath -ErrorAction Stop
            }
            catch {
                $null = $_
                continue
            }
            if ($null -eq $props.DisplayName) { continue }
            if ($props.DisplayName -like '*Google Credential Provider*') {
                $stillPresent = $true
            }
        }
    }

    if ($stillPresent) {
        Write-Verbose -Message 'WARNING: GCPW uninstall entry still present after purge'
    }
    else {
        Write-Verbose -Message 'Purge verified -- no GCPW entries remain'
    }
}


function Set-GcpwRegistryConfig {
    <#
    .SYNOPSIS
        Pre-stages the GCPW registry configuration before install.
    .DESCRIPTION
        Creates the GCPW registry key and sets domains_allowed_to_login
        and enable_hw_acceleration values.
    .EXAMPLE
        Set-GcpwRegistryConfig
    #>
    [CmdletBinding()]
    param()

    Write-Verbose -Message 'Phase 3: Pre-staging registry configuration'

    if (-not (Test-Path -LiteralPath $script:GCPW_REG_PATH)) {
        $newKeyParams = @{
            Path        = $script:GCPW_REG_PATH
            Force       = $true
            ErrorAction = 'Stop'
        }
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


function Install-GcpwMsi {
    <#
    .SYNOPSIS
        Downloads (if needed) and installs the GCPW MSI.
    .DESCRIPTION
        Ensures the MSI exists at MsiPath, downloading from MsiUrl if absent.
        Runs msiexec with verbose logging and checks the exit code.
        Waits 10 seconds after install for child processes to settle.
    .EXAMPLE
        Install-GcpwMsi
    #>
    [CmdletBinding()]
    param()

    Write-Verbose -Message 'Phase 4: Installing GCPW'

    # ── Download MSI if not present ──

    if (-not (Test-Path -LiteralPath $MsiPath)) {
        Write-Verbose -Message "MSI not found at $MsiPath -- downloading"

        # Ensure TLS 1.2 for the download
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

        $parentDir = Split-Path -Path $MsiPath -Parent
        if (-not (Test-Path -LiteralPath $parentDir)) {
            $newDirParams = @{
                Path        = $parentDir
                ItemType    = 'Directory'
                Force       = $true
                ErrorAction = 'Stop'
            }
            $null = New-Item @newDirParams
        }

        $dlParams = @{
            Uri             = $MsiUrl
            OutFile         = $MsiPath
            UseBasicParsing = $true
            ErrorAction     = 'Stop'
        }
        Invoke-WebRequest @dlParams
        Write-Verbose -Message 'Download complete'
    }
    else {
        Write-Verbose -Message "MSI found at $MsiPath"
    }

    # ── Run MSI install ──
    # Start-Process -Wait -PassThru is used because msiexec can spawn child
    # processes; $LASTEXITCODE is not reliable with Start-Process, so we
    # check $proc.ExitCode instead (equivalent intent to rule 15).

    $msiArgs = @(
        '/i'
        "`"$MsiPath`""
        '/qn'
        '/norestart'
        "/l*v `"$LogPath`""
    )

    $procParams = @{
        FilePath     = 'msiexec.exe'
        ArgumentList = $msiArgs
        Wait         = $true
        PassThru     = $true
        NoNewWindow  = $true
    }

    Write-Verbose -Message "Running: msiexec.exe $($msiArgs -join ' ')"
    $proc = Start-Process @procParams

    # 0 = success, 3010 = success but reboot needed
    if ($proc.ExitCode -notin @(0, 3010)) {
        $msg = "MSI install failed with exit code $($proc.ExitCode). See log: $LogPath"
        New-TerminatingError -Cmdlet $PSCmdlet -Message $msg -ErrorId 'MsiInstallFailed'
    }

    Write-Verbose -Message "MSI exited with code $($proc.ExitCode)"
    Write-Verbose -Message 'Waiting 10 seconds for post-install processes to settle'
    Start-Sleep -Seconds 10
}


function Register-GcpwCredentialProvider {
    <#
    .SYNOPSIS
        Validates GCPW DLL extraction and registers the credential provider.
    .DESCRIPTION
        Confirms Gaia1_0.dll is present and correctly sized. Checks whether
        the GCPW credential provider and filter CLSIDs are registered under
        Winlogon\CredentialProviders and writes them manually if missing
        (a known post-install gap).
    .EXAMPLE
        Register-GcpwCredentialProvider
    #>
    [CmdletBinding()]
    param()

    Write-Verbose -Message 'Phase 5: Validating DLL and credential provider registration'

    # ── Validate main DLL ──

    $dllPath = Join-Path -Path $script:INSTALL_DIR -ChildPath $script:MAIN_DLL
    if (-not (Test-Path -LiteralPath $dllPath)) {
        $msg = "Main DLL not found at $dllPath -- MSI extraction failed"
        New-TerminatingError -Cmdlet $PSCmdlet -Message $msg -ErrorId 'DllNotFound'
    }

    $dllItem = Get-Item -LiteralPath $dllPath -ErrorAction Stop
    if ($dllItem.Length -lt $script:MAIN_DLL_MIN_BYTES) {
        $sizeMB = [math]::Round($dllItem.Length / 1MB, 2)
        $msg = "Main DLL is only ${sizeMB} MB -- expected ~81 MB. Extraction incomplete."
        New-TerminatingError -Cmdlet $PSCmdlet -Message $msg -ErrorId 'DllTooSmall'
    }

    $sizeMB = [math]::Round($dllItem.Length / 1MB, 1)
    Write-Verbose -Message "Main DLL verified: $dllPath ($sizeMB MB)"

    # ── Register CP CLSID if missing ──

    $cpKeyPath = Join-Path -Path $script:CRED_PROV_BASE -ChildPath $script:GCPW_CP_CLSID
    if (-not (Test-Path -LiteralPath $cpKeyPath)) {
        Write-Verbose -Message 'CP CLSID not registered in Winlogon -- writing manually'
        $newKeyParams = @{
            Path        = $cpKeyPath
            Force       = $true
            ErrorAction = 'Stop'
        }
        $null = New-Item @newKeyParams
        $cpParams = @{
            LiteralPath = $cpKeyPath
            Name        = '(Default)'
            Value       = 'Google Credential Provider Class'
            Force       = $true
            ErrorAction = 'Stop'
        }
        $null = Set-ItemProperty @cpParams
        Write-Verbose -Message "Registered CP CLSID: $($script:GCPW_CP_CLSID)"
    }
    else {
        Write-Verbose -Message 'CP CLSID already registered'
    }

    # ── Register Filter CLSID if missing ──

    $filterKeyPath = Join-Path -Path $script:CRED_PROV_BASE -ChildPath $script:GCPW_FILTER_CLSID
    if (-not (Test-Path -LiteralPath $filterKeyPath)) {
        Write-Verbose -Message 'Filter CLSID not registered in Winlogon -- writing manually'
        $newKeyParams = @{
            Path        = $filterKeyPath
            Force       = $true
            ErrorAction = 'Stop'
        }
        $null = New-Item @newKeyParams
        $filterParams = @{
            LiteralPath = $filterKeyPath
            Name        = '(Default)'
            Value       = 'Google Credential Provider Filter'
            Force       = $true
            ErrorAction = 'Stop'
        }
        $null = Set-ItemProperty @filterParams
        Write-Verbose -Message "Registered filter CLSID: $($script:GCPW_FILTER_CLSID)"
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
    exit 1
}

# ── Main ─────────────────────────────────────────────────────────────────────

try {
    try { Start-Transcript -Path $TranscriptPath -Force -ErrorAction Stop }
    catch { $null = $_ }

    Write-Verbose -Message '=== GCPW Install Script Started ==='
    Write-Verbose -Message "Timestamp : $(Get-Date -Format 'o')"
    Write-Verbose -Message "Identity  : $($currentIdentity.Name)"
    Write-Verbose -Message "Host      : $env:COMPUTERNAME"

    # ── Phase 1: Detect current state ──

    Write-Verbose -Message 'Phase 1: Detecting current GCPW state'
    $state = Test-GcpwFullyFunctional

    Write-Verbose -Message "  DLL present  : $($state.DllPresent)"
    Write-Verbose -Message "  CP registered: $($state.CpRegistered)"
    Write-Verbose -Message "  Config set   : $($state.ConfigSet)"

    if ($state.FullyFunctional) {
        Write-Verbose -Message 'GCPW is fully functional -- no action needed (idempotent exit)'

        $result = [PSCustomObject]@{
            Status       = 'AlreadyInstalled'
            DllPresent   = $true
            CpRegistered = $true
            ConfigSet    = $true
            Timestamp    = (Get-Date -Format 'o')
        }
        $result

        try { Stop-Transcript -ErrorAction Stop } catch { $null = $_ }
        exit 0
    }

    # ── Decide scope of work ──

    $needsInstall = -not $state.DllPresent

    if ($needsInstall) {
        # Phase 2: Full purge before reinstall
        Invoke-GcpwPurge
    }

    # Phase 3: Pre-stage registry (always -- ensures config is correct)
    Set-GcpwRegistryConfig

    if ($needsInstall) {
        # Phase 4: Install
        Install-GcpwMsi
    }

    # Phase 5: Validate and remediate credential provider registration
    Register-GcpwCredentialProvider

    # ── Phase 6: Final validation and output ──

    Write-Verbose -Message 'Phase 6: Final validation'
    $finalState = Test-GcpwFullyFunctional

    $status = 'PartialFailure'
    if ($finalState.FullyFunctional) {
        $status = 'Success'
    }

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

    $result = [PSCustomObject]@{
        Status       = 'Failed'
        Error        = $caughtError.Exception.Message
        DllPresent   = $false
        CpRegistered = $false
        ConfigSet    = $false
        Timestamp    = (Get-Date -Format 'o')
    }
    $result

    try { Stop-Transcript -ErrorAction Stop } catch { $null = $_ }
    exit 1
}
