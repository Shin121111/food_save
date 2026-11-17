# Tests the running store from end to end: owner, food item, booking, pickup.
# Start the store first (start.cmd), then run this (check.cmd).
# If a step fails, copy the whole output and paste it to Codex.
# Keep this file ASCII only: Windows PowerShell 5.1 misreads other characters.

$ErrorActionPreference = 'Stop'
$base = 'http://localhost:8080'
$json = 'application/json'
$stamp = Get-Date -Format 'yyyyMMddHHmmss'
$script:passed = 0
$script:failed = 0

function Step($name, [scriptblock]$action) {
    try {
        $detail = & $action
        $script:passed++
        Write-Host "  [PASS] $name" -ForegroundColor Green
        if ($detail) { Write-Host "         $detail" -ForegroundColor DarkGray }
        return $true
    } catch {
        $script:failed++
        Write-Host "  [FAIL] $name" -ForegroundColor Red
        Write-Host "         $($_.Exception.Message)" -ForegroundColor Yellow
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
            Write-Host "         Server said: $($_.ErrorDetails.Message)" -ForegroundColor Yellow
        }
        return $false
    }
}
function Send($method, $path, $session, $body) {
    $params = @{ Method = $method; Uri = "$base$path"; WebSession = $session; ContentType = $json }
    if ($null -ne $body) { $params.Body = ($body | ConvertTo-Json -Compress) }
    Invoke-RestMethod @params
}
function Assert($condition, $message) { if (-not $condition) { throw $message } }

Write-Host ''
Write-Host '  The Good Store - self-test' -ForegroundColor Cyan
Write-Host '  --------------------------' -ForegroundColor Cyan

$up = Step 'Server is running on http://localhost:8080' {
    $text = Invoke-RestMethod "$base/api/health"
    Assert ($text -match 'running') "Unexpected answer: $text"
}
if (-not $up) {
    Write-Host ''
    Write-Host '  The server is not running. Double-click start.cmd, wait for' -ForegroundColor Yellow
    Write-Host '  "The store is running", then run check.cmd again.' -ForegroundColor Yellow
    Write-Host ''
    exit 1
}

Step 'Customer page loads' {
    $page = Invoke-WebRequest "$base/user/index.html" -UseBasicParsing
    Assert ($page.StatusCode -eq 200) "Status $($page.StatusCode)"
} | Out-Null
Step 'Shop owner page loads' {
    $page = Invoke-WebRequest "$base/Shop%20owner%20log%20in%20screen/shop-owner-login.html" -UseBasicParsing
    Assert ($page.StatusCode -eq 200) "Status $($page.StatusCode)"
} | Out-Null

$owner = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$customer = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$email = "check-$stamp@example.com"
$password = 'check-password-123'

Step 'Register a new shop (writes to MySQL)' {
    $r = Send 'POST' '/api/register' $owner @{ shopName = "Self-test shop $stamp"; email = $email; password = $password }
    "shop: $($r.shopName)"
} | Out-Null
Step 'Shop owner can sign in' {
    $fresh = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $r = Send 'POST' '/api/login' $fresh @{ email = $email; password = $password }
    Assert ($r.shopName) 'No shop name in the answer'
} | Out-Null

# Smallest valid JPEG header; the server only checks the first two bytes.
$photo = 'data:image/jpeg;base64,' + [Convert]::ToBase64String([byte[]](0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10))
$deadline = (Get-Date).AddHours(3).ToString('yyyy-MM-ddTHH:mm')
$itemId = $null
Step 'Owner adds a food item' {
    $r = Send 'POST' '/api/owner/items' $owner @{ name = "Self-test bread $stamp"; quantity = 5; originalPrice = 900; salePrice = 600; deadline = $deadline; photo = $photo }
    Set-Variable -Name itemId -Value $r.id -Scope Script
    "item id: $($r.id)"
} | Out-Null
Step 'Customers can see the food item' {
    $items = @(Send 'GET' '/api/items' $customer $null)
    Assert (@($items | Where-Object { $_.id -eq $itemId }).Count -eq 1) "Item $itemId is not in /api/items"
} | Out-Null
Step 'Customer books 2 of the item' {
    $r = Send 'POST' '/api/bookings' $customer @{ itemId = $itemId; quantity = 2; customerName = 'Self Test'; customerEmail = 'customer@example.com'; customerPhone = '0912345678' }
    Assert ($r.totalPrice -eq 1200) "Total price is $($r.totalPrice), expected 1200"
    "booking id: $($r.id), total: $($r.totalPrice)"
} | Out-Null
Step 'Stock went down from 5 to 3' {
    $mine = @(Send 'GET' '/api/owner/items' $owner $null) | Where-Object { $_.id -eq $itemId }
    Assert ($mine.quantity -eq 3) "Quantity is $($mine.quantity), expected 3"
} | Out-Null
Step 'Customer sees the booking in My bookings' {
    $list = @(Send 'GET' '/api/my-bookings' $customer $null)
    Assert ($list.Count -ge 1) 'My bookings is empty'
} | Out-Null
$bookingId = $null
Step 'Owner sees the booking' {
    $list = @(Send 'GET' '/api/owner/bookings' $owner $null)
    Assert ($list.Count -ge 1) 'Owner booking list is empty'
    Set-Variable -Name bookingId -Value $list[0].id -Scope Script
} | Out-Null
Step 'Owner marks the booking as picked up' {
    Send 'POST' "/api/owner/bookings/$bookingId/pickup" $owner $null | Out-Null
    $status = (@(Send 'GET' '/api/owner/bookings' $owner $null) | Where-Object { $_.id -eq $bookingId }).status
    Assert ($status -eq 'PICKED_UP') "Status is $status, expected PICKED_UP"
} | Out-Null
Step 'Owner deletes the test item (cleanup)' {
    Send 'DELETE' "/api/owner/items/$itemId" $owner $null | Out-Null
} | Out-Null

Write-Host ''
if ($script:failed -eq 0) {
    Write-Host "  ALL $($script:passed) CHECKS PASSED. Database, Java and pages work together." -ForegroundColor Green
} else {
    Write-Host "  $($script:failed) CHECK(S) FAILED, $($script:passed) passed." -ForegroundColor Red
    Write-Host '  Copy everything in this window and paste it to Codex.' -ForegroundColor Yellow
    Write-Host '  Also copy the end of backend\logs\server.log (the server log).' -ForegroundColor Yellow
}
Write-Host ''
if ($script:failed -gt 0) { exit 1 }
