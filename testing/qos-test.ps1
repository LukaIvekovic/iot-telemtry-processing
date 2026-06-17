param(
    [int]$Devices      = 5,
    [int]$Duration     = 10,
    [int]$Rate         = 10,
    [int]$BootWait     = 10,
    [int]$DrainTimeout = 120
)

function Get-StoredCount {
    return [int]((docker compose exec -T postgres psql -U postgres -d iot_telemetry -t -A `
        -c "SELECT COUNT(*) FROM telemetry_readings;").Trim())
}

function Wait-Drain {
    param([int]$TimeoutSec, [int]$Target)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    $last = -1
    $stable = 0
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 3
        $n = Get-StoredCount
        if ($Target -gt 0 -and $n -ge $Target) {
            Write-Host "    ...dosegnut cilj: $n / $Target"
            return $n
        }
        if ($n -eq $last) {
            $stable++
            if ($stable -ge 8) {
                Write-Host "    ...prazno: $n stabilno (cilj=$Target)"
                return $n
            }
        } else {
            $stable = 0
            Write-Host "    ...nadoknada: $n / $Target"
        }
        $last = $n
    }
    Write-Host "    (istek nakon ${TimeoutSec}s, $last / $Target)" -ForegroundColor Yellow
    return $last
}

Write-Host "########## QoS test gubitka ##########" -ForegroundColor Magenta
foreach ($q in 0, 1, 2) {
    Write-Host "`n========== QoS $q ==========" -ForegroundColor Cyan
    ./testing/reset.ps1

    Write-Host "Pokrećem ingestion-service..."
    docker compose start ingestion-service | Out-Null
    Start-Sleep -Seconds $BootWait

    Write-Host "Zaustavljam ingestion-service..." -ForegroundColor Yellow
    docker compose stop ingestion-service | Out-Null

    Write-Host "Objavljujem: $Devices uređaja, ${Duration}s, QoS $q"
    $outFile = [System.IO.Path]::GetTempFileName()
    $proc = Start-Process -FilePath "python" `
        -ArgumentList "testing/load-generator.py", "--devices", "$Devices", `
                      "--duration", "$Duration", "--rate", "$Rate", "--qos", "$q" `
        -RedirectStandardOutput $outFile -NoNewWindow -PassThru
    $proc.WaitForExit()
    $published = [int]((Select-String -Path $outFile -Pattern 'Objavljeno:\s+(\d+)').Matches[0].Groups[1].Value)
    Remove-Item $outFile -ErrorAction SilentlyContinue

    Write-Host "Ponovno pokrećem ingestion-service..." -ForegroundColor Green
    docker compose start ingestion-service | Out-Null
    Start-Sleep -Seconds $BootWait
    Wait-Drain -TimeoutSec $DrainTimeout -Target $published | Out-Null

    $unique = [int]((docker compose exec -T postgres psql -U postgres -d iot_telemetry -t -A `
        -c "SELECT COUNT(DISTINCT msg_id) FROM telemetry_readings;").Trim())
    $loss = if ($published -gt 0) { [math]::Round((($published - $unique) / $published) * 100, 2) } else { 0 }

    Write-Host "`n  REZULTAT QoS $q : objavljeno=$published  jedinstveno=$unique  GUBITAK=$loss%" -ForegroundColor Cyan
    Write-Host "`n  Mjerenje:"
    Get-Content testing/measure.sql -Encoding UTF8 | docker compose exec -T postgres psql -U postgres -d iot_telemetry
}

Write-Host "`nGotovo. QoS 0 ~100% gubitka; QoS 1/2 ~0% gubitka uz nadoknadu pri ponovnoj isporuci." -ForegroundColor Cyan
