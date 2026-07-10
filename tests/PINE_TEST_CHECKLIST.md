# Pine test checklist

## Compile a prostředí

- [ ] Pine v6 kompiluje bez warningu/chyby v aktuálním Pine Editoru.
- [ ] Test běží na standardních svíčkách XAUUSD M5.
- [ ] H1 a H4 vstupy odmítnou stejný/nižší timeframe a H4 <= H1.
- [ ] Screenshot Strategy Properties zachycuje kapitál, Bar Magnifier, náklady,
      slippage a limit-fill assumption.

## Repainting a pořadí setupu

- [ ] H1/H4 hodnoty se během otevřené HTF svíčky nemění.
- [ ] Reload grafu nezmění historické sweep/CHoCH/FVG signály.
- [ ] Pivot se smí použít až po `swingLen` pravých svíčkách.
- [ ] Je otestováno a zdokumentováno, zda CHoCH a FVG smějí sdílet svíčku.
- [ ] Invalidní směr SL vůči vstupu nevytvoří plán.

## Pending a hranice

- [ ] Pending z poslední session svíčky se nemůže vyplnit po 12:00 NY.
- [ ] Pending se nemůže vyplnit po začátku news blackout, včetně události
      uprostřed M5 svíčky.
- [ ] Expirace pro N=1 a N=12 odpovídá formální definici bez off-by-one.
- [ ] Nový NY den, daily stop a total stop zruší pending před možným fillem.
- [ ] Každé zrušení odešle právě jeden CANCEL alert se stejným `planId`.

## Fill a trade management

- [ ] Same-bar entry+SL nezpůsobí druhý vstup.
- [ ] Same-bar entry+TP nezpůsobí druhý vstup.
- [ ] Same-bar entry+BE+exit nezpůsobí druhý vstup.
- [ ] Realtime forward test potvrzuje stav po intrabar fillu i po reloadu alertu.
- [ ] BE přesně odpovídá schválenému pravidlu (intrabar dotyk nebo M5 close).
- [ ] Extrém před vstupním filleм nesmí zpětně aktivovat BE.
- [ ] TP a BE backtestu jsou odvozené od skutečného TradingView fillu.
- [ ] MT5 workflow výslovně řeší rozdíl plánovaného a skutečného MT5 fillu.

## Risk a alerty

- [ ] Změna referenční velikosti účtu nemůže okamžitě rozbít total-loss guard.
- [ ] Backtest qty i MT5 lot se zaokrouhlují dolů a nepřekročí risk.
- [ ] Finální lot splňuje min/max/step i při hraničních konfiguracích.
- [ ] CREATE, FILLED, MOVE_BE, EXIT a CANCEL používají jedno `planId`.
- [ ] Alert a dashboard odpovídají internímu stavu.
- [ ] Maximálně dvě vyplnění za NY den a jedna otevřená pozice.

## Reprodukovatelnost

- [ ] Stejný symbol, timeframe a nastavení dají po reloadu stejný výsledek.
- [ ] Výsledky jsou porovnány s vypnutým/zapnutým Bar Magnifierem.
- [ ] Je proveden citlivostní test spreadu, komise a slippage.
- [ ] Export obchodů a testovací nastavení jsou uloženy do ignorovaného
      `reports/`, ne do Gitu.
