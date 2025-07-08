//+------------------------------------------------------------------+
//|                                                 UIManager.mqh     |
//|                                     Zarządzanie interfejsem użytk.|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property strict

#include "Utils.mqh"
#include "ConfigManager.mqh"
#include "TradingManager.mqh"

//+------------------------------------------------------------------+
//| KLASA UIManager - Zarządzanie interfejsem użytkownika            |
//+------------------------------------------------------------------+
class CUIManager
{
private:
    bool m_initialized;
    bool keyBPressed;
    datetime lastButtonClickTime; // DODAJ - czas ostatniego kliknięcia przycisku
    
    // Zmienne do zapamiętania poprzedniego stanu przed użyciem przycisku 007
    double previousPositionSize;
    int previousMagicNumber;
    string previousActiveButton;
    
    // Pozycje przycisków
    int button_x_start;
    int button_y_position;
    int button_width;
    int button_height;
    int button_spacing;
    
public:
    CUIManager() : m_initialized(false), keyBPressed(false), lastButtonClickTime(0),
                   previousPositionSize(0), previousMagicNumber(0), previousActiveButton("") {} // DODAJ inicjalizację
    ~CUIManager() {}
    
    //+------------------------------------------------------------------+
    //| Inicjalizacja UI managera                                       |
    //+------------------------------------------------------------------+
    bool Initialize()
    {
        if(m_initialized) return true;
        
        // Ustawienia pozycji przycisków
        button_x_start = 250;
        button_y_position = 30;
        button_width = 60;
        button_height = 30;
        button_spacing = 70;
        
        CreateButtons();
        
        m_initialized = true;
        PrintDebug("UIManager zainicjalizowany pomyślnie");
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Tworzenie wszystkich przycisków                                 |
    //+------------------------------------------------------------------+
    void CreateButtons()
    {
        // Przyciski rozmiaru pozycji - używamy wartości z parametrów input
        CreateButton("Button1", DoubleToStringFormatted(Config.GetDefaultSize()), button_x_start, button_y_position, clrDarkGray);
        ObjectSetInteger(0, "Button1", OBJPROP_STATE, 1); // Domyślnie aktywny
        
        CreateButton("Button2", DoubleToStringFormatted(Config.GetButton2Size()), button_x_start + button_spacing, button_y_position, clrDarkGray);
        CreateButton("Button3", DoubleToStringFormatted(Config.GetButton3Size()), button_x_start + button_spacing * 2, button_y_position, clrDarkGray);
        
        // NOWY PRZYCISK 007
        CreateButton("Button_007", "?? " + DoubleToStringFormatted(Config.GetButton007Size()), button_x_start + button_spacing * 3, button_y_position, clrGold);
        
        // Przycisk Break Even (przesunięty o jedną pozycję)
        CreateButton("Button_BE", "BE", button_x_start + button_spacing * 4, button_y_position, clrLightBlue);
        
        PrintDebug("Utworzono przyciski interfejsu");
    }
    
    //+------------------------------------------------------------------+
    //| Tworzenie pojedynczego przycisku                                |
    //+------------------------------------------------------------------+
    void CreateButton(string name, string label, int x, int y, color kolor)
    {
        ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, name, OBJPROP_XSIZE, button_width);
        ObjectSetInteger(0, name, OBJPROP_YSIZE, button_height);
        ObjectSetString(0, name, OBJPROP_TEXT, label);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack);
        ObjectSetInteger(0, name, OBJPROP_BGCOLOR, kolor);
        ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrBlue);
    }
    
    //+------------------------------------------------------------------+
    //| Aktualizacja koloru przycisku                                   |
    //+------------------------------------------------------------------+
    void UpdateButtonColor(string name, color kolor_wcisniety, color kolor_puszczony)
    {
        bool pressed = ObjectGetInteger(0, name, OBJPROP_STATE);
        if(pressed)
            ObjectSetInteger(0, name, OBJPROP_BGCOLOR, kolor_wcisniety);
        else
            ObjectSetInteger(0, name, OBJPROP_BGCOLOR, kolor_puszczony);
    }
    
    //+------------------------------------------------------------------+
    //| Obsługa kliknięcia przycisku                                    |
    //+------------------------------------------------------------------+
    void HandleButtonClick(string buttonName)
    {
        lastButtonClickTime = TimeCurrent(); // DODAJ - zapisz czas kliknięcia
        
        if(buttonName == "Button1")
        {
            Config.SetPositionSize(Config.GetDefaultSize());
            Config.SetMagicNumber(0); // Resetuj magic number
            SetActiveButton("Button1");
            PrintDebug("Ustawiono rozmiar pozycji: Button1 (" + DoubleToStringFormatted(Config.GetDefaultSize()) + ")");
        }
        else if(buttonName == "Button2")
        {
            Config.SetPositionSize(Config.GetButton2Size());
            Config.SetMagicNumber(0); // Resetuj magic number
            SetActiveButton("Button2");
            PrintDebug("Ustawiono rozmiar pozycji: Button2 (" + DoubleToStringFormatted(Config.GetButton2Size()) + ")");
        }
        else if(buttonName == "Button3")
        {
            Config.SetPositionSize(Config.GetButton3Size());
            Config.SetMagicNumber(0); // Resetuj magic number
            SetActiveButton("Button3");
            PrintDebug("Ustawiono rozmiar pozycji: Button3 (" + DoubleToStringFormatted(Config.GetButton3Size()) + ")");
        }
        // NOWA OBSŁUGA PRZYCISKU 007
        else if(buttonName == "Button_007")
        {
            // Zapamiętaj poprzedni stan przed zmianą
            previousPositionSize = Config.GetPositionSize();
            previousMagicNumber = Config.GetMagicNumber();
            previousActiveButton = GetActiveButton();
            
            // Ustaw nowe wartości dla 007
            Config.SetPositionSize(Config.GetButton007Size());
            Config.SetMagicNumber(007); // Ustaw magic number na 007
            Config.SetTakeAction(true, "Magic007"); // Automatycznie aktywuj tryb akcji
            SetActiveButton("Button_007");
            PrintDebug("Ustawiono rozmiar pozycji: Button_007 (" + DoubleToStringFormatted(Config.GetButton007Size()) + ") z Magic Number: 007");
            PrintDebug("Zapamiętano poprzedni stan: rozmiar=" + DoubleToStringFormatted(previousPositionSize) + ", magic=" + IntegerToString(previousMagicNumber) + ", przycisk=" + previousActiveButton);
            PlaySoundSafe(Config.GetSoundOK()); // Odtwórz dźwięk potwierdzenia
        }
        else if(buttonName == "Button_BE")
        {
            Trading.ModifyStopLoss();
            PrintDebug("Wykonano modyfikację SL (Break Even)");
        }
    }
    
    //+------------------------------------------------------------------+
    //| Pobranie nazwy aktualnie aktywnego przycisku                     |
    //+------------------------------------------------------------------+
    string GetActiveButton()
    {
        if(ObjectGetInteger(0, "Button1", OBJPROP_STATE) == 1) return "Button1";
        if(ObjectGetInteger(0, "Button2", OBJPROP_STATE) == 1) return "Button2";
        if(ObjectGetInteger(0, "Button3", OBJPROP_STATE) == 1) return "Button3";
        if(ObjectGetInteger(0, "Button_007", OBJPROP_STATE) == 1) return "Button_007";
        return "Button1"; // Domyślny
    }
    
    //+------------------------------------------------------------------+
    //| Ustawienie aktywnego przycisku (resetuje pozostałe)             |
    //+------------------------------------------------------------------+
    void SetActiveButton(string activeButton)
    {
        // Resetuj wszystkie przyciski
        ObjectSetInteger(0, "Button1", OBJPROP_STATE, 0);
        ObjectSetInteger(0, "Button2", OBJPROP_STATE, 0);
        ObjectSetInteger(0, "Button3", OBJPROP_STATE, 0);
        ObjectSetInteger(0, "Button_007", OBJPROP_STATE, 0); // DODAJ
        
        // Ustaw aktywny przycisk
        ObjectSetInteger(0, activeButton, OBJPROP_STATE, 1);
    }
    
    //+------------------------------------------------------------------+
    //| Obsługa kliknięcia na wykresie                                  |
    //+------------------------------------------------------------------+
    void HandleChartClick(long lparam, double dparam)
    {
        // Sprawdzenie czy nie kliknięto niedawno przycisku (zabezpieczenie przed podwójnym kliknięciem)
        if(TimeCurrent() - lastButtonClickTime < 1)
        {
            PrintDebug("Ignoruję kliknięcie na wykresie - niedawno kliknięto przycisk");
            return;
        }
        
        datetime time;
        double price_on_click;
        int subwindow;
        
        if(!ChartXYToTimePrice(0, lparam, dparam, subwindow, time, price_on_click))
            return;
            
        // Obsługa trybu rysowania półprostej
        if(Config.GetDrawingMode())
        {
            HandleDrawingClick(time, price_on_click);
            return;
        }
        
        // Obsługa standardowego kliknięcia trading
        if(Config.GetTakeAction())
        {
            HandleTradingClick(price_on_click);
        }
    }
    
    //+------------------------------------------------------------------+
    //| Obsługa kliknięcia w trybie rysowania                           |
    //+------------------------------------------------------------------+
    void HandleDrawingClick(datetime time, double price_on_click)
    {
        // Sprawdzenie, czy kliknięcie jest nad/pod świeczką
        int bar = iBarShift(_Symbol, PERIOD_CURRENT, time);
        double high = iHigh(_Symbol, PERIOD_CURRENT, bar);
        double low = iLow(_Symbol, PERIOD_CURRENT, bar);
        
        // Dostosowanie ceny do granic świeczki
        if(price_on_click > high)
            price_on_click = high;
        else if(price_on_click < low)
            price_on_click = low;
        else
            return; // Kliknięcie w środku świeczki - ignoruj
            
        int clickCount = Config.GetClickCount();
        
        if(clickCount == 0)
        {
            // Pierwszy punkt
            Config.SetPoint1(time, price_on_click);
            Config.IncrementClickCount();
        }
        else if(clickCount == 1)
        {
            // Drugi punkt - narysuj linię
            Config.SetPoint2(time, price_on_click);
            
            string rayName = Config.GetNextRayName();
            
            // Usuń istniejącą linię o tej samej nazwie
            ObjectDelete(0, rayName);
            
            // Utwórz półprostą
            ObjectCreate(0, rayName, OBJ_TREND, 0, Config.GetTime1(), Config.GetPrice1(), time, price_on_click);
            ObjectSetInteger(0, rayName, OBJPROP_RAY_RIGHT, true);
            ObjectSetInteger(0, rayName, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, rayName, OBJPROP_WIDTH, 2);
            ObjectSetString(0, rayName, OBJPROP_TEXT, "AutoRay " + IntegerToString(Config.GetRayCounter() - 1));
            
            // Reset trybu rysowania
            Config.SetDrawingMode(false);
            ChartRedraw();
            
            PrintDebug("Narysowano półprostą: " + rayName);
        }
    }
    
    //+------------------------------------------------------------------+
    //| Obsługa kliknięcia trading                                      |
    //+------------------------------------------------------------------+
    void HandleTradingClick(double price_on_click)
    {
        if(Config.IsTradingBlocked())
        {
            MessageBox("Zakaz brania trejdu!");
            Config.SetTakeAction(false);
            return;
        }
        
        double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
        double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
        
        bool success = false;
        
        if(Bid > price_on_click)
        {
            // Buy Limit
            success = Trading.ExecuteBuyLimit(price_on_click);
        }
        else if(Ask < price_on_click)
        {
            // Sell Limit
            success = Trading.ExecuteSellLimit(price_on_click);
        }
        
        if(success)
        {
            Config.SetTakeAction(false);
            
            // Jeśli używano przycisku 007, przywróć poprzedni stan
            if(Config.GetMagicNumber() == 007)
            {
                Config.SetPositionSize(previousPositionSize);
                Config.SetMagicNumber(previousMagicNumber);
                SetActiveButton(previousActiveButton);
                PrintDebug("Przywrócono poprzedni stan po użyciu przycisku 007: rozmiar=" + DoubleToStringFormatted(previousPositionSize) + ", magic=" + IntegerToString(previousMagicNumber) + ", przycisk=" + previousActiveButton);
            }
        }
    }
    
    //+------------------------------------------------------------------+
    //| Obsługa naciśnięć klawiszy                                      |
    //+------------------------------------------------------------------+
    void HandleKeyPress(long lparam)
    {
        switch((int)lparam)
        {
            // Klawisz 1 - aktywacja trybu rysowania półprostej
            case 49:
                Config.SetDrawingMode(true);
                PlaySoundSafe(Config.GetSoundOK());
                break;
                
            // Klawisz 2 - ustawienie rozmiaru pozycji i aktywacja
            case 50:
                Config.SetPositionSize(Config.GetButton2Size());
                SetActiveButton("Button2");
                Config.SetTakeAction(true, "Size2");
                break;
                
            // Klawisz 3 - ustawienie rozmiaru pozycji i aktywacja
            case 51:
                Config.SetPositionSize(Config.GetButton3Size());
                SetActiveButton("Button3");
                Config.SetTakeAction(true, "Size3");
                break;
                
            // Klawisz 7 - aktywacja przycisku 007
            case 55: // Klawisz 7
                // Zapamiętaj poprzedni stan przed zmianą
                previousPositionSize = Config.GetPositionSize();
                previousMagicNumber = Config.GetMagicNumber();
                previousActiveButton = GetActiveButton();
                
                Config.SetPositionSize(Config.GetButton007Size());
                Config.SetMagicNumber(007);
                Config.SetTakeAction(true, "Magic007_Key");
                SetActiveButton("Button_007");
                PlaySoundSafe(Config.GetSoundOK());
                PrintDebug("Aktywowano przycisk 007 klawiszem 7");
                PrintDebug("Zapamiętano poprzedni stan: rozmiar=" + DoubleToStringFormatted(previousPositionSize) + ", magic=" + IntegerToString(previousMagicNumber) + ", przycisk=" + previousActiveButton);
                break;
                
            // Klawisz C - aktywacja/deaktywacja buy limit
            case 67:
                if(Config.GetTakeAction())
                {
                    Config.SetTakeAction(false);
                }
                else
                {
                    Config.SetTakeAction(true, "Manual");
                }
                break;
                
            // Klawisz B - BUY market
            case 66:
                Trading.DeleteAllPendingOrders();
                Trading.ExecuteBuyMarket();
                break;
                
            // Klawisz S - SELL market
            case 83:
                Trading.DeleteAllPendingOrders();
                Trading.ExecuteSellMarket();
                break;
                
            // Klawisz E - przesunięcie BE
            case 69:
                Trading.ModifyStopLoss();
                break;
                
            // Klawisz F - przesunięcie TP
            case 70:
                Trading.ModifyTakeProfit();
                break;
                
            // Klawisz Q - zamknięcie ostatniej pozycji
            case 81:
                Trading.CloseLastPosition();
                break;
                
            // Klawisz T - usunięcie wszystkich zleceń oczekujących
            case 84:
                Trading.DeleteAllPendingOrders();
                break;
                
            // Klawisz D - usuwanie linii (pojedynczo lub wszystkie)
            case 68:
                HandleDeleteLines();
                break;
        }
    }
    
    //+------------------------------------------------------------------+
    //| Obsługa usuwania linii                                          |
    //+------------------------------------------------------------------+
    void HandleDeleteLines()
    {
        static datetime lastDeleteKeyPress = 0;
        datetime currentTime = TimeCurrent();
        
        if(currentTime - lastDeleteKeyPress < 1)
        {
            // Podwójne naciśnięcie - usuń wszystkie linie
            DeleteAllRays();
            PlaySoundSafe(Config.GetSoundOK());
            PrintDebug("Usunięto wszystkie półproste");
        }
        else if(Config.GetRayCounter() > 1)
        {
            // Pojedyncze naciśnięcie - usuń ostatnią linię
            Config.DecrementRayCounter();
            string lastRayName = "AutoRay" + IntegerToString(Config.GetRayCounter());
            if(ObjectDelete(0, lastRayName))
            {
                PlaySoundSafe(Config.GetSoundOK());
                PrintDebug("Usunięto półprostą: " + lastRayName);
            }
        }
        
        lastDeleteKeyPress = currentTime;
        ChartRedraw();
    }
    
    //+------------------------------------------------------------------+
    //| Usunięcie wszystkich półprostych                                |
    //+------------------------------------------------------------------+
    void DeleteAllRays()
    {
        for(int i = 1; i < Config.GetRayCounter(); i++)
        {
            string currentRayName = "AutoRay" + IntegerToString(i);
            ObjectDelete(0, currentRayName);
        }
    }
    
    //+------------------------------------------------------------------+
    //| Wyświetlenie informacji o statusie                              |
    //+------------------------------------------------------------------+
    void ShowStatusInfo()
    {
        string info = "=== STATUS EA ===\n";
        info += "Rozmiar pozycji: " + DoubleToStringFormatted(Config.GetPositionSize()) + "\n";
        info += "Magic Number: " + IntegerToString(Config.GetMagicNumber()) + "\n"; // DODAJ
        info += "Tryb akcji: " + BoolToString(Config.GetTakeAction()) + "\n";
        info += "Setup: " + Config.GetCurrentSetup() + "\n";
        info += "Tryb rysowania: " + BoolToString(Config.GetDrawingMode()) + "\n";
        info += "Trading zablokowany: " + BoolToString(Config.IsTradingBlocked()) + "\n";
        info += "Data przerwy: " + Config.GetPrzerrwaDoString() + "\n";
        info += "\n" + Trading.GetPositionsInfo();
        
        Comment(info);
        // Uwaga: Rozmiar czcionki komentarza można zmienić tylko ręcznie w ustawieniach MT5
        // Properties -> Fonts -> Comments -> Font Size
    }
    
    //+------------------------------------------------------------------+
    //| Aktualizacja etykiet przycisków zgodnie z parametrami input       |
    //+------------------------------------------------------------------+
    void UpdateButtonLabels()
    {
        ObjectSetString(0, "Button1", OBJPROP_TEXT, DoubleToStringFormatted(Config.GetDefaultSize()));
        ObjectSetString(0, "Button2", OBJPROP_TEXT, DoubleToStringFormatted(Config.GetButton2Size()));
        ObjectSetString(0, "Button3", OBJPROP_TEXT, DoubleToStringFormatted(Config.GetButton3Size()));
        ObjectSetString(0, "Button_007", OBJPROP_TEXT, "?? " + DoubleToStringFormatted(Config.GetButton007Size())); // DODAJ
    }
    
    //+------------------------------------------------------------------+
    //| Aktualizacja interfejsu (wywoływana regularnie)                 |
    //+------------------------------------------------------------------+
    void UpdateInterface()
    {
        // Aktualizuj etykiety przycisków (ważne dla nowych parametrów input)
        UpdateButtonLabels();
        
        // Aktualizuj status
        ShowStatusInfo();
        
        // Aktualizuj kolory przycisków w zależności od stanu
        if(Config.GetTakeAction())
        {
            // Zmień kolor gdy tryb akcji aktywny
            ObjectSetInteger(0, "Button1", OBJPROP_BORDER_COLOR, clrRed);
            ObjectSetInteger(0, "Button2", OBJPROP_BORDER_COLOR, clrRed);
            ObjectSetInteger(0, "Button3", OBJPROP_BORDER_COLOR, clrRed);
            ObjectSetInteger(0, "Button_007", OBJPROP_BORDER_COLOR, clrRed); // DODAJ
        }
        else
        {
            // Przywróć normalny kolor
            ObjectSetInteger(0, "Button1", OBJPROP_BORDER_COLOR, clrBlue);
            ObjectSetInteger(0, "Button2", OBJPROP_BORDER_COLOR, clrBlue);
            ObjectSetInteger(0, "Button3", OBJPROP_BORDER_COLOR, clrBlue);
            ObjectSetInteger(0, "Button_007", OBJPROP_BORDER_COLOR, clrBlue); // DODAJ
        }
    }
    
    //+------------------------------------------------------------------+
    //| Usunięcie wszystkich obiektów UI                                |
    //+------------------------------------------------------------------+
    void DeleteAllUIObjects()
    {
        ObjectDelete(0, "Button1");
        ObjectDelete(0, "Button2");
        ObjectDelete(0, "Button3");
        ObjectDelete(0, "Button_007"); // DODAJ
        ObjectDelete(0, "Button_BE");
        
        // Usuń wszystkie półproste
        DeleteAllRays();
        
        // Usuń komentarz
        Comment("");
        
        PrintDebug("Usunięto wszystkie obiekty UI");
    }
    
    //+------------------------------------------------------------------+
    //| Sprawdzenie czy kliknięto na przycisk                           |
    //+------------------------------------------------------------------+
    bool IsButtonClick(string objectName)
    {
        return (objectName == "Button1" || objectName == "Button2" || 
                objectName == "Button3" || objectName == "Button_007" || // DODAJ
                objectName == "Button_BE");
    }
    
    //+------------------------------------------------------------------+
    //| Cleanup przy zamknięciu                                         |
    //+------------------------------------------------------------------+
    void Cleanup()
    {
        DeleteAllUIObjects();
        m_initialized = false;
        PrintDebug("UIManager: Cleanup completed");
    }
};

// Globalna instancja managera UI
CUIManager UI;
