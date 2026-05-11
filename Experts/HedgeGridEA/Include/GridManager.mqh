//+------------------------------------------------------------------+
//|                                                  GridManager.mqh |
//|   Adds new grid levels on one side + opens hedge when warranted. |
//+------------------------------------------------------------------+
#ifndef __HGEA_GRID_MANAGER_MQH__
#define __HGEA_GRID_MANAGER_MQH__

#include "Inputs.mqh"
#include "Utils.mqh"
#include "TradeManager.mqh"
#include "Indicators.mqh"
#include "RiskManager.mqh"

//+------------------------------------------------------------------+
//| Try to add another grid level on 'side' (0=buy, 1=sell).         |
//| Grid level opens when price has moved against the last entry    |
//| by at least (ATR * g_GridSpacingATRMult).                        |
//| Returns true if an order was placed.                             |
//+------------------------------------------------------------------+
bool TryAddGridLevel(const int side)
  {
   if(!CanOpenMorePositions()) return(false);
   if(!CanAddGridLevel(side))  return(false);
   if(!SpreadOK(_Symbol))      return(false);

   const double atr = GetATR();
   if(atr <= 0.0) return(false);

   const double step = atr * g_GridSpacingATRMult;
   if(step <= 0.0) return(false);

   double lastPrice = 0.0, lastLot = 0.0;
   datetime lastT   = 0;
   if(!GetLastSidePosition(side, lastPrice, lastLot, lastT))
     {
      // No existing position on this side -> open the first one at market
      return(OpenMarket(side == 0, NextGridLot(side)));
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool shouldAdd = false;

   if(side == 0) // BUY -> add when price dropped by >= step from last fill
      shouldAdd = (ask <= lastPrice - step);
   else          // SELL -> add when price rose by >= step from last fill
      shouldAdd = (bid >= lastPrice + step);

   if(!shouldAdd) return(false);

   return(OpenMarket(side == 0, NextGridLot(side)));
  }

//+------------------------------------------------------------------+
//| Open a hedge on the opposite side if the loss on 'loserSide'     |
//| has exceeded (ATR * g_HedgeTriggerATRMult) in price terms.       |
//| Hedge lot = SideVolume(loserSide) * g_HedgeLotMultiplier, capped.|
//| Returns true if the hedge was opened.                            |
//+------------------------------------------------------------------+
bool TryOpenHedge(const int loserSide)
  {
   if(!CanOpenMorePositions()) return(false);
   const int hedgeSide = (loserSide == 0) ? 1 : 0;
   if(CountEAPositions(hedgeSide) > 0) return(false); // only one hedge

   const double atr = GetATR();
   if(atr <= 0.0) return(false);

   const double triggerDist = atr * g_HedgeTriggerATRMult;
   if(triggerDist <= 0.0) return(false);

   const double avg = SideAvgPrice(loserSide);
   if(avg <= 0.0) return(false);

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool shouldHedge = false;
   if(loserSide == 0) // BUY basket is losing -> price below avg
      shouldHedge = (bid <= avg - triggerDist);
   else               // SELL basket is losing -> price above avg
      shouldHedge = (ask >= avg + triggerDist);

   if(!shouldHedge) return(false);

   double hedgeLot = SideVolume(loserSide) * g_HedgeLotMultiplier;
   if(hedgeLot > g_MaxLotCap) hedgeLot = g_MaxLotCap;
   hedgeLot = NormalizeLot(_Symbol, hedgeLot);
   if(hedgeLot <= 0.0) return(false);

   VLog(StringFormat("HEDGE: opening opposite side %s, lot=%.2f (loser avg=%.5f, dist=%.5f)",
                     hedgeSide == 0 ? "BUY" : "SELL", hedgeLot, avg, triggerDist));
   return(OpenMarket(hedgeSide == 0, hedgeLot));
  }

#endif // __HGEA_GRID_MANAGER_MQH__
//+------------------------------------------------------------------+
