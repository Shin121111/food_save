# Deletes the local good_store database. The next start.cmd creates it again with
# the newest tables from backend/src/main/resources/schema.sql.
# Use it when you see "Unknown column" or "Table ... doesn't exist".
# Local test data only: this never touches Railway.
# Keep this file ASCII only: Windows PowerShell 5.1 misreads other characters.

$ErrorActionPreference = 'Continue'
$onWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or $IsWindows
$database = if ($env:MYSQLDATABASE) { $env:MYSQLDATABASE } else { 'good_store' }

Write-Host ''
Write-Host '  The Good Store - reset local database' -ForegroundColor Cyan
Write-Host '  -------------------------------------' -ForegroundColor Cyan

$mysql = (Get-Command mysql -ErrorAction SilentlyContinue).Source
if (-not $mysql -and $onWindows) {
    $mysql = Get-ChildItem "$env:ProgramFiles\MySQL\MySQL Server *\bin\mysql.exe" -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $mysql) {
    Write-Host '  [STOP] Cannot find mysql.exe.' -ForegroundColor Red
    Write-Host '  Open "MySQL 8.4 Command Line Client" from the Start menu, type the password, then type:' -ForegroundColor Yellow
    Write-Host "    DROP DATABASE $database;" -ForegroundColor Yellow
    exit 1
}

if ($null -eq $env:MYSQLPASSWORD -and $onWindows) {
    $saved = [Environment]::GetEnvironmentVariable('MYSQLPASSWORD', 'User')
    if ($null -ne $saved) { $env:MYSQLPASSWORD = $saved }
}

Write-Host ''
Write-Host "  This deletes ALL local shops, food items and bookings in '$database'." -ForegroundColor Yellow
Write-Host '  Stop the store first (press Ctrl+C in the start.cmd window).' -ForegroundColor Yellow
$answer = Read-Host '  Type YES to continue'
if ($answer -cne 'YES') { Write-Host '  Nothing was deleted.'; exit 0 }

$env:MYSQL_PWD = $env:MYSQLPASSWORD
$output = & $mysql -u root -h 127.0.0.1 -e "DROP DATABASE IF EXISTS $database;" 2>&1 | ForEach-Object { "$_" }
$code = $LASTEXITCODE
Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
if ($code -ne 0) {
    Write-Host "  [FAIL] $($output -join ' ')" -ForegroundColor Red
    if (($output -join ' ') -match 'Access denied') { Write-Host '  The MySQL password is wrong. Run start.cmd: it asks for the password again.' -ForegroundColor Yellow }
    exit 1
}
Write-Host "  [OK]   '$database' was deleted. Double-click start.cmd: it creates fresh tables." -ForegroundColor Green
Write-Host ''
