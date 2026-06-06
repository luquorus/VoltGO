# Try login as admin2
$r = Invoke-RestMethod -Uri "http://localhost:8080/auth/login" -Method POST -ContentType "application/json" -Body (@{email="admin2@local";password="Admin@123"} | ConvertTo-Json) -ErrorAction SilentlyContinue
if ($r.token) {
    Write-Host "Login OK! Token: $($r.token.Substring(0, 40))..."
    Write-Host "UserId: $($r.userId)"
} else {
    Write-Host "Login failed: $($r | ConvertTo-Json)"
}
