# EKV Gold Trader Indicator v1.3

v1.3 je signalizační Pine v6 indikátor pro ruční exekuci v MT5. Nepoužívá
`strategy()`, Strategy Tester ani Bar Magnifier a nikdy nepotvrzuje skutečný fill.

## Instalace

1. Otevřete standardní XAUUSD graf na M5.
2. Vložte `pine/EKV_Gold_Trader_indicator_v1_3.pine` do Pine Editoru, uložte a
   zvolte Add to chart.
3. Zkontrolujte H1 `60`, H4 `240`, timezone `America/New_York`, session
   `0930-1200` a lot specifikaci brokera.
4. Vytvořte alert `Any alert() function call`; po změně skriptu jej vytvořte znovu.

## Profily a zobrazení

| Profil | HTF filtr | Alerty |
|---|---|---|
| Production | H1 i H4 stejným směrem | ano |
| Balanced experimental | jednostranný H1/H4 bez konfliktu | ano |
| Structure debug | bias ignorován | ne |

Clean zobrazuje akční lifecycle značky a levely. Debug navíc zobrazuje pivoty,
BLOCK značky, session/news pozadí a počitadla.

## Lifecycle a alert kontrakt

Stavy jsou `WAIT SWEEP`, `WAIT CHoCH`, `WAIT FVG`, `PENDING`, `OPEN`.
Události jsou `CREATE`, `CANCEL`, `ENTRY_TOUCHED`, `MOVE_BE` a `VIRTUAL_EXIT`;
každý alert začíná `EKV|v1.3` a sdílí `planId`. Dotyk entry je pouze cenová
událost. `AMBIGUOUS_ENTRY_BAR` a `AMBIGUOUS_SL_AND_TP` jsou terminální.

Plán se zruší také při dosažení TP před entry (`TARGET_BEFORE_ENTRY`) a nový
setup se na poslední svíčce session už nezahajuje.

FVG i entry touch musí být na pozdější svíčce. BE vyžaduje close na 1.5R
(výchozí) a nový stop se použije až od další svíčky. Poslední session svíčka
povolí touch pending plánu, jinak jej zruší. Stage 4 se session/news/novým dnem
neruší.

## Diagnostika

Dashboard ověřuje chart, HTF pořadí, lot config, session a news. V Debug režimu
sledujte `Raw/Qualified`, `Last block/Risk` a důvody `USE_M5`, `USE_XAUUSD`,
`BIAS_FILTER`, `STATE_BUSY` nebo `DAILY_LIMIT`.

Podrobný checklist je v `tests/PINE_INDICATOR_V1_3_CHECKLIST.md`; screenshoty a
exporty ukládejte pouze do ignorovaného `reports/`.
