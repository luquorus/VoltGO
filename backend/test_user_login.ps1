$ErrorActionPreference = "Continue"
$baseUrl = "http://localhost:8080"

$testPasswords = @("VoltGo123456", "Test123456", "Password123", "Luquorus@123", "luquorus123")

foreach ($pw in $testPasswords) {
    Write-Host "Trying password: $pw" -ForegroundColor Yellow
    try {
        $body = @{"email"="luquorus.author@gmail.com";"password"=$pw} | ConvertTo-Json
        $login = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body $body -ErrorAction SilentlyContinue
        if ($login.token) {
            Write-Host "SUCCESS! Password: $pw" -ForegroundColor Green
            Write-Host "Token: $($login.token.Substring(0, 40))..."
            break
        }
    } catch {
        $status = [int]$_.Exception.Response.StatusCode
        Write-Host "  -> $status" -ForegroundColor Gray
    }
}
