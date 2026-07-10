# Pine indicator v1.3 checklist

- [ ] Pine v6 kompiluje bez chyby a Add to chart přidá v1.3 na XAUUSD M5.
- [ ] Non-M5, non-XAUUSD, neplatné HTF pořadí, EMA délky a lot config se zablokují.
- [ ] Production vyžaduje H1+H4; Balanced propustí jen nekonfliktní jednostranný bias.
- [ ] Structure debug posílá nulové lifecycle alerty; Clean skrývá debug prvky.
- [ ] Pivot → sweep → CHoCH → FVG → touch → management je vždy v pořadí.
- [ ] Dual sweep je blokován a nejvýše jeden lifecycle alert vznikne na close baru.
- [ ] Expiry N=1/N=12, session close, news blackout a nový NY den mají správný reset/CANCEL.
- [ ] Stage 4 přežije session/news/nový den; entry bar negeneruje fiktivní exit.
- [ ] Ambiguous entry a SL+TP jsou terminální; BE vyžaduje close a MOVE_BE je jednorázové.
- [ ] Lot cap je před round-down, min/max/step platí a risk nepřekročí budget.
- [ ] Invalidní risk smaže stav i FVG box; alerty sdílí `planId` a `EKV|v1.3`.
- [ ] Reload/replay dává stejný lifecycle; evidence patří do ignorovaného `reports/`.
