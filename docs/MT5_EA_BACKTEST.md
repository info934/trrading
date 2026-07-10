# MT5 EA backtest

Expert Advisor: `mql5/Experts/EKV_NY_CHoCH_FVG_EA.mq5` (v1.10)

The default model is now the strict lifecycle `liquidity sweep -> later CHoCH
-> later FVG -> limit retracement`. Direction requires confirmed H1 and H4
EMA alignment. The stop is placed beyond the sweep extreme, the default target
is 3R, and break-even is activated after a confirmed M5 close reaches 1.5R.

## Installation

1. Open MetaTrader 5 and choose **File > Open Data Folder**.
2. Copy the EA to `MQL5/Experts/EKV/` and open it in MetaEditor.
3. Compile with F7. Warnings and errors must both be reviewed.
4. Refresh Expert Advisors in the Navigator.

## Strategy Tester baseline

- Symbol: the broker's XAUUSD symbol (it may have a suffix).
- Timeframe: M5.
- Model: **Every tick based on real ticks**.
- Deposit and leverage: match the intended account.
- Date range: use separate in-sample and out-of-sample windows.
- Forward optimization: enable it when optimizing parameters.

Session inputs use **broker server time**, not Prague or New York time. Set
`InpSessionStartHour/Minute` and `InpSessionEndHour/Minute` so they correspond
to 09:30-11:30 New York for the tested broker and daylight-saving period.

## Lot sizing

Dynamic sizing uses `OrderCalcProfit()` for a one-lot move from entry to stop,
then divides the chosen account risk by that broker-specific loss. The result
is multiplied by `InpLotMultiplier`, capped by `InpMaximumLots` and the
broker's `SYMBOL_VOLUME_MAX`, and rounded down to `SYMBOL_VOLUME_STEP`.

Start with `InpRiskPercent=0.25` or `0.50`. Do not optimize lot size to maximize
net profit; validate the entry logic in R-multiples and keep a daily loss cap.

## Required validation

- Confirm CHoCH, FVG, pending entry, SL, TP and break-even in visual mode.
- Compare generated ticks and real ticks.
- Test variable spread, commission and broker stop-level rejection.
- Run at least one untouched out-of-sample period.
- Inspect the Journal for rejected pending orders and failed modifications.

## July 2026 reference run

FTMO-Demo XAUUSD M5, real ticks, 2026-01-01 through 2026-07-09, USD 100,000,
1:100 leverage and 24 ms execution delay:

- obsolete CHoCH-only v1.00: final balance USD 97,878.65;
- v1.10 balanced H1-or-H4 profile: 4 closed trades, 1 TP / 3 SL, final balance
  USD 100,030.93;
- v1.10 production H1-and-H4 profile: 3 closed trades, 1 TP / 2 SL, final
  balance USD 100,525.11.

This short sample is a regression check, not evidence of future profitability.
Use the production profile by default and validate it on a later untouched
period before any live deployment.
