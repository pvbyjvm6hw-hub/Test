//+------------------------------------------------------------------+
//|                                                       Inputs.mqh |
//|           Central input block + working (mutable) settings       |
//+------------------------------------------------------------------+
#ifndef __HGEA_INPUTS_MQH__
#define __HGEA_INPUTS_MQH__

#include "Enums.mqh"

//==================================================================//
// USER INPUTS                                                        //
//==================================================================//

input group "=== MAIN SETUP ==="
input ENUM_STRATEGY_PROFILE InpStrategy        = STRATEGY_HYBRID; // Strategy profile
input ENUM_SYMBOL_PRESET    InpSymbolPreset    = PRESET_CUSTOM;   // Symbol preset (overrides values below when != CUSTOM)
input ulong                 InpMagicNumber     = 990011;          // Magic number
input string                InpOrderComment    = "HedgeGridEA";   // Order comment
input bool                  InpVerboseLogging  = true;            // Verbose logging

input group "=== RISK MANAGEMENT ==="
input double InpStartingLot          = 0.01;  // Starting lot size
input double InpLotMultiplier        = 1.30;  // Grid lot multiplier (>=1.0, 1.0 = flat)
input double InpMaxLotCap            = 1.00;  // Maximum lot size per single order
input double InpBasketTPPercent      = 0.50;  // Basket take-profit (% of equity)
input double InpBasketSLPercent      = 5.00;  // Basket stop-loss / kill-switch (% of equity)
input int    InpMaxOpenPositions     = 10;    // Max total open positions (both sides)
input int    InpMaxGridLevels        = 5;     // Max grid levels per side
input bool   InpCloseAllOnFriday     = true;  // Close everything before weekend
input int    InpFridayCloseHour      = 21;    // Hour (server time) to force close on Friday

input group "=== GRID / HEDGE SETTINGS ==="
input double InpGridSpacingATRMult   = 1.00;  // Grid spacing = ATR * this
input int    InpATRPeriod            = 14;    // ATR period
input ENUM_TIMEFRAMES InpATRTimeframe= PERIOD_H1; // ATR timeframe
input double InpHedgeTriggerATRMult  = 2.00;  // Hedge opens after loss >= ATR * this
input double InpHedgeLotMultiplier   = 1.50;  // Hedge lot = loser lot * this

input group "=== FILTERS ==="
input bool   InpUseSpreadFilter      = true;  // Enable spread filter
input double InpMaxSpreadPips        = 2.0;   // Max allowed spread (in pips)
input bool   InpUseSessionFilter     = true;  // Enable session filter
input int    InpSessionStartHour     = 7;     // Session start (server time)
input int    InpSessionEndHour       = 20;    // Session end   (server time)
input bool   InpUseTrendFilter       = true;  // Enable trend filter (EMA cross)
input int    InpTrendEMAFast         = 50;
input int    InpTrendEMASlow         = 200;
input ENUM_TIMEFRAMES InpTrendTimeframe = PERIOD_H4;

input group "=== STRATEGY-SPECIFIC ==="
input int    InpRSIPeriod            = 14;    // RSI period (mean reversion)
input double InpRSIOversold          = 30.0;  // RSI oversold level
input double InpRSIOverbought        = 70.0;  // RSI overbought level
input int    InpBBPeriod             = 20;    // Bollinger period
input double InpBBDeviation          = 2.0;   // Bollinger deviation
input int    InpBreakoutLookbackDays = 1;     // Lookback days for breakout range

//==================================================================//
// WORKING (MUTABLE) VARIABLES                                        //
//  Presets modify these at OnInit(), not the user inputs.            //
//==================================================================//

ENUM_STRATEGY_PROFILE g_Strategy;
double g_StartingLot;
double g_LotMultiplier;
double g_MaxLotCap;
double g_BasketTPPercent;
double g_BasketSLPercent;
int    g_MaxOpenPositions;
int    g_MaxGridLevels;

double g_GridSpacingATRMult;
int    g_ATRPeriod;
ENUM_TIMEFRAMES g_ATRTimeframe;
double g_HedgeTriggerATRMult;
double g_HedgeLotMultiplier;

bool   g_UseSpreadFilter;
double g_MaxSpreadPips;
bool   g_UseSessionFilter;
int    g_SessionStartHour;
int    g_SessionEndHour;
bool   g_UseTrendFilter;
int    g_TrendEMAFast;
int    g_TrendEMASlow;
ENUM_TIMEFRAMES g_TrendTimeframe;

int    g_RSIPeriod;
double g_RSIOversold;
double g_RSIOverbought;
int    g_BBPeriod;
double g_BBDeviation;
int    g_BreakoutLookbackDays;

//+------------------------------------------------------------------+
//| Copy user inputs into the working variables (called at OnInit).  |
//+------------------------------------------------------------------+
void LoadInputsIntoWorking()
  {
   g_Strategy             = InpStrategy;
   g_StartingLot          = InpStartingLot;
   g_LotMultiplier        = InpLotMultiplier;
   g_MaxLotCap            = InpMaxLotCap;
   g_BasketTPPercent      = InpBasketTPPercent;
   g_BasketSLPercent      = InpBasketSLPercent;
   g_MaxOpenPositions     = InpMaxOpenPositions;
   g_MaxGridLevels        = InpMaxGridLevels;

   g_GridSpacingATRMult   = InpGridSpacingATRMult;
   g_ATRPeriod            = InpATRPeriod;
   g_ATRTimeframe         = InpATRTimeframe;
   g_HedgeTriggerATRMult  = InpHedgeTriggerATRMult;
   g_HedgeLotMultiplier   = InpHedgeLotMultiplier;

   g_UseSpreadFilter      = InpUseSpreadFilter;
   g_MaxSpreadPips        = InpMaxSpreadPips;
   g_UseSessionFilter     = InpUseSessionFilter;
   g_SessionStartHour     = InpSessionStartHour;
   g_SessionEndHour       = InpSessionEndHour;
   g_UseTrendFilter       = InpUseTrendFilter;
   g_TrendEMAFast         = InpTrendEMAFast;
   g_TrendEMASlow         = InpTrendEMASlow;
   g_TrendTimeframe       = InpTrendTimeframe;

   g_RSIPeriod            = InpRSIPeriod;
   g_RSIOversold          = InpRSIOversold;
   g_RSIOverbought        = InpRSIOverbought;
   g_BBPeriod             = InpBBPeriod;
   g_BBDeviation          = InpBBDeviation;
   g_BreakoutLookbackDays = InpBreakoutLookbackDays;
  }

#endif // __HGEA_INPUTS_MQH__
//+------------------------------------------------------------------+
