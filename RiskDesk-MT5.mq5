//+------------------------------------------------------------------+
//|                                                RiskDesk-MT5.mq5  |
//|                              Copyright 2024-2026, Keiwan         |
//|                              https://t.me/keiwan_k99             |
//+------------------------------------------------------------------+
#property copyright "Keiwan"
#property link      "https://t.me/keiwan_k99"
#property version   "1.0"
#property description "RiskDesk-MT5 - Professional risk & trade management panel"
#property description "for MetaTrader 5. Position sizing, drag-and-drop level"
#property description "management, pending orders, break-even, trailing stop,"
#property description "partial closes, and daily loss protection."
#property strict

#include <Trade/Trade.mqh>

#define ST_BE1   1
#define ST_BE2   2

#define PANEL_W       320
#define PAD           10
#define ROW_H         22
#define BTN_H         24
#define BIG_BTN_H     30
#define HEADER_H      18
#define SECTION_GAP   8

enum ENUM_RISK_MODE { RISK_PERCENT = 0, RISK_MONEY = 1 };
enum ENUM_RISK_BASE { BASE_BALANCE = 0, BASE_EQUITY = 1 };
enum ENUM_TRAIL_MODE { TRAIL_POINTS = 0, TRAIL_ATR = 1, TRAIL_CANDLE = 2 };
enum ENUM_RISK_SELECT { RSEL_PCT_BALANCE = 0, RSEL_PCT_EQUITY = 1, RSEL_FIXED = 2 };

input group "General"
input long            InpMagic            = 240901;
input bool            InpManageAll        = true;
input int             InpDeviation        = 20;
input string          InpComment          = "TM";
input int             InpMaxSpread        = 0;
input int             InpMaxOpenTrades    = 0;

input group "Risk"
input ENUM_RISK_MODE  InpRiskMode         = RISK_PERCENT;
input ENUM_RISK_BASE  InpRiskBase         = BASE_BALANCE;
input double          InpRiskValue        = 1.0;

input group "Default Levels"
input int             InpAtrPeriod        = 14;
input double          InpAtrMultiplier    = 1.5;
input double          InpFinalRR          = 3.0;

input group "Partial Take Profit"
input bool            InpPartialEnable    = true;
input double          InpTp1R             = 1.0;
input double          InpTp1Pct           = 50.0;
input double          InpTp2R             = 2.0;
input double          InpTp2Pct           = 25.0;

input group "Break Even"
input bool            InpBeEnable         = true;
input double          InpBe1TriggerR      = 1.0;
input double          InpBe1OffsetPoints  = 10.0;
input double          InpBe2TriggerR      = 2.0;
input double          InpBe2LockR         = 1.0;

input group "Trailing Stop"
input bool            InpTrailEnable      = false;
input ENUM_TRAIL_MODE InpTrailMode        = TRAIL_ATR;
input double          InpTrailStartR      = 1.5;
input double          InpTrailPoints      = 300.0;
input int             InpTrailAtrPeriod   = 14;
input double          InpTrailAtrMult     = 2.0;
input int             InpTrailCandles     = 3;
input double          InpTrailBufferPts   = 20.0;
input double          InpTrailStepPts     = 20.0;

input group "Manual Partial Close"
input double          InpManualClosePct   = 50.0;

input group "Protection"
input double          InpMaxDailyLossPct  = 0.0;
input bool            InpCloseOnLock      = true;
input int             InpFridayCloseHour  = -1;

input group "Performance"
input int             InpUiRefreshMs      = 100;
input int             InpCacheSweepMs     = 4000;

input group "Appearance"
input int             InpOffsetX          = 10;
input int             InpOffsetY          = 20;
input int             InpFontSize         = 9;
input string          InpFont             = "Segoe UI";
input color           InpTextColor        = C'220,225,235';
input color           InpMutedColor       = C'140,148,165';
input color           InpPanelColor       = C'22,26,34';
input color           InpHeaderColor      = C'30,36,48';
input color           InpButtonColor      = C'44,52,68';
input color           InpPopupColor       = C'34,40,52';
input color           InpPopupHover       = C'56,66,86';
input color           InpBuyColor         = C'34,120,210';
input color           InpSellColor        = C'200,64,54';
input color           InpAccentColor      = C'240,180,60';
input color           InpWarnColor        = C'240,150,50';
input color           InpOkColor          = C'70,200,120';
input color           InpEntryColor       = C'230,235,245';
input color           InpSlColor          = C'230,80,70';
input color           InpTpColor          = C'70,200,120';
input int             InpBoxHalfBars      = 6;

input group "Box Colors"
input color           InpZoneTpFill       = C'20,70,40';
input color           InpZoneTpBorder     = C'60,180,90';
input color           InpZoneSlFill       = C'80,25,25';
input color           InpZoneSlBorder     = C'220,70,60';

input group "Box Label Colors"
input color           InpTpLabelColor     = C'70,200,120';
input color           InpSlLabelColor     = C'230,80,70';

struct SizingResult
{
   bool   valid, isBuy, tpValid, belowMinLot, marginShort;
   double entry, sl, tp, distance, riskBudget, lots, actualRisk, reward, margin;
   double tp1Price, tp2Price, be1Price;
};

struct PosCache
{
   ulong  ticket;
   double sl;
   double vol;
   int    stage;
};

const string PFX          = "TM_";
const string OBJ_ENTRY    = "TM_ENTRY";
const string OBJ_SL       = "TM_SL";
const string OBJ_TP       = "TM_TP";
const string OBJ_BOX_TP   = "TM_BOX_TP";
const string OBJ_BOX_SL   = "TM_BOX_SL";
const string OBJ_LBL_TP   = "TM_LBL_TP";
const string OBJ_LBL_SL   = "TM_LBL_SL";
const string OBJ_BG       = "TM_BG";
const string OBJ_HDR      = "TM_HDR";
const string OBJ_TITLE    = "TM_TITLE";
const string OBJ_SYM      = "TM_SYM";
const string BTN_MIN      = "TM_BTN_MIN";
const string BTN_MODE     = "TM_BTN_MODE";
const string BTN_BUY      = "TM_BTN_BUY";
const string BTN_SELL     = "TM_BTN_SELL";
const string BTN_PEND     = "TM_BTN_PEND";
const string BTN_RESET    = "TM_BTN_RESET";
const string BTN_FLIP     = "TM_BTN_FLIP";
const string BTN_MOVEBE   = "TM_BTN_MOVEBE";
const string BTN_CLOSEALL = "TM_BTN_CLOSEALL";
const string BTN_CLOSEBUY = "TM_BTN_CLOSEBUY";
const string BTN_CLOSESEL = "TM_BTN_CLOSESELL";
const string BTN_DELPEND  = "TM_BTN_DELPEND";
const string BTN_APPLYPCT = "TM_BTN_APPLYPCT";
const string EDT_RISK     = "TM_EDT_RISK";
const string EDT_CLOSEPCT = "TM_EDT_CLOSEPCT";
const string LBL_RISK     = "TM_LBL_RISK";
const string LBL_STATUS   = "TM_LBL_STATUS";
const string LBL_DOT      = "TM_LBL_DOT";
const string SEC_RISK     = "TM_SEC_RISK";
const string SEC_TRADE    = "TM_SEC_TRADE";
const string SEC_POS      = "TM_SEC_POS";
const string SEC_STATUS   = "TM_SEC_STATUS";

const string BTN_MODE_ITEM0 = "TM_BTN_MODE_I0";
const string BTN_MODE_ITEM1 = "TM_BTN_MODE_I1";
const string BTN_MODE_ITEM2 = "TM_BTN_MODE_I2";

CTrade          trade;
int             g_atrHandle      = INVALID_HANDLE;
int             g_trailAtrHandle = INVALID_HANDLE;
bool            g_entryManual    = false;
bool            g_minimized      = false;
bool            g_beOn           = false;
bool            g_trailOn        = false;
bool            g_partialOn      = false;
bool            g_locked         = false;
bool            g_armed          = false;
bool            g_armedIsBuy     = true;
bool            g_armedPending   = false;
ENUM_RISK_MODE  g_riskMode       = RISK_PERCENT;
ENUM_RISK_BASE  g_riskBase       = BASE_BALANCE;
double          g_riskValue      = 1.0;
double          g_closePct       = 50.0;
int             g_dayKey         = 0;
double          g_dayEquity      = 0.0;
int             g_panelHeight    = 0;
string          g_status         = "";
datetime        g_statusTime     = 0;
string          g_objs[];
PosCache        g_cache[];
uint            g_lastUiMs       = 0;
uint            g_lastSweepMs    = 0;
bool            g_uiDirty        = true;
bool            g_modePopupOpen  = false;

double          g_origRiskDist   = 0.0;
double          g_origRewardDist = 0.0;

string          g_lastClosePctText = "";
string          g_lastModeBtnText  = "";
string          g_lastCloseBtnText = "";
string          g_lastStatusText   = "";
color           g_lastStatusColor  = clrNONE;
color           g_lastDotColor     = clrNONE;
ulong           g_cachedLogin      = 0;
string          g_cachedGKeyPrefix = "";

int LAYOUT_RISK_SEC   = 0;
int LAYOUT_RISK_ROW   = 0;
int LAYOUT_TRADE_SEC  = 0;
int LAYOUT_BUY_Y      = 0;
int LAYOUT_PEND_Y     = 0;
int LAYOUT_RESET_Y    = 0;
int LAYOUT_POS_SEC    = 0;
int LAYOUT_POS_ROW1   = 0;
int LAYOUT_POS_ROW2   = 0;
int LAYOUT_CLOSEPCT_Y = 0;
int LAYOUT_STATUS_SEC = 0;
int LAYOUT_INFO_Y     = 0;
int LAYOUT_STATS_Y    = 0;
int LAYOUT_STATUS_Y   = 0;
int g_infoCount       = 0;
int g_modeBtnX        = 0;
int g_modeBtnY        = 0;
int g_modeBtnW        = 0;

int OnInit()
{
   g_atrHandle      = iATR(_Symbol, _Period, InpAtrPeriod);
   g_trailAtrHandle = iATR(_Symbol, _Period, InpTrailAtrPeriod);
   if(g_atrHandle == INVALID_HANDLE || g_trailAtrHandle == INVALID_HANDLE)
      return INIT_FAILED;

   trade.SetExpertMagicNumber((ulong)InpMagic);
   trade.SetDeviationInPoints(InpDeviation);
   trade.SetTypeFillingBySymbol(_Symbol);

   g_beOn      = InpBeEnable;
   g_trailOn   = InpTrailEnable;
   g_partialOn = InpPartialEnable;
   g_riskMode  = InpRiskMode;
   g_riskBase  = InpRiskBase;
   g_riskValue = InpRiskValue;
   g_closePct  = InpManualClosePct;

   g_cachedLogin      = (ulong)AccountInfoInteger(ACCOUNT_LOGIN);
   g_cachedGKeyPrefix = PFX + IntegerToString((long)g_cachedLogin) + "_";

   LoadSettings();

   BuildPanel();
   ApplyMinimize();
   EventSetMillisecondTimer(50);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0, PFX);
   if(g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);
   if(g_trailAtrHandle != INVALID_HANDLE)
      IndicatorRelease(g_trailAtrHandle);
   ChartRedraw();
}

void OnTick()  { Tick(); }
void OnTimer() { Tick(); }

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_CLICK)
   {
      CommitClosePctEditOnBlur();
      return;
   }

   if(id == CHARTEVENT_OBJECT_DRAG)
   {
      const double entry = LinePrice(OBJ_ENTRY);
      const double sl    = LinePrice(OBJ_SL);
      const double tp    = LinePrice(OBJ_TP);

      if(sparam == OBJ_ENTRY)
      {
         g_entryManual = true;

         // Market-armed (tracking) → switch to pending on drag
         if(g_armed && !g_armedPending)
         {
            const double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            const bool   isBuy = (entry < ask);

            g_origRiskDist   = MathAbs(entry - sl);
            g_origRewardDist = MathAbs(tp - entry);

            if(isBuy != g_armedIsBuy && g_origRiskDist >= _Point)
            {
               const double dir   = isBuy ? 1.0 : -1.0;
               SetLinePrice(OBJ_SL, entry - dir * g_origRiskDist);
               SetLinePrice(OBJ_TP, entry + dir * (g_origRewardDist > 0.0
                                                   ? g_origRewardDist
                                                   : g_origRiskDist * InpFinalRR));
            }

            g_armedPending = true;
            g_armedIsBuy   = isBuy;
            Notify("Entry dragged - switched to PENDING mode");
         }
         else
         {
            Notify("Entry moved");
         }
      }
      else if(sparam == OBJ_SL)
      {
         g_origRiskDist = MathAbs(entry - sl);
         Notify("SL moved");
      }
      else if(sparam == OBJ_TP)
      {
         g_origRewardDist = MathAbs(tp - entry);
         Notify("TP moved");
      }
      MarkDirty();
      return;
   }

   if(id == CHARTEVENT_OBJECT_ENDEDIT && sparam == EDT_RISK)
   {
      const double value = StringToDouble(ObjectGetString(0, EDT_RISK, OBJPROP_TEXT));
      if(value > 0.0)
      {
         g_riskValue = value;
         SaveSettings();
      }
      ObjectSetString(0, EDT_RISK, OBJPROP_TEXT, DoubleToString(g_riskValue, 2));
      MarkDirty();
      return;
   }

   if(id == CHARTEVENT_OBJECT_ENDEDIT && sparam == EDT_CLOSEPCT)
   {
      CommitClosePctEdit();
      MarkDirty();
      return;
   }

   if(id == CHARTEVENT_OBJECT_CLICK && StringFind(sparam, "TM_BTN_") == 0)
   {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      HandleClick(sparam);
      MarkDirty();
   }
}

void MarkDirty() { g_uiDirty = true; }

void Tick()
{
   SyncClosePctLabel();

   Guard();
   ManagePositions();

   if(g_armed)
      EnsureDraggable();

   const uint now = GetTickCount();
   if(now - g_lastSweepMs >= (uint)InpCacheSweepMs)
   {
      g_lastSweepMs = now;
      SweepCache();
   }

   if(!g_armed)
      return;

   if(!LinesExist())
   {
      if(!InitLevels())
         return;
      g_uiDirty = true;
   }

   UpdateAutoEntry();
   UpdatePendingDirection();

   if(!g_uiDirty && now - g_lastUiMs < (uint)InpUiRefreshMs)
      return;

   g_lastUiMs = now;
   g_uiDirty  = false;
   Refresh();
}

string GKey(const string suffix)
{
   return g_cachedGKeyPrefix + suffix;
}

void SaveSettings()
{
   GlobalVariableSet(GKey("RISKVAL"),  g_riskValue);
   GlobalVariableSet(GKey("RISKMODE"), (double)g_riskMode);
   GlobalVariableSet(GKey("RISKBASE"), (double)g_riskBase);
   GlobalVariableSet(GKey("CLOSEPCT"), g_closePct);
}

void LoadSettings()
{
   if(GlobalVariableCheck(GKey("RISKVAL")))
      g_riskValue = GlobalVariableGet(GKey("RISKVAL"));
   if(GlobalVariableCheck(GKey("RISKMODE")))
      g_riskMode = (ENUM_RISK_MODE)(int)GlobalVariableGet(GKey("RISKMODE"));
   if(GlobalVariableCheck(GKey("RISKBASE")))
      g_riskBase = (ENUM_RISK_BASE)(int)GlobalVariableGet(GKey("RISKBASE"));
   if(GlobalVariableCheck(GKey("CLOSEPCT")))
      g_closePct = GlobalVariableGet(GKey("CLOSEPCT"));
}

string StateKey(const ulong ticket, const string field)
{
   return g_cachedGKeyPrefix + IntegerToString((long)ticket) + "_" + field;
}

void StateSetRaw(const ulong ticket, const string field, const double value)
{
   GlobalVariableSet(StateKey(ticket, field), value);
}

int CacheFind(const ulong ticket)
{
   for(int i = 0; i < ArraySize(g_cache); i++)
      if(g_cache[i].ticket == ticket)
         return i;
   return -1;
}

int CacheLoad(const ulong ticket, const double posSl, const double posVol)
{
   int idx = CacheFind(ticket);
   if(idx >= 0)
      return idx;

   const int n = ArraySize(g_cache);
   ArrayResize(g_cache, n + 1);
   g_cache[n].ticket = ticket;

   const string slKey = StateKey(ticket, "SL");
   if(GlobalVariableCheck(slKey))
   {
      g_cache[n].sl    = GlobalVariableGet(slKey);
      g_cache[n].vol   = GlobalVariableGet(StateKey(ticket, "VOL"));
      g_cache[n].stage = GlobalVariableCheck(StateKey(ticket, "ST")) ? (int)GlobalVariableGet(StateKey(ticket, "ST")) : 0;
   }
   else
   {
      g_cache[n].sl    = posSl;
      g_cache[n].vol   = posVol;
      g_cache[n].stage = 0;
      StateSetRaw(ticket, "SL", posSl);
      StateSetRaw(ticket, "VOL", posVol);
      StateSetRaw(ticket, "ST", 0.0);
   }

   if(g_cache[n].sl <= 0.0 && posSl > 0.0)
   {
      g_cache[n].sl = posSl;
      StateSetRaw(ticket, "SL", posSl);
   }

   return n;
}

void CacheSetStage(const int idx, const int stage)
{
   if(g_cache[idx].stage == stage)
      return;
   g_cache[idx].stage = stage;
   StateSetRaw(g_cache[idx].ticket, "ST", (double)stage);
}

void CacheRemove(const int idx)
{
   const ulong ticket = g_cache[idx].ticket;
   GlobalVariableDel(StateKey(ticket, "SL"));
   GlobalVariableDel(StateKey(ticket, "VOL"));
   GlobalVariableDel(StateKey(ticket, "ST"));

   const int last = ArraySize(g_cache) - 1;
   g_cache[idx] = g_cache[last];
   ArrayResize(g_cache, last);
}

void SweepCache()
{
   for(int i = ArraySize(g_cache) - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(g_cache[i].ticket))
         CacheRemove(i);
   }
}

double NormalizePrice(const double price) { return NormalizeDouble(price, _Digits); }
double LinePrice(const string name)       { return ObjectGetDouble(0, name, OBJPROP_PRICE); }

void SetLinePrice(const string name, const double price)
{
   const double norm = NormalizePrice(price);
   if(MathAbs(ObjectGetDouble(0, name, OBJPROP_PRICE) - norm) < _Point * 0.5)
      return;
   ObjectSetDouble(0, name, OBJPROP_PRICE, norm);
   MarkDirty();
}

bool LinesExist()
{
   return ObjectFind(0, OBJ_ENTRY) >= 0 && ObjectFind(0, OBJ_SL) >= 0 && ObjectFind(0, OBJ_TP) >= 0;
}

void CreateLine(const string name, const string text, const double price, const color clr,
                const ENUM_LINE_STYLE style, const bool interactive)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, NormalizePrice(price));

   ObjectSetDouble(0, name, OBJPROP_PRICE, NormalizePrice(price));
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, interactive ? 2 : 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, interactive);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, interactive);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, interactive ? -1 : -2);
}

void CreateBox(const string name, const color fill, const color border)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, 0, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_COLOR, border);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, fill);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, -3);
}

void CreateBoxLabel(const string name, const color clr)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 20);
   ObjectSetString(0, name, OBJPROP_TEXT, " ");
}

void HideTradeBox()
{
   const string names[] = {OBJ_ENTRY, OBJ_SL, OBJ_TP, OBJ_BOX_TP, OBJ_BOX_SL, OBJ_LBL_TP, OBJ_LBL_SL};
   for(int i = 0; i < ArraySize(names); i++)
      if(ObjectFind(0, names[i]) >= 0)
         ObjectSetInteger(0, names[i], OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
}

void ShowTradeBox()
{
   const string names[] = {OBJ_ENTRY, OBJ_SL, OBJ_TP, OBJ_BOX_TP, OBJ_BOX_SL, OBJ_LBL_TP, OBJ_LBL_SL};
   for(int i = 0; i < ArraySize(names); i++)
      if(ObjectFind(0, names[i]) >= 0)
         ObjectSetInteger(0, names[i], OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);

   EnsureDraggable();
}

bool InitLevels()
{
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(g_atrHandle, 0, 1, 1, atr) != 1 || atr[0] <= 0.0)
      return false;

   const double entry    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double distance = atr[0] * InpAtrMultiplier;

   CreateLine(OBJ_ENTRY, "ENTRY", entry, InpEntryColor, STYLE_SOLID, true);
   CreateLine(OBJ_SL, "SL", entry - distance, InpSlColor, STYLE_SOLID, true);
   CreateLine(OBJ_TP, "TP", entry + distance * InpFinalRR, InpTpColor, STYLE_SOLID, true);

   CreateBox(OBJ_BOX_TP, InpZoneTpFill, InpZoneTpBorder);
   CreateBox(OBJ_BOX_SL, InpZoneSlFill, InpZoneSlBorder);

   CreateBoxLabel(OBJ_LBL_TP, InpTpLabelColor);
   CreateBoxLabel(OBJ_LBL_SL, InpSlLabelColor);

   if(!g_armed)
      HideTradeBox();

   return true;
}

void DeleteTradeObjects()
{
   const string names[] = {OBJ_ENTRY, OBJ_SL, OBJ_TP, OBJ_BOX_TP, OBJ_BOX_SL, OBJ_LBL_TP, OBJ_LBL_SL};
   for(int i = 0; i < ArraySize(names); i++)
      ObjectDelete(0, names[i]);
}

void ResetLevels()
{
   g_entryManual    = false;
   g_armed          = false;
   g_armedIsBuy     = true;
   g_armedPending   = false;
   g_status         = "";
   g_statusTime     = 0;
   g_origRiskDist   = 0.0;
   g_origRewardDist = 0.0;

   DeleteTradeObjects();

   for(int i = 0; i < 5; i++)
      ObjectSetString(0, InfoName(i), OBJPROP_TEXT, " ");

   for(int i = 0; i < 3; i++)
      ObjectSetString(0, StatName(i), OBJPROP_TEXT, " ");

   SetStatus("Ready - click BUY or SELL", InpMutedColor);

   g_infoCount = -1;
   LayoutInfoRows(0);

   MarkDirty();
   ChartRedraw();
}

void FlipLevels()
{
   if(!LinesExist())
      return;

   const double entry = LinePrice(OBJ_ENTRY);
   SetLinePrice(OBJ_SL, 2.0 * entry - LinePrice(OBJ_SL));
   SetLinePrice(OBJ_TP, 2.0 * entry - LinePrice(OBJ_TP));
}

void UpdateAutoEntry()
{
   if(g_entryManual || g_armedPending || !LinesExist())
      return;

   const bool isBuy = LinePrice(OBJ_SL) < LinePrice(OBJ_ENTRY);
   SetLinePrice(OBJ_ENTRY, SymbolInfoDouble(_Symbol, isBuy ? SYMBOL_ASK : SYMBOL_BID));
}

void UpdatePendingDirection()
{
   if(!g_armed || !g_armedPending || !LinesExist())
      return;

   const double entry = LinePrice(OBJ_ENTRY);
   const double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   const bool shouldBeBuy = (entry < ask);
   if(shouldBeBuy == g_armedIsBuy)
      return;

   if(g_origRiskDist < _Point)
      return;

   const double dir   = shouldBeBuy ? 1.0 : -1.0;
   const double newSl = entry - dir * g_origRiskDist;
   const double newTp = entry + dir * (g_origRewardDist > 0.0
                                       ? g_origRewardDist
                                       : g_origRiskDist * InpFinalRR);

   SetLinePrice(OBJ_SL, newSl);
   SetLinePrice(OBJ_TP, newTp);

   g_armedIsBuy = shouldBeBuy;
   Notify(shouldBeBuy ? "Flipped to BUY pending" : "Flipped to SELL pending");
}

int LotDigits()
{
   const double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   return (int)MathMax(0.0, MathRound(-MathLog10(step)));
}

double FloorLots(const double lots)
{
   const double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   return NormalizeDouble(MathFloor(lots / step + 1e-9) * step, LotDigits());
}

double NormalizeLots(const double lots)
{
   const double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   return NormalizeDouble(MathMax(minLot, MathMin(maxLot, FloorLots(lots))), LotDigits());
}

double RiskBudget()
{
   const double base = (g_riskBase == BASE_EQUITY) ? AccountInfoDouble(ACCOUNT_EQUITY)
                                                   : AccountInfoDouble(ACCOUNT_BALANCE);
   return (g_riskMode == RISK_PERCENT) ? base * g_riskValue / 100.0 : g_riskValue;
}

bool Calculate(SizingResult &r)
{
   ZeroMemory(r);

   r.entry = LinePrice(OBJ_ENTRY);
   r.sl    = LinePrice(OBJ_SL);
   r.tp    = LinePrice(OBJ_TP);

   if(r.entry <= 0.0 || r.sl <= 0.0 || MathAbs(r.entry - r.sl) < _Point)
      return false;

   r.isBuy    = r.sl < r.entry;
   r.distance = MathAbs(r.entry - r.sl);

   const ENUM_ORDER_TYPE type = r.isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

   double lossPerLot = 0.0;
   if(!OrderCalcProfit(type, _Symbol, 1.0, r.entry, r.sl, lossPerLot) || lossPerLot >= 0.0)
      return false;
   lossPerLot = -lossPerLot;

   r.riskBudget  = RiskBudget();
   const double raw = r.riskBudget / lossPerLot;
   r.belowMinLot = raw < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   r.lots        = NormalizeLots(raw);
   r.actualRisk  = r.lots * lossPerLot;

   r.tpValid = r.isBuy ? r.tp > r.entry : (r.tp > 0.0 && r.tp < r.entry);
   if(!r.tpValid || !OrderCalcProfit(type, _Symbol, r.lots, r.entry, r.tp, r.reward))
      r.reward = 0.0;

   if(!OrderCalcMargin(type, _Symbol, r.lots, r.entry, r.margin))
      r.margin = 0.0;
   r.marginShort = r.margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE);

   const double dir = r.isBuy ? 1.0 : -1.0;
   r.tp1Price = r.entry + dir * r.distance * InpTp1R;
   r.tp2Price = r.entry + dir * r.distance * InpTp2R;
   r.be1Price = r.entry + dir * r.distance * InpBe1TriggerR;

   r.valid = true;
   return true;
}

int CountManaged()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0)
         continue;
      if(IsManaged())
         count++;
   }
   return count;
}

bool IsManaged()
{
   if(PositionGetString(POSITION_SYMBOL) != _Symbol)
      return false;
   return InpManageAll || PositionGetInteger(POSITION_MAGIC) == InpMagic;
}

bool IsManagedOrder()
{
   if(OrderGetString(ORDER_SYMBOL) != _Symbol)
      return false;
   return InpManageAll || OrderGetInteger(ORDER_MAGIC) == InpMagic;
}

void Notify(const string text)
{
   g_status     = text;
   g_statusTime = TimeLocal();
   MarkDirty();
   Print("TradeManager: ", text);
}

bool IsFridayCutoff()
{
   if(InpFridayCloseHour < 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.day_of_week == 5 && dt.hour >= InpFridayCloseHour;
}

bool CanTrade(string &reason)
{
   if(g_locked)                     { reason = "Daily loss limit reached";  return false; }
   if(IsFridayCutoff())             { reason = "Friday cutoff active";      return false; }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
                                    { reason = "Algo trading disabled";     return false; }
   if(InpMaxSpread > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpread)
                                    { reason = "Spread too high";           return false; }
   if(InpMaxOpenTrades > 0 && CountManaged() >= InpMaxOpenTrades)
                                    { reason = "Max open trades reached";   return false; }
   return true;
}

void Execute(const bool wantBuy, const bool pending)
{
   if(!LinesExist())                  { Notify("Levels not ready");            return; }

   string reason;
   if(!CanTrade(reason))              { Notify(reason);                        return; }

   if(!pending)
      SetLinePrice(OBJ_ENTRY, SymbolInfoDouble(_Symbol, wantBuy ? SYMBOL_ASK : SYMBOL_BID));

   SizingResult r;
   if(!Calculate(r))                  { Notify("Invalid ENTRY / SL");          return; }
   if(r.isBuy != wantBuy)             { Notify("SL is on the wrong side");     return; }
   if(r.belowMinLot)                  { Notify("Risk below minimum lot");      return; }
   if(r.marginShort)                  { Notify("Insufficient free margin");    return; }

   const double sl = NormalizePrice(r.sl);
   const double tp = r.tpValid ? NormalizePrice(r.tp) : 0.0;
   bool ok = false;

   if(!pending)
   {
      ok = wantBuy ? trade.Buy(r.lots, _Symbol, 0.0, sl, tp, InpComment)
                   : trade.Sell(r.lots, _Symbol, 0.0, sl, tp, InpComment);
   }
   else
   {
      const double entry = NormalizePrice(r.entry);
      const double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      ENUM_ORDER_TYPE type;
      if(wantBuy) type = entry < ask ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_BUY_STOP;
      else        type = entry > bid ? ORDER_TYPE_SELL_LIMIT : ORDER_TYPE_SELL_STOP;

      ok = trade.OrderOpen(_Symbol, type, r.lots, 0.0, entry, sl, tp, ORDER_TIME_GTC, 0, InpComment);
   }

   if(ok)
   {
      Notify((pending ? "Pending placed " : "Opened ") + DoubleToString(r.lots, LotDigits()) + " lots");
      DisarmTrade();
   }
   else
      Notify("Failed: " + trade.ResultRetcodeDescription());
}

void ExecutePending()
{
   if(!LinesExist())
      return;
   Execute(LinePrice(OBJ_SL) < LinePrice(OBJ_ENTRY), true);
}

void DisarmTrade()
{
   g_armed          = false;
   g_entryManual    = false;
   g_origRiskDist   = 0.0;
   g_origRewardDist = 0.0;
   HideTradeBox();
   DeleteTradeObjects();
   MarkDirty();
   ChartRedraw();
}

void ArmTrade(const bool isBuy, const bool pending)
{
   if(g_armed && g_armedIsBuy == isBuy && g_armedPending == pending)
      return;

   if(!LinesExist())
   {
      if(!InitLevels())
         return;
   }

   const double entry    = LinePrice(OBJ_ENTRY);
   const double sl       = LinePrice(OBJ_SL);
   const double tp       = LinePrice(OBJ_TP);
   const bool   curBuy   = sl < entry;
   const bool   wasArmed = g_armed;

   if(!wasArmed || curBuy != isBuy)
   {
      g_origRiskDist   = MathAbs(entry - sl);
      g_origRewardDist = MathAbs(tp - entry);
   }

   if(curBuy != isBuy)
   {
      if(g_origRiskDist < _Point)
         return;

      const double dir   = isBuy ? 1.0 : -1.0;
      const double newSl = entry - dir * g_origRiskDist;
      const double newTp = entry + dir * (g_origRewardDist > 0.0
                                          ? g_origRewardDist
                                          : g_origRiskDist * InpFinalRR);

      SetLinePrice(OBJ_SL, newSl);
      SetLinePrice(OBJ_TP, newTp);
   }

   g_armed        = true;
   g_armedIsBuy   = isBuy;
   g_armedPending = pending;

   // Market mode → ENTRY tracks price. Pending mode → ENTRY is user-controlled.
   g_entryManual  = pending;

   ShowTradeBox();
   Notify(isBuy
          ? (pending ? "Armed BUY pending - drag ENTRY to reposition"
                     : "Armed BUY - ENTRY tracks price. Drag it to switch to pending.")
          : (pending ? "Armed SELL pending - drag ENTRY to reposition"
                     : "Armed SELL - ENTRY tracks price. Drag it to switch to pending."));
   MarkDirty();
}

void CloseManaged(const int filter)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !IsManaged())
         continue;

      const long   type   = PositionGetInteger(POSITION_TYPE);
      const double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

      if(filter == 1 && type != POSITION_TYPE_BUY)   continue;
      if(filter == 2 && type != POSITION_TYPE_SELL)  continue;
      if(filter == 3 && profit <= 0.0)               continue;
      if(filter == 4 && profit >= 0.0)               continue;

      trade.PositionClose(ticket);
   }
}

void DeletePendings()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !IsManagedOrder())
         continue;
      trade.OrderDelete(ticket);
   }
}

void ClosePercent(const int filter)
{
   if(g_closePct <= 0.0)
   {
      Notify("Close % is zero");
      return;
   }

   const double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   int closed = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !IsManaged())
         continue;

      const long type = PositionGetInteger(POSITION_TYPE);
      if(filter == 1 && type != POSITION_TYPE_BUY)   continue;
      if(filter == 2 && type != POSITION_TYPE_SELL)  continue;

      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double part   = FloorLots(volume * g_closePct / 100.0);

      if(part < minLot || volume - part < minLot)
         continue;

      if(trade.PositionClosePartial(ticket, part))
         closed++;
   }

   if(closed > 0)
      Notify("Closed " + DoubleToString(g_closePct, 1) + "% on " + IntegerToString(closed) + " position(s)");
   else
      Notify("Nothing to close at " + DoubleToString(g_closePct, 1) + "%");
}

void MoveAllToBreakeven()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !IsManaged())
         continue;

      const bool   isBuy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      const double open  = PositionGetDouble(POSITION_PRICE_OPEN);
      const double price = PositionGetDouble(POSITION_PRICE_CURRENT);
      const double dir   = isBuy ? 1.0 : -1.0;

      if(dir * (price - open) <= 0.0)
         continue;

      MoveStop(ticket, isBuy, open + dir * InpBe1OffsetPoints * _Point);
   }
}

bool MoveStop(const ulong ticket, const bool isBuy, const double newSlRaw)
{
   if(!PositionSelectByTicket(ticket))
      return false;

   const double sl    = PositionGetDouble(POSITION_SL);
   const double tp    = PositionGetDouble(POSITION_TP);
   const double newSl = NormalizePrice(newSlRaw);

   if(sl > 0.0 && (isBuy ? newSl <= sl : newSl >= sl))
      return true;

   const double minDist = (double)MathMax(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL),
                                          SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL)) * _Point;
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(isBuy ? newSl > bid - minDist : newSl < ask + minDist)
      return false;

   const bool ok = trade.PositionModify(ticket, newSl, tp);
   if(ok)
      MarkDirty();
   return ok;
}

double PartialLevelR(const int index) { return index == 0 ? InpTp1R : InpTp2R; }
double PartialPct(const int index)    { return index == 0 ? InpTp1Pct : InpTp2Pct; }
int    PartialBit(const int index)    { return index == 0 ? 1 : 2; }

int RunPartials(const ulong ticket, const int idx, const double r, int stage)
{
   const double initVol = g_cache[idx].vol;
   const double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   for(int i = 0; i < 2; i++)
   {
      const int bit = PartialBit(i);
      if((stage & bit) != 0 || PartialPct(i) <= 0.0 || r < PartialLevelR(i))
         continue;

      if(!PositionSelectByTicket(ticket))
         break;

      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double part   = FloorLots(initVol * PartialPct(i) / 100.0);

      if(part < minLot || volume - part < minLot)
      {
         stage |= bit;
         continue;
      }

      if(trade.PositionClosePartial(ticket, part))
      {
         stage |= bit;
         MarkDirty();
      }
   }
   return stage;
}

int RunBreakeven(const ulong ticket, const bool isBuy, const double open, const double riskDist,
                 const double r, int stage)
{
   const double dir = isBuy ? 1.0 : -1.0;

   if((stage & ST_BE1) == 0 && r >= InpBe1TriggerR)
   {
      if(MoveStop(ticket, isBuy, open + dir * InpBe1OffsetPoints * _Point))
         stage |= ST_BE1;
   }

   if(InpBe2TriggerR > 0.0 && (stage & ST_BE2) == 0 && r >= InpBe2TriggerR)
   {
      if(MoveStop(ticket, isBuy, open + dir * riskDist * InpBe2LockR))
         stage |= ST_BE2;
   }
   return stage;
}

double TrailTarget(const bool isBuy, const double price)
{
   const double dir = isBuy ? 1.0 : -1.0;

   if(InpTrailMode == TRAIL_POINTS)
      return price - dir * InpTrailPoints * _Point;

   if(InpTrailMode == TRAIL_ATR)
   {
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(g_trailAtrHandle, 0, 1, 1, atr) != 1)
         return 0.0;
      return price - dir * atr[0] * InpTrailAtrMult;
   }

   double values[];
   if(isBuy)
   {
      if(CopyLow(_Symbol, _Period, 1, InpTrailCandles, values) != InpTrailCandles)
         return 0.0;
      return values[ArrayMinimum(values)] - InpTrailBufferPts * _Point;
   }

   if(CopyHigh(_Symbol, _Period, 1, InpTrailCandles, values) != InpTrailCandles)
      return 0.0;
   return values[ArrayMaximum(values)] + InpTrailBufferPts * _Point;
}

void RunTrail(const ulong ticket, const bool isBuy, const double price)
{
   const double target = TrailTarget(isBuy, price);
   if(target <= 0.0 || !PositionSelectByTicket(ticket))
      return;

   const double sl   = PositionGetDouble(POSITION_SL);
   const double step = InpTrailStepPts * _Point;

   if(sl > 0.0 && (isBuy ? target < sl + step : target > sl - step))
      return;

   MoveStop(ticket, isBuy, target);
}

void ManagePosition(const ulong ticket)
{
   if(!PositionSelectByTicket(ticket))
      return;

   const bool   isBuy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   const double dir   = isBuy ? 1.0 : -1.0;
   const double open  = PositionGetDouble(POSITION_PRICE_OPEN);

   const int idx = CacheLoad(ticket, PositionGetDouble(POSITION_SL), PositionGetDouble(POSITION_VOLUME));

   const double initSl = g_cache[idx].sl;
   if(initSl <= 0.0)
      return;

   const double riskDist = MathAbs(open - initSl);
   if(riskDist < _Point)
      return;

   const double price = PositionGetDouble(POSITION_PRICE_CURRENT);
   const double r     = dir * (price - open) / riskDist;
   int stage          = g_cache[idx].stage;

   if(g_partialOn)
      stage = RunPartials(ticket, idx, r, stage);

   if(!PositionSelectByTicket(ticket))
      return;

   if(g_beOn)
      stage = RunBreakeven(ticket, isBuy, open, riskDist, r, stage);

   if(g_trailOn && r >= InpTrailStartR)
      RunTrail(ticket, isBuy, price);

   CacheSetStage(idx, stage);
}

void ManagePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !IsManaged())
         continue;
      ManagePosition(ticket);
   }
}

void Guard()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   const int    dayKey = dt.year * 10000 + dt.mon * 100 + dt.day;
   const string key    = GKey("DAYEQ_" + IntegerToString(dayKey));

   if(dayKey != g_dayKey)
   {
      g_dayKey = dayKey;
      g_locked = false;
      if(!GlobalVariableCheck(key))
         GlobalVariableSet(key, AccountInfoDouble(ACCOUNT_EQUITY));
      g_dayEquity = GlobalVariableGet(key);
      MarkDirty();
   }

   if(InpMaxDailyLossPct > 0.0 && !g_locked && g_dayEquity > 0.0)
   {
      const double lossPct = (g_dayEquity - AccountInfoDouble(ACCOUNT_EQUITY)) / g_dayEquity * 100.0;
      if(lossPct >= InpMaxDailyLossPct)
      {
         g_locked = true;
         Notify("Daily loss limit hit");
         if(InpCloseOnLock)
         {
            CloseManaged(0);
            DeletePendings();
         }
      }
   }

   if(IsFridayCutoff() && (CountManaged() > 0))
   {
      CloseManaged(0);
      DeletePendings();
   }
}

void OpenModePopup()
{
   g_modePopupOpen = true;
   const long vis = OBJ_ALL_PERIODS;
   ObjectSetInteger(0, BTN_MODE_ITEM0, OBJPROP_TIMEFRAMES, vis);
   ObjectSetInteger(0, BTN_MODE_ITEM1, OBJPROP_TIMEFRAMES, vis);
   ObjectSetInteger(0, BTN_MODE_ITEM2, OBJPROP_TIMEFRAMES, vis);
   ChartRedraw();
}

void CloseModePopup()
{
   g_modePopupOpen = false;
   const long vis = OBJ_NO_PERIODS;
   ObjectSetInteger(0, BTN_MODE_ITEM0, OBJPROP_TIMEFRAMES, vis);
   ObjectSetInteger(0, BTN_MODE_ITEM1, OBJPROP_TIMEFRAMES, vis);
   ObjectSetInteger(0, BTN_MODE_ITEM2, OBJPROP_TIMEFRAMES, vis);
   ChartRedraw();
}

void ApplyModeSelection(const int selection)
{
   switch(selection)
   {
      case RSEL_PCT_BALANCE: g_riskMode = RISK_PERCENT; g_riskBase = BASE_BALANCE; break;
      case RSEL_PCT_EQUITY:  g_riskMode = RISK_PERCENT; g_riskBase = BASE_EQUITY;  break;
      case RSEL_FIXED:       g_riskMode = RISK_MONEY;                              break;
   }
   SaveSettings();
   CloseModePopup();
   UpdateModeButton();
   MarkDirty();
}

void FlushEditBox(const string name)
{
   if(ObjectFind(0, name) < 0)
      return;
   ObjectSetInteger(0, name, OBJPROP_READONLY, true);
   ObjectSetInteger(0, name, OBJPROP_READONLY, false);
}

void CommitClosePctEdit()
{
   const string raw = ObjectGetString(0, EDT_CLOSEPCT, OBJPROP_TEXT);
   double v = StringToDouble(raw);
   if(v < 0.0)   v = 0.0;
   if(v > 100.0) v = 100.0;

   g_closePct         = v;
   g_lastClosePctText = raw;

   const string txt = "Close " + DoubleToString(g_closePct, 1) + "% of Position";
   if(txt != g_lastCloseBtnText)
   {
      g_lastCloseBtnText = txt;
      ObjectSetString(0, BTN_APPLYPCT, OBJPROP_TEXT, txt);
   }

   SaveSettings();
   ChartRedraw();
}

void CommitClosePctEditOnBlur()
{
   FlushEditBox(EDT_CLOSEPCT);

   const string raw = ObjectGetString(0, EDT_CLOSEPCT, OBJPROP_TEXT);
   if(raw == g_lastClosePctText)
      return;

   CommitClosePctEdit();
}

void SyncClosePctLabel()
{
   const string s = ObjectGetString(0, EDT_CLOSEPCT, OBJPROP_TEXT);
   if(s == g_lastClosePctText)
      return;

   g_lastClosePctText = s;

   double v = StringToDouble(s);
   if(v < 0.0)   v = 0.0;
   if(v > 100.0) v = 100.0;

   if(MathAbs(v - g_closePct) <= 0.001)
      return;

   g_closePct = v;
   UpdateClosePctButton();
   MarkDirty();
}

void HandleClick(const string name)
{
   if(name == BTN_MODE_ITEM0) { ApplyModeSelection(RSEL_PCT_BALANCE); return; }
   if(name == BTN_MODE_ITEM1) { ApplyModeSelection(RSEL_PCT_EQUITY);  return; }
   if(name == BTN_MODE_ITEM2) { ApplyModeSelection(RSEL_FIXED);       return; }

   if(g_modePopupOpen && name != BTN_MODE)
      CloseModePopup();

   if(name == BTN_BUY)
   {
      if(g_armed && g_armedIsBuy && !g_armedPending)
         Execute(true, false);          // market execute
      else if(g_armed && g_armedIsBuy && g_armedPending)
         ExecutePending();              // pending execute
      else
         ArmTrade(true, false);         // first arm → market mode
   }
   else if(name == BTN_SELL)
   {
      if(g_armed && !g_armedIsBuy && !g_armedPending)
         Execute(false, false);         // market execute
      else if(g_armed && !g_armedIsBuy && g_armedPending)
         ExecutePending();              // pending execute
      else
         ArmTrade(false, false);        // first arm → market mode
   }
   else if(name == BTN_PEND)
   {
      if(g_armed && g_armedPending)  ExecutePending();
      else                           ArmTrade(LinePrice(OBJ_SL) < LinePrice(OBJ_ENTRY), true);
   }
   else if(name == BTN_RESET)     ResetLevels();
   else if(name == BTN_FLIP)      FlipLevels();
   else if(name == BTN_MOVEBE)    MoveAllToBreakeven();
   else if(name == BTN_APPLYPCT)
   {
      const string raw = ObjectGetString(0, EDT_CLOSEPCT, OBJPROP_TEXT);
      if(raw != g_lastClosePctText)
         CommitClosePctEdit();
      ClosePercent(0);
   }
   else if(name == BTN_CLOSEALL)
   {
      CloseManaged(0);
      DeletePendings();
   }
   else if(name == BTN_CLOSEBUY)  CloseManaged(1);
   else if(name == BTN_CLOSESEL)  CloseManaged(2);
   else if(name == BTN_DELPEND)   DeletePendings();
   else if(name == BTN_MODE)
   {
      if(g_modePopupOpen)
         CloseModePopup();
      else
         OpenModePopup();
   }
   else if(name == BTN_MIN)
   {
      if(g_modePopupOpen)
         CloseModePopup();
      g_minimized = !g_minimized;
      ApplyMinimize();
   }
}

void Track(const string name)
{
   const int n = ArraySize(g_objs);
   ArrayResize(g_objs, n + 1);
   g_objs[n] = name;
}

void MakeButton(const string name, const string text, const int x, const int y, const int w, const int h,
                const color bg, const bool track = true)
{
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, InpTextColor);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrDimGray);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, InpFont);
   if(track)
      Track(name);
}

void MakeLabel(const string name, const int x, const int y, const string text = " ", const bool track = true)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, InpTextColor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_FONT, InpFont);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   if(track)
      Track(name);
}

void MakeEdit(const string name, const string text, const int x, const int y, const int w, const int h)
{
   ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrDimGray);
   ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_CENTER);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_FONT, InpFont);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   Track(name);
}

void MakeSection(const string name, const int x, const int y, const string text)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize - 1);
   ObjectSetInteger(0, name, OBJPROP_COLOR, InpMutedColor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_FONT, InpFont);
   ObjectSetString(0, name, OBJPROP_TEXT, "  " + text);
   Track(name);
}

string InfoName(const int index)  { return PFX + "INFO_" + IntegerToString(index); }
string StatName(const int index)  { return PFX + "STAT_" + IntegerToString(index); }

string PeriodToString(const ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
   }
   return "TF";
}

void UpdateModeButton()
{
   string text;
   if(g_riskMode == RISK_PERCENT)
      text = (g_riskBase == BASE_EQUITY) ? "% of equity  v" : "% of balance  v";
   else
      text = "Fixed money  v";

   if(text == g_lastModeBtnText)
      return;
   g_lastModeBtnText = text;
   ObjectSetString(0, BTN_MODE, OBJPROP_TEXT, text);
}

void UpdateClosePctButton()
{
   const string text = "Close " + DoubleToString(g_closePct, 1) + "% of Position";
   if(text == g_lastCloseBtnText)
      return;
   g_lastCloseBtnText = text;
   ObjectSetString(0, BTN_APPLYPCT, OBJPROP_TEXT, text);
}

void SetStatus(const string text, const color clr)
{
   g_lastStatusText  = text;
   g_lastStatusColor = clr;
   ObjectSetString(0, LBL_STATUS, OBJPROP_TEXT, text);
   ObjectSetInteger(0, LBL_STATUS, OBJPROP_COLOR, clr);
}

void EnsureDraggable()
{
   if(!g_armed)
      return;

   const string names[] = {OBJ_ENTRY, OBJ_SL, OBJ_TP};
   for(int i = 0; i < ArraySize(names); i++)
   {
      if(ObjectFind(0, names[i]) < 0)
         continue;

      if(ObjectGetInteger(0, names[i], OBJPROP_SELECTABLE) != 1)
      {
         ObjectSetInteger(0, names[i], OBJPROP_SELECTABLE, true);
         ObjectSetInteger(0, names[i], OBJPROP_HIDDEN,     false);
         ObjectSetInteger(0, names[i], OBJPROP_BACK,       true);
         ObjectSetInteger(0, names[i], OBJPROP_ZORDER,     -1);
      }
      if(ObjectGetInteger(0, names[i], OBJPROP_SELECTED) != 1)
         ObjectSetInteger(0, names[i], OBJPROP_SELECTED, true);
   }
}

void BuildPanel()
{
   ArrayResize(g_objs, 0);

   const int x     = InpOffsetX;
   const int y     = InpOffsetY;
   const int inner = PANEL_W - PAD * 2;
   const int half  = (inner - PAD) / 2;
   const int third = (inner - PAD * 2) / 3;

   ObjectCreate(0, OBJ_BG, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, OBJ_BG, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, OBJ_BG, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, OBJ_BG, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, OBJ_BG, OBJPROP_XSIZE, PANEL_W);
   ObjectSetInteger(0, OBJ_BG, OBJPROP_BGCOLOR, InpPanelColor);
   ObjectSetInteger(0, OBJ_BG, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, OBJ_BG, OBJPROP_COLOR, clrDimGray);
   ObjectSetInteger(0, OBJ_BG, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, OBJ_BG, OBJPROP_HIDDEN, true);

   ObjectCreate(0, OBJ_HDR, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, OBJ_HDR, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, OBJ_HDR, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, OBJ_HDR, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, OBJ_HDR, OBJPROP_XSIZE, PANEL_W);
   ObjectSetInteger(0, OBJ_HDR, OBJPROP_YSIZE, 26);
   ObjectSetInteger(0, OBJ_HDR, OBJPROP_BGCOLOR, InpHeaderColor);
   ObjectSetInteger(0, OBJ_HDR, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, OBJ_HDR, OBJPROP_COLOR, InpHeaderColor);
   ObjectSetInteger(0, OBJ_HDR, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, OBJ_HDR, OBJPROP_HIDDEN, true);
   Track(OBJ_HDR);

   MakeLabel(OBJ_TITLE, x + PAD, y + 6, "TRADE MANAGER", false);
   ObjectSetInteger(0, OBJ_TITLE, OBJPROP_COLOR, InpAccentColor);
   ObjectSetInteger(0, OBJ_TITLE, OBJPROP_FONTSIZE, InpFontSize + 1);

   MakeLabel(OBJ_SYM, x + PANEL_W - 130, y + 6, _Symbol + "  " + PeriodToString(_Period), false);
   ObjectSetInteger(0, OBJ_SYM, OBJPROP_COLOR, InpMutedColor);

   MakeButton(BTN_MIN, "_", x + PANEL_W - 26, y + 3, 20, 20, InpHeaderColor, false);
   ObjectSetInteger(0, BTN_MIN, OBJPROP_COLOR, InpMutedColor);

   int cy = y + 26 + SECTION_GAP;

   LAYOUT_RISK_SEC = cy;            cy += HEADER_H;
   LAYOUT_RISK_ROW = cy;            cy += ROW_H + SECTION_GAP;

   LAYOUT_TRADE_SEC = cy;           cy += HEADER_H;
   LAYOUT_BUY_Y = cy;               cy += BIG_BTN_H + 4;
   LAYOUT_PEND_Y = cy;              cy += BTN_H + 4;
   LAYOUT_RESET_Y = cy;             cy += BTN_H + SECTION_GAP;

   LAYOUT_POS_SEC = cy;             cy += HEADER_H;
   LAYOUT_POS_ROW1 = cy;            cy += BTN_H + 4;
   LAYOUT_POS_ROW2 = cy;            cy += BTN_H + 4;
   LAYOUT_CLOSEPCT_Y = cy;          cy += BTN_H + SECTION_GAP;

   LAYOUT_STATUS_SEC = cy;          cy += HEADER_H;
   LAYOUT_INFO_Y = cy;
   LAYOUT_STATS_Y = LAYOUT_INFO_Y + 5 * 16 + 4;
   LAYOUT_STATUS_Y = LAYOUT_STATS_Y + 3 * 16 + 4;

   MakeSection(SEC_RISK, x, LAYOUT_RISK_SEC, "RISK");

   MakeLabel(LBL_RISK, x + PAD, LAYOUT_RISK_ROW + 3, "Risk", false);
   ObjectSetInteger(0, LBL_RISK, OBJPROP_COLOR, InpMutedColor);

   MakeEdit(EDT_RISK, DoubleToString(g_riskValue, 2), x + PAD + 36, LAYOUT_RISK_ROW, 74, ROW_H);

   g_modeBtnX = x + PAD + 36 + 74 + 6;
   g_modeBtnY = LAYOUT_RISK_ROW;
   g_modeBtnW = inner - 36 - 74 - 6;

   MakeButton(BTN_MODE, "", g_modeBtnX, g_modeBtnY, g_modeBtnW, ROW_H, InpButtonColor);
   UpdateModeButton();

   {
      const int itemH = ROW_H;
      int py = g_modeBtnY + ROW_H;
      MakeButton(BTN_MODE_ITEM0, "  % of balance", g_modeBtnX, py, g_modeBtnW, itemH, InpPopupColor);  py += itemH;
      MakeButton(BTN_MODE_ITEM1, "  % of equity",  g_modeBtnX, py, g_modeBtnW, itemH, InpPopupColor);  py += itemH;
      MakeButton(BTN_MODE_ITEM2, "  Fixed money",  g_modeBtnX, py, g_modeBtnW, itemH, InpPopupColor);

      const string items[] = {BTN_MODE_ITEM0, BTN_MODE_ITEM1, BTN_MODE_ITEM2};
      for(int i = 0; i < 3; i++)
      {
         ObjectSetInteger(0, items[i], OBJPROP_ALIGN, ALIGN_LEFT);
         ObjectSetInteger(0, items[i], OBJPROP_BORDER_COLOR, InpPopupColor);
         ObjectSetInteger(0, items[i], OBJPROP_ZORDER, 30);
         ObjectSetInteger(0, items[i], OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
      }
   }

   MakeSection(SEC_TRADE, x, LAYOUT_TRADE_SEC, "TRADE SETUP");

   MakeButton(BTN_BUY, "BUY", x + PAD, LAYOUT_BUY_Y, half, BIG_BTN_H, InpBuyColor);
   MakeButton(BTN_SELL, "SELL", x + PAD + half + PAD, LAYOUT_BUY_Y, half, BIG_BTN_H, InpSellColor);

   MakeButton(BTN_PEND, "PLACE PENDING ORDER", x + PAD, LAYOUT_PEND_Y, inner, BTN_H, InpButtonColor);

   MakeButton(BTN_RESET, "Reset Levels", x + PAD, LAYOUT_RESET_Y, half, BTN_H, InpButtonColor);
   MakeButton(BTN_FLIP, "Flip Levels", x + PAD + half + PAD, LAYOUT_RESET_Y, half, BTN_H, InpButtonColor);

   MakeSection(SEC_POS, x, LAYOUT_POS_SEC, "POSITION");

   MakeButton(BTN_MOVEBE, "Move to BE", x + PAD,                    LAYOUT_POS_ROW1, half, BTN_H, InpButtonColor);
   MakeButton(BTN_CLOSEALL, "Close All", x + PAD + half + PAD,      LAYOUT_POS_ROW1, half, BTN_H, InpButtonColor);

   MakeButton(BTN_CLOSEBUY, "Close Buys",   x + PAD,                       LAYOUT_POS_ROW2, third, BTN_H, InpButtonColor);
   MakeButton(BTN_CLOSESEL, "Close Sells",  x + PAD + third + PAD,         LAYOUT_POS_ROW2, third, BTN_H, InpButtonColor);
   MakeButton(BTN_DELPEND,  "Del Pending",  x + PAD + (third + PAD) * 2,   LAYOUT_POS_ROW2, third, BTN_H, InpButtonColor);

   MakeEdit(EDT_CLOSEPCT, DoubleToString(g_closePct, 1), x + PAD, LAYOUT_CLOSEPCT_Y, 60, BTN_H);
   MakeButton(BTN_APPLYPCT, "", x + PAD + 68, LAYOUT_CLOSEPCT_Y, inner - 68, BTN_H, InpButtonColor);
   UpdateClosePctButton();
   g_lastClosePctText = ObjectGetString(0, EDT_CLOSEPCT, OBJPROP_TEXT);

   MakeSection(SEC_STATUS, x, LAYOUT_STATUS_SEC, "STATUS");

   for(int i = 0; i < 5; i++)
      MakeLabel(InfoName(i), x + PAD, LAYOUT_INFO_Y + i * 16);

   for(int i = 0; i < 3; i++)
      MakeLabel(StatName(i), x + PAD, LAYOUT_STATS_Y + i * 16);

   MakeLabel(LBL_DOT, x + PAD, LAYOUT_STATUS_Y + 2, ".", false);
   ObjectSetInteger(0, LBL_DOT, OBJPROP_COLOR, InpMutedColor);

   MakeLabel(LBL_STATUS, x + PAD + 14, LAYOUT_STATUS_Y, "Ready", false);
   g_lastStatusText  = "Ready";
   g_lastStatusColor = InpTextColor;
   g_lastDotColor    = InpMutedColor;

   g_panelHeight = (LAYOUT_STATUS_Y - y) + ROW_H + 6;
}

void ApplyMinimize()
{
   const long visibility = g_minimized ? OBJ_NO_PERIODS : OBJ_ALL_PERIODS;

   for(int i = 0; i < ArraySize(g_objs); i++)
   {
      if(g_objs[i] == BTN_MODE_ITEM0 || g_objs[i] == BTN_MODE_ITEM1 || g_objs[i] == BTN_MODE_ITEM2)
         continue;
      ObjectSetInteger(0, g_objs[i], OBJPROP_TIMEFRAMES, visibility);
   }

   ObjectSetInteger(0, OBJ_HDR, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(0, OBJ_TITLE, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(0, OBJ_SYM, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(0, BTN_MIN, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);

   if(g_minimized && g_modePopupOpen)
      CloseModePopup();

   if(!g_modePopupOpen)
   {
      ObjectSetInteger(0, BTN_MODE_ITEM0, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
      ObjectSetInteger(0, BTN_MODE_ITEM1, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
      ObjectSetInteger(0, BTN_MODE_ITEM2, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
   }

   ObjectSetInteger(0, OBJ_BG, OBJPROP_YSIZE, g_minimized ? 26 : g_panelHeight);
   ObjectSetString(0, BTN_MIN, OBJPROP_TEXT, g_minimized ? "+" : "_");
   MarkDirty();
   ChartRedraw();
}

bool SetText(const string name, const string text, const color clr)
{
   const string value   = (text == "") ? " " : text;
   bool         changed = false;

   if(ObjectGetString(0, name, OBJPROP_TEXT) != value)
   {
      ObjectSetString(0, name, OBJPROP_TEXT, value);
      changed = true;
   }
   if(ObjectGetInteger(0, name, OBJPROP_COLOR) != clr)
   {
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      changed = true;
   }
   return changed;
}

string Money(const double value)
{
   return DoubleToString(value, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY);
}

void PositionStats(int &count, double &volume, double &floating, double &atStop)
{
   count    = 0;
   volume   = 0.0;
   floating = 0.0;
   atStop   = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0 || !IsManaged())
         continue;

      const double vol  = PositionGetDouble(POSITION_VOLUME);
      const double open = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl   = PositionGetDouble(POSITION_SL);
      const ENUM_ORDER_TYPE type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

      count++;
      volume   += vol;
      floating += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

      double p = 0.0;
      if(sl > 0.0 && OrderCalcProfit(type, _Symbol, vol, open, sl, p))
         atStop += p;
   }
}

void UpdateBox(const SizingResult &r)
{
   const datetime t1 = TimeCurrent() - PeriodSeconds(_Period) * InpBoxHalfBars;
   const datetime t2 = TimeCurrent() + PeriodSeconds(_Period) * InpBoxHalfBars;

   const double entry = r.entry;
   const double sl    = r.sl;
   const double tp    = r.tpValid ? r.tp : entry;

   ObjectSetInteger(0, OBJ_BOX_TP, OBJPROP_TIME,  0, t1);
   ObjectSetDouble (0, OBJ_BOX_TP, OBJPROP_PRICE, 0, entry);
   ObjectSetInteger(0, OBJ_BOX_TP, OBJPROP_TIME,  1, t2);
   ObjectSetDouble (0, OBJ_BOX_TP, OBJPROP_PRICE, 1, tp);
   ObjectSetInteger(0, OBJ_BOX_TP, OBJPROP_BGCOLOR, InpZoneTpFill);
   ObjectSetInteger(0, OBJ_BOX_TP, OBJPROP_COLOR,   InpZoneTpBorder);

   ObjectSetInteger(0, OBJ_BOX_SL, OBJPROP_TIME,  0, t1);
   ObjectSetDouble (0, OBJ_BOX_SL, OBJPROP_PRICE, 0, entry);
   ObjectSetInteger(0, OBJ_BOX_SL, OBJPROP_TIME,  1, t2);
   ObjectSetDouble (0, OBJ_BOX_SL, OBJPROP_PRICE, 1, sl);
   ObjectSetInteger(0, OBJ_BOX_SL, OBJPROP_BGCOLOR, InpZoneSlFill);
   ObjectSetInteger(0, OBJ_BOX_SL, OBJPROP_COLOR,   InpZoneSlBorder);

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   ObjectSetInteger(0, OBJ_LBL_TP, OBJPROP_TIME, t2);
   ObjectSetDouble (0, OBJ_LBL_TP, OBJPROP_PRICE, tp);
   ObjectSetInteger(0, OBJ_LBL_TP, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, OBJ_LBL_TP, OBJPROP_COLOR, InpTpLabelColor);
   ObjectSetString (0, OBJ_LBL_TP, OBJPROP_TEXT,
                    " TP " + DoubleToString(tp, _Digits) +
                    "   RR " + DoubleToString(r.actualRisk > 0.0 ? r.reward / r.actualRisk : 0.0, 2));

   ObjectSetInteger(0, OBJ_LBL_SL, OBJPROP_TIME, t2);
   ObjectSetDouble (0, OBJ_LBL_SL, OBJPROP_PRICE, sl);
   ObjectSetInteger(0, OBJ_LBL_SL, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
   ObjectSetInteger(0, OBJ_LBL_SL, OBJPROP_COLOR, InpSlLabelColor);
   ObjectSetString (0, OBJ_LBL_SL, OBJPROP_TEXT,
                    " SL " + DoubleToString(sl, _Digits) +
                    "   " + DoubleToString(r.distance / point, 0) + "p");
}

void LayoutInfoRows(const int visibleRows)
{
   if(visibleRows == g_infoCount)
      return;

   g_infoCount = visibleRows;

   const int maxRows  = 5;
   const int rowH     = 16;
   const int reserved = maxRows * rowH;

   const int shift   = reserved - visibleRows * rowH;
   const int statsY  = LAYOUT_STATS_Y - shift;
   const int statusY = LAYOUT_STATUS_Y - shift;

   for(int i = 0; i < 3; i++)
      ObjectSetInteger(0, StatName(i), OBJPROP_YDISTANCE, statsY + i * rowH);

   ObjectSetInteger(0, LBL_DOT,    OBJPROP_YDISTANCE, statusY + 2);
   ObjectSetInteger(0, LBL_STATUS, OBJPROP_YDISTANCE, statusY);

   const int newHeight = (statusY - InpOffsetY) + ROW_H + 6;
   ObjectSetInteger(0, OBJ_BG, OBJPROP_YSIZE, g_minimized ? 26 : newHeight);
   g_panelHeight = newHeight;
}

void Refresh()
{
   UpdateModeButton();
   UpdateClosePctButton();

   if(!g_armed || !LinesExist())
   {
      LayoutInfoRows(0);

      int    count;
      double volume, floating, atStop;
      PositionStats(count, volume, floating, atStop);

      bool changed = false;
      if(SetText(StatName(0), "Open " + IntegerToString(count) + "   Vol " + DoubleToString(volume, LotDigits()), InpTextColor)) changed = true;
      if(SetText(StatName(1), "P/L " + Money(floating) + "   @SL " + Money(atStop), floating >= 0.0 ? InpOkColor : InpSlColor)) changed = true;

      const double dayPct = g_dayEquity > 0.0 ? (AccountInfoDouble(ACCOUNT_EQUITY) - g_dayEquity) / g_dayEquity * 100.0 : 0.0;
      string dayText = "Day " + DoubleToString(dayPct, 2) + "%";
      if(InpMaxDailyLossPct > 0.0)
         dayText += "  /  -" + DoubleToString(InpMaxDailyLossPct, 2) + "%";
      if(g_locked)
         dayText += "   LOCKED";
      if(SetText(StatName(2), dayText, g_locked ? InpWarnColor : InpTextColor)) changed = true;

      if(g_status != "" && TimeLocal() - g_statusTime > 8)
         g_status = "";

      const string st = (g_status == "") ? "Ready - click BUY or SELL" : g_status;
      const color  sc = (g_status == "") ? InpMutedColor : InpAccentColor;
      if(SetText(LBL_STATUS, st, sc)) changed = true;
      if(ObjectGetInteger(0, LBL_DOT, OBJPROP_COLOR) != (g_locked ? InpWarnColor : InpOkColor))
      {
         ObjectSetInteger(0, LBL_DOT, OBJPROP_COLOR, g_locked ? InpWarnColor : InpOkColor);
         changed = true;
      }

      if(changed)
         ChartRedraw();
      return;
   }

   bool changed = false;

   SizingResult r;

   if(!Calculate(r))
   {
      LayoutInfoRows(1);
      if(SetText(InfoName(0), "Invalid ENTRY / SL levels", InpWarnColor)) changed = true;
      for(int i = 1; i < 5; i++)
         if(SetText(InfoName(i), "", InpTextColor)) changed = true;
   }
   else
   {
      LayoutInfoRows(5);

      const double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double freeMgn = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      const long   spread  = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

      if(SetText(InfoName(0), (r.isBuy ? "BUY  " : "SELL ") + "   Lots " + DoubleToString(r.lots, LotDigits()),
                 r.isBuy ? InpBuyColor : InpSellColor)) changed = true;
      if(SetText(InfoName(1), "Risk   " + Money(r.actualRisk) + "   SL " + DoubleToString(r.distance / point, 0) + "p",
                 r.belowMinLot ? InpWarnColor : InpTextColor)) changed = true;

      if(r.tpValid && r.actualRisk > 0.0)
      {
         if(SetText(InfoName(2), "Reward " + Money(r.reward) + "   RR " + DoubleToString(r.reward / r.actualRisk, 2), InpTextColor)) changed = true;
      }
      else
      {
         if(SetText(InfoName(2), "Reward: TP on wrong side", InpWarnColor)) changed = true;
      }

      if(SetText(InfoName(3), "Margin " + Money(r.margin) + "   (" + DoubleToString(freeMgn > 0.0 ? r.margin / freeMgn * 100.0 : 0.0, 1) + "%)",
                 r.marginShort ? InpWarnColor : InpTextColor)) changed = true;
      if(SetText(InfoName(4), "Spread " + IntegerToString((int)spread) + "p   (" + DoubleToString(spread * point / r.distance * 100.0, 1) + "% of SL)",
                 InpTextColor)) changed = true;

      UpdateBox(r);
      changed = true;
   }

   int    count;
   double volume, floating, atStop;
   PositionStats(count, volume, floating, atStop);

   if(SetText(StatName(0), "Open " + IntegerToString(count) + "   Vol " + DoubleToString(volume, LotDigits()), InpTextColor)) changed = true;
   if(SetText(StatName(1), "P/L " + Money(floating) + "   @SL " + Money(atStop), floating >= 0.0 ? InpOkColor : InpSlColor)) changed = true;

   const double dayPct = g_dayEquity > 0.0 ? (AccountInfoDouble(ACCOUNT_EQUITY) - g_dayEquity) / g_dayEquity * 100.0 : 0.0;
   string dayText = "Day " + DoubleToString(dayPct, 2) + "%";
   if(InpMaxDailyLossPct > 0.0)
      dayText += "  /  -" + DoubleToString(InpMaxDailyLossPct, 2) + "%";
   if(g_locked)
      dayText += "   LOCKED";
   if(SetText(StatName(2), dayText, g_locked ? InpWarnColor : InpTextColor)) changed = true;

   if(g_status != "" && TimeLocal() - g_statusTime > 8)
   {
      g_status = "";
      changed  = true;
   }
   const string st = (g_status == "") ? (g_armed ? "Armed - click BUY/SELL to execute" : "Ready") : g_status;
   const color  sc = (g_status == "") ? InpMutedColor : InpAccentColor;
   if(SetText(LBL_STATUS, st, sc)) changed = true;
   if(ObjectGetInteger(0, LBL_DOT, OBJPROP_COLOR) != (g_locked ? InpWarnColor : InpOkColor))
   {
      ObjectSetInteger(0, LBL_DOT, OBJPROP_COLOR, g_locked ? InpWarnColor : InpOkColor);
      changed = true;
   }

   if(changed)
      ChartRedraw();
}