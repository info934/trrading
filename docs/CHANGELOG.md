# Changelog

## 2026-07-15 - MT5 EA v1.30 overall profile

- Replaced the regime-dependent Asia+NY unfiltered default with NY-only entries
  aligned to the confirmed H1 EMA trend.
- Reduced default risk from 2% to 1% while retaining the fixed 1:2 target and
  two-trades-per-day cap.
- Added true peak-to-trough equity drawdown tracking to tester diagnostics.
- Screened six session/bias combinations and selected H1-only over balanced for
  materially lower drawdown.
- Reproduced positive results separately in 2024, 2025 and real-tick 2026 data;
  the combined run returned USD 18,988.13 with USD 4,930.83 peak drawdown.

## 2026-07-10 - MT5 EA v1.20 challenge profile

- Changed the target to 1:2 and added an Asia + New York multi-session model.
- Added the USD 100k challenge guardrails: USD 5k profit target, USD 5k maximum
  daily loss, USD 10k maximum loss and at least two trade days.
- Added a 14-day target classification without forcing the EA to stop after day
  14; the journal reports `PASS_14D`, `PASS_LATE` or `FAIL`.
- Added persistent chart drawings for sweep, CHoCH, FVG, Entry/SL/TP, fills and
  exits, plus challenge drawdown and weekly diagnostics.
- Validated four consecutive 14-day real-tick windows: three passed within the
  target duration and one remained profitable but missed the USD 5k target.
- Extended validation across separate 2024, 2025 and 2026 periods invalidated
  the profile: every period breached the USD 10k maximum-loss boundary. The EA
  is therefore not approved for automated challenge deployment.

## 2026-07-10 - MT5 EA v1.10

- Replaced the unfiltered session CHoCH entry with the intended sequential
  liquidity sweep, later CHoCH, later FVG and later limit-fill lifecycle.
- Added confirmed H1/H4 EMA direction filtering; strict H1+H4 alignment is the
  default after outperforming the balanced profile in the reference regression.
- Moved structural invalidation behind the sweep extreme, changed the default
  target to 3R and break-even trigger to a confirmed 1.5R M5 close.
- Added deal-transaction accounting so an intrabar round trip cannot be missed.
- Verified compilation with zero errors and zero warnings and tested on FTMO
  real ticks; the reference balance improved from USD 97,878.65 to USD 100,525.11.

Všechny významné změny projektu budou dokumentovány v tomto souboru.

## Unreleased

### Added

- Added an MT5 Expert Advisor for the NY CHoCH/FVG model with broker-aware
  `OrderCalcProfit` risk sizing, limit orders, structural break-even, spread
  protection, daily loss cap and real-tick backtest instructions.
- Strategy backtest now follows the supplied NY-open model: first confirmed
  CHoCH, FVG midpoint inside the 50%-61.8% retracement zone, limit entry,
  FVG-candle stop, 4R target, structural-close break-even, and configurable
  dynamic/fixed lot scaling.
- Structure tracking now distinguishes continuation BOS from bias-flipping
  CHoCH, consumes each confirmed swing once, and requires a directional
  displacement candle for FVG qualification.
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
