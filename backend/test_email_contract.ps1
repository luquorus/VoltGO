$ErrorActionPreference = "Continue"
$baseUrl = "http://localhost:8080"

# Admin login and get token
$login = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"="admin@local";"password"="Admin@123"} | ConvertTo-Json)
$token = $login.token
$headers = @{"Authorization"="Bearer $token"}
Write-Host "Admin login OK" -ForegroundColor Green

# Get contracts for luquorus.author@gmail.com (collaborator ID from earlier run)
$collabId = "1d1f510d-ac32-43fa-9359-a66dffeae622"
Write-Host "Getting contracts for collaborator $collabId..."
try {
    $contracts = Invoke-RestMethod -Uri "$baseUrl/api/admin/contracts?collaboratorId=$collabId" -Method GET -Headers $headers
    Write-Host "Contracts found: $($contracts.Count)"
    $contracts | ForEach-Object {
        Write-Host "  Contract: $($_.id) | Status: $($_.status)"
    }

    if ($contracts.Count -gt 0) {
        $contractId = $contracts[0].id

        Write-Host ""
        Write-Host "=== Test: CONTRACT_UPDATED notification + email ===" -ForegroundColor Cyan
        $updateBody = @{
            note = "Updated by test script at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        } | ConvertTo-Json
        $update = Invoke-RestMethod -Uri "$baseUrl/api/admin/contracts/$contractId" -Method PUT -Headers $headers -ContentType "application/json" -Body $updateBody
        Write-Host "Updated contract: $($update.id) | Note: $($update.note)" -ForegroundColor Green
        Write-Host "-> Email should be sent to luquorus.author@gmail.com" -ForegroundColor Yellow
        Write-Host "-> Subject: Contract Updated" -ForegroundColor Yellow

        Start-Sleep -Seconds 3

        Write-Host ""
        Write-Host "=== Test: CONTRACT_TERMINATED notification + email ===" -ForegroundColor Cyan
        # But first re-create a contract so we don't break things
        $createBody = @{
            collaboratorId = $collabId
            region = "Test Region"
            startDate = "2026-06-06"
            endDate = "2027-06-06"
            note = "Test contract for email"
        } | ConvertTo-Json
        $newContract = Invoke-RestMethod -Uri "$baseUrl/api/admin/contracts" -Method POST -Headers $headers -ContentType "application/json" -Body $createBody
        Write-Host "Created new contract: $($newContract.id)" -ForegroundColor Green

        $termBody = @{ reason = "Test termination" } | ConvertTo-Json
        $term = Invoke-RestMethod -Uri "$baseUrl/api/admin/contracts/$($newContract.id)/terminate" -Method POST -Headers $headers -ContentType "application/json" -Body $termBody
        Write-Host "Terminated contract: $($term.id) | Status: $($term.status)" -ForegroundColor Green
        Write-Host "-> Email should be sent to luquorus.author@gmail.com" -ForegroundColor Yellow
        Write-Host "-> Subject: Contract Terminated" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Verify notifications for luquorus.author@gmail.com ===" -ForegroundColor Cyan
try {
    $login2 = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"="luquorus.author@gmail.com";"password"="VoltGoTest123"} | ConvertTo-Json)
    $token2 = $login2.token
    $headers2 = @{"Authorization"="Bearer $token2"}
    $notifs = Invoke-RestMethod -Uri "$baseUrl/api/collab/notifications?page=0&size=20" -Method GET -Headers $headers2
    Write-Host "Total: $($notifs.totalElements), Unread: $($notifs.unreadCount)"
    $notifs.notifications | ForEach-Object {
        Write-Host "  [$($_.type)] $($_.title) - $($_.body)"
    }
} catch {
    Write-Host "Could not get notifications: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green
