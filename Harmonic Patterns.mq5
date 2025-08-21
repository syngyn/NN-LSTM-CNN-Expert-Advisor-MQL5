//+------------------------------------------------------------------+
//|                                              HarmonicPatterns.mqh |
//|                                  Copyright 2025, Your Company Ltd |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company Ltd"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//+------------------------------------------------------------------+
//| Harmonic Pattern Types                                           |
//+------------------------------------------------------------------+
enum ENUM_HARMONIC_PATTERN
{
   PATTERN_NONE,
   PATTERN_GARTLEY,
   PATTERN_BUTTERFLY,
   PATTERN_BAT,
   PATTERN_CRAB,
   PATTERN_CYPHER,
   PATTERN_SHARK
};

//+------------------------------------------------------------------+
//| Structure for pattern points                                     |
//+------------------------------------------------------------------+
struct SPatternPoint
{
   datetime time;
   double   price;
   int      bar_index;
   
   SPatternPoint() { time = 0; price = 0; bar_index = -1; }
   SPatternPoint(datetime t, double p, int idx) { time = t; price = p; bar_index = idx; }
};

//+------------------------------------------------------------------+
//| Structure for harmonic pattern                                   |
//+------------------------------------------------------------------+
struct SHarmonicPattern
{
   ENUM_HARMONIC_PATTERN pattern_type;
   SPatternPoint         X, A, B, C, D;
   bool                  is_bullish;
   bool                  is_confirmed;
   double                entry_price;
   double                stop_loss;
   double                take_profit1;
   double                take_profit2;
   string                pattern_name;
   long                  chart_id;
   
   SHarmonicPattern() 
   { 
      pattern_type = PATTERN_NONE; 
      is_bullish = false; 
      is_confirmed = false;
      entry_price = 0;
      stop_loss = 0;
      take_profit1 = 0;
      take_profit2 = 0;
      pattern_name = "";
      chart_id = 0;
   }
};

//+------------------------------------------------------------------+
//| Harmonic Pattern Recognition Class                               |
//+------------------------------------------------------------------+
class CHarmonicPatterns
{
private:
   CTrade            m_trade;
   CPositionInfo     m_position;
   COrderInfo        m_order;
   
   // Parameters
   int               m_lookback_bars;
   double            m_tolerance;
   double            m_lot_size;
   int               m_magic_number;
   double            m_risk_percent;
   bool              m_enable_drawing;
   
   // Pattern storage
   SHarmonicPattern  m_current_patterns[];
   int               m_max_patterns;
   
   // Fibonacci ratios for pattern validation
   double            m_fib_ratios[13];
   
public:
                     CHarmonicPatterns();
                    ~CHarmonicPatterns();
   
   // Initialization
   bool              Init(int lookback = 100, double tolerance = 0.05, 
                         double lot = 0.1, int magic = 12345, 
                         double risk = 2.0, bool draw = true);
   
   // Main functions
   void              ScanForPatterns();
   bool              IsNewPattern(const SHarmonicPattern &pattern);
   void              ExecuteTrade(const SHarmonicPattern &pattern);
   void              ManageTrades();
   
   // Pattern recognition
   bool              FindGartleyPattern(SHarmonicPattern &pattern, bool bullish);
   bool              FindButterflyPattern(SHarmonicPattern &pattern, bool bullish);
   bool              FindBatPattern(SHarmonicPattern &pattern, bool bullish);
   bool              FindCrabPattern(SHarmonicPattern &pattern, bool bullish);
   bool              FindCypherPattern(SHarmonicPattern &pattern, bool bullish);
   bool              FindSharkPattern(SHarmonicPattern &pattern, bool bullish);
   
   // Pattern validation
   bool              ValidateGartley(const SPatternPoint &X, const SPatternPoint &A, 
                                   const SPatternPoint &B, const SPatternPoint &C, 
                                   const SPatternPoint &D);
   bool              ValidateButterfly(const SPatternPoint &X, const SPatternPoint &A, 
                                     const SPatternPoint &B, const SPatternPoint &C, 
                                     const SPatternPoint &D);
   bool              ValidateBat(const SPatternPoint &X, const SPatternPoint &A, 
                               const SPatternPoint &B, const SPatternPoint &C, 
                               const SPatternPoint &D);
   bool              ValidateCrab(const SPatternPoint &X, const SPatternPoint &A, 
                                const SPatternPoint &B, const SPatternPoint &C, 
                                const SPatternPoint &D);
   
   // Utility functions
   SPatternPoint     FindSwingHigh(int start_bar, int end_bar);
   SPatternPoint     FindSwingLow(int start_bar, int end_bar);
   bool              IsSwingHigh(int bar_index, int lookback = 5);
   bool              IsSwingLow(int bar_index, int lookback = 5);
   double            CalculateFibRatio(double point1, double point2, double point3);
   bool              IsRatioValid(double ratio, double target, double tolerance);
   
   // Drawing functions
   void              DrawPattern(const SHarmonicPattern &pattern);
   void              DrawLine(const SPatternPoint &point1, const SPatternPoint &point2, 
                             color line_color, string name);
   void              DrawLabel(const SPatternPoint &point, string text, color text_color);
   void              CleanupDrawings();
   
   // Trade management
   double            CalculateStopLoss(const SHarmonicPattern &pattern);
   double            CalculateTakeProfit1(const SHarmonicPattern &pattern);
   double            CalculateTakeProfit2(const SHarmonicPattern &pattern);
   double            CalculateLotSize(double stop_loss_distance);
   void              UpdateTrailingStop();
   
   // Getters
   int               GetPatternsCount() { return ArraySize(m_current_patterns); }
   SHarmonicPattern  GetPattern(int index);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CHarmonicPatterns::CHarmonicPatterns()
{
   m_lookback_bars = 100;
   m_tolerance = 0.05;
   m_lot_size = 0.1;
   m_magic_number = 12345;
   m_risk_percent = 2.0;
   m_enable_drawing = true;
   m_max_patterns = 10;
   
   // Initialize Fibonacci ratios
   m_fib_ratios[0] = 0.236;
   m_fib_ratios[1] = 0.382;
   m_fib_ratios[2] = 0.500;
   m_fib_ratios[3] = 0.618;
   m_fib_ratios[4] = 0.764;
   m_fib_ratios[5] = 0.786;
   m_fib_ratios[6] = 0.886;
   m_fib_ratios[7] = 1.000;
   m_fib_ratios[8] = 1.272;
   m_fib_ratios[9] = 1.414;
   m_fib_ratios[10] = 1.618;
   m_fib_ratios[11] = 2.000;
   m_fib_ratios[12] = 2.618;
   
   ArrayResize(m_current_patterns, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CHarmonicPatterns::~CHarmonicPatterns()
{
   CleanupDrawings();
}

//+------------------------------------------------------------------+
//| Initialize the harmonic pattern system                           |
//+------------------------------------------------------------------+
bool CHarmonicPatterns::Init(int lookback = 100, double tolerance = 0.05, 
                           double lot = 0.1, int magic = 12345, 
                           double risk = 2.0, bool draw = true)
{
   m_lookback_bars = lookback;
   m_tolerance = tolerance;
   m_lot_size = lot;
   m_magic_number = magic;
   m_risk_percent = risk;
   m_enable_drawing = draw;
   
   m_trade.SetExpertMagicNumber(m_magic_number);
   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(Symbol());
   
   return true;
}

//+------------------------------------------------------------------+
//| Main function to scan for patterns                               |
//+------------------------------------------------------------------+
void CHarmonicPatterns::ScanForPatterns()
{
   SHarmonicPattern pattern;
   
   // Scan for bullish patterns
   if(FindGartleyPattern(pattern, true) && IsNewPattern(pattern))
   {
      pattern.pattern_type = PATTERN_GARTLEY;
      pattern.pattern_name = "Bullish Gartley";
      pattern.is_bullish = true;
      
      if(m_enable_drawing)
         DrawPattern(pattern);
      
      int size = ArraySize(m_current_patterns);
      ArrayResize(m_current_patterns, size + 1);
      m_current_patterns[size] = pattern;
      
      ExecuteTrade(pattern);
   }
   
   if(FindButterflyPattern(pattern, true) && IsNewPattern(pattern))
   {
      pattern.pattern_type = PATTERN_BUTTERFLY;
      pattern.pattern_name = "Bullish Butterfly";
      pattern.is_bullish = true;
      
      if(m_enable_drawing)
         DrawPattern(pattern);
      
      int size = ArraySize(m_current_patterns);
      ArrayResize(m_current_patterns, size + 1);
      m_current_patterns[size] = pattern;
      
      ExecuteTrade(pattern);
   }
   
   if(FindBatPattern(pattern, true) && IsNewPattern(pattern))
   {
      pattern.pattern_type = PATTERN_BAT;
      pattern.pattern_name = "Bullish Bat";
      pattern.is_bullish = true;
      
      if(m_enable_drawing)
         DrawPattern(pattern);
      
      int size = ArraySize(m_current_patterns);
      ArrayResize(m_current_patterns, size + 1);
      m_current_patterns[size] = pattern;
      
      ExecuteTrade(pattern);
   }
   
   if(FindCrabPattern(pattern, true) && IsNewPattern(pattern))
   {
      pattern.pattern_type = PATTERN_CRAB;
      pattern.pattern_name = "Bullish Crab";
      pattern.is_bullish = true;
      
      if(m_enable_drawing)
         DrawPattern(pattern);
      
      int size = ArraySize(m_current_patterns);
      ArrayResize(m_current_patterns, size + 1);
      m_current_patterns[size] = pattern;
      
      ExecuteTrade(pattern);
   }
   
   // Scan for bearish patterns
   if(FindGartleyPattern(pattern, false) && IsNewPattern(pattern))
   {
      pattern.pattern_type = PATTERN_GARTLEY;
      pattern.pattern_name = "Bearish Gartley";
      pattern.is_bullish = false;
      
      if(m_enable_drawing)
         DrawPattern(pattern);
      
      int size = ArraySize(m_current_patterns);
      ArrayResize(m_current_patterns, size + 1);
      m_current_patterns[size] = pattern;
      
      ExecuteTrade(pattern);
   }
   
   if(FindButterflyPattern(pattern, false) && IsNewPattern(pattern))
   {
      pattern.pattern_type = PATTERN_BUTTERFLY;
      pattern.pattern_name = "Bearish Butterfly";
      pattern.is_bullish = false;
      
      if(m_enable_drawing)
         DrawPattern(pattern);
      
      int size = ArraySize(m_current_patterns);
      ArrayResize(m_current_patterns, size + 1);
      m_current_patterns[size] = pattern;
      
      ExecuteTrade(pattern);
   }
   
   if(FindBatPattern(pattern, false) && IsNewPattern(pattern))
   {
      pattern.pattern_type = PATTERN_BAT;
      pattern.pattern_name = "Bearish Bat";
      pattern.is_bullish = false;
      
      if(m_enable_drawing)
         DrawPattern(pattern);
      
      int size = ArraySize(m_current_patterns);
      ArrayResize(m_current_patterns, size + 1);
      m_current_patterns[size] = pattern;
      
      ExecuteTrade(pattern);
   }
   
   if(FindCrabPattern(pattern, false) && IsNewPattern(pattern))
   {
      pattern.pattern_type = PATTERN_CRAB;
      pattern.pattern_name = "Bearish Crab";
      pattern.is_bullish = false;
      
      if(m_enable_drawing)
         DrawPattern(pattern);
      
      int size = ArraySize(m_current_patterns);
      ArrayResize(m_current_patterns, size + 1);
      m_current_patterns[size] = pattern;
      
      ExecuteTrade(pattern);
   }
   
   // Manage existing trades
   ManageTrades();
}

//+------------------------------------------------------------------+
//| Find Gartley Pattern                                             |
//+------------------------------------------------------------------+
bool CHarmonicPatterns::FindGartleyPattern(SHarmonicPattern &pattern, bool bullish)
{
   for(int i = m_lookback_bars; i >= 50; i--)
   {
      if(bullish)
      {
         // Look for swing points in bullish Gartley sequence
         SPatternPoint X = FindSwingLow(i + 40, i + 20);
         if(X.bar_index == -1) continue;
         
         SPatternPoint A = FindSwingHigh(X.bar_index - 20, X.bar_index - 5);
         if(A.bar_index == -1) continue;
         
         SPatternPoint B = FindSwingLow(A.bar_index - 20, A.bar_index - 5);
         if(B.bar_index == -1) continue;
         
         SPatternPoint C = FindSwingHigh(B.bar_index - 20, B.bar_index - 5);
         if(C.bar_index == -1) continue;
         
         SPatternPoint D = FindSwingLow(C.bar_index - 15, C.bar_index - 1);
         if(D.bar_index == -1) continue;
         
         // Validate Gartley ratios
         if(ValidateGartley(X, A, B, C, D))
         {
            pattern.X = X;
            pattern.A = A;
            pattern.B = B;
            pattern.C = C;
            pattern.D = D;
            pattern.is_bullish = true;
            pattern.is_confirmed = true;
            
            // Calculate trade levels
            pattern.entry_price = D.price;
            pattern.stop_loss = CalculateStopLoss(pattern);
            pattern.take_profit1 = CalculateTakeProfit1(pattern);
            pattern.take_profit2 = CalculateTakeProfit2(pattern);
            
            return true;
         }
      }
      else
      {
         // Look for swing points in bearish Gartley sequence
         SPatternPoint X = FindSwingHigh(i + 40, i + 20);
         if(X.bar_index == -1) continue;
         
         SPatternPoint A = FindSwingLow(X.bar_index - 20, X.bar_index - 5);
         if(A.bar_index == -1) continue;
         
         SPatternPoint B = FindSwingHigh(A.bar_index - 20, A.bar_index - 5);
         if(B.bar_index == -1) continue;
         
         SPatternPoint C = FindSwingLow(B.bar_index - 20, B.bar_index - 5);
         if(C.bar_index == -1) continue;
         
         SPatternPoint D = FindSwingHigh(C.bar_index - 15, C.bar_index - 1);
         if(D.bar_index == -1) continue;
         
         // Validate Gartley ratios
         if(ValidateGartley(X, A, B, C, D))
         {
            pattern.X = X;
            pattern.A = A;
            pattern.B = B;
            pattern.C = C;
            pattern.D = D;
            pattern.is_bullish = false;
            pattern.is_confirmed = true;
            
            // Calculate trade levels
            pattern.entry_price = D.price;
            pattern.stop_loss = CalculateStopLoss(pattern);
            pattern.take_profit1 = CalculateTakeProfit1(pattern);
            pattern.take_profit2 = CalculateTakeProfit2(pattern);
            
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Find Butterfly Pattern                                           |
//+------------------------------------------------------------------+
bool CHarmonicPatterns::FindButterflyPattern(SHarmonicPattern &pattern, bool bullish)
{
   for(int i = m_lookback_bars; i >= 50; i--)
   {
      if(bullish)
      {
         SPatternPoint X = FindSwingLow(i + 40, i + 20);
         if(X.bar_index == -1) continue;
         
         SPatternPoint A = FindSwingHigh(X.bar_index - 20, X.bar_index - 5);
         if(A.bar_index == -1) continue;
         
         SPatternPoint B = FindSwingLow(A.bar_index - 20, A.bar_index - 5);
         if(B.bar_index == -1) continue;
         
         SPatternPoint C = FindSwingHigh(B.bar_index - 20, B.bar_index - 5);
         if(C.bar_index == -1) continue;
         
         SPatternPoint D = FindSwingLow(C.bar_index - 15, C.bar_index - 1);
         if(D.bar_index == -1) continue;
         
         if(ValidateButterfly(X, A, B, C, D))
         {
            pattern.X = X;
            pattern.A = A;
            pattern.B = B;
            pattern.C = C;
            pattern.D = D;
            pattern.is_bullish = true;
            pattern.is_confirmed = true;
            
            pattern.entry_price = D.price;
            pattern.stop_loss = CalculateStopLoss(pattern);
            pattern.take_profit1 = CalculateTakeProfit1(pattern);
            pattern.take_profit2 = CalculateTakeProfit2(pattern);
            
            return true;
         }
      }
      else
      {
         SPatternPoint X = FindSwingHigh(i + 40, i + 20);
         if(X.bar_index == -1) continue;
         
         SPatternPoint A = FindSwingLow(X.bar_index - 20, X.bar_index - 5);
         if(A.bar_index == -1) continue;
         
         SPatternPoint B = FindSwingHigh(A.bar_index - 20, A.bar_index - 5);
         if(B.bar_index == -1) continue;
         
         SPatternPoint C = FindSwingLow(B.bar_index - 20, B.bar_index - 5);
         if(C.bar_index == -1) continue;
         
         SPatternPoint D = FindSwingHigh(C.bar_index - 15, C.bar_index - 1);
         if(D.bar_index == -1) continue;
         
         if(ValidateButterfly(X, A, B, C, D))
         {
            pattern.X = X;
            pattern.A = A;
            pattern.B = B;
            pattern.C = C;
            pattern.D = D;
            pattern.is_bullish = false;
            pattern.is_confirmed = true;
            
            pattern.entry_price = D.price;
            pattern.stop_loss = CalculateStopLoss(pattern);
            pattern.take_profit1 = CalculateTakeProfit1(pattern);
            pattern.take_profit2 = CalculateTakeProfit2(pattern);
            
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Find Bat Pattern                                                 |
//+------------------------------------------------------------------+
bool CHarmonicPatterns::FindBatPattern(SHarmonicPattern &pattern, bool bullish)
{
   for(int i = m_lookback_bars; i >= 50; i--)
   {
      if(bullish)
      {
         SPatternPoint X = FindSwingLow(i + 40, i + 20);
         if(X.bar_index == -1) continue;
         
         SPatternPoint A = FindSwingHigh(X.bar_index - 20, X.bar_index - 5);
         if(A.bar_index == -1) continue;
         
         SPatternPoint B = FindSwingLow(A.bar_index - 20, A.bar_index - 5);
         if(B.bar_index == -1) continue;
         
         SPatternPoint C = FindSwingHigh(B.bar_index - 20, B.bar_index - 5);
         if(C.bar_index == -1) continue;
         
         SPatternPoint D = FindSwingLow(C.bar_index - 15, C.bar_index - 1);
         if(D.bar_index == -1) continue;
         
         if(ValidateBat(X, A, B, C, D))
         {
            pattern.X = X;
            pattern.A = A;
            pattern.B = B;
            pattern.C = C;
            pattern.D = D;
            pattern.is_bullish = true;
            pattern.is_confirmed = true;
            
            pattern.entry_price = D.price;
            pattern.stop_loss = CalculateStopLoss(pattern);
            pattern.take_profit1 = CalculateTakeProfit1(pattern);
            pattern.take_profit2 = CalculateTakeProfit2(pattern);
            
            return true;
         }
      }
      else
      {
         SPatternPoint X = FindSwingHigh(i + 40, i + 20);
         if(X.bar_index == -1) continue;
         
         SPatternPoint A = FindSwingLow(X.bar_index - 20, X.bar_index - 5);
         if(A.bar_index == -1) continue;
         
         SPatternPoint B = FindSwingHigh(A.bar_index - 20, A.bar_index - 5);
         if(B.bar_index == -1) continue;
         
         SPatternPoint C = FindSwingLow(B.bar_index - 20, B.bar_index - 5);
         if(C.bar_index == -1) continue;
         
         SPatternPoint D = FindSwingHigh(C.bar_index - 15, C.bar_index - 1);
         if(D.bar_index == -1) continue;
         
         if(ValidateBat(X, A, B, C, D))
         {
            pattern.X = X;
            pattern.A = A;
            pattern.B = B;
            pattern.C = C;
            pattern.D = D;
            pattern.is_bullish = false;
            pattern.is_confirmed = true;
            
            pattern.entry_price = D.price;
            pattern.stop_loss = CalculateStopLoss(pattern);
            pattern.take_profit1 = CalculateTakeProfit1(pattern);
            pattern.take_profit2 = CalculateTakeProfit2(pattern);
            
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Find Crab Pattern                                                |
//+------------------------------------------------------------------+
bool CHarmonicPatterns::FindCrabPattern(SHarmonicPattern &pattern, bool bullish)
{
   for(int i = m_lookback_bars; i >= 50; i--)
   {
      if(bullish)
      {
         SPatternPoint X = FindSwingLow(i + 40, i + 20);
         if(X.bar_index == -1) continue;
         
         SPatternPoint A = FindSwingHigh(X.bar_index - 20, X.bar_index - 5);
         if(A.bar_index == -1) continue;
         
         SPatternPoint B = FindSwingLow(A.bar_index - 20, A.bar_index - 5);
         if(B.bar_index == -1) continue;
         
         SPatternPoint C = FindSwingHigh(B.bar_index - 20, B.bar_index - 5);
         if(C.bar_index == -1) continue;
         
         SPatternPoint D = FindSwingLow(C.bar_index - 15, C.bar_index - 1);
         if(D.bar_index == -1) continue;
         
         if(ValidateCrab(X, A, B, C, D))
         {
            pattern.X = X;
            pattern.A = A;
            pattern.B = B;
            pattern.C = C;
            pattern.D = D;
            pattern.is_bullish = true;
            pattern.is_confirmed = true;
            
            pattern.entry_price = D.price;
            pattern.stop_loss = CalculateStopLoss(pattern);
            pattern.take_profit1 = CalculateTakeProfit1(pattern);
            pattern.take_profit2 = CalculateTakeProfit2(pattern);
            
            return true;
         }
      }
      else
      {
         SPatternPoint X = FindSwingHigh(i + 40, i + 20);
         if(X.bar_index == -1) continue;
         
         SPatternPoint A = FindSwingLow(X.bar_index - 20, X.bar_index - 5);
         if(A.bar_index == -1) continue;
         
         SPatternPoint B = FindSwingHigh(A.bar_index - 20, A.bar_index - 5);
         if(B.bar_index == -1) continue;
         
         SPatternPoint C = FindSwingLow(B.bar_index - 20, B.bar_index - 5);
         if(C.bar_index == -1) continue;
         
         SPatternPoint D = FindSwingHigh(C.bar_index - 15, C.bar_index - 1);
         if(D.bar_index == -1) continue;
         
         if(ValidateCrab(X, A, B, C, D))
         {
            pattern.X = X;
            pattern.A = A;
            pattern.B = B;
            pattern.C = C;
            pattern.D = D;
            pattern.is_bullish = false;
            pattern.is_confirmed = true;
            
            pattern.entry_price = D.price;
            pattern.stop_loss = CalculateStopLoss(pattern);
            pattern.take_profit1 = CalculateTakeProfit1(pattern);
            pattern.take_profit2 = CalculateTakeProfit2(pattern);
            
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Validate Gartley Pattern Ratios                                  |
//+------------------------------------------------------------------+
bool CHarmonicPatterns::ValidateGartley(const SPatternPoint &X, const SPatternPoint &A, 
                                       const SPatternPoint &B, const SPatternPoint &C, 
                                       const SPatternPoint &D)
{
   double AB_XA = CalculateFibRatio(X.price, A.price, B.price);
   double BC_AB = CalculateFibRatio(A.price, B.price, C.price);
   double CD_BC = CalculateFibRatio(B.price, C.price, D.price);
   double AD_XA = CalculateFibRatio(X.price, A.price, D.price);
   
   // Gartley pattern validation
   // AB = 0.618 of XA
   // BC = 0.382 or 0.886 of AB  
   // CD = 1.272 or 1.618 of BC
   // AD = 0.786 of XA
   
   if(!IsRatioValid(AB_XA, 0.618, m_tolerance)) return false;
   if(!IsRatioValid(BC_AB, 0.382, m_tolerance) && !IsRatioValid(BC_AB, 0.886, m_tolerance)) return false;
   if(!IsRatioValid(CD_BC, 1.272, m_tolerance) && !IsRatioValid(CD_BC, 1.618, m_tolerance)) return false;
   if(!IsRatioValid(AD_XA, 0.786, m_tolerance)) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Validate Butterfly Pattern Ratios                                |
//+------------------------------------------------------------------+
bool CHarmonicPatterns::ValidateButterfly(const SPatternPoint &X, const SPatternPoint &A, 
                                         const SPatternPoint &B, const SPatternPoint &C, 
                                         const SPatternPoint &D)
{
   double AB_XA = CalculateFibRatio(X.price, A.price, B.price);
   double BC_AB = CalculateFibRatio(A.price, B.price, C.price);
   double CD_BC = CalculateFibRatio(B.price, C.price, D.price);
   double AD_XA = CalculateFibRatio(X.price, A.price, D.price);
   
   // Butterfly pattern validation
   // AB = 0.786 of XA
   // BC = 0.382 or 0.886 of AB
   // CD = 1.618 or 2.618 of BC  
   // AD = 1.272 or 1.618 of XA
   
   if(!IsRatioValid(AB_XA, 0.786, m_tolerance)) return false;
   if(!IsRatioValid(BC_AB, 0.382, m_tolerance) && !IsRatioValid(BC_AB, 0.886, m_tolerance)) return false;
   if(!IsRatioValid(CD_BC, 1.618, m_tolerance) && !IsRatioValid(CD_BC, 2.618, m_tolerance)) return false;
   if(!IsRatioValid(AD_XA, 1.272, m_tolerance) && !IsRatioValid(AD_XA, 1.618, m_tolerance)) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Validate Bat Pattern Ratios                                      |
//+------------------------------------------------------------------+
bool CHarmonicPatterns::ValidateBat(const SPatternPoint &X, const SPatternPoint &A, 
                                   const SPatternPoint &B, const SPatternPoint &C, 
                                   const SPatternPoint &D)
{
   double AB_XA = CalculateFibRatio(X.price, A.price, B.price);
   double BC_AB = CalculateFibRatio(A.price, B.price, C.price);
   double CD_BC = CalculateFibRatio(B.price, C.price, D.price);
   double AD_XA = CalculateFibRatio(X.price, A.price, D.price);
   
   // Bat pattern validation
   // AB = 0.382 or 0.500 of XA
   // BC = 0.382 or 0.886 of AB
   // CD = 1.618 or 2.618 of BC
   // AD = 0.886 of XA
   
   if(!IsRatioValid(AB_XA, 0.382, m_tolerance) && !IsRatioValid(AB_XA, 0.500, m_tolerance)) return false;
   if(!IsRatioValid(BC_AB, 0.382, m_tolerance) && !IsRatioValid(BC_AB, 0.886, m_tolerance)) return false;
   if(!IsRatioValid(CD_BC, 1.618, m_tolerance) && !IsRatioValid(CD_BC, 2.618, m_tolerance)) return false;
   if(!IsRatioValid(AD_XA, 0.886, m_tolerance)) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Validate Crab Pattern Ratios                                     |
//+------------------------------------------------------------------+
bool CHarmonicPatterns::ValidateCrab(const SPatternPoint &X, const SPatternPoint &A, 
                                    const SPatternPoint &B, const SPatternPoint &C, 
                                    const SPatternPoint &D)
{
   double AB_XA = CalculateFibRatio(X.price, A.price, B.price);
   double BC_AB = CalculateFibRatio(A.price, B.price, C.price);
   double CD_BC = CalculateFibRatio(B.price, C.price, D.price);
   double AD_XA = CalculateFibRatio(X.price, A.price, D.price);
   
   // Crab pattern validation
   // AB = 0.382 or 0.618 of XA
   // BC = 0.382 or 0.886 of AB
   // CD = 2.24 or 3.618 of BC
   // AD = 1.618 of XA
   
   if(!IsRatioValid(AB_XA, 0.382, m_tolerance) && !IsRatioValid(AB_XA, 0.618, m_tolerance)) return false;
   if(!IsRatioValid(BC_AB, 0.382, m_tolerance) && !IsRatioValid(BC_AB, 0.886, m_tolerance)) return false;
   if(!IsRatioValid(CD_BC, 2.24, m_tolerance) && !IsRatioValid(CD_BC, 3.618, m_tolerance)) return false;
   if(!IsRatioValid(AD_XA, 1.618, m_tolerance)) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Find swing high in given range                                   |
//+------------------------------------------------------------------+
SPatternPoint CHarmonicPatterns::FindSwingHigh(int start_bar, int end_bar)
{
   SPatternPoint point;
   double highest = 0;
   int highest_index = -1;
   
   for(int i = start_bar; i >= end_bar && i >= 0; i--)
   {
      if(IsSwingHigh(i))
      {
         double high_price = iHigh(Symbol(), PERIOD_CURRENT, i);
         if(highest_index == -1 || high_price > highest)
         {
            highest = high_price;
            highest_index = i;
         }
      }
   }
   
   if(highest_index != -1)
   {
      point.price = highest;
      point.bar_index = highest_index;
      point.time = iTime(Symbol(), PERIOD_CURRENT, highest_index);
   }
   
   return point;
}

//+------------------------------------------------------------------+
//| Find swing low in given range                                    |
//+------------------------------------------------------------------+
SPatternPoint CHarmonicPatterns::FindSwingLow(int start_bar, int end_bar)
{
   SPatternPoint point;
   double lowest = 0;
   int lowest_index = -1;
   
   for(int i = start_bar; i >= end_bar && i >= 0; i--)
   {
      if(IsSwingLow(i))
      {
         double low_price = iLow(Symbol(), PERIOD_CURRENT, i);
         if(lowest_index == -1 || low_price < lowest)
         {
            lowest = low_price;
            lowest_index = i;
         }
      }
   }
   
   if(lowest_index != -1)
   {
      point.price = lowest;
      point.bar_index = lowest_index;
      point.time = iTime(Symbol(), PERIOD_CURRENT, lowest_index);
   }
   
   return point;
}

//+------------------------------------------------------------------+
//| Check if bar is swing high                                       |
//+------------------------------------------------------------------+
bool CHarmonicPatterns::IsSwingHigh(int bar_index, int lookback = 5)
{
   if(bar_index < lookback || bar_index >= Bars(Symbol(), PERIOD_CURRENT) - lookback)
      return false;
   
   double center_high = iHigh(Symbol(), PERIOD_CURRENT, bar_index);
   
   for(int i = 1; i <= lookback; i++)
   {
      if(iHigh(Symbol(), PERIOD_CURRENT, bar_index - i) >= center_high ||
         iHigh(Symbol(), PERIOD_CURRENT, bar_index + i) >= center_high)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if bar is swing low                                        |
//+------------------------------------------------------------------+
bool CHarmonicPatterns::IsSwingLow(int bar_index, int lookback = 5)
{
   if(bar_index < lookback || bar_index >= Bars(Symbol(), PERIOD_CURRENT) - lookback)
      return false;
   
   double center_low = iLow(Symbol(), PERIOD_CURRENT, bar_index);
   
   for(int i = 1; i <= lookback; i++)
   {
      if(iLow(Symbol(), PERIOD_CURRENT, bar_index - i) <= center_low ||
         iLow(Symbol(), PERIOD_CURRENT, bar_index + i) <= center_low)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate Fibonacci ratio                                        |
//+------------------------------------------------------------------+
double CHarmonicPatterns::CalculateFibRatio(double point1, double point2, double point3)
{
   double range = MathAbs(point2 - point1);
   double retracement = MathAbs(point3 - point2);
   
   if(range == 0) return 0;
   
   return retracement / range;
}

//+------------------------------------------------------------------+
//| Check if ratio is valid within tolerance                         |
//+------------------------------------------------------------------+
bool CHarmonicPatterns::IsRatioValid(double ratio, double target, double tolerance)
{
   return (ratio >= target - tolerance && ratio <= target + tolerance);
}

//+------------------------------------------------------------------+
//| Check if pattern is new                                          |
//+------------------------------------------------------------------+
bool CHarmonicPatterns::IsNewPattern(const SHarmonicPattern &pattern)
{
   for(int i = 0; i < ArraySize(m_current_patterns); i++)
   {
      if(MathAbs(m_current_patterns[i].D.time - pattern.D.time) < 300 &&
         MathAbs(m_current_patterns[i].D.price - pattern.D.price) < Point() * 10)
         return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Execute trade based on pattern                                   |
//+------------------------------------------------------------------+
void CHarmonicPatterns::ExecuteTrade(const SHarmonicPattern &pattern)
{
   double lot_size = CalculateLotSize(MathAbs(pattern.entry_price - pattern.stop_loss));
   
   if(pattern.is_bullish)
   {
      m_trade.Buy(lot_size, Symbol(), pattern.entry_price, 
                  pattern.stop_loss, pattern.take_profit1, 
                  "Harmonic " + pattern.pattern_name);
   }
   else
   {
      m_trade.Sell(lot_size, Symbol(), pattern.entry_price, 
                   pattern.stop_loss, pattern.take_profit1, 
                   "Harmonic " + pattern.pattern_name);
   }
   
   Print("Trade executed for ", pattern.pattern_name, " at ", pattern.entry_price);
}

//+------------------------------------------------------------------+
//| Calculate stop loss                                              |
//+------------------------------------------------------------------+
double CHarmonicPatterns::CalculateStopLoss(const SHarmonicPattern &pattern)
{
   if(pattern.is_bullish)
   {
      return pattern.D.price - (pattern.A.price - pattern.D.price) * 0.236;
   }
   else
   {
      return pattern.D.price + (pattern.D.price - pattern.A.price) * 0.236;
   }
}

//+------------------------------------------------------------------+
//| Calculate first take profit                                      |
//+------------------------------------------------------------------+
double CHarmonicPatterns::CalculateTakeProfit1(const SHarmonicPattern &pattern)
{
   if(pattern.is_bullish)
   {
      return pattern.D.price + (pattern.A.price - pattern.D.price) * 0.382;
   }
   else
   {
      return pattern.D.price - (pattern.D.price - pattern.A.price) * 0.382;
   }
}

//+------------------------------------------------------------------+
//| Calculate second take profit                                     |
//+------------------------------------------------------------------+
double CHarmonicPatterns::CalculateTakeProfit2(const SHarmonicPattern &pattern)
{
   if(pattern.is_bullish)
   {
      return pattern.D.price + (pattern.A.price - pattern.D.price) * 0.618;
   }
   else
   {
      return pattern.D.price - (pattern.D.price - pattern.A.price) * 0.618;
   }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                                 |
//+------------------------------------------------------------------+
double CHarmonicPatterns::CalculateLotSize(double stop_loss_distance)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount = balance * m_risk_percent / 100;
   double tick_value = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   
   if(tick_size == 0 || tick_value == 0) return m_lot_size;
   
   double lot_size = risk_amount / (stop_loss_distance / tick_size * tick_value);
   
   double min_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   
   lot_size = MathMax(min_lot, MathMin(max_lot, lot_size));
   
   return NormalizeDouble(lot_size, 2);
}

//+------------------------------------------------------------------+
//| Manage existing trades                                           |
//+------------------------------------------------------------------+
void CHarmonicPatterns::ManageTrades()
{
   UpdateTrailingStop();
   
   // Clean up old patterns
   int new_size = 0;
   for(int i = 0; i < ArraySize(m_current_patterns); i++)
   {
      if(TimeCurrent() - m_current_patterns[i].D.time < 3600 * 24) // Keep patterns for 24 hours
      {
         if(new_size != i)
            m_current_patterns[new_size] = m_current_patterns[i];
         new_size++;
      }
   }
   ArrayResize(m_current_patterns, new_size);
}

//+------------------------------------------------------------------+
//| Update trailing stop                                             |
//+------------------------------------------------------------------+
void CHarmonicPatterns::UpdateTrailingStop()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == Symbol() && m_position.Magic() == m_magic_number)
         {
            double current_price = m_position.Type() == POSITION_TYPE_BUY ? 
                                 SymbolInfoDouble(Symbol(), SYMBOL_BID) : 
                                 SymbolInfoDouble(Symbol(), SYMBOL_ASK);
            
            double new_sl = 0;
            
            if(m_position.Type() == POSITION_TYPE_BUY)
            {
               new_sl = current_price - (m_position.PriceOpen() - m_position.StopLoss());
               if(new_sl > m_position.StopLoss() + Point() * 10)
               {
                  m_trade.PositionModify(m_position.Ticket(), new_sl, m_position.TakeProfit());
               }
            }
            else
            {
               new_sl = current_price + (m_position.StopLoss() - m_position.PriceOpen());
               if(new_sl < m_position.StopLoss() - Point() * 10)
               {
                  m_trade.PositionModify(m_position.Ticket(), new_sl, m_position.TakeProfit());
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Draw pattern on chart                                            |
//+------------------------------------------------------------------+
void CHarmonicPatterns::DrawPattern(const SHarmonicPattern &pattern)
{
   string pattern_id = pattern.pattern_name + "_" + TimeToString(pattern.D.time);
   color line_color = pattern.is_bullish ? clrBlue : clrRed;
   
   // Draw pattern lines
   DrawLine(pattern.X, pattern.A, line_color, pattern_id + "_XA");
   DrawLine(pattern.A, pattern.B, line_color, pattern_id + "_AB");
   DrawLine(pattern.B, pattern.C, line_color, pattern_id + "_BC");
   DrawLine(pattern.C, pattern.D, line_color, pattern_id + "_CD");
   DrawLine(pattern.X, pattern.B, line_color, pattern_id + "_XB");
   DrawLine(pattern.A, pattern.C, line_color, pattern_id + "_AC");
   DrawLine(pattern.X, pattern.D, line_color, pattern_id + "_XD");
   
   // Draw labels
   DrawLabel(pattern.X, "X", line_color);
   DrawLabel(pattern.A, "A", line_color);
   DrawLabel(pattern.B, "B", line_color);
   DrawLabel(pattern.C, "C", line_color);
   DrawLabel(pattern.D, "D", line_color);
   
   // Draw pattern name
   ObjectCreate(0, pattern_id + "_Label", OBJ_TEXT, 0, 
                pattern.D.time, pattern.D.price);
   ObjectSetString(0, pattern_id + "_Label", OBJPROP_TEXT, pattern.pattern_name);
   ObjectSetInteger(0, pattern_id + "_Label", OBJPROP_COLOR, line_color);
   ObjectSetInteger(0, pattern_id + "_Label", OBJPROP_FONTSIZE, 10);
}

//+------------------------------------------------------------------+
//| Draw line between two points                                     |
//+------------------------------------------------------------------+
void CHarmonicPatterns::DrawLine(const SPatternPoint &point1, const SPatternPoint &point2, 
                                color line_color, string name)
{
   ObjectCreate(0, name, OBJ_TREND, 0, point1.time, point1.price, point2.time, point2.price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
}

//+------------------------------------------------------------------+
//| Draw label at point                                              |
//+------------------------------------------------------------------+
void CHarmonicPatterns::DrawLabel(const SPatternPoint &point, string text, color text_color)
{
   string name = "Label_" + text + "_" + TimeToString(point.time);
   ObjectCreate(0, name, OBJ_TEXT, 0, point.time, point.price);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, text_color);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 12);
}

//+------------------------------------------------------------------+
//| Clean up all drawings                                            |
//+------------------------------------------------------------------+
void CHarmonicPatterns::CleanupDrawings()
{
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, "Harmonic") >= 0 || 
         StringFind(name, "Gartley") >= 0 ||
         StringFind(name, "Butterfly") >= 0 ||
         StringFind(name, "Bat") >= 0 ||
         StringFind(name, "Crab") >= 0)
      {
         ObjectDelete(0, name);
      }
   }
}

//+------------------------------------------------------------------+
//| Get pattern by index                                             |
//+------------------------------------------------------------------+
SHarmonicPattern CHarmonicPatterns::GetPattern(int index)
{
   SHarmonicPattern empty_pattern;
   if(index >= 0 && index < ArraySize(m_current_patterns))
      return m_current_patterns[index];
   return empty_pattern;
}