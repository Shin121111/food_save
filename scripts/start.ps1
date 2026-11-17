# Starts The Good Store on this computer.
# It checks Java, MySQL and the MySQL password first, and prints a fix for each problem.
# Keep this file ASCII only: Windows PowerShell 5.1 misreads other characters.

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$backend = Join-Path $root 'backend'
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

Say ''
Say '  The Good Store - start' 'Cyan'
Say '  ----------------------' 'Cyan'

# 1. Java 21 or newer
$javaExe = $null
if ($env:JAVA_HOME) {
    $candidate = Join-Path $env:JAVA_HOME 'bin/java'
    if ($onWindows) { $candidate += '.exe' }
    if (Test-Path $candidate) { $javaExe = $candidate }
    else {
        Stop-With "JAVA_HOME points to a folder without Java: $env:JAVA_HOME" @(
            'Open Windows search, type "environment variables", open "Edit the system environment variables".',
            'Click "Environment Variables...", then fix or delete JAVA_HOME.',
            'Close this window and double-click start.cmd again.')
    }
} else {
    $cmd = Get-Command java -ErrorAction SilentlyContinue
    if ($cmd) { $javaExe = $cmd.Source }
}
if (-not $javaExe) {
    Stop-With 'Java is not installed (or this window was opened before Java was installed).' @(
        'In PowerShell, run:  winget install EclipseAdoptium.Temurin.21.JDK',
        'Close ALL terminal windows, then double-click start.cmd again.')
}
$versionText = (& $javaExe -version 2>&1 | ForEach-Object { "$_" }) -join "`n"
$javaMajor = 0
if ($versionText -match 'version "(\d+)') { $javaMajor = [int]$Matches[1] }
if ($javaMajor -lt 21) {
    Stop-With "Java is too old (found version $javaMajor, need 21 or newer)." @(
        'In PowerShell, run:  winget install EclipseAdoptium.Temurin.21.JDK',
        'If Java 21 is already installed, JAVA_HOME may point to the old Java: fix it in',
        '  "Edit the system environment variables" > "Environment Variables...".',
        'Close ALL terminal windows, then double-click start.cmd again.')
}
Ok "Java $javaMajor"

# 2. MySQL server is running on port 3306
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
                "Find '$($service.Name)', right-click it, click Start.",
                'Then double-click start.cmd again.')
        }
        Stop-With "MySQL is not running on port $dbPort." @(
            'If MySQL is not installed: get "MySQL Community Server 8.4" (Windows MSI) from',
            '  https://dev.mysql.com/downloads/mysql/',
            '  During setup choose "Development Computer", set a root password',
            '  (write it down), and keep "Start the MySQL Server at System Startup" on.',
            'If it is installed: start the MySQL service in the Windows "Services" app.')
    }
}
Ok "MySQL is running on port $dbPort"

# 3. MySQL password (saved for this Windows user, asked only once)
if ($null -eq $env:MYSQLPASSWORD -and $onWindows) {
    $saved = [Environment]::GetEnvironmentVariable('MYSQLPASSWORD', 'User')
    if ($null -ne $saved) { $env:MYSQLPASSWORD = $saved }
}
if ($null -eq $env:MYSQLPASSWORD) {
    Say ''
    Say '  Type the MySQL root password you chose when you installed MySQL.' 'Yellow'
    Say '  (Nothing shows while you type. That is normal. Press Enter when done.)' 'Yellow'
    $secure = Read-Host '  MySQL password' -AsSecureString
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
    $env:MYSQLPASSWORD = $plain
    if ($onWindows -and $plain -ne '') {
        [Environment]::SetEnvironmentVariable('MYSQLPASSWORD', $plain, 'User')
        Ok 'Password saved for next time'
    }
} else {
    Ok 'MySQL password is set'
}

# 4. Port 8080 is free
if (Test-Port 8080) {
    Say ''
    Say '  Something already runs on port 8080. Maybe the store is already open in another window.' 'Yellow'
    Say '  Opening http://localhost:8080/ ...' 'Yellow'
    Say '  If the page does not work: close the other black window (or press Ctrl+C in it) and try again.' 'Yellow'
    Start-Process 'http://localhost:8080/'
    exit 0
}

# 5. Start the app. Watch its log and explain the usual errors in plain words.
Say ''
Say '  Starting the server. The FIRST start downloads tools and takes a few minutes.' 'Cyan'
Say '  Keep this window open while you use the store. Press Ctrl+C to stop it.' 'Cyan'
Say ''

# Each pattern is a regular expression matched against one log line.
$hints = @(
    @{ Pattern = 'Access denied for user'; Name = 'Wrong MySQL password'; Fix = @('The saved password was cleared.', 'Run start.cmd again and type the right MySQL root password.') }
    @{ Pattern = 'Communications link failure'; Name = 'Cannot reach MySQL'; Fix = @('Start the MySQL service in the Windows "Services" app, then run start.cmd again.') }
    @{ Pattern = 'Public Key Retrieval is not allowed'; Name = 'MySQL login method'; Fix = @('Open "MySQL 8.4 Command Line Client" from the Start menu, type the password once,', 'close it, then run start.cmd again.') }
    @{ Pattern = 'Port 8080 was already in use'; Name = 'Port 8080 is busy'; Fix = @('Another program uses port 8080. Close the other black window and try again.') }
    @{ Pattern = 'Unknown column'; Name = 'Old database tables'; Fix = @('The tables are older than the code (a column is missing).', 'Double-click reset-db.cmd to rebuild them. This deletes local test data only.') }
    @{ Pattern = "Table '[^']+' doesn't exist"; Name = 'Missing table'; Fix = @('Double-click reset-db.cmd to rebuild the tables. This deletes local test data only.') }
    @{ Pattern = 'COMPILATION ERROR'; Name = 'Java code does not compile'; Fix = @('Copy the [ERROR] lines above and paste them to Codex.') }
)
$shownHint = $false
$opened = $false
$mvnw = if ($onWindows) { Join-Path $backend 'mvnw.cmd' } else { Join-Path $backend 'mvnw' }

Push-Location $backend
try {
    & $mvnw -B spring-boot:run 2>&1 | ForEach-Object {
        $line = "$_"
        Write-Host $line
        if (-not $opened -and $line -match 'Started GoodStoreApplication') {
            $opened = $true
            Say ''
            Say '  ==================================================' 'Green'
            Say '   The store is running:  http://localhost:8080/' 'Green'
            Say '   Test it: double-click check.cmd' 'Green'
            Say '  ==================================================' 'Green'
            Say ''
            Start-Process 'http://localhost:8080/'
        }
        if (-not $shownHint) {
            foreach ($hint in $hints) {
                if ($line -match $hint.Pattern) {
                    $shownHint = $true
                    if ($hint.Name -eq 'Wrong MySQL password' -and $onWindows) {
                        [Environment]::SetEnvironmentVariable('MYSQLPASSWORD', $null, 'User')
                    }
                    Say ''
                    Say '  ==================================================' 'Red'
                    Say "   PROBLEM FOUND: $($hint.Name)" 'Red'
                    foreach ($h in $hint.Fix) { Say "   $h" 'Yellow' }
                    Say '  ==================================================' 'Red'
                    Say ''
                    break
                }
            }
        }
    }
} finally { Pop-Location }
