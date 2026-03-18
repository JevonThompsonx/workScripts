# sfcDism.ps1

## What this script is

`sfcDism.ps1` is a daily Windows maintenance script for NinjaOne-managed computers.

Its job is to keep Windows servicing healthy without doing anything destructive to user data. It checks the health of the Windows image, runs repair tools on a safe schedule, makes sure key repair services are working, and leaves clear logs for review.

In plain English:

- it checks whether Windows needs a reboot before or after maintenance
- it makes sure there is enough free disk space to run repair tasks safely
- it prepares the Windows repair services that DISM and SFC depend on
- it runs light health checks every day
- it runs heavier repair tasks only when due, so endpoints are not doing the most expensive work every single day
- it writes logs in a NinjaOne-friendly way
- it avoids touching user files and avoids risky cleanup by default

This script is built for:

- PowerShell 5.1
- NinjaOne RMM
- scheduled maintenance
- safe repeat execution

## Default behavior

By default, the script is tuned for a daily schedule:

- `DISM /CheckHealth` can run every day
- medium-cost tasks run every 3 days
- heavy tasks run every 7 days
- reboot-needed or warning states return success in `NinjaFriendly` mode so simple RMM wrappers do not mark healthy maintenance runs as failures

## What it can do

Depending on settings, the script can run:

- `CHKDSK /scan`
- `DISM /CheckHealth`
- `DISM /ScanHealth`
- `DISM /RestoreHealth`
- `DISM /AnalyzeComponentStore`
- `DISM /StartComponentCleanup`
- `SFC /scannow`
- optional Windows Update download cache reset for a DISM retry
- optional stale Delivery Optimization cache cleanup

## Safe-by-default choices

The script intentionally avoids a few things unless you explicitly enable them:

- no aggressive Windows Update cache reset every day
- no broad folder deletion outside of maintenance-specific cache paths
- no user profile cleanup
- no temp file sweeps across user folders
- no registry hacks to fake away pending reboot state
- no forced reboot

## Files and locations

- Script: `P:\Archive\Projects\Windows 11 update\sfcDism.ps1`
- Logs: `C:\ProgramData\Scripts\Logs\sfcDism`
- State file: `C:\ProgramData\Scripts\State\sfcDism\MaintenanceState.clixml`
- DISM log: `C:\Windows\Logs\DISM\dism.log`
- CBS log: `C:\Windows\Logs\CBS\CBS.log`

## Simple recommended use

For a normal daily NinjaOne schedule, the current defaults are a good starting point:

- `UseCadenceControl=true`
- `RunCheckHealth=true`
- `RunScanHealth=true`
- `RunAnalyzeComponentStore=true`
- `RunRestoreHealth=true`
- `RunStartComponentCleanup=true`
- `RunSfc=true`
- `RunChkdskScan=true`
- `RunDeliveryOptimizationCacheCleanup=false`
- `ResetWindowsUpdateComponents=false`
- `ExitCodeMode=NinjaFriendly`

## More detail

### Why cadence control exists

This script is meant to run every day. That does not mean every repair action should run every day.

Some commands are light and useful as daily checks. Others are heavier and can add unnecessary load, disk churn, or servicing time if repeated too often. The cadence system lets the script stay useful daily without behaving like a full repair marathon every single run.

Current defaults:

- medium tasks every 3 days
- heavy tasks every 7 days

The script stores successful run times in `C:\ProgramData\Scripts\State\sfcDism\MaintenanceState.clixml` so it knows when each task is next due.

### What counts as medium vs heavy

Medium tasks:

- `DISM /ScanHealth`
- `DISM /AnalyzeComponentStore`

Heavy tasks:

- `CHKDSK /scan`
- `DISM /RestoreHealth`
- `DISM /StartComponentCleanup`
- `SFC /scannow`
- optional Delivery Optimization cache cleanup

`DISM /CheckHealth` is kept as the lightweight daily check.

### Why NinjaFriendly exit mode is the default

Many RMM wrappers treat any non-zero exit code as a hard failure.

That becomes misleading when the maintenance script actually worked but Windows still reports one of these normal follow-up states:

- a reboot is still pending
- a repair completed with a warning that needs review
- all heavy tasks were skipped because they are not due yet

In `NinjaFriendly` mode, the script still prints those states clearly in output, but returns `0` unless there is a true critical failure.

If you want stricter automation behavior, switch to:

- `ExitCodeMode=Strict`

### Why some options stay off by default

#### ResetWindowsUpdateComponents

This is useful for targeted troubleshooting, but not ideal as daily maintenance. Resetting update download state too often can increase re-download activity and create noise in normal update behavior.

#### RunDeliveryOptimizationCacheCleanup

This can reclaim space, but if you run it too often on many devices it may reduce the benefit of Delivery Optimization and increase bandwidth usage. That is why it is available, but disabled by default.

### What the script checks before repair work

Before it does maintenance, it validates:

- admin or SYSTEM context
- command availability
- repair source path, if provided
- operating system details
- free space on the system drive
- pending reboot state
- required servicing services such as TrustedInstaller, Windows Update, Cryptographic Services, and BITS

### Logging and review

The script is designed to be easy to review later in NinjaOne or on the local machine.

It writes:

- a normal log file
- a transcript file
- step-by-step status lines through `Write-Host`
- short summaries of command output instead of dumping huge raw logs into the activity feed

If SFC reports corruption it cannot fully fix, the script also summarizes recent `[SR]` entries from `CBS.log`.

### Custom fields

The script does not require NinjaOne custom fields, but it can write to them if you provide:

- `ResultFieldName`
- `DetailsFieldName`

That lets you store a short summary and a longer maintenance detail string on the device record.

### Good use cases

This script is a good fit for:

- daily servicing health maintenance
- light ongoing remediation across many endpoints
- detecting devices that repeatedly show reboot-pending or servicing issues
- keeping a regular repair baseline without overdoing expensive repair steps

### Not the best use case

This script is not meant to be the most aggressive one-time break/fix tool for a badly damaged Windows image. For that kind of incident response, you may want a separate targeted remediation script with more aggressive options and technician review.

### Suggested operations pattern

If you want a clean operational pattern:

- run `sfcDism.ps1` daily for maintenance
- use targeted remediation scripts only when a device still shows update or servicing problems
- treat repeated pending reboot states as an operational follow-up item, not something to suppress in script logic

### Version note

This readme matches the cadence-aware maintenance version of the script:

- `Version: 5.0.0`
