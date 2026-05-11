//+------------------------------------------------------------------+
//|                                                   Indicators.mqh |
//|     Wraps indicator handle creation & latest-value readers.      |
//+------------------------------------------------------------------+
#ifndef __HGEA_INDICATORS_MQH__
#define __HGEA_INDICATORS_MQH__

#include "Inputs.mqh"
#include "Utils.mqh"

//--- Global handles (created once in OnInit) ----------------------
int g_hATR       = INVALID_HANDLE;
int g_hEmaFast   = INVALID_HANDLE;
int g_hEmaSlow   = INVALID_HANDLE;
int g_hRSI       = INVALID_HANDLE;
int g_hBB        = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Create all indicator handles. Returns true on success.           |
//+------------------------------------------------------------------+
bool CreateIndicatorHandles(const string symbol)
  {
   g_hATR = iATR(symbol, g_ATRTimeframe, g_ATRPeriod);
   if(g_hATR == INVALID_HANDLE)
     {
      VLog(StringFormat("iATR failed, err=%d", GetLastError()));
      return(false);
     }

   g_hEmaFast = iMA(symbol, g_TrendTimeframe, g_TrendEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   if(g_hEmaFast == INVALID_HANDLE)
     {
      VLog(StringFormat("iMA fast failed, err=%d", GetLastError()));
      return(false);
     }

   g_hEmaSlow = iMA(symbol, g_TrendTimeframe, g_TrendEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   if(g_hEmaSlow == INVALID_HANDLE)
     {
      VLog(StringFormat("iMA slow failed, err=%d", GetLastError()));
      return(false);
     }

   g_hRSI = iRSI(symbol, PERIOD_CURRENT, g_RSIPeriod, PRICE_CLOSE);
   if(g_hRSI == INVALID_HANDLE)
     {
      VLog(StringFormat("iRSI failed, err=%d", GetLastError()));
      return(false);
     }

   g_hBB = iBands(symbol, PERIOD_CURRENT, g_BBPeriod, 0, g_BBDeviation, PRICE_CLOSE);
   if(g_hBB == INVALID_HANDLE)
     {
      VLog(StringFormat("iBands failed, err=%d", GetLastError()));
      return(false);
     }

   return(true);
  }

//+------------------------------------------------------------------+
//| Release all indicator handles. Safe to call in OnDeinit.         |
//+------------------------------------------------------------------+
void ReleaseIndicatorHandles()
  {
   if(g_hATR      != INVALID_HANDLE) { IndicatorRelease(g_hATR);     g_hATR     = INVALID_HANDLE; }
   if(g_hEmaFast  != INVALID_HANDLE) { IndicatorRelease(g_hEmaFast); g_hEmaFast = INVALID_HANDLE; }
   if(g_hEmaSlow  != INVALID_HANDLE) { IndicatorRelease(g_hEmaSlow); g_hEmaSlow = INVALID_HANDLE; }
   if(g_hRSI      != INVALID_HANDLE) { IndicatorRelease(g_hRSI);     g_hRSI     = INVALID_HANDLE; }
   if(g_hBB       != INVALID_HANDLE) { IndicatorRelease(g_hBB);      g_hBB      = INVALID_HANDLE; }
  }

//+------------------------------------------------------------------+
//| Read the last-completed-bar ATR value. Returns 0.0 on failure.   |
//|                                                                  |
//| NOTE: CopyBuffer(h,b,start_pos,count,out) copies chronologically |
//| into a non-series array: out[0] is the OLDEST of the range.      |
//| We pass start_pos=1 so we get the value at the last closed bar. |
//+------------------------------------------------------------------+
double GetATR()
  {
   double buf[];
   if(CopyBuffer(g_hATR, 0, 1, 1, buf) < 1)
      return(0.0);
   return(buf[0]);
  }

//+------------------------------------------------------------------+
//| Read fast/slow EMA for the last completed bar.                   |
//| Returns true on success.                                         |
//+------------------------------------------------------------------+
bool GetEMAValues(double &emaFast, double &emaSlow)
  {
   double bf[], bs[];
   if(CopyBuffer(g_hEmaFast, 0, 1, 1, bf) < 1) return(false);
   if(CopyBuffer(g_hEmaSlow, 0, 1, 1, bs) < 1) return(false);
   emaFast = bf[0];
   emaSlow = bs[0];
   return(true);
  }

//+------------------------------------------------------------------+
//| Read the last-completed-bar RSI value. Returns -1.0 on failure.  |
//+------------------------------------------------------------------+
double GetRSI()
  {
   double buf[];
   if(CopyBuffer(g_hRSI, 0, 1, 1, buf) < 1)
      return(-1.0);
   return(buf[0]);
  }

//+------------------------------------------------------------------+
//| Read Bollinger upper/lower/middle for the last completed bar.    |
//|  iBands buffers: 0=base/middle, 1=upper, 2=lower                 |
//+------------------------------------------------------------------+
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

#endif // __HGEA_INDICATORS_MQH__
//+------------------------------------------------------------------+
