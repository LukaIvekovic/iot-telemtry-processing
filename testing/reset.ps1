Write-Host "Brišem telemetry_readings i alert_events..."
docker compose exec -T postgres psql -U postgres -d iot_telemetry `
    -c "TRUNCATE telemetry_readings; TRUNCATE alert_events;"

Write-Host "Praznim Redis ključeve..."
docker compose exec -T redis redis-cli FLUSHDB

Write-Host "Gotovo."
