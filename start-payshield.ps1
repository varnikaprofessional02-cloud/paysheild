<#
  One-click local start for PayShield (Windows).
    Postgres :55433  ->  API :8080  ->  UI :5174

  First run on a new machine: creates the Postgres cluster, Python venv, npm packages and seeds the DBs.
  Later runs: just starts everything.

    .\start-payshield.ps1                              # asks for the repo folder
    .\start-payshield.ps1 -RepoPath "D:\code\paysheild" # repo folder given up front
    .\start-payshield.ps1 -Reset                       # rebuild + reseed the demo databases
#>
param(
    [string]$RepoPath,
    [switch]$Reset,
    [string]$PgBin = "C:\Program Files\PostgreSQL\18\bin",
    [string]$PgData = "C:\pgdata-payshield",
    [int]$PgPort = 55433,
    [int]$Employees = 50
)
$ErrorActionPreference = "Stop"
if (-not $RepoPath) {
    $RepoPath = (Read-Host "PayShield repo folder (the one containing package.json and times-intelligence)").Trim('"', ' ')
}
if (-not (Test-Path (Join-Path $RepoPath "times-intelligence\payshield-ai\scripts\run_portal_prototype.py"))) {
    throw "'$RepoPath' is not the PayShield repo folder (times-intelligence\payshield-ai not found)."
}
$Root = (Resolve-Path $RepoPath).Path
$Api = Join-Path $Root "times-intelligence\payshield-ai"

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Need($cmd, $hint) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { throw "$cmd not found. $hint" }
}
function Wait-Port($port, $seconds) {
    $end = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $end) {
        $c = New-Object Net.Sockets.TcpClient
        try { $c.Connect("127.0.0.1", $port); return $true } catch { Start-Sleep -Seconds 2 } finally { $c.Dispose() }
    }
    return $false
}

Step "Checking prerequisites"
Need python "Install Python 3.11+ and tick 'Add to PATH'."
Need npm "Install Node.js 18+."
if (-not (Test-Path (Join-Path $PgBin "pg_ctl.exe"))) {
    throw "PostgreSQL not found in '$PgBin'. Install PostgreSQL 18 or pass -PgBin '<path to bin>'."
}

# 1. Postgres on $PgPort (own cluster, trust auth, local demo only)
if (-not (Test-Path (Join-Path $PgData "PG_VERSION"))) {
    Step "Creating Postgres cluster in $PgData"
    & (Join-Path $PgBin "initdb.exe") -D $PgData -U postgres -A trust -E UTF8 | Out-Null
    $Reset = $true
}
& (Join-Path $PgBin "pg_ctl.exe") -D $PgData status *> $null
if ($LASTEXITCODE -ne 0) {
    Step "Starting Postgres on port $PgPort"
    & (Join-Path $PgBin "pg_ctl.exe") -D $PgData -o "-p $PgPort" -l (Join-Path $PgData "log.txt") -w start
    if ($LASTEXITCODE -ne 0) { throw "Postgres failed to start, see $PgData\log.txt" }
} else { Step "Postgres already running" }

# 2. Python venv + packages
$Py = Join-Path $Api ".venv\Scripts\python.exe"
if (-not (Test-Path $Py)) {
    Step "Creating Python venv"
    python -m venv (Join-Path $Api ".venv")
    & $Py -m pip install --upgrade pip | Out-Null
    & $Py -m pip install -r (Join-Path $Api "requirements.txt")
    if ($LASTEXITCODE -ne 0) { throw "pip install failed" }
}

# 3. API on :8080 in its own window (with --reset on first run)
$apiArgs = "scripts\run_portal_prototype.py --port $PgPort --pg-bin '$PgBin' --employees $Employees"
if ($Reset) { $apiArgs += " --reset" }
Step "Starting API (new window)$(if ($Reset) { ' - seeding databases, this takes a few minutes' })"
Start-Process powershell -WorkingDirectory $Api -ArgumentList "-NoExit", "-Command",
    "`$Host.UI.RawUI.WindowTitle='PayShield API :8080'; & '$Py' -u $apiArgs"
if (-not (Wait-Port 8080 600)) { throw "API did not come up on :8080, check the API window." }

# 4. UI on :5174 (proxies /api and /dev to :8080)
Set-Location $Root
if (-not (Test-Path (Join-Path $Root "node_modules"))) {
    Step "Installing npm packages"
    npm install
    if ($LASTEXITCODE -ne 0) { throw "npm install failed" }
}
Step "Starting UI at http://localhost:5174  (Ctrl+C to stop the UI; close the API window to stop the API)"
Start-Process "http://localhost:5174"
npx vite --port 5174 --strictPort
