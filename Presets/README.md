# HedgeGridEA — Presets

Ready-to-load `.set` files for all 8 supported symbols. Each preset sets `InpSymbolPreset` to the matching enum value so the EA auto-applies its internal overrides, and also fills in every other input with the matching value (so the file is self-contained if you later switch `InpSymbolPreset` to `CUSTOM`).

## Installation

Copy the `.set` files into your MT5 terminal's presets folder:

```
<MT5 data folder>/MQL5/Presets/
```

To find the data folder from inside MetaTrader 5: **File -> Open Data Folder**.

## Loading a preset

### In the Strategy Tester
1. Open the Strategy Tester (**View -> Strategy Tester**, or `Ctrl+R`).
2. Choose `HedgeGridEA` as the Expert.
3. Click **Inputs** tab -> **Load** -> select the `.set` file.

### On a live chart
1. Drag `HedgeGridEA` onto the chart (use the same symbol as the preset!).
2. In the settings dialog, go to **Inputs** -> **Load**.
3. Pick the `.set` file that matches the symbol.

## Preset summary

| File | Symbol | Strategy | Starting lot | Spread limit | Grid ATR | Hedge ATR | Notes |
|---|---|---|---|---|---|---|---|
| `HedgeGridEA_EURUSD.set` | EURUSD | HYBRID | 0.01 | 2.0 pips | 1.0 | 2.0 | Major pair, balanced |
| `HedgeGridEA_GBPUSD.set` | GBPUSD | HYBRID | 0.01 | 2.5 pips | 1.0 | 2.0 | Major pair |
| `HedgeGridEA_USDJPY.set` | USDJPY | HYBRID | 0.01 | 2.0 pips | 1.0 | 2.0 | Major pair |
| `HedgeGridEA_GBPJPY.set` | GBPJPY | TREND_GRID | 0.01 | 4.0 pips | 1.2 | 2.2 | Volatile cross |
| `HedgeGridEA_EURCHF.set` | EURCHF | DUAL_HEDGE | 0.01 | 3.0 pips | 0.7 | 1.8 | Ranging pair, tight grid |
| `HedgeGridEA_XAUUSD.set` | XAUUSD | TREND_GRID | 0.01 | 30 pips | 1.5 | 2.5 | Gold, wider ATR |
| `HedgeGridEA_US30.set`   | US30   | HYBRID | 0.10 | 50 pips | 1.0 | 2.0 | Dow index, NY session 14-21 |
| `HedgeGridEA_BTCUSD.set` | BTCUSD | BREAKOUT | 0.01 | 500 pips | 1.5 | 3.0 | Crypto, 24/7, no Friday close |

## Tuning per broker

The preset numbers are conservative starting points; spreads, commissions and symbol naming vary per broker:

- **Symbol name differences:** some brokers use `EURUSD.m`, `XAUUSDm`, `US30.cash`, `BTCUSDT`, etc. The preset applies regardless of symbol name, but make sure the chart's symbol is the right one.
- **5-digit vs 4-digit pricing:** the EA auto-detects (pip = 10 x point on 3/5-digit symbols). No change needed.
- **Spread limit:** if your broker shows wider spreads than the preset allows, either raise `InpMaxSpreadPips` or set `InpUseSpreadFilter=false`.
- **Starting lot:** for accounts with >1-cent minimum volume, bump `InpStartingLot` and `InpMaxLotCap` proportionally.

## Before going live

Always backtest with real tick data for at least 2-3 years and forward-test on demo before committing real capital. No preset makes an EA profitable on its own.
