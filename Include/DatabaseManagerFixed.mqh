//+------------------------------------------------------------------+
//|                                    DatabaseManagerFixed.mqh     |
//|                            Zarządzanie bazą danych SQLite (FIXED)|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property strict

#include <Generic\HashSet.mqh>
#include <Trade\DealInfo.mqh>
#include "Utils.mqh"
#include "ConfigManager.mqh"

//+------------------------------------------------------------------+
//| KLASA DatabaseManager - POPRAWIONA WERSJA                       |
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
    //| NOWA WERSJA: Export historii pozycji (POJEDYNCZE TRANSAKCJE)    |
    //+------------------------------------------------------------------+
    bool ExportHistoryPositionsToSQLite()
    {
        if(!m_database_ready || m_db_handle == INVALID_HANDLE)
        {
            LogError("Baza danych nie jest gotowa", "ExportHistoryPositionsToSQLite");
            return false;
        }
        
        PrintDebug("=== EKSPORT HISTORII POZYCJI (FIXED) ===");
        
        // SPRAWDZENIE TYPU RACHUNKU
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
                    fromDate = (datetime)maxTime;
                    PrintDebug("Zaczynamy od daty: " + TimeToString(fromDate));
                }
                else
                {
                    PrintDebug("brak wpisów w tabeli, zaczynamy od daty default: " + TimeToString(Config.GetStartDate()));
                }
            }
            DatabaseFinalize(request);
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
        
        // Zbierz unikalne pozycje
        long positionIds[];
        CDealInfo deal;
        
        for(int i = 0; i < dealsTotal && !IsStopped(); i++)
        {
            if(!deal.SelectByIndex(i)) continue;
            if(deal.Entry() != DEAL_ENTRY_IN) continue;
            if(deal.DealType() != DEAL_TYPE_BUY && deal.DealType() != DEAL_TYPE_SELL) continue;
                
            long positionId = deal.PositionId();
            
            // Sprawdź czy już mamy tę pozycję
            bool alreadyAdded = false;
            for(int j = 0; j < ArraySize(positionIds); j++)
            {
                if(positionIds[j] == positionId)
                {
                    alreadyAdded = true;
                    break;
                }
            }
            
            if(!alreadyAdded)
            {
                int size = ArraySize(positionIds);
                ArrayResize(positionIds, size + 1);
                positionIds[size] = positionId;
            }
        }
        
        int totalPositions = ArraySize(positionIds);
        PrintDebug("Znaleziono " + IntegerToString(totalPositions) + " unikalnych pozycji do przetworzenia");
        
        if(totalPositions == 0)
        {
            PrintDebug("Brak pozycji do eksportu");
            return true;
        }
        
        int insertedCount = 0;
        int errorCount = 0;
        
        // Przetwórz każdą pozycję w OSOBNEJ transakcji
        for(int i = 0; i < totalPositions && !IsStopped(); i++)
        {
            long positionId = positionIds[i];
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
                if(errorCount > 10)
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
        if(errorCount > 0) PrintDebug("✗ Błędy: " + IntegerToString(errorCount) + " pozycji");
        PrintDebug("Łącznie przetworzono: " + IntegerToString(insertedCount + errorCount) + "/" + IntegerToString(totalPositions));
        
        return (insertedCount > 0);
    }
    
    //+------------------------------------------------------------------+
    //| Przetwarza pojedynczą pozycję w osobnej transakcji              |
    //+------------------------------------------------------------------+
    bool ProcessSinglePositionWithTransaction(long positionId)
    {
        // Rozpocznij transakcję
        if(!DatabaseExecute(m_db_handle, "BEGIN TRANSACTION"))
        {
            LogError("Błąd transakcji dla pozycji " + IntegerToString(positionId), "ProcessSinglePositionWithTransaction");
            return false;
        }
        
        // Przygotuj zapytanie
        string insertSQL = "INSERT OR IGNORE INTO positions "
                          "(position_id, open_time, ticket, type, volume, symbol, open_price, sl, tp, "
                          "close_time, close_price, commission, swap, profit, profit_points, "
                          "magic_number, duration, open_reason, close_reason, open_comment, close_comment, "
                          "deal_in_ticket, deal_out_tickets) "
                          "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)";
        
        int insertRequest = DatabasePrepare(m_db_handle, insertSQL);
        
        if(insertRequest == INVALID_HANDLE)
        {
            LogError("Błąd przygotowania INSERT dla pozycji " + IntegerToString(positionId), "ProcessSinglePositionWithTransaction");
            DatabaseExecute(m_db_handle, "ROLLBACK");
            return false;
        }
        
        // Przetwórz pozycję
        bool success = ProcessPositionData(positionId, insertRequest);
        DatabaseFinalize(insertRequest);
        
        if(success)
        {
            if(!DatabaseExecute(m_db_handle, "COMMIT"))
            {
                LogError("Błąd COMMIT dla pozycji " + IntegerToString(positionId), "ProcessSinglePositionWithTransaction");
                DatabaseExecute(m_db_handle, "ROLLBACK");
                return false;
            }
            return true;
        }
        else
        {
            DatabaseExecute(m_db_handle, "ROLLBACK");
            return false;
        }
    }
    
    //+------------------------------------------------------------------+
    //| Przetwarza dane pojedynczej pozycji                             |
    //+------------------------------------------------------------------+
    bool ProcessPositionData(long positionId, int insertRequest)
    {
        if(!HistorySelectByPosition(positionId))
        {
            LogError("Nie można wybrać historii dla pozycji: " + IntegerToString(positionId), "ProcessPositionData");
            return false;
        }
            
        int deals = HistoryDealsTotal();
        if(deals < 1)
        {
            PrintDebug("Pozycja " + IntegerToString(positionId) + " ma tylko " + IntegerToString(deals) + " transakcji - pomijamy");
            return false;
        }
            
        CDealInfo deal;
        
        // Inicjalizacja danych pozycji
        string pos_symbol = "";
        long pos_type = -1, pos_magic = -1;
        double pos_open_price = 0, pos_close_price = 0, pos_sl = 0, pos_tp = 0;
        double pos_commission = 0, pos_swap = 0, pos_profit = 0, pos_volume = 0;
        datetime pos_open_time = 0, pos_close_time = 0;
        string pos_open_comment = "", pos_close_comment = "", pos_deal_in = "", pos_deal_out = "";
        long pos_open_reason = -1, pos_close_reason = -1;
        bool hasEntry = false, hasExit = false;
        
        // Zbierz dane z transakcji
        for(int i = 0; i < deals; i++)
        {
            if(!deal.SelectByIndex(i)) continue;
                
            pos_symbol = deal.Symbol();
            pos_commission += deal.Commission();
            pos_swap += deal.Swap();
            pos_profit += deal.Profit();
            
            if(deal.Entry() == DEAL_ENTRY_IN)
            {
                hasEntry = true;
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
                hasExit = true;
                pos_close_time = deal.Time();
                pos_close_price = deal.Price();
                pos_sl = HistoryDealGetDouble(deal.Ticket(), DEAL_SL);
                pos_tp = HistoryDealGetDouble(deal.Ticket(), DEAL_TP);
                pos_close_comment = deal.Comment();
                pos_deal_out = IntegerToString(deal.Ticket());
                pos_close_reason = HistoryDealGetInteger(deal.Ticket(), DEAL_REASON);
            }
        }
        
        // Sprawdź kompletność pozycji
        if(!hasEntry || !hasExit || pos_open_time == 0 || pos_close_time == 0)
        {
            PrintDebug("Pozycja " + IntegerToString(positionId) + " niekompletna - pomijamy");
            return false;
        }
        
        // Oblicz profit w punktach
        int profit_points = 0;
        if(pos_symbol != "")
        {
            SymbolSelect(pos_symbol, true);
            double point = SymbolInfoDouble(pos_symbol, SYMBOL_POINT);
            if(point > 0)
            {
                profit_points = (int)MathRound((pos_type == DEAL_TYPE_BUY ? pos_close_price - pos_open_price : pos_open_price - pos_close_price) / point);
            }
        }
        
        string duration = TimeElapsedToString(pos_close_time - pos_open_time);
        
        // Bind wartości
        if(!DatabaseReset(insertRequest)) return false;
        
        DatabaseBind(insertRequest, 0, (long)positionId);
        DatabaseBind(insertRequest, 1, (long)pos_open_time);
        DatabaseBind(insertRequest, 2, (long)positionId);
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
            LogError("Błąd DatabaseRead dla pozycji ID=" + IntegerToString(positionId) + ": " + IntegerToString(GetLastError()), "ProcessPositionData");
            return false;
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Pozostałe funkcje pomocnicze                                    |
    //+------------------------------------------------------------------+
    bool IsDatabaseReady() { return m_database_ready; }
    
    void PrintDatabaseStats()
    {
        if(!m_database_ready) return;
        
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
    }
    
    bool TestReadLastPositions()
    {
        PrintDebug("=== TEST ODCZYTU OSTATNICH 3 POZYCJI ===");
        
        if(!m_database_ready)
        {
            LogError("Baza danych nie jest gotowa", "TestReadLastPositions");
            return false;
        }
        
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
            PrintDebug("Baza jest pusta");
            return true;
        }
        
        string querySQL = "SELECT position_id, open_time, close_time, type, symbol, volume, "
                         "open_price, close_price, profit, profit_points, duration "
                         "FROM positions ORDER BY close_time DESC LIMIT 3";
        
        int queryRequest = DatabasePrepare(m_db_handle, querySQL);
        
        if(queryRequest == INVALID_HANDLE)
        {
            LogError("Błąd zapytania SELECT", "TestReadLastPositions");
            return false;
        }
        
        int rowCount = 0;
        while(DatabaseRead(queryRequest))
        {
            rowCount++;
            
            long position_id, open_time, close_time, profit_points;
            string type, symbol, duration;
            double volume, open_price, close_price, profit;
            
            DatabaseColumnLong(queryRequest, 0, position_id);
            DatabaseColumnLong(queryRequest, 1, open_time);
            DatabaseColumnLong(queryRequest, 2, close_time);
            DatabaseColumnText(queryRequest, 3, type);
            DatabaseColumnText(queryRequest, 4, symbol);
            DatabaseColumnDouble(queryRequest, 5, volume);
            DatabaseColumnDouble(queryRequest, 6, open_price);
            DatabaseColumnDouble(queryRequest, 7, close_price);
            DatabaseColumnDouble(queryRequest, 8, profit);
            DatabaseColumnLong(queryRequest, 9, profit_points);
            DatabaseColumnText(queryRequest, 10, duration);
            
            PrintDebug("=== POZYCJA " + IntegerToString(rowCount) + " ===");
            PrintDebug("ID: " + IntegerToString(position_id) + ", Symbol: " + symbol + ", Typ: " + type);
            PrintDebug("Volume: " + DoubleToString(volume, 2) + ", Profit: " + DoubleToString(profit, 2) + " USD");
            PrintDebug("Open: " + TimeToString((datetime)open_time) + " @ " + DoubleToString(open_price, 5));
            PrintDebug("Close: " + TimeToString((datetime)close_time) + " @ " + DoubleToString(close_price, 5));
        }
        
        DatabaseFinalize(queryRequest);
        PrintDebug("✓ Odczytano " + IntegerToString(rowCount) + " pozycji");
        return true;
    }
    
    bool TestDatabaseStatus()
    {
        PrintDebug("=== STATUS BAZY DANYCH ===");
        PrintDebug("Ścieżka: " + m_db_path);
        PrintDebug("Handle: " + IntegerToString(m_db_handle));
        PrintDebug("Gotowa: " + BoolToString(m_database_ready));
        
        if(m_db_handle == INVALID_HANDLE)
        {
            LogError("Handle bazy nieprawidłowy!", "TestDatabaseStatus");
            return false;
        }
        
        string tablesSQL = "SELECT name FROM sqlite_master WHERE type='table'";
        int tablesRequest = DatabasePrepare(m_db_handle, tablesSQL);
        
        if(tablesRequest != INVALID_HANDLE)
        {
            PrintDebug("Tabele w bazie:");
            while(DatabaseRead(tablesRequest))
            {
                string tableName;
                DatabaseColumnText(tablesRequest, 0, tableName);
                PrintDebug("  - " + tableName);
            }
            DatabaseFinalize(tablesRequest);
        }
        
        return true;
    }
    
    string TimeElapsedToString(const datetime pElapsedSeconds)
    {
        const long days = pElapsedSeconds / PeriodSeconds(PERIOD_D1);
        return((days ? (string)days + "d " : "") + TimeToString(pElapsedSeconds, TIME_SECONDS));
    }
    
    string DealReasonToString(ENUM_DEAL_REASON deal_reason)
    {
        switch(deal_reason)
        {
            case DEAL_REASON_CLIENT: return ("client");
            case DEAL_REASON_MOBILE: return ("mobile");
            case DEAL_REASON_WEB: return ("web");
            case DEAL_REASON_EXPERT: return ("expert");
            case DEAL_REASON_SL: return ("sl");
            case DEAL_REASON_TP: return ("tp");
            case DEAL_REASON_SO: return ("so");
            case DEAL_REASON_ROLLOVER: return ("rollover");
            case DEAL_REASON_VMARGIN: return ("vmargin");
            case DEAL_REASON_SPLIT: return ("split");
            default: return ("unknown");
        }
    }
    
    void Cleanup()
    {
        if(m_db_handle != INVALID_HANDLE)
        {
            DatabaseClose(m_db_handle);
            m_db_handle = INVALID_HANDLE;
        }
        m_database_ready = false;
        m_initialized = false;
        PrintDebug("DatabaseManager: Cleanup completed");
    }
};

// Globalna instancja managera bazy danych
CDatabaseManager Database;
