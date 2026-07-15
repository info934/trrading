#property copyright "EKV TradeGold"
#property version   "1.20"
#property strict
#property description "Asia/NY liquidity sweep + CHoCH + FVG challenge EA"

#include <Trade/Trade.mqh>

enum ENUM_POSITION_SIZING
  {
   SIZING_RISK_PERCENT = 0,
   SIZING_FIXED_LOTS   = 1
  };

enum ENUM_SETUP_STAGE
  {
   STAGE_WAIT_SWEEP = 0,
   STAGE_WAIT_CHOCH = 1,
   STAGE_WAIT_FVG   = 2,
   STAGE_PENDING    = 3,
   STAGE_LIVE       = 4
  };

enum ENUM_BIAS_PROFILE
  {
   BIAS_PRODUCTION = 0,
   BIAS_BALANCED   = 1,
   BIAS_H1_ONLY    = 2,
   BIAS_DISABLED   = 3
  };

input group "01 - Environment"
input long                 InpMagicNumber          = 26071001;
input bool                 InpRequireM5            = true;
input bool                 InpUseAsiaSession       = true;
input int                  InpAsiaStartHour        = 1;        // broker server time
input int                  InpAsiaStartMinute      = 0;
input int                  InpAsiaEndHour          = 4;
input int                  InpAsiaEndMinute        = 0;
input bool                 InpUseNewYorkSession    = true;
input int                  InpSessionStartHour     = 16;       // broker server time
input int                  InpSessionStartMinute   = 30;
input int                  InpSessionEndHour       = 19;       // broker server time
input int                  InpSessionEndMinute     = 30;
input int                  InpMaxTradesPerDay      = 2;
input double               InpMaxDailyLossPct      = 5.0;
input int                  InpMaxSpreadPoints      = 80;

input group "02 - Challenge limits"
input bool                 InpUseChallengeLimits   = true;
input double               InpChallengeProfitTarget = 5000.0;
input double               InpChallengeMaxDailyLoss = 5000.0;
input double               InpChallengeMaxLoss     = 10000.0;
input int                  InpChallengeMinTradeDays = 2;
input int                  InpChallengeTargetDays  = 14;
input bool                 InpStopAfterTarget      = true;

input group "03 - Structure and FVG"
input int                  InpSwingLength          = 2;
input int                  InpMaxSweepToChochBars  = 18;
input int                  InpMaxChochToFvgBars    = 12;
input int                  InpPendingExpiryBars    = 18;
input int                  InpATRPeriod            = 14;
input double               InpMaxSweepDepthATR     = 1.50;
input double               InpMinDisplacementATR   = 0.35;
input double               InpMinFvgATR            = 0.03;
input double               InpSLBufferATR          = 0.10;
input double               InpMinStopATR           = 0.25;
input double               InpMaxStopATR           = 4.00;

input group "04 - Higher timeframe bias"
input ENUM_BIAS_PROFILE    InpBiasProfile          = BIAS_DISABLED;
input int                  InpHTFFastEMA           = 50;
input int                  InpHTFSlowEMA           = 200;
input bool                 InpUseEMASlope          = true;

input group "05 - Risk and exits"
input ENUM_POSITION_SIZING InpSizingMode           = SIZING_RISK_PERCENT;
input double               InpRiskPercent          = 2.00;
input double               InpFixedLots            = 0.10;
input double               InpLotMultiplier        = 1.00;
input double               InpMaximumLots          = 10.0;
input double               InpRewardRisk           = 2.0;
input double               InpBreakEvenAtR          = 1.00;
input int                  InpBreakEvenOffsetPoints = 10;

input group "06 - Chart drawings"
input bool                 InpDrawOnChart           = true;
input bool                 InpKeepHistoricalObjects = true;

CTrade trade;
int g_atr_handle = INVALID_HANDLE;
int g_h1_fast_handle = INVALID_HANDLE;
int g_h1_slow_handle = INVALID_HANDLE;
int g_h4_fast_handle = INVALID_HANDLE;
int g_h4_slow_handle = INVALID_HANDLE;
datetime g_last_bar_time = 0;

ENUM_SETUP_STAGE g_stage = STAGE_WAIT_SWEEP;
int g_direction = 0;
bool g_had_position = false;
bool g_be_moved = false;

double g_swing_high = 0.0;
double g_swing_low = 0.0;
datetime g_swing_high_time = 0;
datetime g_swing_low_time = 0;
datetime g_sweep_time = 0;
datetime g_choch_time = 0;
int g_bars_since_sweep = 0;
int g_bars_since_choch = 0;
double g_sweep_extreme = 0.0;
double g_sweep_reference = 0.0;
double g_choch_level = 0.0;
double g_planned_entry = 0.0;
double g_planned_sl = 0.0;
double g_planned_tp = 0.0;
double g_planned_be_trigger = 0.0;
double g_planned_lots = 0.0;

int g_day_key = -1;
int g_trades_today = 0;
double g_day_start_equity = 0.0;
double g_initial_balance = 0.0;
double g_min_equity = 0.0;
double g_max_daily_loss_seen = 0.0;
int g_metric_day_key = -1;
int g_last_trade_day_key = -1;
int g_trade_days = 0;
int g_week_key = -1;
double g_week_start_balance = 0.0;
bool g_week_had_trade = false;
int g_traded_weeks = 0;
int g_profitable_weeks = 0;
int g_losing_weeks = 0;
datetime g_target_reached_time = 0;
datetime g_challenge_start_time = 0;

string ObjectPrefix()
  {
   return StringFormat("EKV_%I64d_",InpMagicNumber);
  }

string ObjectId(const string tag,const datetime time)
  {
   return ObjectPrefix()+tag+"_"+IntegerToString((long)time);
  }

void DrawEvent(const string tag,const datetime time,const double price,const color line_color)
  {
   if(!InpDrawOnChart)
      return;
   const string name=ObjectId(tag,time);
   if(ObjectFind(0,name)>=0 || !ObjectCreate(0,name,OBJ_TEXT,0,time,price))
      return;
   ObjectSetString(0,name,OBJPROP_TEXT,tag);
   ObjectSetString(0,name,OBJPROP_FONT,"Arial Bold");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,name,OBJPROP_COLOR,line_color);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_CENTER);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
  }

void DrawLevel(const string tag,const datetime start_time,const datetime end_time,const double price,const color line_color,const ENUM_LINE_STYLE style)
  {
   if(!InpDrawOnChart)
      return;
   const string name=ObjectId(tag,start_time);
   if(!ObjectCreate(0,name,OBJ_TREND,0,start_time,price,end_time,price))
      return;
   ObjectSetInteger(0,name,OBJPROP_COLOR,line_color);
   ObjectSetInteger(0,name,OBJPROP_STYLE,style);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,tag+" "+DoubleToString(price,_Digits));
  }

void DrawPlan(const datetime fvg_start,const datetime plan_time,const datetime expiry,const double fvg_low,const double fvg_high)
  {
   if(!InpDrawOnChart)
      return;
   const string box_name=ObjectId("FVG",plan_time);
   if(ObjectCreate(0,box_name,OBJ_RECTANGLE,0,fvg_start,fvg_high,expiry,fvg_low))
     {
      ObjectSetInteger(0,box_name,OBJPROP_COLOR,g_direction>0 ? clrTeal : clrOrange);
      ObjectSetInteger(0,box_name,OBJPROP_FILL,true);
      ObjectSetInteger(0,box_name,OBJPROP_BACK,true);
      ObjectSetInteger(0,box_name,OBJPROP_SELECTABLE,false);
     }
   DrawLevel("ENTRY",plan_time,expiry,g_planned_entry,clrGold,STYLE_SOLID);
   DrawLevel("SL",plan_time,expiry,g_planned_sl,clrRed,STYLE_DASH);
   DrawLevel("TP",plan_time,expiry,g_planned_tp,clrLimeGreen,STYLE_DASH);
  }

int MinuteOfDay(const datetime value)
  {
   MqlDateTime parts;
   TimeToStruct(value,parts);
   return parts.hour*60+parts.min;
  }

int DayKey(const datetime value)
  {
   MqlDateTime parts;
   TimeToStruct(value,parts);
   return parts.year*10000+parts.mon*100+parts.day;
  }

int WeekKey(const datetime value)
  {
   MqlDateTime parts;
   TimeToStruct(value,parts);
   const int days_from_monday=(parts.day_of_week+6)%7;
   return DayKey(value-days_from_monday*86400);
  }

void CloseWeekMetrics(const double current_balance)
  {
   if(!g_week_had_trade)
      return;
   g_traded_weeks++;
   const double result=current_balance-g_week_start_balance;
   if(result>0.01)
      g_profitable_weeks++;
   else if(result<-0.01)
      g_losing_weeks++;
  }

void UpdateChallengeMetrics(const datetime now)
  {
   const double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   const double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   g_min_equity=MathMin(g_min_equity,equity);

   const int current_day=DayKey(now);
   if(current_day!=g_metric_day_key)
     {
      g_metric_day_key=current_day;
      g_day_start_equity=equity;
     }
   g_max_daily_loss_seen=MathMax(g_max_daily_loss_seen,g_day_start_equity-equity);

   const int current_week=WeekKey(now);
   if(current_week!=g_week_key)
     {
      if(g_week_key!=-1)
         CloseWeekMetrics(balance);
      g_week_key=current_week;
      g_week_start_balance=balance;
      g_week_had_trade=false;
     }

   if(g_target_reached_time==0 && g_trade_days>=InpChallengeMinTradeDays && balance-g_initial_balance>=InpChallengeProfitTarget)
      g_target_reached_time=now;
  }

bool InMinuteWindow(const int minute_of_day,const int start_minute,const int end_minute)
  {
   if(start_minute==end_minute)
      return false;
   if(start_minute<end_minute)
      return minute_of_day>=start_minute && minute_of_day<end_minute;
   return minute_of_day>=start_minute || minute_of_day<end_minute;
  }

bool InSession(const datetime value)
  {
   const int now_minute=MinuteOfDay(value);
   const bool asia=InpUseAsiaSession && InMinuteWindow(now_minute,InpAsiaStartHour*60+InpAsiaStartMinute,InpAsiaEndHour*60+InpAsiaEndMinute);
   const bool new_york=InpUseNewYorkSession && InMinuteWindow(now_minute,InpSessionStartHour*60+InpSessionStartMinute,InpSessionEndHour*60+InpSessionEndMinute);
   return asia || new_york;
  }

bool NewEntriesAllowed(const datetime value)
  {
   if(!InSession(value) || g_trades_today>=InpMaxTradesPerDay)
      return false;

   if(g_day_start_equity<=0.0)
      return true;

   const double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   const double drawdown_pct=(g_day_start_equity-equity)/g_day_start_equity*100.0;
   if(drawdown_pct>=InpMaxDailyLossPct)
      return false;

   if(InpUseChallengeLimits)
     {
      const double balance=AccountInfoDouble(ACCOUNT_BALANCE);
      if(g_day_start_equity-equity>=InpChallengeMaxDailyLoss || g_initial_balance-equity>=InpChallengeMaxLoss)
         return false;
      if(InpStopAfterTarget && g_trade_days>=InpChallengeMinTradeDays && balance-g_initial_balance>=InpChallengeProfitTarget)
         return false;
     }
   return true;
  }

double NormalizePrice(const double price)
  {
   const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   return NormalizeDouble(price,digits);
  }

int VolumeDigits(const double step)
  {
   int digits=0;
   double scaled=step;
   while(digits<8 && MathAbs(scaled-MathRound(scaled))>1e-9)
     {
      scaled*=10.0;
      digits++;
     }
   return digits;
  }

double NormalizeVolumeDown(const double requested)
  {
   const double broker_min=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   const double broker_max=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   const double broker_step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(broker_min<=0.0 || broker_max<=0.0 || broker_step<=0.0)
      return 0.0;

   const double capped=MathMin(requested,MathMin(InpMaximumLots,broker_max));
   const double rounded=MathFloor(capped/broker_step+1e-9)*broker_step;
   if(rounded<broker_min)
      return 0.0;
   return NormalizeDouble(rounded,VolumeDigits(broker_step));
  }

double CalculateLots(const int direction,const double entry,const double stop)
  {
   double base_lots=InpFixedLots;
   if(InpSizingMode==SIZING_RISK_PERCENT)
     {
      const double risk_money=AccountInfoDouble(ACCOUNT_EQUITY)*InpRiskPercent/100.0;
      double one_lot_result=0.0;
      const ENUM_ORDER_TYPE side=direction>0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(!OrderCalcProfit(side,_Symbol,1.0,entry,stop,one_lot_result))
        {
         PrintFormat("OrderCalcProfit failed: %d",GetLastError());
         return 0.0;
        }
      const double one_lot_loss=MathAbs(one_lot_result);
      if(one_lot_loss<=0.0)
         return 0.0;
      base_lots=risk_money/one_lot_loss;
     }
   return NormalizeVolumeDown(base_lots*InpLotMultiplier);
  }

double GetATR(const int shift)
  {
   double values[1];
   if(CopyBuffer(g_atr_handle,0,shift,1,values)!=1)
      return 0.0;
   return values[0];
  }

bool ReadIndicatorValue(const int handle,const int shift,double &value)
  {
   double values[1];
   if(handle==INVALID_HANDLE || CopyBuffer(handle,0,shift,1,values)!=1)
      return false;
   value=values[0];
   return value!=EMPTY_VALUE;
  }

bool BiasAllows(const int direction)
  {
   if(InpBiasProfile==BIAS_DISABLED)
      return true;

   double h1_fast=0.0,h1_fast_prev=0.0,h1_slow=0.0;
   double h4_fast=0.0,h4_fast_prev=0.0,h4_slow=0.0;
   if(!ReadIndicatorValue(g_h1_fast_handle,1,h1_fast) ||
      !ReadIndicatorValue(g_h1_fast_handle,2,h1_fast_prev) ||
      !ReadIndicatorValue(g_h1_slow_handle,1,h1_slow) ||
      !ReadIndicatorValue(g_h4_fast_handle,1,h4_fast) ||
      !ReadIndicatorValue(g_h4_fast_handle,2,h4_fast_prev) ||
      !ReadIndicatorValue(g_h4_slow_handle,1,h4_slow))
      return false;

   const double h1_close=iClose(_Symbol,PERIOD_H1,1);
   const double h4_close=iClose(_Symbol,PERIOD_H4,1);
   if(h1_close<=0.0 || h4_close<=0.0)
      return false;

   const bool h1_bull=h1_close>h1_slow && h1_fast>h1_slow && (!InpUseEMASlope || h1_fast>h1_fast_prev);
   const bool h1_bear=h1_close<h1_slow && h1_fast<h1_slow && (!InpUseEMASlope || h1_fast<h1_fast_prev);
   const bool h4_bull=h4_close>h4_slow && h4_fast>h4_slow && (!InpUseEMASlope || h4_fast>h4_fast_prev);
   const bool h4_bear=h4_close<h4_slow && h4_fast<h4_slow && (!InpUseEMASlope || h4_fast<h4_fast_prev);

   if(InpBiasProfile==BIAS_PRODUCTION)
      return direction>0 ? h1_bull && h4_bull : h1_bear && h4_bear;

   if(InpBiasProfile==BIAS_H1_ONLY)
      return direction>0 ? h1_bull : h1_bear;

   return direction>0 ? (h1_bull || h4_bull) && !(h1_bear || h4_bear)
                      : (h1_bear || h4_bear) && !(h1_bull || h4_bull);
  }

bool HasOurPosition(ulong &ticket)
  {
   ticket=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      const ulong candidate=PositionGetTicket(i);
      if(candidate==0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==InpMagicNumber)
        {
         ticket=candidate;
         return true;
        }
     }
   return false;
  }

bool HasOurPendingOrder()
  {
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      const ulong ticket=OrderGetTicket(i);
      if(ticket==0)
         continue;
      if(OrderGetString(ORDER_SYMBOL)!=_Symbol || OrderGetInteger(ORDER_MAGIC)!=InpMagicNumber)
         continue;
      const ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type==ORDER_TYPE_BUY_LIMIT || type==ORDER_TYPE_SELL_LIMIT)
         return true;
     }
   return false;
  }

bool TradeRetcodeAccepted()
  {
   const uint retcode=trade.ResultRetcode();
   return retcode==TRADE_RETCODE_DONE || retcode==TRADE_RETCODE_PLACED || retcode==TRADE_RETCODE_DONE_PARTIAL;
  }

void CancelOurPendingOrders()
  {
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      const ulong ticket=OrderGetTicket(i);
      if(ticket==0)
         continue;
      if(OrderGetString(ORDER_SYMBOL)==_Symbol && OrderGetInteger(ORDER_MAGIC)==InpMagicNumber)
         trade.OrderDelete(ticket);
     }
  }

bool IsPivotHigh(MqlRates &rates[],const int center,const int length)
  {
   const double value=rates[center].high;
   for(int i=center-length;i<=center+length;i++)
     {
      if(i==center)
         continue;
      if(rates[i].high>=value)
         return false;
     }
   return true;
  }

bool IsPivotLow(MqlRates &rates[],const int center,const int length)
  {
   const double value=rates[center].low;
   for(int i=center-length;i<=center+length;i++)
     {
      if(i==center)
         continue;
      if(rates[i].low<=value)
         return false;
     }
   return true;
  }

void ResetDay(const datetime bar_time)
  {
   const int key=DayKey(bar_time);
   if(key==g_day_key)
      return;

   g_day_key=key;
   g_trades_today=0;
   g_day_start_equity=AccountInfoDouble(ACCOUNT_EQUITY);
   if(!InSession(bar_time) && g_stage!=STAGE_LIVE)
     {
      CancelOurPendingOrders();
      ResetPlan();
     }
  }

void ResetPlan()
  {
   g_stage=STAGE_WAIT_SWEEP;
   g_direction=0;
   g_sweep_time=0;
   g_choch_time=0;
   g_bars_since_sweep=0;
   g_bars_since_choch=0;
   g_sweep_extreme=0.0;
   g_sweep_reference=0.0;
   g_choch_level=0.0;
   g_planned_entry=0.0;
   g_planned_sl=0.0;
   g_planned_tp=0.0;
   g_planned_be_trigger=0.0;
   g_planned_lots=0.0;
   g_be_moved=false;
  }

bool PlaceSetupOrder(const int direction,const double entry,const double stop,const double atr,const datetime bar_time)
  {
   const double stop_distance=MathAbs(entry-stop);
   if((direction>0 && stop>=entry) || (direction<0 && stop<=entry))
      return false;
   if(stop_distance<atr*InpMinStopATR || stop_distance>atr*InpMaxStopATR)
      return false;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick))
      return false;

   const double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   const int stops_level=(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   const double minimum_distance=stops_level*point;
   if(direction>0 && entry>=tick.ask-minimum_distance)
      return false;
   if(direction<0 && entry<=tick.bid+minimum_distance)
      return false;

   const double lots=CalculateLots(direction,entry,stop);
   if(lots<=0.0)
      return false;

   const double take_profit=entry+direction*stop_distance*InpRewardRisk;
   const datetime expiry=bar_time+InpPendingExpiryBars*PeriodSeconds(PERIOD_M5);
   const string comment=StringFormat("EKV NY CHOCH %.2f lot",lots);

   bool sent=false;
   if(direction>0)
      sent=trade.BuyLimit(lots,NormalizePrice(entry),_Symbol,NormalizePrice(stop),NormalizePrice(take_profit),ORDER_TIME_SPECIFIED,expiry,comment);
   else
      sent=trade.SellLimit(lots,NormalizePrice(entry),_Symbol,NormalizePrice(stop),NormalizePrice(take_profit),ORDER_TIME_SPECIFIED,expiry,comment);

   if(!sent || !TradeRetcodeAccepted())
     {
      PrintFormat("Pending order rejected: retcode=%u %s",trade.ResultRetcode(),trade.ResultRetcodeDescription());
      return false;
     }

   g_planned_entry=NormalizePrice(entry);
   g_planned_sl=NormalizePrice(stop);
   g_planned_tp=NormalizePrice(take_profit);
   g_planned_be_trigger=NormalizePrice(entry+direction*stop_distance*InpBreakEvenAtR);
   g_planned_lots=lots;
   g_stage=STAGE_PENDING;
   PrintFormat("Setup placed: direction=%d entry=%.*f sl=%.*f tp=%.*f lots=%.2f",direction,_Digits,g_planned_entry,_Digits,g_planned_sl,_Digits,g_planned_tp,lots);
   return true;
  }

void ManagePosition(const MqlRates &closed_bar)
  {
   ulong ticket=0;
   const bool has_position=HasOurPosition(ticket);

   if(has_position && !g_had_position)
     {
      g_had_position=true;
      g_stage=STAGE_LIVE;
      g_trades_today++;
      CancelOurPendingOrders();
     }

   if(has_position && !g_be_moved && PositionSelectByTicket(ticket))
     {
      const bool trigger_reached=g_direction>0 ? closed_bar.close>=g_planned_be_trigger : closed_bar.close<=g_planned_be_trigger;
      if(trigger_reached)
        {
         const double open_price=PositionGetDouble(POSITION_PRICE_OPEN);
         const double current_tp=PositionGetDouble(POSITION_TP);
         const double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
         const double new_sl=NormalizePrice(open_price+g_direction*InpBreakEvenOffsetPoints*point);
         if(trade.PositionModify(ticket,new_sl,current_tp) && TradeRetcodeAccepted())
            g_be_moved=true;
         else
            PrintFormat("Break-even modify failed: %u %s",trade.ResultRetcode(),trade.ResultRetcodeDescription());
        }
     }

   if(!has_position && g_had_position)
     {
      g_had_position=false;
      ResetPlan();
     }
  }

void ProcessClosedBar()
  {
   const int required=MathMax(100,InpSwingLength*2+10);
   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   if(CopyRates(_Symbol,PERIOD_M5,0,required,rates)<required)
      return;

   const MqlRates closed_bar=rates[1];
   ResetDay(closed_bar.time);
   ManagePosition(closed_bar);

   if(g_stage==STAGE_PENDING && !NewEntriesAllowed(closed_bar.time))
     {
      CancelOurPendingOrders();
      ResetPlan();
     }

   const int center=InpSwingLength+1;
   if(IsPivotHigh(rates,center,InpSwingLength))
     {
      g_swing_high=rates[center].high;
      g_swing_high_time=rates[center].time;
     }
   if(IsPivotLow(rates,center,InpSwingLength))
     {
      g_swing_low=rates[center].low;
      g_swing_low_time=rates[center].time;
     }

   const bool session_now=InSession(closed_bar.time);
   if(!session_now)
     {
      if(g_stage!=STAGE_LIVE && g_stage!=STAGE_WAIT_SWEEP)
        {
         CancelOurPendingOrders();
         ResetPlan();
        }
      return;
     }

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick))
      return;
   const double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   if(point<=0.0 || (tick.ask-tick.bid)/point>InpMaxSpreadPoints)
      return;

   const double atr=GetATR(1);
   if(atr<=0.0)
      return;

   if(g_stage==STAGE_WAIT_SWEEP && NewEntriesAllowed(closed_bar.time))
     {
      const bool pivots_ready=g_swing_high>0.0 && g_swing_low>0.0;
      const double bull_depth=pivots_ready ? g_swing_low-closed_bar.low : 0.0;
      const double bear_depth=pivots_ready ? closed_bar.high-g_swing_high : 0.0;
      const bool raw_bull=pivots_ready && closed_bar.low<g_swing_low && closed_bar.close>g_swing_low &&
                          closed_bar.time>g_swing_low_time && bull_depth<=atr*InpMaxSweepDepthATR;
      const bool raw_bear=pivots_ready && closed_bar.high>g_swing_high && closed_bar.close<g_swing_high &&
                          closed_bar.time>g_swing_high_time && bear_depth<=atr*InpMaxSweepDepthATR;
      const bool bull_sweep=raw_bull && !raw_bear && BiasAllows(1);
      const bool bear_sweep=raw_bear && !raw_bull && BiasAllows(-1);
      if(bull_sweep || bear_sweep)
        {
         g_direction=bull_sweep ? 1 : -1;
         g_stage=STAGE_WAIT_CHOCH;
         g_sweep_time=closed_bar.time;
         g_bars_since_sweep=0;
         g_sweep_extreme=bull_sweep ? closed_bar.low : closed_bar.high;
         g_sweep_reference=bull_sweep ? g_swing_low : g_swing_high;
         g_choch_level=bull_sweep ? g_swing_high : g_swing_low;
         DrawEvent(bull_sweep ? "SWEEP LONG" : "SWEEP SHORT",closed_bar.time,g_sweep_extreme,bull_sweep ? clrDeepSkyBlue : clrOrangeRed);
         PrintFormat("Liquidity sweep detected: direction=%d sweep=%.*f CHoCH=%.*f",g_direction,_Digits,g_sweep_extreme,_Digits,g_choch_level);
        }
     }

   if(g_stage==STAGE_WAIT_CHOCH)
     {
      g_bars_since_sweep=(int)((closed_bar.time-g_sweep_time)/PeriodSeconds(PERIOD_M5));
      if(g_direction>0)
         g_sweep_extreme=MathMin(g_sweep_extreme,closed_bar.low);
      else
         g_sweep_extreme=MathMax(g_sweep_extreme,closed_bar.high);

      const bool depth_invalid=g_direction>0 ? g_sweep_reference-g_sweep_extreme>atr*InpMaxSweepDepthATR
                                             : g_sweep_extreme-g_sweep_reference>atr*InpMaxSweepDepthATR;
      const bool reclaim_failed=g_direction>0 ? closed_bar.close<g_sweep_reference : closed_bar.close>g_sweep_reference;
      if(depth_invalid || reclaim_failed || g_bars_since_sweep>InpMaxSweepToChochBars || !NewEntriesAllowed(closed_bar.time))
        {
         ResetPlan();
         return;
        }

      const double body=MathAbs(closed_bar.close-closed_bar.open);
      const bool displacement_ok=InpMinDisplacementATR<=0.0 || body>=atr*InpMinDisplacementATR;
      const bool choch=g_direction>0 ? closed_bar.time>g_sweep_time && closed_bar.close>g_choch_level && displacement_ok
                                     : closed_bar.time>g_sweep_time && closed_bar.close<g_choch_level && displacement_ok;
      if(choch)
        {
         g_stage=STAGE_WAIT_FVG;
         g_choch_time=closed_bar.time;
         g_bars_since_choch=0;
         DrawEvent(g_direction>0 ? "CHoCH LONG" : "CHoCH SHORT",closed_bar.time,closed_bar.close,g_direction>0 ? clrLimeGreen : clrTomato);
         PrintFormat("CHoCH confirmed after sweep: direction=%d",g_direction);
        }
     }

   if(g_stage==STAGE_WAIT_FVG)
     {
      g_bars_since_choch=(int)((closed_bar.time-g_choch_time)/PeriodSeconds(PERIOD_M5));
      if(g_bars_since_choch>InpMaxChochToFvgBars || !NewEntriesAllowed(closed_bar.time))
        {
         ResetPlan();
         return;
        }

      const bool later_bar=closed_bar.time>g_choch_time;
      const bool bull_fvg=g_direction>0 && later_bar && rates[1].low>rates[3].high && rates[1].low-rates[3].high>=atr*InpMinFvgATR;
      const bool bear_fvg=g_direction<0 && later_bar && rates[1].high<rates[3].low && rates[3].low-rates[1].high>=atr*InpMinFvgATR;
      if(!bull_fvg && !bear_fvg)
         return;

      const double fvg_low=bull_fvg ? rates[3].high : rates[1].high;
      const double fvg_high=bull_fvg ? rates[1].low : rates[3].low;
      const double entry=(fvg_low+fvg_high)/2.0;
      const double stop=g_direction>0 ? g_sweep_extreme-atr*InpSLBufferATR : g_sweep_extreme+atr*InpSLBufferATR;
      if(PlaceSetupOrder(g_direction,entry,stop,atr,closed_bar.time))
        {
         const datetime expiry=closed_bar.time+InpPendingExpiryBars*PeriodSeconds(PERIOD_M5);
         DrawPlan(rates[3].time,closed_bar.time,expiry,fvg_low,fvg_high);
        }
      else
         ResetPlan();
     }

   if(g_stage==STAGE_PENDING && !HasOurPendingOrder())
     {
      ulong position_ticket=0;
      if(!HasOurPosition(position_ticket))
         ResetPlan();
     }
  }

int OnInit()
  {
   if(InpRequireM5 && _Period!=PERIOD_M5)
     {
      Print("Attach the EA to an M5 chart or disable InpRequireM5.");
      return INIT_PARAMETERS_INCORRECT;
     }
   if((!InpUseAsiaSession && !InpUseNewYorkSession) || InpSwingLength<1 || InpHTFFastEMA<1 || InpHTFSlowEMA<=InpHTFFastEMA ||
      (InpSizingMode==SIZING_RISK_PERCENT && InpRiskPercent<=0.0) || InpLotMultiplier<=0.0 ||
      InpRewardRisk<=0.0 || InpBreakEvenAtR<=0.0 || InpMinStopATR>InpMaxStopATR ||
      (InpUseChallengeLimits && (InpChallengeProfitTarget<=0.0 || InpChallengeMaxDailyLoss<=0.0 || InpChallengeMaxLoss<=0.0 || InpChallengeMinTradeDays<1 || InpChallengeTargetDays<1)))
      return INIT_PARAMETERS_INCORRECT;

   g_atr_handle=iATR(_Symbol,PERIOD_M5,InpATRPeriod);
   g_h1_fast_handle=iMA(_Symbol,PERIOD_H1,InpHTFFastEMA,0,MODE_EMA,PRICE_CLOSE);
   g_h1_slow_handle=iMA(_Symbol,PERIOD_H1,InpHTFSlowEMA,0,MODE_EMA,PRICE_CLOSE);
   g_h4_fast_handle=iMA(_Symbol,PERIOD_H4,InpHTFFastEMA,0,MODE_EMA,PRICE_CLOSE);
   g_h4_slow_handle=iMA(_Symbol,PERIOD_H4,InpHTFSlowEMA,0,MODE_EMA,PRICE_CLOSE);
   if(g_atr_handle==INVALID_HANDLE || g_h1_fast_handle==INVALID_HANDLE || g_h1_slow_handle==INVALID_HANDLE ||
      g_h4_fast_handle==INVALID_HANDLE || g_h4_slow_handle==INVALID_HANDLE)
      return INIT_FAILED;

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetAsyncMode(false);
   g_initial_balance=AccountInfoDouble(ACCOUNT_BALANCE);
   g_challenge_start_time=TimeCurrent();
   g_day_start_equity=AccountInfoDouble(ACCOUNT_EQUITY);
   g_min_equity=g_day_start_equity;
   UpdateChallengeMetrics(TimeCurrent());
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   CloseWeekMetrics(AccountInfoDouble(ACCOUNT_BALANCE));
   const bool limits_ok=g_trade_days>=InpChallengeMinTradeDays && g_max_daily_loss_seen<InpChallengeMaxDailyLoss &&
                        MathMax(0.0,g_initial_balance-g_min_equity)<InpChallengeMaxLoss;
   const bool target_reached=g_target_reached_time>0;
   const bool target_in_time=target_reached && g_target_reached_time-g_challenge_start_time<=InpChallengeTargetDays*86400;
   const string challenge_result=!limits_ok || !target_reached ? "FAIL" : target_in_time ? "PASS_14D" : "PASS_LATE";
   PrintFormat("CHALLENGE SUMMARY: result=%s start=%.2f final=%.2f net=%.2f trade_days=%d traded_weeks=%d profitable_weeks=%d losing_weeks=%d max_daily_loss=%.2f max_loss_from_start=%.2f target_reached=%s target_days=%d",
               challenge_result,
               g_initial_balance,AccountInfoDouble(ACCOUNT_BALANCE),AccountInfoDouble(ACCOUNT_BALANCE)-g_initial_balance,
               g_trade_days,g_traded_weeks,g_profitable_weeks,g_losing_weeks,g_max_daily_loss_seen,
               MathMax(0.0,g_initial_balance-g_min_equity),g_target_reached_time>0 ? TimeToString(g_target_reached_time,TIME_DATE|TIME_MINUTES) : "NO",InpChallengeTargetDays);
   if(g_atr_handle!=INVALID_HANDLE)
      IndicatorRelease(g_atr_handle);
   if(g_h1_fast_handle!=INVALID_HANDLE)
      IndicatorRelease(g_h1_fast_handle);
   if(g_h1_slow_handle!=INVALID_HANDLE)
      IndicatorRelease(g_h1_slow_handle);
   if(g_h4_fast_handle!=INVALID_HANDLE)
      IndicatorRelease(g_h4_fast_handle);
   if(g_h4_slow_handle!=INVALID_HANDLE)
      IndicatorRelease(g_h4_slow_handle);
   if(!InpKeepHistoricalObjects)
      ObjectsDeleteAll(0,ObjectPrefix());
   Comment("");
  }

void OnTradeTransaction(const MqlTradeTransaction &transaction,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(transaction.type!=TRADE_TRANSACTION_DEAL_ADD || transaction.deal==0 || !HistoryDealSelect(transaction.deal))
      return;
   if(HistoryDealGetString(transaction.deal,DEAL_SYMBOL)!=_Symbol ||
      HistoryDealGetInteger(transaction.deal,DEAL_MAGIC)!=InpMagicNumber)
      return;

   const ENUM_DEAL_ENTRY entry_type=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(transaction.deal,DEAL_ENTRY);
   const datetime deal_time=(datetime)HistoryDealGetInteger(transaction.deal,DEAL_TIME);
   const double deal_price=HistoryDealGetDouble(transaction.deal,DEAL_PRICE);
   if(entry_type==DEAL_ENTRY_IN || entry_type==DEAL_ENTRY_INOUT)
     {
      DrawEvent(g_direction>0 ? "FILL LONG" : "FILL SHORT",deal_time,deal_price,clrGold);
      const int trade_day=DayKey(deal_time);
      if(trade_day!=g_last_trade_day_key)
        {
         g_last_trade_day_key=trade_day;
         g_trade_days++;
        }
      g_week_had_trade=true;
      if(!g_had_position)
         g_trades_today++;
      g_had_position=true;
      g_stage=STAGE_LIVE;
      CancelOurPendingOrders();
      return;
     }

   if(entry_type==DEAL_ENTRY_OUT || entry_type==DEAL_ENTRY_OUT_BY)
     {
      const ENUM_DEAL_REASON reason=(ENUM_DEAL_REASON)HistoryDealGetInteger(transaction.deal,DEAL_REASON);
      const string exit_tag=reason==DEAL_REASON_TP ? "EXIT TP" : reason==DEAL_REASON_SL ? "EXIT SL/BE" : "EXIT";
      DrawEvent(exit_tag,deal_time,deal_price,reason==DEAL_REASON_TP ? clrLimeGreen : clrRed);
      ulong remaining_ticket=0;
      if(!HasOurPosition(remaining_ticket))
        {
         g_had_position=false;
         ResetPlan();
        }
     }
  }

void OnTick()
  {
   UpdateChallengeMetrics(TimeCurrent());
   const datetime current_bar=iTime(_Symbol,PERIOD_M5,0);
   if(current_bar==0 || current_bar==g_last_bar_time)
      return;

   g_last_bar_time=current_bar;
   ProcessClosedBar();

   Comment(StringFormat("EKV Asia/NY Sweep / CHoCH / FVG v1.20\nStage: %d  Direction: %d  Trades today: %d\nPlanned lots: %.2f  Entry: %.*f\nDay start equity: %.2f",
                        (int)g_stage,g_direction,g_trades_today,g_planned_lots,_Digits,g_planned_entry,g_day_start_equity));
  }
