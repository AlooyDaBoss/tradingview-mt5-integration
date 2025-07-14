#include <Trade\Trade.mqh>
CTrade trade;

input string signalFile = "signal.txt";
input double lotSize = 0.1;
input double extraPips = 50;  // Extra buffer for SL in pips
input double rrRatio = 1.5;   // Risk-to-Reward Ratio

datetime lastCheckTime = 0;

int OnInit()
{
   Print("✅ EA Initialized.");
   return INIT_SUCCEEDED;
}

void OnTick()
{
   if (TimeCurrent() - lastCheckTime < 5)
      return;  // Wait 5 seconds between checks

   lastCheckTime = TimeCurrent();
   Print("🔄 Checking for signal...");

   if (HasOpenPosition(_Symbol))
   {
      Print("⏹ Trade already open on symbol ", _Symbol, ". Skipping.");
      return;
   }

   string signalText = ReadSignalFile();
   if (StringLen(signalText) == 0)
   {
      Print("⚠️ No signal data to process.");
      return;
   }

   if (!IsFreshSignal(signalText))
   {
      Print("⚠️ Signal invalid or outdated: ", signalText);
      return;
   }

   Print("📩 Raw signal content: ", signalText);

   if (StringFind(signalText, "buy") != -1)
   {
      Print("📈 Detected BUY signal");
      ExecuteTrade(ORDER_TYPE_BUY);
   }
   else if (StringFind(signalText, "sell") != -1)
   {
      Print("📉 Detected SELL signal");
      ExecuteTrade(ORDER_TYPE_SELL);
   }
   else
   {
      Print("❓ No actionable keyword ('buy' or 'sell') found.");
      return;
   }

   bool deleted = FileDelete(signalFile);
   if (deleted)
      Print("🗑 Deleted signal file after execution.");
   else
      Print("⚠️ Failed to delete signal file. Error: ", GetLastError());
}

void ExecuteTrade(int type)
{
   double price, sl, tp;

   // Get the previous candle’s levels
   double candleLow  = iLow(_Symbol, _Period, 1);
   double candleHigh = iHigh(_Symbol, _Period, 1);

   if (type == ORDER_TYPE_BUY)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = NormalizeDouble(candleLow - extraPips * _Point, _Digits);
      double risk = price - sl;
      tp = NormalizeDouble(price + (risk * rrRatio), _Digits);

      if (trade.Buy(lotSize, _Symbol, price, sl, tp, "TV Buy"))
         Print("✅ BUY placed at ", price, " | SL: ", sl, " | TP: ", tp);
      else
         Print("❌ BUY failed. Error: ", GetLastError());
   }
   else if (type == ORDER_TYPE_SELL)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = NormalizeDouble(candleHigh + extraPips * _Point, _Digits);
      double risk = sl - price;
      tp = NormalizeDouble(price - (risk * rrRatio), _Digits);

      if (trade.Sell(lotSize, _Symbol, price, sl, tp, "TV Sell"))
         Print("✅ SELL placed at ", price, " | SL: ", sl, " | TP: ", tp);
      else
         Print("❌ SELL failed. Error: ", GetLastError());
   }
}

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

string ReadSignalFile()
{
   int handle = FileOpen(signalFile, FILE_READ | FILE_TXT | FILE_ANSI);
   if (handle == INVALID_HANDLE)
   {
      Print("❌ Cannot open file: ", signalFile, " | Error: ", GetLastError());
      return "";
   }

   string content = FileReadString(handle);
   FileClose(handle);
   Print("✅ Successfully read: ", content);
   return content;
}

bool IsFreshSignal(string signalText)
{
   string parts[];
   StringSplit(signalText, '|', parts);
   if (ArraySize(parts) != 2)
      return false;

   string action = TrimString(parts[0]);
   int signalTime = (int)StringToInteger(parts[1]);

   if ((action != "buy" && action != "sell") || signalTime == 0)
      return false;

   int secondsAgo = (int)(TimeCurrent() - signalTime);
   if (secondsAgo > 60)
   {
      Print("⚠️ Signal is too old: ", secondsAgo, " seconds ago");
      return false;
   }

   return true;
}

// ✅ Simple trim function for MQL5
string TrimString(string str)
{
   int start = 0;
   while (start < StringLen(str) && (uchar)StringGetCharacter(str, start) <= ' ')
      start++;

   int end = StringLen(str) - 1;
   while (end >= 0 && (uchar)StringGetCharacter(str, end) <= ' ')
      end--;

   if (end < start)
      return "";

   return StringSubstr(str, start, end - start + 1);
}
