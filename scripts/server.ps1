# Controls the local Good Store server.
#
#   server.ps1 start    check Java + MySQL, build, start in the background, wait until it answers
#   server.ps1 stop     stop the background server
#   server.ps1 status   is it running?
#   server.ps1 logs     show the last lines of backend\logs\server.log
#
# "start" always ends (it does not block), so coding agents can run it too. The server
# keeps running in the background after the command ends. Running "start" again restarts it
# with the newest code.
#
# Keep this file ASCII only: Windows PowerShell 5.1 misreads other characters.

param(
    [ValidateSet('start', 'stop', 'status', 'logs')] [string]$Command = 'start',
    [switch]$NoBrowser
)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$backend = Join-Path $root 'backend'
$logDir = Join-Path $backend 'logs'
$logFile = Join-Path $logDir 'server.log'
$errFile = Join-Path $logDir 'server-error.log'
$pidFile = Join-Path $logDir 'server.pid'
$localProps = Join-Path $backend 'local.properties'
$jar = Join-Path $backend 'target/good-store-0.1.0.jar'
$url = 'http://localhost:8080/'
$onWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or $IsWindows

function Say($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }
function Ok($text) { Say "  [OK]   $text" 'Green' }
function Stop-With($problem, [string[]]$fix) {
    Say ''
    Say "  [STOP] $problem" 'Red'
    Say ''
    Say '  How to fix:' 'Yellow'
    foreach ($line in $fix) { Say "    $line" 'Yellow' }
    Say ''
    exit 1
}
function Test-Port($port) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $task = $client.ConnectAsync('127.0.0.1', $port)
        return ($task.Wait(1500) -and $client.Connected)
    } catch { return $false } finally { $client.Close() }
}
function Test-Health {
    try { return ((Invoke-RestMethod "$($url)api/health" -TimeoutSec 3) -match 'running') } catch { return $false }
}
function Get-ServerProcess {
    if (Test-Path $pidFile) {
        $id = (Get-Content $pidFile -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($id) {
            $p = Get-Process -Id ([int]$id) -ErrorAction SilentlyContinue
            if ($p -and $p.ProcessName -match '^java') { return $p }
        }
    }
    if ($onWindows) {
        $conn = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($conn) {
            $p = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
            if ($p -and $p.ProcessName -match '^java') { return $p }
        }
    }
    return $null
}
function Stop-Server {
    $p = Get-ServerProcess
    if ($p) {
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        for ($i = 0; $i -lt 20 -and (Test-Port 8080); $i++) { Start-Sleep -Milliseconds 500 }
        Ok "Stopped the old server (process $($p.Id))"
    }
    Remove-Item $pidFile -ErrorAction SilentlyContinue
    if (Test-Port 8080) {
        Stop-With 'Another program (not this store) uses port 8080.' @(
            'Close other servers or apps that use port 8080, then try again.',
            'To see which program it is, run in PowerShell:',
            '  Get-Process -Id (Get-NetTCPConnection -LocalPort 8080).OwningProcess')
    }
}
function Show-LogHint {
    $text = ''
    foreach ($f in @($logFile, $errFile)) { if (Test-Path $f) { $text += (Get-Content $f -Raw -ErrorAction SilentlyContinue) } }
    $hints = @(
        @{ Pattern = 'Access denied for user'; Name = 'Wrong MySQL password'; Fix = @('The saved password was deleted. Double-click start.cmd and type the right MySQL root password.') }
        @{ Pattern = 'Communications link failure'; Name = 'Cannot reach MySQL'; Fix = @('Start the MySQL service in the Windows "Services" app, then start again.', 'Coding agent: run this command outside the sandbox.') }
        @{ Pattern = 'Public Key Retrieval is not allowed'; Name = 'MySQL login method'; Fix = @('Open "MySQL 8.4 Command Line Client" from the Start menu, type the password once, close it, then start again.') }
        @{ Pattern = 'Port 8080 was already in use'; Name = 'Port 8080 is busy'; Fix = @('Double-click stop.cmd, then start again.') }
        @{ Pattern = 'Unknown column'; Name = 'Old database tables'; Fix = @('The tables are older than the code. Double-click reset-db.cmd (deletes local test data only), then start again.') }
        @{ Pattern = "Table '[^']+' doesn't exist"; Name = 'Missing table'; Fix = @('Double-click reset-db.cmd (deletes local test data only), then start again.') }
    )
    foreach ($hint in $hints) {
        if ($text -match $hint.Pattern) {
            if ($hint.Name -eq 'Wrong MySQL password') { Remove-Item $localProps -ErrorAction SilentlyContinue }
            Say ''
            Say "  PROBLEM FOUND: $($hint.Name)" 'Red'
            foreach ($h in $hint.Fix) { Say "  $h" 'Yellow' }
            return
        }
    }
}
function Show-LogTail($lines) {
    if (Test-Path $logFile) { Get-Content $logFile -Tail $lines | ForEach-Object { Say "  | $_" 'DarkGray' } }
    if ((Test-Path $errFile) -and (Get-Item $errFile).Length -gt 0) { Get-Content $errFile -Tail $lines | ForEach-Object { Say "  | $_" 'DarkGray' } }
}

switch ($Command) {
    'status' {
        $p = Get-ServerProcess
        if (Test-Health) { Ok "Server is running at $url (process $(if ($p) { $p.Id } else { '?' }))"; exit 0 }
        Say '  Server is not running. Start it with start.cmd.' 'Yellow'; exit 1
    }
    'logs' {
        if (-not (Test-Path $logFile)) { Say '  No log yet. Start the server first.' 'Yellow'; exit 1 }
        Show-LogTail 80; exit 0
    }
    'stop' {
        if (-not (Get-ServerProcess)) { Say '  The server was not running.'; Remove-Item $pidFile -ErrorAction SilentlyContinue; exit 0 }
        Stop-Server; exit 0
    }
}

# ---------------- start ----------------
Say ''
Say '  The Good Store - start' 'Cyan'
Say '  ----------------------' 'Cyan'

# 1. Java 21 or newer
$javaExe = $null
$exe = if ($onWindows) { 'java.exe' } else { 'java' }
if ($env:JAVA_HOME) {
    $candidate = Join-Path (Join-Path $env:JAVA_HOME 'bin') $exe
    if (Test-Path $candidate) { $javaExe = $candidate }
    else {
        Stop-With "JAVA_HOME points to a folder without Java: $env:JAVA_HOME" @(
            'Windows search: "Edit the system environment variables" > "Environment Variables...".',
            'Fix or delete JAVA_HOME, close all terminal windows, then start again.')
    }
} else {
    $cmd = Get-Command java -ErrorAction SilentlyContinue
    if ($cmd) { $javaExe = $cmd.Source }
}
if (-not $javaExe) {
    Stop-With 'Java is not installed (or this window was opened before Java was installed).' @(
        'In PowerShell, run:  winget install EclipseAdoptium.Temurin.21.JDK',
        'Close ALL terminal windows (and restart Codex), then start again.')
}
$versionText = (& $javaExe -version 2>&1 | ForEach-Object { "$_" }) -join "`n"
$javaMajor = 0
if ($versionText -match 'version "(\d+)') { $javaMajor = [int]$Matches[1] }
if ($javaMajor -lt 21) {
    Stop-With "Java is too old (found version $javaMajor, need 21 or newer)." @(
        'In PowerShell, run:  winget install EclipseAdoptium.Temurin.21.JDK',
        'If Java 21 is already installed, JAVA_HOME may point to the old Java.',
        'Close ALL terminal windows (and restart Codex), then start again.')
}
# Make the Maven Wrapper use this same Java.
if (-not $env:JAVA_HOME) {
    $javaHome = Split-Path -Parent (Split-Path -Parent $javaExe)
    if (Test-Path (Join-Path (Join-Path $javaHome 'bin') $exe)) { $env:JAVA_HOME = $javaHome }
}
Ok "Java $javaMajor"

# 2. MySQL is running
$dbPort = if ($env:MYSQLPORT) { [int]$env:MYSQLPORT } else { 3306 }
if (-not (Test-Port $dbPort)) {
    $service = $null
    if ($onWindows) { $service = Get-Service -Name 'MySQL*' -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if ($service) {
        Say "  MySQL service '$($service.Name)' is stopped. Trying to start it..." 'Yellow'
        Start-Service $service.Name -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
    }
    if (-not (Test-Port $dbPort)) {
        if ($service) {
            Stop-With "MySQL is installed but not running (service '$($service.Name)')." @(
                'Press the Windows key, type "Services", open it.',
                "Find '$($service.Name)', right-click it, click Start. Then start again.")
        }
        Stop-With "Cannot reach MySQL on port $dbPort." @(
            'Not installed? Get "MySQL Community Server 8.4" (Windows MSI) from https://dev.mysql.com/downloads/mysql/',
            '  Choose "Development Computer", set a root password, keep "Start at System Startup" on.',
            'Installed? Start the MySQL service in the Windows "Services" app.',
            'Coding agent: the sandbox can block this check. Run this command outside the sandbox.')
    }
}
Ok "MySQL is running on port $dbPort"

# 3. MySQL password, saved once in backend\local.properties (Git ignores this file)
if (-not $env:MYSQLPASSWORD -and -not (Test-Path $localProps)) {
    Say ''
    Say '  Type the MySQL root password you chose when you installed MySQL.' 'Yellow'
    Say '  (Nothing shows while you type. That is normal. Press Enter when done.)' 'Yellow'
    try {
        $secure = Read-Host '  MySQL password' -AsSecureString
    } catch {
        Stop-With 'The MySQL password is not saved yet, and this window cannot ask for it.' @(
            'The student must double-click start.cmd once and type the password.',
            'After that, agents can start the server without a password prompt.')
    }
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
    # Properties files treat backslash as an escape character.
    $escaped = $plain.Replace('\', '\\')
    $content = "# Local MySQL password for this computer only. Git ignores this file.`r`nspring.datasource.password=$escaped`r`n"
    [IO.File]::WriteAllText($localProps, $content, (New-Object Text.UTF8Encoding($false)))
    Ok 'Password saved in backend\local.properties'
} else {
    Ok 'MySQL password is set'
}

# 4. Stop an old copy, then build. Build errors show here, before anything starts.
Stop-Server
Say ''
Say '  Building... (the first time downloads tools and takes a few minutes)' 'Cyan'
$mvnw = if ($onWindows) { Join-Path $backend 'mvnw.cmd' } else { Join-Path $backend 'mvnw' }
Push-Location $backend
$buildOutput = & $mvnw -q -B -DskipTests package 2>&1 | ForEach-Object { "$_" }
$buildCode = $LASTEXITCODE
Pop-Location
if ($buildCode -ne 0 -or -not (Test-Path $jar)) {
    $buildOutput | Select-Object -Last 40 | ForEach-Object { Say "  | $_" 'DarkGray' }
    Stop-With 'The build failed (see the lines above).' @(
        'If you see "COMPILATION ERROR": copy the [ERROR] lines and paste them to Codex.',
        'If you see "Could not transfer artifact" or "Unknown host": check the internet connection.',
        '  (Coding agent: the sandbox may block downloads. Run this command outside the sandbox.)')
}
Ok 'Build finished'

# 5. Start in the background and wait until it answers.
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
Remove-Item $logFile, $errFile -ErrorAction SilentlyContinue
# On Windows use javaw.exe: it has no console window that someone could close by mistake.
$serverJava = $javaExe
$javaw = Join-Path (Split-Path -Parent $javaExe) 'javaw.exe'
if ($onWindows -and (Test-Path $javaw)) { $serverJava = $javaw }
$startArgs = @{
    FilePath               = $serverJava
    ArgumentList           = @('-jar', 'target/good-store-0.1.0.jar')
    WorkingDirectory       = $backend
    RedirectStandardOutput = $logFile
    RedirectStandardError  = $errFile
    PassThru               = $true
}
$proc = Start-Process @startArgs
Set-Content -Path $pidFile -Value $proc.Id
Say "  Starting (process $($proc.Id))..." 'Cyan'

$up = $false
for ($i = 0; $i -lt 90; $i++) {
    if (Test-Health) { $up = $true; break }
    if ($proc.HasExited) { break }
    Start-Sleep -Seconds 1
}
if (-not $up) {
    if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    Remove-Item $pidFile -ErrorAction SilentlyContinue
    Say ''
    Say '  [STOP] The server did not start. Last log lines:' 'Red'
    Show-LogTail 30
    Show-LogHint
    Say ''
    Say "  Full log: $logFile" 'Yellow'
    exit 1
}

Say ''
Say '  ==================================================' 'Green'
Say "   The store is running:  $url" 'Green'
Say '   It keeps running after you close this window.' 'Green'
Say '   Test it:  check.cmd      Stop it:  stop.cmd' 'Green'
Say "   Log:      backend\logs\server.log" 'Green'
Say '  ==================================================' 'Green'
Say ''
if (-not $NoBrowser) { Start-Process $url }
exit 0
