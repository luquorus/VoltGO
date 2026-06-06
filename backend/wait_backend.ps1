Write-Host "Waiting for backend to be ready..." -ForegroundColor Yellow
$maxWait = 60
$elapsed = 0
while ($elapsed -lt $maxWait) {
    try {
        $r = Invoke-RestMethod -Uri "http://localhost:8080/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"="admin@local";"password"="Admin@123"} | ConvertTo-Json) -ErrorAction SilentlyContinue
        if ($r.token) {
            Write-Host "[OK] Backend ready after $elapsed seconds!" -ForegroundColor Green
            exit 0
        }
    } catch {}
    Start-Sleep -Seconds 3
    $elapsed += 3
}
Write-Host "[FAIL] Backend not ready after $maxWait seconds" -ForegroundColor Red
exit 1
