//+------------------------------------------------------------------+
//|                                                PresetManager.mqh |
//|          Applies per-symbol presets by overriding globals.       |
//+------------------------------------------------------------------+
#ifndef __HGEA_PRESET_MANAGER_MQH__
#define __HGEA_PRESET_MANAGER_MQH__

#include "Enums.mqh"
#include "Inputs.mqh"

//+------------------------------------------------------------------+
//| Apply a preset. Returns true if a preset was applied.            |
//+------------------------------------------------------------------+
bool ApplyPreset(const ENUM_SYMBOL_PRESET preset)
  {
   switch(preset)
     {
      //-------------------------------------------------------------
      case PRESET_CUSTOM:
         return(false); // Leave working vars as loaded from inputs

      //-------------------------------------------------------------
      case PRESET_EURUSD:
         g_Strategy            = STRATEGY_HYBRID;
         g_StartingLot         = 0.01;
         g_LotMultiplier       = 1.30;
         g_MaxLotCap           = 1.00;
         g_BasketTPPercent     = 0.50;
         g_BasketSLPercent     = 5.00;
         g_MaxGridLevels       = 5;
         g_GridSpacingATRMult  = 1.00;
         g_HedgeTriggerATRMult = 2.00;
         g_HedgeLotMultiplier  = 1.50;
         g_MaxSpreadPips       = 2.0;
         g_UseTrendFilter      = true;
         g_UseSessionFilter    = true;
         g_ATRTimeframe        = PERIOD_H1;
         g_TrendTimeframe      = PERIOD_H4;
         return(true);

      //-------------------------------------------------------------
      case PRESET_GBPUSD:
         g_Strategy            = STRATEGY_HYBRID;
         g_StartingLot         = 0.01;
         g_LotMultiplier       = 1.30;
         g_MaxLotCap           = 1.00;
         g_BasketTPPercent     = 0.50;
         g_BasketSLPercent     = 5.00;
         g_MaxGridLevels       = 5;
         g_GridSpacingATRMult  = 1.00;
         g_HedgeTriggerATRMult = 2.00;
         g_HedgeLotMultiplier  = 1.50;
         g_MaxSpreadPips       = 2.5;
         g_UseTrendFilter      = true;
         g_UseSessionFilter    = true;
         g_ATRTimeframe        = PERIOD_H1;
         g_TrendTimeframe      = PERIOD_H4;
         return(true);

      //-------------------------------------------------------------
      case PRESET_USDJPY:
         g_Strategy            = STRATEGY_HYBRID;
         g_StartingLot         = 0.01;
         g_LotMultiplier       = 1.30;
         g_MaxLotCap           = 1.00;
         g_BasketTPPercent     = 0.50;
         g_BasketSLPercent     = 5.00;
         g_MaxGridLevels       = 5;
         g_GridSpacingATRMult  = 1.00;
         g_HedgeTriggerATRMult = 2.00;
         g_HedgeLotMultiplier  = 1.50;
         g_MaxSpreadPips       = 2.0;
         g_UseTrendFilter      = true;
         g_UseSessionFilter    = true;
         g_ATRTimeframe        = PERIOD_H1;
         g_TrendTimeframe      = PERIOD_H4;
         return(true);

      //-------------------------------------------------------------
      case PRESET_GBPJPY:
         g_Strategy            = STRATEGY_TREND_GRID;
         g_StartingLot         = 0.01;
         g_LotMultiplier       = 1.25;
         g_MaxLotCap           = 0.80;
         g_BasketTPPercent     = 0.60;
         g_BasketSLPercent     = 5.00;
         g_MaxGridLevels       = 4;
         g_GridSpacingATRMult  = 1.20;  // wider for volatile cross
         g_HedgeTriggerATRMult = 2.20;
         g_HedgeLotMultiplier  = 1.50;
         g_MaxSpreadPips       = 4.0;
         g_UseTrendFilter      = true;
         g_UseSessionFilter    = true;
         g_ATRTimeframe        = PERIOD_H1;
         g_TrendTimeframe      = PERIOD_H4;
         return(true);

      //-------------------------------------------------------------
      case PRESET_EURCHF:
         g_Strategy            = STRATEGY_DUAL_HEDGE; // ranging pair
         g_StartingLot         = 0.01;
         g_LotMultiplier       = 1.20;
         g_MaxLotCap           = 1.00;
         g_BasketTPPercent     = 0.40;
         g_BasketSLPercent     = 5.00;
         g_MaxGridLevels       = 8;
         g_GridSpacingATRMult  = 0.70;  // tight grid
         g_HedgeTriggerATRMult = 1.80;
         g_HedgeLotMultiplier  = 1.40;
         g_MaxSpreadPips       = 3.0;
         g_UseTrendFilter      = false;
         g_UseSessionFilter    = false;
         g_ATRTimeframe        = PERIOD_H1;
         g_TrendTimeframe      = PERIOD_H4;
         return(true);

      //-------------------------------------------------------------
      case PRESET_XAUUSD:
         g_Strategy            = STRATEGY_TREND_GRID;
         g_StartingLot         = 0.01;
         g_LotMultiplier       = 1.40;
         g_MaxLotCap           = 0.50;
         g_BasketTPPercent     = 0.70;
         g_BasketSLPercent     = 6.00;
         g_MaxGridLevels       = 4;
         g_GridSpacingATRMult  = 1.50;  // wider for gold
         g_HedgeTriggerATRMult = 2.50;
         g_HedgeLotMultiplier  = 1.60;
         g_MaxSpreadPips       = 30.0;  // gold spread is huge in points-as-pips
         g_UseTrendFilter      = true;
         g_UseSessionFilter    = true;
         g_ATRTimeframe        = PERIOD_H1;
         g_TrendTimeframe      = PERIOD_H4;
         return(true);

      //-------------------------------------------------------------
      case PRESET_US30:
         g_Strategy            = STRATEGY_HYBRID;
         g_StartingLot         = 0.10;
         g_LotMultiplier       = 1.30;
         g_MaxLotCap           = 2.00;
         g_BasketTPPercent     = 0.60;
         g_BasketSLPercent     = 5.00;
         g_MaxGridLevels       = 5;
         g_GridSpacingATRMult  = 1.00;
         g_HedgeTriggerATRMult = 2.00;
         g_HedgeLotMultiplier  = 1.50;
         g_MaxSpreadPips       = 50.0; // index in pips-as-points; broker dependent
         g_UseTrendFilter      = true;
         g_UseSessionFilter    = true;
         g_ATRTimeframe        = PERIOD_M30;
         g_TrendTimeframe      = PERIOD_H4;
         return(true);

      //-------------------------------------------------------------
      case PRESET_BTCUSD:
         g_Strategy            = STRATEGY_BREAKOUT;
         g_StartingLot         = 0.01;
         g_LotMultiplier       = 1.25;
         g_MaxLotCap           = 0.50;
         g_BasketTPPercent     = 1.00;
         g_BasketSLPercent     = 8.00;
         g_MaxGridLevels       = 3;
         g_GridSpacingATRMult  = 1.50;
         g_HedgeTriggerATRMult = 3.00;
         g_HedgeLotMultiplier  = 1.50;
         g_MaxSpreadPips       = 500.0; // crypto spread wide; symbol dependent
         g_UseTrendFilter      = false;
         g_UseSessionFilter    = false;
         g_ATRTimeframe        = PERIOD_H1;
         g_TrendTimeframe      = PERIOD_H4;
         return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Helper for logging the applied preset                            |
//+------------------------------------------------------------------+
string PresetToString(const ENUM_SYMBOL_PRESET preset)
  {
   switch(preset)
     {
      case PRESET_CUSTOM:  return("CUSTOM");
      case PRESET_EURUSD:  return("EURUSD");
      case PRESET_GBPUSD:  return("GBPUSD");
      case PRESET_USDJPY:  return("USDJPY");
      case PRESET_GBPJPY:  return("GBPJPY");
      case PRESET_EURCHF:  return("EURCHF");
      case PRESET_XAUUSD:  return("XAUUSD");
      case PRESET_US30:    return("US30");
      case PRESET_BTCUSD:  return("BTCUSD");
     }
   return("UNKNOWN");
  }

string StrategyToString(const ENUM_STRATEGY_PROFILE s)
  {
   switch(s)
     {
      case STRATEGY_DUAL_HEDGE:     return("DUAL_HEDGE");
      case STRATEGY_TREND_GRID:     return("TREND_GRID");
      case STRATEGY_MEAN_REVERSION: return("MEAN_REVERSION");
      case STRATEGY_BREAKOUT:       return("BREAKOUT");
      case STRATEGY_HYBRID:         return("HYBRID");
     }
   return("UNKNOWN");
  }

#endif // __HGEA_PRESET_MANAGER_MQH__
//+------------------------------------------------------------------+
