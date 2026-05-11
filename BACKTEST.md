# Backtest Plan — MC_Hedge_M5 v2.03

**Target:** produce a defensible, reproducible evaluation of MC_Hedge_M5 v2.03 under realistic conditions, then converge on an input profile that is robust across time windows and instruments.

This document is a **plan**, not results. It defines the tester setup, metrics, parameter sweeps, and acceptance criteria so that any run can be replayed end-to-end.

---

## 1. Tester Configuration

| Setting | Value | Reason |
|---|---|---|
| Platform | MetaTrader 5 build 4150+ | Needed for `TESTER_EVERY_TICK_BASED_ON_REAL_TICKS` and MQL5 hedging semantics |
| Account type | **Hedge** | EA fails init on netting accounts by design |
| Symbol | XAUUSD primary; EURUSD / GBPUSD for cross-instrument robustness | M5 strategy; these are the common MC-Hedge deployment targets |
| Timeframe | M5 | Fibo and ADX both read M5; tester must drive at M5 or lower |
| Modeling | **Every tick based on real ticks** | Hedge triggering is tick-sensitive; OHLC/1-minute modeling will produce misleading results |
| Deposit | $1000 | Matches typical prop / retail starting balance for 0.01-lot sizing |
| Leverage | 1:100 | Conservative default |
| Spread | **Variable (from real ticks)** | Fixed spread understates cost during news |
| Optimization | **Genetic** for coarse; **Slow complete** for fine | Two-phase — reduces runtime |
| Criterion | Balance + max Profit Factor (custom) | Avoid pure balance-max optimization; penalize low PF |

**One-off sanity test first:** 6-month run at default inputs on XAUUSD M5 before touching optimization. Purpose: confirm the EA boots in the tester, hedging mode is correct, and at least a handful of baskets form.

---

## 2. Date Windows

Split into **in-sample (IS)** / **out-of-sample (OOS)** blocks for walk-forward:

| Block | Window | Role |
|---|---|---|
| IS-1 | 2023-01-01 → 2023-12-31 | Optimization |
| OOS-1 | 2024-01-01 → 2024-06-30 | OOS validation |
| IS-2 | 2024-07-01 → 2025-06-30 | Re-optimization |
| OOS-2 | 2025-07-01 → 2026-04-30 | Final walk-forward |

Adjust windows to whatever your broker's tick-data availability provides. The key invariant: **never touch OOS windows during optimization.**

---

## 3. Metrics (tracked per run)

Primary (must report for every run):

- **Net Profit (USD)**
- **Profit Factor** — target ≥ 1.30
- **Max Drawdown (% of balance)** — target ≤ 25%
- **Recovery Factor** (net profit / max DD $) — target ≥ 2.0
- **Total Trades** — need ≥ 100 for statistical weight
- **Avg Trade ($)** — must exceed commission + avg spread cost
- **Win % (baskets)** and **Win % (single-trade L1 closes)** separately
- **Basket activation rate** (baskets / total L1 openings) — shows how often hedge fires

Secondary:

- **Sharpe Ratio** (annualized)
- **Longest losing streak** — should be ≤ 8 baskets
- **Max consecutive basket-SL hits** — if > 3, cooldown tuning is off
- **Avg basket life (bars)** — for basket timing analysis
- **Avg $ per basket** and **Avg basket P&L @ close**

Reject any run that:
- has fewer than 50 L1 entries, OR
- has PF < 1.10, OR
- has a single basket-SL > Basket SL limit (indicates emergency-stop misfire).

---

## 4. Optimization Phases

Optimize in **three separate stages** — do NOT optimize all inputs simultaneously. Each stage holds the other groups constant, then passes its best profile to the next stage.

### Stage A — Entry Quality (Fibo + ADX)

Hold constant: everything in exits, hedge, and risk.

| Input | Range | Step |
|---|---|---|
| `InpFiboPeriod` | 30 → 80 | 10 |
| `InpFiboUpperLevel` | 0.236 → 0.500 | 0.1 |
| `InpFiboLowerLevel` | 0.500 → 0.786 | 0.1 |
| `InpADX_Min` | 15 → 30 | 2 |
| `InpADX_Period` | 10 → 20 | 2 |

Filter constraint: `InpFiboUpperLevel < InpFiboLowerLevel` (enforced by `ValidateInputs`).

**Output:** top 10 IS-1 profiles by PF. Forward-test each on OOS-1. Select the profile whose PF degrades ≤ 20% from IS to OOS.

### Stage B — Single-Trade Exits

Freeze Stage A winner.

| Input | Range | Step |
|---|---|---|
| `InpSingleTP_USD` | 4.0 → 20.0 | 2.0 |
| `InpSingleTrailStart` | 10 → 60 | 10 |
| `InpSingleTrailStop` | 20 → 80 | 10 |
| `InpSingleTrailStep` | 5 → 30 | 5 |
| `InpSingleUseTrailing` | true / false | - |

**Watch-outs:**
- If trailing is ON but TP is too tight, trailing never engages (TP hits first). Expected-value charts will show a flat region at low TP.
- `InpSingleTrailStart >= (InpSingleTP_USD in points equivalent)` creates a degenerate trailing-inactive region.

### Stage C — Hedge Geometry

Freeze Stages A and B winners.

| Input | Range | Step |
|---|---|---|
| `InpHedgeATRMult` | 0.75 → 3.00 | 0.25 |
| `InpHedgeATR_Period` | 10 → 20 | 2 |
| `InpHedgeMultiplier` | 1.5 → 2.5 | 0.25 |
| `InpHedgeRequireTrend` | true / false | - |
| `InpBasketTP_USD` | 10 → 50 | 5 |
| `InpBasketSL_USD` | 40 → 150 | 10 |
| `InpCooldownMinutes` | 15 → 120 | 15 |

**Ratios to honor:**
- `InpBasketSL_USD ≥ 2 × InpBasketTP_USD` — standard hedge asymmetry.
- `InpEmergencyStop ≥ 1.5 × InpBasketSL_USD` — kill-switch gap.
- `InpMaxLayerLot ≥ InpLotSize × InpHedgeMultiplier^(InpMaxOrders-1)` — otherwise the cap chokes normal basket growth.

### (Optional) Stage D — Direction Bias

If IS shows strong asymmetry (e.g., long-only has higher PF on XAUUSD during uptrend year):

- `InpDirFilter` ∈ {`DIR_BOTH`, `DIR_BUY_ONLY`, `DIR_SELL_ONLY`}

Warning: direction bias rarely generalizes across years. Keep `DIR_BOTH` unless OOS confirms.

---

## 5. Walk-Forward Schema

Pattern: **train → validate → reject-or-accept → roll forward.**

```
  IS-1  ──▶  top 10 profiles  ──▶  OOS-1 validation  ──▶  1 winner
                                                              │
                                                              ▼
  IS-2  ──▶  re-optimize around winner (tighter ranges)  ──▶  OOS-2 validation
```

Accept the final profile only if:

1. OOS-2 PF ≥ 0.80 × IS-2 PF (<20% degradation).
2. Max-DD OOS-2 ≤ 1.25 × Max-DD IS-2 (<25% inflation).
3. No single OOS month loses more than 1.5 × the worst IS month.

---

## 6. Robustness Perturbations (run AFTER walk-forward passes)

These protect against "optimum on a knife-edge":

1. **Spread shock** — re-run OOS-2 with `InpMaxSpreadPts` cut in half and the broker's "current" spread profile. Degradation > 15% = fragile.
2. **Slippage** — bump `InpSlippage` to 40 and re-run. Degradation > 10% = too tight.
3. **Clock shift** — shift start/end hour by ±1. Should be near-invariant; large shifts reveal session-dependence overfitting.
4. **±10% neighbors** — re-run with each numeric input at ±10%. Plot heatmap of Net Profit. The winner should be a broad basin, not a spike.
5. **Symbol transfer** — run the same profile on a related instrument (XAUUSD → XAGUSD, EURUSD → GBPUSD). Is the EA strategy-robust or symbol-overfit?

---

## 7. Ordering of Basket-Math Sanity

Before the first optimization run, verify by hand that the *default* inputs yield a recoverable basket:

1. Pick a recent adverse move on the live chart: e.g., XAUUSD M5 ATR = 2.50, drop 20 pts from entry.
2. L1 BUY 0.01 at $1950.00. Price drops to $1945.25 → L1 loss ≈ $4.75.
3. Hedge triggers at 1.5 × ATR = 3.75 pts drop (from L1). L2 SELL 0.02 at $1946.25.
4. Need basket TP $25 ⇒ L2 gain − L1 loss = 25. Solve for target price T:
   - L1 loss = (1950 − T) × 0.01 × 100 = (1950 − T)
   - L2 gain = (1946.25 − T) × 0.02 × 100 = 2 × (1946.25 − T)
   - Set: 2(1946.25 − T) − (1950 − T) = 25 → 3892.5 − 2T − 1950 + T = 25 → −T = −1917.5 → T = 1917.5
   - That's a further $28.75 drop from L2 entry. Feasible on XAUUSD M5? Historically yes, but not every basket.

Repeat for your target symbol before starting optimization. If the target T is beyond a plausible M5 move, your Basket TP is unreachable and the optimizer will "learn" to never let baskets form.

---

## 8. Logging & Output Contract

To make runs comparable, every tester run should produce:

- `report.html` (MT5 default) — save in a dated folder.
- A CSV of every deal (exported from the tester) — for custom metrics.
- The **input profile** as a `.set` file, saved in the same folder.
- A `run_notes.md` with: date, intent, parent profile, one-line conclusion.

Folder layout suggestion:
```
backtests/
├── 2026-05-11-stageA-xauusd/
│   ├── inputs.set
│   ├── report.html
│   ├── deals.csv
│   └── run_notes.md
├── 2026-05-12-stageB-xauusd/
│   └── ...
```

---

## 9. Known Interactions to Watch

From REVIEW.md, during backtest specifically:

- **P1-2 (fresh-zone re-arm missing):** expect "serial L1" runs after basket SL. These will look like long losing streaks in the tester. Consider patching the re-arm before committing to a profile.
- **P1-3 (points vs pips):** if comparing EURUSD runs to XAUUSD runs, **do not** carry over the trail/TP inputs unchanged — recalibrate.
- **P1-9 (basket-math reachability):** verify Stage C results make geometric sense (see §7). A profile with Basket TP=$25 that never fires a basket close will look excellent on balance but has no real hedge edge.

---

## 10. Acceptance Criteria (go-live gate)

Do **not** move from tester to demo, or demo to live, without:

- Two consecutive quarters of forward testing (demo or real ticks) confirming OOS-2 metrics within ±20%.
- At least one news-heavy week (NFP, FOMC) survived without basket SL runaway.
- Manual review of the 20 worst baskets — no "stuck state" bugs (EA failing to close, stranded L2, etc.).
- Fix or explicit acknowledgement of P1-1 (open/strip race) before going live at >0.10 lot.

---

## 11. Next Actions (ordered)

1. Fix P1-5 (`return false` on close fail) and P1-8 (tester hint) — zero strategy impact, land first.
2. Patch P1-1 (strip-before-open) — required for safe live, recommended for realistic backtest.
3. Patch P1-2 (fresh-zone re-arm) — will materially change backtest results; decide whether to include before Stage A.
4. Run baseline sanity test (§1 last paragraph).
5. Begin Stage A optimization on IS-1.

Each step produces a commit and/or a backtest report; the file structure in §8 keeps them reproducible.
