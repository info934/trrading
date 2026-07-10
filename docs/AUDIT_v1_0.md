# Audit EKV Gold Trader v1.0

## Stav auditu

**Statický audit dokončen 2026-07-10. TradingView compile a replay test čekají na
ruční ověření v Pine Editoru.**

Auditovaná obsahově nezměněná kopie (pouze normalizovaný konec souboru) je
`pine/EKV_Gold_Trader_v1_0.txt`. Audit nepotvrzuje
ziskovost a verze 1.1 zatím nebyla vytvořena.

## Souhrn

- HTF požadavky používají správný nerepaintující vzor: historický offset `[1]`
  společně s `barmerge.lookahead_on` (řádky 47–56).
- Pivoty jsou potvrzené až po `swingLen` pravých svíčkách (řádky 169–184).
- Oddělení MT5 lotu a TradingView `qty` je koncepčně správné.
- Produkční použití ale blokují chyby P0 a P1 níže. Nejzávažnější je kombinace
  `calc_on_order_fills`, stavových proměnných `var` a realtime rollbacku.

## Nálezy

### P0 — Intrabar rollback může znovu odeslat již uzavřený vstup

**Řádky:** 10, 189–215, 371–385, 401–471
**Dopad:** neočekávaný opakovaný vstup a rozdíl mezi historií a realtime.

Na otevřené realtime svíčce se hodnoty běžných `var` před každou další exekucí
vracejí k poslednímu potvrzenému close; brokerem vyplněné příkazy se naopak
nerollbackují. Pokud se limit vstup a následný exit vyplní ve stejné M5 svíčce,
další exekuce po fillu může vidět poslední potvrzený stav `stage == 3`,
`fillHandled == false` a současně `flat == true`. Blok na řádcích 371–385 pak
znovu vytvoří vstupní příkaz. Reset na řádcích 445–471 se nespustí, protože
`fillHandled` se rollbackem vrátil na `false`.

**Oprava:** navrhnout fill stav tak, aby se neopíral o dočasné intrabar hodnoty
`var`; explicitně detekovat změny `strategy.opentrades`/`strategy.closedtrades`,
zabránit rearmování stejného plánu a otestovat same-bar entry+SL, entry+TP i
entry+BE+exit v realtime. Pouhé nahrazení všeho za `varip` není přijatelné bez
samostatného testu, protože `varip` se na historických svíčkách chová jinak.

### P1 — Pending limit může být vyplněn mimo session nebo během news blackout

**Řádky:** 143–151, 233–241, 370–385
**Dopad:** obchod poruší časový/news filtr.

Pending příkaz existuje u broker emulátoru mezi výpočty skriptu. Zrušení se
provádí až při dalším výpočtu. Příkaz ponechaný z poslední povolené svíčky se
proto může vyplnit uvnitř první svíčky po 12:00 nebo po začátku news okna; fill
vyvolá přepnutí do `stage == 4` a následné zrušení už nepřijde.

**Oprava:** zrušit pending ještě na posledním povoleném close podle
`time_close`, definovat přesnou platnost příkazu a přidat replay test přes hranici
session i přes událost uprostřed M5 svíčky.

### P1 — Break-even není v realtime aktivován při dotyku 1,5R

**Řádky:** 11, 414–442
**Dopad:** cena může po dosažení 1,5R před close svíčky spadnout zpět; MT5 BE
alert přijde pozdě nebo vůbec a chování neodpovídá komentáři „after 1.5R“.

S `calc_on_every_tick = false` se otevřený obchod standardně vyhodnotí až na
close M5 svíčky (výjimkou jsou fill události). Podmínka přes `high`/`low` tedy
není tickový trigger. Navíc při přepočtu po vstupním fillu může historická
svíčka obsahovat extrém, který nastal před vstupem, což vytváří intrabar pořadí,
které nebylo obchodovatelné.

**Oprava:** přesně rozhodnout, zda pravidlo znamená dotyk intrabar nebo potvrzený
M5 close. Pro intrabar variantu použít broker-emulovatelnou order konstrukci a
oddělit backtest od alertové realtime logiky; ověřit pořadí pomocí Bar Magnifieru
a forward testu.

### P1 — Ruční MT5 pending order nedostane CANCEL alert

**Řádky:** 239–260, 387–399
**Dopad:** TradingView plán expiruje nebo je invalidován, ale ručně vložený MT5
příkaz zůstane aktivní a může se později vyplnit.

Plán má dynamický alert, všechny reset větve jsou však bez odpovídajícího alertu
a bez důvodu zrušení. Chybí také jednoznačné ID plánu pro párování CREATE,
FILLED, MOVE_BE a CANCEL zpráv.

**Oprava:** přidat stabilní `planId`, důvod resetu a povinný CANCEL alert pro
expiry, session, news, daily/total stop a nový NY den. V návodu vyžadovat
spárování alertu s konkrétním MT5 pending příkazem.

### P1 — `accountSize` není svázán s kapitálem Strategy Testeru

**Řádky:** 5, 80–86, 165–167, 328–334
**Dopad:** změna vstupu `accountSize` rozbije význam risku a total-loss guardu.

`initial_capital` je pevně 100 000 USD, zatímco výpočty používají měnitelný
`accountSize`. Při `accountSize = 200000` je `totalStopHit` aktivní okamžitě
(100 000 <= 190 000); při `accountSize = 50000` začne total stop až po ztrátě
více než poloviny testerového kapitálu.

**Oprava:** používat jednu autoritativní základnu. Pro backtest odvodit guardy a
qty od `strategy.initial_capital`/equity; referenční MT5 účet držet explicitně
odděleně a na nesoulad upozornit.

### P1 — Backtest nemodeluje spread, komisi, slippage ani ověření limit fillu

**Řádky:** 2–16, 84, 370–437
**Dopad:** výsledky, zejména BE+0,10 a těsné FVG vstupy, mohou být významně
nadhodnocené.

Deklarace nemá `commission_*`, `slippage` ani
`backtest_fill_limits_assumption`. `beOffsetPrice` není náhradou nákladového
modelu. Bar Magnifier pouze zpřesňuje intrabar data; nevytváří spread ani
likviditu.

**Oprava:** přidat explicitní, dokumentované náklady pro konkrétní feed/brokera,
konzervativní limit-fill assumption a citlivostní test více nákladových scénářů.

### P2 — FVG může vzniknout na stejné svíčce jako CHoCH

**Řádky:** 306–316
**Dopad:** skutečné pořadí je `sweep → CHoCH+FVG`, ačkoli popis a checklist
uvádějí `sweep → CHoCH → FVG`.

Po nastavení `stage := 2` se ve stejné exekuci vyhodnotí `bar_index >= chochBar`,
což je vždy pravda. Je nutné potvrdit obchodní záměr. Pokud má FVG následovat až
po CHoCH svíčce, podmínka musí být striktní a test musí vyloučit same-bar FVG.

### P2 — Směr SL vůči vstupu není validován

**Řádky:** 323–345
**Dopad:** nestandardní cenová sekvence může projít přes `math.abs`, i když je
long SL nad vstupem nebo short SL pod vstupem; výsledný stop je neplatný či se
aktivuje okamžitě.

**Oprava:** před výpočtem risku vyžadovat pro long `plannedSL < plannedEntry` a
pro short `plannedSL > plannedEntry`, poté teprve počítat směrovou vzdálenost.

### P2 — Nejsou validovány vzájemné vztahy MT5 parametrů

**Řádky:** 89–92, 329–342
**Dopad:** konfigurace `mt5MinLot > mt5MaxLot` může projít kontrolou a po aplikaci
maxima vytvořit lot menší než minimum. Neověřuje se ani soulad minima s krokem.

**Oprava:** kontrolovat `min <= max`, kladný krok, obchodovatelný interval a po
všech clamp/round operacích znovu ověřit finální lot.

### P2 — Uživatelské HTF vstupy nemusí být vyšší než chart timeframe

**Řádky:** 41–56
**Dopad:** po změně H1/H4 vstupu na stejný nebo nižší timeframe už použitý HTF
vzor nemá deklarovanou sémantiku a `request.security()` z nižšího timeframe
vrací jen omezený výsek intrabar dat.

**Oprava:** vyžadovat `H1 > chart` a `H4 > H1`, jinak zastavit skript jasnou
runtime chybou.

### P2 — Chybí ochrana před nestandardním typem grafu

**Řádky:** 2–16, 138–143
**Dopad:** Heikin Ashi, Renko a další syntetické ceny mohou dát nereálné fill a
risk výsledky.

**Oprava:** dokumentovat a kontrolovat standardní svíčky; pro Heikin Ashi lze
zvážit `fill_orders_on_standard_ohlc`, ostatní nestandardní grafy nepovolit.

### P2 — MT5 plán nelze po fillu bezpečně synchronizovat s TradingView

**Řádky:** 387–442
**Dopad:** CREATE alert obsahuje TP/BE od plánovaného vstupu, zatímco backtest po
fillu přepočítá úrovně ze `strategy.position_avg_price`. TradingView nezná
skutečný MT5 fill, takže ruční obchod může mít jiné R a chybí potvrzovací workflow.

**Oprava:** v dokumentaci oddělit „plánované“ a „skutečné“ hodnoty a vyžadovat po
MT5 fillu ruční přepočet nebo bezpečnou integraci se zpětnou vazbou od brokera.

### P3 — Expirace má nejasnou hranici o jednu svíčku

**Řádky:** 231–233
**Dopad:** podmínka `>` ruší až na svíčce následující po dosažení limitu. Bez
formální definice není jasné, zda se počítá signální svíčka a kolik fill oken je
povoleno.

**Oprava:** zapsat příklady pro hodnoty 1 a 12 a podle schválené definice použít
`>=` nebo `>`.

## Potvrzené správné části

1. Nerepaintující výchozí H1/H4 data přes `[1] + lookahead_on`.
2. Potvrzené pivoty bez zpětného použití před okamžikem jejich potvrzení.
3. `pyramiding = 0` a samostatné ID long/short při jednom aktivním setupu.
4. Zaokrouhlení qty a lotu dolů (pro validní kladné parametry).
5. TP a BE backtestu se po fillu přepočítají z `strategy.position_avg_price`.
6. NY kalendářní klíč používá timezone `America/New_York`, takže respektuje DST.

## Omezení auditu a povinné ověření

V lokálním prostředí není Pine kompilátor ani TradingView broker emulator. Proto
nelze zatím tvrdit, že skript kompiluje nebo že pořadí fillů odpovídá očekávání.
Před v1.1 je nutné v TradingView provést checklist v
`tests/PINE_TEST_CHECKLIST.md`, uložit screenshot Properties a export obchodů.

## Doporučené pořadí oprav pro v1.1

1. Opravit realtime fill state/rollback a zablokovat re-entry stejného plánu.
2. Uzavřít pending příkazy před session/news hranicí a přidat CANCEL workflow.
3. Formálně rozhodnout intrabar versus close-only BE a CHoCH/FVG pořadí.
4. Sjednotit kapitálové základny, validace směru SL a MT5 parametrů.
5. Přidat realistický nákladový a limit-fill model.
6. Přidat timeframe/chart guardy a úplná ID alertů.
7. Teprve poté vytvořit v1.1 a provést ruční replay + forward test.

## Referenční dokumentace

- TradingView, Execution model: https://www.tradingview.com/pine-script-docs/language/execution-model/
- TradingView, Strategies: https://www.tradingview.com/pine-script-docs/concepts/strategies/
- TradingView, Strategy properties: https://www.tradingview.com/support/solutions/43000628599-strategy-properties/
- TradingView, Other timeframes and data: https://www.tradingview.com/pine-script-docs/faq/other-data-and-timeframes/
- TradingView, Alerts: https://www.tradingview.com/pine-script-docs/faq/alerts/
