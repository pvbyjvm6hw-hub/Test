//+------------------------------------------------------------------+
//|                                       MC_Hedge_M5_v2.03.mq5       |
//|        Fibo zone entry (M5) + ATR-gated SINGLE-HEDGE Recovery     |
//|                                                                   |
//| v2.03 changes (vs v2.02):                                         |
//|   1.  REMOVED: Asymmetric L2 exit (close L2 + L1->BE).            |
//|       InpHedgeLegTP_USD input + CheckAsymmetricL2Exit() function. |
//|   2.  REMOVED: Basket time-stop (InpMaxBasketBars).               |
//|   3.  REMOVED: ADX-fade basket close (InpADX_FadeHysteresis).     |
//|   4.  RETAINED: ATR-based hedge step distance (InpHedgeATRMult).  |
//|   5.  RETAINED: ADX trend confirmation for hedge ENTRY            |
//|       (InpHedgeRequireTrend) — entry-side gate, not an exit.      |
//|                                                                   |
//| v2.02 carryover (vs v2.01):                                       |
//|   - Daily lockout race window closed.                             |
//|   - Cooldown persisted via GlobalVariable.                        |
//|   - Daily P&L driven by OnTradeTransaction.                       |
//|   - High-watermark trail on L1.                                   |
//|   - HYBRID mode removed; ATR×Mult hedge trigger.                  |
//|                                                                   |
//| Account: HEDGING ONLY                                             |
//+------------------------------------------------------------------+
#property copyright "MC / FETOUH"
#property version   "2.03"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/SymbolInfo.mqh>
#include <Trade/DealInfo.mqh>

#define   INVALID_DIRECTION_VAL ((ENUM_POSITION_TYPE)-1)

//==================================================================//
// ENUMS                                                              //
//==================================================================//
enum ENUM_DIR_FILTER { DIR_BOTH=0, DIR_BUY_ONLY=1, DIR_SELL_ONLY=2 };

//==================================================================//
// INPUTS                                                             //
//==================================================================//

input group "=== GENERAL ==="
input int      InpMaxSpreadPts   = 30;        // Max spread (points). 0 = disabled
input int      InpSlippage       = 20;        // Deviation (points)
input ulong    InpMagicNumber    = 404005;    // Magic number
input string   InpOrderComment   = "MC Hedge M5";
input bool     InpVerboseLogging = true;      // Print errors and signal events

input group "=== Trading Hours (Server Time) ==="
input int      InpStartHour      = 1;         // Start hour (0-23)
input int      InpEndHour        = 23;        // End hour (0-23, exclusive)

input group "=== Single Trade Rules (Layer 1 only) ==="
input double   InpSingleTP_USD      = 8.0;       // Single trade TP in $ (closes L1)
input bool     InpSingleUseTrailing = true;      // Trail L1 once profitable
input int      InpSingleTrailStart  = 30;        // Profit (points) before trail engages
input int      InpSingleTrailStop   = 50;        // Trail distance (points from watermark)
input int      InpSingleTrailStep   = 20;        // Min step to move trail (points)

input group "=== Basket Rules (active once hedge fires) ==="
input double   InpBasketTP_USD      = 25.0;      // Basket TP in $ (closes ALL legs)
input double   InpBasketSL_USD      = 80.0;      // Basket SL in $ (closes ALL legs, triggers cooldown)
// [REMOVED v2.03] InpHedgeLegTP_USD  — asymmetric L2 exit feature removed
// [REMOVED v2.03] InpMaxBasketBars   — basket time stop removed
// [REMOVED v2.03] InpADX_FadeHysteresis — ADX-fade basket close removed

input group "=== Emergency / Cooldown / Weekend ==="
input double   InpEmergencyStop     = 150.0;     // Hard panic stop in $ (kill switch beyond Basket SL)
input int      InpCooldownMinutes   = 60;        // Pause new initial entries after Basket SL hit (min)
input bool     InpCloseBeforeWeekend= true;      // Close everything Fri before market close
input int      InpWeekendCloseHour  = 22;        // Hour Friday to force-close (server time)

input group "=== General Risk ==="
input ENUM_DIR_FILTER InpDirFilter = DIR_BOTH;   // Restrict L1 to BUY-only / SELL-only / both

input group "=== Lot Sizing ==="
input double   InpLotSize        = 0.01;      // Fixed lot (used when dynamic = OFF)
input bool     InpUseDynamicLot  = false;     // Enable dynamic lot
input double   InpCapitalUnit    = 100.0;     // Capital unit ($)
input double   InpLotPerUnit     = 0.01;      // Lot per capital unit
input double   InpMinDynamicLot  = 0.01;      // Min dynamic lot
input double   InpMaxDynamicLot  = 1.00;      // Max dynamic lot

input group "=== Daily Limits (NET REALIZED P&L only — excludes floating) ==="
input double   InpDailyTarget    = 20.0;      // Daily profit target ($). 0 = disabled
input double   InpDailyLoss      = 50.0;      // Daily loss limit ($). 0 = disabled
input bool     InpCloseOnDaily   = true;      // Force-close all on daily limit hit

input group "=== Fibo Entry Logic (M5) ==="
input int      InpFiboPeriod        = 50;     // Bars to compute Fibo zones (high/low range)
input double   InpFiboUpperLevel    = 0.382;  // Upper zone (sell trigger above this retrace)
input double   InpFiboLowerLevel    = 0.618;  // Lower zone (buy trigger below this retrace)

input group "=== Entry Filter (ADX only) ==="
input bool     InpUseADX_Filter     = true;   // ADX strength filter (the only confirmation)
input int      InpADX_Period        = 14;
input int      InpADX_Min           = 22;     // Min ADX value (M5 default 22)

input group "=== Hedge Recovery (single opposite leg, ATR-gated) ==="
input int      InpMaxOrders         = 2;     // Max basket size (default 2 = L1+L2 only). >2 enables more layers if you really want.
input double   InpHedgeATRMult      = 1.5;   // Hedge fires when adverse move >= ATR × this
input int      InpHedgeATR_Period   = 14;    // ATR period (M5)
input bool     InpHedgeRequireTrend = true;  // Require ADX>=Min AND rising at hedge time
input double   InpHedgeMultiplier   = 2.0;   // Lot multiplier vs IMMEDIATELY PREVIOUS layer
input double   InpMaxLayerLot       = 1.00;  // Hard cap per layer lot. 0 = unlimited

input group "=== Dashboard ==="
input bool     InpShowDashboard   = true;
input int      InpDashboardCorner = 0;        // 0=TL 1=TR 2=BL 3=BR
input int      InpDashboardX      = 20;
input int      InpDashboardY      = 20;

//==================================================================//
// GLOBALS                                                            //
//==================================================================//
CTrade         trade;
CPositionInfo  m_position;
CSymbolInfo    m_symbol;
CDealInfo      m_deal;

// Bar / day tracking
datetime g_lastBarTime    = 0;
int      g_lastDayKey     = -1;
datetime g_dayStart       = 0;

// Daily lockout
bool     g_dailyLockout   = false;
string   g_lockoutReason  = "";
double   g_dailyClosedPnL = 0.0;

// Cooldown after basket-SL hit (persisted via GlobalVariable)
datetime g_cooldownUntil  = 0;
string   g_cooldownGV     = "";   // GlobalVariable name (built in OnInit)

// Single-trade trailing state
double   g_singleTrailWatermark = 0.0;   // Peak favorable price (BUY: max bid; SELL: min ask)
bool     g_singleTrailActive    = false;

// Symbol cache
int      g_stopsLevel    = 0;
int      g_freezeLevel   = 0;
double   g_pointValue    = 0.0;
double   g_volMin        = 0.0;
double   g_volMax        = 0.0;
double   g_volStep       = 0.0;
int      g_digits        = 0;

// Per-tick cache
// [MODIFIED v2.03] Removed g_cachedEarliestTime, g_cachedL1OpenPrice, g_cachedL2Profit
// (no longer needed after asym-exit & time-stop removal).
int                g_cachedPositionCount  = 0;
ENUM_POSITION_TYPE g_cachedDirection      = INVALID_DIRECTION_VAL; // L1 direction (earliest fill)
double             g_cachedBasketProfit   = 0.0;
double             g_cachedLastPrice      = 0.0;                   // open price of most-recent fill
ENUM_POSITION_TYPE g_cachedLastDirection  = INVALID_DIRECTION_VAL;
double             g_cachedLastLot        = 0.0;
ulong              g_cachedL1Ticket       = 0;
ulong              g_cachedL2Ticket       = 0;
bool               g_cacheValid           = false;
bool               g_spreadBlocked        = false;

// Basket lot (locked at first entry; used as base for multiplier calc)
double   g_currentBasketLot = 0.0;

// Indicator handles
int      g_hADX_M5 = INVALID_HANDLE;
int      g_hATR_M5 = INVALID_HANDLE;

#define   DASH_PREFIX "MC_M5_DASH_"

#define   COLOR_BG_MAIN      C'13,27,42'
#define   COLOR_BG_HEADER    C'31,97,141'
#define   COLOR_TEXT_MAIN    C'241,250,238'
#define   COLOR_TEXT_DIM     C'168,218,220'
#define   COLOR_HEADER       C'76,201,240'
#define   COLOR_PROFIT       C'46,196,182'
#define   COLOR_LOSS         C'230,57,70'
#define   COLOR_ACTIVE       C'6,214,160'
#define   COLOR_STOPPED      C'255,107,107'
#define   COLOR_WARNING      C'255,214,10'
#define   COLOR_PROGRESS     C'6,214,160'

#define   DASH_WIDTH         340
#define   DASH_LINE_HEIGHT   18
#define   DASH_PADDING       10

//==================================================================//
// HELPERS                                                            //
//==================================================================//
double NPrice(double p) { return NormalizeDouble(p, g_digits); }
double PointsToPrice(double pts) { return pts * g_pointValue; }

datetime GetDayStart(datetime t)
{
   MqlDateTime mt; TimeToStruct(t, mt);
   mt.hour=0; mt.min=0; mt.sec=0;
   return StructToTime(mt);
}

int DayKeyFromTime(datetime t)
{
   MqlDateTime mt; TimeToStruct(t, mt);
   return mt.year * 10000 + mt.mon * 100 + mt.day;
}

bool IsInCooldown()
{
   return (g_cooldownUntil > 0 && TimeCurrent() < g_cooldownUntil);
}

void SetCooldown(int minutes)
{
   g_cooldownUntil = TimeCurrent() + (minutes * 60);
   if(g_cooldownGV != "")
      GlobalVariableSet(g_cooldownGV, (double)g_cooldownUntil);
}

void LoadCooldownFromGV()
{
   if(g_cooldownGV == "") return;
   if(GlobalVariableCheck(g_cooldownGV))
   {
      datetime saved = (datetime)GlobalVariableGet(g_cooldownGV);
      if(saved > TimeCurrent()) g_cooldownUntil = saved;
      else                      GlobalVariableDel(g_cooldownGV);
   }
}

bool IsFridayWeekendCloseTime()
{
   if(!InpCloseBeforeWeekend) return false;
   MqlDateTime t; TimeCurrent(t);
   if(t.day_of_week == 5 && t.hour >= InpWeekendCloseHour) return true;
   if(t.day_of_week == 6) return true;
   if(t.day_of_week == 0) return true;
   return false;
}

bool IsTradingTime()
{
   MqlDateTime t; TimeCurrent(t);
   return (t.hour >= InpStartHour && t.hour < InpEndHour);
}

bool IsNewBar()
{
   datetime curr = iTime(_Symbol, PERIOD_M5, 0);
   if(curr != g_lastBarTime) { g_lastBarTime = curr; return true; }
   return false;
}

bool IsSpreadAcceptable()
{
   if(InpMaxSpreadPts <= 0) return true;
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread <= InpMaxSpreadPts);
}

void LogTradeError(string operation)
{
   if(!InpVerboseLogging) return;
   uint   retcode = trade.ResultRetcode();
   string retDesc = trade.ResultRetcodeDescription();
   int    lastErr = GetLastError();
   PrintFormat("TRADE ERROR [%s] | RetCode=%u (%s) | LastError=%d",
               operation, retcode, retDesc, lastErr);
}

double GetBufferValue(int handle, int shift)
{
   if(handle == INVALID_HANDLE) return 0.0;
   double buf[];
   if(CopyBuffer(handle, 0, shift, 1, buf) < 1) return 0.0;
   return buf[0];
}

double GetHigh(ENUM_TIMEFRAMES tf, int s) { double a[]; if(CopyHigh(_Symbol,tf,s,1,a)<1) return 0.0; return a[0]; }
double GetLow (ENUM_TIMEFRAMES tf, int s) { double a[]; if(CopyLow (_Symbol,tf,s,1,a)<1) return 0.0; return a[0]; }

//==================================================================//
// VALIDATION                                                         //
//==================================================================//
bool ValidateInputs()
{
   string err = "";
   if(InpLotSize <= 0)                err += "InpLotSize must be > 0\n";
   if(InpSingleTP_USD <= 0)           err += "InpSingleTP_USD must be > 0\n";
   if(InpBasketTP_USD <= 0)           err += "InpBasketTP_USD must be > 0\n";
   if(InpBasketSL_USD <= 0)           err += "InpBasketSL_USD must be > 0\n";
   if(InpEmergencyStop <= 0)          err += "InpEmergencyStop must be > 0\n";
   if(InpEmergencyStop <= InpBasketSL_USD)
                                      err += "InpEmergencyStop should exceed InpBasketSL_USD (basket SL fires first)\n";
   // [REMOVED v2.03] InpHedgeLegTP_USD / InpMaxBasketBars / InpADX_FadeHysteresis validations
   if(InpCooldownMinutes < 0)         err += "InpCooldownMinutes cannot be negative\n";
   if(InpWeekendCloseHour < 0 || InpWeekendCloseHour > 23) err += "InpWeekendCloseHour must be 0-23\n";
   if(InpStartHour < 0 || InpStartHour > 23) err += "InpStartHour must be 0-23\n";
   if(InpEndHour < 0 || InpEndHour > 23)     err += "InpEndHour must be 0-23\n";
   if(InpStartHour >= InpEndHour)     err += "InpStartHour must be < InpEndHour\n";
   if(InpMaxSpreadPts < 0)            err += "InpMaxSpreadPts cannot be negative\n";
   if(InpDailyTarget < 0)             err += "InpDailyTarget cannot be negative\n";
   if(InpDailyLoss < 0)               err += "InpDailyLoss cannot be negative\n";
   if(InpMaxOrders < 1)               err += "InpMaxOrders must be >= 1\n";
   if(InpMaxOrders > 10)              err += "InpMaxOrders too high (max 10; default 2)\n";
   if(InpHedgeATRMult <= 0)           err += "InpHedgeATRMult must be > 0\n";
   if(InpHedgeATRMult > 5)            err += "InpHedgeATRMult too large (max 5)\n";
   if(InpHedgeATR_Period < 5)         err += "InpHedgeATR_Period must be >= 5\n";
   if(InpHedgeMultiplier < 1.0)       err += "InpHedgeMultiplier must be >= 1.0\n";
   if(InpHedgeMultiplier > 3.0)       err += "InpHedgeMultiplier too aggressive (max 3.0)\n";
   if(InpMaxLayerLot < 0)             err += "InpMaxLayerLot cannot be negative (use 0 for unlimited)\n";
   if(InpFiboPeriod < 5)              err += "InpFiboPeriod must be >= 5\n";
   if(InpFiboUpperLevel <= 0 || InpFiboUpperLevel >= 1) err += "InpFiboUpperLevel must be in (0,1)\n";
   if(InpFiboLowerLevel <= 0 || InpFiboLowerLevel >= 1) err += "InpFiboLowerLevel must be in (0,1)\n";
   if(InpFiboUpperLevel >= InpFiboLowerLevel) err += "InpFiboUpperLevel must be < InpFiboLowerLevel\n";
   if(InpADX_Period < 1)              err += "InpADX_Period must be >= 1\n";
   if(InpADX_Min < 0)                 err += "InpADX_Min cannot be negative\n";
   if(InpSingleUseTrailing)
   {
      if(InpSingleTrailStart < 0)     err += "InpSingleTrailStart cannot be negative\n";
      if(InpSingleTrailStop  <= 0)    err += "InpSingleTrailStop must be > 0\n";
      if(InpSingleTrailStep  < 0)     err += "InpSingleTrailStep cannot be negative\n";
   }
   if(InpUseDynamicLot)
   {
      if(InpCapitalUnit <= 0)         err += "InpCapitalUnit must be > 0\n";
      if(InpLotPerUnit <= 0)          err += "InpLotPerUnit must be > 0\n";
      if(InpMinDynamicLot <= 0)       err += "InpMinDynamicLot must be > 0\n";
      if(InpMaxDynamicLot <= 0)       err += "InpMaxDynamicLot must be > 0\n";
      if(InpMinDynamicLot > InpMaxDynamicLot)
                                      err += "InpMinDynamicLot must be <= InpMaxDynamicLot\n";
   }
   if(StringLen(err) > 0)
   {
      Print("INPUT VALIDATION FAILED:\n", err);
      return false;
   }
   return true;
}

bool CacheSymbolProperties()
{
   g_stopsLevel  = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   g_freezeLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   g_pointValue  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_volMin      = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   g_volMax      = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   g_volStep     = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   g_digits      = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(g_pointValue <= 0 || g_volMin <= 0 || g_volStep <= 0) return false;
   return true;
}

//==================================================================//
// LOT SIZING                                                         //
//==================================================================//
double CalculateDynamicLot()
{
   if(!InpUseDynamicLot) return InpLotSize;
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0 || InpCapitalUnit <= 0) return InpMinDynamicLot;
   double rawLot = (balance / InpCapitalUnit) * InpLotPerUnit;
   if(rawLot < InpMinDynamicLot) rawLot = InpMinDynamicLot;
   if(rawLot > InpMaxDynamicLot) rawLot = InpMaxDynamicLot;
   return rawLot;
}

double NormalizeVolume(double vol)
{
   if(vol < g_volMin) vol = g_volMin;
   if(vol > g_volMax) vol = g_volMax;
   vol = MathRound(vol / g_volStep) * g_volStep;
   int volDigits = 2;
   if(g_volStep >= 1.0)       volDigits = 0;
   else if(g_volStep >= 0.1)  volDigits = 1;
   else if(g_volStep >= 0.01) volDigits = 2;
   else                       volDigits = 3;
   return NormalizeDouble(vol, volDigits);
}

double CalculateLayerLot(int layerIndex, double previousLayerLot)
{
   if(layerIndex <= 1)
   {
      double baseLot = (g_currentBasketLot > 0.0) ? g_currentBasketLot : CalculateDynamicLot();
      return NormalizeVolume(baseLot);
   }
   if(previousLayerLot <= 0.0) previousLayerLot = CalculateDynamicLot();
   double resultLot = previousLayerLot * InpHedgeMultiplier;
   if(InpMaxLayerLot > 0.0 && resultLot > InpMaxLayerLot)
      resultLot = InpMaxLayerLot;
   return NormalizeVolume(resultLot);
}

//==================================================================//
// CACHE BUILDER — single pass over basket positions                  //
// Captures: count, basket P&L, L1/L2 tickets, last fill data         //
// [MODIFIED v2.03] Removed L1 open time / L1 open price / L2 profit  //
// caching — no longer needed after asym-exit & time-stop removal.    //
//==================================================================//
void BuildCache()
{
   g_cachedPositionCount  = 0;
   g_cachedDirection      = INVALID_DIRECTION_VAL;
   g_cachedBasketProfit   = 0.0;
   g_cachedLastPrice      = 0.0;
   g_cachedLastDirection  = INVALID_DIRECTION_VAL;
   g_cachedLastLot        = 0.0;
   g_cachedL1Ticket       = 0;
   g_cachedL2Ticket       = 0;

   datetime latestT   = 0;
   datetime earliestT = D'9999.12.31';

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Magic()  != InpMagicNumber) continue;
      if(m_position.Symbol() != _Symbol)        continue;

      g_cachedPositionCount++;
      double legPnL = m_position.Profit() + m_position.Swap() + m_position.Commission();
      g_cachedBasketProfit += legPnL;

      datetime tOpen = m_position.Time();
      ulong    tk    = m_position.Ticket();
      double   px    = m_position.PriceOpen();
      double   vol   = m_position.Volume();
      ENUM_POSITION_TYPE pt = m_position.PositionType();

      // Most recent fill
      if(tOpen > latestT)
      {
         latestT               = tOpen;
         g_cachedLastPrice     = px;
         g_cachedLastDirection = pt;
         g_cachedLastLot       = vol;
         g_cachedL2Ticket      = tk;
      }

      // Earliest fill (true L1)
      if(tOpen < earliestT)
      {
         earliestT             = tOpen;
         g_cachedDirection     = pt;
         g_cachedL1Ticket      = tk;
      }
   }

   // If only 1 position, L2 cache should be cleared
   if(g_cachedPositionCount < 2)
   {
      g_cachedL2Ticket = 0;
   }

   g_cacheValid = true;
}

int CountOpenPositionsLive()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(m_position.SelectByIndex(i))
         if(m_position.Magic() == InpMagicNumber && m_position.Symbol() == _Symbol) count++;
   return count;
}

//==================================================================//
// EXIT FUNCTIONS                                                     //
//==================================================================//
void CloseAllPositions(string reason)
{
   int closed = 0, failed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Magic()  != InpMagicNumber) continue;
      if(m_position.Symbol() != _Symbol)        continue;
      if(trade.PositionClose(m_position.Ticket()))
         closed++;
      else
      {
         failed++;
         LogTradeError(StringFormat("Close ticket #%I64u", m_position.Ticket()));
      }
   }
   PrintFormat("%s | Closed: %d | Failed: %d", reason, closed, failed);

   if(closed > 0)
   {
      g_currentBasketLot         = 0.0;
      g_singleTrailActive        = false;
      g_singleTrailWatermark     = 0.0;
   }
}

bool CheckEmergencyExits()
{
   if(g_cachedPositionCount == 0) return false;
   if(g_cachedBasketProfit <= -InpEmergencyStop)
   {
      CloseAllPositions("EMERGENCY STOP: Hard panic limit.");
      return true;
   }
   return false;
}

//==================================================================//
// SINGLE-TRADE EXITS — applies ONLY when L1 is alone                //
// L1: TP target + high-watermark trailing. NO SL.                   //
//==================================================================//
bool CheckSingleTradeExits()
{
   if(g_cachedPositionCount != 1) return false;

   ulong  ticket = g_cachedL1Ticket;
   if(ticket == 0) return false;
   if(!m_position.SelectByTicket(ticket)) return false;

   double openP = m_position.PriceOpen();
   double pnl   = m_position.Profit() + m_position.Swap() + m_position.Commission();
   ENUM_POSITION_TYPE pType = m_position.PositionType();

   // Single TP — close on $-target
   if(pnl >= InpSingleTP_USD)
   {
      if(trade.PositionClose(ticket))
      {
         PrintFormat("Single TP hit: $%.2f >= $%.2f. L1 closed.", pnl, InpSingleTP_USD);
         g_currentBasketLot     = 0.0;
         g_singleTrailActive    = false;
         g_singleTrailWatermark = 0.0;
         return true;
      }
      LogTradeError("Single TP close");
   }

   // High-watermark trailing
   if(InpSingleUseTrailing)
   {
      double pip          = g_pointValue;
      double trailStartPx = InpSingleTrailStart * pip;
      double trailDistPx  = InpSingleTrailStop  * pip;
      double trailStepPx  = InpSingleTrailStep  * pip;
      double minStopPx    = PointsToPrice(g_stopsLevel);
      double freezeStopPx = PointsToPrice(g_freezeLevel);
      double bid          = m_symbol.Bid();
      double ask          = m_symbol.Ask();
      double sl           = m_position.StopLoss();
      double tp           = m_position.TakeProfit();

      if(pType == POSITION_TYPE_BUY)
      {
         // Update peak favorable price (highest bid seen)
         if(g_singleTrailWatermark <= 0.0 || bid > g_singleTrailWatermark)
            g_singleTrailWatermark = bid;

         double profitPx = g_singleTrailWatermark - openP;
         if(profitPx < trailStartPx) return false;

         double newSL = g_singleTrailWatermark - trailDistPx;
         double maxAllowedSL = bid - minStopPx;
         if(newSL > maxAllowedSL) newSL = maxAllowedSL;
         if(sl > 0 && MathAbs(bid - sl) < freezeStopPx) return false;

         if(sl == 0.0 || newSL > sl + trailStepPx)
         {
            newSL = NPrice(newSL);
            if(!trade.PositionModify(ticket, newSL, tp))
               LogTradeError(StringFormat("Single trail BUY #%I64u newSL=%.*f", ticket, g_digits, newSL));
            else
            {
               g_singleTrailActive = true;
               if(InpVerboseLogging)
                  PrintFormat("Single trail BUY: peak=%.*f SL=%.*f", g_digits, g_singleTrailWatermark, g_digits, newSL);
            }
         }
      }
      else if(pType == POSITION_TYPE_SELL)
      {
         // Update peak favorable price (lowest ask seen)
         if(g_singleTrailWatermark <= 0.0 || ask < g_singleTrailWatermark)
            g_singleTrailWatermark = ask;

         double profitPx = openP - g_singleTrailWatermark;
         if(profitPx < trailStartPx) return false;

         double newSL = g_singleTrailWatermark + trailDistPx;
         double minAllowedSL = ask + minStopPx;
         if(newSL < minAllowedSL) newSL = minAllowedSL;
         if(sl > 0 && MathAbs(ask - sl) < freezeStopPx) return false;

         if(sl == 0.0 || newSL < sl - trailStepPx)
         {
            newSL = NPrice(newSL);
            if(!trade.PositionModify(ticket, newSL, tp))
               LogTradeError(StringFormat("Single trail SELL #%I64u newSL=%.*f", ticket, g_digits, newSL));
            else
            {
               g_singleTrailActive = true;
               if(InpVerboseLogging)
                  PrintFormat("Single trail SELL: peak=%.*f SL=%.*f", g_digits, g_singleTrailWatermark, g_digits, newSL);
            }
         }
      }
   }
   return false;
}

//==================================================================//
// BASKET EXITS — applies ONLY when basket has >=2 layers            //
// [MODIFIED v2.03] Time-stop and ADX-fade exits removed entirely.   //
// Loss-side: BasketSL & EmergencyStop only. Profit-side: BasketTP.  //
//==================================================================//
bool CheckBasketExits()
{
   if(g_cachedPositionCount < 2) return false;

   // Basket TP — net profit hits target
   if(g_cachedBasketProfit >= InpBasketTP_USD)
   {
      CloseAllPositions(StringFormat("Basket TP hit: $%.2f >= $%.2f.",
                                     g_cachedBasketProfit, InpBasketTP_USD));
      return true;
   }

   // Basket SL — net loss hits limit; start cooldown
   if(g_cachedBasketProfit <= -InpBasketSL_USD)
   {
      CloseAllPositions(StringFormat("Basket SL hit: $%.2f <= -$%.2f. Cooldown %d min started.",
                                     g_cachedBasketProfit, InpBasketSL_USD, InpCooldownMinutes));
      SetCooldown(InpCooldownMinutes);
      return true;
   }

   return false;
}

// [REMOVED v2.03] CheckAsymmetricL2Exit() — feature removed by user request.

//==================================================================//
// Strip per-position SL/TP from L1 when basket activates             //
//==================================================================//
void StripL1ProtectionForBasket()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Magic()  != InpMagicNumber) continue;
      if(m_position.Symbol() != _Symbol)        continue;
      double sl = m_position.StopLoss();
      double tp = m_position.TakeProfit();
      if(sl == 0.0 && tp == 0.0) continue;
      if(!trade.PositionModify(m_position.Ticket(), 0.0, 0.0))
         LogTradeError(StringFormat("Strip L1 SL/TP #%I64u", m_position.Ticket()));
      else if(InpVerboseLogging)
         PrintFormat("L1 SL/TP stripped (basket mode): #%I64u", m_position.Ticket());
   }
   g_singleTrailActive    = false;
   g_singleTrailWatermark = 0.0;
}

//==================================================================//
// DAILY P/L TRACKING                                                 //
//==================================================================//
double CalculateDailyClosedPnL()
{
   double total = 0.0;
   if(!HistorySelect(g_dayStart, TimeCurrent())) return 0.0;
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      if(!m_deal.SelectByIndex(i)) continue;
      if(m_deal.Symbol() != _Symbol)       continue;
      if(m_deal.Magic()  != InpMagicNumber) continue;
      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)m_deal.Entry();
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT && entry != DEAL_ENTRY_OUT_BY)
         continue;
      total += m_deal.Profit() + m_deal.Commission() + m_deal.Swap();
   }
   return total;
}

void CheckDailyLimits()
{
   if(g_dailyLockout) return;
   bool targetHit = (InpDailyTarget > 0 && g_dailyClosedPnL >=  InpDailyTarget);
   bool lossHit   = (InpDailyLoss   > 0 && g_dailyClosedPnL <= -InpDailyLoss);
   if(!targetHit && !lossHit) return;

   g_dailyLockout = true;
   g_lockoutReason = targetHit
                     ? StringFormat("Daily Target Hit: $%.2f >= $%.2f", g_dailyClosedPnL, InpDailyTarget)
                     : StringFormat("Daily Loss Hit: $%.2f <= -$%.2f", g_dailyClosedPnL, InpDailyLoss);
   PrintFormat(">>> DAILY LOCKOUT: %s", g_lockoutReason);

   if(InpCloseOnDaily && CountOpenPositionsLive() > 0)
      CloseAllPositions(StringFormat("DAILY LOCKOUT: %s", g_lockoutReason));
}

void CheckDailyReset()
{
   int currKey = DayKeyFromTime(TimeCurrent());
   if(g_lastDayKey != currKey)
   {
      MqlDateTime t; TimeCurrent(t);
      g_lastDayKey     = currKey;
      g_dayStart       = GetDayStart(TimeCurrent());
      g_dailyLockout   = false;
      g_lockoutReason  = "";
      g_dailyClosedPnL = 0.0;
      PrintFormat(">>> NEW DAY: %04d-%02d-%02d | Daily counters reset.", t.year, t.mon, t.day);
   }
}

//==================================================================//
// ENTRY FILTERS                                                      //
//==================================================================//
bool ADX_Strong()
{
   if(!InpUseADX_Filter) return true;
   if(g_hADX_M5 == INVALID_HANDLE) return false;
   return GetBufferValue(g_hADX_M5, 1) >= (double)InpADX_Min;
}

// Hedge confirmation: ADX above entry minimum AND rising
bool ADX_RisingAndStrong()
{
   if(g_hADX_M5 == INVALID_HANDLE) return false;
   double a1 = GetBufferValue(g_hADX_M5, 1);
   double a2 = GetBufferValue(g_hADX_M5, 2);
   if(a1 <= 0 || a2 <= 0) return false;
   if(a1 < (double)InpADX_Min) return false;
   return (a1 >= a2);
}

//==================================================================//
// SIGNAL — Fibo zone (ADX-confirmed)                                //
// Returns: +1 BUY, -1 SELL, 0 none.                                 //
//==================================================================//
int DetectFiboSignal()
{
   if(Bars(_Symbol, PERIOD_M5) < InpFiboPeriod + 5) return 0;

   int hiIdx = iHighest(_Symbol, PERIOD_M5, MODE_HIGH, InpFiboPeriod, 1);
   int loIdx = iLowest (_Symbol, PERIOD_M5, MODE_LOW,  InpFiboPeriod, 1);
   if(hiIdx < 0 || loIdx < 0) return 0;

   double high = GetHigh(PERIOD_M5, hiIdx);
   double low  = GetLow (PERIOD_M5, loIdx);
   if(high <= 0 || low <= 0 || high <= low) return 0;

   double range     = high - low;
   double upperZone = high - (range * InpFiboUpperLevel);
   double lowerZone = high - (range * InpFiboLowerLevel);

   double ask = m_symbol.Ask();

   bool sellSignal = (ask >= upperZone);
   bool buySignal  = (ask <= lowerZone);

   if(InpDirFilter == DIR_BUY_ONLY)  sellSignal = false;
   if(InpDirFilter == DIR_SELL_ONLY) buySignal  = false;

   if(!buySignal && !sellSignal)
   {
      if(InpVerboseLogging)
         PrintFormat("Fibo scan: ask=%.*f upper=%.*f lower=%.*f (no zone)",
                     g_digits, ask, g_digits, upperZone, g_digits, lowerZone);
      return 0;
   }

   if(!ADX_Strong())
   {
      if(InpVerboseLogging) PrintFormat("Fibo signal blocked by ADX < %d", InpADX_Min);
      return 0;
   }

   if(buySignal)  return +1;
   if(sellSignal) return -1;
   return 0;
}

//==================================================================//
// EXECUTE INITIAL ENTRY (Layer 1)                                    //
//==================================================================//
void ExecuteInitialEntry(int dir)
{
   g_currentBasketLot = CalculateDynamicLot();
   double lot = CalculateLayerLot(1, 0.0);
   string cmt = (dir > 0) ? (InpOrderComment + " BUY L1 (Fibo)")
                          : (InpOrderComment + " SELL L1 (Fibo)");

   if(dir > 0)
   {
      double ask = m_symbol.Ask();
      if(!trade.Buy(lot, _Symbol, ask, 0, 0, cmt))
         LogTradeError("Buy (Fibo Entry L1)");
      else
      {
         g_singleTrailWatermark = ask;
         g_singleTrailActive    = false;
         if(InpVerboseLogging)
            PrintFormat("BUY L1 @ %.*f | lot=%.2f", g_digits, ask, lot);
      }
   }
   else if(dir < 0)
   {
      double bid = m_symbol.Bid();
      if(!trade.Sell(lot, _Symbol, bid, 0, 0, cmt))
         LogTradeError("Sell (Fibo Entry L1)");
      else
      {
         g_singleTrailWatermark = bid;
         g_singleTrailActive    = false;
         if(InpVerboseLogging)
            PrintFormat("SELL L1 @ %.*f | lot=%.2f", g_digits, bid, lot);
      }
   }
}

//==================================================================//
// HEDGE RECOVERY — ATR×Mult adverse + ADX confirmation               //
// Each new layer is OPPOSITE the most-recent fill (always SMART).    //
//==================================================================//
void ManageHedgeRecovery()
{
   int total = g_cachedPositionCount;
   if(total <= 0)              return;
   if(total >= InpMaxOrders)   return;
   if(!IsSpreadAcceptable())   return;

   double lastPrice           = g_cachedLastPrice;
   ENUM_POSITION_TYPE lastDir = g_cachedLastDirection;
   double lastLot             = g_cachedLastLot;
   if(lastPrice <= 0.0)                   return;
   if(lastDir == INVALID_DIRECTION_VAL)   return;

   // Dynamic step from ATR
   double atr = GetBufferValue(g_hATR_M5, 1);
   if(atr <= 0)
   {
      if(InpVerboseLogging) Print("Hedge: ATR not ready, skipping evaluation.");
      return;
   }
   double stepPrice = atr * InpHedgeATRMult;

   double ask = m_symbol.Ask();
   double bid = m_symbol.Bid();
   int newLayerIdx = total + 1;

   ENUM_POSITION_TYPE newLayerDir = (lastDir == POSITION_TYPE_BUY) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;

   // Trigger geometry: last fill must be losing by stepPrice
   bool triggered = false;
   if(lastDir == POSITION_TYPE_BUY)  triggered = (ask <= lastPrice - stepPrice);
   else                              triggered = (bid >= lastPrice + stepPrice);

   if(InpVerboseLogging)
   {
      bool refIsBuy = (lastDir == POSITION_TYPE_BUY);
      double distAdverse = refIsBuy ? (lastPrice - ask) : (bid - lastPrice);
      if(distAdverse > stepPrice * 0.8)
         PrintFormat("Hedge eval: lastPx=%.*f ask=%.*f bid=%.*f ATR=%.*f stepPx=%.*f adv=%.*f trig=%s",
                     g_digits, lastPrice, g_digits, ask, g_digits, bid,
                     g_digits, atr, g_digits, stepPrice, g_digits, distAdverse,
                     triggered ? "YES" : "no");
   }
   if(!triggered) return;

   // Gate 1: basket must be net negative
   if(g_cachedBasketProfit >= 0.0)
   {
      if(InpVerboseLogging)
         PrintFormat("Hedge: trigger met but basket P&L=$%.2f >= 0. Skip.", g_cachedBasketProfit);
      return;
   }

   // Gate 2: ADX strong AND rising (if enabled)
   if(InpHedgeRequireTrend && !ADX_RisingAndStrong())
   {
      if(InpVerboseLogging)
      {
         double a1 = GetBufferValue(g_hADX_M5, 1);
         double a2 = GetBufferValue(g_hADX_M5, 2);
         PrintFormat("Hedge: trend confirm failed. ADX[1]=%.1f ADX[2]=%.1f Min=%d. Skip.",
                     a1, a2, InpADX_Min);
      }
      return;
   }

   double lotNorm = CalculateLayerLot(newLayerIdx, lastLot);
   string cmt;

   if(newLayerDir == POSITION_TYPE_BUY)
   {
      cmt = StringFormat("%s BUY L%d (Hedge)", InpOrderComment, newLayerIdx);
      if(!trade.Buy(lotNorm, _Symbol, ask, 0, 0, cmt))
         LogTradeError(StringFormat("Buy (Hedge L%d)", newLayerIdx));
      else
      {
         if(InpVerboseLogging)
            PrintFormat("Hedge BUY L%d @ %.*f | lot=%.2f | step=%.*f (ATR×%.2f)",
                        newLayerIdx, g_digits, ask, lotNorm, g_digits, stepPrice, InpHedgeATRMult);
         if(total == 1) StripL1ProtectionForBasket();
      }
   }
   else
   {
      cmt = StringFormat("%s SELL L%d (Hedge)", InpOrderComment, newLayerIdx);
      if(!trade.Sell(lotNorm, _Symbol, bid, 0, 0, cmt))
         LogTradeError(StringFormat("Sell (Hedge L%d)", newLayerIdx));
      else
      {
         if(InpVerboseLogging)
            PrintFormat("Hedge SELL L%d @ %.*f | lot=%.2f | step=%.*f (ATR×%.2f)",
                        newLayerIdx, g_digits, bid, lotNorm, g_digits, stepPrice, InpHedgeATRMult);
         if(total == 1) StripL1ProtectionForBasket();
      }
   }
}

//==================================================================//
// MAIN ENTRY MANAGER                                                 //
//==================================================================//
void ManageEntry()
{
   if(!IsTradingTime()) return;

   if(g_cachedPositionCount == 0)
   {
      if(IsInCooldown())
      {
         // Non-destructive bar check so cooldown logging doesn't consume
         // the new-bar event the entry-signal needs.
         static datetime lastCooldownLogBar = 0;
         datetime curBar = iTime(_Symbol, PERIOD_M5, 0);
         if(InpVerboseLogging && curBar != lastCooldownLogBar)
         {
            lastCooldownLogBar = curBar;
            PrintFormat("Cooldown active until %s — skipping entry.",
                        TimeToString(g_cooldownUntil, TIME_DATE|TIME_MINUTES));
         }
         return;
      }
      if(!IsNewBar()) return;
      int sig = DetectFiboSignal();
      if(sig == 0) return;
      ExecuteInitialEntry(sig);
   }
   else
   {
      ManageHedgeRecovery();
   }
}

//==================================================================//
// INDICATOR HANDLES                                                  //
//==================================================================//
bool CreateIndicatorHandles()
{
   g_hADX_M5 = iADX(_Symbol, PERIOD_M5, InpADX_Period);
   if(g_hADX_M5 == INVALID_HANDLE) { Print("Failed to create ADX M5 handle"); return false; }

   g_hATR_M5 = iATR(_Symbol, PERIOD_M5, InpHedgeATR_Period);
   if(g_hATR_M5 == INVALID_HANDLE) { Print("Failed to create ATR M5 handle"); return false; }

   return true;
}

void ReleaseIndicatorHandles()
{
   if(g_hADX_M5 != INVALID_HANDLE) IndicatorRelease(g_hADX_M5);
   if(g_hATR_M5 != INVALID_HANDLE) IndicatorRelease(g_hATR_M5);
}

//==================================================================//
// DASHBOARD                                                          //
//==================================================================//
ENUM_BASE_CORNER GetCorner()
{
   switch(InpDashboardCorner)
   {
      case 0: return CORNER_LEFT_UPPER;
      case 1: return CORNER_RIGHT_UPPER;
      case 2: return CORNER_LEFT_LOWER;
      case 3: return CORNER_RIGHT_LOWER;
   }
   return CORNER_LEFT_UPPER;
}
ENUM_ANCHOR_POINT GetAnchor()
{
   switch(InpDashboardCorner)
   {
      case 0: return ANCHOR_LEFT_UPPER;
      case 1: return ANCHOR_RIGHT_UPPER;
      case 2: return ANCHOR_LEFT_LOWER;
      case 3: return ANCHOR_RIGHT_LOWER;
   }
   return ANCHOR_LEFT_UPPER;
}

void CreateRectLabel(string name, int xOff, int yOff, int width, int height, color clr)
{
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER,    GetCorner());
   ObjectSetInteger(0, name, OBJPROP_ANCHOR,    GetAnchor());
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, InpDashboardX + xOff);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, InpDashboardY + yOff);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,     width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,     height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,   clr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, name, OBJPROP_BACK,      false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,    true);
}

void CreateLabel(string name, int xOff, int yOff, string text, color clr, int fontSize=9, string font="Consolas")
{
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER,    GetCorner());
   ObjectSetInteger(0, name, OBJPROP_ANCHOR,    GetAnchor());
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, InpDashboardX + xOff);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, InpDashboardY + yOff);
   ObjectSetString (0, name, OBJPROP_TEXT,      text);
   ObjectSetInteger(0, name, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,  fontSize);
   ObjectSetString (0, name, OBJPROP_FONT,      font);
   ObjectSetInteger(0, name, OBJPROP_BACK,      false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,    true);
}

void SetLabelText(string name, string text, color clr=clrNONE)
{
   if(ObjectFind(0, name) < 0) return;
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   if(clr != clrNONE) ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

string MakeProgressBar(double value, double maxValue, int barLength=10)
{
   if(maxValue <= 0) return "[----------] 0%";
   double pct = MathAbs(value / maxValue) * 100.0;
   if(pct > 100.0) pct = 100.0;
   if(pct < 0.0)   pct = 0.0;
   int filled = (int)MathRound((pct / 100.0) * barLength);
   if(filled > barLength) filled = barLength;
   if(filled < 0) filled = 0;
   string bar = "[";
   for(int i = 0; i < barLength; i++) bar += (i < filled ? "#" : "-");
   bar += StringFormat("] %.0f%%", pct);
   return bar;
}

void DeleteDashboard()
{
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, DASH_PREFIX) == 0) ObjectDelete(0, name);
   }
   ChartRedraw();
}

void CreateDashboard()
{
   DeleteDashboard();
   int totalHeight = 14 * DASH_LINE_HEIGHT + DASH_PADDING * 2 + 40;
   CreateRectLabel(DASH_PREFIX + "BG_MAIN",   0, 0, DASH_WIDTH, totalHeight, COLOR_BG_MAIN);
   CreateRectLabel(DASH_PREFIX + "BG_HEADER", 0, 0, DASH_WIDTH, 32, COLOR_BG_HEADER);
   CreateLabel(DASH_PREFIX + "TITLE", DASH_PADDING, 8, "MC HEDGE M5 v2.03", COLOR_TEXT_MAIN, 11, "Consolas Bold");
   CreateLabel(DASH_PREFIX + "STATUS_DOT", DASH_WIDTH - 70, 8, "* LIVE", COLOR_ACTIVE, 10, "Consolas Bold");

   int y = 40;
   CreateLabel(DASH_PREFIX + "STATUS_LBL", DASH_PADDING, y, "STATUS", COLOR_HEADER, 9, "Consolas Bold");
   CreateLabel(DASH_PREFIX + "STATUS_VAL", DASH_PADDING+90, y, "...", COLOR_TEXT_MAIN); y += DASH_LINE_HEIGHT;

   CreateLabel(DASH_PREFIX + "SES_LBL", DASH_PADDING, y, "SESSION", COLOR_HEADER);
   CreateLabel(DASH_PREFIX + "SES_VAL", DASH_PADDING+90, y, "...", COLOR_TEXT_MAIN); y += DASH_LINE_HEIGHT;

   CreateLabel(DASH_PREFIX + "SPR_LBL", DASH_PADDING, y, "SPREAD", COLOR_HEADER);
   CreateLabel(DASH_PREFIX + "SPR_VAL", DASH_PADDING+90, y, "...", COLOR_TEXT_MAIN); y += DASH_LINE_HEIGHT;

   y += 6;
   CreateLabel(DASH_PREFIX + "BAL_LBL", DASH_PADDING, y, "BALANCE", COLOR_HEADER);
   CreateLabel(DASH_PREFIX + "BAL_VAL", DASH_PADDING+90, y, "...", COLOR_TEXT_MAIN); y += DASH_LINE_HEIGHT;

   CreateLabel(DASH_PREFIX + "EQ_LBL", DASH_PADDING, y, "EQUITY", COLOR_HEADER);
   CreateLabel(DASH_PREFIX + "EQ_VAL", DASH_PADDING+90, y, "...", COLOR_TEXT_MAIN); y += DASH_LINE_HEIGHT;

   y += 6;
   CreateLabel(DASH_PREFIX + "DPNL_LBL", DASH_PADDING, y, "DAILY P/L", COLOR_HEADER);
   CreateLabel(DASH_PREFIX + "DPNL_VAL", DASH_PADDING+90, y, "...", COLOR_TEXT_MAIN); y += DASH_LINE_HEIGHT;

   CreateLabel(DASH_PREFIX + "TGT_LBL", DASH_PADDING, y, "TARGET", COLOR_HEADER);
   CreateLabel(DASH_PREFIX + "TGT_BAR", DASH_PADDING+90, y, "...", COLOR_PROGRESS); y += DASH_LINE_HEIGHT;

   y += 6;
   CreateLabel(DASH_PREFIX + "DIR_LBL", DASH_PADDING, y, "POSITION", COLOR_HEADER);
   CreateLabel(DASH_PREFIX + "DIR_VAL", DASH_PADDING+90, y, "...", COLOR_TEXT_MAIN); y += DASH_LINE_HEIGHT;

   CreateLabel(DASH_PREFIX + "LOT_LBL", DASH_PADDING, y, "LOT", COLOR_HEADER);
   CreateLabel(DASH_PREFIX + "LOT_VAL", DASH_PADDING+90, y, "...", COLOR_TEXT_MAIN); y += DASH_LINE_HEIGHT;

   CreateLabel(DASH_PREFIX + "BPNL_LBL", DASH_PADDING, y, "BASKET P/L", COLOR_HEADER);
   CreateLabel(DASH_PREFIX + "BPNL_VAL", DASH_PADDING+90, y, "...", COLOR_TEXT_MAIN); y += DASH_LINE_HEIGHT;

   CreateLabel(DASH_PREFIX + "BTGT_LBL", DASH_PADDING, y, "B-TGT", COLOR_HEADER);
   CreateLabel(DASH_PREFIX + "BTGT_BAR", DASH_PADDING+90, y, "...", COLOR_PROGRESS); y += DASH_LINE_HEIGHT;

   y += 6;
   CreateLabel(DASH_PREFIX + "FOOTER", DASH_PADDING, y, "...", COLOR_TEXT_DIM);
   ChartRedraw();
}

void UpdateDashboard()
{
   int    total      = g_cachedPositionCount;
   double basketPnL  = g_cachedBasketProfit;
   ENUM_POSITION_TYPE dir = g_cachedDirection;
   long   spread     = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity     = AccountInfoDouble(ACCOUNT_EQUITY);

   string statusText = "ACTIVE (L1)"; color statusColor = COLOR_ACTIVE;
   if(total >= 2)
   {
      statusText  = StringFormat("BASKET (%d)", total);
      statusColor = COLOR_WARNING;
   }
   else if(total == 0)
   {
      statusText  = "SCANNING";
      statusColor = COLOR_TEXT_DIM;
   }
   if(IsInCooldown())
   {
      int secsLeft = (int)(g_cooldownUntil - TimeCurrent());
      statusText  = StringFormat("COOLDOWN %dm%ds", secsLeft/60, secsLeft%60);
      statusColor = COLOR_STOPPED;
   }
   if(g_dailyLockout)        { statusText = "HALTED (Daily)"; statusColor = COLOR_STOPPED; }
   else if(!IsTradingTime()) { statusText = "OFF-HOURS";      statusColor = COLOR_WARNING; }
   SetLabelText(DASH_PREFIX + "STATUS_VAL", statusText, statusColor);
   SetLabelText(DASH_PREFIX + "STATUS_DOT",
                (g_dailyLockout || IsInCooldown()) ? "* HALT" : "* LIVE",
                (g_dailyLockout || IsInCooldown()) ? COLOR_STOPPED : COLOR_ACTIVE);

   bool tradingTime = IsTradingTime();
   SetLabelText(DASH_PREFIX + "SES_VAL",
                StringFormat("%s (%02d-%02d)", (tradingTime ? "OPEN" : "CLOSED"), InpStartHour, InpEndHour),
                (tradingTime ? COLOR_PROFIT : COLOR_TEXT_DIM));

   color sprColor = COLOR_PROFIT; string sprStatus = "OK";
   if(InpMaxSpreadPts > 0 && spread > InpMaxSpreadPts) { sprColor = COLOR_LOSS; sprStatus = "HIGH"; }
   else if(InpMaxSpreadPts > 0 && spread > InpMaxSpreadPts * 0.7) { sprColor = COLOR_WARNING; sprStatus = "WARN"; }
   SetLabelText(DASH_PREFIX + "SPR_VAL", StringFormat("%d pts (%s)", (int)spread, sprStatus), sprColor);

   SetLabelText(DASH_PREFIX + "BAL_VAL", StringFormat("$%.2f", balance), COLOR_TEXT_MAIN);
   color eqColor = (equity >= balance) ? COLOR_PROFIT : COLOR_LOSS;
   SetLabelText(DASH_PREFIX + "EQ_VAL", StringFormat("$%.2f", equity), eqColor);

   color pnlColor = (g_dailyClosedPnL >= 0) ? COLOR_PROFIT : COLOR_LOSS;
   string pnlText = StringFormat("%s$%.2f", (g_dailyClosedPnL >= 0 ? "+" : "-"), MathAbs(g_dailyClosedPnL));
   SetLabelText(DASH_PREFIX + "DPNL_VAL", pnlText, pnlColor);

   if(InpDailyTarget > 0)
      SetLabelText(DASH_PREFIX + "TGT_BAR",
                   MakeProgressBar(MathMax(0,g_dailyClosedPnL), InpDailyTarget, 10), COLOR_PROGRESS);
   else
      SetLabelText(DASH_PREFIX + "TGT_BAR", "DISABLED", COLOR_TEXT_DIM);

   string dirText = "FLAT"; color dirColor = COLOR_TEXT_DIM;
   if(dir == POSITION_TYPE_BUY)  { dirText = "BUY";  dirColor = COLOR_PROFIT; }
   if(dir == POSITION_TYPE_SELL) { dirText = "SELL"; dirColor = COLOR_LOSS; }
   SetLabelText(DASH_PREFIX + "DIR_VAL", StringFormat("%s (%d)", dirText, total), dirColor);

   double dispLot = (total > 0) ? 0.0 : CalculateDynamicLot();
   if(total > 0)
   {
      double sum = 0;
      for(int i = PositionsTotal()-1; i >= 0; i--)
         if(m_position.SelectByIndex(i))
            if(m_position.Magic() == InpMagicNumber && m_position.Symbol() == _Symbol)
               sum += m_position.Volume();
      dispLot = sum;
   }
   string lotMode = InpUseDynamicLot ? "DYNAMIC" : "FIXED";
   SetLabelText(DASH_PREFIX + "LOT_VAL",
                StringFormat("%.2f (%s)", dispLot, lotMode), COLOR_TEXT_MAIN);

   color bpnlColor = (basketPnL >= 0) ? COLOR_PROFIT : COLOR_LOSS;
   string bpnlText = StringFormat("%s$%.2f", (basketPnL >= 0 ? "+" : "-"), MathAbs(basketPnL));
   SetLabelText(DASH_PREFIX + "BPNL_VAL", bpnlText, bpnlColor);

   double progTgt = (total >= 2) ? InpBasketTP_USD : InpSingleTP_USD;
   SetLabelText(DASH_PREFIX + "BTGT_BAR",
                MakeProgressBar(MathMax(0,basketPnL), progTgt, 10), COLOR_PROGRESS);

   MqlDateTime t; TimeCurrent(t);
   SetLabelText(DASH_PREFIX + "FOOTER",
                StringFormat("%02d:%02d:%02d  Magic:%I64u", t.hour, t.min, t.sec, InpMagicNumber),
                COLOR_TEXT_DIM);

   ChartRedraw();
}

//==================================================================//
// EVENT HANDLERS                                                     //
//==================================================================//
int OnInit()
{
   ENUM_ACCOUNT_MARGIN_MODE mm = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(mm != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      Alert("MC_Hedge_M5 v2.03: Hedging account REQUIRED. Init failed.");
      return INIT_FAILED;
   }

   if(!m_symbol.Name(_Symbol))
   {
      Print("ERROR: Failed to initialize symbol info for ", _Symbol);
      return INIT_FAILED;
   }

   if(!ValidateInputs())        return INIT_PARAMETERS_INCORRECT;
   if(!CacheSymbolProperties()) { Print("ERROR: Symbol caching failed."); return INIT_FAILED; }
   if(!CreateIndicatorHandles()) return INIT_FAILED;

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetDeviationInPoints(InpSlippage);

   g_lastBarTime    = iTime(_Symbol, PERIOD_M5, 0);
   g_lastDayKey     = DayKeyFromTime(TimeCurrent());
   g_dayStart       = GetDayStart(TimeCurrent());
   g_dailyLockout   = false;
   g_lockoutReason  = "";
   g_dailyClosedPnL = CalculateDailyClosedPnL();

   // Persisted cooldown (survives recompile / reattach)
   g_cooldownGV    = StringFormat("MC_HEDGE_M5_CD_%I64u", InpMagicNumber);
   g_cooldownUntil = 0;
   LoadCooldownFromGV();

   g_singleTrailActive    = false;
   g_singleTrailWatermark = 0.0;
   g_currentBasketLot     = 0.0;

   if(InpShowDashboard) CreateDashboard();
   EventSetTimer(5);   // 5s timer for dashboard refresh only

   PrintFormat("MC_Hedge_M5 v2.03: ONLINE | Symbol=%s | StopsLevel=%d | Digits=%d | Magic=%I64u",
               _Symbol, g_stopsLevel, g_digits, InpMagicNumber);
   PrintFormat("Volume: Min=%.2f Max=%.2f Step=%.2f", g_volMin, g_volMax, g_volStep);
   PrintFormat("Single L1: TP=$%.2f Trail=%s (start=%d, dist=%d, step=%d) high-watermark anchored",
               InpSingleTP_USD,
               InpSingleUseTrailing ? "ON" : "OFF",
               InpSingleTrailStart, InpSingleTrailStop, InpSingleTrailStep);
   PrintFormat("Basket: TP=$%.2f SL=$%.2f Cooldown=%dm | Emerg=$%.2f | WeekendClose=%s @Fri %d:00",
               InpBasketTP_USD, InpBasketSL_USD, InpCooldownMinutes, InpEmergencyStop,
               InpCloseBeforeWeekend ? "ON" : "OFF", InpWeekendCloseHour);
   // [REMOVED v2.03] Asym L2 / Time stop / ADX-fade summary line
   PrintFormat("Daily: TP=$%.2f SL=$%.2f (NET REALIZED only)", InpDailyTarget, InpDailyLoss);
   PrintFormat("Fibo: Period=%d Upper=%.3f Lower=%.3f | ADX_Filter=%s (min %d)",
               InpFiboPeriod, InpFiboUpperLevel, InpFiboLowerLevel,
               InpUseADX_Filter ? "ON" : "OFF", InpADX_Min);
   PrintFormat("Hedge: MaxOrders=%d ATR×%.2f (period %d) TrendConfirm=%s Mult=%.2f LotCap=%.2f",
               InpMaxOrders, InpHedgeATRMult, InpHedgeATR_Period,
               InpHedgeRequireTrend ? "ON" : "OFF", InpHedgeMultiplier, InpMaxLayerLot);
   if(g_cooldownUntil > TimeCurrent())
      PrintFormat("Cooldown active (restored): until %s",
                  TimeToString(g_cooldownUntil, TIME_DATE|TIME_MINUTES));

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteDashboard();
   ReleaseIndicatorHandles();
   PrintFormat("MC_Hedge_M5 v2.03: Shutting down. Reason code=%d", reason);
}

void OnTimer()
{
   // Dashboard refresh only — daily P&L is event-driven via OnTradeTransaction
   if(InpShowDashboard)
   {
      BuildCache();
      UpdateDashboard();
   }
}

//==================================================================//
// Trade-event-driven daily P&L update                               //
//==================================================================//
void OnTradeTransaction(const MqlTradeTransaction &trans,
                       const MqlTradeRequest &request,
                       const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;

   ulong dealTicket = trans.deal;
   if(dealTicket == 0) return;
   if(!HistoryDealSelect(dealTicket)) return;
   if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) return;
   if((ulong)HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != InpMagicNumber) return;

   ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT && entry != DEAL_ENTRY_OUT_BY)
      return;

   // Recompute and re-check daily limits (event-driven; no 1s rescan)
   g_dailyClosedPnL = CalculateDailyClosedPnL();
   CheckDailyLimits();
}

void OnTick()
{
   if(!m_symbol.RefreshRates()) return;

   BuildCache();

   // 1. Daily reset must run first
   CheckDailyReset();

   // 2. Weekend close
   if(IsFridayWeekendCloseTime())
   {
      if(g_cachedPositionCount > 0)
         CloseAllPositions("WEEKEND: Closing all before market close.");
      return;
   }

   // 3. Hard emergency stop
   if(CheckEmergencyExits()) return;

   // 4. Basket exits (TP/SL only — time-stop & ADX-fade removed v2.03)
   if(CheckBasketExits())
   {
      // Race-window fix: re-check daily lockout immediately after a basket
      // close so next tick can't slip a fresh L1 in.
      g_dailyClosedPnL = CalculateDailyClosedPnL();
      CheckDailyLimits();
      return;
   }

   // [REMOVED v2.03] Step 5 (Asymmetric L2 exit) deleted.

   // 5. Single-trade exits (TP + watermark trail) — only when exactly 1 layer
   CheckSingleTradeExits();

   // 6. Halt new entries if daily locked
   if(g_dailyLockout) return;

   // 7. Spread gate (single check per tick)
   if(!IsSpreadAcceptable())
   {
      if(InpVerboseLogging && !g_spreadBlocked)
         PrintFormat("Spread too high. Skipping.");
      g_spreadBlocked = true;
      return;
   }
   g_spreadBlocked = false;

   // 8. Entry dispatch
   ManageEntry();
}
//+------------------------------------------------------------------+
