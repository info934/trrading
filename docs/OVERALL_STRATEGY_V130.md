# EKV Overall Strategy v1.30

## Vybraný model

- XAUUSD, M5
- pouze New York okno 16:30-19:30 serverového času FTMO
- H1 trendový filtr: close a EMA 50 na stejné straně EMA 200, EMA 50 musí
  mít odpovídající sklon
- potvrzený liquidity sweep -> pozdější CHoCH -> pozdější FVG -> limitní vstup
- stop za extrémem sweepu s ATR bufferem
- pevný poměr risk/zisk 1:2
- přesun na BE po potvrzeném M5 close na 1R
- 1 % equity risk na obchod, maximálně dva vyplněné obchody denně

## Reprodukční výsledky

| Období | Kvalita dat | Čistý výsledek | Konečný stav | Obchody | Peak drawdown |
|---|---|---:|---:|---:|---:|
| 26. 4.-31. 12. 2024 | modelované tickové pohyby | +4 530,55 USD | 104 530,55 USD | 15 | 4 930,83 USD |
| 1. 1.-31. 12. 2025 | modelované tickové pohyby | +7 480,33 USD | 107 480,33 USD | 25 | 4 310,91 USD |
| 2. 1.-14. 7. 2026 | skutečné tickové údaje | +5 947,56 USD | 105 947,56 USD | 15 | 2 932,40 USD |
| 26. 4. 2024-14. 7. 2026 | kombinovaná historie | +18 988,13 USD | 118 988,13 USD | 55 | 4 930,83 USD |

Celý reprodukční test měl maximální denní ztrátu 1 235,67 USD. Z 48 týdnů,
ve kterých byl uzavřen obchod, bylo 21 ziskových a 27 ztrátových. Strategie je
tedy overall kladná v dostupném vzorku, ale negeneruje rovnoměrný týdenní zisk
a není historickou zárukou budoucí profitability.

## Výběr profilu

NY H1-only byl zvolen před NY balanced. Balanced dosáhl +21 074,66 USD, ale
jeho peak drawdown byl 8 331,88 USD. H1-only dosáhl +18 988,13 USD při výrazně
nižším peak drawdownu 4 930,83 USD a byl kladný ve všech třech samostatných
obdobích.

## Soubory

- demo/live vizuální profil: `configs/EKV_v130_overall_visual.set`
- výzkumný profil bez challenge stopu: `configs/EKV_v130_overall_research.set`
- celý test: `configs/mt5_backtest_v130_overall.ini`
- roční testy: `configs/mt5_backtest_v130_2024.ini`,
  `configs/mt5_backtest_v130_2025.ini`,
  `configs/mt5_backtest_v130_2026_real.ini`

Profil s challenge ochranami zastaví nové vstupy po dosažení realizovaného
targetu nebo po dosažení nastavených loss limitů. Cenový gap, slippage, komise
a swap přesto mohou způsobit překročení plánované hranice.
