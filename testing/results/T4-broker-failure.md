# T4: Ispad brokera / izlazni spremnik uređaja (rezultati)

Postupak: fizički ESP32 objavljuje (sklopka uključena); Mosquitto se gasi usred
toka i pokreće nakon ispada. Uređaj šalje 2 očitanja svakih 5 s (~0,4 msg/s);
`OUTBOX_CAPACITY = 256`.

| Varijanta | Ispad (s) | Vršna dubina spremnika | `[Outbox] FULL`? | Očitanja u prozoru | Spremljeno | Gubitak % |
|---------|-----------|-------------------|-----------------------|--------------------|------------|-----------|
| Ispod kapaciteta | 300 | 118 | ne  | 118                | 118        | 0.0       |
| Iznad kapaciteta | 900 | 256 | da  | 356                | 256        | 28.1      |
