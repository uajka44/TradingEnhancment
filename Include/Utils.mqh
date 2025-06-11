//+------------------------------------------------------------------+
//|                                                        Utils.mqh |
//|                                  Funkcje pomocnicze dla EA       |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property strict

//+------------------------------------------------------------------+
//| ENUMY I STAŁE                                                     |
//+------------------------------------------------------------------+
enum ENUM_HISTORY_SORT
{
   HISTORY_SORT_OPENTIME,   // Open time
   HISTORY_SORT_CLOSETIME   // Close time
};

enum ENUM_SOUND_TYPE
{
   SOUND_OK,
   SOUND_WARNING,
   SOUND_ERROR
};

// Stałe systemowe
#define MAX_RETRIES 3
#define SECONDS_IN_DAY 86400
#define MILLISECONDS_FOR_DOUBLE_CLICK 1000

//+------------------------------------------------------------------+
//| FUNKCJE KONWERSJI I FORMATOWANIA                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Konwertuje czas trwania na czytelny string                       |
//+------------------------------------------------------------------+
string TimeElapsedToString(const datetime pElapsedSeconds)
{
    const long days = pElapsedSeconds / PeriodSeconds(PERIOD_D1);
    return((days ? (string)days + "d " : "") + TimeToString(pElapsedSeconds, TIME_SECONDS));
}

//+------------------------------------------------------------------+
//| Konwertuje powód transakcji na string                            |
//+------------------------------------------------------------------+
string DealReasonToString(ENUM_DEAL_REASON deal_reason)
{
    switch(deal_reason)
    {
        case DEAL_REASON_CLIENT:   return ("client");
        case DEAL_REASON_MOBILE:   return ("mobile");
        case DEAL_REASON_WEB:      return ("web");
        case DEAL_REASON_EXPERT:   return ("expert");
        case DEAL_REASON_SL:       return ("sl");
        case DEAL_REASON_TP:       return ("tp");
        case DEAL_REASON_SO:       return ("so");
        case DEAL_REASON_ROLLOVER: return ("rollover");
        case DEAL_REASON_VMARGIN:  return ("vmargin");
        case DEAL_REASON_SPLIT:    return ("split");
        default:
            return ("unknown reason");
    }
}

//+------------------------------------------------------------------+
//| Konwertuje typ zlecenia na string                                |
//+------------------------------------------------------------------+
string OrderTypeToString(ENUM_ORDER_TYPE type)
{
    switch(type)
    {
        case ORDER_TYPE_BUY:             return "buy";
        case ORDER_TYPE_SELL:            return "sell";
        case ORDER_TYPE_BUY_LIMIT:       return "buy_limit";
        case ORDER_TYPE_SELL_LIMIT:      return "sell_limit";
        case ORDER_TYPE_BUY_STOP:        return "buy_stop";
        case ORDER_TYPE_SELL_STOP:       return "sell_stop";
        case ORDER_TYPE_BUY_STOP_LIMIT:  return "buy_stop_limit";
        case ORDER_TYPE_SELL_STOP_LIMIT: return "sell_stop_limit";
        default:                         return "unknown";
    }
}

//+------------------------------------------------------------------+
//| Konwertuje bool na string                                        |
//+------------------------------------------------------------------+
string BoolToString(bool value)
{
    return value ? "true" : "false";
}

//+------------------------------------------------------------------+
//| Formatuje double z określoną liczbą miejsc po przecinku          |
//+------------------------------------------------------------------+
string DoubleToStringFormatted(double value, int digits = 2)
{
    return DoubleToString(value, digits);
}

//+------------------------------------------------------------------+
//| FUNKCJE MATEMATYCZNE I OBLICZENIOWE                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Konwertuje punkty na cenę dla danego symbolu                     |
//+------------------------------------------------------------------+
double PointsToPrice(int points, string symbol = "")
{
    if(symbol == "") symbol = _Symbol;
    return points * SymbolInfoDouble(symbol, SYMBOL_POINT);
}

//+------------------------------------------------------------------+
//| Konwertuje różnicę cen na punkty dla danego symbolu             |
//+------------------------------------------------------------------+
int PriceToPoints(double price_diff, string symbol = "")
{
    if(symbol == "") symbol = _Symbol;
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    if(point == 0) return 0;
    return (int)MathRound(price_diff / point);
}

//+------------------------------------------------------------------+
//| Normalizuje volume zgodnie z wymaganiami symbolu                 |
//+------------------------------------------------------------------+
double NormalizeVolume(double volume, string symbol = "")
{
    if(symbol == "") symbol = _Symbol;
    
    double min_volume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double max_volume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double step_volume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    if(volume < min_volume) return min_volume;
    if(volume > max_volume) return max_volume;
    
    return MathRound(volume / step_volume) * step_volume;
}

//+------------------------------------------------------------------+
//| Sprawdza czy poziom stop jest poprawny                           |
//+------------------------------------------------------------------+
bool IsValidStopLevel(double entry_price, double stop_price, string symbol = "")
{
    if(symbol == "") symbol = _Symbol;
    
    double min_stop_level = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * 
                           SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    return MathAbs(entry_price - stop_price) >= min_stop_level;
}

//+------------------------------------------------------------------+
//| FUNKCJE WALIDACJI                                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Sprawdza czy rynek jest otwarty                                  |
//+------------------------------------------------------------------+
bool IsMarketOpen(string symbol = "")
{
    if(symbol == "") symbol = _Symbol;
    return SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_DISABLED;
}

//+------------------------------------------------------------------+
//| Sprawdza czy symbol jest poprawny                                |
//+------------------------------------------------------------------+
bool IsValidSymbol(string symbol)
{
    return SymbolSelect(symbol, true);
}

//+------------------------------------------------------------------+
//| Sprawdza czy to weekend                                          |
//+------------------------------------------------------------------+
bool IsWeekend()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    return (dt.day_of_week == 0 || dt.day_of_week == 6); // Niedziela = 0, Sobota = 6
}

//+------------------------------------------------------------------+
//| Sprawdza czy jest to czas sesji tradingowej                      |
//+------------------------------------------------------------------+
bool IsTradingSession(string symbol = "")
{
    if(symbol == "") symbol = _Symbol;
    
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    datetime session_from, session_to;
    if(!SymbolInfoSessionTrade(symbol, (ENUM_DAY_OF_WEEK)dt.day_of_week, 0, session_from, session_to))
        return false;
        
    datetime current_time = dt.hour * 3600 + dt.min * 60 + dt.sec;
    return (current_time >= session_from && current_time <= session_to);
}

//+------------------------------------------------------------------+
//| FUNKCJE POMOCNICZE DLA STRINGÓW                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Trim spacji z obu stron stringa                                  |
//+------------------------------------------------------------------+
string StringTrim(string text)
{
    StringTrimLeft(text);
    StringTrimRight(text);
    return text;
}

//+------------------------------------------------------------------+
//| Dzieli string i trim każdy element                               |
//+------------------------------------------------------------------+
void StringSplitAndTrim(string text, string delimiter, string &result[])
{
    string temp[];
    int count = StringSplit(text, StringGetCharacter(delimiter, 0), temp);
    ArrayResize(result, count);
    
    for(int i = 0; i < count; i++)
    {
        result[i] = StringTrim(temp[i]);
    }
}

//+------------------------------------------------------------------+
//| Sprawdza czy string zawiera podstring                            |
//+------------------------------------------------------------------+
bool StringContains(string text, string search)
{
    return StringFind(text, search) >= 0;
}

//+------------------------------------------------------------------+
//| FUNKCJE SYSTEMOWE                                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Bezpieczne odtwarzanie dźwięku                                   |
//+------------------------------------------------------------------+
void PlaySoundSafe(string filename)
{
    if(filename != "" && StringLen(filename) > 0)
    {
        PlaySound(filename);
    }
}

//+------------------------------------------------------------------+
//| Debug print z timestampem                                        |
//+------------------------------------------------------------------+
void PrintDebug(string message)
{
    Print("[", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), "] DEBUG: ", message);
}

//+------------------------------------------------------------------+
//| Log błędu z informacją o funkcji                                 |
//+------------------------------------------------------------------+
void LogError(string error, string function_name = "")
{
    string log_message = "[ERROR] " + error;
    if(function_name != "")
        log_message += " in function: " + function_name;
    
    Print("[", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), "] ", log_message);
}

//+------------------------------------------------------------------+
//| FUNKCJE POMOCNICZE DLA PLIKÓW                                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Sprawdza czy plik istnieje                                       |
//+------------------------------------------------------------------+
bool FileExists(string filename)
{
    int handle = FileOpen(filename, FILE_READ);
    if(handle != INVALID_HANDLE)
    {
        FileClose(handle);
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Odczytuje datetime z pliku CSV                                   |
//+------------------------------------------------------------------+
datetime ReadDateFromCSVSafe(string filename)
{
    datetime loadedValue = 0;
    
    if(!FileExists(filename))
    {
        LogError("File not found: " + filename, "ReadDateFromCSVSafe");
        return 0;
    }
    
    int fileHandle = FileOpen(filename, FILE_READ | FILE_CSV);
    
    if(fileHandle != INVALID_HANDLE)
    {
        loadedValue = FileReadDatetime(fileHandle);
        FileClose(fileHandle);
        //PrintDebug("Loaded date from CSV: " + TimeToString(loadedValue));
    }
    else
    {
        LogError("Cannot open file: " + filename + ", Error: " + IntegerToString(GetLastError()), "ReadDateFromCSVSafe");
    }
    
    return loadedValue;
}

//+------------------------------------------------------------------+
//| FUNKCJE POMOCNICZE DLA TABLICY                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Sprawdza czy element istnieje w tablicy                          |
//+------------------------------------------------------------------+
bool ArrayContains(int &array[], int value)
{
    for(int i = 0; i < ArraySize(array); i++)
    {
        if(array[i] == value)
            return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Dodaje element do tablicy jeśli go tam nie ma                    |
//+------------------------------------------------------------------+
bool ArrayAddUnique(int &array[], int value, int max_size = 10)
{
    if(ArrayContains(array, value))
        return false;
        
    int size = ArraySize(array);
    if(size >= max_size)
    {
        // Przesuwamy elementy (usuwamy najstarszy)
        for(int i = 0; i < size - 1; i++)
        {
            array[i] = array[i + 1];
        }
        array[size - 1] = value;
    }
    else
    {
        ArrayResize(array, size + 1);
        array[size] = value;
    }
    return true;
}
