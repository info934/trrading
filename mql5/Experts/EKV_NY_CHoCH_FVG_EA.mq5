#property copyright "EKV TradeGold"
#property version   "1.00"
#property strict
#property description "NY-open CHoCH + displacement FVG + 50-61.8 retracement EA"

#include <Trade/Trade.mqh>

enum ENUM_POSITION_SIZING
  {
   SIZING_RISK_PERCENT = 0,
   SIZING_FIXED_LOTS   = 1
  };

enum ENUM_SETUP_STAGE
  {
   STAGE_WAIT_CHOCH = 0,
   STAGE_WAIT_FVG   = 1,
   STAGE_PENDING    = 2,
   STAGE_LIVE       = 3
  };

input group "01 - Environment"
input long                 InpMagicNumber          = 26071001;
input bool                 InpRequireM5            = true;
input int                  InpSessionStartHour     = 16;       // broker server time
input int                  InpSessionStartMinute   = 30;
input int                  InpSessionEndHour       = 18;       // broker server time
input int                  InpSessionEndMinute     = 30;
input int                  InpMaxTradesPerDay      = 2;
input double               InpMaxDailyLossPct      = 1.0;
input int                  InpMaxSpreadPoints      = 80;

input group "02 - Structure and FVG"
input int                  InpSwingLength          = 3;
input int                  InpMaxChochToFvgBars    = 12;
input int                  InpPendingExpiryBars    = 20;
input int                  InpATRPeriod            = 14;
input double               InpMinDisplacementATR   = 0.30;
input double               InpMinFvgATR            = 0.05;
input double               InpFibZoneStart         = 0.500;
input double               InpFibZoneEnd           = 0.618;
input double               InpSLBufferATR          = 0.10;
input double               InpMinStopATR           = 0.10;
input double               InpMaxStopATR           = 10.0;

input group "03 - Risk and exits"
input ENUM_POSITION_SIZING InpSizingMode           = SIZING_RISK_PERCENT;
input double               InpRiskPercent          = 0.50;
input double               InpFixedLots            = 0.10;
input double               InpLotMultiplier        = 1.00;
input double               InpMaximumLots          = 10.0;
input double               InpRewardRisk           = 4.0;
input int                  InpBreakEvenOffsetPoints = 10;

CTrade trade;
int g_atr_handle = INVALID_HANDLE;
datetime g_last_bar_time = 0;

ENUM_SETUP_STAGE g_stage = STAGE_WAIT_CHOCH;
int g_direction = 0;
int g_structure_bias = 0;
bool g_swing_high_crossed = false;
bool g_swing_low_crossed = false;
bool g_session_choch_found = false;
bool g_had_position = false;
bool g_be_moved = false;

double g_swing_high = 0.0;
double g_swing_low = 0.0;
datetime g_swing_high_time = 0;
datetime g_swing_low_time = 0;
datetime g_choch_time = 0;
int g_bars_since_choch = 0;
double g_impulse_origin = 0.0;
double g_impulse_extreme = 0.0;
double g_be_confirm_level = 0.0;
double g_planned_entry = 0.0;
double g_planned_sl = 0.0;
double g_planned_tp = 0.0;
double g_planned_lots = 0.0;

int g_day_key = -1;
int g_trades_today = 0;
double g_day_start_equity = 0.0;

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

bool InSession(const datetime value)
  {
   const int now_minute=MinuteOfDay(value);
   const int start_minute=InpSessionStartHour*60+InpSessionStartMinute;
   const int end_minute=InpSessionEndHour*60+InpSessionEndMinute;
   return now_minute>=start_minute && now_minute<end_minute;
  }

bool NewEntriesAllowed(const datetime value)
  {
   if(!InSession(value) || g_trades_today>=InpMaxTradesPerDay)
      return false;

   if(g_day_start_equity<=0.0)
      return true;

   const double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   const double drawdown_pct=(g_day_start_equity-equity)/g_day_start_equity*100.0;
   return drawdown_pct<InpMaxDailyLossPct;
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
   g_session_choch_found=false;
   if(!InSession(bar_time))
     {
      CancelOurPendingOrders();
      g_stage=STAGE_WAIT_CHOCH;
     }
  }

void ResetPlan(const bool keep_choch)
  {
   g_stage=keep_choch ? STAGE_WAIT_FVG : STAGE_WAIT_CHOCH;
   if(!keep_choch)
     {
      g_direction=0;
      g_choch_time=0;
      g_bars_since_choch=0;
      g_impulse_origin=0.0;
      g_impulse_extreme=0.0;
     }
   g_planned_entry=0.0;
   g_planned_sl=0.0;
   g_planned_tp=0.0;
   g_planned_lots=0.0;
   g_be_moved=false;
  }

bool PlaceSetupOrder(const int direction,const double entry,const double stop,const double atr,const datetime bar_time)
  {
   const double stop_distance=MathAbs(entry-stop);
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
   g_planned_lots=lots;
   g_be_confirm_level=g_impulse_extreme;
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
      const bool structure_confirmed=g_direction>0 ? closed_bar.close>g_be_confirm_level : closed_bar.close<g_be_confirm_level;
      if(structure_confirmed)
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
      const bool can_reuse_choch=InSession(closed_bar.time) && g_trades_today<InpMaxTradesPerDay && g_bars_since_choch<=InpMaxChochToFvgBars;
      ResetPlan(can_reuse_choch);
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
      ResetPlan(false);
     }

   const int center=InpSwingLength+1;
   if(IsPivotHigh(rates,center,InpSwingLength))
     {
      g_swing_high=rates[center].high;
      g_swing_high_time=rates[center].time;
      g_swing_high_crossed=false;
     }
   if(IsPivotLow(rates,center,InpSwingLength))
     {
      g_swing_low=rates[center].low;
      g_swing_low_time=rates[center].time;
      g_swing_low_crossed=false;
     }

   const bool bull_break=g_swing_high>0.0 && !g_swing_high_crossed && closed_bar.close>g_swing_high && closed_bar.time>g_swing_high_time;
   const bool bear_break=g_swing_low>0.0 && !g_swing_low_crossed && closed_bar.close<g_swing_low && closed_bar.time>g_swing_low_time;
   const bool valid_bull_break=bull_break && !bear_break;
   const bool valid_bear_break=bear_break && !bull_break;
   const bool bull_choch=valid_bull_break && g_structure_bias<0;
   const bool bear_choch=valid_bear_break && g_structure_bias>0;

   if(valid_bull_break)
     {
      g_swing_high_crossed=true;
      g_structure_bias=1;
     }
   if(valid_bear_break)
     {
      g_swing_low_crossed=true;
      g_structure_bias=-1;
     }

   const bool session_now=InSession(closed_bar.time);
   if(!session_now)
     {
      if(g_stage==STAGE_PENDING)
        {
         CancelOurPendingOrders();
         ResetPlan(false);
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

   const double body=MathAbs(closed_bar.close-closed_bar.open);
   const bool displacement_ok=InpMinDisplacementATR<=0.0 || body>=atr*InpMinDisplacementATR;
   if(g_stage==STAGE_WAIT_CHOCH && !g_session_choch_found && NewEntriesAllowed(closed_bar.time))
     {
      if((bull_choch || bear_choch) && displacement_ok)
        {
         g_direction=bull_choch ? 1 : -1;
         g_session_choch_found=true;
         g_stage=STAGE_WAIT_FVG;
         g_choch_time=closed_bar.time;
         g_bars_since_choch=0;
         g_impulse_origin=bull_choch ? g_swing_low : g_swing_high;
         g_impulse_extreme=bull_choch ? closed_bar.high : closed_bar.low;
         PrintFormat("Session CHoCH detected: direction=%d",g_direction);
        }
     }

   if(g_stage==STAGE_WAIT_FVG)
     {
      g_bars_since_choch++;
      if(g_direction>0)
         g_impulse_extreme=MathMax(g_impulse_extreme,closed_bar.high);
      else
         g_impulse_extreme=MathMin(g_impulse_extreme,closed_bar.low);

      if(g_bars_since_choch>InpMaxChochToFvgBars || !NewEntriesAllowed(closed_bar.time))
        {
         ResetPlan(false);
         return;
        }

      const double displacement_atr=GetATR(2);
      const double middle_body=MathAbs(rates[2].close-rates[2].open);
      const bool bull_displacement=rates[2].close>rates[2].open && rates[2].close>rates[3].high && (InpMinDisplacementATR<=0.0 || middle_body>=displacement_atr*InpMinDisplacementATR);
      const bool bear_displacement=rates[2].close<rates[2].open && rates[2].close<rates[3].low && (InpMinDisplacementATR<=0.0 || middle_body>=displacement_atr*InpMinDisplacementATR);
      const bool bull_fvg=g_direction>0 && rates[1].low>rates[3].high && rates[1].low-rates[3].high>=atr*InpMinFvgATR && bull_displacement;
      const bool bear_fvg=g_direction<0 && rates[1].high<rates[3].low && rates[3].low-rates[1].high>=atr*InpMinFvgATR && bear_displacement;
      if(!bull_fvg && !bear_fvg)
         return;

      const double fvg_low=bull_fvg ? rates[3].high : rates[1].high;
      const double fvg_high=bull_fvg ? rates[1].low : rates[3].low;
      const double entry=(fvg_low+fvg_high)/2.0;
      const double impulse_range=MathAbs(g_impulse_extreme-g_impulse_origin);
      if(impulse_range<=0.0)
         return;

      const double fib_a=g_direction>0 ? g_impulse_extreme-impulse_range*InpFibZoneStart : g_impulse_extreme+impulse_range*InpFibZoneStart;
      const double fib_b=g_direction>0 ? g_impulse_extreme-impulse_range*InpFibZoneEnd : g_impulse_extreme+impulse_range*InpFibZoneEnd;
      const double fib_low=MathMin(fib_a,fib_b);
      const double fib_high=MathMax(fib_a,fib_b);
      if(entry<fib_low || entry>fib_high)
         return;

      const double stop=g_direction>0 ? MathMin(rates[1].low,rates[2].low)-atr*InpSLBufferATR : MathMax(rates[1].high,rates[2].high)+atr*InpSLBufferATR;
      PlaceSetupOrder(g_direction,entry,stop,atr,closed_bar.time);
     }

   if(g_stage==STAGE_PENDING && !HasOurPendingOrder())
     {
      ulong position_ticket=0;
      if(!HasOurPosition(position_ticket))
         ResetPlan(g_bars_since_choch<=InpMaxChochToFvgBars);
     }
  }

int OnInit()
  {
   if(InpRequireM5 && _Period!=PERIOD_M5)
     {
      Print("Attach the EA to an M5 chart or disable InpRequireM5.");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpSwingLength<1 || InpFibZoneStart>=InpFibZoneEnd || InpRiskPercent<=0.0 || InpLotMultiplier<=0.0 || InpRewardRisk<=0.0)
      return INIT_PARAMETERS_INCORRECT;

   g_atr_handle=iATR(_Symbol,PERIOD_M5,InpATRPeriod);
   if(g_atr_handle==INVALID_HANDLE)
      return INIT_FAILED;

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetAsyncMode(false);
   g_day_start_equity=AccountInfoDouble(ACCOUNT_EQUITY);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(g_atr_handle!=INVALID_HANDLE)
      IndicatorRelease(g_atr_handle);
   Comment("");
  }

void OnTick()
  {
   const datetime current_bar=iTime(_Symbol,PERIOD_M5,0);
   if(current_bar==0 || current_bar==g_last_bar_time)
      return;

   g_last_bar_time=current_bar;
   ProcessClosedBar();

   Comment(StringFormat("EKV NY CHoCH FVG\nStage: %d  Bias: %d  Trades today: %d\nPlanned lots: %.2f  Entry: %.*f\nDay start equity: %.2f",
                        (int)g_stage,g_structure_bias,g_trades_today,g_planned_lots,_Digits,g_planned_entry,g_day_start_equity));
  }
