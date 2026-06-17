# T5: Pad i ponovno pokretanje servisa (rezultati)

Postupak: zaustavi se `ingestion-service`, objavljuje se dok je ugašen (2 uređaja
x 3 ciklusa/s tijekom 30 s = 360 poruka), zatim se pokreće i pušta da nadoknadi.
Pouzdanost počiva na redu na brokeru za trajnu sesiju (`cleanSession=false`).

| Metrika | Vrijednost |
|--------|-------|
| Objavljeno tijekom ispada | 360 |
| Spremljeno nakon pokretanja | 360 |
| Potpunost nadoknade (spremljeno == objavljeno) | da (360 / 360) |
| Jedinstveni msg_id | 360 |
| Redovi duplikata nakon nadoknade | 0 |
| Trajanje nadoknade (s) | 3.2 |
| Redovi po uređaju/senzoru | 90 svaki |
| Latencija avg / p50 / p95 / p99 (ms) | 53171 / 53196 / 65264 / 66183 |
| Upozorenja (WARNING / CRITICAL) | 23 / 12 |
