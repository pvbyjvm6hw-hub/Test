//+------------------------------------------------------------------+
//|                                                   HedgeGridEA.mq5|
//|                            All-in-one Hedge + Grid EA for MT5    |
//|                                                                  |
//|  Features                                                        |
//|  --------                                                        |
//|    * 5 strategy profiles selectable via `InpStrategy` input:     |
//|        DUAL_HEDGE, TREND_GRID, MEAN_REVERSION, BREAKOUT, HYBRID  |
//|    * 8 symbol presets selectable via `InpSymbolPreset` that      |
//|      override the risk / grid / filter inputs at init.           |
//|    * ATR-based grid spacing                                      |
//|    * Single-hedge recovery triggered by ATR-distance threshold   |
//|    * Equity-based basket take-profit and kill-switch             |
//|    * Optional session, spread, and trend filters                 |
//|    * Optional Friday flat-close                                  |
//|                                                                  |
//|  IMPORTANT                                                       |
//|  ---------                                                       |
//|    Requires a HEDGING MT5 account (not netting). Backtest and    |
//|    forward-test on demo before deploying capital. No EA can      |
//|    guarantee "daily profits".                                    |
//|                                                                  |
//|  License: MIT (see project README)                               |
//+------------------------------------------------------------------+
#property copyright "HedgeGridEA"
#property version   "1.00"
#property strict

//--- All includes live under ./Include/ ---------------------------
#include "Include/Enums.mqh"
#include "Include/Inputs.mqh"
#include "Include/Utils.mqh"
#include "Include/Indicators.mqh"
#include "Include/FilterEngine.mqh"
#include "Include/PresetManager.mqh"
#include "Include/TradeManager.mqh"
#include "Include/RiskManager.mqh"
#include "Include/GridManager.mqh"
#include "Include/StrategyEngine.mqh"

//==================================================================//
// State                                                              //
//==================================================================//
datetime g_LastBarTime = 0;

//+------------------------------------------------------------------+
//| OnInit                                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   // 1. Ensure a hedging account (this EA will not behave on netting)
   if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)
      != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
     {
      Print("[HGEA] ERROR: This EA requires a HEDGING account.");
      return(INIT_FAILED);
     }

   // 2. Load user inputs into working globals and optionally apply a preset
   LoadInputsIntoWorking();
   const bool applied = ApplyPreset(InpSymbolPreset);
   if(applied)
      Print("[HGEA] Preset applied: ", PresetToString(InpSymbolPreset),
            " -> strategy=", StrategyToString(g_Strategy));
   else
      Print("[HGEA] Using manual inputs. strategy=", StrategyToString(g_Strategy));

   // 3. Basic input sanity
   if(g_StartingLot <= 0.0)         { Print("[HGEA] StartingLot must be > 0");          return(INIT_PARAMETERS_INCORRECT); }
   if(g_LotMultiplier < 1.0)        { Print("[HGEA] LotMultiplier must be >= 1");        return(INIT_PARAMETERS_INCORRECT); }
   if(g_MaxLotCap < g_StartingLot)  { Print("[HGEA] MaxLotCap must be >= StartingLot");  return(INIT_PARAMETERS_INCORRECT); }
   if(g_MaxGridLevels < 1)          { Print("[HGEA] MaxGridLevels must be >= 1");        return(INIT_PARAMETERS_INCORRECT); }
   if(g_MaxOpenPositions < 1)       { Print("[HGEA] MaxOpenPositions must be >= 1");     return(INIT_PARAMETERS_INCORRECT); }
   if(g_BasketTPPercent <= 0.0)     { Print("[HGEA] BasketTPPercent must be > 0");       return(INIT_PARAMETERS_INCORRECT); }
   if(g_BasketSLPercent <= 0.0)     { Print("[HGEA] BasketSLPercent must be > 0");       return(INIT_PARAMETERS_INCORRECT); }
   if(g_ATRPeriod < 2)              { Print("[HGEA] ATRPeriod must be >= 2");            return(INIT_PARAMETERS_INCORRECT); }
   if(g_GridSpacingATRMult <= 0.0)  { Print("[HGEA] GridSpacingATRMult must be > 0");    return(INIT_PARAMETERS_INCORRECT); }
   if(g_HedgeTriggerATRMult <= 0.0) { Print("[HGEA] HedgeTriggerATRMult must be > 0");   return(INIT_PARAMETERS_INCORRECT); }
   if(g_HedgeLotMultiplier < 1.0)   { Print("[HGEA] HedgeLotMultiplier must be >= 1");   return(INIT_PARAMETERS_INCORRECT); }

   // 4. Check the symbol is selected in Market Watch
   if(!SymbolSelect(_Symbol, true))
     {
      Print("[HGEA] SymbolSelect failed for ", _Symbol);
      return(INIT_FAILED);
     }

   // 5. Create indicator handles
   if(!CreateIndicatorHandles(_Symbol))
     {
      Print("[HGEA] Failed to create indicator handles");
      return(INIT_FAILED);
     }

   // 6. Trade wrapper
   InitTradeManager();

   Print("[HGEA] Init OK. symbol=", _Symbol,
         " digits=", (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS),
         " point=",  DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_POINT), 8),
         " pip=",    DoubleToString(PipSize(_Symbol), 8));
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ReleaseIndicatorHandles();
   Print("[HGEA] Deinit reason=", reason);
  }

//+------------------------------------------------------------------+
//| New-bar detector on the CURRENT chart timeframe.                 |
//+------------------------------------------------------------------+
bool IsNewBar()
  {
   datetime times[];
   if(CopyTime(_Symbol, PERIOD_CURRENT, 0, 1, times) < 1) return(false);
   if(times[0] == g_LastBarTime) return(false);
   g_LastBarTime = times[0];
   return(true);
  }

//+------------------------------------------------------------------+
//| OnTick                                                            |
//+------------------------------------------------------------------+
void OnTick()
  {
   // 1. Exit management first (runs every tick, cheap)
   if(CheckBasketExits()) return;

   // 2. Manage grid progression + hedge trigger (every tick)
   //    Only meaningful if we have open positions
   const int buys  = CountEAPositions(0);
   const int sells = CountEAPositions(1);

   if(buys > 0)
     {
      // Add more BUY grid levels (averaging down)
      TryAddGridLevel(0);
      // Hedge the BUY basket if losing too hard
      if(SideBasketProfit(0) < 0.0)
         TryOpenHedge(0);
     }
   if(sells > 0)
     {
      TryAddGridLevel(1);
      if(SideBasketProfit(1) < 0.0)
         TryOpenHedge(1);
     }

   // 3. First-entry logic: only on new bar to avoid spam
   if(!IsNewBar()) return;

   // Don't start anything new at Friday-close
   if(IsFridayClosingTime()) return;

   // Only create a first entry when there are no existing positions
   if(buys == 0 && sells == 0)
     {
      if(!SpreadOK(_Symbol)) return;

      const int vote = EvaluateEntry();
      switch(vote)
        {
         case ENTRY_BUY:
            if(CanOpenMorePositions())
               OpenMarket(true, NextGridLot(0));
            break;
         case ENTRY_SELL:
            if(CanOpenMorePositions())
               OpenMarket(false, NextGridLot(1));
            break;
         case ENTRY_BOTH:
            if(CanOpenMorePositions()) OpenMarket(true,  NextGridLot(0));
            if(CanOpenMorePositions()) OpenMarket(false, NextGridLot(1));
            break;
         case ENTRY_NONE:
         default:
            break;
        }
     }
  }
//+------------------------------------------------------------------+
