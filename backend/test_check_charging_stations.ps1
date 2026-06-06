$baseUrl = "http://localhost:8080"
$adminLogin = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method POST -ContentType "application/json" -Body (@{"email"="admin2@local";"password"="Admin@456"} | ConvertTo-Json)
$adminHeaders = @{"Authorization"="Bearer $($adminLogin.token)"}
$stations = Invoke-RestMethod -Uri "$baseUrl/api/admin/stations?page=0&size=3" -Method GET -Headers $adminHeaders
$stations.content | ConvertTo-Json -Depth 5
