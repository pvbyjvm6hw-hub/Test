//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh |
//|   Basket TP, kill-switch, Friday close, position-count cap.     |
//+------------------------------------------------------------------+
#ifndef __HGEA_RISK_MANAGER_MQH__
#define __HGEA_RISK_MANAGER_MQH__

#include "Inputs.mqh"
#include "Utils.mqh"
#include "TradeManager.mqh"
#include "FilterEngine.mqh"

//+------------------------------------------------------------------+
//| Check basket TP / SL relative to account equity.                 |
//| Returns true if the basket was closed.                           |
//+------------------------------------------------------------------+
bool CheckBasketExits()
  {
   const int open = CountEAPositions(-1);
   if(open == 0) return(false);

   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0) return(false);

   const double profit    = TotalEABasketProfit();
   const double tpMoney   = equity * (g_BasketTPPercent / 100.0);
   const double slMoney   = equity * (g_BasketSLPercent / 100.0);

   if(profit >= tpMoney && tpMoney > 0.0)
     {
      CloseAllEAPositions(StringFormat("Basket TP reached (%.2f >= %.2f)", profit, tpMoney));
      return(true);
     }

   if(profit <= -slMoney && slMoney > 0.0)
     {
      CloseAllEAPositions(StringFormat("KILL-SWITCH: loss %.2f <= -%.2f (%.2f%% equity)",
                                       profit, slMoney, g_BasketSLPercent));
      return(true);
     }

   if(IsFridayClosingTime())
     {
      CloseAllEAPositions("Friday weekend-close");
      return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Hard cap on the total number of EA positions.                    |
//+------------------------------------------------------------------+
bool CanOpenMorePositions()
  {
   return(CountEAPositions(-1) < g_MaxOpenPositions);
  }

//+------------------------------------------------------------------+
//| Cap on grid levels on a single side.                             |
//|   side: 0=buy, 1=sell                                            |
//+------------------------------------------------------------------+
bool CanAddGridLevel(const int side)
  {
   return(CountEAPositions(side) < g_MaxGridLevels);
  }

//+------------------------------------------------------------------+
//| Next grid lot size (based on level count already on that side).  |
//+------------------------------------------------------------------+
double NextGridLot(const int side)
  {
   const int level = CountEAPositions(side); // 0 for first
   double lot = g_StartingLot;
   for(int i = 0; i < level; i++)
      lot *= g_LotMultiplier;
   if(lot > g_MaxLotCap) lot = g_MaxLotCap;
   return(NormalizeLot(_Symbol, lot));
  }

#endif // __HGEA_RISK_MANAGER_MQH__
//+------------------------------------------------------------------+
