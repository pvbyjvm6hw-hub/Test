//+------------------------------------------------------------------+
//|                                                        Enums.mqh |
//|                 Shared enumerations for the Hedge-Grid EA        |
//+------------------------------------------------------------------+
#ifndef __HGEA_ENUMS_MQH__
#define __HGEA_ENUMS_MQH__

//--- Trading strategy profile (selectable from inputs) --------------
enum ENUM_STRATEGY_PROFILE
  {
   STRATEGY_DUAL_HEDGE      = 0, // Buy + Sell grid (no signal, range pairs)
   STRATEGY_TREND_GRID      = 1, // Grid only in H4 trend direction
   STRATEGY_MEAN_REVERSION  = 2, // RSI + Bollinger reversal entries
   STRATEGY_BREAKOUT        = 3, // Previous-day high/low break
   STRATEGY_HYBRID          = 4  // Multi-filter (trend + session + spread)
  };

//--- Per-symbol preset ---------------------------------------------
enum ENUM_SYMBOL_PRESET
  {
   PRESET_CUSTOM            = 0, // Use the manual input values as-is
   PRESET_EURUSD            = 1,
   PRESET_GBPUSD            = 2,
   PRESET_USDJPY            = 3,
   PRESET_GBPJPY            = 4,
   PRESET_EURCHF            = 5, // Ranging pair -> DUAL_HEDGE
   PRESET_XAUUSD            = 6, // Gold -> TREND_GRID
   PRESET_US30              = 7, // Dow -> HYBRID
   PRESET_BTCUSD            = 8  // Crypto -> BREAKOUT
  };

//--- Basket side indicator -----------------------------------------
enum ENUM_BASKET_SIDE
  {
   BASKET_BUY               = 0,
   BASKET_SELL              = 1
  };

#endif // __HGEA_ENUMS_MQH__
//+------------------------------------------------------------------+
