//+------------------------------------------------------------------+
//|                                   Enhanced HttpClient.mqh       |
//|                        Better Error Handling & Server Response  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

class CHttpClient
{
private:
    string serverURL;
    int timeout;
    string userAgent;
public:
    CHttpClient(); ~CHttpClient();
    bool Initialize(string url, int timeoutMs=30000);
    bool SendPredictionRequest(string jsonData, string &response);
    bool TestConnection();
    void Cleanup();
private:
    bool IsValidJSON(string json);
    string SafeStringToCharArray(string str, char &result[]);
    bool ValidateJSONBeforeSending(string json);
    void LogServerError(int httpCode, string responseBody, string responseHeaders); // NEW
    string GetErrorDescription(int errorCode); // NEW
};

CHttpClient::CHttpClient()
{ 
    timeout = 30000; 
    userAgent = "MT5-PredictiveEA/4.1"; 
}

CHttpClient::~CHttpClient()
{
    // Cleanup handled in Cleanup()
}

void CHttpClient::Cleanup()
{
    // Any cleanup operations if needed
}

bool CHttpClient::Initialize(string url, int timeoutMs=30000)
{
    if(StringLen(url) == 0)
    { 
        Print("HttpClient: Invalid URL"); 
        return false; 
    }
    
    serverURL = url;
    timeout = timeoutMs;
    
    // Ensure URL doesn't end with slash for consistency
    if(StringSubstr(serverURL, StringLen(serverURL) - 1) == "/")
    { 
        serverURL = StringSubstr(serverURL, 0, StringLen(serverURL) - 1); 
    }
    
    Print("HttpClient: Initialized with URL: ", serverURL);
    Print("HttpClient: Timeout set to: ", timeout, "ms");
    
    return TestConnection();
}

//+------------------------------------------------------------------+
//| NEW: Get human-readable error description                       |
//+------------------------------------------------------------------+
string CHttpClient::GetErrorDescription(int errorCode)
{
    switch(errorCode)
    {
        case 5203: return "WebRequest not allowed for this URL (check allowed URLs in settings)";
        case 4060: return "Function not allowed in testing mode";
        case 4014: return "Invalid function parameter";
        case 4013: return "Invalid function parameter value";
        case 4012: return "Array index out of range";
        case 4003: return "No memory for function call stack";
        default: return "Unknown error code: " + IntegerToString(errorCode);
    }
}

//+------------------------------------------------------------------+
//| NEW: Enhanced server error logging                              |
//+------------------------------------------------------------------+
void CHttpClient::LogServerError(int httpCode, string responseBody, string responseHeaders)
{
    Print("HttpClient: ===== SERVER ERROR DETAILS =====");
    Print("HttpClient: HTTP Status Code: ", httpCode);
    Print("HttpClient: MT5 Error Code: ", GetLastError(), " (", GetErrorDescription(GetLastError()), ")");
    Print("HttpClient: Server URL: ", serverURL);
    
    if(StringLen(responseHeaders) > 0)
    {
        Print("HttpClient: Response Headers: ", responseHeaders);
    }
    
    if(StringLen(responseBody) > 0)
    {
        Print("HttpClient: Server Response Body:");
        // Log response in chunks if it's long
        int maxChunkSize = 1000;
        int totalLen = StringLen(responseBody);
        
        for(int i = 0; i < totalLen; i += maxChunkSize)
        {
            int chunkLen = MathMin(maxChunkSize, totalLen - i);
            string chunk = StringSubstr(responseBody, i, chunkLen);
            Print("HttpClient: Response[", i, "-", i+chunkLen-1, "]: ", chunk);
        }
    }
    else
    {
        Print("HttpClient: No response body received");
    }
    
    Print("HttpClient: ===== END SERVER ERROR =====");
}

//+------------------------------------------------------------------+
//| Safe string to char array conversion                            |
//+------------------------------------------------------------------+
string CHttpClient::SafeStringToCharArray(string str, char &result[])
{
    // Calculate the actual byte length needed
    int strLen = StringLen(str);
    
    // Resize array to exact size needed (no null terminator for HTTP)
    ArrayResize(result, strLen);
    
    // Convert each character individually to avoid encoding issues
    for(int i = 0; i < strLen; i++)
    {
        result[i] = (char)StringGetCharacter(str, i);
    }
    
    return "OK";
}

//+------------------------------------------------------------------+
//| Validate JSON before sending                                    |
//+------------------------------------------------------------------+
bool CHttpClient::ValidateJSONBeforeSending(string json)
{
    // Check basic structure
    if(StringLen(json) < 10)
    {
        Print("HttpClient: JSON too short: ", StringLen(json), " characters");
        return false;
    }
    
    // Must start and end correctly
    if(StringGetCharacter(json, 0) != '{' || 
       StringGetCharacter(json, StringLen(json) - 1) != '}')
    {
        Print("HttpClient: JSON doesn't have proper braces");
        Print("HttpClient: First char: ", StringGetCharacter(json, 0));
        Print("HttpClient: Last char: ", StringGetCharacter(json, StringLen(json) - 1));
        return false;
    }
    
    // Check for required fields
    if(StringFind(json, "\"symbol\"") == -1)
    {
        Print("HttpClient: JSON missing symbol field");
        return false;
    }
    
    if(StringFind(json, "\"data\"") == -1)
    {
        Print("HttpClient: JSON missing data field");
        return false;
    }
    
    // Check for obvious formatting issues
    if(StringFind(json, ",,") != -1)
    {
        Print("HttpClient: JSON has double commas");
        return false;
    }
    
    if(StringFind(json, "[,") != -1 || StringFind(json, ",]") != -1)
    {
        Print("HttpClient: JSON has invalid comma placement");
        return false;
    }
    
    // NEW: Check for incomplete JSON (common issue)
    int openBraces = 0, closeBraces = 0;
    int openBrackets = 0, closeBrackets = 0;
    
    for(int i = 0; i < StringLen(json); i++)
    {
        ushort ch = StringGetCharacter(json, i);
        if(ch == '{') openBraces++;
        else if(ch == '}') closeBraces++;
        else if(ch == '[') openBrackets++;
        else if(ch == ']') closeBrackets++;
    }
    
    if(openBraces != closeBraces)
    {
        Print("HttpClient: JSON has unmatched braces. Open: ", openBraces, ", Close: ", closeBraces);
        return false;
    }
    
    if(openBrackets != closeBrackets)
    {
        Print("HttpClient: JSON has unmatched brackets. Open: ", openBrackets, ", Close: ", closeBrackets);
        return false;
    }
    
    Print("HttpClient: JSON validation passed");
    return true;
}

//+------------------------------------------------------------------+
//| ENHANCED: Prediction request with comprehensive error handling  |
//+------------------------------------------------------------------+
bool CHttpClient::SendPredictionRequest(string jsonData, string &response)
{
    Print("HttpClient: ===== SENDING PREDICTION REQUEST =====");
    
    // CRITICAL: Validate JSON before sending
    if(!ValidateJSONBeforeSending(jsonData))
    {
        Print("HttpClient: JSON validation failed before sending");
        return false;
    }
    
    string url = serverURL + "/predict";
    Print("HttpClient: Target URL: ", url);
    Print("HttpClient: JSON size: ", StringLen(jsonData), " characters");
    
    // Show more of the JSON for debugging
    Print("HttpClient: JSON start: ", StringSubstr(jsonData, 0, 200));
    Print("HttpClient: JSON end: ", StringSubstr(jsonData, StringLen(jsonData) - 200, 200));
    
    // Prepare headers with proper content type
    string headers = "";
    headers += "Content-Type: application/json\r\n";
    headers += "User-Agent: " + userAgent + "\r\n";
    headers += "Accept: application/json\r\n";
    headers += "Content-Length: " + IntegerToString(StringLen(jsonData)) + "\r\n";
    headers += "Connection: close\r\n";  // NEW: Ensure connection is closed after request
    
    Print("HttpClient: Request headers: ", headers);
    
    // Convert JSON to char array safely
    char postData[];
    SafeStringToCharArray(jsonData, postData);
    
    Print("HttpClient: Converted to ", ArraySize(postData), " bytes");
    
    char result[];
    string resultHeaders;
    
    Print("HttpClient: Making WebRequest to server...");
    
    // Clear last error before request
    ResetLastError();
    
    // Make the HTTP request
    int httpResult = WebRequest(
        "POST",           // method
        url,              // url
        headers,          // headers
        timeout,          // timeout
        postData,         // data
        result,           // result
        resultHeaders     // result headers
    );
    
    int lastError = GetLastError();
    Print("HttpClient: WebRequest completed with HTTP status: ", httpResult);
    Print("HttpClient: MT5 last error: ", lastError);
    
    if(httpResult != 200)
    { 
        // Get response body even for errors
        string errorResponse = "";
        if(ArraySize(result) > 0)
        {
            errorResponse = CharArrayToString(result);
        }
        
        LogServerError(httpResult, errorResponse, resultHeaders);
        
        // ENHANCED: Show server error details for 400 errors
        if(httpResult == 400 && StringLen(errorResponse) > 0)
        {
            Print("HttpClient: ===== SERVER REJECTION DETAILS =====");
            Print("HttpClient: The server rejected our request with detailed error:");
            Print("HttpClient: ", errorResponse);
            Print("HttpClient: ===== END REJECTION DETAILS =====");
        }
        
        // Specific handling for common errors
        if(lastError == 5203)
        {
            Print("HttpClient: ERROR 5203 - URL not allowed in WebRequest settings!");
            Print("HttpClient: SOLUTION: Add '", serverURL, "' to Tools -> Options -> Expert Advisors -> Allow WebRequest for listed URL");
        }
        
        return false; 
    }
    
    // Convert response
    response = CharArrayToString(result);
    Print("HttpClient: Response received successfully");
    Print("HttpClient: Response length: ", StringLen(response));
    Print("HttpClient: Response headers: ", resultHeaders);
    
    // Validate response JSON
    if(!IsValidJSON(response))
    { 
        Print("HttpClient: Received invalid JSON response");
        Print("HttpClient: Response content: ", StringSubstr(response, 0, 500)); 
        return false; 
    }
    
    Print("HttpClient: ===== REQUEST COMPLETED SUCCESSFULLY =====");
    return true;
}

bool CHttpClient::TestConnection()
{
    string url = serverURL + "/health";
    Print("HttpClient: Testing connection to ", url, "...");
    
    // Clear last error
    ResetLastError();
    
    // Prepare empty data for GET request
    char postData[];
    ArrayResize(postData, 0);
    
    char result[];
    string resultHeaders;
    
    int httpResult = WebRequest(
        "GET",            // method
        url,              // url
        "",               // headers (empty for GET)
        5000,             // 5 second timeout for health check
        postData,         // empty data
        result,           // result
        resultHeaders     // result headers
    );
    
    int lastError = GetLastError();
    
    if(httpResult != 200)
    { 
        Print("HttpClient: Connection test FAILED. HTTP Status: ", httpResult);
        Print("HttpClient: MT5 Error: ", lastError, " (", GetErrorDescription(lastError), ")");
        
        if(lastError == 5203)
        {
            Print("HttpClient: CRITICAL: URL not allowed in WebRequest settings!");
            Print("HttpClient: SOLUTION: Add '", serverURL, "' to Tools -> Options -> Expert Advisors -> Allow WebRequest for listed URL");
        }
        
        Print("HttpClient: Response Headers: ", resultHeaders);
        return false; 
    }
    
    string healthResponse = CharArrayToString(result);
    Print("HttpClient: Connection test PASSED");
    Print("HttpClient: Server response: ", healthResponse);
    return true;
}

//+------------------------------------------------------------------+
//| Enhanced JSON validation                                         |
//+------------------------------------------------------------------+
bool CHttpClient::IsValidJSON(string json)
{
    // Trim whitespace
    string trimmed = json; 
    StringTrimLeft(trimmed); 
    StringTrimRight(trimmed);
    
    // Basic length check
    if(StringLen(trimmed) < 2) 
        return false;
    
    // Must be object or array
    bool isObject = (StringGetCharacter(trimmed, 0) == '{' && 
                    StringGetCharacter(trimmed, StringLen(trimmed) - 1) == '}');
    bool isArray = (StringGetCharacter(trimmed, 0) == '[' && 
                   StringGetCharacter(trimmed, StringLen(trimmed) - 1) == ']');
    
    if(!isObject && !isArray)
        return false;
    
    return true;
}