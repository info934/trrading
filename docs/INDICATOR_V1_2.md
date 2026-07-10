# EKV Gold Trader Indicator v1.2

Tato varianta je běžný Pine indikátor. Nepoužívá `strategy()`, Strategy Tester,
Bar Magnifier ani simulované broker objednávky.

## Instalace v TradingView

1. Otevřít standardní svíčkový graf XAUUSD na timeframe 5 minut.
2. Otevřít Pine Editor a vložit celý obsah
   `pine/EKV_Gold_Trader_indicator_v1_2.pine`.
3. Zvolit Save a Add to chart.
4. V nastavení zkontrolovat H1=`60`, H4=`240`, timezone
   `America/New_York` a specifikaci MT5 lotu konkrétního brokera.
5. Pro alert zvolit tento indikátor a podmínku `Any alert() function call`.

Výchozí profil `Balanced` vyžaduje odpovídající EMA bias alespoň na H1 nebo H4.
`Strict v1.0` zachovává původní požadavek současného H1 i H4 biasu. Profil
`Structure only` ignoruje EMA bias a slouží k ověření sweep/CHoCH/FVG logiky.

## Význam alertů

- `CREATE` — vznikl kompletní BUY/SELL LIMIT plán.
- `CANCEL` — plán už není platný; podle stejného `planId` zrušit ruční MT5
  pending příkaz.
- `ENTRY_TOUCHED` — cena v TradingView na potvrzené svíčce zasáhla entry;
  skutečný MT5 fill je nutné ověřit ručně.
- `MOVE_BE` — indikativní výzva k posunu SL.
- `VIRTUAL_EXIT` — indikativní zásah SL/BE/TP; není to broker potvrzení.

## Důležitá omezení

- Indikátor neposkytuje backtest ani statistiku ziskovosti.
- Price touch není důkaz skutečného fillu, protože TradingView nezná spread,
  likviditu ani exekuci účtu v MT5.
- Pokud jedna svíčka zasáhne SL i TP, výsledek je označen
  `AMBIGUOUS_SL_AND_TP`; z OHLC nelze bezpečně určit pořadí.
- Výchozí volba `Allow FVG on CHoCH candle` je zapnutá stejně jako v původní
  v1.0. Jejím vypnutím se počet historických plánů obvykle sníží.

## Když nejsou vidět historické signály

- Zelené/červené trojúhelníky jsou potvrzené pivoty a ověřují, že indikátor
  historická data zpracovává.
- Šedé `BLOCK` znamená strukturální sweep, který zablokoval bias, session,
  timeframe nebo rozpracovaný stav.
- Dashboard ukazuje počty `qualified/raw` sweepů a `CHoCH/plans` za právě
  načtenou historii grafu.
- Tyrkysová EMA 20 je kontrola, že je indikátor skutečně spuštěný. Pokud není
  vidět EMA ani dashboard, skript nebyl přidaný do grafu nebo neprošel kompilací.
- Pokud je `raw = 0`, načíst delší historii nebo zvýšit `Maximum sweep depth`.
- Pokud `raw > 0`, ale `qualified = 0`, zkontrolovat červený stav Chart,
  H1/H4 bias a NY session.
