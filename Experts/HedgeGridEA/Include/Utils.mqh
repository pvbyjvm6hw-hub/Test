//+------------------------------------------------------------------+
//|                                                        Utils.mqh |
//|          Small helpers: pip/point math, normalization, logging.  |
//+------------------------------------------------------------------+
#ifndef __HGEA_UTILS_MQH__
#define __HGEA_UTILS_MQH__

#include "Inputs.mqh"

//+------------------------------------------------------------------+
//| One pip in price units.                                          |
//|  - 3 or 5 digit symbols: 1 pip = 10 points                       |
//|  - others:              1 pip =  1 point                         |
//+------------------------------------------------------------------+
double PipSize(const string symbol)
  {
   const int    digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   const double point  = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(digits == 3 || digits == 5)
      return(point * 10.0);
   return(point);
  }

//+------------------------------------------------------------------+
//| Normalize a lot size to the symbol's volume constraints          |
//+------------------------------------------------------------------+
double NormalizeLot(const string symbol, double lot)
  {
   const double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   const double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   const double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;

   if(stepLot > 0.0)
     {
      const double steps = MathFloor(lot / stepLot + 1e-10);
      lot = steps * stepLot;
     }

   // Round to the volume-step precision (typically 2 decimal digits)
   int digits = 2;
   if(stepLot >= 1.0)       digits = 0;
   else if(stepLot >= 0.1)  digits = 1;
   else if(stepLot >= 0.01) digits = 2;
   else                     digits = 3;

   return(NormalizeDouble(lot, digits));
  }

//+------------------------------------------------------------------+
//| Normalize a price to the symbol's digit count                    |
//+------------------------------------------------------------------+
double NormalizePrice(const string symbol, const double price)
  {
   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   return(NormalizeDouble(price, digits));
  }

//+------------------------------------------------------------------+
//| Is the market currently open for this symbol (by schedule)?      |
//+------------------------------------------------------------------+
bool IsTradingSessionOpen(const string symbol)
  {
   const datetime now   = TimeTradeServer();
   MqlDateTime mdt;
   TimeToStruct(now, mdt);
   const int dow = mdt.day_of_week; // 0=Sun ... 6=Sat

   datetime from, to;
   if(!SymbolInfoSessionTrade(symbol, (ENUM_DAY_OF_WEEK)dow, 0, from, to))
      return(false);

   const int nowSec  = mdt.hour * 3600 + mdt.min * 60 + mdt.sec;
   MqlDateTime f, t;
   TimeToStruct(from, f);
   TimeToStruct(to,   t);
   const int fromSec = f.hour * 3600 + f.min * 60 + f.sec;
   const int toSec   = t.hour * 3600 + t.min * 60 + t.sec;
   return(nowSec >= fromSec && nowSec < toSec);
  }

//+------------------------------------------------------------------+
//| Verbose log helper                                               |
//+------------------------------------------------------------------+
void VLog(const string msg)
  {
   if(InpVerboseLogging)
      Print("[HGEA] ", msg);
  }

#endif // __HGEA_UTILS_MQH__
//+------------------------------------------------------------------+
