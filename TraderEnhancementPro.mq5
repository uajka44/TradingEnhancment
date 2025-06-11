//+------------------------------------------------------------------+
//|                                         shortcuts_exporthh5.mq5   |
//|                                  Zrefaktoryzowany Expert Advisor  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "2.00"
#property strict

// Includy wszystkich modułów
#include "Include\Utils.mqh"
#include "Include\ConfigManager.mqh"
#include "Include\TradingManager.mqh"
#include "Include\UIManager.mqh"
#include "Include\DatabaseManagerSimple.mqh"
#include "Include\DrawingManager.mqh"

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    PrintDebug("=== INICJALIZACJA EA ===");
    
    // Inicjalizacja wszystkich modułów w odpowiedniej kolejności
    if(!Config.Initialize())
    {
        LogError("Błąd inicjalizacji ConfigManager", "OnInit");
        return INIT_FAILED;
    }
    
    if(!Trading.Initialize())
    {
        LogError("Błąd inicjalizacji TradingManager", "OnInit");
        return INIT_FAILED;
    }
    
    if(!UI.Initialize())
    {
        LogError("Błąd inicjalizacji UIManager", "OnInit");
        return INIT_FAILED;
    }
    
    if(!Database.Initialize())
    {
        LogError("Błąd inicjalizacji DatabaseManager", "OnInit");
        return INIT_FAILED;
    }
    
    if(!Drawing.Initialize())
    {
        LogError("Błąd inicjalizacji DrawingManager", "OnInit");
        return INIT_FAILED;
    }
    
    // Walidacja konfiguracji
    if(!Config.ValidateConfiguration())
    {
        LogError("Błędna konfiguracja EA", "OnInit");
        return INIT_FAILED;
    }
    
    // Ustawienie timera
    EventSetTimer(10); // 10 sekund
    
    // Wyświetlenie informacji o konfiguracji
    Config.PrintConfiguration();
    
    PrintDebug("=== EA ZAINICJALIZOWANY POMYŚLNIE ===");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    PrintDebug("=== DEINICJALIZACJA EA ===");
    
    // Zatrzymanie timera
    EventKillTimer();
    
    // Cleanup wszystkich modułów
    UI.Cleanup();
    Drawing.Cleanup();
    Database.Cleanup();
    Trading.Cleanup();
    Config.Cleanup();
    
    PrintDebug("=== EA ZAMKNIĘTY ===");
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Sprawdzenie czy nie ma blokady tradingu
    if(Config.IsTradingBlocked())
    {
        PrintDebug("Usuwanie wszystkich zleceń oczekujących - blokada tradingu");
        Trading.DeleteAllPendingOrders();
    }
    
    // Aktualizacja interfejsu
    UI.UpdateInterface();
    
    // Aktualizacja obiektów rysowania
    Drawing.MarkSLTPLevels();
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    switch(id)
    {
        case CHARTEVENT_CLICK:
        {
            // Obsługa kliknięcia na wykresie
            UI.HandleChartClick(lparam, dparam);
            break;
        }
        
        case CHARTEVENT_OBJECT_CLICK:
        {
            // Obsługa kliknięcia na przyciski
            if(UI.IsButtonClick(sparam))
            {
                UI.HandleButtonClick(sparam);
            }
            break;
        }
        
        case CHARTEVENT_KEYDOWN:
        {
            // Obsługa skrótów klawiszowych
            UI.HandleKeyPress(lparam);
            
            // Specjalna obsługa klawisza H - export TYLKO pozycji do bazy danych
            if((int)lparam == 72) // Klawisz H
            {
                if(Database.IsDatabaseReady())
                {
                    PrintDebug("=== ROZPOCZYNAM EKSPORT POZYCJI (klawisz H) ===");
                    Database.ExportHistoryPositionsToSQLite();
                    // Usunięto eksport świeczek - Database.ExportAllSymbols(); 
                    Database.PrintDatabaseStats();
                }
                else
                {
                    LogError("Baza danych nie jest gotowa", "OnChartEvent");
                    Database.TestDatabaseStatus();
                }
            }
            
            // TEST: Klawisz R - odczyt ostatnich 3 pozycji
            else if((int)lparam == 82) // Klawisz R
            {
                if(Database.IsDatabaseReady())
                {
                    Database.TestReadLastPositions();
                }
                else
                {
                    LogError("Baza danych nie jest gotowa", "OnChartEvent");
                    Database.TestDatabaseStatus();
                }
            }
            
            // TEST: Klawisz G - status bazy danych (zmienione z D, żeby nie kolidowało)
            else if((int)lparam == 71) // Klawisz G  
            {
                Database.TestDatabaseStatus();
            }
            
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
{
    // Aktualizacja poziomów SL/TP po każdej operacji tradingowej
    Drawing.MarkSLTPLevels();
    
    // Aktualizacja interfejsu
    UI.UpdateInterface();
}

//+------------------------------------------------------------------+
//| Tick function (opcjonalna)                                      |
//+------------------------------------------------------------------+
void OnTick()
{
    // Można dodać logikę wykonującą się na każdym tiku
    // Na razie pozostawiamy pustą
}
