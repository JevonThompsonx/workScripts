# Egnyte Nuke & Update - NinjaOne RMM Edition

Enterprise-grade PowerShell scripts for complete Egnyte removal and reinstallation via NinjaOne RMM. Designed for mass deployment across 300+ endpoints.

---

## Quick Start - Legacy Scripts (One-Liner Remote Execution)

For quick manual fixes or ad-hoc deployments, use these one-liners in an **elevated PowerShell** window:

### Step 1: Nuke Egnyte
```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/workScripts/refs/heads/main/updatingSoftware/egnyteNukeAndUpdate/Egnyte-Nuke.ps1")))
```

### Step 2: Reboot
```powershell
Restart-Computer -Force
```

### Step 3: Install Latest Egnyte

**Option A - Direct MSI Download:**
```
https://egnyte-cdn.egnyte.com/egnytedrive/win/en-us/latest/EgnyteConnectWin.msi
```

**Option B - Run Install Script:**
```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/workScripts/refs/heads/main/updatingSoftware/egnyteNukeAndUpdate/Egnyte-Update.ps1")))
```

---

## Scripts Overview

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `NinjaOne-Egnyte-Nuke.ps1` | Complete Egnyte removal | Stage 1 - Before clean install or troubleshooting |
| `NinjaOne-Egnyte-Install.ps1` | Install/Update Egnyte | Stage 2 - After nuke or for updates |
| `Egnyte-Nuke.ps1` | Legacy manual removal script | Manual/ad-hoc use |
| `Egnyte-Update.ps1` | Legacy manual install script | Manual/ad-hoc use |

---

## NinjaOne Deployment Guide

### Step 1: Create the Nuke Script in NinjaOne

1. Go to **Administration > Library > Automation**
2. Click **Add > New Script**
3. Configure:
   - **Name**: `Egnyte - Complete Removal (Nuke)`
   - **Description**: `Completely removes Egnyte Desktop App and all remnants. Run before reinstall.`
   - **Language**: PowerShell
   - **Architecture**: All
   - **Run As**: System
   - **Paste the contents of `NinjaOne-Egnyte-Nuke.ps1`**
4. Save the script

### Step 2: Create the Install Script in NinjaOne

1. **Add > New Script**
2. Configure:
   - **Name**: `Egnyte - Install/Update`
   - **Description**: `Downloads and installs latest Egnyte Desktop App from official CDN.`
   - **Language**: PowerShell
   - **Architecture**: All
   - **Run As**: System
   - **Paste the contents of `NinjaOne-Egnyte-Install.ps1`**
3. Save the script

### Step 3: Create Scheduled Tasks (Recommended Workflow)

#### For Complete Reinstall (Two-Stage Deployment):

**Stage 1 - Nuke (Day 1)**
1. Create a Scheduled Script Task
2. Select: `Egnyte - Complete Removal (Nuke)`
3. Set parameter: `$ForceReboot = $false` (let NinjaOne handle reboot)
4. Schedule for off-hours (e.g., 6 PM)
5. Add a **Reboot** task to follow

**Stage 2 - Install (Day 2 or after reboot)**
1. Create a Scheduled Script Task  
2. Select: `Egnyte - Install/Update`
3. Use default parameters
4. Schedule for after expected reboot completion

#### For Update Only:
1. Run only `Egnyte - Install/Update`
2. The script handles in-place upgrades automatically

---

## Exit Codes Reference

### Nuke Script Exit Codes
| Code | Meaning | NinjaOne Action |
|------|---------|-----------------|
| 0 | Success - Egnyte fully removed | Continue to Stage 2 |
| 1 | Partial success - Some remnants may exist | Review logs, usually OK to continue |
| 2 | Critical failure - Could not execute | Investigate immediately |
| 100 | Egnyte was not installed | No action needed |

### Install Script Exit Codes
| Code | Meaning | NinjaOne Action |
|------|---------|-----------------|
| 0 | Success - Installed successfully | Complete |
| 1 | Installation failed | Check MSI log |
| 2 | Prerequisites not met (no admin, etc.) | Fix permissions |
| 3 | Download failed | Check network/firewall |
| 4 | MSI installation failed | Check MSI log |
| 5 | Post-install verification failed | Manual review needed |
| 100 | Skipped (already installed, SkipIfInstalled=true) | Expected behavior |
| 3010 | Success - Reboot required | Schedule reboot |

---

## Script Parameters

### NinjaOne-Egnyte-Nuke.ps1

```powershell
# Force automatic reboot after cleanup (default: false)
-ForceReboot $true

# Delay before reboot in seconds (default: 60)
-RebootDelaySeconds 120
```

**NinjaOne Script Variable Example:**
```
-ForceReboot $false
```

### NinjaOne-Egnyte-Install.ps1

```powershell
# Custom download URL (default: official Egnyte CDN)
-DownloadUrl "https://your-internal-server/EgnyteConnect.msi"

# Skip if Egnyte is already installed (default: false)
-SkipIfInstalled $true

# Only install if current version is below this (e.g., "3.30.0")
-MinimumVersion "3.30.0"
```

**NinjaOne Script Variable Example:**
```
-SkipIfInstalled $false -MinimumVersion "3.30.0"
```

---

## Monitoring & Conditions

### Create NinjaOne Conditions for Monitoring

**Condition: Egnyte Not Installed**
```
Registry Key Missing: HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\*
Where DisplayName contains "Egnyte"
```

**Condition: Egnyte Version Below Minimum**
```
Script Result: Run version check script
Compare version to minimum required
```

### Recommended Monitoring Script
```powershell
# Quick Egnyte status check for NinjaOne monitoring
$egnyte = Get-ItemProperty 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -EA SilentlyContinue | 
    Where-Object { $_.DisplayName -like '*Egnyte*' } | Select-Object -First 1

if ($egnyte) {
    Write-Output "Installed: $($egnyte.DisplayName) v$($egnyte.DisplayVersion)"
    exit 0
} else {
    Write-Output "Egnyte NOT INSTALLED"
    exit 1
}
```

---

## Troubleshooting

### Log Locations

| Log | Location | Purpose |
|-----|----------|---------|
| Nuke Transcript | `%TEMP%\EgnyteNuke_*.log` | Full script output |
| Install Transcript | `%TEMP%\EgnyteInstall_Transcript_*.log` | Full script output |
| MSI Install Log | `%TEMP%\EgnyteInstall\EgnyteInstall_*.log` | Detailed MSI operations |
| MSI Uninstall Log | `%TEMP%\EgnyteUninstall_MSI.log` | Uninstall details |

### Common Issues

**Issue: Nuke script reports partial success (Exit 1)**
- Some files may be locked by Explorer
- Solution: Script will clean remaining files on next run or reboot

**Issue: Install fails with Exit 3 (download failed)**
- Check firewall allows HTTPS to `egnyte-cdn.egnyte.com`
- Verify BITS service is running
- Try custom download URL from internal server

**Issue: Install fails with Exit 4 (MSI failed)**
- Check MSI log for specific error
- Common: Another MSI installation in progress (wait and retry)
- Common: Existing Egnyte causing conflict (run Nuke first)

**Issue: Service not running after install**
- This is normal - Egnyte service starts when user logs in
- The client runs in user context, not as a system service

---

## Mass Deployment Strategy

### Recommended Approach for 300+ Endpoints

1. **Pilot Group (5-10 devices)**
   - Run full nuke + install cycle
   - Verify functionality
   - Monitor for 24-48 hours

2. **Phase 1 (25% of fleet)**
   - Schedule during maintenance window
   - Stagger to avoid network saturation

3. **Phase 2-4 (Remaining 75%)**
   - Roll out in batches of 25%
   - Monitor exit codes via NinjaOne dashboard

### Network Considerations
- MSI download is ~100MB
- For large deployments, consider:
  - Hosting MSI on internal server
  - Using BITS throttling
  - Staggering deployment times

---

## Manual Execution

### Running Locally (Admin PowerShell)
```powershell
# Nuke
Set-ExecutionPolicy -Scope Process Bypass
.\NinjaOne-Egnyte-Nuke.ps1 -ForceReboot $false

# After reboot - Install
.\NinjaOne-Egnyte-Install.ps1
```

### Running Remotely Without Download
```powershell
# From GitHub (if you host there)
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/YourOrg/YourRepo/main/NinjaOne-Egnyte-Nuke.ps1")))
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 2.0 | Jan 2025 | Complete rewrite for NinjaOne RMM with enterprise features |
| 1.0 | Original | Basic nuke and install scripts |

## Tested On
- Windows 10 22H2
- Windows 11 23H2
- Egnyte Desktop App 3.31.1.179

## Support
For issues with these scripts, check the NinjaOne script activity logs and the log files listed above.
