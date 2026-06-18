# Testni okvir: upute za pokretanje

Naredbe za scenarije performansi i pouzdanosti T1 do T6. Sve se pokreće iz
**korijena projekta** u **PowerShell-u**.

## Preduvjeti

```powershell
pip install paho-mqtt
docker compose up --build -d
docker compose ps
```

## Pomoćne skripte

| Skripta | Namjena |
|---|---|
| `load-generator.py` | Objava s N virtualnih uređaja uz zadanu brzinu i QoS |
| `reset.ps1` | TRUNCATE obje tablice i Redis `FLUSHDB` (između scenarija) |
| `duplicate-test.ps1` | Provjera obrade duplikata (T3) |
| `redis-stats.ps1` | Zauzeće Redis skupa viđenih ključeva (broj ključeva i memorija) |
| `measure.sql` | Percentili latencije, propusnost, osnovica gubitka, trajanje nadoknade |

Mjerenja se pokreću s:

```powershell
Get-Content testing/measure.sql | docker compose exec -T postgres psql -U postgres -d iot_telemetry
```

`Gubitak % = (objavljeno − jedinstveno_spremljeno) / objavljeno × 100.`

## T1: Stalno opterećenje

Osnovica performansi pri stabilnom opterećenju.

```powershell
./testing/reset.ps1
python testing/load-generator.py --devices 5 --rate 2 --duration 120 --qos 1
Get-Content testing/measure.sql | docker compose exec -T postgres psql -U postgres -d iot_telemetry
```

## T2: QoS 0 naspram QoS 1/2

Gubitak po razini QoS-a dok je potrošač ugašen tijekom objave.

```powershell
./testing/qos-test.ps1
```

## T3: Obrada duplikata

Ista poruka objavljena više puta; očekuje se 1 spremljeni red.

```powershell
./testing/reset.ps1
./testing/duplicate-test.ps1
```

## T4: Ispad brokera

Put izlaznog spremnika (engl. *outbox*) na fizičkom ESP32 uređaju tijekom ispada
brokera. Skripta sama otvara serijski port, gasi i pokreće broker po isteku
zadanog prozora, parsira serijski tok (vršna dubina, `[Outbox] FULL`, ponovna
isporuka) i ispisuje redak za tablicu rezultata. Sklopka na uređaju mora biti
uključena, a PlatformIO Serial Monitor zatvoren (port zauzima samo jedan program).

Varijanta ispod kapaciteta (~5 min, bez gubitka):

```powershell
./testing/broker-failure-test.ps1 -Port COM3 -OutageSeconds 300 -Label ispod-kapaciteta
```

Varijanta iznad kapaciteta (~15 min, spremnik se prepuni, očekuje se gubitak):

```powershell
./testing/broker-failure-test.ps1 -Port COM3 -OutageSeconds 900 -Label iznad-kapaciteta
```

## T5: Pad i ponovno pokretanje servisa

Objava dok je ingestion ugašen, zatim provjera nadoknade iz reda na brokeru.

```powershell
./testing/reset.ps1
docker compose stop ingestion-service
python testing/load-generator.py --devices 2 --rate 3 --duration 30 --qos 1
docker compose start ingestion-service
Start-Sleep -Seconds 20
Get-Content testing/measure.sql | docker compose exec -T postgres psql -U postgres -d iot_telemetry
```

## T6: Deduplikacija pod opterećenjem

Preopterećenje koje broker stavlja u red; nakon nadoknade mjeri se gubitak,
duplikati i zauzeće Redisa. Pauza od ~90 s čeka da se zaostatak isprazni.

```powershell
./testing/reset.ps1
python testing/load-generator.py --devices 20 --rate 10 --duration 60 --qos 1
Start-Sleep -Seconds 90
Get-Content testing/measure.sql | docker compose exec -T postgres psql -U postgres -d iot_telemetry
./testing/redis-stats.ps1
```
