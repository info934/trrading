# NY SMC Strategy Tester v1.0

`pine/EKV_Gold_Trader_strategy_v1_0.pine` is a separate research strategy based
on the repeatable NY-open model from the supplied transcript:

1. Detect the first confirmed CHoCH after 09:30 New York.
2. Track the directional impulse from its preceding swing to its new extreme.
3. Accept only an FVG whose midpoint is inside the 50%-61.8% retracement zone.
4. Place a limit order at the FVG midpoint and the stop beyond its producing candle.
5. Target 4R by default and move to break-even only after a confirmed structural close.

It is not an MT5 execution model. Its order fills, commission, slippage,
contract semantics, and intrabar order are TradingView assumptions. Use it for
walk-forward and out-of-sample comparison, not as evidence of live performance.
The strategy declaration uses 1% long/short margin to model 1:100 leverage;
without it, TradingView can reject risk-sized XAUUSD quantities as unaffordable
and show an empty report even when structural setup markers are visible.

Use standard OANDA:XAUUSD M5 candles. The default `Session CHoCH` profile does
not impose an EMA direction gate; `Production` requires H1 and H4 alignment and
`Balanced experimental` accepts a non-conflicting directional bias. Review the
trade list and test multiple non-overlapping date windows. Keep exports in
`reports/`.

## Position sizing

`Position sizing mode` controls how the base lot is calculated:

- `Risk % (dynamic)`: `equity × risk % / (SL distance × contract size)`.
- `Fixed lots`: uses the `Fixed lots` input directly.

`Lot multiplier` then scales either base value and `Maximum lots` caps the
result before the order is sent. The final lot is rounded down to `Lot step`.
TradingView's `strategy.entry()` quantity for XAUUSD is expressed in ounces,
not MT5 lots. With a contract size of 100, a TradingView quantity of `23`
represents `0.23` lot; `1.00` MT5 lot is sent as `100` ounces.
