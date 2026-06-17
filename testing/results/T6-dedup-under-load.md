# T6: Deduplikacija pod opterećenjem (rezultati)

Konfiguracija: 20 virtualnih uređaja x 10 ciklusa/s tijekom 60 s, QoS 1; ukupno
ponuđeno opterećenje ~385 msg/s, 23566 objavljenih poruka, nakon potpune
nadoknade zaostatka.

| Metrika | Vrijednost |
|--------|-------|
| Objavljeno | 23566 |
| Jedinstveno spremljeno | 23566 |
| Gubitak % | 0.0 |
| Redovi duplikata (mora biti 0) | 0 |
| Latencija P50 / P99 (ms) | 48725 / 63031 |
| Održiva propusnost (msg/s) | 191.0 |
| Trajanje nadoknade (s) | 123.4 |
| Redis DBSIZE (oba servisa) | 47132 |
| Redis used_memory_human | 6.67M |

Ključevi po prefiksu: `dedup:ingestion:*` = 23566, `dedup:alerting:*` = 23566.
Upozorenja tijekom pokretanja: 554 CRITICAL, 1356 WARNING.
