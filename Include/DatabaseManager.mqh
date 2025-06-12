//+------------------------------------------------------------------+
//|                                           DatabaseManager.mqh     |
//|                            Zarządzanie bazą danych SQLite (NATIVE)|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property strict

#include <Generic\HashSet.mqh>
#include <Trade\DealInfo.mqh>
// USUNIĘTE STARE BIBLIOTEKI SQLite3 - używamy natywnego SQLite MT5
// #include <SQLite3/SQLite3.mqh>
// #include <SQLite3/Statement.mqh>
#include "Utils.mqh"
#include "ConfigManager.mqh"

//+------------------------------------------------------------------+
//| KLASA DatabaseManager - Zarządzanie bazą danych (NATIVE SQLite) |
//+------------------------------------------------------------------+
class CDatabaseManager
{
private:
    int m_db_handle;
    bool m_initialized;
    bool m_database_ready;
    string m_db_path;
    
public:
    CDatabaseManager() : m_db_handle(INVALID_HANDLE), m_initialized(false), m_database_ready(false) {}
    ~CDatabaseManager() { Cleanup(); }
    
    //+------------------------------------------------------------------+
    //| Inicjalizacja database managera z natywnym SQLite               |
    //+------------------------------------------------------------------+
    bool Initialize()
    {
        if(m_initialized) return true;
        
        // Ścieżka do bazy danych
        m_db_path = "multi_candles.db";
        
        // Otwórz lub utwórz bazę danych w katalogu terminala (bez flagi COMMON)
        m_db_handle = DatabaseOpen(m_db_path, DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE);
        
        if(m_db_handle == INVALID_HANDLE)
        {
            LogError("Nie można otworzyć/utworzyć bazy danych: " + IntegerToString(GetLastError()), "Initialize");
            return false;
        }
        
        PrintDebug("Baza danych otwarta pomyślnie: " + m_db_path);
        
        if(!CreateTables())
        {
            LogError("Błąd przy tworzeniu tabel", "Initialize");
            return false;
        }
        
        m_database_ready = true;
        m_initialized = true;
        PrintDebug("DatabaseManager zainicjalizowany pomyślnie z natywnym SQLite");
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Utworzenie wszystkich potrzebnych tabel                         |
    //+------------------------------------------------------------------+
    bool CreateTables()
    {
        // Utworzenie tabel dla świeczek
        for(int i = 0; i < Config.GetSymbolsCount(); i++)
        {
            string symbol = Config.GetSymbol(i);
            if(symbol == "") continue;
            
            string createTableSQL = StringFormat("CREATE TABLE IF NOT EXISTS [%s] ("
                                    "time INTEGER PRIMARY KEY,"
                                    "open REAL,"
                                    "high REAL,"
                                    "low REAL,"
                                    "close REAL,"
                                    "tick_volume INTEGER,"
                                    "spread INTEGER,"
                                    "real_volume INTEGER)", symbol);
            
            if(!DatabaseExecute(m_db_handle, createTableSQL))
            {
                LogError("Błąd przy tworzeniu tabeli dla " + symbol + ": " + IntegerToString(GetLastError()), "CreateTables");
                return false;
            }
            
            PrintDebug("Tabela utworzona/sprawdzona: " + symbol);
        }
        
        // Utworzenie tabeli pozycji
        string createPosTableSQL = "CREATE TABLE IF NOT EXISTS positions ("
                                   "position_id INTEGER PRIMARY KEY,"
                                   "open_time INTEGER,"
                                   "ticket INTEGER,"
                                   "type TEXT,"
                                   "volume REAL,"
                                   "symbol TEXT,"
                                   "open_price REAL,"
                                   "sl REAL,"
                                   "tp REAL,"
                                   "close_time INTEGER,"
                                   "close_price REAL,"
                                   "commission REAL,"
                                   "swap REAL,"
                                   "profit REAL,"
                                   "profit_points INTEGER,"
                                   "balance REAL,"
                                   "magic_number INTEGER,"
                                   "duration TEXT,"
                                   "open_reason TEXT,"
                                   "close_reason TEXT,"
                                   "open_comment TEXT,"
                                   "close_comment TEXT,"
                                   "deal_in_ticket TEXT,"
                                   "deal_out_tickets TEXT,"
                                   "Setup TEXT,"
                                   "Uwagi TEXT,"
                                   "TrendS TEXT,"
                                   "TrendL TEXT,"
                                   "Wybicie INTEGER,"
                                   "Niedojscie INTEGER,"
                                   "Tag TEXT)";
        
        if(!DatabaseExecute(m_db_handle, createPosTableSQL))
        {
            LogError("Błąd przy tworzeniu tabeli positions: " + IntegerToString(GetLastError()), "CreateTables");
            return false;
        }
        
        PrintDebug("Tabela positions utworzona/sprawdzona");
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Export świeczek do bazy danych z natywnym SQLite                |
    //+------------------------------------------------------------------+
    bool ExportCandlesToDatabase(string symbol, ENUM_TIMEFRAMES timeframe = PERIOD_H1)
    {
        if(!m_database_ready)
        {
            LogError("Baza danych nie jest gotowa", "ExportCandlesToDatabase");
            return false;
        }
        
        PrintDebug("Export świeczek dla symbolu: " + symbol);
        
        datetime lastTime = GetLastCandleTime(symbol);
        if(lastTime == 0)
            lastTime = Config.GetStartDate();
            
        datetime currentTime = TimeCurrent();
        
        MqlRates rates[];
        int copied = CopyRates(symbol, timeframe, lastTime, currentTime, rates);
        
        if(copied <= 0)
        {
            LogError("Brak danych do eksportu dla " + symbol, "ExportCandlesToDatabase");
            return false;
        }
        
        // Rozpocznij transakcję
        if(!DatabaseExecute(m_db_handle, "BEGIN TRANSACTION"))
        {
            LogError("Błąd przy rozpoczynaniu transakcji: " + IntegerToString(GetLastError()), "ExportCandlesToDatabase");
            return false;
        }
        
        string insertSQL = StringFormat("INSERT OR REPLACE INTO [%s] VALUES (?,?,?,?,?,?,?,?)", symbol);
        int insertRequest = DatabasePrepare(m_db_handle, insertSQL);
        
        if(insertRequest == INVALID_HANDLE)
        {
            LogError("Błąd zapytania dla " + symbol + ": " + IntegerToString(GetLastError()), "ExportCandlesToDatabase");
            DatabaseExecute(m_db_handle, "ROLLBACK");
            return false;
        }
        
        int inserted_count = 0;
        
        for(int i = 0; i < copied; i++)
        {
            DatabaseReset(insertRequest);
            
            DatabaseBind(insertRequest, 0, (long)rates[i].time);
            DatabaseBind(insertRequest, 1, rates[i].open);
            DatabaseBind(insertRequest, 2, rates[i].high);
            DatabaseBind(insertRequest, 3, rates[i].low);
            DatabaseBind(insertRequest, 4, rates[i].close);
            DatabaseBind(insertRequest, 5, rates[i].tick_volume);
            DatabaseBind(insertRequest, 6, rates[i].spread);
            DatabaseBind(insertRequest, 7, rates[i].real_volume);
            
            if(DatabaseRead(insertRequest))
            {
                inserted_count++;
            }
        }
        
        DatabaseFinalize(insertRequest);
        
        // Zatwierdź transakcję
        if(!DatabaseExecute(m_db_handle, "COMMIT"))
        {
            LogError("Błąd przy zatwierdzaniu transakcji: " + IntegerToString(GetLastError()), "ExportCandlesToDatabase");
            DatabaseExecute(m_db_handle, "ROLLBACK");
            return false;
        }
        
        PrintDebug("Wyeksportowano " + IntegerToString(inserted_count) + " świeczek dla " + symbol);
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Pobranie ostatniego czasu świeczki dla symbolu                  |
    //+------------------------------------------------------------------+
    datetime GetLastCandleTime(string symbol)
    {
        string querySQL = StringFormat("SELECT MAX(time) FROM [%s]", symbol);
        int queryRequest = DatabasePrepare(m_db_handle, querySQL);
        
        if(queryRequest == INVALID_HANDLE)
            return 0;
            
        datetime result = 0;
        if(DatabaseRead(queryRequest))
        {
            long columnValue;
            if(DatabaseColumnLong(queryRequest, 0, columnValue))
            {
                result = (datetime)columnValue;
            }
        }
        
        DatabaseFinalize(queryRequest);
        return result;
    }
    
    //+------------------------------------------------------------------+
    //| Export wszystkich symboli                                       |
    //+------------------------------------------------------------------+
    void ExportAllSymbols()
    {
        for(int i = 0; i < Config.GetSymbolsCount(); i++)
        {
            string symbol = Config.GetSymbol(i);
            if(symbol != "")
            {
                ExportCandlesToDatabase(symbol);
            }
        }
    }
    
    //+------------------------------------------------------------------+
    //| Export historii pozycji z natywnym SQLite                       |
    //+------------------------------------------------------------------+
    bool ExportHistoryPositionsToSQLite()
    {
        if(!m_database_ready || m_db_handle == INVALID_HANDLE)
        {
            LogError("Baza danych nie jest gotowa", "ExportHistoryPositionsToSQLite");
            return false;
        }
        
        PrintDebug("=== Eksport historii pozycji do SQLite ===");
        
        // SPRAWDZENIE TYPU RACHUNKU (jak w oryginalnej funkcji)
        if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
        {
            LogError("Ten EA działa tylko na rachunkach z hedgingiem (Forex)", "ExportHistoryPositionsToSQLite");
            return false;
        }
        
        // Sprawdź ostatnią datę w bazie
        string querySQL = "SELECT MAX(open_time) FROM positions";
        int request = DatabasePrepare(m_db_handle, querySQL);
        
        datetime fromDate = Config.GetStartDate();
        
        if(request != INVALID_HANDLE)
        {
            if(DatabaseRead(request))
            {
                long maxTime;
                if(DatabaseColumnLong(request, 0, maxTime) && maxTime > 0)
                {
                    fromDate = (datetime)maxTime; // Bez dodawania 1 sekundy - może duplikować
                    PrintDebug("Żaczynamy od daty: " + TimeToString(fromDate));
                }
                else
                {
                    PrintDebug("brak wpisów w tabeli, zaczynamy od daty default: " + TimeToString(Config.GetStartDate()));
                    fromDate = Config.GetStartDate();
                }
            }
            DatabaseFinalize(request);
        }
        else
        {
            LogError("Błąd zapytania o MAX(open_time): " + IntegerToString(GetLastError()), "ExportHistoryPositionsToSQLite");
        }
        
        datetime toDate = TimeCurrent();
        
        PrintDebug("Okres eksportu: " + TimeToString(fromDate) + " - " + TimeToString(toDate));
        
        // Wybierz historię
        if(!HistorySelect(fromDate, toDate))
        {
            LogError("HistorySelect nie powiodło się!", "ExportHistoryPositionsToSQLite");
            return false;
        }
        
        int dealsTotal = HistoryDealsTotal();
        PrintDebug("Znaleziono " + IntegerToString(dealsTotal) + " transakcji w historii");
        
        if(dealsTotal == 0)
        {
            PrintDebug("Brak nowych transakcji do eksportu");
            return true;
        }
        
        long processedPositions[];
        int insertedCount = 0;
        int errorCount = 0;
        
        CDealInfo deal;
        
        PrintDebug("=== ZBIERANIE POZYCJI DO EKSPORTU ===");
        
        // Przetwarzanie transakcji - zbieranie unikalnych pozycji
        for(int i = 0; i < dealsTotal && !IsStopped(); i++)
        {
            if(!deal.SelectByIndex(i))
                continue;
                
            if(deal.Entry() != DEAL_ENTRY_IN)
                continue;
                
            if(deal.DealType() != DEAL_TYPE_BUY && deal.DealType() != DEAL_TYPE_SELL)
                continue;
                
            long positionId = deal.PositionId();
            
            // Sprawdź czy już przetworzyliśmy tę pozycję
            bool alreadyProcessed = false;
            for(int j = 0; j < ArraySize(processedPositions); j++)
            {
                if(processedPositions[j] == positionId)
                {
                    alreadyProcessed = true;
                    break;
                }
            }
            
            if(alreadyProcessed)
                continue;
                
            // Dodaj do listy przetworzonych
            int size = ArraySize(processedPositions);
            ArrayResize(processedPositions, size + 1);
            processedPositions[size] = positionId;
        }
        
        int totalPositions = ArraySize(processedPositions);
        PrintDebug("Znaleziono " + IntegerToString(totalPositions) + " unikalnych pozycji do przetworzenia");
        
        if(totalPositions == 0)
        {
            PrintDebug("Brak pozycji do eksportu");
            return true;
        }
        
        PrintDebug("=== ROZPOCZĘCIE EKSPORTU POZYCJI ===");
        
        // Przetwórz każdą pozycję w OSOBNEJ transakcji
        for(int i = 0; i < totalPositions && !IsStopped(); i++)
        {
            long positionId = processedPositions[i];
            PrintDebug("Przetwarzanie pozycji " + IntegerToString(i+1) + "/" + IntegerToString(totalPositions) + ": ID=" + IntegerToString(positionId));
            
            if(ProcessSinglePositionWithTransaction(positionId))
            {
                insertedCount++;
                PrintDebug("✓ Pozycja " + IntegerToString(positionId) + " zapisana pomyślnie");
            }
            else
            {
                errorCount++;
                LogError("✗ Błąd przy zapisywaniu pozycji " + IntegerToString(positionId), "ExportHistoryPositionsToSQLite");
                
                // Jeśli jest zbyt dużo błędów, przerwij
                if(errorCount > 5)
                {
                    LogError("Zbyt dużo błędów (" + IntegerToString(errorCount) + ") - przerywam eksport", "ExportHistoryPositionsToSQLite");
                    break;
                }
            }
            
            // Krótka przerwa między pozycjami
            Sleep(10);
        }
        
        PrintDebug("=== PODSUMOWANIE EKSPORTU ===");
        PrintDebug("✓ Pomyślnie zapisano: " + IntegerToString(insertedCount) + " pozycji");
        if(errorCount > 0)
        {
            PrintDebug("✗ Błędy: " + IntegerToString(errorCount) + " pozycji");
        }
        PrintDebug("Łącznie przetworzono: " + IntegerToString(insertedCount + errorCount) + "/" + IntegerToString(totalPositions));
        
        return (insertedCount > 0); // Sukces jeśli choć jedna pozycja się udała
    }
    

    
    //+------------------------------------------------------------------+
    //| Przetwarza pojedynczą pozycję - UPROSZCZONE bez transakcji     |
    //+------------------------------------------------------------------+
    bool ProcessSinglePositionWithTransaction(long positionId)
    {
        // USUWAMY TRANSAKCJE - robimy PROSTO jak w Simple
        PrintDebug("Przetwarzanie pozycji: " + IntegerToString(positionId));
        
        if(!HistorySelectByPosition(positionId))
        {
            return false;
        }
        
        int deals = HistoryDealsTotal();
        if(deals < 2) return false; // Musi mieć open i close
        
        CDealInfo deal;
        
        // Dane pozycji
        string symbol = "";
        long type = -1;
        double volume = 0, open_price = 0, close_price = 0, profit = 0;
        double commission = 0, swap = 0, sl = 0, tp = 0;
        datetime open_time = 0, close_time = 0;
        long magic = 0;
        string open_comment = "", close_comment = "";
        bool hasOpen = false, hasClose = false;
        
        // Zbierz dane z transakcji
        for(int i = 0; i < deals; i++)
        {
            if(!deal.SelectByIndex(i)) continue;
            
            symbol = deal.Symbol();
            commission += deal.Commission();
            swap += deal.Swap();
            profit += deal.Profit();
            
            if(deal.Entry() == DEAL_ENTRY_IN)
            {
                hasOpen = true;
                magic = deal.Magic();
                type = deal.DealType();
                open_time = deal.Time();
                open_price = deal.Price();
                volume = deal.Volume();
                open_comment = deal.Comment();
            }
            else if(deal.Entry() == DEAL_ENTRY_OUT || deal.Entry() == DEAL_ENTRY_OUT_BY)
            {
                hasClose = true;
                close_time = deal.Time();
                close_price = deal.Price();
                sl = HistoryDealGetDouble(deal.Ticket(), DEAL_SL);
                tp = HistoryDealGetDouble(deal.Ticket(), DEAL_TP);
                close_comment = deal.Comment();
            }
        }
        
        // Sprawdź kompletność
        if(!hasOpen || !hasClose || open_time == 0 || close_time == 0)
        {
            return false;
        }
        
        // Oblicz punkty
        int points = 0;
        if(symbol != "")
        {
            SymbolSelect(symbol, true);
            double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
            if(point > 0)
            {
                points = (int)MathRound((type == DEAL_TYPE_BUY ? close_price - open_price : open_price - close_price) / point);
            }
        }
        
        string duration = TimeElapsedToString(close_time - open_time);
        
        // DEBUG: Wyświetl zebrane dane przed zapisem
        PrintDebug("=== DANE DO ZAPISU ====");
        PrintDebug("Position ID: " + IntegerToString(positionId));
        PrintDebug("Symbol: " + symbol);
        PrintDebug("Type: " + ((type == DEAL_TYPE_BUY) ? "BUY" : "SELL"));
        PrintDebug("Volume: " + DoubleToString(volume, 2));
        PrintDebug("Open Price: " + DoubleToString(open_price, 5));
        PrintDebug("Close Price: " + DoubleToString(close_price, 5));
        PrintDebug("SL: " + DoubleToString(sl, 5) + " (" + (sl > 0 ? "SET" : "NOT SET") + ")");
        PrintDebug("TP: " + DoubleToString(tp, 5) + " (" + (tp > 0 ? "SET" : "NOT SET") + ")");
        PrintDebug("Commission: " + DoubleToString(commission, 2));
        PrintDebug("Swap: " + DoubleToString(swap, 2));
        PrintDebug("Profit: " + DoubleToString(profit, 2));
        PrintDebug("Points: " + IntegerToString(points));
        PrintDebug("Magic: " + IntegerToString(magic));
        PrintDebug("Duration: " + duration);
        PrintDebug("Open Comment: '" + open_comment + "'");
        PrintDebug("Close Comment: '" + close_comment + "'");
        PrintDebug("==================");
        
        // BEZPOŚREDNIE SQL - tylko podstawowe pola które na pewno istnieją
        string directSQL = StringFormat(
            "INSERT OR IGNORE INTO positions "
            "(position_id, open_time, ticket, type, volume, symbol, open_price, sl, tp, "
            "close_time, close_price, commission, swap, profit, profit_points, "
            "magic_number, duration, open_comment, close_comment) "
            "VALUES (%d, %d, %d, '%s', %.2f, '%s', %.5f, %.5f, %.5f, %d, %.5f, %.2f, %.2f, %.2f, %d, %d, '%s', '%s', '%s')",
            positionId,
            (long)open_time,
            positionId, // ticket = position_id
            (type == DEAL_TYPE_BUY) ? "buy" : "sell",
            volume,
            symbol,
            open_price,
            sl,
            tp,
            (long)close_time,
            close_price,
            commission,
            swap,
            profit,
            points,
            magic,
            duration,
            open_comment,
            close_comment
        );
        
        // Wykonaj BEZPOŚREDNIO - jak w Simple
        if(!DatabaseExecute(m_db_handle, directSQL))
        {
            return false;
        }
        
        return true;
    }

    //+------------------------------------------------------------------+
    //| Konwertuje czas na czytelny string                              |
    //+------------------------------------------------------------------+
    string TimeElapsedToString(const datetime pElapsedSeconds)
    {
        const long days = pElapsedSeconds / PeriodSeconds(PERIOD_D1);
        return((days ? (string)days + "d " : "") + TimeToString(pElapsedSeconds, TIME_SECONDS));
    }
    
    //+------------------------------------------------------------------+
    //| Konwertuje DEAL_REASON na string                                |
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
    //| Sprawdzenie stanu bazy danych                                   |
    //+------------------------------------------------------------------+
    bool IsDatabaseReady() { return m_database_ready; }
    
    //+------------------------------------------------------------------+
    //| Statystyki bazy danych                                          |
    //+------------------------------------------------------------------+
    void PrintDatabaseStats()
    {
        if(!m_database_ready) return;
        
        PrintDebug("=== STATYSTYKI BAZY DANYCH ===");
        
        string querySQL = "SELECT COUNT(*) FROM positions";
        int queryRequest = DatabasePrepare(m_db_handle, querySQL);
        
        if(queryRequest != INVALID_HANDLE)
        {
            if(DatabaseRead(queryRequest))
            {
                long count;
                if(DatabaseColumnLong(queryRequest, 0, count))
                {
                    PrintDebug("Liczba pozycji w bazie: " + IntegerToString(count));
                }
            }
            DatabaseFinalize(queryRequest);
        }
        
        PrintDebug("===============================");
    }
    
    //+------------------------------------------------------------------+
    //| TEST: Odczyt ostatnich 3 pozycji z bazy danych                  |
    //+------------------------------------------------------------------+
    bool TestReadLastPositions()
    {
        PrintDebug("=== TEST ODCZYTU OSTATNICH 3 POZYCJI ===");
        
        if(!m_database_ready || m_db_handle == INVALID_HANDLE)
        {
            LogError("Baza danych nie jest gotowa", "TestReadLastPositions");
            return false;
        }
        
        // Sprawdź czy tabela positions istnieje
        string checkTableSQL = "SELECT name FROM sqlite_master WHERE type='table' AND name='positions'";
        int checkRequest = DatabasePrepare(m_db_handle, checkTableSQL);
        
        if(checkRequest == INVALID_HANDLE)
        {
            LogError("Nie można sprawdzić istnienia tabeli: " + IntegerToString(GetLastError()), "TestReadLastPositions");
            return false;
        }
        
        bool tableExists = false;
        if(DatabaseRead(checkRequest))
        {
            tableExists = true;
            PrintDebug("✓ Tabela 'positions' istnieje");
        }
        else
        {
            PrintDebug("✗ Tabela 'positions' NIE istnieje lub jest pusta");
            DatabaseFinalize(checkRequest);
            return false;
        }
        DatabaseFinalize(checkRequest);
        
        // Sprawdź liczbę wszystkich wpisów
        string countSQL = "SELECT COUNT(*) FROM positions";
        int countRequest = DatabasePrepare(m_db_handle, countSQL);
        
        long totalCount = 0;
        if(countRequest != INVALID_HANDLE)
        {
            if(DatabaseRead(countRequest))
            {
                DatabaseColumnLong(countRequest, 0, totalCount);
                PrintDebug("Łączna liczba pozycji w bazie: " + IntegerToString(totalCount));
            }
            DatabaseFinalize(countRequest);
        }
        
        if(totalCount == 0)
        {
            PrintDebug("Baza jest pusta - brak pozycji do wyświetlenia");
            return true;
        }
        
        // Pobierz ostatnie 3 pozycje - tylko pola które są w INSERT
        string querySQL = "SELECT position_id, ticket, sl, tp, commission, swap, open_time, close_time, type, symbol, volume, "
                         "open_price, close_price, profit, profit_points, duration, magic_number, "
                         "open_comment, close_comment "
                         "FROM positions "
                         "ORDER BY close_time DESC "
                         "LIMIT 3";
        
        int queryRequest = DatabasePrepare(m_db_handle, querySQL);
        
        if(queryRequest == INVALID_HANDLE)
        {
            LogError("Błąd przygotowania zapytania SELECT: " + IntegerToString(GetLastError()), "TestReadLastPositions");
            return false;
        }
        
        PrintDebug("=== OSTATNIE 3 POZYCJE ===");
        
        int rowCount = 0;
        while(DatabaseRead(queryRequest))
        {
            rowCount++;
            
            // Pobierz dane z kolumn - NOWA KOLEJNOŚĆ
            long position_id, ticket, open_time, close_time, magic_number;
            double sl, tp, commission, swap, volume, open_price, close_price, profit;
            string type, symbol, duration, open_comment, close_comment;
            long profit_points;
            
            DatabaseColumnLong(queryRequest, 0, position_id);
            DatabaseColumnLong(queryRequest, 1, ticket);
            DatabaseColumnDouble(queryRequest, 2, sl);
            DatabaseColumnDouble(queryRequest, 3, tp);
            DatabaseColumnDouble(queryRequest, 4, commission);
            DatabaseColumnDouble(queryRequest, 5, swap);
            DatabaseColumnLong(queryRequest, 6, open_time);
            DatabaseColumnLong(queryRequest, 7, close_time);
            DatabaseColumnText(queryRequest, 8, type);
            DatabaseColumnText(queryRequest, 9, symbol);
            DatabaseColumnDouble(queryRequest, 10, volume);
            DatabaseColumnDouble(queryRequest, 11, open_price);
            DatabaseColumnDouble(queryRequest, 12, close_price);
            DatabaseColumnDouble(queryRequest, 13, profit);
            DatabaseColumnLong(queryRequest, 14, profit_points);
            DatabaseColumnText(queryRequest, 15, duration);
            DatabaseColumnLong(queryRequest, 16, magic_number);
            DatabaseColumnText(queryRequest, 17, open_comment);
            DatabaseColumnText(queryRequest, 18, close_comment);
            
            // Wyświetl dane pozycji - Z DODATKOWYMI POLAMI
            PrintDebug("--- POZYCJA " + IntegerToString(rowCount) + " ---");
            PrintDebug("Position ID: " + IntegerToString(position_id));
            PrintDebug("Ticket: " + IntegerToString(ticket));
            PrintDebug("Symbol: " + symbol + " (" + type + ")");
            PrintDebug("Volume: " + DoubleToString(volume, 2));
            PrintDebug("Otwarcie: " + TimeToString((datetime)open_time) + " @ " + DoubleToString(open_price, 5));
            PrintDebug("Zamknięcie: " + TimeToString((datetime)close_time) + " @ " + DoubleToString(close_price, 5));
            PrintDebug("SL: " + DoubleToString(sl, 5) + " | TP: " + DoubleToString(tp, 5));
            PrintDebug("Commission: " + DoubleToString(commission, 2) + " | Swap: " + DoubleToString(swap, 2));
            PrintDebug("Profit: " + DoubleToString(profit, 2) + " USD (" + IntegerToString(profit_points) + " pkt)");
            PrintDebug("Magic: " + IntegerToString(magic_number) + " | Czas trwania: " + duration);
            if(open_comment != "") PrintDebug("Komentarz otwarcia: '" + open_comment + "'");
            if(close_comment != "") PrintDebug("Komentarz zamknięcia: '" + close_comment + "'");
            PrintDebug("");
        }
        
        DatabaseFinalize(queryRequest);
        
        if(rowCount == 0)
        {
            PrintDebug("Nie znaleziono żadnych pozycji (pomimo że COUNT pokazał " + IntegerToString(totalCount) + ")");
            
            // Dodatkowy test - sprawdź strukturę tabeli
            PrintDebug("=== SPRAWDZANIE STRUKTURY TABELI ===");
            string pragmaSQL = "PRAGMA table_info(positions)";
            int pragmaRequest = DatabasePrepare(m_db_handle, pragmaSQL);
            
            if(pragmaRequest != INVALID_HANDLE)
            {
                PrintDebug("Kolumny w tabeli positions:");
                while(DatabaseRead(pragmaRequest))
                {
                    long cid;
                    string name, type, dflt_value;
                    long notnull, pk;
                    
                    DatabaseColumnLong(pragmaRequest, 0, cid);
                    DatabaseColumnText(pragmaRequest, 1, name);
                    DatabaseColumnText(pragmaRequest, 2, type);
                    DatabaseColumnLong(pragmaRequest, 3, notnull);
                    DatabaseColumnText(pragmaRequest, 4, dflt_value);
                    DatabaseColumnLong(pragmaRequest, 5, pk);
                    
                    PrintDebug("  " + IntegerToString(cid) + ": " + name + " (" + type + ")" + 
                              (pk ? " PRIMARY KEY" : ""));
                }
                DatabaseFinalize(pragmaRequest);
            }
        }
        else
        {
            PrintDebug("✓ Pomyślnie odczytano " + IntegerToString(rowCount) + " pozycji");
        }
        
        PrintDebug("=== KONIEC TESTU ODCZYTU ===");
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| TEST: Sprawdź szczegółowy stan bazy danych                      |
    //+------------------------------------------------------------------+
    bool TestDatabaseStatus()
    {
        PrintDebug("=== SZCZEGÓŁOWY STAN BAZY DANYCH ===");
        
        PrintDebug("Ścieżka bazy: " + m_db_path);
        PrintDebug("Handle: " + IntegerToString(m_db_handle));
        PrintDebug("Zainicjalizowana: " + BoolToString(m_initialized));
        PrintDebug("Gotowa: " + BoolToString(m_database_ready));
        
        if(m_db_handle == INVALID_HANDLE)
        {
            LogError("Handle bazy danych jest nieprawidłowy!", "TestDatabaseStatus");
            return false;
        }
        
        // Lista wszystkich tabel w bazie
        string tablesSQL = "SELECT name FROM sqlite_master WHERE type='table'";
        int tablesRequest = DatabasePrepare(m_db_handle, tablesSQL);
        
        if(tablesRequest != INVALID_HANDLE)
        {
            PrintDebug("Tabele w bazie danych:");
            bool foundTables = false;
            while(DatabaseRead(tablesRequest))
            {
                string tableName;
                DatabaseColumnText(tablesRequest, 0, tableName);
                PrintDebug("  - " + tableName);
                foundTables = true;
            }
            
            if(!foundTables)
            {
                PrintDebug("  BRAK TABEL w bazie danych!");
            }
            
            DatabaseFinalize(tablesRequest);
        }
        else
        {
            LogError("Nie można pobrać listy tabel: " + IntegerToString(GetLastError()), "TestDatabaseStatus");
        }
        
        PrintDebug("=====================================");
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Cleanup przy zamknięciu                                         |
    //+------------------------------------------------------------------+
    void Cleanup()
    {
        if(m_db_handle != INVALID_HANDLE)
        {
            DatabaseClose(m_db_handle);
            m_db_handle = INVALID_HANDLE;
            PrintDebug("Połączenie z bazą danych zamknięte");
        }
        m_database_ready = false;
        m_initialized = false;
        PrintDebug("DatabaseManager: Cleanup completed");
    }
};

// Globalna instancja managera bazy danych
CDatabaseManager Database;
