#property copyright "Vyacheslav Demidyuk"
#property link      "http://mtapi4.net/"
#property version   "1.8"
#property description "MtApi connection expert"

#include <WinUser32.mqh>
#include <stdlib.mqh>
#include <json.mqh>

#import "MTConnector.dll"
   bool initExpert(int expertHandle, int port, string symbol, double bid, double ask, string& err);
   bool deinitExpert(int expertHandle, string& err);   
   bool updateQuote(int expertHandle, string symbol, double bid, double ask, string& err);
   bool sendEvent(int expertHandle, int eventType, string payload, string& err);  
   
   bool sendIntResponse(int expertHandle, int response, string& err);
   bool sendBooleanResponse(int expertHandle, int response, string& err);
   bool sendDoubleResponse(int expertHandle, double response, string& err);
   bool sendStringResponse(int expertHandle, string response, string& err);
   bool sendVoidResponse(int expertHandle, string& err);
   bool sendDoubleArrayResponse(int expertHandle, double& values[], int size, string& err);
   bool sendIntArrayResponse(int expertHandle, int& values[], int size, string& err);
   bool sendLongResponse(int expertHandle, long response, string& err);
   bool sendErrorResponse(int expertHandle, int code, string message, string& err);
   
   bool getCommandType(int expertHandle, int& res, string& err);
   bool getIntValue(int expertHandle, int paramIndex, int& res, string& err);
   bool getDoubleValue(int expertHandle, int paramIndex, double& res, string& err);
   bool getStringValue(int expertHandle, int paramIndex, string& res, string& err);
   bool getBooleanValue(int expertHandle, int paramIndex, bool& res, string& err);
   bool getLongValue(int expertHandle, int paramIndex, long& res, string& err);
#import

extern int Port = 8222;

int ExpertHandle;

string _error;
string _response_error;
bool isCrashed = FALSE;

bool IsRemoteReadyForTesting = false;

int _lastBarOpenTime;

class MtOrder
{
public:
   int getTicket() { return _ticket; }
   string getSymbol() { return _symbol; }
   int getOperation() { return _operation; }
   double getOpenPrice() { return _openPrice; }
   double getClosePrice() { return _closePrice; }
   double getLots() { return _lots; }
   double getProfit() { return _profit; }
   string getComment() { return _comment; }
   double getCommission() { return _commission; }
   int getMagicNumber() { return _magicNumber; }
   datetime getOpenTime() { return _openTime; }
   datetime getCloseTime() { return _closeTime; }
   double getSwap() { return _swap; }
   datetime getExpiration() { return _expiration; }
   double getTakeProfit() { return _takeProfit; }
   double getStopLoss() { return _stopLoss; }
   
   static bool isLong(int operation)
   {
      if (operation == OP_BUY || operation == OP_BUYLIMIT || operation == OP_BUYSTOP)
         return true;
      return false;
   }
   
   JSONObject* CreateJson()
   {
      JSONObject *jo = new JSONObject();   
      jo.put("Ticket", new JSONNumber(_ticket));
      jo.put("Symbol", new JSONString(_symbol));
      jo.put("Operation", new JSONNumber(_operation));
      jo.put("OpenPrice", new JSONNumber(_openPrice));
      jo.put("ClosePrice", new JSONNumber(_closePrice));
      jo.put("Lots", new JSONNumber(_lots));
      jo.put("Profit", new JSONNumber(_profit));
      jo.put("Comment", new JSONString(_comment));
      jo.put("Commission", new JSONString(_commission));
      jo.put("MagicNumber", new JSONNumber(_magicNumber));
      jo.put("Commission", new JSONString(_commission));
      jo.put("MagicNumber", new JSONNumber(_magicNumber));
      jo.put("MtOpenTime", new JSONNumber(_openTime));
      jo.put("MtCloseTime", new JSONNumber(_closeTime));
      jo.put("Swap", new JSONNumber(_swap));
      jo.put("MtExpiration", new JSONNumber(_expiration));
      jo.put("TakeProfit", new JSONNumber(_takeProfit));
      jo.put("StopLoss", new JSONNumber(_stopLoss));
      return jo;
   }
         
   static MtOrder* LoadOrder(int index, int select, int pool)
   {
      MtOrder* order = NULL;
      if (OrderSelect(index, select, pool))
      {
         order = new MtOrder();
         order._ticket = OrderTicket();
         order._symbol = OrderSymbol();
         order._operation = OrderType();
         order._openPrice = OrderOpenPrice();
         order._closePrice = OrderClosePrice();
         order._lots = OrderLots();
         order._profit = OrderProfit();
         order._comment = OrderComment();
         order._commission = OrderCommission();
         order._magicNumber = OrderMagicNumber();
         order._openTime = OrderOpenTime();
         order._closeTime = OrderCloseTime();
         order._swap = OrderSwap();
         order._expiration = OrderExpiration();
         order._takeProfit = OrderTakeProfit();
         order._stopLoss = OrderStopLoss();
      }
      return order;
   }         
         
private:
   int _ticket;
   string _symbol;
   int _operation;
   double _openPrice;
   double _closePrice;
   double _lots;
   double _profit;
   string _comment;
   double _commission;
   int _magicNumber;
   datetime _openTime;
   datetime _closeTime;
   double _swap;
   datetime _expiration;
   double _takeProfit;
   double _stopLoss;
};

class MtTimeBar
{
public:
   MtTimeBar(string symbol, datetime openTime, datetime closeTime, double open, double close, double high, double low)
   {
      _symbol = symbol;
      _openTime = openTime;
      _closeTime = closeTime;
      _open = open;
      _close = close;
      _high = high;
      _low = low;
   }

   string getSymbol() { return _symbol; }
   datetime getOpenTime() { return _openTime; }
   datetime getCloseTime() { return _closeTime; }
   double getOpen() { return _open; }
   double getClose() { return _close; }
   double getHigh() { return _high; }
   double getLow() { return _low; }

   JSONObject* CreateJson()
   {
      JSONObject *jo = new JSONObject();   
      jo.put("Symbol", new JSONString(_symbol));
      jo.put("MtOpenTime", new JSONNumber(_openTime));
      jo.put("MtCloseTime", new JSONNumber(_closeTime));
      jo.put("Open", new JSONNumber(_open));
      jo.put("Close", new JSONNumber(_close));
      jo.put("High", new JSONNumber(_high));
      jo.put("Low", new JSONNumber(_low));
      return jo;
   }
   
private:
   string _symbol;
   datetime _openTime;
   datetime _closeTime;
   double _open;
   double _close;
   double _high;
   double _low;
};

class MtSession
{
   public:  
      static MtSession* LoadSession(string symbol, int day, int index, int type)
      {
         MtSession *session = new MtSession(symbol, day, index, type);
         
         if (type == QUOTE)
         {
            session._hasData = SymbolInfoSessionQuote(symbol, day, index, session._from, session._to);
         }
         else
         {
            session._hasData = SymbolInfoSessionTrade(symbol, day, index, session._from, session._to);
         }
         
         return session;          
      }
   
      JSONObject* CreateJson()
      {
         JSONObject *jo = new JSONObject();
         jo.put("Symbol", new JSONString(_symbol));
         jo.put("DayOfWeek", new JSONNumber(_dayOfWeek));
         jo.put("Index", new JSONNumber(_index));
         jo.put("MtFromTime", new JSONNumber(_from));
         jo.put("MtToTime", new JSONNumber(_to));
         jo.put("HasData", new JSONBool(_hasData));
         jo.put("Type", new JSONNumber(_type));
         return jo;
      }

   private:
      string _symbol;
      int _dayOfWeek;
      int _index;
      datetime _from;
      datetime _to;
      bool _hasData;
      int _type;
      
      MtSession(string symbol, int day, int index, int type)
      {
         _symbol = symbol;
         _dayOfWeek = day;
         _index = index;
         _type = type;
      }
};

enum MtSessionType
{
   QUOTE,
   TRADE
};

enum MtEventTypes
{
   LAST_TIME_BAR_EVENT = 1
};

int preinit()
{
//   StringInit(message,1000,0);
   StringInit(_error,1000,0);
   StringInit(_response_error,1000,0);
/*
   StringInit(symbolValue,200,0);
   StringInit(commentValue,200,0);
   StringInit(msgValue,200,0);
   StringInit(captionValue,200,0);
   StringInit(filenameValue,200,0);
   StringInit(ftp_pathValue,200,0);
   StringInit(subjectValue,200,0);
   StringInit(some_textValue,200,0);
   StringInit(nameValue,200,0);
   StringInit(prefix_nameValue,200,0);
   StringInit(requestValue, 500,0);
*/
   return (0);
}

int init() {
   preinit();
     
   if (IsDllsAllowed() == FALSE) 
   {
      MessageBox("Dlls not allowed.", "MtApi", MB_OK);
      isCrashed = TRUE;
      return (1);
   }
   if (IsLibrariesAllowed() == FALSE) 
   {
      MessageBox("Libraries not allowed.", "MtApi", MB_OK);
      isCrashed = TRUE;
      return (1);
   }

   if (IsTradeAllowed() == FALSE) 
   {
      MessageBox("Trade not allowed.", "MtApi", MB_OK);
      isCrashed = TRUE;
      return (1);
   }  

   ExpertHandle = WindowHandle(Symbol(), Period());
   
   if (!initExpert(ExpertHandle, Port, Symbol(), Bid, Ask, _error))
   {
       MessageBox(_error, "MtApi", MB_OK);
       isCrashed = TRUE;
       return(1);
   }
    
   if (ExecuteCommand() == 1)
   {   
      isCrashed = TRUE;
      return (1);
   }
   
   //--- Backtesting mode
   if (IsTesting())
   {      
      Print("Waiting on remote client...");
      //wait for command (BacktestingReady) from remote side to be ready for work
      while(!IsRemoteReadyForTesting)
      {
         ExecuteCommand();
         
         //This section uses a while loop to simulate Sleep() during Backtest.
         unsigned int viSleepUntilTick = GetTickCount() + 100; //100 milliseconds
         while(GetTickCount() < viSleepUntilTick) 
         {
            //Do absolutely nothing. Just loop until the desired tick is reached.
         }
      }
   }
   //--- 
   
   _lastBarOpenTime = Time[0];
   
   return (0);
}

int deinit() {
   if (isCrashed == 0) 
   {
      if (!deinitExpert(ExpertHandle, _error)) 
      {
         MessageBox(_error, "MtApi", MB_OK);
         isCrashed = TRUE;
         return (1);
      }
   }
   
   return (0);
}

int start() 
{
   updateQuote(ExpertHandle, Symbol(), Bid, Ask, _error);
     
   if (_lastBarOpenTime != Time[0])
   {
      Print("start() new bar: _lastBarOpenTime = ", _lastBarOpenTime, "; Time[0] = ", Time[0]);
   
      double open = Open[1];
      double close = Close[1];
      double high = High[1];
      double low = Low[1];
      
      MtTimeBar* timeBar = new MtTimeBar(Symbol(), _lastBarOpenTime, Time[0], open, close, high, low);
      SendLastTimeBartEvent(timeBar);
      delete timeBar;
      
      _lastBarOpenTime = Time[0];
   }

   
   if (IsTesting())
   {
        while(true)
        {
            int executedCommand = ExecuteCommand();
            if (executedCommand == 0) break;
        }
   }
      
   return (0);
}

void OnTimer()
{
   while(true)
   {
      int executedCommand = ExecuteCommand();
      if (executedCommand == 0) return;
   }
}

void SendLastTimeBartEvent(MtTimeBar* timeBar)
{
   JSONObject* json = timeBar.CreateJson();
   if (sendEvent(ExpertHandle, (int)LAST_TIME_BAR_EVENT, json.toString(), _error))
   {
      Print("Send LastTimeBar event: payload = ", json.toString());      
   }
   else
   {
      PrintFormat("[ERROR] SendLastTimeBartEvent: %s", _error);
   }
   
   delete json;
}

int ExecuteCommand()
{
   int command_type = 0;
      
   if (!getCommandType(ExpertHandle, command_type, _error))
   {
      Print("[ERROR] ExecuteCommand: Failed to get command type!", _error);
      return (0);
   }         
   
   if (command_type > 0)
   {
      Print("ExecuteCommand: commnad type = ", command_type);
   }
   
   switch (command_type) 
   {
   case 0:
      //NoCommand    
   break;   
   case 155: //Request
      Execute_Request();
   break;      
   case 151: //OrderCloseAll
      Execute_OrderCloseAll();
   break;      
   case 3: // OrderCloseBy
      Execute_OrderCloseBy();            
   break;      
   case 4: // OrderClosePrice
      Execute_OrderClosePrice();           
   break;      
   case 1004: // OrderClosePriceByTicket
      Execute_OrderClosePriceByTicket();            
   break;                   
   case 5: //OrderCloseTime
      Execute_OrderCloseTime();        
   break;
   case 6: //OrderComment
      Execute_OrderComment();
   break;
   case 7: //OrderCommission
      Execute_OrderCommission();      
   break;      
   case 8: //OrderDelete
      Execute_OrderDelete();
   break;      
   case 9: //OrderExpiration
      Execute_OrderExpiration();             
   break;      
   case 10: //OrderLots
      Execute_OrderLots();              
   break;
   case 11: //OrderMagicNumber
      Execute_OrderMagicNumber();           
   break;      
   case 12: //OrderModify
      Execute_OrderModify();                     
   break;      
   case 13: //OrderOpenPrice
      Execute_OrderOpenPrice();          
   break;      
   case 1013: // OrderOpenPriceByTicket
      Execute_OrderOpenPriceByTicket();           
   break;      
   case 14: //OrderOpenTime
      Execute_OrderOpenTime();      
   break;      
   case 15: //OrderPrint
      Execute_OrderPrint();
   break;      
   case 16: //OrderProfit
      Execute_OrderProfit();          
   break;      
   case 17: //OrderSelect
      Execute_OrderSelect();           
   break;      
   case 18: //OrdersHistoryTotal
      Execute_OrdersHistoryTotal();
   break;      
   case 19: //OrderStopLoss
      Execute_OrderStopLoss();
   break;   
   case 20: //OrdersTotal
      Execute_OrdersTotal();
   break;
   case 21: //OrderSwap
      Execute_OrderSwap();
   break;
   case 22: //OrderSymbol
      Execute_OrderSymbol();
   break;      
   case 23: //OrderTakeProfit
      Execute_OrderTakeProfit();
   break;      
   case 24: //OrderTicket
      Execute_OrderTicket();
   break;      
   case 25: //OrderType
      Execute_OrderType();
   break;      
   case 26: //GetLastError
      Execute_GetLastError();
   break;
   case 27: //IsConnected
      Execute_IsConnected();
   break;
   case 28: //IsDemo
      Execute_IsDemo();
   break;      
   case 29: //IsDllsAllowed
      Execute_IsDllsAllowed();
   break;      
   case 30: //IsExpertEnabled
      Execute_IsExpertEnabled();
   break;      
   case 31: //IsLibrariesAllowed
      Execute_IsLibrariesAllowed();
   break;      
   case 32: //IsOptimization
      Execute_IsOptimization();
   break;      
   case 33: //IsStopped
      Execute_IsStopped();
   break;
   case 34: //IsTesting
      Execute_IsTesting();
   break;      
   case 35: //IsTradeAllowed
      Execute_IsTradeAllowed();
   break;      
   case 36: //IsTradeContextBusy
      Execute_IsTradeContextBusy();
   break;
   case 37: //IsVisualMode
      Execute_IsVisualMode();
   break;      
   case 38: //UninitializeReason
      Execute_UninitializeReason();
   break;      
   case 39: //ErrorDescription
      Execute_ErrorDescription();
   break;      
   case 40: //AccountBalance
      Execute_AccountBalance();
   break;      
   case 41: //AccountCredit
      Execute_AccountCredit();      
   break;      
   case 42: //AccountCompany
      Execute_AccountCompany();
   break;      
   case 43: //AccountCurrency
      Execute_AccountCurrency();
   break;      
   case 44: //AccountEquity
      Execute_AccountEquity();
   break;     
   case 45: //AccountFreeMargin
      Execute_AccountFreeMargin();
   break;      
   case 46: //AccountFreeMarginCheck
      Execute_AccountFreeMarginCheck();
   break;
   case 47: //AccountFreeMarginMode
      Execute_AccountFreeMarginMode();
   break;      
   case 48: //AccountLeverage
      Execute_AccountLeverage();
   break;
   case 49: //AccountMargin
      Execute_AccountMargin();
   break;   
   case 50: //AccountName
      Execute_AccountName();
   break;
   case 51: //AccountNumber
      Execute_AccountNumber();
   break;
   case 52: //AccountProfit
      Execute_AccountProfit();
   break;
   case 53: //AccountServer
      Execute_AccountServer();
   break;
   case 54: //AccountStopoutLevel
      Execute_AccountStopoutLevel();
   break;
   case 55: //AccountStopoutMode
      Execute_AccountStopoutMode();
   break;
   case 56: //Alert
      Execute_Alert();
   break;
   case 57: //Comment
      Execute_Comment();
   break;
   case 58: //GetTickCount
      Execute_GetTickCount();
   break;
   case 59: //MarketInfo   
      Execute_MarketInfo();
   break;
   case 60: //MessageBox
      Execute_MessageBox(false);
   break;
   case 61: //MessageBoxA
      Execute_MessageBox(true);
   break;
   case 62: //PlaySound
      Execute_PlaySound();
   break;
   case 63: //Print
      Execute_Print();
   break;
   case 64: //SendFTP
      Execute_SendFTP(false);
   break;
   case 65: //SendFTPA
      Execute_SendFTP(true);      
   break;
   case 66: //SendMail
      Execute_SendMail();
   break;
   case 67: //Sleep
      Execute_Sleep();      
   break;
   case 68: //TerminalCompany      
      Execute_TerminalCompany();
   break;
   case 69: //TerminalName
      Execute_TerminalName();
   break;
   case 70: //TerminalPath
      Execute_TerminalPath();
   break;   
   case 71: //Day
      Execute_Day();
   break;
   case 72: //DayOfWeek
      Execute_DayOfWeek();
   break;
   case 73: //DayOfYear
      Execute_DayOfYear();
   break;
   case 74: //Hour
      Execute_Hour();      
   break;
   case 75: //Minute
      Execute_Minute();      
   break;
   case 76: //Month
      Execute_Month();
   break;
   case 77: //Seconds
      Execute_Seconds();      
   break;
   case 78: //TimeCurrent
      Execute_TimeCurrent();
   break;
   case 79: //TimeDay
      Execute_TimeDay();      
   break;
   case 80: //TimeDayOfWeek
      Execute_TimeDayOfWeek();
   break;
   case 81: //TimeDayOfYear
      Execute_TimeDayOfYear();
   break;
   case 82: //TimeHour
      Execute_TimeHour();      
   break;
   case 83: //TimeLocal
      Execute_TimeLocal();
   break;
   case 84: //TimeMinute
      Execute_TimeMinute();      
   break;
   case 85: //TimeMonth
      Execute_TimeMonth();      
   break;
   case 86: //TimeSeconds
      Execute_TimeSeconds();      
   break;
   case 87: //TimeYear
      Execute_TimeYear();
   break;          
   case 88: //Year
      Execute_Year();
   break;      
   case 89: //GlobalVariableCheck
      Execute_GlobalVariableCheck();      
   break;
   case 90: //GlobalVariableDel
      Execute_GlobalVariableDel();      
   break;
   case 91: //GlobalVariableGet
      Execute_GlobalVariableGet();
   break;
   case 92: //GlobalVariableName
      Execute_GlobalVariableName();      
   break;   
   case 93: //GlobalVariableSet
      Execute_GlobalVariableSet();      
   break;   
   case 94: //GlobalVariableSetOnCondition
      Execute_GlobalVariableSetOnCondition();      
   break;   
   case 95: //GlobalVariablesDeleteAll
      Execute_GlobalVariablesDeleteAll();      
   break;   
   case 96: //GlobalVariablesTotal
      Execute_GlobalVariablesTotal();
   break;   
   case 97: //iAC
      Execute_iAC();
   break;
   case 98: //iAD
      Execute_iAD();    
   break;
   case 99: //iAlligator
      Execute_iAlligator();   
   break;   
   case 100: //iADX
      Execute_iADX();   
   break;
   case 101: //iATR
      Execute_iATR();   
   break;
   case 102: //iAO
      Execute_iAO();
   break;
   case 103: //iBearsPower
      Execute_iBearsPower();   
   break;
   case 104: //iBands
      Execute_iBands();
   break;   
   case 105: //iBandsOnArray
      Execute_iBandsOnArray();
   break;
   case 106: //iBullsPower
      Execute_iBullsPower();   
   break;
   case 107: //iCCI
      Execute_iCCI();            
   break;
   case 108: //iCCIOnArray
      Execute_iCCIOnArray();
   break;   
   case 109: //iCustom
      //redesigned to request
   break;
   case 110: //iDeMarker
      Execute_iDeMarker();            
   break;
   case 111: //iEnvelopes
      Execute_iEnvelopes();
   break;
   case 112: //iEnvelopesOnArray
      Execute_iEnvelopesOnArray();
   break;
   case 113: //iForce
      Execute_iForce();              
   break;
   case 114: //iFractals
      Execute_iFractals();   
   break;
   case 115: //iGator
      Execute_iGator();   
   break;
   case 116: //iIchimoku
      Execute_iIchimoku();
   break;
   case 117: //iBWMFI
      Execute_iBWMFI();   
   break;
   case 118: //iMomentum
      Execute_iMomentum();
   break;   
   case 119: //iMomentumOnArray
      Execute_iMomentumOnArray();
   break;
   case 120: //iMFI
      Execute_iMFI();   
   break;
   case 121: //iMA
      Execute_iMA();   
   break;   
   case 122: //iMAOnArray
      Execute_iMAOnArray();
   break;
   case 123: //iOsMA
      Execute_iOsMA();   
   break;
   case 124: //iMACD
      Execute_iMACD();            
   break;
   case 125: //iOBV
      Execute_iOBV();   
   break;
   case 126: //iSAR
      Execute_iSAR();   
   break;
   case 127: //iRSI     
      Execute_iRSI();
   break;   
   case 128: //iRSIOnArray
      Execute_iRSIOnArray();
   break;
   case 129: //iRVI
      Execute_iRVI();   
   break;
   case 130: //iStdDev
      Execute_iStdDev();   
   break;   
   case 131: //iStdDevOnArray
      Execute_iStdDevOnArray();
   break;
   case 132: //iStochastic
      Execute_iStochastic();   
   break;
   case 133: //iWPR
      Execute_iWPR();   
   break;   
   case 134: //iBars
      Execute_iBars();
   break;
   case 135: //iBarShift
      Execute_iBarShift();
   break;
   case 136: //iClose
      Execute_iClose();
   break;
   case 137: //iHigh
      Execute_iHigh();
   break;
   case 138: //iHighest
      Execute_iHighest();
   break;
   case 139: //iLow
      Execute_iLow();
   break;
   case 140: //iLowest
      Execute_iLowest();
   break;
   case 141: //iOpen
      Execute_iOpen();
   break;
   case 142: //iTime
      Execute_iTime();
   break;
   case 143: //iVolume
      Execute_iVolume();
   break;
   case 144: //iCloseArray
      Execute_iCloseArray();
   break;
   case 145: //iHighArray
      Execute_iHighArray();
   break;
   case 146: //iLowArray
      Execute_iLowArray();
   break;
   case 147: //iOpenArray
      Execute_iOpenArray();
   break;
   case 148: //iVolumeArray
      Execute_iVolumeArray();
   break;
   case 149: //iTimeArray
      Execute_iTimeArray();
   break;   
   case 150: //RefreshRates
      Execute_RefreshRates(); 
   break;   
   case 153: //TerminalInfoString
      Execute_TerminalInfoString();
   break;   
   case 154: //SymbolInfoString
      Execute_SymbolInfoString();
   break;   
   case 156: //BacktestingReady
      Execute_BacktestingReady();
   break;   
   case 200: //SymbolsTotal
      Execute_SymbolsTotal();
   break;   
   case 201: //SymbolName
      Execute_SymbolName();
   break;    
   case 202: //SymbolSelect
      Execute_SymbolSelect();
   break;   
   case 203: //SymbolInfoInteger
      Execute_SymbolInfoInteger();
   break;   
   case 204: //TerminalInfoInteger
      Execute_TerminalInfoInteger();
   break;   
   case 205: //TerminalInfoDouble
      Execute_TerminalInfoDouble();
   break;   
   case 206: //ChartId
      Execute_CharId();
   break;   
   case 207: //ChartRedraw
      Execute_ChartRedraw();
   break;
   
   default:
      _error = "Unknown command type = " + command_type;
      Print("[ERROR] ExecuteCommand: ", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);      
      break;
   }     
   
   return (command_type);
}

void Execute_Request()
{
   string request;
   StringInit(request, 1000, 0);

   if (!getStringValue(ExpertHandle, 0, request, _error))
   {
      PrintParamError("Request", "request", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);      
      return;
   }
   
   Print("Execute_Request: ", request);
   
   string response = OnRequest(request);
   
   if (!sendStringResponse(ExpertHandle, response, _response_error))
   {
      PrintResponseError("Request", _response_error);
   }
}

void Execute_OrderCloseAll()
{
   if (!sendBooleanResponse(ExpertHandle, OrderCloseAll(), _response_error)) 
   {
      PrintResponseError("OrderCloseAll", _response_error);
   }
}

void Execute_OrderCloseBy()
{
   int ticket;
   int opposite;
   int color_value;

   if (!getIntValue(ExpertHandle, 0, ticket, _error)) 
   {
      PrintParamError("OrderCloseBy", "ticket", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);      
      return;
   }
                    
   if (!getIntValue(ExpertHandle, 1, opposite, _error))
   {
      PrintParamError("OrderCloseBy", "opposite", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);      
      return;
   }
   
   if (!getIntValue(ExpertHandle, 2, color_value, _error))
   {
      PrintParamError("OrderCloseBy", "color", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);      
      return;
   }
   
   bool res = OrderCloseBy(ticket, opposite, color_value);

   if (!sendBooleanResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("OrderCloseBy", _response_error);
   }
}

void Execute_OrderClosePrice()
{
   if (!sendDoubleResponse(ExpertHandle, OrderClosePrice(), _response_error)) 
   {
      PrintResponseError("OrderClosePrice", _response_error);
   }
}

void Execute_OrderClosePriceByTicket()
{
   int ticket;
         
   if (!getIntValue(ExpertHandle, 0, ticket, _error))
   {
      PrintParamError("OrderClosePriceByTicket", "ticket", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);      
      return;
   }   
   
   bool selected = OrderSelect(ticket, SELECT_BY_TICKET);
   if (!selected)
   {
      int last_error = GetLastError();
      PrintFormat("[ERROR] Command: %s, Failed to select order! ErrorCode = %d", "OrderClosePriceByTicket", last_error);
      sendErrorResponse(ExpertHandle, last_error, "Failed to select order", _response_error);
      return;
   }

   if (!sendDoubleResponse(ExpertHandle, OrderClosePrice(), _response_error)) 
   {
      PrintResponseError("OrderClosePriceByTicket", _response_error);
   }
}

void Execute_OrderCloseTime()
{
   if (!sendIntResponse(ExpertHandle, OrderCloseTime(), _response_error)) 
   {
      PrintResponseError("OrderCloseTime", _response_error);
   }
}

void Execute_OrderComment()
{
   if (!sendStringResponse(ExpertHandle, OrderComment(), _response_error)) 
   {
      PrintResponseError("OrderComment", _response_error);
   }
}

void Execute_OrderCommission()
{
   if (!sendDoubleResponse(ExpertHandle, OrderCommission(), _response_error)) 
   {
      PrintResponseError("OrderCommission", _response_error);
   }
}

void Execute_OrderDelete()
{
   int ticket;
   int arrow_color;

   if (!getIntValue(ExpertHandle, 0, ticket, _error)) 
   {
      PrintParamError("OrderDelete", "ticket", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);      
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, arrow_color, _error))
   {
      PrintParamError("OrderDelete", "arrow_color", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);      
      return;
   }
   
   if (!sendDoubleResponse(ExpertHandle, OrderDelete(ticket, arrow_color), _response_error)) 
   {
      PrintResponseError("OrderDelete", _response_error);
   }
}

void Execute_OrderExpiration()
{
   if (!sendIntResponse(ExpertHandle, OrderExpiration(), _response_error)) 
   {
      PrintResponseError("OrderExpiration", _response_error);
   }
}

void Execute_OrderLots()
{
   if (!sendDoubleResponse(ExpertHandle, OrderLots(), _response_error)) 
   {
      PrintResponseError("OrderLots", _response_error);
   }
}

void Execute_OrderMagicNumber()
{
   if (!sendIntResponse(ExpertHandle, OrderMagicNumber(), _response_error)) 
   {
      PrintResponseError("OrderMagicNumber", _response_error);
   }
}

void Execute_OrderModify()
{
   int ticket;
   double price;
   double stoploss;
   double takeprofit;
   int expiration;
   int arrow_color;

   if (!getIntValue(ExpertHandle, 0, ticket, _error))
   {
      PrintParamError("OrderModify", "ticket", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);      
      return;
   }
                     
   if (!getDoubleValue(ExpertHandle, 1, price, _error))
   {
      PrintParamError("OrderModify", "price", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);      
      return;
   }
   
   if (!getDoubleValue(ExpertHandle, 2, stoploss, _error))
   {
      PrintParamError("OrderModify", "stoploss", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);      
      return;
   }

   if (!getDoubleValue(ExpertHandle, 3, takeprofit, _error))
   {
      PrintParamError("OrderModify", "takeprofit", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);      
      return;
   }
           
   if (!getIntValue(ExpertHandle, 4, expiration, _error))
   {
      PrintParamError("OrderModify", "expiration", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);      
      return;
   }
   
   if (!getIntValue(ExpertHandle, 5, arrow_color, _error))
   {
      PrintParamError("OrderModify", "arrow_color", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);      
      return;
   }
   
   bool res = OrderModify(ticket, price, stoploss, takeprofit, expiration, arrow_color);
   
   if (!sendBooleanResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("OrderModify", _response_error);
   }
}

void Execute_OrderOpenPrice()
{
   if (!sendDoubleResponse(ExpertHandle, OrderOpenPrice(), _response_error)) 
   {
      PrintResponseError("OrderOpenPrice", _response_error);
   }
}

void Execute_OrderOpenPriceByTicket()
{
   int ticket;
         
   if (!getIntValue(ExpertHandle, 0, ticket, _error))
   {
      PrintParamError("OrderOpenPriceByTicket", "ticket", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);      
      return;
   }   
   
   bool selected = OrderSelect(ticket, SELECT_BY_TICKET);
   if (!selected)
   {
      int last_error = GetLastError();
      PrintFormat("[ERROR] Command: %s, Failed to select order! ErrorCode = %d", "OrderOpenPriceByTicket", last_error);
      sendErrorResponse(ExpertHandle, last_error, "Failed to select order", _response_error);
      return;
   }
                             
   if (!sendDoubleResponse(ExpertHandle, OrderOpenPrice(), _response_error)) 
   {
      PrintResponseError("OrderOpenPriceByTicket", _response_error);
   }
}

void Execute_OrderOpenTime()
{
   if (!sendIntResponse(ExpertHandle, OrderOpenTime(), _response_error)) 
   {
      PrintResponseError("OrderOpenTime", _response_error);
   }               
}

void Execute_OrderPrint()
{
   OrderPrint();

   if (!sendVoidResponse(ExpertHandle, _response_error))
   {
      PrintResponseError("OrderPrint", _response_error);
   }
}

void Execute_OrderProfit()
{
   if (!sendDoubleResponse(ExpertHandle, OrderProfit(), _response_error)) 
   {
      PrintResponseError("OrderProfit", _response_error);
   }
}

void Execute_OrderSelect()
{
   int index;
   int select;
   int pool;
   
   if (!getIntValue(ExpertHandle, 0, index, _error))
   {
      PrintParamError("OrderSelect", "index", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!getIntValue(ExpertHandle, 1, select, _error))
   {
      PrintParamError("OrderSelect", "select", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 2, pool, _error))
   {
      PrintParamError("OrderSelect", "pool", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!sendBooleanResponse(ExpertHandle, OrderSelect(index, select, pool), _response_error)) 
   {
      PrintResponseError("OrderSelect", _response_error);
   }
}

void Execute_OrdersHistoryTotal()
{
   if (!sendIntResponse(ExpertHandle, OrdersHistoryTotal(), _response_error)) 
   {
      PrintResponseError("OrdersHistoryTotal", _response_error);
   }
}

void Execute_OrderStopLoss()
{
   if (!sendDoubleResponse(ExpertHandle, OrderStopLoss(), _response_error)) 
   {
      PrintResponseError("OrderStopLoss", _response_error);
   }
}

void Execute_OrdersTotal()
{
   if (!sendIntResponse(ExpertHandle, OrdersTotal(), _response_error)) 
   {
      PrintResponseError("OrdersTotal", _response_error);
   }
}

void Execute_OrderSwap()
{
   if (!sendDoubleResponse(ExpertHandle, OrderSwap(), _response_error)) 
   {
      PrintResponseError("OrderSwap", _response_error);
   }
}

void Execute_OrderSymbol()
{
   if (!sendStringResponse(ExpertHandle, OrderSymbol(), _response_error)) 
   {
      PrintResponseError("OrderSymbol", _response_error);
   }
}

void Execute_OrderTakeProfit()
{
   if (!sendDoubleResponse(ExpertHandle, OrderTakeProfit(), _response_error)) 
   {
      PrintResponseError("OrderTakeProfit", _response_error);
   }
}

void Execute_OrderTicket()
{
   if (!sendIntResponse(ExpertHandle, OrderTicket(), _response_error)) 
   {
      PrintResponseError("OrderTicket", _response_error);
   }
}

void Execute_OrderType()
{
   if (!sendIntResponse(ExpertHandle, OrderType(), _response_error)) 
   {
      PrintResponseError("OrderType", _response_error);
   }
}

void Execute_GetLastError()
{
   if (!sendIntResponse(ExpertHandle, GetLastError(), _response_error)) 
   {
      PrintResponseError("GetLastError", _response_error);
   }
}

void Execute_IsConnected()
{
   if (!sendBooleanResponse(ExpertHandle, IsConnected(), _response_error)) 
   {
      PrintResponseError("IsConnected", _response_error);
   }
}

void Execute_IsDemo()
{
   if (!sendBooleanResponse(ExpertHandle, IsDemo(), _response_error)) 
   {
      PrintResponseError("IsDemo", _response_error);
   }
}

void Execute_IsDllsAllowed()
{
   if (!sendBooleanResponse(ExpertHandle, IsDllsAllowed(), _response_error)) 
   {
      PrintResponseError("IsDllsAllowed", _response_error);
   }
}

void Execute_IsExpertEnabled()
{
   if (!sendBooleanResponse(ExpertHandle, IsExpertEnabled(), _response_error)) 
   {
      PrintResponseError("IsExpertEnabled", _response_error);
   }
}

void Execute_IsLibrariesAllowed()
{
   if (!sendBooleanResponse(ExpertHandle, IsLibrariesAllowed(), _response_error)) 
   {
      PrintResponseError("IsLibrariesAllowed", _response_error);
   }
}

void Execute_IsOptimization()
{
   if (!sendBooleanResponse(ExpertHandle, IsOptimization(), _response_error)) 
   {
      PrintResponseError("IsOptimization", _response_error);
   }
}

void Execute_IsStopped()
{
   if (!sendBooleanResponse(ExpertHandle, IsStopped(), _response_error)) 
   {
      PrintResponseError("IsStopped", _response_error);
   }
}

void Execute_IsTesting()
{
   if (!sendBooleanResponse(ExpertHandle, IsTesting(), _response_error)) 
   {
      PrintResponseError("IsTesting", _response_error);
   }
}

void Execute_IsTradeAllowed()
{
   if (!sendBooleanResponse(ExpertHandle, IsTradeAllowed(), _response_error)) 
   {
      PrintResponseError("IsTradeAllowed", _response_error);
   }
}

void Execute_IsTradeContextBusy()
{
   if (!sendBooleanResponse(ExpertHandle, IsTradeContextBusy(), _response_error)) 
   {
      PrintResponseError("IsTradeContextBusy", _response_error);
   }
}

void Execute_IsVisualMode()
{
   if (!sendBooleanResponse(ExpertHandle, IsVisualMode(), _response_error)) 
   {
      PrintResponseError("IsVisualMode", _response_error);
   }
}

void Execute_UninitializeReason()
{
   if (!sendIntResponse(ExpertHandle, UninitializeReason(), _response_error)) 
   {
      PrintResponseError("UninitializeReason", _response_error);
   }
}

void Execute_ErrorDescription()
{
   int error_code;

   if (!getIntValue(ExpertHandle, 0, error_code, _error)) 
   {
      PrintParamError("ErrorDescription", "errorCode", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!sendStringResponse(ExpertHandle, ErrorDescription(error_code), _response_error)) 
   {
      PrintResponseError("ErrorDescription", _response_error);
   }
}

void Execute_AccountBalance()
{
   if (!sendDoubleResponse(ExpertHandle, AccountBalance(), _response_error)) 
   {
      PrintResponseError("AccountBalance", _response_error);
   }
}

void Execute_AccountCredit()
{
   if (!sendDoubleResponse(ExpertHandle, AccountCredit(), _response_error)) 
   {
      PrintResponseError("AccountCredit", _response_error);
   }
}

void Execute_AccountCompany()
{
   if (!sendStringResponse(ExpertHandle, AccountCompany(), _response_error)) 
   {
      PrintResponseError("AccountCompany", _response_error);
   }
}

void Execute_AccountCurrency()
{
   if (!sendStringResponse(ExpertHandle, AccountCurrency(), _response_error)) 
   {
      PrintResponseError("AccountCurrency", _response_error);
   }
}

void Execute_AccountEquity()
{
   if (!sendDoubleResponse(ExpertHandle, AccountEquity(), _response_error)) 
   {
      PrintResponseError("AccountEquity", _response_error);
   }
}

void Execute_AccountFreeMargin()
{
   if (!sendDoubleResponse(ExpertHandle, AccountFreeMargin(), _response_error)) 
   {
      PrintResponseError("AccountFreeMargin", _response_error);
   }
}

void Execute_AccountFreeMarginCheck()
{
   string symbol;
   int cmd;
   double volume;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("AccountFreeMarginCheck", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, cmd, _error)) 
   {
      PrintParamError("AccountFreeMarginCheck", "cmd", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getDoubleValue(ExpertHandle, 2, volume, _error)) 
   {
      PrintParamError("AccountFreeMarginCheck", "volume", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double res = AccountFreeMarginCheck(symbol, cmd, volume);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("AccountFreeMarginCheck", _response_error);
   }
}

void Execute_AccountFreeMarginMode()
{
   if (!sendDoubleResponse(ExpertHandle, AccountFreeMarginMode(), _response_error)) 
   {
      PrintResponseError("AccountFreeMarginMode", _response_error);
   }
}

void Execute_AccountLeverage()
{
   if (!sendIntResponse(ExpertHandle, AccountLeverage(), _response_error)) 
   {
      PrintResponseError("AccountLeverage", _response_error);
   }
}

void Execute_AccountMargin()
{
   if (!sendDoubleResponse(ExpertHandle, AccountMargin(), _response_error)) 
   {
      PrintResponseError("AccountMargin", _response_error);
   }
}

void Execute_AccountName()
{
   if (!sendStringResponse(ExpertHandle, AccountName(), _response_error)) 
   {
      PrintResponseError("AccountName", _response_error);
   }
}

void Execute_AccountNumber()
{
   if (!sendIntResponse(ExpertHandle, AccountNumber(), _response_error)) 
   {
      PrintResponseError("AccountNumber", _response_error);
   }
}

void Execute_AccountProfit()
{
   if (!sendDoubleResponse(ExpertHandle, AccountProfit(), _response_error)) 
   {
      PrintResponseError("AccountProfit", _response_error);
   }
}

void Execute_AccountServer()
{
   if (!sendStringResponse(ExpertHandle, AccountServer(), _response_error)) 
   {
      PrintResponseError("AccountServer", _response_error);
   }
}

void Execute_AccountStopoutLevel()
{
   if (!sendIntResponse(ExpertHandle, AccountStopoutLevel(), _response_error)) 
   {
      PrintResponseError("AccountStopoutLevel", _response_error);
   }
}

void Execute_AccountStopoutMode()
{
   if (!sendIntResponse(ExpertHandle, AccountStopoutMode(), _response_error)) 
   {
      PrintResponseError("AccountStopoutMode", _response_error);
   }
}

void Execute_Alert()
{
   string msg;
   StringInit(msg, 1000, 0);
   
   if (!getStringValue(ExpertHandle, 0, msg, _error)) 
   {
      PrintParamError("Alert", "msg", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   Alert(msg);
   
   if (!sendVoidResponse(ExpertHandle, _response_error))
   {
      PrintResponseError("Alert", _response_error);
   }
}

void Execute_Comment()
{
   string msg;
   StringInit(msg, 1000, 0);
   
   if (!getStringValue(ExpertHandle, 0, msg, _error)) 
   {
      PrintParamError("Comment", "msg", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   Comment(msg);
   
   if (!sendVoidResponse(ExpertHandle, _response_error))
   {
      PrintResponseError("Comment", _response_error);
   }
}

void Execute_GetTickCount()
{
   if (!sendIntResponse(ExpertHandle, GetTickCount(), _response_error)) 
   {
      PrintResponseError("GetTickCount", _response_error);
   }
}

void Execute_MarketInfo()
{
   string symbol;
   int type;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("MarketInfo", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, type, _error)) 
   {
      PrintParamError("MarketInfo", "type", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!sendDoubleResponse(ExpertHandle, MarketInfo(symbol, type), _response_error)) 
   {
      PrintResponseError("MarketInfo", _response_error);
   }
}

void Execute_MessageBox(bool use_ext_params)
{
   string text;
   string caption = NULL;
   int flag = 0;
   StringInit(text, 2000, 0);

   if (!getStringValue(ExpertHandle, 0, text, _error)) 
   {
      PrintParamError("MessageBox", "text", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (use_ext_params)
   {
      StringInit(caption, 1000, 0);
      if (!getStringValue(ExpertHandle, 1, caption, _error)) 
      {
         PrintParamError("MessageBox", "caption", _error);
         sendErrorResponse(ExpertHandle, -1, _error, _response_error);
         return;
      }
      
      if (!getIntValue(ExpertHandle, 2, flag, _error)) 
      {
         PrintParamError("MessageBox", "flag", _error);
         sendErrorResponse(ExpertHandle, -1, _error, _response_error);
         return;
      }
   }
   
   if (!sendIntResponse(ExpertHandle, MessageBox(text, caption, flag), _response_error)) 
   {
      PrintResponseError("MessageBox", _response_error);
   }
}

void Execute_PlaySound()
{
   string filename;
   StringInit(filename, 1000, 0);

   if (!getStringValue(ExpertHandle, 0, filename, _error)) 
   {
      PrintParamError("PlaySound", "filename", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!sendBooleanResponse(ExpertHandle, PlaySound(filename), _response_error))
   {
      PrintResponseError("PlaySound", _response_error);
   }
}

void Execute_Print()
{
   string msg;
   StringInit(msg, 1000, 0);
   
   if (!getStringValue(ExpertHandle, 0, msg, _error)) 
   {
      PrintParamError("Print", "msg", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   Print(msg);
   
   if (!sendVoidResponse(ExpertHandle, _response_error))
   {
      PrintResponseError("Print", _response_error);
   }
}

void Execute_SendFTP(bool use_path)
{
   string filename;
   string ftp_path = NULL;
   StringInit(filename, 250, 0);
   
   if (!getStringValue(ExpertHandle, 0, filename, _error)) 
   {
      PrintParamError("SendFTP", "filename", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (use_path)
   {
      StringInit(ftp_path, 500, 0);
      if (!getStringValue(ExpertHandle, 1, ftp_path, _error)) 
      {
         PrintParamError("SendFTP", "ftp_path", _error);
         sendErrorResponse(ExpertHandle, -1, _error, _response_error);
         return;
      }
   }
   
   if (!sendBooleanResponse(ExpertHandle, SendFTP(filename, ftp_path), _response_error)) 
   {
      PrintResponseError("SendFTP", _response_error);
   }
}

void Execute_SendMail()
{
   string subject;
   string some_text;
   StringInit(subject, 1000, 0);
   StringInit(some_text, 10000, 0);

   if (!getStringValue(ExpertHandle, 0, subject, _error)) 
   {
      PrintParamError("SendMail", "subject", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getStringValue(ExpertHandle, 1, some_text, _error)) 
   {
      PrintParamError("SendMail", "some_text", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!sendBooleanResponse(ExpertHandle, SendMail(subject, some_text), _response_error))
   {
      PrintResponseError("SendMail", _response_error);
   }
}

void Execute_Sleep()
{
   int milliseconds;
   
   if (!getIntValue(ExpertHandle, 0, milliseconds, _error)) 
   {
      PrintParamError("Sleep", "milliseconds", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   Sleep(milliseconds);
   
   if (!sendVoidResponse(ExpertHandle, _response_error))
   {
      PrintResponseError("Sleep", _response_error);
   }
}

void Execute_TerminalCompany()
{
   if (!sendStringResponse(ExpertHandle, TerminalCompany(), _response_error)) 
   {
      PrintResponseError("TerminalCompany", _response_error);
   }
}

void Execute_TerminalName()
{
   if (!sendStringResponse(ExpertHandle, TerminalName(), _response_error)) 
   {
      PrintResponseError("TerminalName", _response_error);
   }
}

void Execute_TerminalPath()
{
   if (!sendStringResponse(ExpertHandle, TerminalPath(), _response_error)) 
   {
      PrintResponseError("TerminalPath", _response_error);
   }
}

void Execute_Day()
{
   if (!sendIntResponse(ExpertHandle, Day(), _response_error)) 
   {
      PrintResponseError("Day", _response_error);
   }
}

void Execute_DayOfWeek()
{
   if (!sendIntResponse(ExpertHandle, DayOfWeek(), _response_error)) 
   {
      PrintResponseError("DayOfWeek", _response_error);
   }
}

void Execute_DayOfYear()
{
   if (!sendIntResponse(ExpertHandle, DayOfYear(), _response_error)) 
   {
      PrintResponseError("DayOfYear", _response_error);
   }
}

void Execute_Hour()
{
   if (!sendIntResponse(ExpertHandle, Hour(), _response_error)) 
   {
      PrintResponseError("Hour", _response_error);
   }
}

void Execute_Minute()
{
   if (!sendIntResponse(ExpertHandle, Minute(), _response_error)) 
   {
      PrintResponseError("Minute", _response_error);
   }
}

void Execute_Month()
{
   if (!sendIntResponse(ExpertHandle, Month(), _response_error)) 
   {
      PrintResponseError("Month", _response_error);
   }
}

void Execute_Seconds()
{
   if (!sendIntResponse(ExpertHandle, Seconds(), _response_error)) 
   {
      PrintResponseError("Seconds", _response_error);
   }
}

void Execute_TimeCurrent()
{
   if (!sendIntResponse(ExpertHandle, TimeCurrent(), _response_error)) 
   {
      PrintResponseError("TimeCurrent", _response_error);
   }
}

void Execute_TimeDay()
{
   int date;

   if (!getIntValue(ExpertHandle, 0, date, _error)) 
   {
      PrintParamError("TimeDay", "date", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!sendIntResponse(ExpertHandle, TimeDay(date), _response_error)) 
   {
      PrintResponseError("TimeDay", _response_error);
   }
}

void Execute_TimeDayOfWeek()
{
   int date;
   
   if (!getIntValue(ExpertHandle, 0, date, _error)) 
   {
      PrintParamError("TimeDayOfWeek", "date", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!sendIntResponse(ExpertHandle, TimeDayOfWeek(date), _response_error)) 
   {
      PrintResponseError("TimeDayOfWeek", _response_error);
   }
}

void Execute_TimeDayOfYear()
{
   int date;
   
   if (!getIntValue(ExpertHandle, 0, date, _error)) 
   {
      PrintParamError("TimeDayOfYear", "date", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!sendIntResponse(ExpertHandle, TimeDayOfYear(date), _response_error)) 
   {
      PrintResponseError("TimeDayOfYear", _response_error);
   }
}

void Execute_TimeHour()
{
   int time;

   if (!getIntValue(ExpertHandle, 0, time, _error)) 
   {
      PrintParamError("TimeHour", "time", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!sendIntResponse(ExpertHandle, TimeHour(time), _response_error)) 
   {
      PrintResponseError("TimeHour", _response_error);
   }
}

void Execute_TimeLocal()
{
   if (!sendIntResponse(ExpertHandle, TimeLocal(), _response_error)) 
   {
      PrintResponseError("TimeLocal", _response_error);
   }
}

void Execute_TimeMinute()
{
   int time;

   if (!getIntValue(ExpertHandle, 0, time, _error)) 
   {
      PrintParamError("TimeMinute", "time", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!sendIntResponse(ExpertHandle, TimeMinute(time), _response_error)) 
   {
      PrintResponseError("TimeMinute", _response_error);
   }
}

void Execute_TimeMonth()
{
   int time;
   
   if (!getIntValue(ExpertHandle, 0, time, _error)) 
   {
      PrintParamError("TimeMonth", "time", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!sendIntResponse(ExpertHandle, TimeMonth(time), _response_error)) 
   {
      PrintResponseError("TimeMonth", _response_error);
   }
}

void Execute_TimeSeconds()
{
   int time;

   if (!getIntValue(ExpertHandle, 0, time, _error)) 
   {
      PrintParamError("TimeSeconds", "time", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!sendIntResponse(ExpertHandle, TimeSeconds(time), _response_error)) 
   {
      PrintResponseError("TimeSeconds", _response_error);
   }
}

void Execute_TimeYear()
{
   int time;
   
   if (!getIntValue(ExpertHandle, 0, time, _error)) 
   {
      PrintParamError("TimeYear", "time", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }

   if (!sendIntResponse(ExpertHandle, TimeYear(time), _response_error)) 
   {
      PrintResponseError("TimeYear", _response_error);
   }
}

void Execute_Year()
{
   if (!sendIntResponse(ExpertHandle, Year(), _response_error)) 
   {
      PrintResponseError("Year", _response_error);
   }
}

void Execute_GlobalVariableCheck()
{
   string name;
   StringInit(name, 250, 0);
   
   if (!getStringValue(ExpertHandle, 0, name, _error)) 
   {
      PrintParamError("GlobalVariableCheck", "name", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!sendBooleanResponse(ExpertHandle, GlobalVariableCheck(name), _response_error)) 
   {
      PrintResponseError("GlobalVariableCheck", _response_error);
   }
}

void Execute_GlobalVariableDel()
{
   string name;
   StringInit(name, 250, 0);
   
   if (!getStringValue(ExpertHandle, 0, name, _error)) 
   {
      PrintParamError("GlobalVariableDel", "name", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!sendBooleanResponse(ExpertHandle, GlobalVariableDel(name), _response_error)) 
   {
      PrintResponseError("GlobalVariableDel", _response_error);
   }
}

void Execute_GlobalVariableGet()
{
   string name;
   StringInit(name, 250, 0);
   
   if (!getStringValue(ExpertHandle, 0, name, _error)) 
   {
      PrintParamError("GlobalVariableGet", "name", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!sendDoubleResponse(ExpertHandle, GlobalVariableGet(name), _response_error)) 
   {
      PrintResponseError("GlobalVariableGet", _response_error);
   }
}

void Execute_GlobalVariableName()
{
   int index;   

   if (!getIntValue(ExpertHandle, 0, index, _error)) 
   {
      PrintParamError("GlobalVariableName", "index", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!sendStringResponse(ExpertHandle, GlobalVariableName(index), _response_error)) 
   {
      PrintResponseError("GlobalVariableName", _response_error);
   }
}

void Execute_GlobalVariableSet()
{
   string name;
   double value;
   StringInit(name, 250, 0);

   if (!getStringValue(ExpertHandle, 0, name, _error)) 
   {
      PrintParamError("GlobalVariableSet", "name", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getDoubleValue(ExpertHandle, 1, value, _error)) 
   {
      PrintParamError("GlobalVariableSet", "value", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   int res = GlobalVariableSet(name, value);
   
   if (!sendIntResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("GlobalVariableSet", _response_error);
   }
}

void Execute_GlobalVariableSetOnCondition()
{
   string name;
   double value;
   double check_value;
   StringInit(name, 250, 0);

   if (!getStringValue(ExpertHandle, 0, name, _error)) 
   {
      PrintParamError("GlobalVariableSetOnCondition", "name", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getDoubleValue(ExpertHandle, 1, value, _error)) 
   {
      PrintParamError("GlobalVariableSetOnCondition", "value", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getDoubleValue(ExpertHandle, 2, check_value, _error)) 
   {
      PrintParamError("GlobalVariableSetOnCondition", "check_value", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   bool res = GlobalVariableSetOnCondition(name, value, check_value);
   
   if (!sendBooleanResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("GlobalVariableSetOnCondition", _response_error);
   }
}

void Execute_GlobalVariablesDeleteAll()
{
   string prefix_name;
   StringInit(prefix_name, 250, 0);

   if (!getStringValue(ExpertHandle, 0, prefix_name, _error)) 
   {
      PrintParamError("GlobalVariablesDeleteAll", "prefix_name", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!sendIntResponse(ExpertHandle, GlobalVariablesDeleteAll(prefix_name), _response_error)) 
   {
      PrintResponseError("GlobalVariablesDeleteAll", _response_error);
   }
}

void Execute_GlobalVariablesTotal()
{
   if (!sendIntResponse(ExpertHandle, GlobalVariablesTotal(), _response_error)) 
   {
      PrintResponseError("GlobalVariablesTotal", _response_error);
   }
}

void Execute_iAC()
{
   string symbol;
   int timeframe;
   int shift;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iAC", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iAC", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 2, shift, _error)) 
   {
      PrintParamError("iAC", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double res = iAC(symbol, timeframe, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iAC", _response_error);
   }
}

void Execute_iAD()
{
   string symbol;
   int timeframe;
   int shift;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iAD", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iAD", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 2, shift, _error)) 
   {
      PrintParamError("iAD", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double res = iAD(symbol, timeframe, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iAD", _response_error);
   }
}

void Execute_iAlligator()
{
   string symbol;
   int timeframe;
   int shift;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iAD", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iAD", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 2, shift, _error)) 
   {
      PrintParamError("iAD", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double res =  iAD(symbol, timeframe, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iAD", _response_error);
   } 
}

void Execute_iADX()
{
   string symbol;
   int timeframe;
   int period;
   int applied_price;
   int mode;
   int shift;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iADX", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iADX", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 2, period, _error)) 
   {
      PrintParamError("iADX", "period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 3, applied_price, _error)) 
   {
      PrintParamError("iADX", "applied_price", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }         

   if (!getIntValue(ExpertHandle, 4, mode, _error)) 
   {
      PrintParamError("iADX", "mode", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 5, shift, _error)) 
   {
      PrintParamError("iADX", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double res = iADX(symbol, timeframe, period, applied_price, mode, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iADX", _response_error);
   } 
}

void Execute_iATR()
{
   string symbol;
   int timeframe;
   int period;
   int shift;
   StringInit(symbol, 100, 0);
   
   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iATR", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iATR", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 2, period, _error)) 
   {
      PrintParamError("iATR", "period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 3, shift, _error)) 
   {
      PrintParamError("iATR", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double res = iATR(symbol, timeframe, period, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iATR", _response_error);
   } 
}

void Execute_iAO()
{
   string symbol;
   int timeframe;
   int shift;
   StringInit(symbol, 100, 0);
   
   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iAO", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iAO", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 2, shift, _error)) 
   {
      PrintParamError("iAO", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double res = iAO(symbol, timeframe, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iAO", _response_error);
   }      
}

void Execute_iBearsPower()
{
   string symbol;
   int timeframe;
   int period;
   int applied_price;
   int shift;
   StringInit(symbol, 100, 0);
   
   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iBearsPower", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iBearsPower", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!getIntValue(ExpertHandle, 2, period, _error)) 
   {
      PrintParamError("iBearsPower", "period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 3, applied_price, _error)) 
   {
      PrintParamError("iBearsPower", "applied_price", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }         
   
   if (!getIntValue(ExpertHandle, 4, shift, _error)) 
   {
      PrintParamError("iBearsPower", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double res = iBearsPower(symbol, timeframe, period, applied_price, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iBearsPower", _response_error);
   }
}

void Execute_iBands()
{
   string symbol;
   int timeframe;
   int period;
   int deviation;
   int bands_shift;
   int applied_price;
   int mode;
   int shift;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iBands", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iBands", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!getIntValue(ExpertHandle, 2, period, _error)) 
   {
      PrintParamError("iBands", "period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!getIntValue(ExpertHandle, 3, deviation, _error)) 
   {
      PrintParamError("iBands", "deviation", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 4, bands_shift, _error)) 
   {
      PrintParamError("iBands", "bands_shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 5, applied_price, _error)) 
   {
      PrintParamError("iBands", "applied_price", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!getIntValue(ExpertHandle, 6, mode, _error)) 
   {
      PrintParamError("iBands", "mode", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 7, shift, _error)) 
   {
      PrintParamError("iBands", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double res = iBands(symbol, timeframe, period, deviation, bands_shift, applied_price, mode, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iBands", _response_error);
   }
}

void Execute_iBandsOnArray()
{
   int array_size = 0;
   double doubleArray[];
   int total;
   int period;
   int deviation;
   int bands_shift;
   int mode;
   int shift;
 
   int param_index = 0;  
   if (!getIntValue(ExpertHandle, param_index, array_size, _error))
   {
      PrintParamError("iBandsOnArray", "array_size", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   ArrayResize(doubleArray, array_size);
   
   for(int i = 0; i < array_size; i++)
   {
      double tempDouble;
      param_index++;
      if (!getDoubleValue(ExpertHandle, param_index, tempDouble, _error))
      {
         PrintParamError("iBandsOnArray", "array", _error);
         sendErrorResponse(ExpertHandle, -1, _error, _response_error);
         return;
      }
      doubleArray[i] = tempDouble;         
   }                  
   
   param_index++;
   if (getIntValue(ExpertHandle, param_index, total, _error))
   {
      PrintParamError("iBandsOnArray", "total", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   param_index++;
   if (!getIntValue(ExpertHandle, param_index, period, _error))
   {
      PrintParamError("iBandsOnArray", "period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
      
   param_index++;
   if (!getIntValue(ExpertHandle, param_index, deviation, _error))
   {
      PrintParamError("iBandsOnArray", "deviation", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
      
   param_index++;
   if (!getIntValue(ExpertHandle, param_index, bands_shift, _error))
   {
      PrintParamError("iBandsOnArray", "bands_shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
      
   param_index++;
   if (!getIntValue(ExpertHandle, param_index, mode, _error))
   {
      PrintParamError("iBandsOnArray", "mode", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
      
   param_index++;
   if (!getIntValue(ExpertHandle, param_index, shift, _error))
   {
      PrintParamError("iBandsOnArray", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }   
   
   double res = iBandsOnArray(doubleArray, total, period, deviation, bands_shift, mode, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iBandsOnArray", _response_error);
   }
}

void Execute_iBullsPower()
{
   string symbol;
   int timeframe;
   int period;
   int applied_price;
   int shift;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iBullsPower", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iBullsPower", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }

   if (!getIntValue(ExpertHandle, 2, period, _error)) 
   {
      PrintParamError("iBullsPower", "period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   if (!getIntValue(ExpertHandle, 3, applied_price, _error)) 
   {
      PrintParamError("iBullsPower", "applied_price", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }         
   
   if (!getIntValue(ExpertHandle, 4, shift, _error)) 
   {
      PrintParamError("iBullsPower", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double res = iBullsPower(symbol, timeframe, period, applied_price, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iBullsPower", _response_error);
   }
}

void Execute_iCCI()
{
   string symbol;
   int timeframe;
   int period;
   int applied_price;
   int shift;
   StringInit(symbol, 100, 0);
   
   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iCCI", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iCCI", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }

   if (!getIntValue(ExpertHandle, 2, period, _error)) 
   {
      PrintParamError("iCCI", "period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   if (!getIntValue(ExpertHandle, 3, applied_price, _error)) 
   {
      PrintParamError("iCCI", "applied_price", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 4, shift, _error)) 
   {
      PrintParamError("iCCI", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double res = iCCI(symbol, timeframe, period, applied_price, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iCCI", _response_error);
   }
}

void Execute_iCCIOnArray()
{
   int array_size = 0;
   double doubleArray[];
   int total;
   int period;
   int shift;
 
   int param_index = 0;  
   if (!getIntValue(ExpertHandle, param_index, array_size, _error))
   {
      PrintParamError("iCCIOnArray", "array_size", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);      
      return;
   }

   ArrayResize(doubleArray, array_size);
   
   for(int i = 0; i < array_size; i++)
   {
      double tempDouble;
      param_index++;
      getDoubleValue(ExpertHandle, param_index, tempDouble, _error);
      {
         PrintParamError("iCCIOnArray", "array", _error);
         sendErrorResponse(ExpertHandle, -1, _error, _response_error);      
         return;
      }

      doubleArray[i] = tempDouble;         
   }                  

   param_index++;   
   if (!getIntValue(ExpertHandle, param_index, total, _error))
   {
      PrintParamError("iCCIOnArray", "total", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);      
      return;
   }
   
   
   param_index++;
   if (!getIntValue(ExpertHandle, param_index, period, _error))
   {
      PrintParamError("iCCIOnArray", "period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);      
      return;
   }
   
   param_index++;
   if (!getIntValue(ExpertHandle, param_index, shift, _error))
   {
      PrintParamError("iCCIOnArray", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);      
      return;
   }
   
   double res = iCCIOnArray(doubleArray, total, period, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iCCIOnArray", _response_error);
   } 
}

void Execute_iDeMarker()
{
   string symbol;
   int timeframe;
   int period;
   int shift;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iDeMarker", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iDeMarker", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!getIntValue(ExpertHandle, 2, period, _error)) 
   {
      PrintParamError("iDeMarker", "period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
           
   if (!getIntValue(ExpertHandle, 3, shift, _error)) 
   {
      PrintParamError("iDeMarker", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double res = iDeMarker(symbol, timeframe, period, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iDeMarker", _response_error);
   }
}

void Execute_iEnvelopes()
{
   string symbol;
   int timeframe;
   int ma_period;
   int ma_method;
   int ma_shift;
   int applied_price;
   double deviation;
   int mode;
   int shift;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iEnvelopes", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iEnvelopes", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!getIntValue(ExpertHandle, 2, ma_period, _error)) 
   {
      PrintParamError("iEnvelopes", "ma_period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 3, ma_method, _error)) 
   {
      PrintParamError("iEnvelopes", "ma_method", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }         

   if (!getIntValue(ExpertHandle, 4, ma_shift, _error)) 
   {
      PrintParamError("iEnvelopes", "ma_shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }         

   if (!getIntValue(ExpertHandle, 5, applied_price, _error)) 
   {
      PrintParamError("iEnvelopes", "applied_price", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }         

   if (!getDoubleValue(ExpertHandle, 6, deviation, _error)) 
   {
      PrintParamError("iEnvelopes", "deviation", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }         

   if (!getIntValue(ExpertHandle, 7, mode, _error)) 
   {
      PrintParamError("iEnvelopes", "mode", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }         
           
   if (!getIntValue(ExpertHandle, 8, shift, _error)) 
   {
      PrintParamError("iEnvelopes", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double res = iEnvelopes(symbol, timeframe, ma_period, ma_method, ma_shift, applied_price, deviation, mode, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iEnvelopes", _response_error);
   }
}

void Execute_iEnvelopesOnArray()
{
   int array_size = 0;
   double doubleArray[];
   int total;
   int ma_period;
   int ma_method;
   int ma_shift;
   double deviation;
   int mode;
   int shift;
 
   int param_index = 0;  
   if (!getIntValue(ExpertHandle, param_index, array_size, _error))
   {
      PrintParamError("iEnvelopesOnArray", "array_size", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
    
   ArrayResize(doubleArray, array_size);
   
   for(int i = 0; i < array_size; i++)
   {
      double tempDouble;
      param_index++;
      if (!getDoubleValue(ExpertHandle, param_index, tempDouble, _error))
      {
         PrintParamError("iEnvelopesOnArray", "array", _error);
         sendErrorResponse(ExpertHandle, -1, _error, _response_error);
         return;
      }
      
      doubleArray[i] = tempDouble;         
   }                  
   
   param_index++;
   if (!getIntValue(ExpertHandle, param_index, total, _error))
   {
      PrintParamError("iEnvelopesOnArray", "total", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   param_index++;
   if (!getIntValue(ExpertHandle, param_index, ma_period, _error))
   {
      PrintParamError("iEnvelopesOnArray", "ma_period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   param_index++;
   if (!getIntValue(ExpertHandle, param_index, ma_method, _error))
   {
      PrintParamError("iEnvelopesOnArray", "ma_method", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   param_index++;
   if (!getIntValue(ExpertHandle, param_index, ma_shift, _error))
   {
      PrintParamError("iEnvelopesOnArray", "ma_shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   param_index++;    
   if (!getDoubleValue(ExpertHandle, param_index, deviation, _error))
   {
      PrintParamError("iEnvelopesOnArray", "deviation", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   param_index++;    
   if (!getIntValue(ExpertHandle, param_index, mode, _error))
   {
      PrintParamError("iEnvelopesOnArray", "mode", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }   
   
   param_index++;    
   if (!getIntValue(ExpertHandle, param_index, shift, _error))
   {
      PrintParamError("iEnvelopesOnArray", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }    

   double res = iEnvelopesOnArray(doubleArray, total, ma_period, ma_method, ma_shift, deviation, mode, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iEnvelopesOnArray", _response_error);
   }
}

void Execute_iForce()
{
   string symbol;
   int timeframe;
   int period;
   int ma_method;
   int applied_price;
   int shift;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iForce", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iForce", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!getIntValue(ExpertHandle, 2, period, _error)) 
   {
      PrintParamError("iForce", "period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 3, ma_method, _error)) 
   {
      PrintParamError("iForce", "ma_method", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }         

   if (!getIntValue(ExpertHandle, 4, applied_price, _error)) 
   {
      PrintParamError("iForce", "applied_price", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }         

   if (!getIntValue(ExpertHandle, 5, shift, _error)) 
   {
      PrintParamError("iForce", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double res = iForce(symbol, timeframe, period, ma_method, applied_price, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iForce", _response_error);
   }
}

void Execute_iFractals()
{
   string symbol;
   int timeframe;
   int mode;
   int shift;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iFractals", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iFractals", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!getIntValue(ExpertHandle, 2, mode, _error)) 
   {
      PrintParamError("iFractals", "mode", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }

   if (!getIntValue(ExpertHandle, 3, shift, _error)) 
   {
      PrintParamError("iFractals", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   double res = iFractals(symbol, timeframe, mode, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iFractals", _response_error);
   }
}

void Execute_iGator()
{
   string symbol;
   int timeframe;
   int jaw_period;
   int jaw_shift;
   int teeth_period;
   int teeth_shift;
   int lips_period;
   int lips_shift;
   int ma_method;
   int applied_price;
   int mode;
   int shift;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iGator", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iGator", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   if (!getIntValue(ExpertHandle, 2,  jaw_period, _error)) 
   {
      PrintParamError("iGator", "jaw_period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 3, jaw_shift, _error)) 
   {
      PrintParamError("iGator", "jaw_shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 4, teeth_period, _error)) 
   {
      PrintParamError("iGator", "teeth_period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 5, teeth_shift, _error)) 
   {
      PrintParamError("iGator", "teeth_shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 6, lips_period, _error)) 
   {
      PrintParamError("iGator", "lips_period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 7, lips_shift, _error)) 
   {
      PrintParamError("iGator", "lips_shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 8, ma_method, _error)) 
   {
      PrintParamError("iGator", "ma_method", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
            
   if (!getIntValue(ExpertHandle, 9, applied_price, _error)) 
   {
      PrintParamError("iGator", "applied_price", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 10, mode, _error)) 
   {
      PrintParamError("iGator", "mode", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 11, shift, _error)) 
   {
      PrintParamError("iGator", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double res = iGator(symbol, timeframe, jaw_period, jaw_shift, teeth_period, teeth_shift, lips_period, lips_shift, ma_method, applied_price, mode, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iGator", _response_error);
   }
}

void Execute_iIchimoku()
{
   string symbol;
   int timeframe;
   int tenkan_sen;
   int kijun_sen;
   int senkou_span_b;
   int mode;
   int shift;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iIchimoku", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iIchimoku", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 2,  tenkan_sen, _error)) 
   {
      PrintParamError("iIchimoku", "tenkan_sen", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!getIntValue(ExpertHandle, 3, kijun_sen, _error)) 
   {
      PrintParamError("iIchimoku", "kijun_sen", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!getIntValue(ExpertHandle, 4, senkou_span_b, _error)) 
   {
      PrintParamError("iIchimoku", "senkou_span_b", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!getIntValue(ExpertHandle, 5, mode, _error)) 
   {
      PrintParamError("iIchimoku", "mode", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!getIntValue(ExpertHandle, 6, shift, _error)) 
   {
      PrintParamError("iIchimoku", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double res = iIchimoku(symbol, timeframe, tenkan_sen, kijun_sen, senkou_span_b, mode, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iIchimoku", _response_error);
   }
}

void Execute_iBWMFI()
{
   string symbol;
   int timeframe;
   int shift;
   StringInit(symbol, 100, 0);
   
   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iBWMFI", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iBWMFI", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 2, shift, _error)) 
   {
      PrintParamError("iBWMFI", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double res = iBWMFI(symbol, timeframe, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iBWMFI", _response_error);
   }
}

void Execute_iMomentum()
{
   string symbol;
   int timeframe;
   int period;
   int applied_price;
   int shift;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iMomentum", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iMomentum", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }

   if (!getIntValue(ExpertHandle, 2, period, _error)) 
   {
      PrintParamError("iMomentum", "period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }         
   
   if (!getIntValue(ExpertHandle, 3, applied_price, _error)) 
   {
      PrintParamError("iMomentum", "applied_price", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }         

   if (!getIntValue(ExpertHandle, 4, shift, _error)) 
   {
      PrintParamError("iMomentum", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double res = iMomentum(symbol, timeframe, period, applied_price, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iMomentum", _response_error);
   }
}

void Execute_iMomentumOnArray()
{
   int array_size = 0;
   double doubleArray[];
   int total;
   int period;
   int shift;
 
   int param_index = 0;  
   if (!getIntValue(ExpertHandle, param_index, array_size, _error))
   {
      PrintParamError("iMomentumOnArray", "array_size", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   ArrayResize(doubleArray, array_size);
   
   for(int i = 0; i < array_size; i++)
   {
      double tempDouble;
      
      param_index++;
      if (!getDoubleValue(ExpertHandle, param_index, tempDouble, _error))
      {
         PrintParamError("iMomentumOnArray", "array", _error);
         sendErrorResponse(ExpertHandle, -1, _error, _response_error);
         return;
      }
      
      doubleArray[i] = tempDouble;         
   }                  
   
   param_index++;
   if (!getIntValue(ExpertHandle, param_index, total, _error))
   {
      PrintParamError("iMomentumOnArray", "total", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }   
   
   param_index++;
   if (!getIntValue(ExpertHandle, param_index, period, _error))
   {
      PrintParamError("iMomentumOnArray", "period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }   
   
   param_index++;
   if (!getIntValue(ExpertHandle, param_index, shift, _error))
   {
      PrintParamError("iMomentumOnArray", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double res = iMomentumOnArray(doubleArray, total, period, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iMomentumOnArray", _response_error);
   }
}

void Execute_iMFI()
{
   string symbol;
   int timeframe;
   int period;
   int shift;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iMFI", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iMFI", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!getIntValue(ExpertHandle, 2, period, _error)) 
   {
      PrintParamError("iMFI", "period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }         
   
   if (!getIntValue(ExpertHandle, 3, shift, _error)) 
   {
      PrintParamError("iMFI", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   double res = iMFI(symbol, timeframe, period, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iMFI", _response_error);
   }
}

void Execute_iMA()
{
   string symbol;
   int timeframe;
   int period;
   int ma_shift;
   int ma_method;
   int applied_price;
   int shift;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iMA", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iMA", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }

   if (!getIntValue(ExpertHandle, 2, period, _error)) 
   {
      PrintParamError("iMA", "period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }         
   
   if (!getIntValue(ExpertHandle, 3, ma_shift, _error)) 
   {
      PrintParamError("iMA", "ma_shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }         

   if (!getIntValue(ExpertHandle, 4, ma_method, _error)) 
   {
      PrintParamError("iMA", "ma_method", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }         

   if (!getIntValue(ExpertHandle, 5, applied_price, _error)) 
   {
      PrintParamError("iMA", "applied_price", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }         
   
   if (!getIntValue(ExpertHandle, 6, shift, _error)) 
   {
      PrintParamError("iMA", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }         
   
   double res = iMA(symbol, timeframe, period, ma_shift, ma_method, applied_price, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iMA", _response_error);
   }
}

void Execute_iMAOnArray()
{
   int array_size = 0;
   double doubleArray[];
   int total;
   int period;
   int ma_shift;
   int ma_method;
   int shift;
 
   int param_index = 0;  
   if (!getIntValue(ExpertHandle, param_index, array_size, _error))
   {
      PrintParamError("iMAOnArray", "array_size", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
        
   ArrayResize(doubleArray, array_size);
   
   for(int i = 0; i < array_size; i++)
   {
      double tempDouble;
      param_index++;
      if (!getDoubleValue(ExpertHandle, param_index, tempDouble, _error))
      {
         PrintParamError("iMAOnArray", "array", _error);
         sendErrorResponse(ExpertHandle, -1, _error, _response_error);
         return;
      }
            
      doubleArray[i] = tempDouble;         
   }                  
   
   param_index++;
   if (!getIntValue(ExpertHandle, param_index, total, _error))
   {
      PrintParamError("iMAOnArray", "total", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;   
   }
   
   param_index++;
   if (!getIntValue(ExpertHandle, param_index, period, _error))
   {
      PrintParamError("iMAOnArray", "period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;   
   }
      
   param_index++;
   if (!getIntValue(ExpertHandle, param_index, ma_shift, _error))
   {
      PrintParamError("iMAOnArray", "ma_shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;   
   }   
   
   param_index++;
   if (!getIntValue(ExpertHandle, param_index, ma_method, _error))
   {
      PrintParamError("iMAOnArray", "ma_method", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;   
   }      
   
   param_index++;
   if (!getIntValue(ExpertHandle, param_index, shift, _error))
   {
      PrintParamError("iMAOnArray", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;   
   }        
   
   double res = iMAOnArray(doubleArray, total, period, ma_shift, ma_method, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iMAOnArray", _response_error);
   }
}

void Execute_iOsMA()
{
   string symbol;
   int timeframe;
   int fast_ema_period;
   int slow_ema_period;
   int signal_period;
   int applied_price;
   int shift;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iOsMA", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iOsMA", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!getIntValue(ExpertHandle, 2, fast_ema_period, _error)) 
   {
      PrintParamError("iOsMA", "fast_ema_period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }         
   
   if (!getIntValue(ExpertHandle, 3, slow_ema_period, _error)) 
   {
      PrintParamError("iOsMA", "slow_ema_period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }         

   if (!getIntValue(ExpertHandle, 4, signal_period, _error)) 
   {
      PrintParamError("iOsMA", "signal_period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }         

   if (!getIntValue(ExpertHandle, 5, applied_price, _error)) 
   {
      PrintParamError("iOsMA", "applied_price", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }         
   
   if (!getIntValue(ExpertHandle, 6, shift, _error)) 
   {
      PrintParamError("iOsMA", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double res = iOsMA(symbol, timeframe, fast_ema_period, slow_ema_period, signal_period, applied_price, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iOsMA", _response_error);
   }
}

void Execute_iMACD()
{
   string symbol;
   int timeframe;
   int fast_ema_period;
   int slow_ema_period;
   int signal_period;
   int applied_price;
   int mode;
   int shift;
   StringInit(symbol, 100, 0);
   
   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iMACD", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iMACD", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }

   if (!getIntValue(ExpertHandle, 2, fast_ema_period, _error)) 
   {
      PrintParamError("iMACD", "fast_ema_period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }         
   
   if (!getIntValue(ExpertHandle, 3, slow_ema_period, _error)) 
   {
      PrintParamError("iMACD", "slow_ema_period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }         

   if (!getIntValue(ExpertHandle, 4, signal_period, _error)) 
   {
      PrintParamError("iMACD", "signal_period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }         

   if (!getIntValue(ExpertHandle, 5, applied_price, _error)) 
   {
      PrintParamError("iMACD", "applied_price", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }         

   if (!getIntValue(ExpertHandle, 6, mode, _error)) 
   {
      PrintParamError("iMACD", "mode", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }         
   
   if (!getIntValue(ExpertHandle, 7, shift, _error)) 
   {
      PrintParamError("iMACD", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double res = iMACD(symbol, timeframe, fast_ema_period, slow_ema_period, signal_period, applied_price, mode, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iMACD", _response_error);
   }
}

void Execute_iOBV()
{
   string symbol;
   int timeframe;
   int applied_price;
   int shift;
   StringInit(symbol, 100, 0);
   
   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iOBV", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iOBV", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }

   if (!getIntValue(ExpertHandle, 2, applied_price, _error)) 
   {
      PrintParamError("iOBV", "applied_price", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }         
   
   if (!getIntValue(ExpertHandle, 3, shift, _error)) 
   {
      PrintParamError("iOBV", shift, _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double res = iOBV(symbol, timeframe, applied_price, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iOBV", _response_error);
   }
}

void Execute_iSAR()
{
   string symbol;
   int timeframe;
   double step;
   double maximum;
   int shift;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error))
   {      
      PrintParamError("iSAR", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iSAR", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }

   if (!getDoubleValue(ExpertHandle, 2, step, _error)) 
   {
      PrintParamError("iSAR", "step", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }         

   if (!getDoubleValue(ExpertHandle, 3, maximum, _error)) 
   {
      PrintParamError("iSAR", "maximum", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }         
   
   if (!getIntValue(ExpertHandle, 4, shift, _error)) 
   {
      PrintParamError("iSAR", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   double res = iSAR(symbol, timeframe, step, maximum, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iSAR", _response_error);
   }
}

void Execute_iRSI()
{
   string symbol;
   int timeframe;
   int period;
   int applied_price;
   int shift;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iRSI", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iRSI", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }

   if (!getIntValue(ExpertHandle, 2, period, _error)) 
   {
      PrintParamError("iRSI", "period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }         

   if (!getIntValue(ExpertHandle, 3, applied_price, _error)) 
   {
      PrintParamError("iRSI", "applied_price", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }         
   
   if (!getIntValue(ExpertHandle, 4, shift, _error)) 
   {
      PrintParamError("iRSI", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   double res = iRSI(symbol, timeframe, period, applied_price, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iRSI", _response_error);
   }
}

void Execute_iRSIOnArray()
{
   int array_size = 0;
   double doubleArray[];
   int total;
   int period;
   int shift;
 
   int param_index = 0;  
   if (!getIntValue(ExpertHandle, param_index, array_size, _error))
   {
      PrintParamError("iRSIOnArray", "array_size", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   ArrayResize(doubleArray, array_size);
   
   for(int i = 0; i < array_size; i++)
   {
      double tempDouble;
      param_index++;
      if (!getDoubleValue(ExpertHandle, param_index, tempDouble, _error))
      {
         PrintParamError("iRSIOnArray", "array", _error);
         sendErrorResponse(ExpertHandle, -1, _error, _response_error);
         return;
      }
      doubleArray[i] = tempDouble;         
   }
   
   param_index++;
   if (!getIntValue(ExpertHandle, param_index, total, _error))
   {
      PrintParamError("iRSIOnArray", "total", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   param_index++;
   if (!getIntValue(ExpertHandle, param_index, period, _error))
   {
      PrintParamError("iRSIOnArray", "period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   param_index++;
   if (!getIntValue(ExpertHandle, param_index, shift, _error))
   {
      PrintParamError("iRSIOnArray", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double res = iRSIOnArray(doubleArray, total, period, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iRSIOnArray", _response_error);
   }         
}

void Execute_iRVI()
{
   string symbol;
   int timeframe;
   int period;
   int mode;
   int shift;
   StringInit(symbol, 100, 0);
   
   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iRVI", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iRVI", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }

   if (!getIntValue(ExpertHandle, 2, period, _error)) 
   {
      PrintParamError("iRVI", "period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }         

   if (!getIntValue(ExpertHandle, 3, mode, _error)) 
   {
      PrintParamError("iRVI", "mode", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }         
   
   if (!getIntValue(ExpertHandle, 4, shift, _error)) 
   {
      PrintParamError("iRVI", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   double res = iRVI(symbol, timeframe, period, mode, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iRVI", _response_error);
   }
}

void Execute_iStdDev()
{
   string symbol;
   int timeframe;
   int ma_period;
   int ma_shift;
   int ma_method;
   int applied_price;
   int shift;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iStdDev", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iStdDev", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }

   if (!getIntValue(ExpertHandle, 2, ma_period, _error)) 
   {
      PrintParamError("iStdDev", "ma_period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   if (!getIntValue(ExpertHandle, 3, ma_shift, _error)) 
   {
      PrintParamError("iStdDev", "ma_shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }         

   if (!getIntValue(ExpertHandle, 4, ma_method, _error)) 
   {
      PrintParamError("iStdDev", "ma_method", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }         

   if (!getIntValue(ExpertHandle, 5, applied_price, _error)) 
   {
      PrintParamError("iStdDev", "applied_price", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }         

   if (!getIntValue(ExpertHandle, 6, shift, _error)) 
   {
      PrintParamError("iStdDev", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   double res = iStdDev(symbol, timeframe, ma_period, ma_shift, ma_method, applied_price, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iStdDev", _response_error);
   }
}

void Execute_iStdDevOnArray()
{
   int array_size;
   double doubleArray[];
   int total;
   int ma_period;
   int ma_shift;
   int ma_method;
   int shift;
   
   int param_index = 0;   
   if (!getIntValue(ExpertHandle, param_index, array_size, _error))
   {
      PrintParamError("iStdDevOnArray", "array_size", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   ArrayResize(doubleArray, array_size);   
   
   for(int i = 0; i < array_size; i++)
   {
      double tempDouble;
      param_index++;
      if (!getDoubleValue(ExpertHandle, param_index, tempDouble, _error))
      {
         PrintParamError("iStdDevOnArray", "array", _error);
         sendErrorResponse(ExpertHandle, -1, _error, _response_error);
         return;
      }
      
      doubleArray[i] = tempDouble;         
   }                  
   
   param_index++;
   if (!getIntValue(ExpertHandle, param_index, total, _error))
   {
      PrintParamError("iStdDevOnArray", "total", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   param_index++;   
   if (!getIntValue(ExpertHandle, param_index, ma_period, _error))
   {
      PrintParamError("iStdDevOnArray", "ma_period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }  
   
   param_index++;
   if (!getIntValue(ExpertHandle, param_index, ma_shift, _error))
   {
      PrintParamError("iStdDevOnArray", "ma_shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }  
   
   param_index++;    
   if (!getIntValue(ExpertHandle, param_index, ma_method, _error))
   {
      PrintParamError("iStdDevOnArray", "ma_method", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   } 
   
   param_index++;    
   if (!getIntValue(ExpertHandle, param_index, shift, _error))
   {
      PrintParamError("iStdDevOnArray", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   } 
   
   double res = iStdDevOnArray(doubleArray, total, ma_period, ma_shift, ma_method, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iStdDevOnArray", _response_error);
   } 
}

void Execute_iStochastic()
{
   string symbol;
   int timeframe;
   int kperiod;
   int dperiod;
   int slowing;
   int method;
   int price_field;
   int mode;
   int shift;
   StringInit(symbol, 100, 0);
   
   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iStochastic", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iStochastic", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!getIntValue(ExpertHandle, 2, kperiod, _error)) 
   {
      PrintParamError("iStochastic", "Kperiod", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }   
   
   if (!getIntValue(ExpertHandle, 3, dperiod, _error)) 
   {
      PrintParamError("iStochastic", "Dperiod", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!getIntValue(ExpertHandle, 4, slowing, _error)) 
   {
      PrintParamError("iStochastic", "slowing", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!getIntValue(ExpertHandle, 5, method, _error)) 
   {
      PrintParamError("iStochastic", "method", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!getIntValue(ExpertHandle, 6, price_field, _error)) 
   {
      PrintParamError("iStochastic", "price_field", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!getIntValue(ExpertHandle, 7, mode, _error)) 
   {
      PrintParamError("iStochastic", "mode", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }

   if (!getIntValue(ExpertHandle, 8, shift, _error)) 
   {
      PrintParamError("iStochastic", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   double res = iStochastic(symbol, timeframe, kperiod, dperiod, slowing, method, price_field, mode, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iStochastic", _response_error);
   }
}

void Execute_iWPR()
{
   string symbol;
   int timeframe;
   int period;
   int shift;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iWPR", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iWPR", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }

   if (!getIntValue(ExpertHandle, 2, period, _error)) 
   {
      PrintParamError("iWPR", "period", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   if (!getIntValue(ExpertHandle, 3, shift, _error)) 
   {
      PrintParamError("iWPR", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   double res = iWPR(symbol, timeframe, period, shift);

   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iWPR", _response_error);
   }
}

void Execute_iBars()
{
   string symbol;
   int timeframe;
   StringInit(symbol, 100, 0);
   
   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iBars", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;        
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iBars", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;         
   }
   
   int res = iBars(symbol, timeframe);
   
   if (!sendIntResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iBars", _response_error);
   }
}

void Execute_iBarShift()
{
   string symbol;
   int timeframe;
   int time;
   int exact;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iBarShift", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iBarShift", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;            
   }
   
   if (!getIntValue(ExpertHandle, 2, time, _error)) 
   {
      PrintParamError("iBarShift", "time", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;          
   }

   if (!getIntValue(ExpertHandle, 3, exact, _error)) 
   {
      PrintParamError("iBarShift", "exact", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;            
   }
   
   int res = iBarShift(symbol, timeframe, time, exact);
   
   if (!sendIntResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iBarShift", _response_error);
   }
}

void Execute_iClose()
{
   string symbol;
   int timeframe;
   int shift;
   StringInit(symbol, 100, 0);
   
   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iClose", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iClose", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 2, shift, _error)) 
   {
      PrintParamError("iClose", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double res = iClose(symbol, timeframe, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iClose", _response_error);
   }   
}

void Execute_iHigh()
{
   string symbol;
   int timeframe;
   int shift;
   StringInit(symbol, 100, 0);
   
   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iHigh", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iHigh", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 2, shift, _error)) 
   {
      PrintParamError("iHigh", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double res = iHigh(symbol, timeframe, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iHigh", _response_error);
   }
}

void Execute_iHighest()
{
   string symbol;
   int timeframe;
   int type;
   int count;
   int start_value;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iHighest", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iHighest", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;     
   }
   
   if (!getIntValue(ExpertHandle, 2, type, _error)) 
   {
      PrintParamError("iHighest", "type", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   if (!getIntValue(ExpertHandle, 3, count, _error)) 
   {
      PrintParamError("iHighest", "count", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }

   if (!getIntValue(ExpertHandle, 4, start_value, _error)) 
   {
      PrintParamError("iHighest", "start", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   int res = iHighest(symbol, timeframe, type, count, start_value);
   
   if (!sendIntResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iHighest", _response_error);
   }
}

void Execute_iLow()
{
   string symbol;
   int timeframe;
   int shift;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iLow", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iLow", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   if (!getIntValue(ExpertHandle, 2, shift, _error)) 
   {
      PrintParamError("iLow", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double res = iLow(symbol, timeframe, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iLow", _response_error);
   }
}

void Execute_iLowest()
{
   string symbol;
   int timeframe;
   int type;
   int count;
   int start_value;
   StringInit(symbol, 100, 0);
   
   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iLowest", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iLowest", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 2, type, _error)) 
   {
      PrintParamError("iLowest", "type", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;           
   }
   
   if (!getIntValue(ExpertHandle, 3, count, _error)) 
   {
      PrintParamError("iLowest", "count", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }

   if (!getIntValue(ExpertHandle, 4, start_value, _error)) 
   {
      PrintParamError("iLowest", "start", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   int res= iLowest(symbol, timeframe, type, count, start_value);
   
   if (!sendIntResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iLowest", _response_error);
   }
}

void Execute_iOpen()
{
   string symbol;
   int timeframe;
   int shift;
   StringInit(symbol, 100, 0);
   
   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iOpen", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iOpen", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 2, shift, _error)) 
   {
      PrintParamError("iOpen", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;       
   }
   
   double res = iOpen(symbol, timeframe, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iOpen", _response_error);
   }
}

void Execute_iTime()
{
   string symbol;
   int timeframe;
   int shift;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iTime", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iTime", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;            
   }
   
   if (!getIntValue(ExpertHandle, 2, shift, _error)) 
   {
      PrintParamError("iTime", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;              
   }
   
   int res = iTime(symbol, timeframe, shift);

   if (!sendIntResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iTime", _response_error);
   }
}

void Execute_iVolume()
{
   string symbol;
   int timeframe;
   int shift;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iVolume", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iVolume", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 2, shift, _error)) 
   {
      PrintParamError("iVolume", "shift", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double res = iVolume(symbol, timeframe, shift);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("iVolume", _response_error);
   }
}

void Execute_iCloseArray()
{
   string symbol;
   int timeframe;
   StringInit(symbol, 100, 0);
   
   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iCloseArray", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iCloseArray", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double priceArray[];
   int barsCount = iBars(symbol, timeframe);
   int priceCount = ArrayResize(priceArray, barsCount);
   
   for(int i = 0; i < priceCount; i++)
   {
      priceArray[i] = iClose(symbol, timeframe, i);
   }
                       
   if (!sendDoubleArrayResponse(ExpertHandle, priceArray, priceCount, _response_error)) 
   {
      PrintResponseError("iCloseArray", _response_error);
   }
}

void Execute_iHighArray()
{
   string symbol;
   int timeframe;
   StringInit(symbol, 100, 0);
   
   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iHighArray", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iHighArray", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double priceArray[];
   int barsCount = iBars(symbol, timeframe);
   int priceCount = ArrayResize(priceArray, barsCount);
   
   for(int i = 0; i < priceCount; i++)
   {
      priceArray[i] = iHigh(symbol, timeframe, i);
   }
                       
   if (!sendDoubleArrayResponse(ExpertHandle, priceArray, priceCount, _response_error)) 
   {
      PrintResponseError("iHighArray", _response_error);
   }
}

void Execute_iLowArray()
{
   string symbol;
   int timeframe;
   StringInit(symbol, 100, 0);
   
   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iLowArray", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iOpenArray", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double priceArray[];
   int barsCount = iBars(symbol, timeframe);
   int priceCount = ArrayResize(priceArray, barsCount);
   
   for(int i = 0; i < priceCount; i++)
   {
      priceArray[i] = iLow(symbol, timeframe, i);
   }
                       
   if (!sendDoubleArrayResponse(ExpertHandle, priceArray, priceCount, _response_error)) 
   {
      PrintResponseError("iLowArray", _response_error);
   }
}

void Execute_iOpenArray()
{
   string symbol;
   int timeframe;
   StringInit(symbol, 100, 0);
   
   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iOpenArray", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iOpenArray", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double priceArray[];
   int barsCount = iBars(symbol, timeframe);
   int priceCount = ArrayResize(priceArray, barsCount);
   
   for(int i = 0; i < priceCount; i++)
   {
      priceArray[i] = iOpen(symbol, timeframe, i);
   }
                       
   if (!sendDoubleArrayResponse(ExpertHandle, priceArray, priceCount, _response_error)) 
   {
      PrintResponseError("iOpenArray", _response_error);
   }
}

void Execute_iVolumeArray()
{
   string symbol;
   int timeframe;
   StringInit(symbol, 100, 0);
   
   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iVolumeArray", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iVolumeArray", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double volumeArray[];
   int barsCount = iBars(symbol, timeframe);
   int volumeCount = ArrayResize(volumeArray, barsCount);
   
   for(int i = 0; i < volumeCount; i++)
   {
      volumeArray[i] = iVolume(symbol, timeframe, i);
   }
                       
   if (!sendDoubleArrayResponse(ExpertHandle, volumeArray, volumeCount, _response_error)) 
   {
      PrintResponseError("iVolumeArray", _response_error);
   }
}

void Execute_iTimeArray()
{
   string symbol;
   int timeframe;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("iTimeArray", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getIntValue(ExpertHandle, 1, timeframe, _error)) 
   {
      PrintParamError("iTimeArray", "timeframe", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   int timeArray[];
   int barsCount = iBars(symbol, timeframe);
   int timeCount = ArrayResize(timeArray, barsCount);
   
   for(int i = 0; i < timeCount; i++)
   {
      timeArray[i] = iTime(symbol, timeframe, i);
   }
                       
   if (!sendIntArrayResponse(ExpertHandle, timeArray, timeCount, _response_error)) 
   {
      PrintResponseError("iTimeArray", _response_error);
   }
}

void Execute_RefreshRates()
{
   bool res = RefreshRates();

   if (!sendBooleanResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("RefreshRates", _response_error);
   }  
}

void Execute_TerminalInfoString()
{
   int type;

   if (getIntValue(ExpertHandle, 0, type, _error))
   {
      PrintParamError("TerminalInfoString", "type", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   string res = TerminalInfoString(type);
   
   if (!sendStringResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("TerminalInfoString", _response_error);
   }
}

void Execute_SymbolInfoString()
{
   string symbol;
   int propId;
   StringInit(symbol, 100, 0);

   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("SymbolInfoString", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
         
   if (getIntValue(ExpertHandle, 1, propId, _error))
   {
      PrintParamError("SymbolInfoString", "propId", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   string res = SymbolInfoString(symbol, propId);
   
   if (!sendStringResponse(ExpertHandle, res, _response_error)) 
   {
      PrintResponseError("SymbolInfoString", _response_error);
   }
}

void Execute_BacktestingReady()
{
   if (IsTesting())
   {
      Print("Remote client is ready for backteting");
      IsRemoteReadyForTesting = true;
   }
   
   if (!sendBooleanResponse(ExpertHandle, IsRemoteReadyForTesting, _response_error))
   {
      PrintResponseError("BacktestingReady", _response_error);
   }
}

void Execute_SymbolsTotal()
{
   bool select;
   
   if (!getBooleanValue(ExpertHandle, 0, select, _error))
   {
      PrintParamError("SymbolsTotal", "select", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   int res = SymbolsTotal(select);
   
   if (!sendIntResponse(ExpertHandle, res, _response_error))
   {
      PrintResponseError("SymbolsTotal", _response_error);
   }
}

void Execute_SymbolName()
{
   int index;
   bool select;
   
   if (!getIntValue(ExpertHandle, 0, index, _error))
   {
      PrintParamError("SymbolName", "index", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   if (!getBooleanValue(ExpertHandle, 1, select, _error))
   {
      PrintParamError("SymbolName", "select", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return; 
   }
   
   string res = SymbolName(index, select);
   
   if (!sendStringResponse(ExpertHandle, res, _response_error))
   {
      PrintResponseError("SymbolName", _response_error);
   }
}

void Execute_SymbolSelect()
{
   string symbol;
   bool select;
   StringInit(symbol, 100, 0);
   
   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("SymbolSelect", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;  
   }
   
   if (!getBooleanValue(ExpertHandle, 1, select, _error))
   {
      PrintParamError("SymbolSelect", "select", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;  
   }
   
   bool res = SymbolSelect(symbol, select);

   if (!sendBooleanResponse(ExpertHandle, res, _response_error))
   {
      PrintResponseError("SymbolSelect", _response_error);
   }
}

void Execute_SymbolInfoInteger()
{
   string symbol;
   int propId;
   StringInit(symbol, 100, 0);
   
   if (!getStringValue(ExpertHandle, 0, symbol, _error)) 
   {
      PrintParamError("SymbolInfoInteger", "symbol", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;      
   }

   if (!getIntValue(ExpertHandle, 1, propId, _error)) 
   {
      PrintParamError("SymbolInfoInteger", "propId", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   long res = SymbolInfoInteger(symbol, propId);
   
   if (!sendLongResponse(ExpertHandle, res, _response_error))
   {
      PrintResponseError("SymbolInfoInteger", _response_error);
   }
}

void Execute_TerminalInfoInteger()
{
   int propId;
      
   if (!getIntValue(ExpertHandle, 0, propId, _error)) 
   {
      PrintParamError("TerminalInfoInteger", "propId", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   int res = TerminalInfoInteger(propId);
   
   if (!sendIntResponse(ExpertHandle, res, _response_error))
   {
      PrintResponseError("TerminalInfoInteger", _response_error);
   }
}

void Execute_TerminalInfoDouble()
{
   int propId;

   if (!getIntValue(ExpertHandle, 0, propId, _error)) 
   {
      PrintParamError("TerminalInfoDouble", "propId", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }
   
   double res = TerminalInfoDouble(propId);
   
   if (!sendDoubleResponse(ExpertHandle, res, _response_error))
   {
      PrintResponseError("TerminalInfoDouble", _response_error);
   }
}

void Execute_CharId()
{
   long res = ChartID();
   
   if (!sendLongResponse(ExpertHandle, res, _response_error))
   {
      PrintResponseError("ChartId", _response_error);
   }
}

void Execute_ChartRedraw()
{
   long chartId;

   if (!getLongValue(ExpertHandle, 0, chartId, _error)) 
   {
      PrintParamError("ChartRedraw", "chartId", _error);
      sendErrorResponse(ExpertHandle, -1, _error, _response_error);
      return;
   }   
   
   ChartRedraw(chartId);
   
   if (!sendVoidResponse(ExpertHandle, _response_error))
   {
      PrintResponseError("ChartRedraw", _response_error);
   }  
}

void PrintParamError(string paramName)
{
   PrintFormat("[ERROR] parameter: %s.", paramName);
}

void PrintParamError(string commandName, string paramName, string error)
{
   PrintFormat("[ERROR] Command: %s, parameter: %s. %s", commandName, paramName, error);
}

void PrintResponseError(string commandName, string error = "")
{
   PrintFormat("[ERROR] response: %s. %s", commandName, error);
}

bool OrderCloseAll()
{
   int total = OrdersTotal();
   for(int i = total-1; i >= 0; i--)
   {
      if (OrderSelect(i, SELECT_BY_POS))
      {
         int type = OrderType();   
         switch(type)
         {
            //Close opened long positions
            case OP_BUY: OrderClose( OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_BID), 5, Red );
               break;      
            //Close opened short positions
            case OP_SELL: OrderClose( OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_ASK), 5, Red );
               break;
         }      
      }
   }
   
   return (true);
}

string CreateErrorResponse(int code, string error)
{
   JSONObject *joResponse = new JSONObject();   
   joResponse.put("ErrorCode", new JSONNumber(code));
   joResponse.put("ErrorMessage", new JSONString(error));
   
   string res = joResponse.toString();   
   delete joResponse;   
   return res; 
}

string CreateSuccessResponse(string responseName, JSONValue* responseBody)
{
   JSONObject *joResponse = new JSONObject();
   joResponse.put("ErrorCode", new JSONNumber(ERR_NO_ERROR));
      
   if (responseBody != NULL)
   {
      joResponse.put(responseName, responseBody);   
   }
   
   string res = joResponse.toString();   
   delete joResponse;   
   return res;
}

string OnRequest(string json)
{
   string response = "";

   JSONParser *parser = new JSONParser();
   JSONValue *jv = parser.parse(json);
   
   if(jv == NULL) 
   {   
      Print("OnRequest [ERROR]:" + (string)parser.getErrorCode() + parser.getErrorMessage());
   }
   else
   {
      if(jv.isObject()) 
      {
         JSONObject *jo = jv;
         int requestType = jo.getInt("RequestType");

         Print("OnRequest: RequestType = ", requestType);      
         switch(requestType)
         {
            case 1: //GetOrder
               response = ExecuteRequest_GetOrder(jo);
               break;
            case 2: //GetOrders
               response = ExecuteRequest_GetOrders(jo);
               break;
            case 3: //OrderSend
               response = ExecuteRequest_OrderSend(jo);
               break;
            case 4: //OrderClose
               response = ExecuteRequest_OrderClose(jo);
               break;
            case 5: //OrderCloseBy
               response = ExecuteRequest_OrderCloseBy(jo);
               break;
            case 6: //OrderDelete
               response = ExecuteRequest_OrderDelete(jo);
               break;
            case 7: //OrderModify
               response = ExecuteRequest_OrderModify(jo);
               break;
            case 8: //iCustom
               response = ExecuteRequest_iCustom(jo);
               break;
            case 9: //CopyRates
               response = ExecuteRequest_CopyRates(jo);
               break;
            case 10: //Session
               response = ExecuteRequest_Session(jo);
               break;
            case 11: //SeriesInfoInteger
               response = ExecuteRequest_SeriesInfoInteger(jo);
               break;
            case 12: //SymbolInfoDouble
               response = ExecuteRequest_SymbolInfoDouble(jo);
               break;
            case 13: //SymbolInfoTick
               response = ExecuteRequest_SymbolInfoTick(jo);
               break;
            default:
               Print("OnRequest [WARNING]: Unknown request type ", requestType);
               response = CreateErrorResponse(-1, "Unknown request type");
               break;
         }
      }
      
      delete jv;
   }   
   
   delete parser;
   
   Print("OnRequest: Response = ", response);
   
   return response;
}

string ExecuteRequest_GetOrder(JSONObject *jo)
{
   if (jo.getValue("Index") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter Index");
   if (jo.getValue("Select") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter Select");
   if (jo.getValue("Pool") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter Pool");

   int index = jo.getInt("Index");
   int select = jo.getInt("Select");
   int pool = jo.getInt("Pool");
   
   MtOrder* order = MtOrder::LoadOrder(index, select, pool);
   if (order == NULL)
      return CreateErrorResponse(GetLastError(), "GetOrder failed");   

   string response = CreateSuccessResponse("Order", order.CreateJson());
   delete order;
        
   return response;
}

string ExecuteRequest_GetOrders(JSONObject *jo)
{
   if (jo.getValue("Pool") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter Pool");

   int pool = jo.getInt("Pool");
      
   int total = (pool == MODE_HISTORY) ? OrdersHistoryTotal() : OrdersTotal();
   
   JSONArray* joOrders = new JSONArray();
   for(int pos = 0; pos < total; pos++)
   {
      MtOrder* order = MtOrder::LoadOrder(pos, SELECT_BY_POS, pool);
      if (order == NULL)
      {
         delete joOrders;
         return CreateErrorResponse(GetLastError(), "GetOrders failed");                  
      }
      
      joOrders.put(pos, order.CreateJson());
      delete order; 
   }
   
   return CreateSuccessResponse("Orders", joOrders);
}

string ExecuteRequest_OrderSend(JSONObject *jo)
{
   if (jo.getValue("Symbol") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter Symbol");
   if (jo.getValue("Cmd") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter Cmd");
   if (jo.getValue("Volume") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter Volume");
            
   string symbol = jo.getString("Symbol");
   int cmd = jo.getInt("Cmd");
   double volume = jo.getDouble("Volume");  
   
   double price;
  
   JSONValue *jvPrice = jo.getValue("Price");
   if (jvPrice != NULL)
   {
      price = jvPrice.getDouble();
   }
   else
   {
      int mode = MtOrder::isLong(cmd) ? MODE_ASK : MODE_BID;
      price = MarketInfo(symbol, mode);
   }
   
   JSONValue *jvSlippage = jo.getValue("Slippage");
   double slippage = (jvSlippage != NULL) ? jvSlippage.getDouble() : 1;
   
   JSONValue *jvStoploss = jo.getValue("Stoploss");
   double stoploss = (jvStoploss != NULL) ? jvStoploss.getDouble() : 0;
   
   JSONValue *jvTakeprofit = jo.getValue("Takeprofit");
   double takeprofit = (jvTakeprofit != NULL) ? jvTakeprofit.getDouble() : 0;
   
   JSONValue *jvComment = jo.getValue("Comment");
   string comment = (jvComment != NULL) ? jvComment.getString() : NULL;
   
   JSONValue *jvMagic = jo.getValue("Magic");
   int magic = (jvMagic != NULL) ? jvMagic.getInt() : 0;
   
   JSONValue *jvExpiration = jo.getValue("Expiration");
   int expiration = (jvExpiration != NULL) ? jvExpiration.getInt() : 0;
     
   JSONValue *jvArrowColor = jo.getValue("ArrowColor");
   int arrowcolor = (jvArrowColor != NULL) ? jvArrowColor.getInt() : clrNONE;
   
   int ticket = OrderSend(symbol, cmd, volume, price, slippage, stoploss, takeprofit, comment, magic, expiration, arrowcolor);
   if(ticket < 0)
      return CreateErrorResponse(GetLastError(), "OrderSend failed");
   
   JSONValue* jvTicket = new JSONNumber(ticket);
   return CreateSuccessResponse("Ticket", jvTicket);      
}

string ExecuteRequest_OrderClose(JSONObject *jo)
{
   if (jo.getValue("Ticket") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter Ticket");

   int ticket = jo.getInt("Ticket");
   
   double price;  
   JSONValue *jvPrice = jo.getValue("Price");
   if (jvPrice != NULL)
   {
      price = jvPrice.getDouble();
   }
   else
   {
      if (OrderSelect(ticket, SELECT_BY_TICKET))
      {
         string symbol = OrderSymbol();
         int mode = MtOrder::isLong(OrderType()) ? MODE_BID : MODE_ASK;
         price = MarketInfo(symbol, mode);
      }
      else
      {
         return CreateErrorResponse(-1, "Failed select order to get current price");
      }     
   }
   
   double lots;
   JSONValue *jvLots = jo.getValue("Lots");
   if (jvLots != NULL)
   {
      lots = jvLots.getDouble();
   }
   else
   {
      if (OrderSelect(ticket, SELECT_BY_TICKET))
      {
         lots = OrderLots();
      }
      else
      {
         return CreateErrorResponse(-1, "Failed select order to get lots of order");
      }     
   }
   
   JSONValue *jvSlippage = jo.getValue("Slippage");
   double slippage = (jvSlippage != NULL) ? jvSlippage.getDouble() : 1;
   
   JSONValue *jvArrowColor = jo.getValue("ArrowColor");
   int arrowcolor = (jvArrowColor != NULL) ? jvArrowColor.getInt() : clrNONE;

   if (!OrderClose(ticket, lots, price, slippage, arrowcolor))
      return CreateErrorResponse(GetLastError(), "OrderClose failed");
   return CreateSuccessResponse("", NULL);   
}

string ExecuteRequest_OrderCloseBy(JSONObject *jo)
{
   if (jo.getValue("Ticket") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter Ticket");
   if (jo.getValue("Opposite") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter Opposite");

   int ticket = jo.getInt("Ticket");
   int opposite = jo.getInt("Opposite");    
   
   JSONValue *jvArrowColor = jo.getValue("ArrowColor");
   int arrowcolor = (jvArrowColor != NULL) ? jvArrowColor.getInt() : CLR_NONE;

   if (!OrderCloseBy(ticket, opposite, arrowcolor))
      return CreateErrorResponse(GetLastError(), "OrderCloseBy failed");
   return CreateSuccessResponse("", NULL);   
}

string ExecuteRequest_OrderDelete(JSONObject *jo)
{
   if (jo.getValue("Ticket") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter Ticket");

   int ticket = jo.getInt("Ticket");
   
   JSONValue *jvArrowColor = jo.getValue("ArrowColor");
   int arrowcolor = (jvArrowColor != NULL) ? jvArrowColor.getInt() : CLR_NONE;

   if (!OrderDelete(ticket, arrowcolor))
      return CreateErrorResponse(GetLastError(), "OrderDelete failed");
   return CreateSuccessResponse("", NULL);   
}

string ExecuteRequest_OrderModify(JSONObject *jo)
{
   if (jo.getValue("Ticket") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter Ticket");
   if (jo.getValue("Price") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter Price");
   if (jo.getValue("Stoploss") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter Stoploss");
   if (jo.getValue("Takeprofit") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter Takeprofit");
   if (jo.getValue("Expiration") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter Expiration");         
      
   int ticket = jo.getInt("Ticket");
   double price = jo.getDouble("Price");
   double stoploss = jo.getDouble("Stoploss");
   double takeprofit = jo.getDouble("Takeprofit");
   int expiration = jo.getInt("Expiration");
   
   JSONValue *jvArrowColor = jo.getValue("ArrowColor");
   int arrowcolor = (jvArrowColor != NULL) ? jvArrowColor.getInt() : CLR_NONE;   
   
   if (!OrderModify(ticket, price, stoploss, takeprofit, expiration, arrowcolor))
      return CreateErrorResponse(GetLastError(), "OrderModify failed");
   return CreateSuccessResponse("", NULL);   
}

string ExecuteRequest_iCustom(JSONObject *jo)
{
   if (jo.getValue("Symbol") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter Symbol");
   if (jo.getValue("Timeframe") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter Timeframe");
   if (jo.getValue("Name") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter Name");
   if (jo.getValue("Mode") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter Mode");
   if (jo.getValue("Shift") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter Shift");         
   
   string symbol = jo.getString("Symbol");   
   int timeframe = jo.getInt("Timeframe");
   string name = jo.getString("Name");
   int mode = jo.getInt("Mode");
   int shift = jo.getInt("Shift");
   
   double result;
   
   if (jo.getValue("Params") == NULL)
   {
      result = iCustom(symbol, timeframe, name, mode, shift);
   }
   else 
   {
      JSONArray *jaParams = jo.getArray("Params");
      int size = jaParams.size();

      if (size < 0 || size > 10)
         return CreateErrorResponse(-1, "Parameter's count is out of range.");

      if (jo.getValue("ParamsType") == NULL)
         return CreateErrorResponse(-1, "Undefinded mandatory parameter ParamsType");         
         
      int paramsType =  jo.getInt("ParamsType");
      switch (paramsType)
      {
      case 0: //Int
      {
         int intParams[];
         ArrayResize(intParams, size);
         for (int i = 0; i < size; i++)
         {
            intParams[i] = jaParams.getInt(i);
         }
         result = iCustomT(symbol, timeframe, name, intParams, size, mode, shift);
      }
      break;
      case 1: //Double
      {
         int doubleParams[];
         ArrayResize(doubleParams, size);
         result = iCustomT(symbol, timeframe, name, doubleParams, size, mode, shift);
      }
      break;
      case 2: //String
      {
         string stringParams[];
         ArrayResize(stringParams, size);
         result = iCustomT(symbol, timeframe, name, stringParams, size, mode, shift);
      }
      break;
      case 3: //Boolean
      {
         string boolParams[];
         ArrayResize(boolParams, size);
         result = iCustomT(symbol, timeframe, name, boolParams, size, mode, shift);      
      }
      break;
      default:
         return CreateErrorResponse(-1, "Unsupported type of iCustom parameters.");
      break;
      }
   }

   return CreateSuccessResponse("Value", new JSONNumber(result));  
}

template<typename T>
double iCustomT(string symbol, int timeframe, string name, T &p[], int count, int mode, int shift)
{
   switch(count)
   {
   case 0:
      return iCustom(symbol, timeframe, name, mode, shift);
      break;
   case 1:
      return iCustom(symbol, timeframe, name, p[0], mode, shift);
   case 2:
      return iCustom(symbol, timeframe, name, p[0], p[1], mode, shift);
   case 3:
      return iCustom(symbol, timeframe, name, p[0], p[1], p[2], mode, shift);
   case 4:
      return iCustom(symbol, timeframe, name, p[0], p[1], p[2], p[3], mode, shift);
   case 5:
      return iCustom(symbol, timeframe, name, p[0], p[1], p[2], p[3], p[4], mode, shift);
   case 6:
      return iCustom(symbol, timeframe, name, p[0], p[1], p[2], p[3], p[4], p[5], mode, shift);
   case 7:
      return iCustom(symbol, timeframe, name, p[0], p[1], p[2], p[3], p[4], p[5], p[6], mode, shift);
   case 8:
      return iCustom(symbol, timeframe, name, p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7], mode, shift);
   case 9:
      return iCustom(symbol, timeframe, name, p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8], mode, shift);
   case 10:
      return iCustom(symbol, timeframe, name, p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8], p[9], mode, shift);
   default:
         return 0;
   }
}

string ExecuteRequest_CopyRates(JSONObject *jo)
{
   if (jo.getValue("Timeframe") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter Timeframe");
   if (jo.getValue("SymbolName") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter SymbolName");
   if (jo.getValue("CopyRatesType") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter CopyRatesType");
      
   string symbolName = jo.getString("SymbolName");
   int timeFrame = jo.getInt("Timeframe");
   int copyRatesType = jo.getInt("CopyRatesType");
   
   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   int copied = 0;
   
   if (copyRatesType == 1)
   {
      if (jo.getValue("StartPos") == NULL)
         return CreateErrorResponse(-1, "Undefinded mandatory parameter StartPos");
      if (jo.getValue("Count") == NULL)
         return CreateErrorResponse(-1, "Undefinded mandatory parameter Count");
      
      copied = CopyRates(symbolName, timeFrame, jo.getInt("StartPos"), jo.getInt("Count"), rates);      
   }
   else if (copyRatesType == 2)
   {
      if (jo.getValue("StartTime") == NULL)
         return CreateErrorResponse(-1, "Undefinded mandatory parameter StartTime");
      if (jo.getValue("Count") == NULL)
         return CreateErrorResponse(-1, "Undefinded mandatory parameter Count");
         
      copied = CopyRates(symbolName, timeFrame, (datetime)jo.getInt("StartTime"), jo.getInt("Count"), rates);  
   }
   else if (copyRatesType == 3)
   {
      if (jo.getValue("StartTime") == NULL)
         return CreateErrorResponse(-1, "Undefinded mandatory parameter StartTime");
      if (jo.getValue("StopTime") == NULL)
         return CreateErrorResponse(-1, "Undefinded mandatory parameter StopTime");
         
      copied = CopyRates(symbolName, timeFrame, (datetime)jo.getInt("StartTime"), (datetime)jo.getInt("StopTime"), rates); 
   }
   else
   {
       return CreateErrorResponse(-1, "Unsupported type of CopyRates.");
   }

   if(copied < 0)
   {
      return CreateErrorResponse(GetLastError(), "CopyRates failed.");
   }

   JSONArray* jaRates = new JSONArray();
   for(int i = 0; i < copied; i++)
   {
      JSONObject *joRate = new JSONObject();   
      joRate.put("MtTime", new JSONNumber(rates[i].time));
      joRate.put("Open", new JSONNumber(rates[i].open)); 
      joRate.put("High", new JSONNumber(rates[i].high));
      joRate.put("Low", new JSONNumber(rates[i].low));
      joRate.put("Close", new JSONNumber(rates[i].close));
      joRate.put("TickVolume", new JSONNumber(rates[i].tick_volume));
      joRate.put("Spread", new JSONNumber(rates[i].spread));
      joRate.put("RealVolume", new JSONNumber(rates[i].real_volume));
      
      jaRates.put(i, joRate);
   }
   
   return CreateSuccessResponse("Rates", jaRates);
}

string ExecuteRequest_Session(JSONObject *jo)
{
   if (jo.getValue("Symbol") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter Symbol");
   if (jo.getValue("DayOfWeek") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter DayOfWeek");
   if (jo.getValue("SessionIndex") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter SessionIndex");
   if (jo.getValue("SessionType") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter SessionType");
      
   string symbolName = jo.getString("Symbol");
   int dayOfWeek = jo.getInt("DayOfWeek");
   int sessionIndex = jo.getInt("SessionIndex");
   int sessionType = jo.getInt("SessionType");  
   
   MtSession* session = MtSession::LoadSession(symbolName, dayOfWeek, sessionIndex, sessionType);   
   string responce = CreateSuccessResponse("Session", session.CreateJson());  
   delete session;
   
   return responce; 
}

string ExecuteRequest_SeriesInfoInteger(JSONObject *jo)
{
   if (jo.getValue("SymbolName") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter SymbolName");
   if (jo.getValue("Timeframe") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter Timeframe");
   if (jo.getValue("PropId") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter PropId");      
      
   string symbolName = jo.getString("SymbolName");
   int timeframe = jo.getInt("Timeframe");
   int propId = jo.getInt("PropId");
   
   long value = 0;
   if (!SeriesInfoInteger(symbolName, timeframe, propId, value))
      return CreateErrorResponse(GetLastError(), "SeriesInfoInteger failed");
      
   return CreateSuccessResponse("Value", new JSONNumber(value));   
}

string ExecuteRequest_SymbolInfoDouble(JSONObject *jo)
{
   if (jo.getValue("SymbolName") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter SymbolName");
   if (jo.getValue("PropId") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter PropId");
      
   string symbolName = jo.getString("SymbolName");
   int propId = jo.getInt("PropId");
   
   double value = 0;
   if (!SymbolInfoDouble(symbolName, propId, value))
      return CreateErrorResponse(GetLastError(), "SymbolInfoDouble failed");
      
   return CreateSuccessResponse("Value", new JSONNumber(value));       
}

string ExecuteRequest_SymbolInfoTick(JSONObject *jo)
{
   if (jo.getValue("Symbol") == NULL)
      return CreateErrorResponse(-1, "Undefinded mandatory parameter Symbol");
   
   string symbol = jo.getString("Symbol");
   
   MqlTick tick;
   if (!SymbolInfoTick(symbol, tick))
      return CreateErrorResponse(GetLastError(), "SymbolInfoDouble failed");

   JSONObject *joTick = new JSONObject();   
   joTick.put("MtTime", new JSONNumber(tick.time));
   joTick.put("Bid", new JSONNumber(tick.bid)); 
   joTick.put("Ask", new JSONNumber(tick.ask));
   joTick.put("Last", new JSONNumber(tick.last));
   joTick.put("Volume", new JSONNumber(tick.volume));
   
   return CreateSuccessResponse("Tick", joTick);
}