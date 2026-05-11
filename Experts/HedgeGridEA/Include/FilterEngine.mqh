//+------------------------------------------------------------------+
//|                                                 FilterEngine.mqh |
//|  Spread / session / trend filters shared by all strategies.      |
//+------------------------------------------------------------------+
#ifndef __HGEA_FILTER_ENGINE_MQH__
#define __HGEA_FILTER_ENGINE_MQH__

#include "Inputs.mqh"
#include "Utils.mqh"
#include "Indicators.mqh"

//+------------------------------------------------------------------+
//| True if the current spread is within the configured limit.      |
//+------------------------------------------------------------------+
bool SpreadOK(const string symbol)
  {
   if(!g_UseSpreadFilter) return(true);
   const double pip        = PipSize(symbol);
   if(pip <= 0.0) return(true);
   const double ask        = SymbolInfoDouble(symbol, SYMBOL_ASK);
   const double bid        = SymbolInfoDouble(symbol, SYMBOL_BID);
   const double spreadPips = (ask - bid) / pip;
   if(spreadPips > g_MaxSpreadPips)
     {
      VLog(StringFormat("Spread blocked: %.1f pips > %.1f", spreadPips, g_MaxSpreadPips));
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| True if the current server hour lies inside the trading session. |
//+------------------------------------------------------------------+
bool SessionOK()
  {
   if(!g_UseSessionFilter) return(true);
   MqlDateTime mdt;
   TimeToStruct(TimeTradeServer(), mdt);
   if(mdt.day_of_week == 0 || mdt.day_of_week == 6) // Sun/Sat
      return(false);
   const int h = mdt.hour;
   if(g_SessionStartHour <= g_SessionEndHour)
      return(h >= g_SessionStartHour && h < g_SessionEndHour);
   // Session crosses midnight (e.g. 22..5)
   return(h >= g_SessionStartHour || h < g_SessionEndHour);
  }

//+------------------------------------------------------------------+
//| Trend direction on the trend timeframe EMA cross.                |
//|   1  = uptrend (fast > slow)                                     |
//|  -1  = downtrend (fast < slow)                                   |
//|   0  = unknown / flat (or indicator not ready)                   |
//+------------------------------------------------------------------+
int TrendDirection()
  {
   if(!g_UseTrendFilter) return(0);
   double fast = 0.0, slow = 0.0;
   if(!GetEMAValues(fast, slow)) return(0);
   if(fast > slow) return(1);
   if(fast < slow) return(-1);
   return(0);
  }

//+------------------------------------------------------------------+
//| Close all on Friday evening?                                     |
//+------------------------------------------------------------------+
bool IsFridayClosingTime()
  {
   if(!InpCloseAllOnFriday) return(false);
   MqlDateTime mdt;
   TimeToStruct(TimeTradeServer(), mdt);
   return(mdt.day_of_week == 5 && mdt.hour >= InpFridayCloseHour);
  }

#endif // __HGEA_FILTER_ENGINE_MQH__
//+------------------------------------------------------------------+
