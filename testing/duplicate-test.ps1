$msg = '{\"msg_id\":\"dup-test-001\",\"device_id\":\"test\",\"sensor\":\"temperature\",\"value\":25.0,\"unit\":\"C\",\"timestamp\":1745658245000}'

Write-Host "Objavljujem dup-test-001 pet puta (QoS 1)..."
for ($i = 1; $i -le 5; $i++) {
    docker compose exec -T mosquitto mosquitto_pub -t "telemetry/test/temperature" -m $msg -q 1
    Start-Sleep -Milliseconds 300
}

Start-Sleep -Seconds 2

Write-Host "`nSpremljeni redovi (očekivano 1):"
docker compose exec -T postgres psql -U postgres -d iot_telemetry `
    -c "SELECT COUNT(*) AS stored FROM telemetry_readings WHERE msg_id = 'dup-test-001';"

Write-Host "`nZapisi za duplikat (očekivano 4 odbacivanja):"
docker compose logs ingestion-service | Select-String "dup-test-001"
