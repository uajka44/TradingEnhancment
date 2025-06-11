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
        
        // Otwórz lub utwórz bazę danych z natywnym SQLite MT5
        m_db_handle = DatabaseOpen(m_db_path, DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE | DATABASE_OPEN_COMMON);
        
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
                    fromDate = (datetime)maxTime + 1; // Dodaj 1 sekundę żeby nie duplikować
                    PrintDebug("Ostatnia pozycja w bazie: " + TimeToString(fromDate-1));
                }
                else
                {
                    PrintDebug("Baza pusta, eksportujemy od: " + TimeToString(Config.GetStartDate()));
                }
            }
            DatabaseFinalize(request);
        }
        
        datetime toDate = TimeCurrent();
        
        // Rozpocznij transakcję
        if(!DatabaseExecute(m_db_handle, "BEGIN TRANSACTION"))
        {
            LogError("Błąd przy rozpoczynaniu transakcji: " + IntegerToString(GetLastError()), "ExportHistoryPositionsToSQLite");
            return false;
        }
        
        // Przygotuj zapytanie INSERT
        string insertSQL = "INSERT OR IGNORE INTO positions "
                          "(position_id, open_time, ticket, type, volume, symbol, open_price, sl, tp, "
                          "close_time, close_price, commission, swap, profit, profit_points, "
                          "magic_number, duration, open_reason, close_reason, open_comment, close_comment, "
                          "deal_in_ticket, deal_out_tickets) "
                          "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)";
        
        int insertRequest = DatabasePrepare(m_db_handle, insertSQL);
        
        if(insertRequest == INVALID_HANDLE)
        {
            LogError("Błąd przy przygotowaniu zapytania INSERT: " + IntegerToString(GetLastError()), "ExportHistoryPositionsToSQLite");
            DatabaseExecute(m_db_handle, "ROLLBACK");
            return false;
        }
        
        // Wybierz historię
        if(!HistorySelect(fromDate, toDate))
        {
            LogError("HistorySelect nie powiodło się!", "ExportHistoryPositionsToSQLite");
            DatabaseFinalize(insertRequest);
            DatabaseExecute(m_db_handle, "ROLLBACK");
            return false;
        }
        
        int dealsTotal = HistoryDealsTotal();
        PrintDebug("Znaleziono " + IntegerToString(dealsTotal) + " transakcji w historii");
        
        long processedPositions[];
        int insertedCount = 0;
        
        CDealInfo deal;
        
        // Przetwarzanie transakcji
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
            
            // Przetwórz pozycję
            if(ProcessPositionForExport(positionId, insertRequest))
                insertedCount++;
        }
        
        // Zatwierdź transakcję
        DatabaseFinalize(insertRequest);
        
        if(!DatabaseExecute(m_db_handle, "COMMIT"))
        {
            LogError("Błąd przy zatwierdzaniu transakcji: " + IntegerToString(GetLastError()), "ExportHistoryPositionsToSQLite");
            DatabaseExecute(m_db_handle, "ROLLBACK");
            return false;
        }
        else
        {
            PrintDebug("✓ Pomyślnie zapisano " + IntegerToString(insertedCount) + " pozycji do bazy danych");
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Przetwarza pojedynczą pozycję i zapisuje do bazy               |
    //+------------------------------------------------------------------+
    bool ProcessPositionForExport(long positionId, int insertRequest)
    {
        if(!HistorySelectByPosition(positionId))
            return false;
            
        int deals = HistoryDealsTotal();
        if(deals < 2) // Pozycja musi mieć minimum open i close
            return false;
            
        CDealInfo deal;
        
        // Dane pozycji
        long pos_id = positionId;
        string pos_symbol = "";
        long pos_type = -1;
        long pos_magic = -1;
        double pos_open_price = 0;
        double pos_close_price = 0;
        double pos_sl = 0;
        double pos_tp = 0;
        double pos_commission = 0;
        double pos_swap = 0;
        double pos_profit = 0;
        double pos_volume = 0;
        datetime pos_open_time = 0;
        datetime pos_close_time = 0;
        string pos_open_comment = "";
        string pos_close_comment = "";
        string pos_deal_in = "";
        string pos_deal_out = "";
        long pos_open_reason = -1;
        long pos_close_reason = -1;
        
        // Zbierz dane z transakcji
        for(int i = 0; i < deals; i++)
        {
            if(!deal.SelectByIndex(i))
                continue;
                
            pos_symbol = deal.Symbol();
            pos_commission += deal.Commission();
            pos_swap += deal.Swap();
            pos_profit += deal.Profit();
            
            if(deal.Entry() == DEAL_ENTRY_IN)
            {
                pos_magic = deal.Magic();
                pos_type = deal.DealType();
                pos_open_time = deal.Time();
                pos_open_price = deal.Price();
                pos_volume = deal.Volume();
                pos_open_comment = deal.Comment();
                pos_deal_in = IntegerToString(deal.Ticket());
                pos_open_reason = HistoryDealGetInteger(deal.Ticket(), DEAL_REASON);
            }
            else if(deal.Entry() == DEAL_ENTRY_OUT || deal.Entry() == DEAL_ENTRY_OUT_BY)
            {
                pos_close_time = deal.Time();
                pos_close_price = deal.Price();
                pos_sl = HistoryDealGetDouble(deal.Ticket(), DEAL_SL);
                pos_tp = HistoryDealGetDouble(deal.Ticket(), DEAL_TP);
                pos_close_comment = deal.Comment();
                pos_deal_out = IntegerToString(deal.Ticket());
                pos_close_reason = HistoryDealGetInteger(deal.Ticket(), DEAL_REASON);
            }
        }
        
        // Sprawdź czy pozycja jest kompletna
        if(pos_open_time == 0 || pos_close_time == 0)
            return false;
            
        // Oblicz profit w punktach
        SymbolSelect(pos_symbol, true);
        double point = SymbolInfoDouble(pos_symbol, SYMBOL_POINT);
        int profit_points = (int)MathRound((pos_type == DEAL_TYPE_BUY ? pos_close_price - pos_open_price : pos_open_price - pos_close_price) / point);
        
        // Oblicz czas trwania pozycji
        string duration = TimeElapsedToString(pos_close_time - pos_open_time);
        
        // Resetuj i przypisz wartości do zapytania
        DatabaseReset(insertRequest);
        
        DatabaseBind(insertRequest, 0, (long)pos_id);
        DatabaseBind(insertRequest, 1, (long)pos_open_time);
        DatabaseBind(insertRequest, 2, (long)pos_id); // ticket = position_id
        DatabaseBind(insertRequest, 3, (pos_type == DEAL_TYPE_BUY) ? "buy" : "sell");
        DatabaseBind(insertRequest, 4, pos_volume);
        DatabaseBind(insertRequest, 5, pos_symbol);
        DatabaseBind(insertRequest, 6, pos_open_price);
        DatabaseBind(insertRequest, 7, pos_sl > 0 ? pos_sl : 0);
        DatabaseBind(insertRequest, 8, pos_tp > 0 ? pos_tp : 0);
        DatabaseBind(insertRequest, 9, (long)pos_close_time);
        DatabaseBind(insertRequest, 10, pos_close_price);
        DatabaseBind(insertRequest, 11, pos_commission);
        DatabaseBind(insertRequest, 12, pos_swap);
        DatabaseBind(insertRequest, 13, pos_profit);
        DatabaseBind(insertRequest, 14, profit_points);
        DatabaseBind(insertRequest, 15, pos_magic);
        DatabaseBind(insertRequest, 16, duration);
        DatabaseBind(insertRequest, 17, DealReasonToString((ENUM_DEAL_REASON)pos_open_reason));
        DatabaseBind(insertRequest, 18, DealReasonToString((ENUM_DEAL_REASON)pos_close_reason));
        DatabaseBind(insertRequest, 19, pos_open_comment);
        DatabaseBind(insertRequest, 20, pos_close_comment);
        DatabaseBind(insertRequest, 21, pos_deal_in);
        DatabaseBind(insertRequest, 22, pos_deal_out);
        
        // Wykonaj zapytanie
        if(!DatabaseRead(insertRequest))
        {
            LogError("Błąd podczas wstawiania pozycji ID=" + IntegerToString(pos_id) + ": " + IntegerToString(GetLastError()), "ProcessPositionForExport");
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
