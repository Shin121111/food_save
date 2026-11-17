# Reads and writes the MySQL password in backend\local.properties.
# A .properties value treats backslash as an escape and drops leading spaces, and Spring may
# read the file as ISO-8859-1. So the file stays ASCII: backslash is written as \\, every
# non-ASCII character as \uXXXX, and a leading space as "\ ".
# Keep this file ASCII only: Windows PowerShell 5.1 misreads other characters.

function ConvertTo-PropertiesValue([string]$value) {
    $escaped = -join ($value.ToCharArray() | ForEach-Object {
        if ($_ -eq [char]'\') { '\\' } elseif ([int]$_ -gt 126) { '\u{0:x4}' -f [int]$_ } else { [string]$_ }
    })
    if ($escaped.StartsWith(' ')) { $escaped = '\' + $escaped }
    return $escaped
}

function ConvertFrom-PropertiesValue([string]$raw) {
    return [regex]::Replace($raw, '\\u([0-9a-fA-F]{4})|\\(.)', {
        param($m)
        if ($m.Groups[1].Success) { [string][char][Convert]::ToInt32($m.Groups[1].Value, 16) } else { $m.Groups[2].Value }
    })
}

function Save-Password([string]$path, [string]$password) {
    $content = "# Local MySQL password for this computer only. Git ignores this file.`r`n" +
        "spring.datasource.password=$(ConvertTo-PropertiesValue $password)`r`n"
    [IO.File]::WriteAllText($path, $content, (New-Object Text.UTF8Encoding($false)))
}

function Read-SavedPassword([string]$path) {
    if (-not (Test-Path $path)) { return $null }
    $line = Get-Content $path | Where-Object { $_ -match '^spring\.datasource\.password=' } | Select-Object -First 1
    if (-not $line) { return $null }
    return (ConvertFrom-PropertiesValue $line.Substring($line.IndexOf('=') + 1))
}
