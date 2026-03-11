Set-StrictMode -Version 2

function Write-PrinterBanner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host ''
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host ("  {0}" -f $Message) -ForegroundColor Cyan
    Write-Host '========================================' -ForegroundColor Cyan
}

function Start-PrinterTranscript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogRoot,

        [Parameter(Mandatory = $true)]
        [string]$FilePrefix
    )

    if (-not (Test-Path -Path $LogRoot)) {
        New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
    }

    $logPath = Join-Path -Path $LogRoot -ChildPath ("{0}_{1}.log" -f $FilePrefix, (Get-Date -Format 'yyyyMMdd_HHmmss'))

    try {
        Start-Transcript -Path $logPath -Force | Out-Null
    }
    catch {
        Write-Warning ("Could not start transcript: {0}" -f $PSItem.Exception.Message)
    }

    return $logPath
}

function Stop-PrinterTranscriptSafe {
    [CmdletBinding()]
    param()

    try {
        Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
    }
    catch {
    }
}

function Assert-PrinterScriptAdministrator {
    [CmdletBinding()]
    param()

    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)

    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'This script requires Administrator or SYSTEM privileges.'
    }
}

function ConvertTo-PrinterScriptBoolean {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    $normalized = $Value.Trim().ToLowerInvariant()
    return ($normalized -eq 'true' -or $normalized -eq '1' -or $normalized -eq 'yes' -or $normalized -eq 'on')
}

function Get-PrinterRepositoryConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    if (-not (Test-Path -Path $ConfigPath)) {
        throw ("Printer config not found: {0}" -f $ConfigPath)
    }

    $config = Import-PowerShellDataFile -Path $ConfigPath
    if ($null -eq $config) {
        throw ("Failed to load printer config: {0}" -f $ConfigPath)
    }

    if (-not $config.ContainsKey('Printers') -or $null -eq $config.Printers -or $config.Printers.Count -eq 0) {
        throw 'Printer config does not contain any printer definitions.'
    }

    return $config
}

function Get-ConfiguredPrinters {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ConfigData
    )

    $printers = @($ConfigData.Printers)
    $keys = @{}

    foreach ($printer in $printers) {
        foreach ($requiredKey in @('Key', 'PrinterName', 'IPAddress', 'DriverFolder', 'InfFile', 'DriverName')) {
            if (-not $printer.ContainsKey($requiredKey) -or [string]::IsNullOrWhiteSpace([string]$printer[$requiredKey])) {
                throw ("Printer config entry is missing required field '{0}'." -f $requiredKey)
            }
        }

        if ($keys.ContainsKey($printer.Key)) {
            throw ("Duplicate printer key found in config: {0}" -f $printer.Key)
        }

        $keys[$printer.Key] = $true
    }

    return $printers
}

function Resolve-PrinterBasePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ConfigData,

        [Parameter()]
        [string]$BasePath
    )

    if (-not [string]::IsNullOrWhiteSpace($env:BasePath)) {
        return $env:BasePath
    }

    if (-not [string]::IsNullOrWhiteSpace($BasePath)) {
        return $BasePath
    }

    return [string]$ConfigData.BasePath
}

function Resolve-DriverSharePathValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ConfigData,

        [Parameter()]
        [string]$DriverSharePath
    )

    if (-not [string]::IsNullOrWhiteSpace($env:DriverSharePath)) {
        return $env:DriverSharePath
    }

    if (-not [string]::IsNullOrWhiteSpace($DriverSharePath)) {
        return $DriverSharePath
    }

    return [string]$ConfigData.DriverSharePath
}

function Resolve-LocalStageRootValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ConfigData,

        [Parameter()]
        [string]$LocalStageRoot
    )

    if (-not [string]::IsNullOrWhiteSpace($env:LocalStageRoot)) {
        return $env:LocalStageRoot
    }

    if (-not [string]::IsNullOrWhiteSpace($LocalStageRoot)) {
        return $LocalStageRoot
    }

    return [string]$ConfigData.LocalStageRoot
}

function Resolve-PrinterKeys {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]$PrinterKeys
    )

    $resolvedKeys = New-Object 'System.Collections.Generic.List[string]'

    foreach ($printerKey in @($PrinterKeys)) {
        if ($null -eq $printerKey) {
            continue
        }

        foreach ($token in ($printerKey -split ',')) {
            $trimmed = $token.Trim()
            if ([string]::IsNullOrWhiteSpace($trimmed)) {
                continue
            }

            if (-not $resolvedKeys.Contains($trimmed)) {
                $resolvedKeys.Add($trimmed) | Out-Null
            }
        }
    }

    return @($resolvedKeys)
}

function Get-SelectedPrinterConfigs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ConfigData,

        [Parameter()]
        [string[]]$PrinterKeys,

        [Parameter()]
        [switch]$InstallAll
    )

    $configuredPrinters = Get-ConfiguredPrinters -ConfigData $ConfigData
    if ($InstallAll.IsPresent) {
        return $configuredPrinters
    }

    $resolvedKeys = Resolve-PrinterKeys -PrinterKeys $PrinterKeys
    if ($resolvedKeys.Count -eq 0) {
        return @()
    }

    $selected = New-Object 'System.Collections.Generic.List[hashtable]'
    $knownKeys = @{}
    foreach ($printer in $configuredPrinters) {
        $knownKeys[$printer.Key] = $printer
    }

    foreach ($key in $resolvedKeys) {
        if (-not $knownKeys.ContainsKey($key)) {
            throw ("Unknown printer key: {0}" -f $key)
        }

        $selected.Add($knownKeys[$key]) | Out-Null
    }

    return @($selected)
}

function Join-PrinterInfPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [Parameter(Mandatory = $true)]
        [hashtable]$PrinterConfig
    )

    return Join-Path -Path (Join-Path -Path $BasePath -ChildPath $PrinterConfig.DriverFolder) -ChildPath $PrinterConfig.InfFile
}

function Test-DriverFoldersForConfigs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [Parameter(Mandatory = $true)]
        [array]$PrinterConfigs
    )

    $available = New-Object 'System.Collections.Generic.List[hashtable]'
    $missing = New-Object 'System.Collections.Generic.List[hashtable]'

    foreach ($config in $PrinterConfigs) {
        $driverFolderPath = Join-Path -Path $BasePath -ChildPath $config.DriverFolder
        if (Test-Path -Path $driverFolderPath) {
            $available.Add($config) | Out-Null
        }
        else {
            $missing.Add($config) | Out-Null
        }
    }

    return @{
        Available = @($available)
        Missing = @($missing)
    }
}

function Test-PrinterExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PrinterName
    )

    return ($null -ne (Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue))
}

function Test-PrinterDriverExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DriverName
    )

    return ($null -ne (Get-PrinterDriver -Name $DriverName -ErrorAction SilentlyContinue))
}

function Get-PrinterPortSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PortName
    )

    try {
        return Get-PrinterPort -Name $PortName -ErrorAction Stop
    }
    catch {
        return $null
    }
}

function Get-PrinterPortHostAddress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PortName
    )

    $port = Get-PrinterPortSafe -PortName $PortName
    if ($null -eq $port) {
        return $null
    }

    if (-not [string]::IsNullOrWhiteSpace($port.PrinterHostAddress)) {
        return $port.PrinterHostAddress
    }

    if (-not [string]::IsNullOrWhiteSpace($port.HostAddress)) {
        return $port.HostAddress
    }

    return $null
}

function Install-PrinterDriverFromInf {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InfPath,

        [Parameter(Mandatory = $true)]
        [string]$DriverName
    )

    if (-not (Test-Path -Path $InfPath)) {
        throw ("INF file not found: {0}" -f $InfPath)
    }

    if (Test-PrinterDriverExists -DriverName $DriverName) {
        return 'AlreadyPresent'
    }

    $printUiArguments = "printui.dll,PrintUIEntry /ia /m `"{0}`" /f `"{1}`" /h x64" -f $DriverName, $InfPath
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = 'rundll32.exe'
    $processInfo.Arguments = $printUiArguments
    $processInfo.UseShellExecute = $true
    $processInfo.CreateNoWindow = $true
    $processInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden

    $process = [System.Diagnostics.Process]::Start($processInfo)
    $completed = $process.WaitForExit(60000)
    if (-not $completed) {
        try {
            $process.Kill()
        }
        catch {
        }
    }

    Start-Sleep -Seconds 2
    if (Test-PrinterDriverExists -DriverName $DriverName) {
        return 'Installed'
    }

    $null = & pnputil.exe /add-driver $InfPath /install 2>&1
    Start-Sleep -Seconds 2

    if (Test-PrinterDriverExists -DriverName $DriverName) {
        return 'Installed'
    }

    Add-PrinterDriver -Name $DriverName -InfPath $InfPath -ErrorAction Stop
    Start-Sleep -Seconds 2

    if (-not (Test-PrinterDriverExists -DriverName $DriverName)) {
        throw ("Driver installation failed: {0}" -f $DriverName)
    }

    return 'Installed'
}

function Ensure-TcpIpPrinterPort {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PortName,

        [Parameter(Mandatory = $true)]
        [string]$IPAddress
    )

    $existingPort = Get-PrinterPortSafe -PortName $PortName
    if ($null -eq $existingPort) {
        Add-PrinterPort -Name $PortName -PrinterHostAddress $IPAddress -ErrorAction Stop
        return 'Created'
    }

    $existingHostAddress = Get-PrinterPortHostAddress -PortName $PortName
    if ($existingHostAddress -eq $IPAddress -or [string]::IsNullOrWhiteSpace($existingHostAddress)) {
        return 'Reused'
    }

    $portUsers = @(Get-Printer -ErrorAction SilentlyContinue | Where-Object { $PSItem.PortName -eq $PortName })
    if ($portUsers.Count -gt 0) {
        throw ("Port {0} already exists and points to {1}." -f $PortName, $existingHostAddress)
    }

    Remove-PrinterPort -Name $PortName -ErrorAction Stop
    Add-PrinterPort -Name $PortName -PrinterHostAddress $IPAddress -ErrorAction Stop
    return 'Recreated'
}

function Install-NetworkPrinter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$PrinterConfig,

        [Parameter(Mandatory = $true)]
        [string]$BasePath
    )

    $printerName = $PrinterConfig.PrinterName
    $driverName = $PrinterConfig.DriverName
    $ipAddress = $PrinterConfig.IPAddress
    $portName = 'IP_{0}' -f $ipAddress
    $infPath = Join-PrinterInfPath -BasePath $BasePath -PrinterConfig $PrinterConfig

    if (Test-PrinterExists -PrinterName $printerName) {
        return 'Skipped'
    }

    $null = Install-PrinterDriverFromInf -InfPath $infPath -DriverName $driverName
    $null = Ensure-TcpIpPrinterPort -PortName $portName -IPAddress $ipAddress
    Add-Printer -Name $printerName -DriverName $driverName -PortName $portName -ErrorAction Stop
    return 'Success'
}

function Remove-ConflictingPrintersAndDrivers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$PrinterConfigs
    )

    $results = @{
        RemovedPrinters = @()
        FailedPrinters = @()
        RemovedPorts = @()
        FailedPorts = @()
        RemovedDrivers = @()
        FailedDrivers = @()
    }

    $selectedIps = @{}
    $selectedNames = @{}
    foreach ($config in $PrinterConfigs) {
        $selectedIps[$config.IPAddress] = $true
        $selectedNames[$config.PrinterName] = $true
    }

    $printers = @(Get-Printer -ErrorAction SilentlyContinue)
    foreach ($printer in $printers) {
        $portHostAddress = Get-PrinterPortHostAddress -PortName $printer.PortName
        $matchesName = $selectedNames.ContainsKey($printer.Name)
        $matchesIp = (-not [string]::IsNullOrWhiteSpace($portHostAddress) -and $selectedIps.ContainsKey($portHostAddress))
        if (-not ($matchesName -or $matchesIp)) {
            continue
        }

        try {
            Remove-Printer -Name $printer.Name -ErrorAction Stop
            $results.RemovedPrinters += $printer.Name
        }
        catch {
            $results.FailedPrinters += $printer.Name
        }
    }

    Start-Sleep -Seconds 2

    foreach ($config in $PrinterConfigs) {
        $portName = 'IP_{0}' -f $config.IPAddress
        $port = Get-PrinterPortSafe -PortName $portName
        if ($null -eq $port) {
            continue
        }

        $portUsers = @(Get-Printer -ErrorAction SilentlyContinue | Where-Object { $PSItem.PortName -eq $portName })
        if ($portUsers.Count -gt 0) {
            continue
        }

        try {
            Remove-PrinterPort -Name $portName -ErrorAction Stop
            $results.RemovedPorts += $portName
        }
        catch {
            $results.FailedPorts += $portName
        }
    }

    foreach ($config in $PrinterConfigs) {
        $driverUsers = @(Get-Printer -ErrorAction SilentlyContinue | Where-Object { $PSItem.DriverName -eq $config.DriverName })
        if ($driverUsers.Count -gt 0) {
            continue
        }

        if (-not (Test-PrinterDriverExists -DriverName $config.DriverName)) {
            continue
        }

        try {
            Remove-PrinterDriver -Name $config.DriverName -ErrorAction Stop
            $results.RemovedDrivers += $config.DriverName
        }
        catch {
            $results.FailedDrivers += $config.DriverName
        }
    }

    return $results
}

function Write-ExternalOutput {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object[]]$OutputLines
    )

    if ($null -eq $OutputLines) {
        return
    }

    foreach ($line in $OutputLines) {
        $text = [string]$line
        if (-not [string]::IsNullOrWhiteSpace($text)) {
            Write-Host ("    {0}" -f $text) -ForegroundColor DarkGray
        }
    }
}

function Copy-DriverFilesToLocalStage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceDriverPath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationDriverPath,

        [Parameter(Mandatory = $true)]
        [string]$InfFileName
    )

    if (-not (Test-Path -Path $DestinationDriverPath)) {
        New-Item -Path $DestinationDriverPath -ItemType Directory -Force | Out-Null
    }

    $destinationInfPath = Join-Path -Path $DestinationDriverPath -ChildPath $InfFileName
    if (Test-Path -Path $destinationInfPath) {
        return 'Reused'
    }

    Copy-Item -Path (Join-Path -Path $SourceDriverPath -ChildPath '*') -Destination $DestinationDriverPath -Recurse -Force
    return 'Copied'
}

function Resolve-SwapDriverSource {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$DriverSharePath,

        [Parameter(Mandatory = $true)]
        [string]$DriverFolder,

        [Parameter(Mandatory = $true)]
        [string]$InfFile,

        [Parameter(Mandatory = $true)]
        [string]$LocalStagePath
    )

    if (-not [string]::IsNullOrWhiteSpace($DriverSharePath)) {
        $networkDriverPath = Join-Path -Path $DriverSharePath -ChildPath $DriverFolder
        $networkInfPath = Join-Path -Path $networkDriverPath -ChildPath $InfFile
        if (Test-Path -Path $networkInfPath) {
            return @{
                Mode = 'Network'
                DriverPath = $networkDriverPath
                InfPath = $networkInfPath
            }
        }
    }

    $localInfPath = Join-Path -Path $LocalStagePath -ChildPath $InfFile
    if (Test-Path -Path $localInfPath) {
        return @{
            Mode = 'LocalCache'
            DriverPath = $LocalStagePath
            InfPath = $localInfPath
        }
    }

    throw 'No reachable driver source was found for the replacement printer.'
}

function Resolve-PublishedInfName {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$InfPath
    )

    if ([string]::IsNullOrWhiteSpace($InfPath)) {
        return $null
    }

    $leaf = Split-Path -Path $InfPath -Leaf
    if ($leaf -match '^oem\d+\.inf$') {
        return $leaf
    }

    if ($InfPath -match '^oem\d+\.inf$') {
        return $InfPath
    }

    return $null
}

function Resolve-PrinterDriverPublishedInfName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DriverName,

        [Parameter()]
        [string]$PublishedInfName
    )

    if (-not [string]::IsNullOrWhiteSpace($PublishedInfName)) {
        return $PublishedInfName
    }

    try {
        $escapedDriverName = $DriverName.Replace("'", "''")
        $cimDriver = Get-CimInstance -ClassName Win32_PrinterDriver -Filter ("Name = '{0}'" -f $escapedDriverName) -ErrorAction Stop
        if ($null -ne $cimDriver) {
            return Resolve-PublishedInfName -InfPath $cimDriver.InfName
        }
    }
    catch {
    }

    return $null
}

function Remove-DriverStorePackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PublishedInfName
    )

    $output = & pnputil.exe /delete-driver $PublishedInfName /uninstall /force 2>&1
    $exitCode = $LASTEXITCODE
    Write-ExternalOutput -OutputLines $output

    if ($exitCode -ne 0 -and $exitCode -ne 3010) {
        throw ("pnputil returned exit code {0} while removing {1}." -f $exitCode, $PublishedInfName)
    }

    return $exitCode
}

function Ensure-PrinterQueue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PrinterName,

        [Parameter(Mandatory = $true)]
        [string]$DriverName,

        [Parameter(Mandatory = $true)]
        [string]$PortName
    )

    $existingPrinter = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
    if ($null -eq $existingPrinter) {
        Add-Printer -Name $PrinterName -DriverName $DriverName -PortName $PortName -ErrorAction Stop
        return 'Created'
    }

    if ($existingPrinter.DriverName -eq $DriverName -and $existingPrinter.PortName -eq $PortName) {
        return 'AlreadyPresent'
    }

    Remove-Printer -Name $PrinterName -ErrorAction Stop
    Start-Sleep -Seconds 2
    Add-Printer -Name $PrinterName -DriverName $DriverName -PortName $PortName -ErrorAction Stop
    return 'Recreated'
}

function Remove-PrintJobsForPrinter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PrinterName
    )

    if (-not (Test-PrinterExists -PrinterName $PrinterName)) {
        return 'Skipped'
    }

    $jobs = @(Get-PrintJob -PrinterName $PrinterName -ErrorAction SilentlyContinue)
    if ($jobs.Count -eq 0) {
        return 'Skipped'
    }

    foreach ($job in $jobs) {
        Remove-PrintJob -PrinterName $PrinterName -ID $job.ID -Confirm:$false -ErrorAction Stop
    }

    return 'Removed'
}
