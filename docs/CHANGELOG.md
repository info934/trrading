# Changelog

Všechny významné změny projektu budou dokumentovány v tomto souboru.

## Unreleased

### Added

- Strategy backtest now follows the supplied NY-open model: first confirmed
  CHoCH, FVG midpoint inside the 50%-61.8% retracement zone, limit entry,
  FVG-candle stop, 4R target, structural-close break-even, and configurable
  dynamic/fixed lot scaling.
- Základní struktura repozitáře.
- Ochrana proti commitnutí dat, logů, reportů, cache a tajných údajů.
- Lokální pre-commit limit 25 MiB na jednotlivý soubor.
- Kontrola velikosti pracovního prostoru.
- Obsahově nezměněná auditovaná kopie Pine zdroje v1.0.
- Statický audit v1.0 se závažnostmi, dopady a ověřovacími scénáři.
- Konkretizovaný Pine test checklist a seznam rozhodnutí před v1.1.
- Pine indikátor v1.1 bez Strategy Testeru a placeného Bar Magnifieru.
- Indikátor v1.2 s výchozím profilem Balanced, volitelným Strict/Structure-only
  režimem a vždy viditelnou diagnostickou EMA.
- Indikátor v1.3 s výchozím Production profilem (H1+H4), Balanced experimental
  bez protisměrného konfliktu a Structure debug profilem bez trade alertů.
- v1.3 vynucuje pozdější CHoCH/FVG/touch, potvrzený close pro BE, deterministické
  session/news/expiry rušení, stabilní planId a alert prefix `EKV|v1.3`.
- v1.3 přidává risk/lot ochrany, cap před round-down, dual-sweep rejection,
  reset invalidního plánu a Clean/Debug dashboard.
- Tuning v1.3 zpřesňuje zmrazený HTF label, blokuje vznik setupu v poslední
  session svíčce, ruší target-before-entry a validuje rozsah stop parametrů.
