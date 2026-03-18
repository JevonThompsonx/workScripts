← [Back to root](../README.md)

# Runners

Master orchestration scripts that download and run all setup steps in sequence from the workScripts GitHub repository.

## Scripts

| File | Description | Elevation | Key Parameters |
|------|-------------|-----------|----------------|
| [Run-All-Work-Scriptsv1.2.ps1](Run-All-Work-Scriptsv1.2.ps1) | Interactive master setup orchestrator (v1.3) | Required | `-NonInteractive`, `-SkipArchiveInstall`, `-SkipDebloat`, `-SkipRmmInstall` |
| [Run-All-Work-Scriptsv1.2-RMM.ps1](Run-All-Work-Scriptsv1.2-RMM.ps1) | Non-interactive RMM orchestrator | Required | `-AdministratorPassword`, `-AdministratorPasswordBase64`, `-SkipSetup`, `-SkipDriveClone`, `-RunRaphireDebloat`, `-RunEngineeringDebloat` |

## Usage

### Run-All-Work-Scriptsv1.2.ps1

Interactive run (prompts for confirmation at each step):

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Runners/Run-All-Work-Scriptsv1.2.ps1')"
```

Non-interactive (skips prompts, suitable for hands-off deployment):

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Runners/Run-All-Work-Scriptsv1.2.ps1')" -NonInteractive -SkipDebloat -SkipRmmInstall
```

### Run-All-Work-Scriptsv1.2-RMM.ps1

RMM deployment with plain-text password:

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Runners/Run-All-Work-Scriptsv1.2-RMM.ps1')" -AdministratorPassword "<YOUR_PASSWORD>"
```

Base64-encoded password (use when the RMM UI blocks special characters):

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Runners/Run-All-Work-Scriptsv1.2-RMM.ps1')" -AdministratorPasswordBase64 "<BASE64_UTF8_PASSWORD>"
```
