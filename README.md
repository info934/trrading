# EKV Gold Trader

Auditovatelný obchodní systém pro XAU/USD CFD. Signály jsou plánované pro
TradingView (Pine Script v6), ruční exekuce pro MetaTrader 5 a pozdější nezávislá
validace v Pythonu.

> Projekt neslibuje ziskovost a není finančním doporučením. Prioritou je správná
> implementace, řízení rizika, reprodukovatelnost a ochrana proti repaintingu,
> look-ahead biasu a overfittingu.

## Aktuální stav

Repozitář je inicializovaný a chráněný proti nechtěnému ukládání velkých dat,
logů, reportů a tajných údajů. Implementace strategie čeká na dodání původního
souboru `EKV_Gold_Trader_v1_0.txt`, který je podle zadání nutné nejprve auditovat.

## Struktura

```text
pine/             Pine strategie a indikátor
python/           pozdější backtestovací a validační vrstva
configs/          verzované příklady konfigurace bez tajných údajů
tests/            testovací checklisty a automatické testy
docs/             audit, pravidla strategie a changelog
reports/          pouze lokální generované výstupy (ignorované Gitem)
scripts/          pomocné provozní kontroly
```

## Ochrana počítače a repozitáře

- Historická data, reporty, databáze, logy, cache a virtuální prostředí Git ignoruje.
- Commit hook odmítne jednotlivé soubory větší než 25 MiB a generované soubory v
  `python/data/` a `reports/`.
- Skript `scripts/check_workspace_size.ps1` ukáže největší soubory a skončí chybou,
  pokud pracovní složka bez `.git` překročí nastavený limit.
- Citlivé hodnoty patří do `.env`, nikdy ne do verzované konfigurace.

Kontrola velikosti:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check_workspace_size.ps1
```

## Dostupné Pine verze

- `pine/EKV_Gold_Trader_v1_0.txt` — původní auditovaný strategický zdroj.
- `pine/EKV_Gold_Trader_indicator_v1_2.pine` — signalizační indikátor v1.2
  bez Strategy Testeru a Bar Magnifieru; obsahuje úrovně, dashboard a alerty.

Indikátor nevytváří skutečné objednávky a jeho price-touch události nejsou
potvrzením fillu v MT5. Před ručním obchodem je nutné zkontrolovat specifikaci
XAUUSD kontraktu u konkrétního brokera.
