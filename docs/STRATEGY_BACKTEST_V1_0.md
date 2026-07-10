# NY SMC Strategy Tester v1.0

`pine/EKV_Gold_Trader_strategy_v1_0.pine` is a separate research strategy.
It shares the NY SMC sequence of the indicator: confirmed HTF bias, liquidity
sweep, later CHoCH, later FVG, and a limit retracement.

It is not an MT5 execution model. Its order fills, commission, slippage,
contract semantics, and intrabar order are TradingView assumptions. Use it for
walk-forward and out-of-sample comparison, not as evidence of live performance.
The strategy declaration uses 1% long/short margin to model 1:100 leverage;
without it, TradingView can reject risk-sized XAUUSD quantities as unaffordable
and show an empty report even when structural setup markers are visible.

Use standard OANDA:XAUUSD M5 candles. Start with Production-style defaults,
review the Strategy Tester list of trades, and test multiple non-overlapping
date windows before changing inputs. Keep any exports in `reports/`.

The backtest defaults to `Balanced experimental` to provide a larger research
sample. It is intentionally not the production signal standard: use
`Production` to require H1 and H4 EMA alignment before drawing conclusions.
Its experimental defaults also use the proximal FVG edge, a longer pending
window, and lower displacement/FVG thresholds. Restore the stricter values
before comparing the result with Production.

`Market on FVG (experimental)` is the default execution setting for a larger
sample of backtest trades. It enters after a confirmed FVG instead of waiting
for a limit retracement, so it must never be treated as equivalent to the
indicator's production MT5 workflow.
