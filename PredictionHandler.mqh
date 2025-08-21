//+------------------------------------------------------------------+
//|                                      Fixed PredictionHandler.mqh |
//|                              Matches Python Server Response      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

struct SPredictionData
{ 
    datetime timestamp; 
    double price; 
    double confidence; 
    int timeframe; 
};

class CPredictionHandler
{
private:
    int hourlyPredictionCount; 
    int dailyPredictionCount;
    SPredictionData lastHourlyPredictions[]; 
    SPredictionData lastDailyPredictions[];
public:
    CPredictionHandler(); 
    ~CPredictionHandler();
    bool Initialize(int hourlyCount, int dailyCount);
    bool ParsePredictions(string jsonResponse, double &hourlyPreds[], double &dailyPreds[]);
private:
    bool ParseJSONArray(string json, string arrayName, double &values[]);
    bool IsValidResponse(string jsonResponse);  // NEW: Response validation
    void LogResponseDetails(string jsonResponse);  // NEW: Debug logging
};

CPredictionHandler::CPredictionHandler()
{ 
    hourlyPredictionCount=5; 
    dailyPredictionCount=5; 
}

CPredictionHandler::~CPredictionHandler()
{ 
    ArrayFree(lastHourlyPredictions); 
    ArrayFree(lastDailyPredictions); 
}

bool CPredictionHandler::Initialize(int hourlyCount, int dailyCount)
{
    if(hourlyCount<=0 || dailyCount<=0) return false;
    hourlyPredictionCount=hourlyCount; 
    dailyPredictionCount=dailyCount;
    ArrayResize(lastHourlyPredictions, hourlyPredictionCount); 
    ArrayResize(lastDailyPredictions, dailyPredictionCount);
    Print("PredictionHandler: Initialized for ", hourlyCount, " hourly and ", dailyCount, " daily predictions");
    return true;
}

//+------------------------------------------------------------------+
//| NEW: Validate server response format                            |
//+------------------------------------------------------------------+
bool CPredictionHandler::IsValidResponse(string jsonResponse)
{
    if(StringLen(jsonResponse) < 10)
    {
        Print("PredictionHandler: Response too short");
        return false;
    }
    
    // Check for required fields
    if(StringFind(jsonResponse, "\"success\"") == -1)
    {
        Print("PredictionHandler: Response missing 'success' field");
        return false;
    }
    
    // Check if success is true
    if(StringFind(jsonResponse, "\"success\":true") == -1 && StringFind(jsonResponse, "\"success\": true") == -1)
    {
        Print("PredictionHandler: Server returned success=false");
        
        // Try to extract error message
        int errorPos = StringFind(jsonResponse, "\"error\"");
        if(errorPos != -1)
        {
            int startQuote = StringFind(jsonResponse, "\"", errorPos + 7);
            int endQuote = StringFind(jsonResponse, "\"", startQuote + 1);
            if(startQuote != -1 && endQuote != -1)
            {
                string errorMsg = StringSubstr(jsonResponse, startQuote + 1, endQuote - startQuote - 1);
                Print("PredictionHandler: Server error: ", errorMsg);
            }
        }
        return false;
    }
    
    // Check for prediction arrays with correct names
    if(StringFind(jsonResponse, "\"hourly_predictions\"") == -1)
    {
        Print("PredictionHandler: Response missing 'hourly_predictions' field");
        return false;
    }
    
    if(StringFind(jsonResponse, "\"daily_predictions\"") == -1)
    {
        Print("PredictionHandler: Response missing 'daily_predictions' field");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| NEW: Log response details for debugging                         |
//+------------------------------------------------------------------+
void CPredictionHandler::LogResponseDetails(string jsonResponse)
{
    Print("PredictionHandler: Response length: ", StringLen(jsonResponse));
    Print("PredictionHandler: Response preview: ", StringSubstr(jsonResponse, 0, 300), "...");
    
    // Check what fields are present
    string fields[] = {"success", "timestamp", "symbol", "timeframe", "hourly_predictions", "daily_predictions", "model_info"};
    for(int i = 0; i < ArraySize(fields); i++)
    {
        bool found = StringFind(jsonResponse, "\"" + fields[i] + "\"") != -1;
        Print("PredictionHandler: Field '", fields[i], "': ", found ? "FOUND" : "MISSING");
    }
}

//+------------------------------------------------------------------+
//| FIXED: Parse predictions with correct field names              |
//+------------------------------------------------------------------+
bool CPredictionHandler::ParsePredictions(string jsonResponse, double &hourlyPreds[], double &dailyPreds[])
{
    if(StringLen(jsonResponse)==0) 
    {
        Print("PredictionHandler: Empty response");
        return false;
    }
    
    // Log response details for debugging
    LogResponseDetails(jsonResponse);
    
    // Validate response format
    if(!IsValidResponse(jsonResponse))
    {
        Print("PredictionHandler: Invalid response format");
        return false;
    }
    
    // FIXED: Use correct field names that match Python server response
    if(!ParseJSONArray(jsonResponse, "hourly_predictions", hourlyPreds))
    { 
        Print("PredictionHandler: Failed to parse 'hourly_predictions' array"); 
        return false; 
    }
    
    if(!ParseJSONArray(jsonResponse, "daily_predictions", dailyPreds))
    { 
        Print("PredictionHandler: Failed to parse 'daily_predictions' array"); 
        return false; 
    }
    
    Print("PredictionHandler: Successfully parsed ", ArraySize(hourlyPreds), " hourly and ", ArraySize(dailyPreds), " daily predictions");
    return true;
}

//+------------------------------------------------------------------+
//| ENHANCED: JSON array parser with better error handling         |
//+------------------------------------------------------------------+
bool CPredictionHandler::ParseJSONArray(string json, string arrayName, double &values[])
{
    // Look for the array with quotes around the field name
    string searchKey = "\"" + arrayName + "\":[";
    int startPos = StringFind(json, searchKey);
    
    if(startPos == -1) 
    {
        // Try with space after colon
        searchKey = "\"" + arrayName + "\": [";
        startPos = StringFind(json, searchKey);
        
        if(startPos == -1)
        {
            Print("PredictionHandler: Array '", arrayName, "' not found in JSON");
            Print("PredictionHandler: Available content: ", StringSubstr(json, 0, 500));
            return false;
        }
    }
    
    // Move to start of array content
    startPos += StringLen(searchKey);
    
    // Find the end of the array
    int endPos = StringFind(json, "]", startPos);
    if(endPos == -1) 
    {
        Print("PredictionHandler: Array '", arrayName, "' not properly closed");
        return false;
    }
    
    // Extract array content
    string arrayContent = StringSubstr(json, startPos, endPos - startPos);
    
    // Remove any whitespace
    StringTrimLeft(arrayContent);
    StringTrimRight(arrayContent);
    
    Print("PredictionHandler: Parsing array '", arrayName, "' content: ", arrayContent);
    
    // Handle empty array
    if(StringLen(arrayContent) == 0)
    {
        ArrayResize(values, 0);
        Print("PredictionHandler: Array '", arrayName, "' is empty");
        return true;
    }
    
    // Split by comma and convert to doubles
    string elements[];
    int elementCount = StringSplit(arrayContent, ',', elements);
    
    if(elementCount > 0)
    {
        ArrayResize(values, elementCount);
        for(int i = 0; i < elementCount; i++) 
        {
            // Remove whitespace from each element
            StringTrimLeft(elements[i]);
            StringTrimRight(elements[i]);
            
            // Convert to double
            values[i] = StringToDouble(elements[i]);
            
            // Validate the number
            if(!MathIsValidNumber(values[i]))
            {
                Print("PredictionHandler: Invalid number at index ", i, ": '", elements[i], "'");
                return false;
            }
        }
        
        Print("PredictionHandler: Successfully parsed ", elementCount, " values from '", arrayName, "'");
        return true;
    }
    
    Print("PredictionHandler: No elements found in array '", arrayName, "'");
    return false;
}




























































































