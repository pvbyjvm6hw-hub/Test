//+------------------------------------------------------------------+
//|                                                 TradeManager.mqh |
//|   Thin wrapper over CTrade + position iteration helpers.         |
//+------------------------------------------------------------------+
#ifndef __HGEA_TRADE_MANAGER_MQH__
#define __HGEA_TRADE_MANAGER_MQH__

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/SymbolInfo.mqh>
#include "Inputs.mqh"
#include "Utils.mqh"

CTrade        g_Trade;
CPositionInfo g_Pos;

//+------------------------------------------------------------------+
//| Configure the CTrade object at startup.                          |
//+------------------------------------------------------------------+
void InitTradeManager()
  {
   g_Trade.SetExpertMagicNumber(InpMagicNumber);
   g_Trade.SetDeviationInPoints(20);
   g_Trade.SetTypeFillingBySymbol(_Symbol);
   g_Trade.SetMarginMode();
   // CTrade.LogLevel() is available in recent MT5 builds; we keep CTrade
   // quiet and do our own structured logging via VLog().
   g_Trade.LogLevel(LOG_LEVEL_ERRORS);
  }

//+------------------------------------------------------------------+
//| Count open positions for this EA on this symbol (optional side). |
//| side = -1 -> all; 0 -> buys; 1 -> sells.                         |
//+------------------------------------------------------------------+
int CountEAPositions(const int side = -1)
  {
   int total = 0;
   const int count = PositionsTotal();
   for(int i = 0; i < count; i++)
     {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Symbol() != _Symbol) continue;
      if(g_Pos.Magic()  != (long)InpMagicNumber) continue;
      if(side == 0 && g_Pos.PositionType() != POSITION_TYPE_BUY)  continue;
      if(side == 1 && g_Pos.PositionType() != POSITION_TYPE_SELL) continue;
      total++;
     }
   return(total);
  }

//+------------------------------------------------------------------+
//| Sum of floating P&L across all EA positions on this symbol.     |
//+------------------------------------------------------------------+
double TotalEABasketProfit()
  {
   double p = 0.0;
   const int count = PositionsTotal();
   for(int i = 0; i < count; i++)
     {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Symbol() != _Symbol) continue;
      if(g_Pos.Magic()  != (long)InpMagicNumber) continue;
      p += g_Pos.Profit() + g_Pos.Swap() + g_Pos.Commission();
     }
   return(p);
  }

//+------------------------------------------------------------------+
//| Side-specific floating P&L, and largest losing position info.    |
//+------------------------------------------------------------------+
double SideBasketProfit(const int side)
  {
   double p = 0.0;
   const int count = PositionsTotal();
   for(int i = 0; i < count; i++)
     {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Symbol() != _Symbol) continue;
      if(g_Pos.Magic()  != (long)InpMagicNumber) continue;
      if(side == 0 && g_Pos.PositionType() != POSITION_TYPE_BUY)  continue;
      if(side == 1 && g_Pos.PositionType() != POSITION_TYPE_SELL) continue;
      p += g_Pos.Profit() + g_Pos.Swap() + g_Pos.Commission();
     }
   return(p);
  }

//+------------------------------------------------------------------+
//| Total volume on one side for this EA on this symbol.             |
//+------------------------------------------------------------------+
double SideVolume(const int side)
  {
   double v = 0.0;
   const int count = PositionsTotal();
   for(int i = 0; i < count; i++)
     {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Symbol() != _Symbol) continue;
      if(g_Pos.Magic()  != (long)InpMagicNumber) continue;
      if(side == 0 && g_Pos.PositionType() != POSITION_TYPE_BUY)  continue;
      if(side == 1 && g_Pos.PositionType() != POSITION_TYPE_SELL) continue;
      v += g_Pos.Volume();
     }
   return(v);
  }

//+------------------------------------------------------------------+
//| Average open price (volume weighted) on one side.                |
//+------------------------------------------------------------------+
double SideAvgPrice(const int side)
  {
   double sumPV = 0.0, sumV = 0.0;
   const int count = PositionsTotal();
   for(int i = 0; i < count; i++)
     {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Symbol() != _Symbol) continue;
      if(g_Pos.Magic()  != (long)InpMagicNumber) continue;
      if(side == 0 && g_Pos.PositionType() != POSITION_TYPE_BUY)  continue;
      if(side == 1 && g_Pos.PositionType() != POSITION_TYPE_SELL) continue;
      sumPV += g_Pos.PriceOpen() * g_Pos.Volume();
      sumV  += g_Pos.Volume();
     }
   if(sumV <= 0.0) return(0.0);
   return(sumPV / sumV);
  }

//+------------------------------------------------------------------+
//| Last (most recent) position's open price & volume on a side.    |
//| Returns false if nothing is open on that side.                  |
//+------------------------------------------------------------------+
bool GetLastSidePosition(const int side, double &openPrice, double &volume, datetime &openTime)
  {
   openPrice = 0.0;
   volume    = 0.0;
   openTime  = 0;
   datetime latest = 0;

   const int count = PositionsTotal();
   for(int i = 0; i < count; i++)
     {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Symbol() != _Symbol) continue;
      if(g_Pos.Magic()  != (long)InpMagicNumber) continue;
      if(side == 0 && g_Pos.PositionType() != POSITION_TYPE_BUY)  continue;
      if(side == 1 && g_Pos.PositionType() != POSITION_TYPE_SELL) continue;

      const datetime t = (datetime)g_Pos.Time();
      if(t > latest)
        {
         latest    = t;
         openPrice = g_Pos.PriceOpen();
         volume    = g_Pos.Volume();
         openTime  = t;
        }
     }
   return(latest > 0);
  }

//+------------------------------------------------------------------+
//| Close every position this EA owns on the current symbol.         |
//| Returns number of successful closes.                             |
//+------------------------------------------------------------------+
int CloseAllEAPositions(const string reason)
  {
   int closed = 0;
   // Iterate top-down, because closing changes the index
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!g_Pos.SelectByIndex(i)) continue;
      if(g_Pos.Symbol() != _Symbol) continue;
      if(g_Pos.Magic()  != (long)InpMagicNumber) continue;
      const ulong ticket = g_Pos.Ticket();
      if(g_Trade.PositionClose(ticket))
         closed++;
      else
         VLog("Close #" + IntegerToString((long)ticket) +
              " failed, err=" + IntegerToString(GetLastError()) +
              " retcode=" + IntegerToString((int)g_Trade.ResultRetcode()));
     }
   if(closed > 0) VLog(StringFormat("Closed %d position(s). Reason: %s", closed, reason));
   return(closed);
  }

//+------------------------------------------------------------------+
//| Open a BUY or SELL at market with the given volume.              |
//+------------------------------------------------------------------+
bool OpenMarket(const bool isBuy, const double rawLot)
  {
   const double lot = NormalizeLot(_Symbol, rawLot);
   if(lot <= 0.0)
     {
      VLog("OpenMarket: normalized lot is 0");
      return(false);
     }
   const double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                              : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(price <= 0.0)
     {
      VLog("OpenMarket: invalid price");
      return(false);
     }

   bool ok;
   if(isBuy)
      ok = g_Trade.Buy(lot, _Symbol, price, 0.0, 0.0, InpOrderComment);
   else
      ok = g_Trade.Sell(lot, _Symbol, price, 0.0, 0.0, InpOrderComment);

   if(!ok)
      VLog(StringFormat("%s %.2f failed, err=%d retcode=%u",
                        isBuy ? "BUY" : "SELL", lot,
                        GetLastError(), g_Trade.ResultRetcode()));
   else
      VLog(StringFormat("%s %.2f @ %.5f ok", isBuy ? "BUY" : "SELL", lot, price));
   return(ok);
  }

#endif // __HGEA_TRADE_MANAGER_MQH__
//+------------------------------------------------------------------+
