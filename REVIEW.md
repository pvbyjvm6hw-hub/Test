# Code Review — MC_Hedge_M5 v2.03

**File:** `Bot` (committed without extension; contents are `MC_Hedge_M5_v2.03.mq5`, 1376 lines)
**Reviewed as of:** 2026-05-11 (commit `15fb85b`)
**Platform:** MetaTrader 5 / MQL5, hedging account required
**Scope:** Full source review — correctness, safety, robustness, performance, MQL5 idioms.

---

## TL;DR

The EA is **well-structured, well-commented, and defensively written**. The trade-lifecycle cache, daily-P&L event sourcing, persisted cooldown, and weekend close are all solid. The main risks are **strategy-level**, not implementation bugs:

1. A short **race window** between opening L2 and stripping L1's protection.
2. **Churn risk** — a new L1 can fire the very next bar after a basket/SL exit if the Fibo zone is still active.
3. **Martingale geometry** (`InpHedgeMultiplier = 2.0`, `InpMaxLayerLot = 1.00`) is not constrained by account-based risk; at L≥3 lot blow-up is possible if `InpMaxOrders` is raised.
4. **Points vs pips** — trailing inputs are documented in "points" and use `SYMBOL_POINT` directly, which behaves very differently across instruments (EURUSD 5-digit vs XAUUSD 2-digit). Easy to misconfigure.
5. A handful of **minor redundancies** and **dead branches**.

No issue is a showstopper; most are tuning/robustness concerns for live deployment and backtesting.

---

## Severity Legend

- **P0** — correctness/safety bug that can cause loss of capital or incorrect behavior
- **P1** — latent issue, edge-case bug, or material robustness concern
- **P2** — code-quality, style, or minor redundancy
- **INFO** — worth knowing; not a defect

---

## P0 — None

No findings at P0 severity. The loss-control primitives (emergency stop, basket SL, daily lockout, weekend close, cooldown) are all present and interact correctly.

---

## P1 — Correctness / Robustness

### P1-1. Race between L2 open and L1 SL/TP strip

**Location:** `ManageHedgeRecovery()` → `trade.Buy/Sell` then `StripL1ProtectionForBasket()`.

**Issue:** L2 is opened first; only after the server confirms the fill does the EA call `StripL1ProtectionForBasket()`. If L1 has an active trailing SL at this moment and price gaps through that SL during the same millisecond the L2 fill comes back, the server can close L1 independently — leaving the EA with a naked L2 that was sized assuming L1 is still open.

**Likelihood:** low in calm markets, non-trivial on news spikes.

**Recommended fix:** strip L1 SL/TP **before** opening L2 when `CountOpenPositionsLive() == 1`. If the `PositionModify` to strip fails, abort the hedge for this tick (do not open L2). On the next tick, retry.

```mql5
// Pseudo
if(total == 1) {
   if(!StripL1ProtectionForBasketSafe()) { log(...); return; }
}
// then open L2
```

### P1-2. Fresh-zone entry re-arm is missing

**Location:** `DetectFiboSignal()` + `ManageEntry()`.

**Issue:** After a basket SL + cooldown expires, if price is still in the Fibo zone, the EA will re-enter on the very next M5 bar. There is no "zone must be exited and re-entered" latch. This can cause serial losses on range-bound chop that keeps printing closes inside the zone.

**Recommended fix:** Add a simple one-shot latch: require that since the last L1 was opened in a zone, price has printed a bar whose close is *outside* the zone before re-arming.

### P1-3. "Points" semantics vary per instrument

**Location:** `CheckSingleTradeExits()` — `pip = g_pointValue = SYMBOL_POINT`.

**Issue:** The inputs are labeled "points" and the code uses `SYMBOL_POINT` directly, so they *are* points. But on a 5-digit EURUSD feed `30 points = 3 pips`, while on a 2-digit XAUUSD feed `30 points = 0.30 USD price` — these are behaviorally different orders of magnitude. A user who tunes on EURUSD and then runs on XAUUSD with unchanged inputs will get unexpected behavior.

**Recommended fix:** document the "points" convention prominently in the input group header; OR add a `_Digits`-aware pip converter (`pip = g_pointValue * (g_digits == 3 || g_digits == 5 ? 10 : 1)`) and document as pips.

### P1-4. `InpMaxOrders > 2` enables unbounded martingale

**Location:** `CalculateLayerLot()` + `ManageHedgeRecovery()`.

**Issue:** With the default `InpHedgeMultiplier = 2.0`, lot sequence is `0.01 → 0.02 → 0.04 → 0.08 → 0.16 → 0.32 → 0.64 → 1.00 (capped)`. At `InpMaxOrders = 10` and leveraged instruments this can overwhelm margin well before the lot cap takes effect, and the "basket TP $25" target becomes increasingly unreachable as the basket grows in USD risk.

**Recommended fix:**
- Default `InpMaxOrders` to 2 (already is) and clamp harder in `ValidateInputs` (`> 4` should warn).
- Make `InpBasketTP_USD` scale with layer count (e.g., `BasketTP × layer_count`).
- Add a runtime check: if projected next-layer margin > free margin × safety_factor, skip the hedge.

### P1-5. `CheckSingleTradeExits()` falls through to trailing after a failed close

**Location:** Single TP path:
```mql5
if(pnl >= InpSingleTP_USD) {
   if(trade.PositionClose(ticket)) { ...; return true; }
   LogTradeError("Single TP close");
   // falls through to trailing block below
}
```

**Issue:** If `PositionClose` fails (requote, server error, freeze), control drops into the trailing-stop block and may try to `PositionModify` a position that the broker is in the middle of closing. Unlikely to be harmful, but it is a redundant request that can generate misleading errors.

**Recommended fix:** `return false;` after `LogTradeError("Single TP close")` — retry the close next tick rather than interleaving with trail updates.

### P1-6. `g_currentBasketLot` branch in `CalculateLayerLot` is effectively dead

**Location:** `CalculateLayerLot(1, 0.0)`.

**Issue:** `g_currentBasketLot` is only ever set by `ExecuteInitialEntry` *immediately before* calling `CalculateLayerLot(1, 0.0)`. Outside of that call site, for L1 it is always zero. The `(g_currentBasketLot > 0.0)` branch cannot realistically take the non-dynamic path. Not a bug — just confusing.

**Recommended fix:** either always use `CalculateDynamicLot()` for L1, or remove `g_currentBasketLot` if nothing else uses it. (It is referenced in the dashboard debug lines but nothing actionable.)

### P1-7. Trading hours cannot wrap midnight

**Location:** `IsTradingTime()`, `ValidateInputs`.

**Issue:** Validation requires `InpStartHour < InpEndHour`. This rules out legitimate overnight sessions (e.g., 22:00–06:00 for Asian-session range plays).

**Recommended fix:** support wrap-around:
```mql5
bool IsTradingTime() {
   MqlDateTime t; TimeCurrent(t);
   if(InpStartHour < InpEndHour)
      return (t.hour >= InpStartHour && t.hour < InpEndHour);
   else
      return (t.hour >= InpStartHour || t.hour < InpEndHour);
}
```
and drop the `InpStartHour < InpEndHour` validation (still keep the 0–23 range check).

### P1-8. Tester requires hedging mode — easy to forget

**Location:** `OnInit()` checks `ACCOUNT_MARGIN_MODE_RETAIL_HEDGING` and fails with an `Alert`.

**Issue:** Strategy Tester defaults to netting. Users will get a silent init-fail on the first run unless they change the tester account setting. This is correct behavior but a common footgun.

**Recommended fix:** add a `Print` line in OnInit explicitly telling the user how to enable hedging in the tester (Options → Tester → Account type = Hedge).

### P1-9. Basket TP is a net-USD target that interacts non-obviously with lot geometry

**Location:** `CheckBasketExits()`.

**Issue:** With L1 = 0.01 and L2 = 0.02 (opposite direction), net exposure is 0.01 lot in the L2 direction. For the basket to profit +$25, price must move in the L2 direction by enough USD to beat L1's accumulated loss + $25. Users who tune `InpBasketTP_USD` without understanding this can set targets that are mathematically unreachable for the given ATR/spread environment.

**Recommended fix:** Document this in the input group comment. In `OnInit`, log a "breakeven-to-TP expected points" estimate using current ATR and lot sizes, so the user sees whether their target is realistic.

### P1-10. Hedge direction ignores `InpDirFilter`

**Location:** `ManageHedgeRecovery()`.

**Issue:** `InpDirFilter = DIR_BUY_ONLY` restricts L1 to BUY only, but L2 still flips to SELL. Users who set DIR_BUY_ONLY for a reason (e.g., long-only bias) may be surprised.

**Recommended fix:** either document clearly ("the filter restricts L1 direction only; recovery legs always flip"), or gate hedge entries by `InpDirFilter` too.

---

## P2 — Code Quality / Minor Issues

### P2-1. `#property strict` is a no-op in MQL5

It is an MQL4 directive. Harmless but misleading. Remove.

### P2-2. Redundant spread check

`ManageHedgeRecovery()` re-checks `IsSpreadAcceptable()` even though `OnTick()` already gated on it. Not a bug; the second check is defensive. Can be removed.

### P2-3. `IsFridayWeekendCloseTime` guards against Saturday/Sunday, but MT5 delivers no ticks on the weekend anyway. Dead branch. Harmless.

### P2-4. `g_cacheValid` is set to true but never read

Dead variable. Either wire it into a "cache built this tick?" gate or remove.

### P2-5. `LogTradeError` ignores errors when `InpVerboseLogging` is off

For a live EA, trade errors should be logged even with verbose off (they are rare but important). Consider splitting into `LogSignal(...)` (verbose-gated) and `LogError(...)` (always logged).

### P2-6. Inconsistent fill handling on L1 close

After `trade.PositionClose(ticket)` for single-TP succeeds, state is reset. But if the close partially fills (rare for a CFD but possible), the code doesn't re-verify. Edge case.

### P2-7. Magic-number persistence of cooldown

`g_cooldownGV = "MC_HEDGE_M5_CD_<magic>"` — good. But this is a global terminal variable, so it persists across chart restarts for the same magic. If the user re-uses the same magic on a different symbol, both would share the cooldown. Minor — document.

### P2-8. `OnInit` log lines are verbose (~10 lines)

Fine in backtest, noisy in production. Consider gating behind `InpVerboseLogging`.

### P2-9. Dashboard iterates `ObjectsTotal(0)` on every DeleteDashboard

Linear scan of all chart objects. Not a performance issue at normal chart-object counts, but O(n) per chart-timeframe change.

### P2-10. No `OnChartEvent` handler

Dashboard is display-only; this is fine. Flagging only in case you want click-to-close buttons later.

---

## INFO — Observations (not defects)

- **`OnTradeTransaction`-driven daily P&L** is the right architecture; iterating history once per out-deal rather than every tick.
- **Persisted cooldown via `GlobalVariable`** survives recompile/reattach — nice.
- **ATR×Mult hedge trigger** is more robust than a fixed-points grid; good choice.
- **ADX `rising` confirmation for hedge entry** is a reasonable filter — avoids mean-reversion hedges.
- **`StripL1ProtectionForBasket`** is the correct policy once basket is active: the basket TP/SL supersedes per-leg protection.
- **High-watermark trailing** (peak bid/ask) is correct; does not trail backwards.
- **All trade operations** are funneled through `CTrade`, with proper retcode inspection via `LogTradeError`.
- **Magic number and symbol filters** are applied consistently in every position/deal iteration. Good hygiene.

---

## Suggested Minimal Patch List (in priority order)

1. **[P1-1]** Reorder: strip L1 protection **before** opening L2; abort hedge if strip fails.
2. **[P1-2]** Add fresh-zone re-arm latch to prevent back-to-back L1s in the same zone.
3. **[P1-5]** `return false` after a failed `PositionClose` on single-TP.
4. **[P1-7]** Support overnight-wrap trading hours.
5. **[P1-10]** Decide and document: does `InpDirFilter` apply to hedge legs? Gate if yes.
6. **[P1-4]** Tighten `InpMaxOrders` validation; add margin-based safety check before each hedge.
7. **[P1-8]** Log "enable hedging mode in tester" hint on init-fail.
8. **[P2-1, P2-4]** Remove `#property strict` and unused `g_cacheValid`.

Each of the above is a localized, low-risk change. None change the core strategy.

---

## Version-Tracking Suggestion

Rename commit `Bot` → `MC_Hedge_M5.mq5`. Then structure future versions as:

```
Test/
├── MC_Hedge_M5.mq5          <-- current live
├── CHANGELOG.md              <-- versioned changes
├── REVIEW.md                 <-- this file
└── BACKTEST.md               <-- backtest plan / results
```

So GitHub renders MQL5 syntax and history stays one-file-linear.
