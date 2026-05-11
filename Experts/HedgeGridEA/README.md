# HedgeGridEA — All-in-one Hedge & Grid EA for MetaTrader 5

A single MQL5 Expert Advisor that combines five trading profiles with eight per-symbol presets. Built to be configurable without recompilation.

> **Risk notice:** Hedge/grid strategies can show a smooth equity curve for long periods and then suffer severe drawdowns during strong trends. No EA guarantees "daily profit". Always backtest and forward-test on demo first, and use the built-in kill-switch.

## Directory layout

```
Experts/HedgeGridEA/
├── HedgeGridEA.mq5        # main EA — compile this in MetaEditor
├── Include/
│   ├── Enums.mqh          # strategy & preset enums
│   ├── Inputs.mqh         # input panel + working globals
│   ├── Utils.mqh          # pip/lot/price helpers
│   ├── Indicators.mqh     # ATR / EMA / RSI / Bollinger handles
│   ├── FilterEngine.mqh   # spread / session / trend filters
│   ├── PresetManager.mqh  # per-symbol preset overrides
│   ├── TradeManager.mqh   # CTrade wrapper + position iteration
│   ├── RiskManager.mqh    # basket TP/SL, kill-switch, Friday close
│   ├── GridManager.mqh    # grid progression + hedge trigger
│   └── StrategyEngine.mqh # entry vote per strategy
├── Presets/               # ready-to-load .set files
│   ├── EURUSD_hybrid.set
│   ├── XAUUSD_trend.set
│   └── EURCHF_range.set
└── README.md
```

## Installation

1. Copy the folder `HedgeGridEA/` into your MT5 terminal's `MQL5/Experts/` directory.
2. Open **MetaEditor**, navigate to `Experts/HedgeGridEA/HedgeGridEA.mq5`, and press **F7** (Compile). There should be zero errors and zero warnings.
3. In MT5, attach `HedgeGridEA` to a chart from the Navigator panel.
4. **Allow algorithmic trading** in the EA dialog.
5. Optionally load one of the `.set` files from `Presets/`.

## Strategy profiles (`InpStrategy`)

| Value | Name | Description |
|---|---|---|
| 0 | `STRATEGY_DUAL_HEDGE` | Opens BUY and SELL together, no signal. Ideal for ranging pairs (EURCHF). |
| 1 | `STRATEGY_TREND_GRID` | Grids only in the direction of the H4 EMA trend. |
| 2 | `STRATEGY_MEAN_REVERSION` | Enters BUY at RSI<30 & lower Bollinger, SELL at RSI>70 & upper Bollinger. |
| 3 | `STRATEGY_BREAKOUT` | Enters on break of previous N-day high or low. |
| 4 | `STRATEGY_HYBRID` | Multi-filter: session + spread + trend must all agree. (Default & safest.) |

## Symbol presets (`InpSymbolPreset`)

When `InpSymbolPreset` is set to any value other than `PRESET_CUSTOM`, the EA overrides the lot, grid, hedge, spread, and trend inputs at `OnInit()`. The user inputs are ignored for the overridden fields.

| Value | Preset | Default strategy | Notable tuning |
|---|---|---|---|
| 0 | `PRESET_CUSTOM` | (manual inputs) | Use the inputs as-is. |
| 1 | `PRESET_EURUSD` | HYBRID | spread 2 pips, ATR×1.0 |
| 2 | `PRESET_GBPUSD` | HYBRID | spread 2.5 pips |
| 3 | `PRESET_USDJPY` | HYBRID | spread 2 pips |
| 4 | `PRESET_GBPJPY` | TREND_GRID | wider ATR×1.2, spread 4 pips |
| 5 | `PRESET_EURCHF` | DUAL_HEDGE | tight ATR×0.7, no filters |
| 6 | `PRESET_XAUUSD` | TREND_GRID | wide ATR×1.5, spread 30 |
| 7 | `PRESET_US30` | HYBRID | M30 ATR, spread 50 |
| 8 | `PRESET_BTCUSD` | BREAKOUT | ATR×1.5, spread 500 |

## Risk management

- **Basket take-profit** (`InpBasketTPPercent`): closes all EA positions when floating P&L ≥ this % of equity.
- **Kill-switch** (`InpBasketSLPercent`): closes all EA positions when floating loss ≥ this % of equity.
- **Position cap** (`InpMaxOpenPositions`): absolute maximum simultaneous positions on this symbol.
- **Grid-level cap** (`InpMaxGridLevels`): maximum averaging levels per side.
- **Friday close** (`InpCloseAllOnFriday`, `InpFridayCloseHour`): flattens everything before the weekend.

## Hedge logic

A single hedge is opened on the opposite side when the loser's floating loss extends past `ATR × InpHedgeTriggerATRMult` from its volume-weighted average price. The hedge lot is `loser_volume × InpHedgeLotMultiplier`, capped by `InpMaxLotCap`.

## Account requirements

- **HEDGING** account (MT5 retail-hedging margin mode). The EA refuses to run on netting accounts.
- Symbol must be selected in Market Watch (the EA auto-selects on init).

## Known limitations / honest notes

- This is a starter codebase, not a plug-and-play money printer.
- The default numbers are reasonable starting points, not optimized values. Run the Strategy Tester with real tick data for at least 3 years before going live.
- Strong, persistent trends are the natural enemy of grid strategies. The kill-switch exists for exactly this reason — respect it.
- Commissions, swaps, slippage and spread **are** included in basket P&L because `CPositionInfo.Profit() + Swap() + Commission()` is summed.

## License

MIT. Use at your own risk.
