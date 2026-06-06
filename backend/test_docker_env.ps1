$envs = docker inspect voltgo-backend --format '{{range .Config.Env}}{{.}} {{end}}' 2>&1
$envs -split ' ' | Where-Object { $_ -like '*SPRING*' -or $_ -like '*MINIO*' -or $_ -like '*PROFILE*' }
