# T2: Usporedba QoS razina (rezultati)

Za svaku razinu QoS 0/1/2 potrošač se gasi tijekom objave (~10 s, 5 uređaja), pa
se mjeri što preživi. `ingestion-service` pretplaćuje se na QoS 1, pa broker
snižava QoS 2 na QoS 1 i oni se prikazuju zajedno kao QoS 1/2.

| QoS | Objavljeno | Jedinstveno spremljeno | Gubitak % | Duplikati |
|-----|-----------|---------------|--------|------------|
| 0     | 1000 | 0    | 100.00 | 0 |
| 1/2   | 1000 | 1000 | 0.00   | 0 |
