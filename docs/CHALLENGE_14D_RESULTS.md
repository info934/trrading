# Výsledky 14denního challenge testu

## Použité nastavení

- FTMO-Demo XAUUSD, M5
- Every tick based on real ticks
- počáteční účet: 100 000 USD, páka 1:100
- risk: 2 % equity na obchod
- maximálně 2 vyplněné obchody denně
- pevný poměr SL:TP 1:2
- obchodní okna: Asie 01:00-04:00 a New York 16:30-19:30 serverového času
- target: +5 000 USD
- maximální denní ztráta: -5 000 USD
- maximální ztráta od startu: -10 000 USD
- minimálně 2 obchodní dny

## Čtyři po sobě jdoucí testy

| Období | Výsledek | Konečný stav | Target dosažen | Obchodní dny | Max. denní ztráta | Max. ztráta od startu |
|---|---:|---:|---|---:|---:|---:|
| 14. 5.-28. 5. 2026 | PASS | 108 157,67 USD | 26. 5. 18:31 | 4 | 1 519,27 USD | 1 519,27 USD |
| 28. 5.-11. 6. 2026 | FAIL target | 103 569,99 USD | ne | 5 | 4 047,32 USD | 5 126,21 USD |
| 11. 6.-25. 6. 2026 | PASS | 109 537,93 USD | 16. 6. 02:40 | 2 | 1 804,19 USD | 598,17 USD |
| 25. 6.-9. 7. 2026 | PASS | 105 985,98 USD | 30. 6. 03:56 | 3 | 1 811,91 USD | 1 811,91 USD |

Tři ze čtyř po sobě jdoucích 14denních oken splnily profit target a všechna
čtyři dodržela uvedené limity ztráty. Jeden úspěšný historický test ani tato
série nezaručují výsledek budoucí challenge.

## Delší validační test 2024-2026

Pozdější validace ukázala, že výše uvedená čtyři okna nejsou dostatečný důkaz
robustnosti. Stejné parametry byly spuštěny bez zastavení po prvním profit
targetu na všech lokálně dostupných FTMO datech. Roky 2024 a 2025 používají
modelované tickové pohyby z dostupné minutové historie; FTMO real ticks jsou
lokálně dostupné až od 2. 1. 2026.

| Období | Kvalita dat | Konečný stav | Čistý výsledek | Obchody | Max. denní ztráta | Max. ztráta od startu |
|---|---|---:|---:|---:|---:|---:|
| 26. 4.-31. 12. 2024 | modelované tickové pohyby | 89 148,53 USD | -10 851,47 USD | 42 | 4 253,18 USD | 10 851,47 USD |
| 1. 1.-31. 12. 2025 | modelované tickové pohyby | 89 035,58 USD | -10 964,42 USD | 16 | 3 677,27 USD | 10 964,42 USD |
| 2. 1.-14. 7. 2026 | skutečné tickové údaje | 89 939,32 USD | -10 060,68 USD | 13 | 2 578,10 USD | 10 060,68 USD |

Všechna tři samostatná období porušila maximální celkovou ztrátu 10 000 USD.
Profil v1.20 proto **není schválen pro automatické obchodování challenge**.
Úspěch ve třech vybraných 14denních oknech byl závislý na režimu trhu.

## Soubory

- tester bez vykreslování: `configs/EKV_v120_challenge_14d.set`
- profil s objekty v grafu: `configs/EKV_v120_challenge_14d_visual.set`
- testovací konfigurace: `configs/mt5_backtest_v120_challenge_14d_recent.ini`
- dlouhý profil: `configs/EKV_v120_long_history.set`
- roční testy: `configs/mt5_backtest_v120_2024.ini`,
  `configs/mt5_backtest_v120_2025.ini`,
  `configs/mt5_backtest_v120_2026_real.ini`
- surový log MT5: `%APPDATA%/MetaQuotes/Tester/49CDDEAA95A409ED22BD2287BB67CB9C/Agent-127.0.0.1-3001/logs/20260710.log`
