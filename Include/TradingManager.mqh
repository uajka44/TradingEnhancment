//+------------------------------------------------------------------+
//|                                             TradingManager.mqh   |
//|                               Zarządzanie operacjami tradingowymi |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property strict

#include <Trade\Trade.mqh>
#include "Utils.mqh"
#include "ConfigManager.mqh"

//+------------------------------------------------------------------+
//| KLASA TradingManager - Zarządzanie tradingiem                    |
//+------------------------------------------------------------------+
class CTradingManager
{
private:
    CTrade trade;
    bool m_initialized;
    
public:
    CTradingManager() : m_initialized(false) {}
    ~CTradingManager() {}
    
    //+------------------------------------------------------------------+
    //| Inicjalizacja trading managera                                   |
    //+------------------------------------------------------------------+
    bool Initialize()
    {
        if(m_initialized) return true;
        
        // Konfiguracja obiektu CTrade
        // Magic number będzie ustawiany dynamicznie przez Config.GetMagicNumber()
        trade.SetMarginMode();
        trade.SetTypeFillingBySymbol(_Symbol);
        
        m_initialized = true;
        PrintDebug("TradingManager zainicjalizowany pomyślnie");
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Sprawdzenie czy można handlować                                  |
    //+------------------------------------------------------------------+
    bool CanTrade()
    {
        if(Config.IsTradingBlocked())
        {
            LogError("Trading zablokowany", "CanTrade");
            return false;
        }
        
        if(!IsMarketOpen())
        {
            LogError("Rynek zamknięty dla symbolu: " + _Symbol, "CanTrade");
            return false;
        }
        
        if(IsWeekend())
        {
            LogError("Weekend - trading niedostępny", "CanTrade");
            return false;
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Wykonanie zlecenia Buy Limit                                     |
    //+------------------------------------------------------------------+
    bool ExecuteBuyLimit(double price)
    {
        if(!CanTrade()) return false;
        
        double volume = Config.GetPositionSize();
        double sl_price = price - (Config.GetSL() * 100 * _Point);
        double tp_price = price + (Config.GetTP() * 100 * _Point);
        
        // Walidacja poziomów
        if(!IsValidStopLevel(price, sl_price))
        {
            LogError("Nieprawidłowy poziom SL dla Buy Limit", "ExecuteBuyLimit");
            return false;
        }
        
        // Ustawienie magic number
        trade.SetExpertMagicNumber(Config.GetMagicNumber());
        
        bool result = trade.BuyLimit(
            volume,
            price,
            _Symbol,
            sl_price,
            tp_price,
            ORDER_TIME_GTC,
            0,
            Config.GetCurrentSetup()
        );
        
        if(result)
        {
            PrintDebug("Buy Limit wykonane: " + DoubleToStringFormatted(price) + 
                      " Volume: " + DoubleToStringFormatted(volume));
            PlaySoundSafe(Config.GetSoundOK());
            SaveOrderData(trade.ResultOrder(), sl_price);
        }
        else
        {
            LogError("Błąd Buy Limit: " + trade.ResultRetcodeDescription(), "ExecuteBuyLimit");
        }
        
        return result;
    }
    
    //+------------------------------------------------------------------+
    //| Wykonanie zlecenia Sell Limit                                    |
    //+------------------------------------------------------------------+
    bool ExecuteSellLimit(double price)
    {
        if(!CanTrade()) return false;
        
        double volume = Config.GetPositionSize();
        double sl_price = price + (Config.GetSL() * 100 * _Point);
        double tp_price = price - (Config.GetTP() * 100 * _Point);
        
        // Walidacja poziomów
        if(!IsValidStopLevel(price, sl_price))
        {
            LogError("Nieprawidłowy poziom SL dla Sell Limit", "ExecuteSellLimit");
            return false;
        }
        
        // Ustawienie magic number
        trade.SetExpertMagicNumber(Config.GetMagicNumber());
        
        bool result = trade.SellLimit(
            volume,
            price,
            _Symbol,
            sl_price,
            tp_price,
            ORDER_TIME_GTC,
            0,
            Config.GetCurrentSetup()
        );
        
        if(result)
        {
            PrintDebug("Sell Limit wykonane: " + DoubleToStringFormatted(price) + 
                      " Volume: " + DoubleToStringFormatted(volume));
            PlaySoundSafe(Config.GetSoundOK());
            SaveOrderData(trade.ResultOrder(), sl_price);
        }
        else
        {
            LogError("Błąd Sell Limit: " + trade.ResultRetcodeDescription(), "ExecuteSellLimit");
        }
        
        return result;
    }
    
    //+------------------------------------------------------------------+
    //| Wykonanie zlecenia Buy Market                                    |
    //+------------------------------------------------------------------+
    bool ExecuteBuyMarket()
    {
        if(!CanTrade()) return false;
        
        double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
        double volume = Config.GetMarketPositionSize();
        double sl_price = Ask - (Config.GetSL() * 100 * _Point);
        double tp_price = Ask + (Config.GetTP() * 100 * _Point);
        
        bool result = trade.Buy(
            volume,
            _Symbol,
            Ask,
            sl_price,
            tp_price,
            "market"
        );
        
        if(result)
        {
            PrintDebug("Buy Market wykonane: " + DoubleToStringFormatted(Ask) + 
                      " Volume: " + DoubleToStringFormatted(volume));
            PlaySoundSafe(Config.GetSoundOK());
            SaveOrderData(trade.ResultOrder(), sl_price);
        }
        else
        {
            LogError("Błąd Buy Market: " + trade.ResultRetcodeDescription() + 
                    " Volume: " + DoubleToStringFormatted(volume), "ExecuteBuyMarket");
        }
        
        return result;
    }
    
    //+------------------------------------------------------------------+
    //| Wykonanie zlecenia Sell Market                                   |
    //+------------------------------------------------------------------+
    bool ExecuteSellMarket()
    {
        if(!CanTrade()) return false;
        
        double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
        double volume = Config.GetMarketPositionSize();
        double sl_price = Bid + (Config.GetSL() * 100 * _Point);
        double tp_price = Bid - (Config.GetTP() * 100 * _Point);
        
        bool result = trade.Sell(
            volume,
            _Symbol,
            Bid,
            sl_price,
            tp_price,
            "market"
        );
        
        if(result)
        {
            PrintDebug("Sell Market wykonane: " + DoubleToStringFormatted(Bid) + 
                      " Volume: " + DoubleToStringFormatted(volume));
            PlaySoundSafe(Config.GetSoundOK());
            SaveOrderData(trade.ResultOrder(), sl_price);
        }
        else
        {
            LogError("Błąd Sell Market: " + trade.ResultRetcodeDescription() + 
                    " Volume: " + DoubleToStringFormatted(volume), "ExecuteSellMarket");
        }
        
        return result;
    }
    
    //+------------------------------------------------------------------+
    //| Modyfikacja Stop Loss (Break Even)                               |
    //+------------------------------------------------------------------+
    void ModifyStopLoss()
    {
        int positions_count = PositionsTotal();
        PrintDebug("Modyfikacja SL dla " + IntegerToString(positions_count) + " pozycji");
        
        for(int i = positions_count - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            
            if(PositionSelectByTicket(ticket))
            {
                double sl_pozycji = PositionGetDouble(POSITION_SL);
                double cena_otwarcia = PositionGetDouble(POSITION_PRICE_OPEN);
                double profit = PositionGetDouble(POSITION_PROFIT);
                ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                
                if(profit > 0)
                {
                    // Pozycja w zysku - ustawiamy BE lub przesuwamy dalej
                    ModifyStopLossProfit(ticket, sl_pozycji, cena_otwarcia, pos_type);
                }
                else
                {
                    // Pozycja w stracie - przesuwamy SL w przeciwnym kierunku
                    ModifyStopLossLoss(ticket, sl_pozycji, pos_type);
                }
            }
        }
    }
    
    //+------------------------------------------------------------------+
    //| Modyfikacja SL dla pozycji w zysku                              |
    //+------------------------------------------------------------------+
    void ModifyStopLossProfit(ulong ticket, double sl_pozycji, double cena_otwarcia, ENUM_POSITION_TYPE pos_type)
    {
        double new_sl = sl_pozycji;
        
        if(pos_type == POSITION_TYPE_BUY)
        {
            if(sl_pozycji - cena_otwarcia > 0) // Już ustawione BE
            {
                new_sl = sl_pozycji + Config.GetBEShift();
            }
            else
            {
                new_sl = cena_otwarcia + Config.GetBEPoints();
            }
        }
        else if(pos_type == POSITION_TYPE_SELL)
        {
            if(sl_pozycji - cena_otwarcia < 0) // Już ustawione BE
            {
                new_sl = sl_pozycji - Config.GetBEShift();
            }
            else
            {
                new_sl = cena_otwarcia - Config.GetBEPoints();
            }
        }
        
        if(trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP)))
        {
            PrintDebug("SL zmodyfikowany dla ticket: " + IntegerToString(ticket));
        }
        else
        {
            LogError("Błąd modyfikacji SL: " + trade.ResultRetcodeDescription(), "ModifyStopLossProfit");
        }
    }
    
    //+------------------------------------------------------------------+
    //| Modyfikacja SL dla pozycji w stracie                            |
    //+------------------------------------------------------------------+
    void ModifyStopLossLoss(ulong ticket, double sl_pozycji, ENUM_POSITION_TYPE pos_type)
    {
        double new_sl = sl_pozycji;
        double shift = Config.GetBEShift() * 2;
        
        if(pos_type == POSITION_TYPE_BUY)
        {
            new_sl = sl_pozycji - shift;
        }
        else if(pos_type == POSITION_TYPE_SELL)
        {
            new_sl = sl_pozycji + shift;
        }
        
        if(trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP)))
        {
            PrintDebug("SL przesunięty (strata) dla ticket: " + IntegerToString(ticket));
        }
        else
        {
            LogError("Błąd przesunięcia SL: " + trade.ResultRetcodeDescription(), "ModifyStopLossLoss");
        }
    }
    
    //+------------------------------------------------------------------+
    //| Modyfikacja Take Profit                                         |
    //+------------------------------------------------------------------+
    void ModifyTakeProfit()
    {
        int positions_count = PositionsTotal();
        PrintDebug("Modyfikacja TP dla " + IntegerToString(positions_count) + " pozycji");
        
        for(int i = positions_count - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            
            if(PositionSelectByTicket(ticket))
            {
                double tp_pozycji = PositionGetDouble(POSITION_TP);
                ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                double new_tp = tp_pozycji;
                
                if(pos_type == POSITION_TYPE_BUY)
                {
                    new_tp = tp_pozycji + Config.GetTPShift();
                }
                else if(pos_type == POSITION_TYPE_SELL)
                {
                    new_tp = tp_pozycji - Config.GetTPShift();
                }
                
                if(trade.PositionModify(ticket, PositionGetDouble(POSITION_SL), new_tp))
                {
                    PrintDebug("TP zmodyfikowany dla ticket: " + IntegerToString(ticket));
                }
                else
                {
                    LogError("Błąd modyfikacji TP: " + trade.ResultRetcodeDescription(), "ModifyTakeProfit");
                }
            }
        }
    }
    

    
    //+------------------------------------------------------------------+
    //| Ustawienie Take Profit na +0.5 punktu od ceny otwarcia          |
    //+------------------------------------------------------------------+
    void SetTPToHalfPoint()
    {
        int positions_count = PositionsTotal();
        PrintDebug("Ustawianie TP na +0.5 punktu od otwarcia dla " + IntegerToString(positions_count) + " pozycji");
        
        for(int i = positions_count - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            
            if(PositionSelectByTicket(ticket))
            {
                double cena_otwarcia = PositionGetDouble(POSITION_PRICE_OPEN);
                ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                double new_tp = 0;
                
                if(pos_type == POSITION_TYPE_BUY)
                {
                    // Dla BUY: TP = cena otwarcia + 0.5 punktu
                    new_tp = cena_otwarcia + 0.5;
                }
                else if(pos_type == POSITION_TYPE_SELL)
                {
                    // Dla SELL: TP = cena otwarcia - 0.5 punktu  
                    new_tp = cena_otwarcia - 0.5;
                }
                
                // Normalizuj cenę do odpowiedniej liczby miejsc dziesiętnych
                new_tp = NormalizeDouble(new_tp, _Digits);
                
                if(trade.PositionModify(ticket, PositionGetDouble(POSITION_SL), new_tp))
                {
                    PrintDebug("TP ustawiony na +0.5 punktu od otwarcia dla ticket: " + IntegerToString(ticket) + 
                              " (otwarcie: " + DoubleToString(cena_otwarcia, _Digits) + 
                              ", nowy TP: " + DoubleToString(new_tp, _Digits) + ")");
                    PlaySoundSafe(Config.GetSoundOK());
                }
                else
                {
                    LogError("Błąd ustawiania TP na +0.5: " + trade.ResultRetcodeDescription(), "SetTPToHalfPoint");
                }
            }
        }
    }

    
    //+------------------------------------------------------------------+
    //| Usunięcie wszystkich zleceń oczekujących                         |
    //+------------------------------------------------------------------+
    void DeleteAllPendingOrders()
    {
        uint total = OrdersTotal();
        int deleted_count = 0;
        
        PrintDebug("Usuwanie " + IntegerToString(total) + " zleceń oczekujących");
        
        for(uint i = 0; i < total; i++)
        {
            if(trade.OrderDelete(OrderGetTicket(0)))
            {
                deleted_count++;
            }
            else
            {
                LogError("Błąd usuwania zlecenia: " + trade.ResultRetcodeDescription(), "DeleteAllPendingOrders");
            }
        }
        
        PrintDebug("Usunięto " + IntegerToString(deleted_count) + " zleceń");
    }
    
    //+------------------------------------------------------------------+
    //| Zamknięcie wszystkich pozycji                                   |
    //+------------------------------------------------------------------+
    void CloseAllPositions()
    {
        uint total = PositionsTotal();
        int closed_count = 0;
        
        PrintDebug("Zamykanie " + IntegerToString(total) + " pozycji");
        
        for(uint i = 0; i < total; i++)
        {
            if(trade.PositionClose(PositionGetTicket(0)))
            {
                closed_count++;
            }
            else
            {
                LogError("Błąd zamykania pozycji: " + trade.ResultRetcodeDescription(), "CloseAllPositions");
            }
        }
        
        PrintDebug("Zamknięto " + IntegerToString(closed_count) + " pozycji");
    }
    
    //+------------------------------------------------------------------+
    //| Zamknięcie ostatniej pozycji                                    |
    //+------------------------------------------------------------------+
    void CloseLastPosition()
    {
        if(PositionsTotal() > 0)
        {
            ulong ticket = PositionGetTicket(0);
            if(trade.PositionClose(ticket))
            {
                PrintDebug("Zamknięto ostatnią pozycję: " + IntegerToString(ticket));
            }
            else
            {
                LogError("Błąd zamykania ostatniej pozycji: " + trade.ResultRetcodeDescription(), "CloseLastPosition");
            }
        }
        else
        {
            PrintDebug("Brak pozycji do zamknięcia");
        }
    }
    
    //+------------------------------------------------------------------+
    //| Zapisanie danych zlecenia do pliku CSV                          |
    //+------------------------------------------------------------------+
    void SaveOrderData(int ticket, double stopLoss)
    {
        string filename = Config.GetOrderDataFile();
        int file_handle = FileOpen(filename, FILE_READ | FILE_WRITE | FILE_TXT | FILE_CSV | FILE_ANSI, ',');
        
        if(file_handle != INVALID_HANDLE)
        {
            // Ustaw wskaźnik na koniec pliku
            FileSeek(file_handle, 0, SEEK_END);
            FileWrite(file_handle, ticket, stopLoss);
            FileClose(file_handle);
            PrintDebug("Zapisano dane zlecenia: " + IntegerToString(ticket));
        }
        else
        {
            LogError("Błąd zapisywania danych zlecenia do pliku: " + filename, "SaveOrderData");
        }
    }
    
    //+------------------------------------------------------------------+
    //| Sprawdzenie limitu strat na dziś                                |
    //+------------------------------------------------------------------+
    bool CheckDailyLossLimit()
    {
        // Można dodać logikę sprawdzania dziennych strat
        // Na razie zwracamy true
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Pobranie informacji o aktualnych pozycjach                      |
    //+------------------------------------------------------------------+
    string GetPositionsInfo()
    {
        int total = PositionsTotal();
        if(total == 0)
            return "Brak otwartych pozycji";
            
        string info = "Otwarte pozycje (" + IntegerToString(total) + "):\n";
        
        for(int i = 0; i < total; i++)
        {
            if(PositionSelectByTicket(PositionGetTicket(i)))
            {
                string symbol = PositionGetString(POSITION_SYMBOL);
                string type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL";
                double volume = PositionGetDouble(POSITION_VOLUME);
                double profit = PositionGetDouble(POSITION_PROFIT);
                
                info += symbol + " " + type + " " + DoubleToStringFormatted(volume) + 
                       " P/L: " + DoubleToStringFormatted(profit) + "\n";
            }
        }
        
        return info;
    }
    
    //+------------------------------------------------------------------+
    //| Cleanup przy zamknięciu                                         |
    //+------------------------------------------------------------------+
    void Cleanup()
    {
        m_initialized = false;
        PrintDebug("TradingManager: Cleanup completed");
    }
};

// Globalna instancja managera tradingu
CTradingManager Trading;
