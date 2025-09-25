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
    datetime lastButtonClickTime;
    
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
    CUIManager() : m_initialized(false), lastButtonClickTime(0),
                   previousPositionSize(0), previousMagicNumber(0), previousActiveButton("") {}
    ~CUIManager() {}
    
    //+------------------------------------------------------------------+
    //| Inicjalizacja UI managera                                       |
    //+------------------------------------------------------------------+
    bool Initialize()
    {
        if(m_initialized) return true;
        
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
        CreateButton("Button1", DoubleToStringFormatted(Config.GetDefaultSize()), button_x_start, button_y_position, clrDarkGray);
        ObjectSetInteger(0, "Button1", OBJPROP_STATE, 1);
        
        CreateButton("Button2", DoubleToStringFormatted(Config.GetButton2Size()), button_x_start + button_spacing, button_y_position, clrDarkGray);
        CreateButton("Button3", DoubleToStringFormatted(Config.GetButton3Size()), button_x_start + button_spacing * 2, button_y_position, clrDarkGray);
        CreateButton("Button_007", "?? " + DoubleToStringFormatted(Config.GetButton007Size()), button_x_start + button_spacing * 3, button_y_position, clrGold);
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
    //| Obsługa kliknięcia przycisku                                    |
    //+------------------------------------------------------------------+
    void HandleButtonClick(string buttonName)
    {
        lastButtonClickTime = TimeCurrent();
        
        if(buttonName == "Button1")
        {
            Config.SetPositionSize(Config.GetDefaultSize());
            Config.SetMagicNumber(0);
            SetActiveButton("Button1");
        }
        else if(buttonName == "Button2")
        {
            Config.SetPositionSize(Config.GetButton2Size());
            Config.SetMagicNumber(0);
            SetActiveButton("Button2");
        }
        else if(buttonName == "Button3")
        {
            Config.SetPositionSize(Config.GetButton3Size());
            Config.SetMagicNumber(0);
            SetActiveButton("Button3");
        }
        else if(buttonName == "Button_007")
        {
            previousPositionSize = Config.GetPositionSize();
            previousMagicNumber = Config.GetMagicNumber();
            previousActiveButton = GetActiveButton();
            
            Config.SetPositionSize(Config.GetButton007Size());
            Config.SetMagicNumber(7);
            Config.SetTakeAction(true, "Magic007");
            SetActiveButton("Button_007");
            PlaySoundSafe(Config.GetSoundOK());
        }
        else if(buttonName == "Button_BE")
        {
            Trading.ModifyStopLoss();
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
        return "Button1";
    }
    
    //+------------------------------------------------------------------+
    //| Ustawienie aktywnego przycisku                                  |
    //+------------------------------------------------------------------+
    void SetActiveButton(string activeButton)
    {
        ObjectSetInteger(0, "Button1", OBJPROP_STATE, 0);
        ObjectSetInteger(0, "Button2", OBJPROP_STATE, 0);
        ObjectSetInteger(0, "Button3", OBJPROP_STATE, 0);
        ObjectSetInteger(0, "Button_007", OBJPROP_STATE, 0);
        
        ObjectSetInteger(0, activeButton, OBJPROP_STATE, 1);
    }
    
    //+------------------------------------------------------------------+
    //| Obsługa kliknięcia na wykresie                                  |
    //+------------------------------------------------------------------+
    void HandleChartClick(long lparam, double dparam)
    {
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
        
        if(Config.GetTakeAction())
        {
            HandleTradingClick(price_on_click);
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
            success = Trading.ExecuteBuyLimit(price_on_click);
        }
        else if(Ask < price_on_click)
        {
            success = Trading.ExecuteSellLimit(price_on_click);
        }
        
        if(success)
        {
            Config.SetTakeAction(false);
            
            if(Config.GetMagicNumber() == 7)
            {
                Config.SetPositionSize(previousPositionSize);
                Config.SetMagicNumber(previousMagicNumber);
                SetActiveButton(previousActiveButton);
            }
            else
            {
                Config.SetMagicNumber(0);
            }
        }
    }
    
    //+------------------------------------------------------------------+
    //| Obsługa naciśnięć klawiszy                                      |
    //+------------------------------------------------------------------+
    void HandleKeyPress(long lparam)
    {
        int keyCode = (int)lparam;
        PrintDebug("HandleKeyPress: kod klawisza " + IntegerToString(keyCode));
        
        // Rozmiar pozycji 2 + aktywacja
        if(keyCode == Config.GetKeySize2())
        {
            Config.SetPositionSize(Config.GetButton2Size());
            SetActiveButton("Button2");
            Config.SetTakeAction(true, "Size2");
        }
        // Rozmiar pozycji 3 + aktywacja
        else if(keyCode == Config.GetKeySize3())
        {
            Config.SetPositionSize(Config.GetButton3Size());
            SetActiveButton("Button3");
            Config.SetTakeAction(true, "Size3");
        }
        // Aktywacja przycisku 007
        else if(keyCode == Config.GetKey007())
        {
            previousPositionSize = Config.GetPositionSize();
            previousMagicNumber = Config.GetMagicNumber();
            previousActiveButton = GetActiveButton();
            
            Config.SetPositionSize(Config.GetButton007Size());
            Config.SetMagicNumber(7);
            Config.SetTakeAction(true, "Magic007_Key");
            SetActiveButton("Button_007");
            PlaySoundSafe(Config.GetSoundOK());
        }
        // Aktywacja/deaktywacja limit
        else if(keyCode == Config.GetKeyToggleLimit())
        {
            Config.SetMagicNumber(0);
            if(Config.GetTakeAction())
            {
                Config.SetTakeAction(false);
            }
            else
            {
                Config.SetTakeAction(true, "Manual");
            }
        }
        // Buy Market
        else if(keyCode == Config.GetKeyBuyMarket())
        {
            Config.SetMagicNumber(2);
            Trading.DeleteAllPendingOrders();
            Trading.ExecuteBuyMarket();
            Config.SetMagicNumber(0);
        }
        // Sell Market
        else if(keyCode == Config.GetKeySellMarket())
        {
            Config.SetMagicNumber(3);
            Trading.DeleteAllPendingOrders();
            Trading.ExecuteSellMarket();
            Config.SetMagicNumber(0);
        }
        // Przesunięcie BE
        else if(keyCode == Config.GetKeyModifyBE())
        {
            Trading.ModifyStopLoss();
        }
        // Przesunięcie TP
        else if(keyCode == Config.GetKeyModifyTP())
        {
            Trading.ModifyTakeProfit();
        }
        // Zamknięcie ostatniej pozycji
        else if(keyCode == Config.GetKeyCloseLast())
        {
            Trading.CloseLastPosition();
        }
        // Usunięcie zleceń oczekujących
        else if(keyCode == Config.GetKeyDeletePending())
        {
            Trading.DeleteAllPendingOrders();
        }
        // TP na +0.5 punktu
        else if(keyCode == Config.GetKeyTPHalfPoint())
        {
            Trading.SetTPToHalfPoint();
        }
    }
    
    //+------------------------------------------------------------------+
    //| Wyświetlenie informacji o statusie                              |
    //+------------------------------------------------------------------+
    void ShowStatusInfo()
    {
        string info = "Data przerwy: " + Config.GetPrzerrwaDoString();
        Comment(info);
    }
    
    //+------------------------------------------------------------------+
    //| Aktualizacja etykiet przycisków                                 |
    //+------------------------------------------------------------------+
    void UpdateButtonLabels()
    {
        ObjectSetString(0, "Button1", OBJPROP_TEXT, DoubleToStringFormatted(Config.GetDefaultSize()));
        ObjectSetString(0, "Button2", OBJPROP_TEXT, DoubleToStringFormatted(Config.GetButton2Size()));
        ObjectSetString(0, "Button3", OBJPROP_TEXT, DoubleToStringFormatted(Config.GetButton3Size()));
        ObjectSetString(0, "Button_007", OBJPROP_TEXT, "?? " + DoubleToStringFormatted(Config.GetButton007Size()));
    }
    
    //+------------------------------------------------------------------+
    //| Aktualizacja interfejsu                                         |
    //+------------------------------------------------------------------+
    void UpdateInterface()
    {
        UpdateButtonLabels();
        ShowStatusInfo();
        
        if(Config.GetTakeAction())
        {
            ObjectSetInteger(0, "Button1", OBJPROP_BORDER_COLOR, clrRed);
            ObjectSetInteger(0, "Button2", OBJPROP_BORDER_COLOR, clrRed);
            ObjectSetInteger(0, "Button3", OBJPROP_BORDER_COLOR, clrRed);
            ObjectSetInteger(0, "Button_007", OBJPROP_BORDER_COLOR, clrRed);
        }
        else
        {
            ObjectSetInteger(0, "Button1", OBJPROP_BORDER_COLOR, clrBlue);
            ObjectSetInteger(0, "Button2", OBJPROP_BORDER_COLOR, clrBlue);
            ObjectSetInteger(0, "Button3", OBJPROP_BORDER_COLOR, clrBlue);
            ObjectSetInteger(0, "Button_007", OBJPROP_BORDER_COLOR, clrBlue);
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
        ObjectDelete(0, "Button_007");
        ObjectDelete(0, "Button_BE");
        Comment("");
        
        PrintDebug("Usunięto wszystkie obiekty UI");
    }
    
    //+------------------------------------------------------------------+
    //| Sprawdzenie czy kliknięto na przycisk                           |
    //+------------------------------------------------------------------+
    bool IsButtonClick(string objectName)
    {
        return (objectName == "Button1" || objectName == "Button2" || 
                objectName == "Button3" || objectName == "Button_007" || 
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
