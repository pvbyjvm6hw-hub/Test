//+------------------------------------------------------------------+
//|                                               StrategyEngine.mqh |
//|  Entry logic per strategy profile. All strategies return a       |
//|  direction vote: +1 = BUY, -1 = SELL, 0 = NOTHING, 2 = BOTH.     |
//+------------------------------------------------------------------+
#ifndef __HGEA_STRATEGY_ENGINE_MQH__
#define __HGEA_STRATEGY_ENGINE_MQH__

#include "Enums.mqh"
#include "Inputs.mqh"
#include "Indicators.mqh"
#include "FilterEngine.mqh"
#include "TradeManager.mqh"
#include "Utils.mqh"

//--- Entry vote values ---------------------------------------------
#define ENTRY_NONE  0
#define ENTRY_BUY   1
#define ENTRY_SELL (-1)
#define ENTRY_BOTH  2

//+------------------------------------------------------------------+
//| STRATEGY_DUAL_HEDGE: always wants both sides open.               |
//+------------------------------------------------------------------+
int Strategy_DualHedge()
  {
   return(ENTRY_BOTH);
  }

//+------------------------------------------------------------------+
//| STRATEGY_TREND_GRID: direction from trend filter.                |
//|   If the trend filter is disabled, this strategy cannot produce  |
//|   a direction and returns ENTRY_NONE. Enable the trend filter    |
//|   or switch to DUAL_HEDGE.                                       |
//+------------------------------------------------------------------+
int Strategy_TrendGrid()
  {
   if(!g_UseTrendFilter) return(ENTRY_NONE);
   const int dir = TrendDirection();
   if(dir > 0) return(ENTRY_BUY);
   if(dir < 0) return(ENTRY_SELL);
   return(ENTRY_NONE);
  }

//+------------------------------------------------------------------+
//| STRATEGY_MEAN_REVERSION: oversold => BUY, overbought => SELL.    |
//+------------------------------------------------------------------+
int Strategy_MeanReversion()
  {
   const double rsi = GetRSI();
   if(rsi < 0.0) return(ENTRY_NONE);
   double up = 0.0, lo = 0.0, mid = 0.0;
   if(!GetBollingerBands(up, lo, mid)) return(ENTRY_NONE);

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(rsi <= g_RSIOversold   && ask <= lo) return(ENTRY_BUY);
   if(rsi >= g_RSIOverbought && bid >= up) return(ENTRY_SELL);
   return(ENTRY_NONE);
  }

//+------------------------------------------------------------------+
//| STRATEGY_BREAKOUT: break of previous N-day high/low range.       |
//+------------------------------------------------------------------+
int Strategy_Breakout()
  {
   const int lookback = MathMax(1, g_BreakoutLookbackDays);
   // We need <lookback> completed daily bars, so shift 1..lookback
   double highs[], lows[];
   if(CopyHigh(_Symbol, PERIOD_D1, 1, lookback, highs) < lookback) return(ENTRY_NONE);
   if(CopyLow (_Symbol, PERIOD_D1, 1, lookback, lows)  < lookback) return(ENTRY_NONE);

   double prevHigh = highs[0], prevLow = lows[0];
   for(int i = 1; i < lookback; i++)
     {
      if(highs[i] > prevHigh) prevHigh = highs[i];
      if(lows[i]  < prevLow)  prevLow  = lows[i];
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > prevHigh) return(ENTRY_BUY);
   if(bid < prevLow)  return(ENTRY_SELL);
   return(ENTRY_NONE);
  }

//+------------------------------------------------------------------+
//| STRATEGY_HYBRID: multi-filter (trend + session + spread).        |
//|   * Session filter: must be inside configured hours              |
//|   * Spread filter:  must be under configured max                 |
//|   * Trend:          must be clearly up or down                   |
//|                                                                  |
//| If `g_UseTrendFilter` is false, HYBRID degrades to DUAL_HEDGE    |
//| so the user doesn't accidentally disable the EA by unticking     |
//| the trend filter.                                                |
//+------------------------------------------------------------------+
int Strategy_Hybrid()
  {
   if(!SessionOK()) return(ENTRY_NONE);
   if(!SpreadOK(_Symbol)) return(ENTRY_NONE);
   if(!g_UseTrendFilter) return(ENTRY_BOTH);
   const int dir = TrendDirection();
   if(dir > 0) return(ENTRY_BUY);
   if(dir < 0) return(ENTRY_SELL);
   return(ENTRY_NONE);
  }

//+------------------------------------------------------------------+
//| Dispatch to the active strategy's entry function.                |
//+------------------------------------------------------------------+
int EvaluateEntry()
  {
   switch(g_Strategy)
     {
      case STRATEGY_DUAL_HEDGE:     return(Strategy_DualHedge());
      case STRATEGY_TREND_GRID:     return(Strategy_TrendGrid());
      case STRATEGY_MEAN_REVERSION: return(Strategy_MeanReversion());
      case STRATEGY_BREAKOUT:       return(Strategy_Breakout());
      case STRATEGY_HYBRID:         return(Strategy_Hybrid());
     }
   return(ENTRY_NONE);
  }

#endif // __HGEA_STRATEGY_ENGINE_MQH__
//+------------------------------------------------------------------+
