$r = Invoke-RestMethod -Uri "http://localhost:8080/auth/register" -Method POST -ContentType "application/json" -Body (@{email="admin2@local";password="Admin@123";role="ADMIN"} | ConvertTo-Json) -ErrorAction SilentlyContinue
if ($r) {
    Write-Host "Registered: $($r | ConvertTo-Json)"
} else {
    Write-Host "Register failed or already exists"
}
