//+------------------------------------------------------------------+
//|                                                   HedgeGridEA.mq5|
//|                  All-in-one Hedge + Grid EA for MetaTrader 5     |
//|                                                                  |
//|  Single-file build. Features                                     |
//|  ----------------------------                                    |
//|    * 5 strategy profiles (selectable via InpStrategy input):     |
//|        DUAL_HEDGE, TREND_GRID, MEAN_REVERSION, BREAKOUT, HYBRID  |
//|    * 8 symbol presets (via InpSymbolPreset) that auto-override   |
//|      the risk / grid / filter inputs at OnInit().                |
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
//|  License: MIT                                                    |
//+------------------------------------------------------------------+
#property copyright "HedgeGridEA"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/SymbolInfo.mqh>

//==================================================================//
// ENUMS                                                              //
//==================================================================//
enum ENUM_STRATEGY_PROFILE
  {
   STRATEGY_DUAL_HEDGE      = 0, // Buy + Sell grid (no signal, range pairs)
   STRATEGY_TREND_GRID      = 1, // Grid only in H4 trend direction
   STRATEGY_MEAN_REVERSION  = 2, // RSI + Bollinger reversal entries
   STRATEGY_BREAKOUT        = 3, // Previous-day high/low break
   STRATEGY_HYBRID          = 4  // Multi-filter (trend + session + spread)
  };

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

//--- Entry vote values --------------------------------------------
#define ENTRY_NONE  0
#define ENTRY_BUY   1
#define ENTRY_SELL (-1)
#define ENTRY_BOTH  2

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
//   Presets modify these at OnInit(), not the user inputs.           //
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

//--- Indicator handles --------------------------------------------
int g_hATR       = INVALID_HANDLE;
int g_hEmaFast   = INVALID_HANDLE;
int g_hEmaSlow   = INVALID_HANDLE;
int g_hRSI       = INVALID_HANDLE;
int g_hBB        = INVALID_HANDLE;

//--- Trade wrappers & state ---------------------------------------
CTrade         g_Trade;
CPositionInfo  g_Pos;
datetime       g_LastBarTime = 0;

//==================================================================//
// UTILITIES                                                          //
//==================================================================//
void VLog(const string msg)
  {
   if(InpVerboseLogging)
      Print("[HGEA] ", msg);
  }

double PipSize(const string symbol)
  {
   const int    digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   const double point  = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(digits == 3 || digits == 5)
      return(point * 10.0);
   return(point);
  }

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

   int digits = 2;
   if(stepLot >= 1.0)       digits = 0;
   else if(stepLot >= 0.1)  digits = 1;
   else if(stepLot >= 0.01) digits = 2;
   else                     digits = 3;

   return(NormalizeDouble(lot, digits));
  }

//==================================================================//
// PRESET APPLICATION                                                 //
//==================================================================//
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

bool ApplyPreset(const ENUM_SYMBOL_PRESET preset)
  {
   switch(preset)
     {
      case PRESET_CUSTOM:
         return(false);

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

      case PRESET_GBPJPY:
         g_Strategy            = STRATEGY_TREND_GRID;
         g_StartingLot         = 0.01;
         g_LotMultiplier       = 1.25;
         g_MaxLotCap           = 0.80;
         g_BasketTPPercent     = 0.60;
         g_BasketSLPercent     = 5.00;
         g_MaxGridLevels       = 4;
         g_GridSpacingATRMult  = 1.20;
         g_HedgeTriggerATRMult = 2.20;
         g_HedgeLotMultiplier  = 1.50;
         g_MaxSpreadPips       = 4.0;
         g_UseTrendFilter      = true;
         g_UseSessionFilter    = true;
         g_ATRTimeframe        = PERIOD_H1;
         g_TrendTimeframe      = PERIOD_H4;
         return(true);

      case PRESET_EURCHF:
         g_Strategy            = STRATEGY_DUAL_HEDGE;
         g_StartingLot         = 0.01;
         g_LotMultiplier       = 1.20;
         g_MaxLotCap           = 1.00;
         g_BasketTPPercent     = 0.40;
         g_BasketSLPercent     = 5.00;
         g_MaxGridLevels       = 8;
         g_GridSpacingATRMult  = 0.70;
         g_HedgeTriggerATRMult = 1.80;
         g_HedgeLotMultiplier  = 1.40;
         g_MaxSpreadPips       = 3.0;
         g_UseTrendFilter      = false;
         g_UseSessionFilter    = false;
         g_ATRTimeframe        = PERIOD_H1;
         g_TrendTimeframe      = PERIOD_H4;
         return(true);

      case PRESET_XAUUSD:
         g_Strategy            = STRATEGY_TREND_GRID;
         g_StartingLot         = 0.01;
         g_LotMultiplier       = 1.40;
         g_MaxLotCap           = 0.50;
         g_BasketTPPercent     = 0.70;
         g_BasketSLPercent     = 6.00;
         g_MaxGridLevels       = 4;
         g_GridSpacingATRMult  = 1.50;
         g_HedgeTriggerATRMult = 2.50;
         g_HedgeLotMultiplier  = 1.60;
         g_MaxSpreadPips       = 30.0;
         g_UseTrendFilter      = true;
         g_UseSessionFilter    = true;
         g_ATRTimeframe        = PERIOD_H1;
         g_TrendTimeframe      = PERIOD_H4;
         return(true);

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
         g_MaxSpreadPips       = 50.0;
         g_UseTrendFilter      = true;
         g_UseSessionFilter    = true;
         g_ATRTimeframe        = PERIOD_M30;
         g_TrendTimeframe      = PERIOD_H4;
         return(true);

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
         g_MaxSpreadPips       = 500.0;
         g_UseTrendFilter      = false;
         g_UseSessionFilter    = false;
         g_ATRTimeframe        = PERIOD_H1;
         g_TrendTimeframe      = PERIOD_H4;
         return(true);
     }
   return(false);
  }

//==================================================================//
// INDICATORS                                                         //
//==================================================================//
bool CreateIndicatorHandles(const string symbol)
  {
   g_hATR = iATR(symbol, g_ATRTimeframe, g_ATRPeriod);
   if(g_hATR == INVALID_HANDLE)
     { VLog("iATR failed, err=" + IntegerToString(GetLastError())); return(false); }

   g_hEmaFast = iMA(symbol, g_TrendTimeframe, g_TrendEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   if(g_hEmaFast == INVALID_HANDLE)
     { VLog("iMA fast failed, err=" + IntegerToString(GetLastError())); return(false); }

   g_hEmaSlow = iMA(symbol, g_TrendTimeframe, g_TrendEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   if(g_hEmaSlow == INVALID_HANDLE)
     { VLog("iMA slow failed, err=" + IntegerToString(GetLastError())); return(false); }

   g_hRSI = iRSI(symbol, PERIOD_CURRENT, g_RSIPeriod, PRICE_CLOSE);
   if(g_hRSI == INVALID_HANDLE)
     { VLog("iRSI failed, err=" + IntegerToString(GetLastError())); return(false); }

   g_hBB = iBands(symbol, PERIOD_CURRENT, g_BBPeriod, 0, g_BBDeviation, PRICE_CLOSE);
   if(g_hBB == INVALID_HANDLE)
     { VLog("iBands failed, err=" + IntegerToString(GetLastError())); return(false); }

   return(true);
  }

void ReleaseIndicatorHandles()
  {
   if(g_hATR      != INVALID_HANDLE) { IndicatorRelease(g_hATR);     g_hATR     = INVALID_HANDLE; }
   if(g_hEmaFast  != INVALID_HANDLE) { IndicatorRelease(g_hEmaFast); g_hEmaFast = INVALID_HANDLE; }
   if(g_hEmaSlow  != INVALID_HANDLE) { IndicatorRelease(g_hEmaSlow); g_hEmaSlow = INVALID_HANDLE; }
   if(g_hRSI      != INVALID_HANDLE) { IndicatorRelease(g_hRSI);     g_hRSI     = INVALID_HANDLE; }
   if(g_hBB       != INVALID_HANDLE) { IndicatorRelease(g_hBB);      g_hBB      = INVALID_HANDLE; }
  }

// NOTE: CopyBuffer(h,buf_index,start_pos,count,out) copies into a
// non-series array; out[0] is the OLDEST of the range. We pass
// start_pos=1 to read the last closed bar (avoids mid-bar flicker).
double GetATR()
  {
   double buf[];
   if(CopyBuffer(g_hATR, 0, 1, 1, buf) < 1) return(0.0);
   return(buf[0]);
  }

bool GetEMAValues(double &emaFast, double &emaSlow)
  {
   double bf[], bs[];
   if(CopyBuffer(g_hEmaFast, 0, 1, 1, bf) < 1) return(false);
   if(CopyBuffer(g_hEmaSlow, 0, 1, 1, bs) < 1) return(false);
   emaFast = bf[0];
   emaSlow = bs[0];
   return(true);
  }

double GetRSI()
  {
   double buf[];
   if(CopyBuffer(g_hRSI, 0, 1, 1, buf) < 1) return(-1.0);
   return(buf[0]);
  }

bool GetBollingerBands(double &upper, double &lower, double &middle)
  {
   double bMid[], bUp[], bLo[];
   if(CopyBuffer(g_hBB, 0, 1, 1, bMid) < 1) return(false);
   if(CopyBuffer(g_hBB, 1, 1, 1, bUp)  < 1) return(false);
   if(CopyBuffer(g_hBB, 2, 1, 1, bLo)  < 1) return(false);
   middle = bMid[0];
   upper  = bUp[0];
   lower  = bLo[0];
   return(true);
  }

//==================================================================//
// FILTERS                                                            //
//==================================================================//
bool SpreadOK(const string symbol)
  {
   if(!g_UseSpreadFilter) return(true);
   const double pip = PipSize(symbol);
   if(pip <= 0.0) return(true);
   const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   const double spreadPips = (ask - bid) / pip;
   if(spreadPips > g_MaxSpreadPips)
     {
      VLog(StringFormat("Spread blocked: %.1f pips > %.1f", spreadPips, g_MaxSpreadPips));
      return(false);
     }
   return(true);
  }

bool SessionOK()
  {
   if(!g_UseSessionFilter) return(true);
   MqlDateTime mdt;
   TimeToStruct(TimeTradeServer(), mdt);
   if(mdt.day_of_week == 0 || mdt.day_of_week == 6) return(false);
   const int h = mdt.hour;
   if(g_SessionStartHour <= g_SessionEndHour)
      return(h >= g_SessionStartHour && h < g_SessionEndHour);
   return(h >= g_SessionStartHour || h < g_SessionEndHour); // crosses midnight
  }

int TrendDirection()
  {
   if(!g_UseTrendFilter) return(0);
   double fast = 0.0, slow = 0.0;
   if(!GetEMAValues(fast, slow)) return(0);
   if(fast > slow) return(1);
   if(fast < slow) return(-1);
   return(0);
  }

bool IsFridayClosingTime()
  {
   if(!InpCloseAllOnFriday) return(false);
   MqlDateTime mdt;
   TimeToStruct(TimeTradeServer(), mdt);
   return(mdt.day_of_week == 5 && mdt.hour >= InpFridayCloseHour);
  }

//==================================================================//
// POSITION INSPECTION                                                //
//==================================================================//
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

//==================================================================//
// TRADE EXECUTION                                                    //
//==================================================================//
int CloseAllEAPositions(const string reason)
  {
   int closed = 0;
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

bool OpenMarket(const bool isBuy, const double rawLot)
  {
   const double lot = NormalizeLot(_Symbol, rawLot);
   if(lot <= 0.0) { VLog("OpenMarket: normalized lot is 0"); return(false); }

   const double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                              : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(price <= 0.0) { VLog("OpenMarket: invalid price"); return(false); }

   const bool ok = isBuy
                   ? g_Trade.Buy (lot, _Symbol, price, 0.0, 0.0, InpOrderComment)
                   : g_Trade.Sell(lot, _Symbol, price, 0.0, 0.0, InpOrderComment);

   if(!ok)
      VLog(StringFormat("%s %.2f failed, err=%d retcode=%u",
                        isBuy ? "BUY" : "SELL", lot,
                        GetLastError(), g_Trade.ResultRetcode()));
   else
      VLog(StringFormat("%s %.2f @ %.5f ok", isBuy ? "BUY" : "SELL", lot, price));
   return(ok);
  }

//==================================================================//
// RISK / GRID HELPERS                                                //
//==================================================================//
bool CanOpenMorePositions() { return(CountEAPositions(-1) < g_MaxOpenPositions); }
bool CanAddGridLevel(const int side) { return(CountEAPositions(side) < g_MaxGridLevels); }

double NextGridLot(const int side)
  {
   const int level = CountEAPositions(side);
   double lot = g_StartingLot;
   for(int i = 0; i < level; i++)
      lot *= g_LotMultiplier;
   if(lot > g_MaxLotCap) lot = g_MaxLotCap;
   return(NormalizeLot(_Symbol, lot));
  }

//+------------------------------------------------------------------+
//| Basket TP / kill-switch / Friday-close. Returns true if closed.  |
//+------------------------------------------------------------------+
bool CheckBasketExits()
  {
   const int open = CountEAPositions(-1);
   if(open == 0) return(false);

   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0) return(false);

   const double profit  = TotalEABasketProfit();
   const double tpMoney = equity * (g_BasketTPPercent / 100.0);
   const double slMoney = equity * (g_BasketSLPercent / 100.0);

   if(profit >= tpMoney && tpMoney > 0.0)
     {
      CloseAllEAPositions(StringFormat("Basket TP (%.2f >= %.2f)", profit, tpMoney));
      return(true);
     }
   if(profit <= -slMoney && slMoney > 0.0)
     {
      CloseAllEAPositions(StringFormat("KILL-SWITCH: %.2f <= -%.2f (%.2f%% equity)",
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
//| Add a grid level on `side` when price has moved against the last |
//| entry by >= (ATR * g_GridSpacingATRMult).                        |
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
      return(OpenMarket(side == 0, NextGridLot(side)));

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const bool shouldAdd = (side == 0)
                           ? (ask <= lastPrice - step)
                           : (bid >= lastPrice + step);
   if(!shouldAdd) return(false);
   return(OpenMarket(side == 0, NextGridLot(side)));
  }

//+------------------------------------------------------------------+
//| Open a hedge on the opposite side when the loser's avg price has |
//| moved against it by >= (ATR * g_HedgeTriggerATRMult).            |
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
   const bool shouldHedge = (loserSide == 0)
                             ? (bid <= avg - triggerDist)
                             : (ask >= avg + triggerDist);
   if(!shouldHedge) return(false);

   double hedgeLot = SideVolume(loserSide) * g_HedgeLotMultiplier;
   if(hedgeLot > g_MaxLotCap) hedgeLot = g_MaxLotCap;
   hedgeLot = NormalizeLot(_Symbol, hedgeLot);
   if(hedgeLot <= 0.0) return(false);

   VLog(StringFormat("HEDGE: opening %s lot=%.2f (loser avg=%.5f, dist=%.5f)",
                     hedgeSide == 0 ? "BUY" : "SELL", hedgeLot, avg, triggerDist));
   return(OpenMarket(hedgeSide == 0, hedgeLot));
  }

//==================================================================//
// STRATEGY ENGINES                                                   //
//==================================================================//
int Strategy_DualHedge() { return(ENTRY_BOTH); }

int Strategy_TrendGrid()
  {
   if(!g_UseTrendFilter) return(ENTRY_NONE);
   const int dir = TrendDirection();
   if(dir > 0) return(ENTRY_BUY);
   if(dir < 0) return(ENTRY_SELL);
   return(ENTRY_NONE);
  }

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

int Strategy_Breakout()
  {
   const int lookback = MathMax(1, g_BreakoutLookbackDays);
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

int Strategy_Hybrid()
  {
   if(!SessionOK()) return(ENTRY_NONE);
   if(!SpreadOK(_Symbol)) return(ENTRY_NONE);
   if(!g_UseTrendFilter) return(ENTRY_BOTH); // graceful fallback
   const int dir = TrendDirection();
   if(dir > 0) return(ENTRY_BUY);
   if(dir < 0) return(ENTRY_SELL);
   return(ENTRY_NONE);
  }

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

//==================================================================//
// INIT / DEINIT / BAR DETECTION                                      //
//==================================================================//
void InitTradeManager()
  {
   g_Trade.SetExpertMagicNumber(InpMagicNumber);
   g_Trade.SetDeviationInPoints(20);
   g_Trade.SetTypeFillingBySymbol(_Symbol);
   g_Trade.SetMarginMode();
   g_Trade.LogLevel(LOG_LEVEL_ERRORS);
  }

bool IsNewBar()
  {
   datetime times[];
   if(CopyTime(_Symbol, PERIOD_CURRENT, 0, 1, times) < 1) return(false);
   if(times[0] == g_LastBarTime) return(false);
   g_LastBarTime = times[0];
   return(true);
  }

int OnInit()
  {
   // 1. Require a hedging account
   if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)
      != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
     {
      Print("[HGEA] ERROR: This EA requires a HEDGING account.");
      return(INIT_FAILED);
     }

   // 2. Load inputs, optionally apply preset
   LoadInputsIntoWorking();
   const bool applied = ApplyPreset(InpSymbolPreset);
   if(applied)
      Print("[HGEA] Preset applied: ", PresetToString(InpSymbolPreset),
            " -> strategy=", StrategyToString(g_Strategy));
   else
      Print("[HGEA] Using manual inputs. strategy=", StrategyToString(g_Strategy));

   // 3. Sanity checks
   if(g_StartingLot <= 0.0)         { Print("[HGEA] StartingLot must be > 0");         return(INIT_PARAMETERS_INCORRECT); }
   if(g_LotMultiplier < 1.0)        { Print("[HGEA] LotMultiplier must be >= 1");      return(INIT_PARAMETERS_INCORRECT); }
   if(g_MaxLotCap < g_StartingLot)  { Print("[HGEA] MaxLotCap must be >= StartingLot");return(INIT_PARAMETERS_INCORRECT); }
   if(g_MaxGridLevels < 1)          { Print("[HGEA] MaxGridLevels must be >= 1");      return(INIT_PARAMETERS_INCORRECT); }
   if(g_MaxOpenPositions < 1)       { Print("[HGEA] MaxOpenPositions must be >= 1");   return(INIT_PARAMETERS_INCORRECT); }
   if(g_BasketTPPercent <= 0.0)     { Print("[HGEA] BasketTPPercent must be > 0");     return(INIT_PARAMETERS_INCORRECT); }
   if(g_BasketSLPercent <= 0.0)     { Print("[HGEA] BasketSLPercent must be > 0");     return(INIT_PARAMETERS_INCORRECT); }
   if(g_ATRPeriod < 2)              { Print("[HGEA] ATRPeriod must be >= 2");          return(INIT_PARAMETERS_INCORRECT); }
   if(g_GridSpacingATRMult <= 0.0)  { Print("[HGEA] GridSpacingATRMult must be > 0");  return(INIT_PARAMETERS_INCORRECT); }
   if(g_HedgeTriggerATRMult <= 0.0) { Print("[HGEA] HedgeTriggerATRMult must be > 0"); return(INIT_PARAMETERS_INCORRECT); }
   if(g_HedgeLotMultiplier < 1.0)   { Print("[HGEA] HedgeLotMultiplier must be >= 1"); return(INIT_PARAMETERS_INCORRECT); }

   // 4. Market Watch
   if(!SymbolSelect(_Symbol, true))
     { Print("[HGEA] SymbolSelect failed for ", _Symbol); return(INIT_FAILED); }

   // 5. Indicators
   if(!CreateIndicatorHandles(_Symbol))
     { Print("[HGEA] Failed to create indicator handles"); return(INIT_FAILED); }

   // 6. Trade wrapper
   InitTradeManager();

   Print("[HGEA] Init OK. symbol=", _Symbol,
         " digits=", (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS),
         " point=",  DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_POINT), 8),
         " pip=",    DoubleToString(PipSize(_Symbol), 8));
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   ReleaseIndicatorHandles();
   Print("[HGEA] Deinit reason=", reason);
  }

//==================================================================//
// MAIN TICK                                                          //
//==================================================================//
void OnTick()
  {
   // 1. Exits first (every tick)
   if(CheckBasketExits()) return;

   // 2. Grid + hedge management on current positions (every tick)
   const int buys  = CountEAPositions(0);
   const int sells = CountEAPositions(1);

   if(buys > 0)
     {
      TryAddGridLevel(0);
      if(SideBasketProfit(0) < 0.0) TryOpenHedge(0);
     }
   if(sells > 0)
     {
      TryAddGridLevel(1);
      if(SideBasketProfit(1) < 0.0) TryOpenHedge(1);
     }

   // 3. First entry -- new bar only, and only when fully flat
   if(!IsNewBar()) return;
   if(IsFridayClosingTime()) return;

   if(buys == 0 && sells == 0)
     {
      if(!SpreadOK(_Symbol)) return;

      const int vote = EvaluateEntry();
      switch(vote)
        {
         case ENTRY_BUY:
            if(CanOpenMorePositions()) OpenMarket(true,  NextGridLot(0));
            break;
         case ENTRY_SELL:
            if(CanOpenMorePositions()) OpenMarket(false, NextGridLot(1));
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
