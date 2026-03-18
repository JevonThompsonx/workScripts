# Windows 11 update unblocker

This folder contains a PowerShell 5.1 remediation script for Windows 11 feature updates that get stuck mid-upgrade, including the common "stuck around 61 percent" case.

Files:

- `Invoke-WindowsUpdateRemediation.ps1` - main remediation script for NinjaOne or manual elevated runs
- `Invoke-WindowsUpdateRemediation.cmd` - simple wrapper for manual double-click use
- `prompt.md` - project instructions and guardrails

What the script does:

- validates admin context, OS info, free space, and pending reboot state
- archives useful Panther and SetupDiag logs before cleanup when available
- stops update-related services safely
- clears BITS queue files, SoftwareDistribution cache, catroot2, Delivery Optimization cache, and stale feature update staging folders
- optionally runs DISM, SFC, Winsock reset, WinHTTP proxy reset, aggressive ACL reset, legacy DLL reregistration, and a post-fix update scan trigger
- returns RMM-friendly exit codes: `0`, `1`, `2`, `100`, `3010`

NinjaOne notes:

- PowerShell 5.1 compatible
- uses `Write-Host` for Activities feed visibility
- supports Script Variables through both parameters and `$env:VarName`
- no custom fields are required, but optional result fields are supported
- defaults to `ExitCodeMode=NinjaFriendly` so handled warnings and reboot-required outcomes are not mislabeled as hard failures by simple RMM wrappers

Typical usage:

```powershell
.\Invoke-WindowsUpdateRemediation.ps1 -Mode Diagnose
.\Invoke-WindowsUpdateRemediation.ps1 -Mode Remediate
```

Suggested NinjaOne defaults:

- `Mode=Remediate`
- `RunComponentRepair=true`
- `RunSystemFileChecker=true`
- `ClearDeliveryOptimizationCache=true`
- `ClearFeatureUpdateStaging=true`
- `ResetWinsock=false`
- `ResetWinHttpProxy=false`
- `AggressiveServiceAclReset=false`
- `LegacyDllReregistration=false`
- `ExitCodeMode=NinjaFriendly`

Why some risky fixes stay optional:

- proxy reset can break managed proxy environments
- Winsock reset usually needs a reboot
- service ACL reset and DLL reregistration are later-stage recovery steps, not safe first-line defaults
- deleting `pending.xml` is intentionally not done because it can worsen servicing corruption
