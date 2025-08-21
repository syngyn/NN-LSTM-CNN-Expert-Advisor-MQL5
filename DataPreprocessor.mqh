//+------------------------------------------------------------------+
//|                                      Fixed DataPreprocessor.mqh  |
//|                              Resolves JSON Formatting Issues     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

class CDataPreprocessor
{
private:
    int historyBars;
    int rsiHandle, macdHandle, maHandle, bollingerHandle, atrHandle, stochHandle;
public:
    CDataPreprocessor(); ~CDataPreprocessor();
    bool Initialize(int historyBarsCount);
    bool PrepareMarketData(double &outputData[]);
    string ConvertToJSON(string symbol, string timeframe, double currentPrice, double &data[]);
private:
    bool ValidateDataArray(double &data[]);
    void FixInvalidValues(double &data[]);
    string FormatNumber(double number);  // NEW: Proper number formatting
    bool IsValidJSONString(string json); // NEW: JSON validation
};

CDataPreprocessor::CDataPreprocessor()
{ 
    historyBars=100; 
    rsiHandle=INVALID_HANDLE; 
    macdHandle=INVALID_HANDLE; 
    maHandle=INVALID_HANDLE; 
    bollingerHandle=INVALID_HANDLE; 
    atrHandle=INVALID_HANDLE; 
    stochHandle=INVALID_HANDLE; 
}

CDataPreprocessor::~CDataPreprocessor()
{ 
    if(rsiHandle!=INVALID_HANDLE)IndicatorRelease(rsiHandle); 
    if(macdHandle!=INVALID_HANDLE)IndicatorRelease(macdHandle); 
    if(maHandle!=INVALID_HANDLE)IndicatorRelease(maHandle); 
    if(bollingerHandle!=INVALID_HANDLE)IndicatorRelease(bollingerHandle); 
    if(atrHandle!=INVALID_HANDLE)IndicatorRelease(atrHandle); 
    if(stochHandle!=INVALID_HANDLE)IndicatorRelease(stochHandle); 
}

bool CDataPreprocessor::Initialize(int historyBarsCount)
{
    if(historyBarsCount <= 0) return false;
    historyBars = historyBarsCount;
    
    rsiHandle = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
    macdHandle = iMACD(_Symbol, _Period, 12, 26, 9, PRICE_CLOSE);
    maHandle = iMA(_Symbol, _Period, 20, 0, MODE_SMA, PRICE_CLOSE);
    bollingerHandle = iBands(_Symbol, _Period, 20, 0, 2.0, PRICE_CLOSE);
    atrHandle = iATR(_Symbol, _Period, 14);
    stochHandle = iStochastic(_Symbol, _Period, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
    
    if(rsiHandle==INVALID_HANDLE || macdHandle==INVALID_HANDLE || maHandle==INVALID_HANDLE || 
       bollingerHandle==INVALID_HANDLE || atrHandle==INVALID_HANDLE || stochHandle==INVALID_HANDLE)
    { 
        Print("DataPreprocessor: Failed to initialize one or more indicators."); 
        return false; 
    }
    
    Print("DataPreprocessor: Initialized with ", historyBars, " bars and technical indicators.");
    return true;
}

bool CDataPreprocessor::PrepareMarketData(double &outputData[])
{
    if(Bars(_Symbol, _Period) < historyBars + 1)
    { 
        Print("DataPreprocessor: Not enough bars available."); 
        return false; 
    }
    
    MqlRates rates[];
    if(CopyRates(_Symbol, _Period, 0, historyBars, rates) != historyBars) 
        return false;
    
    ArraySetAsSeries(rates, false);
    
    double rsi[], macd[], ma[], bb_upper[], bb_lower[], atr[], stoch[];
    
    if(CopyBuffer(rsiHandle,0,0,historyBars,rsi)<=0||
       CopyBuffer(macdHandle,0,0,historyBars,macd)<=0||
       CopyBuffer(maHandle,0,0,historyBars,ma)<=0||
       CopyBuffer(bollingerHandle,1,0,historyBars,bb_upper)<=0||
       CopyBuffer(bollingerHandle,2,0,historyBars,bb_lower)<=0||
       CopyBuffer(atrHandle,0,0,historyBars,atr)<=0||
       CopyBuffer(stochHandle,0,0,historyBars,stoch)<=0)
    { 
        Print("DataPreprocessor: Failed to copy indicator buffers."); 
        return false; 
    }
    
    ArraySetAsSeries(rsi, false); 
    ArraySetAsSeries(macd, false); 
    ArraySetAsSeries(ma, false); 
    ArraySetAsSeries(bb_upper, false); 
    ArraySetAsSeries(bb_lower, false); 
    ArraySetAsSeries(atr, false); 
    ArraySetAsSeries(stoch, false);
    
    int featuresPerBar = 12;
    ArrayResize(outputData, historyBars * featuresPerBar);
    
    for(int i = 0; i < historyBars; i++)
    {
        int base = i * featuresPerBar;
        outputData[base + 0] = rates[i].open; 
        outputData[base + 1] = rates[i].high; 
        outputData[base + 2] = rates[i].low; 
        outputData[base + 3] = rates[i].close; 
        outputData[base + 4] = (double)rates[i].tick_volume;
        outputData[base + 5] = rsi[i]; 
        outputData[base + 6] = macd[i]; 
        outputData[base + 7] = ma[i]; 
        outputData[base + 8] = bb_upper[i]; 
        outputData[base + 9] = bb_lower[i]; 
        outputData[base + 10] = atr[i]; 
        outputData[base + 11] = stoch[i];
    }
    
    // ENHANCED VALIDATION AND FIXING
    if(!ValidateDataArray(outputData))
    {
        Print("DataPreprocessor: Invalid data detected, attempting to fix...");
        FixInvalidValues(outputData);
        
        if(!ValidateDataArray(outputData))
        {
            Print("DataPreprocessor: Unable to fix invalid data.");
            return false;
        }
        Print("DataPreprocessor: Invalid data fixed successfully.");
    }
    
    Print("DataPreprocessor: Prepared ", ArraySize(outputData), " data points (", historyBars, " bars)");
    return true;
}

//+------------------------------------------------------------------+
//| NEW: Proper number formatting for JSON                          |
//+------------------------------------------------------------------+
string CDataPreprocessor::FormatNumber(double number)
{
    // Handle special cases
    if(!MathIsValidNumber(number))
        return "0.0";
    
    // Prevent scientific notation by limiting precision
    if(MathAbs(number) > 1000000)
        return DoubleToString(number, 2);
    else if(MathAbs(number) > 1)
        return DoubleToString(number, 6);
    else
        return DoubleToString(number, 8);
}

//+------------------------------------------------------------------+
//| NEW: JSON string validation                                     |
//+------------------------------------------------------------------+
bool CDataPreprocessor::IsValidJSONString(string json)
{
    // Basic validation
    if(StringLen(json) < 10) return false;
    
    // Must start with { and end with }
    if(StringGetCharacter(json, 0) != '{') return false;
    if(StringGetCharacter(json, StringLen(json) - 1) != '}') return false;
    
    // Must contain required fields
    if(StringFind(json, "\"symbol\"") == -1) return false;
    if(StringFind(json, "\"data\"") == -1) return false;
    
    return true;
}

bool CDataPreprocessor::ValidateDataArray(double &data[])
{
    int size = ArraySize(data);
    
    // Check minimum size (5 bars minimum = 60 data points)
    if(size < 60)
    {
        Print("DataPreprocessor: Data array too small: ", size, " (minimum 60 required)");
        return false;
    }
    
    // Check for invalid values
    int invalidCount = 0;
    for(int i = 0; i < size; i++)
    {
        if(!MathIsValidNumber(data[i]) || data[i] == EMPTY_VALUE)
        {
            invalidCount++;
        }
    }
    
    if(invalidCount > 0)
    {
        Print("DataPreprocessor: Found ", invalidCount, " invalid values in data array");
        return false;
    }
    
    return true;
}

void CDataPreprocessor::FixInvalidValues(double &data[])
{
    int size = ArraySize(data);
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    for(int i = 0; i < size; i++)
    {
        if(!MathIsValidNumber(data[i]) || data[i] == EMPTY_VALUE)
        {
            // Determine what type of data this should be based on position
            int positionInBar = i % 12;
            
            switch(positionInBar)
            {
                case 0: case 1: case 2: case 3: case 7: case 8: case 9: // OHLC, MA, BB
                    data[i] = currentPrice;
                    break;
                case 4: // Volume
                    data[i] = 1000.0;
                    break;
                case 5: case 11: // RSI, Stochastic
                    data[i] = 50.0;
                    break;
                case 6: // MACD
                    data[i] = 0.0;
                    break;
                case 10: // ATR
                    data[i] = 0.001;
                    break;
                default:
                    data[i] = currentPrice;
                    break;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| FIXED: Enhanced JSON creation with proper formatting            |
//+------------------------------------------------------------------+
string CDataPreprocessor::ConvertToJSON(string symbol, string timeframe, double currentPrice, double &data[])
{
    // CRITICAL: Final validation before sending
    if(!ValidateDataArray(data))
    {
        Print("DataPreprocessor: Data validation failed before JSON conversion");
        return "";
    }
    
    // FIXED: Normalize timeframe format for server compatibility
    string normalizedTimeframe = timeframe;
    if(StringFind(timeframe, "PERIOD_") == 0)
    {
        // Convert PERIOD_H1 to H1, PERIOD_M1 to M1, etc.
        normalizedTimeframe = StringSubstr(timeframe, 7); // Remove "PERIOD_" prefix
        Print("DataPreprocessor: Normalized timeframe from '", timeframe, "' to '", normalizedTimeframe, "'");
    }
    
    // Create JSON string with proper formatting
    string json = "";
    json += "{";
    
    // Add symbol field
    json += "\"symbol\":\"" + symbol + "\"";
    
    // Add timeframe field (normalized)
    json += ",\"timeframe\":\"" + normalizedTimeframe + "\"";
    
    // Add current price field (use proper number formatting)
    json += ",\"current_price\":" + FormatNumber(currentPrice);
    
    // Add data array
    json += ",\"data\":[";
    
    int size = ArraySize(data);
    for(int i = 0; i < size; i++)
    {
        // CRITICAL: Ensure each value is valid and properly formatted
        double value = data[i];
        if(!MathIsValidNumber(value))
        {
            Print("DataPreprocessor: Invalid value at index ", i, ", using fallback");
            value = 0.0; // Safe fallback value
        }
        
        // Use proper number formatting to avoid scientific notation
        json += FormatNumber(value);
        
        // Add comma if not last element
        if(i < size - 1) 
            json += ",";
    }
    
    // Close data array and JSON object
    json += "]}";
    
    // CRITICAL: Validate the created JSON
    if(!IsValidJSONString(json))
    {
        Print("DataPreprocessor: Generated invalid JSON!");
        return "";
    }
    
    // Log for debugging (show first and last parts)
    int jsonLen = StringLen(json);
    string preview = StringSubstr(json, 0, MathMin(200, jsonLen));
    string suffix = "";
    if(jsonLen > 400)
    {
        suffix = "..." + StringSubstr(json, jsonLen - 100, 100);
    }
    
    Print("DataPreprocessor: JSON created successfully");
    Print("  Length: ", jsonLen, " characters");
    Print("  Preview: ", preview, suffix);
    Print("  Data points: ", size);
    
    return json;
}