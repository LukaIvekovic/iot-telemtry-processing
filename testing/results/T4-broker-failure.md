# T4: Ispad brokera / izlazni spremnik uređaja (rezultati)

> **TODO (simulirane brojke):** vrijednosti ispod su uvjerljivi rezervirani
> podaci da se 7. poglavlje može pisati. **Ponoviti T4 na fizičkom ESP32 i
> zamijeniti stvarnim mjerenjima sa serijskog monitora.**

Postupak: fizički ESP32 objavljuje (sklopka uključena); Mosquitto se gasi usred
toka i pokreće nakon ispada. Uređaj šalje 2 očitanja svakih 5 s (~0,4 msg/s);
`OUTBOX_CAPACITY = 256`.

| Varijanta | Ispad (s) | Vršna dubina spremnika | `[Outbox] FULL`? | Očitanja u prozoru | Spremljeno | Gubitak % |
|---------|-----------|-------------------|-----------------------|--------------------|--------|--------|
| Ispod kapaciteta | 300 | 120 | ne  | 120 | 120 | 0.0  |
| Iznad kapaciteta | 900 | 256 | da  | 360 | 256 | 28.9 |
