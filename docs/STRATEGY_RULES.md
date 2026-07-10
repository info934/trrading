# Pravidla strategie

## Deklarovaný záměr v1.0

- Trh XAU/USD CFD, graf M5, newyorská session 09:30–12:00.
- Směr vyžaduje soulad potvrzeného H1 a H4 EMA biasu.
- Setup: liquidity sweep → CHoCH → následný FVG → limitní retracement.
- SL za extrémem sweepu, TP ve výchozím nastavení 3R.
- Přesun SL na BE + nákladový offset po dosažení výchozích 1,5R.
- Nejvýše dva vyplněné obchody za newyorský den.
- Ručně spravovaný blackout pro high-impact události.
- TradingView slouží pro signál/backtest, MT5 lot pro ruční exekuci.

## Skutečné odchylky v1.0

- FVG může vzniknout už na stejné svíčce jako CHoCH.
- BE se s `calc_on_every_tick = false` neaktivuje spolehlivě při intrabar dotyku;
  běžně se vyhodnotí až na close M5 svíčky.
- Pending příkaz může být vyplněn po session/news hranici dříve, než jej další
  výpočet stihne zrušit.
- Zrušení TradingView plánu neposílá CANCEL alert pro ruční MT5 příkaz.
- Backtest neobsahuje spread, komisi, slippage ani konzervativní limit-fill model.

## Rozhodnutí požadovaná před v1.1

1. Musí být FVG nejdříve na svíčce po CHoCH, nebo smí sdílet CHoCH svíčku?
2. Znamená BE „intrabar dotyk 1,5R“, nebo „M5 close dosáhl 1,5R“?
3. Kdy přesně expiruje setup pro hodnotu N: na N-té svíčce, nebo až po ní?
4. Má změna HTF biasu invalidovat rozpracovaný/pending setup?
5. Má začátek news blackout zrušit i existující pending MT5 příkaz? Audit
   doporučuje ano.
6. Je risk fixní z referenčního účtu, nebo procento aktuální equity?
7. Jaké spread/komise/slippage a broker lot specifikace jsou autoritativní?

Žádná implementace nesmí tvrdit garantovanou ziskovost.
