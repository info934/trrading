# NY SMC Strategy Tester v1.0

`pine/EKV_Gold_Trader_strategy_v1_0.pine` is a separate research strategy.
It shares the NY SMC sequence of the indicator: confirmed HTF bias, liquidity
sweep, later CHoCH, later FVG, and a limit retracement.

It is not an MT5 execution model. Its order fills, commission, slippage,
contract semantics, and intrabar order are TradingView assumptions. Use it for
walk-forward and out-of-sample comparison, not as evidence of live performance.

Use standard OANDA:XAUUSD M5 candles. Start with Production-style defaults,
review the Strategy Tester list of trades, and test multiple non-overlapping
date windows before changing inputs. Keep any exports in `reports/`.
