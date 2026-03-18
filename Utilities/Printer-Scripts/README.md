# Sanitized Printer Scripts

GitHub-safe PowerShell printer deployment scripts by Jevon Thompson.

This folder is a sanitized template package for Windows printer deployment. It removes business-specific office names, real internal paths, and real LAN IP addresses from the exported scripts while preserving the workflow and structure needed to adapt them for another environment.

## Included Files

- `InstallAllPrinters.ps1` - installs every printer defined in `PrinterConfig.psd1`
- `InstallSelectedPrinters.ps1` - installs only selected printers by config key
- `DeletesAndReinstallsSelectedPrinters.ps1` - removes matching queues, ports, and drivers, then reinstalls selected printers
- `Swap-Printer.ps1` - swaps one existing printer queue for a replacement printer definition
- `PrinterConfig.psd1` - sanitized sample configuration with placeholder printers and paths
- `PrinterCommon.ps1` - shared helper functions used by all scripts

## What Was Sanitized

- Real site or company location codes were replaced with generic names such as `HQ`, `BRANCH`, and `WAREHOUSE`
- Real internal IP addresses were replaced with documentation-only example ranges:
  - `192.0.2.x`
  - `198.51.100.x`
  - `203.0.113.x`
- Real network shares were replaced with a placeholder UNC path: `\\fileserver\PrinterDrivers`
- Local paths were generalized to `C:\PrinterDrivers` and `C:\ProgramData\PrinterScripts\...`
- No driver binaries were copied into this export package

## Recommended Folder Layout

Store the scripts and your extracted printer driver folders together like this:

```text
Sanitized-Printer-Scripts/
|-- InstallAllPrinters.ps1
|-- InstallSelectedPrinters.ps1
|-- DeletesAndReinstallsSelectedPrinters.ps1
|-- Swap-Printer.ps1
|-- PrinterCommon.ps1
|-- PrinterConfig.psd1
|-- README.md
\-- Drivers/
    |-- HQ - Ricoh IM C2510 - 192.0.2.10/
    |   \-- oemsetup.inf
    \-- HQ - Brother HL-L6210DW - 192.0.2.11/
        \-- BROHL20A.INF
```

You can also store driver folders elsewhere and point `BasePath` or `DriverSharePath` to that location.

## Adjust `PrinterConfig.psd1`

Update these values for each real printer:

- `Key` - unique identifier used by selection-based scripts
- `PrinterName` - final Windows printer queue name
- `IPAddress` - printer TCP/IP address
- `DriverFolder` - folder containing the extracted driver files
- `InfFile` - INF file used to stage the driver
- `DriverName` - exact Windows printer driver name

Also update these root settings if needed:

- `BasePath` - local folder used by install scripts
- `DriverSharePath` - network path used by `Swap-Printer.ps1`
- `LogRoot` - transcript log output folder
- `LocalStageRoot` - local cache used by `Swap-Printer.ps1`

## How To Get the Correct Driver Name

If you do not already know the exact `DriverName`, use one of these methods:

1. Check the driver INF and manufacturer/model sections.
2. Install the printer manually once, then run:

```powershell
Get-PrinterDriver | Select-Object Name
```

3. Match the installed driver name exactly in `PrinterConfig.psd1`.

The scripts are sensitive to the exact printer driver name string.

## Usage Examples

Install every configured printer:

```powershell
.\InstallAllPrinters.ps1 -BasePath 'C:\PrinterDrivers'
```

Install selected printers by key:

```powershell
.\InstallSelectedPrinters.ps1 -BasePath 'C:\PrinterDrivers' -PrinterKeys 'HQ_RicohColor','HQ_BrotherMono'
```

Install all printers through an RMM that passes strings:

```powershell
.\InstallSelectedPrinters.ps1 -InstallAll 'true'
```

Delete and reinstall selected printers:

```powershell
.\DeletesAndReinstallsSelectedPrinters.ps1 -BasePath 'C:\PrinterDrivers' -PrinterKeys 'HQ_RicohColor'
```

Swap an old queue for a new printer config entry:

```powershell
.\Swap-Printer.ps1 `
  -OldPrinterName 'Old Office Printer' `
  -OldDriverName 'Old Driver Name' `
  -NewPrinterKey 'HQ_RicohColor' `
  -DriverSharePath '\\fileserver\PrinterDrivers'
```

If you already know the published old OEM INF package name, you can include it:

```powershell
.\Swap-Printer.ps1 -OldPrinterName 'Old Office Printer' -OldDriverName 'Old Driver Name' -OldPublishedInfName 'oem42.inf' -NewPrinterKey 'HQ_RicohColor'
```

## RMM Notes

These scripts work locally in elevated PowerShell and can also be adapted for RMM use.

- `InstallSelectedPrinters.ps1` and `DeletesAndReinstallsSelectedPrinters.ps1` support:
  - `InstallAll`
  - `PrinterKeys`
- If your RMM sets variables as environment variables, the scripts will read:
  - `$env:InstallAll`
  - `$env:PrinterKeys`
  - `$env:BasePath`
  - `$env:DriverSharePath`
  - `$env:LocalStageRoot`

For RMM use, a comma-separated `PrinterKeys` value is usually the simplest pattern.

Example:

- `PrinterKeys=HQ_RicohColor,HQ_BrotherMono`

## Exit Codes

- `0` - success
- `1` - partial success
- `2` - fatal failure
- `100` - nothing to do
- `3010` - success with reboot required

## Before Uploading

Review these items one more time before pushing to GitHub:

- Replace the sample printers in `PrinterConfig.psd1` with your own sanitized or public-safe examples
- Confirm there are no real internal shares, hostnames, or printer names left in the files
- Do not include extracted vendor driver binaries unless you intend to redistribute them
- Test with a non-production printer or a lab machine first

## Suggested Adaptation Workflow

1. Copy this folder into your repo where you want the public version to live.
2. Replace the sample printer entries in `PrinterConfig.psd1`.
3. Put your real extracted drivers in your chosen driver location.
4. Test `InstallSelectedPrinters.ps1` against one printer key first.
5. Test `DeletesAndReinstallsSelectedPrinters.ps1`.
6. Test `Swap-Printer.ps1` last, since it removes an existing queue.

This package is meant to be a clean public template, not a drop-in export of your private environment.
