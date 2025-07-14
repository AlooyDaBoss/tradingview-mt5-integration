#include <Trade\Trade.mqh>
CTrade trade;

//--- Input Parameters
input string signalFile = "signal.txt";      // File name for the signal
input double riskPercent = 10;                // Risk % of account balance
input double extraPips = 50;                  // Extra buffer for SL in pips
input double rrRatio = 1.5;                   // Risk-to-Reward Ratio

//--- Global Variables
datetime lastCheckTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("? EA Initialized.");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Wait 5 seconds between checks to conserve resources
   if (TimeCurrent() - lastCheckTime < 5)
      return;

   lastCheckTime = TimeCurrent();
   Print("?? Checking for signal...");

   // Check if a position for the current symbol already exists
   if (HasOpenPosition(_Symbol))
   {
      Print("? Trade already open on symbol ", _Symbol, ". Skipping.");
      return;
   }

   // Read the signal from the file
   string signalText = ReadSignalFile();
   if (StringLen(signalText) == 0)
   {
      Print("?? No signal data to process.");
      return;
   }

   // Validate the signal's freshness
   if (!IsFreshSignal(signalText))
   {
      Print("?? Signal invalid or outdated: ", signalText);
      return;
   }
   
   Print("?? Raw signal content: ", signalText);

   // Process the signal and execute trade
   if (StringFind(signalText, "buy") != -1)
   {
      Print("?? Detected BUY signal");
      ExecuteTrade(ORDER_TYPE_BUY);
   }
   else if (StringFind(signalText, "sell") != -1)
   {
      Print("?? Detected SELL signal");
      ExecuteTrade(ORDER_TYPE_SELL);
   }
   else
   {
      Print("? No actionable keyword ('buy' or 'sell') found.");
      return;
   }

   // Delete the signal file after processing
   bool deleted = FileDelete(signalFile);
   if (deleted)
      Print("?? Deleted signal file after execution.");
   else
      Print("?? Failed to delete signal file. Error: ", GetLastError());
}

//+------------------------------------------------------------------+
//| Executes a trade based on the signal type                        |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE type)
{
   double price, sl, tp;

   // Get the previous candle’s high and low for SL placement
   double candleLow  = iLow(_Symbol, _Period, 1);
   double candleHigh = iHigh(_Symbol, _Period, 1);

   if (type == ORDER_TYPE_BUY)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = NormalizeDouble(candleLow - extraPips * _Point, _Digits);
      double riskPoints = price - sl;
      Print("price===========", price);
      Print("sl===========", sl);
      double lotSize = CalculateLotSize(riskPoints);
      
      if(lotSize <= 0) 
      {
         Print("? Lot size is zero. Cannot place trade.");
         return;
      }
      
      tp = NormalizeDouble(price + (riskPoints * rrRatio), _Digits);

      if (trade.Buy(lotSize, _Symbol, price, sl, tp, "TV Buy"))
         Print("? BUY placed at ", price, " | SL: ", sl, " | TP: ", tp, " | Lots: ", lotSize);
      else
         Print("? BUY failed. Error: ", GetLastError());
   }
   else if (type == ORDER_TYPE_SELL)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = NormalizeDouble(candleHigh + extraPips * _Point, _Digits);
      double riskPoints = sl - price;
      double lotSize = CalculateLotSize(riskPoints);

      if(lotSize <= 0) 
      {
         Print("? Lot size is zero. Cannot place trade.");
         return;
      }

      tp = NormalizeDouble(price - (riskPoints * rrRatio), _Digits);

      if (trade.Sell(lotSize, _Symbol, price, sl, tp, "TV Sell"))
         Print("? SELL placed at ", price, " | SL: ", sl, " | TP: ", tp, " | Lots: ", lotSize);
      else
         Print("? SELL failed. Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Checks if there is an open position for a given symbol           |
//+------------------------------------------------------------------+
bool HasOpenPosition(string symbol)
{
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if (PositionGetTicket(i) > 0)
      {
         if (PositionGetString(POSITION_SYMBOL) == symbol)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Reads the content of the signal file                             |
//+------------------------------------------------------------------+
string ReadSignalFile()
{
   // Reset error code
   ResetLastError(); 
   int handle = FileOpen(signalFile, FILE_READ | FILE_TXT | FILE_ANSI);
   if (handle == INVALID_HANDLE)
   {
      Print("❌ Cannot open file: ", signalFile, " | Error: ", GetLastError());
      return "";
   }

   string content = FileReadString(handle);
   FileClose(handle);
   Print("? Successfully read: ", content);
   return content;
}

//+------------------------------------------------------------------+
//| Checks if the signal is fresh (within the last 60 seconds)       |
//+------------------------------------------------------------------+
bool IsFreshSignal(string signalText)
{
   string parts[];
   if (StringSplit(signalText, '|', parts) != 2)
      return false;

   string action = TrimString(parts[0]);
   long signalTime = (long)StringToInteger(parts[1]);

   if ((action != "buy" && action != "sell") || signalTime == 0)
      return false;

   long secondsAgo = TimeCurrent() - signalTime;
   if (secondsAgo > 60)
   {
      Print("?? Signal is too old: ", secondsAgo, " seconds ago");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| A simple trim function to remove leading/trailing whitespace     |
//+------------------------------------------------------------------+
string TrimString(string str)
{
   int start = 0;
   while (start < StringLen(str) && StringGetCharacter(str, start) <= ' ')
      start++;

   int end = StringLen(str) - 1;
   while (end >= start && StringGetCharacter(str, end) <= ' ')
      end--;

   if (end < start)
      return "";

   return StringSubstr(str, start, end - start + 1);
}


//+------------------------------------------------------------------+
//| Calculates lot size based on risk percentage and stop loss       |
//+------------------------------------------------------------------+
double CalculateLotSize(double riskInPoints)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * (riskPercent / 100.0);

   // Get symbol properties
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   double lots = 0.0;
   
   // Ensure no division by zero
   if (tickSize > 0 && tickValue > 0 && riskInPoints > 0)
   {
      double valuePerPoint = tickValue / tickSize; // always 1.0
      Print("tickValue===============", tickValue);
      Print("tickSize===============", tickSize);
      lots = riskMoney / (riskInPoints * valuePerPoint);
      Print("lots1==========", lots);
   } else {
       Print("? Could not calculate lot size due to invalid symbol info or risk points.");
       return 0.0;
   }

   // Normalize lot size according to broker's limits
   lots = MathFloor(lots / lotStep) * lotStep;
   Print("lots2==========", lots);

   // Clamp to min/max lot size
   lots = MathMax(minLot, MathMin(maxLot, lots));
   Print("lots3==========", lots);
   
   Print("?? Calculated Lot: ", lots, " | Risk Money: ", riskMoney, " | Risk Points: ", riskInPoints * _Point);
   
   // Final margin check
   double marginNeeded;
   if(!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, lots, SymbolInfoDouble(_Symbol, SYMBOL_ASK), marginNeeded))
   {
        Print("?? Could not calculate margin. Error: ", GetLastError());
        return 0.0;
   }
   
   if (marginNeeded > AccountInfoDouble(ACCOUNT_FREEMARGIN))
   {
      Print("?? Not enough free margin. Required: ", marginNeeded, " | Free: ", AccountInfoDouble(ACCOUNT_FREEMARGIN));
      return 0.0; // Return 0 if not enough margin
   }

   return lots;
}