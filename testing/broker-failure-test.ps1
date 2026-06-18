param(
    [string]$Port          = "COM3",
    [int]$Baud             = 115200,
    [int]$OutageSeconds    = 300,
    [string]$Label         = "ispod-kapaciteta",
    [string]$DeviceId      = "esp32-001",
    [int]$OnlineTimeout    = 60,
    [int]$DrainTimeout     = 120
)

$state = [ordered]@{
    Online        = $false
    Sent          = 0
    Queued        = 0
    Full          = 0
    Replayed      = 0
    PeakDepth     = 0
    LastRemaining = -1
}

function Get-UniqueCount {
    return [int]((docker compose exec -T postgres psql -U postgres -d iot_telemetry -t -A `
        -c "SELECT COUNT(DISTINCT msg_id) FROM telemetry_readings WHERE device_id='$DeviceId';").Trim())
}

function Parse-Line {
    param([string]$line, [string]$phase)

    if ($line -match 'QoS \d+, sent')      { $state.Sent++; $state.Online = $true }
    if ($line -match '\[MQTT\].*connected!') { $state.Online = $true }

    if ($line -match '\(depth=(\d+)\)') {
        $d = [int]$Matches[1]
        if ($d -gt $state.PeakDepth) { $state.PeakDepth = $d }
        if ($phase -eq 'outage') { $state.Queued++ }
    }
    if ($line -match '\[Outbox\] FULL' -and $phase -eq 'outage') { $state.Full++ }
    if ($line -match 'Replayed.*remaining=(\d+)') {
        $state.Replayed++
        $state.LastRemaining = [int]$Matches[1]
    }
}

function Pump {
    param([object]$port, [string]$phase, [datetime]$deadline, [scriptblock]$stopWhen, [string]$log)

    while ((Get-Date) -lt $deadline) {
        if ($stopWhen -and (& $stopWhen)) { return }
        try { $line = $port.ReadLine() }
        catch [TimeoutException] { continue }
        catch { return }

        $line = $line.Trim()
        if (-not $line) { continue }

        Write-Host "  | $line" -ForegroundColor DarkGray
        if ($log) { Add-Content -Path $log -Value $line -Encoding UTF8 }
        Parse-Line $line $phase
    }
}

$log = "testing/results/T4-$Label.log"
Remove-Item $log -ErrorAction SilentlyContinue

Write-Host "########## T4: ispad brokera ($Label) ##########" -ForegroundColor Magenta
Write-Host "Port=$Port  Baud=$Baud  Ispad=${OutageSeconds}s  Uređaj=$DeviceId" -ForegroundColor Cyan

$sp = New-Object System.IO.Ports.SerialPort($Port, $Baud)
$sp.ReadTimeout = 1000
$sp.NewLine = "`n"

try {
    $sp.Open()
}
catch {
    Write-Host "GREŠKA: ne mogu otvoriti $Port. Zatvori PlatformIO Serial Monitor i provjeri da je uređaj spojen." -ForegroundColor Red
    return
}

try {
    Write-Host "`nČekam da uređaj bude online (do ${OnlineTimeout}s)..." -ForegroundColor Yellow
    Pump $sp 'warmup' ((Get-Date).AddSeconds($OnlineTimeout)) { $state.Online } $log
    if (-not $state.Online) {
        Write-Host "UPOZORENJE: nisam vidio potvrdu da uređaj objavljuje. Je li sklopka uključena?" -ForegroundColor Yellow
    }

    Write-Host "`nZaustavljam broker (mosquitto)..." -ForegroundColor Yellow
    docker compose stop mosquitto | Out-Null

    Write-Host "Čistim bazu i Redis prije prozora ispada..."
    ./testing/reset.ps1 | Out-Null

    $state.Queued = 0; $state.Full = 0; $state.PeakDepth = 0
    $state.Replayed = 0; $state.LastRemaining = -1

    Write-Host "`nProzor ispada: ${OutageSeconds}s (uređaj puni izlazni spremnik)..." -ForegroundColor Cyan
    Pump $sp 'outage' ((Get-Date).AddSeconds($OutageSeconds)) $null $log

    Write-Host "`nPokrećem broker (mosquitto)..." -ForegroundColor Green
    docker compose start mosquitto | Out-Null

    Write-Host "Čekam pražnjenje spremnika (do ${DrainTimeout}s)..." -ForegroundColor Cyan
    Pump $sp 'drain' ((Get-Date).AddSeconds($DrainTimeout)) `
        { $state.LastRemaining -eq 0 -and $state.Replayed -gt 0 } $log
}
finally {
    $sp.Close()
}

Start-Sleep -Seconds 5
$stored = Get-UniqueCount

$attempted = $state.Queued
$dropped   = $state.Full
$full      = if ($dropped -gt 0) { "da" } else { "ne" }
$loss      = if ($attempted -gt 0) {
    [math]::Round((($attempted - $state.Replayed) / $attempted) * 100, 1)
} else { 0 }

Write-Host "`n========== REZULTAT T4 ($Label) ==========" -ForegroundColor Cyan
Write-Host ("  Vršna dubina spremnika : {0}" -f $state.PeakDepth)
Write-Host ("  [Outbox] FULL?         : {0} ({1} odbačenih)" -f $full, $dropped)
Write-Host ("  Očitanja u prozoru     : {0}" -f $attempted)
Write-Host ("  Ponovno poslano        : {0}" -f $state.Replayed)
Write-Host ("  Jedinstveno u bazi     : {0} (unakrsna provjera)" -f $stored)
Write-Host ("  Gubitak %              : {0}" -f $loss)

Write-Host "`nRedak za tablicu (testing/results/T4-broker-failure.md):" -ForegroundColor Yellow
Write-Host ("| {0} | {1} | {2} | {3} | {4} | {5} | {6} |" -f `
    $Label, $OutageSeconds, $state.PeakDepth, $full, $attempted, $state.Replayed, $loss)

Write-Host "`nSerijski zapis spremljen u: $log" -ForegroundColor DarkGray
