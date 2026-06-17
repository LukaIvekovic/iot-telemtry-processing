Write-Host "Aktivni dedup ključevi (DBSIZE):"
docker compose exec -T redis redis-cli DBSIZE

Write-Host "`nKljučevi po servisu:"
docker compose exec -T redis redis-cli --scan --pattern "dedup:ingestion:*" | Measure-Object | Select-Object -ExpandProperty Count | ForEach-Object { Write-Host "  dedup:ingestion:* = $_" }
docker compose exec -T redis redis-cli --scan --pattern "dedup:alerting:*"  | Measure-Object | Select-Object -ExpandProperty Count | ForEach-Object { Write-Host "  dedup:alerting:*  = $_" }

Write-Host "`nMemorija:"
docker compose exec -T redis redis-cli INFO memory | Select-String "used_memory_human|used_memory_peak_human"
