//+------------------------------------------------------------------+
//|                                              ConfigManager.mqh   |
//|                            Zarządzanie konfiguracją i parametrami|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property strict

#include "Utils.mqh"

//+------------------------------------------------------------------+
//| PARAMETRY INPUT - KONFIGURACJA EA                               |
//+------------------------------------------------------------------+

// === PARAMETRY TRADINGU ===
input int      sl = 10;                                    // Stop Loss (w punktach * 100)
input int      tp = 50;                                    // Take Profit (w punktach * 100) 
input double   default_size = 0.1;                         // Domyślny rozmiar pozycji
input double   button2_size = 0.1;                         // Rozmiar pozycji dla przycisku 2
input double   button3_size = 2;                           // Rozmiar pozycji dla przycisku 3
input double   button_007_size = 0.01;                     // Rozmiar pozycji dla przycisku 007
input double   market_order_size_multiplier = 0.5;         // Mnożnik rozmiaru dla zleceń market

// === PARAMETRY STOP LOSS ===
input int      max_sl_dj = 41;                             // Maksymalny SL dla DJ (Dow Jones)
input int      max_sl = 20;                                // Maksymalny SL domyślny

// === PARAMETRY BREAK EVEN I MODYFIKACJI ===
input double   ile_pkt_be = 1;                            // Ile punktów BE od ceny otwarcia
input int      o_ile_przesunac_be = 1;                    // O ile przesunąć BE
input int      o_ile_przesunac_tp = 5;                    // O ile przesunąć TP

// === PARAMETRY BEZPIECZEŃSTWA ===
input double   maxStrataPunktow = -200;                    // Maksymalna strata w punktach

// === PARAMETRY EKSPORTU DANYCH ===
input ENUM_HISTORY_SORT InpHistorySort = HISTORY_SORT_OPENTIME; // Sortowanie pozycji według
input string   Symbols = "US100.cash,US30.cash,XAUUSD,GER40.cash"; // Instrumenty do eksportu
input datetime StartDate = D'2025.05.01 00:00';           // Data początkowa dla eksportu

//+------------------------------------------------------------------+
//| ZMIENNE GLOBALNE - STAN APLIKACJI                               |
//+------------------------------------------------------------------+

// === STAN TRADINGU ===
bool           take_action = false;                        // Flaga aktywacji akcji tradingowej
string         setup = "";                                 // Aktualny setup tradingowy
double         position_size = 0.1;                        // Aktualny rozmiar pozycji
datetime       przerwa_do = 0;                            // Data zakazu tradingu (zabezpieczenie)
int            current_magic_number = 0;                   // Aktualny magic number

// === ZARZĄDZANIE TICKETAMI ===
int            tickets[10];                                // Tablica przetworzonych ticketów
int            ticket_count = 0;                          // Liczba ticketów w tablicy

// === TIMER I INTERWAŁY ===
int            timerInterval = 10;                         // Interwał timera w sekundach

// === RYSOWANIE LINII ===
bool           isDrawingMode = false;                      // Tryb rysowania półprostych
int            clickCount = 0;                            // Licznik kliknięć
datetime       time1, time2;                              // Czasy dla punktów linii
double         price1, price2;                            // Ceny dla punktów linii
string         rayName = "AutoRay";                       // Prefix nazwy linii
int            rayCounter = 1;                            // Licznik linii
datetime       lastDeleteKeyPress = 0;                    // Ostatnie naciśnięcie Delete
bool           deleteAllMode = false;                      // Tryb usuwania wszystkich linii

// === BAZA DANYCH ===
bool           databaseReady = false;                      // Status gotowości bazy danych
string         symbolArray[];                              // Tablica symboli do eksportu

// === PLIKI I ŚCIEŻKI ===
string         filename = "order_data.csv";               // Plik z danymi zleceń
string         przerwa_filename = "przerwa_do.csv";       // Plik z datą przerwy

// === DŹWIĘKI ===
string         dzwiek_ok = "ok.wav";                      // Dźwięk potwierdzenia
string         dzwiek_2 = "expert.wav";                   // Dźwięk ostrzeżenia

// === STAŁE CZASOWE ===
int            przesuniecie_czasu_platforma_warszawa = 7200; // Różnica czasu platforma-Warszawa (sekundy)

//+------------------------------------------------------------------+
//| KLASA ConfigManager - Zarządzanie konfiguracją                   |
//+------------------------------------------------------------------+
class CConfigManager
{
private:
    bool m_initialized;
    
public:
    CConfigManager() : m_initialized(false) {}
    ~CConfigManager() {}
    
    //+------------------------------------------------------------------+
    //| Inicjalizacja konfiguracji                                       |
    //+------------------------------------------------------------------+
    bool Initialize()
    {
        if(m_initialized) return true;
        
        // Inicjalizacja zmiennych globalnych
        position_size = default_size; // Ustaw domyślny rozmiar z parametru input
        take_action = false;
        setup = "";
        przerwa_do = 0;
        ticket_count = 0;
        
        // Inicjalizacja rysowania
        isDrawingMode = false;
        clickCount = 0;
        rayCounter = 1;
        deleteAllMode = false;
        
        // Wczytanie daty przerwy z pliku
        LoadPrzerwaDo();
        
        // Przygotowanie tablicy symboli
        if(!PrepareSymbolArray())
        {
            LogError("Błąd przygotowania tablicy symboli", "CConfigManager::Initialize");
            return false;
        }
        
        m_initialized = true;
        PrintDebug("ConfigManager zainicjalizowany pomyślnie");
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Przygotowanie tablicy symboli z parametru input                  |
    //+------------------------------------------------------------------+
    bool PrepareSymbolArray()
    {
        StringSplitAndTrim(Symbols, ",", symbolArray);
        
        if(ArraySize(symbolArray) == 0)
        {
            LogError("Brak symboli w konfiguracji", "PrepareSymbolArray");
            return false;
        }
        
        PrintDebug("Przygotowano " + IntegerToString(ArraySize(symbolArray)) + " symboli do eksportu");
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Wczytanie daty przerwy z pliku CSV                               |
    //+------------------------------------------------------------------+
    void LoadPrzerwaDo()
    {
        przerwa_do = ReadDateFromCSVSafe(przerwa_filename);
        // Usunięto debug print - wyświetlany będzie tylko w statusie EA
    }
    
    //+------------------------------------------------------------------+
    //| Sprawdzenie czy jest przerwa w tradingu                          |
    //+------------------------------------------------------------------+
    bool IsTradingBlocked()
    {
        LoadPrzerwaDo(); // Odświeżamy datę z pliku
        return (przerwa_do > TimeCurrent());
    }
    
    //+------------------------------------------------------------------+
    //| Pobiera datę przerwy dla wyświetlenia w statusie                 |
    //+------------------------------------------------------------------+
    string GetPrzerrwaDoString()
    {
        if(przerwa_do > 0)
            return TimeToString(przerwa_do, TIME_DATE|TIME_MINUTES|TIME_SECONDS);
        return "Brak";
    }
    
    //+------------------------------------------------------------------+
    //| Ustawienie rozmiaru pozycji                                      |
    //+------------------------------------------------------------------+
    void SetPositionSize(double size)
    {
        if(size > 0)
        {
            position_size = NormalizeVolume(size);
            PrintDebug("Ustawiono rozmiar pozycji: " + DoubleToStringFormatted(position_size));
        }
    }
    
    //+------------------------------------------------------------------+
    //| Pobranie rozmiaru pozycji                                        |
    //+------------------------------------------------------------------+
    double GetPositionSize() { return position_size; }
    
    //+------------------------------------------------------------------+
    //| Pobranie rozmiarów pozycji dla przycisków                        |
    //+------------------------------------------------------------------+
    double GetButton2Size() { return button2_size; }
    double GetButton3Size() { return button3_size; }
    double GetDefaultSize() { return default_size; }
    
    //+------------------------------------------------------------------+
    //| Pobranie rozmiaru pozycji dla zleceń market                      |
    //+------------------------------------------------------------------+
    double GetMarketPositionSize() 
    { 
        return NormalizeVolume(position_size * market_order_size_multiplier);
    }
    
    //+------------------------------------------------------------------+
    //| Aktywacja/deaktywacja trybu akcji                                |
    //+------------------------------------------------------------------+
    void SetTakeAction(bool action, string setupName = "")
    {
        take_action = action;
        setup = setupName;
        
        if(action)
        {
            PlaySoundSafe(dzwiek_2);
            PrintDebug("Aktywowano tryb akcji: " + setup);
        }
        else
        {
            PrintDebug("Deaktywowano tryb akcji");
        }
    }
    
    bool GetTakeAction() { return take_action; }
    string GetCurrentSetup() { return setup; }
    
    //+------------------------------------------------------------------+
    //| Zarządzanie trybem rysowania                                     |
    //+------------------------------------------------------------------+
    void SetDrawingMode(bool mode)
    {
        isDrawingMode = mode;
        if(mode)
        {
            clickCount = 0;
            PlaySoundSafe(dzwiek_ok);
            PrintDebug("Aktywowano tryb rysowania");
        }
    }
    
    bool GetDrawingMode() { return isDrawingMode; }
    
    //+------------------------------------------------------------------+
    //| Zarządzanie ticketami                                           |
    //+------------------------------------------------------------------+
    bool IsTicketProcessed(int ticket)
    {
        return ArrayContains(tickets, ticket);
    }
    
    void AddTicket(int ticket)
    {
        if(ArrayAddUnique(tickets, ticket, 10))
        {
            ticket_count = ArraySize(tickets);
            PrintDebug("Dodano ticket: " + IntegerToString(ticket));
        }
    }
    
    //+------------------------------------------------------------------+
    //| Pobranie parametrów SL/TP                                       |
    //+------------------------------------------------------------------+
    int GetSL() { return sl; }
    int GetTP() { return tp; }
    int GetMaxSL() { return max_sl; }
    int GetMaxSLDJ() { return max_sl_dj; }
    
    double GetBEPoints() { return ile_pkt_be; }
    int GetBEShift() { return o_ile_przesunac_be; }
    int GetTPShift() { return o_ile_przesunac_tp; }
    
    //+------------------------------------------------------------------+
    //| Pobranie nazw plików dźwiękowych                                 |
    //+------------------------------------------------------------------+
    string GetSoundOK() { return dzwiek_ok; }
    string GetSoundWarning() { return dzwiek_2; }
    
    //+------------------------------------------------------------------+
    //| Informacje o konfiguracji (debug)                               |
    //+------------------------------------------------------------------+
    void PrintConfiguration()
    {
        PrintDebug("=== KONFIGURACJA EA ===");
        PrintDebug("SL/TP: " + IntegerToString(sl) + "/" + IntegerToString(tp));
        PrintDebug("Rozmiary pozycji (1/2/3/007): " + DoubleToStringFormatted(default_size) + 
                  "/" + DoubleToStringFormatted(button2_size) + 
                  "/" + DoubleToStringFormatted(button3_size) + 
                  "/" + DoubleToStringFormatted(button_007_size));
        PrintDebug("Mnożnik market: " + DoubleToStringFormatted(market_order_size_multiplier));
        PrintDebug("BE parametry: " + DoubleToStringFormatted(ile_pkt_be) + 
                  "/" + IntegerToString(o_ile_przesunac_be));
        PrintDebug("Symbole do eksportu: " + Symbols);
        PrintDebug("Data początkowa: " + TimeToString(StartDate));
        PrintDebug("========================");
    }
    
    //+------------------------------------------------------------------+
    //| Sprawdzenie poprawności konfiguracji                            |
    //+------------------------------------------------------------------+
    bool ValidateConfiguration()
    {
        bool isValid = true;
        
        if(sl <= 0 || tp <= 0)
        {
            LogError("SL i TP muszą być większe od 0", "ValidateConfiguration");
            isValid = false;
        }
        
        if(default_size <= 0 || button2_size <= 0 || button3_size <= 0 || button_007_size <= 0)
        {
            LogError("Rozmiary pozycji muszą być większe od 0", "ValidateConfiguration");
            isValid = false;
        }
        
        if(market_order_size_multiplier <= 0 || market_order_size_multiplier > 2.0)
        {
            LogError("Mnożnik market order poza zakresem (0-2.0)", "ValidateConfiguration");
            isValid = false;
        }
        
        if(ArraySize(symbolArray) == 0)
        {
            LogError("Brak symboli do eksportu", "ValidateConfiguration");
            isValid = false;
        }
        
        return isValid;
    }
    
    //+------------------------------------------------------------------+
    //| Gettery dla zmiennych rysowania                                 |
    //+------------------------------------------------------------------+
    int GetClickCount() { return clickCount; }
    void SetClickCount(int count) { clickCount = count; }
    void IncrementClickCount() { clickCount++; }
    
    datetime GetTime1() { return time1; }
    double GetPrice1() { return price1; }
    void SetPoint1(datetime t, double p) { time1 = t; price1 = p; }
    
    datetime GetTime2() { return time2; }
    double GetPrice2() { return price2; }
    void SetPoint2(datetime t, double p) { time2 = t; price2 = p; }
    
    string GetNextRayName() 
    { 
        string name = rayName + IntegerToString(rayCounter);
        rayCounter++;
        return name;
    }
    
    void DecrementRayCounter() { if(rayCounter > 1) rayCounter--; }
    int GetRayCounter() { return rayCounter; }
    
    //+------------------------------------------------------------------+
    //| Gettery dla tablicy symboli                                     |
    //+------------------------------------------------------------------+
    int GetSymbolsCount() { return ArraySize(symbolArray); }
    string GetSymbol(int index) 
    { 
        if(index >= 0 && index < ArraySize(symbolArray))
            return symbolArray[index];
        return "";
    }
    
    //+------------------------------------------------------------------+
    //| Gettery dla parametrów eksportu                                 |
    //+------------------------------------------------------------------+
    ENUM_HISTORY_SORT GetHistorySort() { return InpHistorySort; }
    datetime GetStartDate() { return StartDate; }
    string GetOrderDataFile() { return filename; }
    
    //+------------------------------------------------------------------+
    //| Pobranie rozmiaru pozycji dla przycisku 007                      |
    //+------------------------------------------------------------------+
    double GetButton007Size() { return button_007_size; }
    
    //+------------------------------------------------------------------+
    //| Ustawienie magic number                                          |
    //+------------------------------------------------------------------+
    void SetMagicNumber(int magic)
    {
        current_magic_number = magic;
        PrintDebug("Ustawiono magic number: " + IntegerToString(magic));
    }
    
    //+------------------------------------------------------------------+
    //| Pobranie aktualnego magic number                                 |
    //+------------------------------------------------------------------+
    int GetMagicNumber() { return current_magic_number; }
    
    //+------------------------------------------------------------------+
    //| Cleanup przy zamknięciu                                         |
    //+------------------------------------------------------------------+
    void Cleanup()
    {
        m_initialized = false;
        ArrayResize(symbolArray, 0);
        ArrayResize(tickets, 0);
        PrintDebug("ConfigManager: Cleanup completed");
    }
};

// Globalna instancja managera konfiguracji
CConfigManager Config;
