# Test script to verify key functions work on this system
# This is a read-only test - won't make changes

Write-Host "=========================================="
Write-Host "EGNYTE SCRIPTS VALIDATION TEST"
Write-Host "=========================================="

# Test 1: Administrator check
Write-Host "`n[TEST 1] Administrator Privileges"
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host "Running as Administrator: $isAdmin"

# Test 2: Detect installed Egnyte version
Write-Host "`n[TEST 2] Detecting Installed Egnyte"
$uninstallPaths = @(
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

$egnyteProducts = @()
foreach ($path in $uninstallPaths) {
    $products = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -like '*Egnyte*' }
    if ($products) {
        $egnyteProducts += $products
    }
}

if ($egnyteProducts) {
    foreach ($p in $egnyteProducts) {
        Write-Host "  Found: $($p.DisplayName)"
        Write-Host "  Version: $($p.DisplayVersion)"
        Write-Host "  Uninstall: $($p.UninstallString)"
        Write-Host "  Product Code: $($p.PSChildName)"
        Write-Host ""
    }
} else {
    Write-Host "  No Egnyte found in registry"
}

# Test 3: Detect running processes
Write-Host "`n[TEST 3] Detecting Egnyte Processes"
$procs = Get-Process | Where-Object { $_.Name -like '*egnyte*' }
if ($procs) {
    foreach ($p in $procs) {
        Write-Host "  Process: $($p.Name) (PID: $($p.Id))"
        Write-Host "    Path: $($p.Path)"
    }
} else {
    Write-Host "  No Egnyte processes running"
}

# Test 4: Detect services
Write-Host "`n[TEST 4] Detecting Egnyte Services"
$services = Get-Service | Where-Object { $_.Name -like '*egnyte*' -or $_.DisplayName -like '*Egnyte*' }
if ($services) {
    foreach ($s in $services) {
        Write-Host "  Service: $($s.Name) ($($s.DisplayName))"
        Write-Host "    Status: $($s.Status)"
    }
} else {
    Write-Host "  No Egnyte services found"
}

# Test 5: Detect installation folders
Write-Host "`n[TEST 5] Detecting Egnyte Folders"
$folders = @(
    "$env:ProgramFiles\Egnyte",
    "$env:ProgramFiles\Egnyte Connect",
    "${env:ProgramFiles(x86)}\Egnyte",
    "${env:ProgramFiles(x86)}\Egnyte Connect",
    "$env:ProgramData\Egnyte",
    "C:\Egnyte Data",
    "C:\Egnyte Sync"
)

foreach ($f in $folders) {
    if (Test-Path $f) {
        $size = (Get-ChildItem $f -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        $sizeMB = [math]::Round($size/1MB, 2)
        Write-Host "  EXISTS: $f ($sizeMB MB)"
    }
}

# Test 6: Network connectivity to Egnyte CDN
Write-Host "`n[TEST 6] Testing Network Connectivity"
try {
    $null = [System.Net.Dns]::GetHostAddresses('egnyte-cdn.egnyte.com')
    Write-Host "  DNS Resolution: OK"
    
    $testRequest = [System.Net.WebRequest]::Create('https://egnyte-cdn.egnyte.com/egnytedrive/win/en-us/latest/')
    $testRequest.Method = 'HEAD'
    $testRequest.Timeout = 10000
    $response = $testRequest.GetResponse()
    Write-Host "  HTTPS Connectivity: OK (Status: $($response.StatusCode))"
    $response.Close()
} catch {
    Write-Host "  Network Test Failed: $_" -ForegroundColor Red
}

# Test 7: Check BITS service
Write-Host "`n[TEST 7] BITS Service Status"
$bits = Get-Service -Name 'BITS' -ErrorAction SilentlyContinue
if ($bits) {
    Write-Host "  BITS Service: $($bits.Status)"
} else {
    Write-Host "  BITS Service: NOT FOUND" -ForegroundColor Red
}

# Test 8: Check scheduled tasks
Write-Host "`n[TEST 8] Egnyte Scheduled Tasks"
$tasks = Get-ScheduledTask | Where-Object { $_.TaskName -like '*Egnyte*' -or $_.TaskPath -like '*Egnyte*' }
if ($tasks) {
    foreach ($t in $tasks) {
        Write-Host "  Task: $($t.TaskName)"
        Write-Host "    State: $($t.State)"
    }
} else {
    Write-Host "  No Egnyte scheduled tasks found"
}

Write-Host "`n=========================================="
Write-Host "VALIDATION TEST COMPLETE"
Write-Host "=========================================="
