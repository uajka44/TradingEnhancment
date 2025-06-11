//+------------------------------------------------------------------+
//|                                            DrawingManager.mqh     |
//|                                       Zarządzanie obiektami rysowania|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property strict

#include "Utils.mqh"
#include "ConfigManager.mqh"

//+------------------------------------------------------------------+
//| KLASA DrawingManager - Zarządzanie rysowaniem                    |
//+------------------------------------------------------------------+
class CDrawingManager
{
private:
    bool m_initialized;
    
public:
    CDrawingManager() : m_initialized(false) {}
    ~CDrawingManager() {}
    
    //+------------------------------------------------------------------+
    //| Inicjalizacja drawing managera                                  |
    //+------------------------------------------------------------------+
    bool Initialize()
    {
        if(m_initialized) return true;
        
        // Jednorazowe usunięcie istniejących linii SL/TP
        CleanupExistingSLTPLines();
        
        m_initialized = true;
        PrintDebug("DrawingManager zainicjalizowany pomyślnie (rysowanie SL/TP wyłączone)");
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Rysowanie overlay na ostatniej świeczce                         |
    //+------------------------------------------------------------------+
    void DrawOverlayOnLastCandle(string name = "CandleCover", color clr = clrBlack, int opacity = 150)
    {
        ChartSetInteger(0, CHART_SHOW_BID_LINE, false);
        datetime times[2];
        double high[2], low[2];

        if(CopyTime(_Symbol, PERIOD_CURRENT, 0, 2, times) != 2) return;
        if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, 2, high) != 2) return;
        if(CopyLow(_Symbol, PERIOD_CURRENT, 0, 2, low) != 2) return;

        double midPrice = (high[0] + low[0]) / 2.0;

        int x1, y1, x2, y2;
        if(!ChartTimePriceToXY(0, 0, times[0], midPrice, x1, y1)) return;
        if(!ChartTimePriceToXY(0, 0, times[1], midPrice, x2, y2)) return;

        int candle_width = MathAbs(x1 - x2);

        ObjectDelete(0, name);

        if(ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
        {
            ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x1 + candle_width / 2);
            ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 0);
            ObjectSetInteger(0, name, OBJPROP_XSIZE, candle_width);
            ObjectSetInteger(0, name, OBJPROP_YSIZE, 1000);
            ObjectSetInteger(0, name, OBJPROP_COLOR, ColorToARGB(clr, opacity));
            ObjectSetInteger(0, name, OBJPROP_BACK, false);
            
            PrintDebug("Nałożono overlay na ostatnią świeczkę");
        }
    }
    
    //+------------------------------------------------------------------+
    //| Usunięcie overlay z ostatniej świeczki - ZAKOMENTOWANE        |
    //+------------------------------------------------------------------+
    void DeleteOverlayOnLastCandle(string name = "CandleCover")
    {
        // FUNKCJA ZAKOMENTOWANA - SPRAWDZENIE CZY JEST WYWOŁYWANA
        PrintDebug("UWAGA! DeleteOverlayOnLastCandle() została wywołana! - funkcja zakomentowana");
        PlaySoundSafe("expert.wav"); // Dźwięk ostrzeżenia
        return; // Nie wykonuj reszty funkcji
        
        
        ObjectDelete(0, name);
        ChartSetInteger(0, CHART_SHOW_BID_LINE, true);
        PrintDebug("Usunięto overlay ze świeczki");
        
    }
    
    //+------------------------------------------------------------------+
    //| Rysowanie linii poziomej                                        |
    //+------------------------------------------------------------------+
    bool DrawHorizontalLine(string name, double price, color lineColor = clrRed, int lineWidth = 1, ENUM_LINE_STYLE lineStyle = STYLE_SOLID)
    {
        ObjectDelete(0, name);
        
        if(ObjectCreate(0, name, OBJ_HLINE, 0, 0, price))
        {
            ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, lineWidth);
            ObjectSetInteger(0, name, OBJPROP_STYLE, lineStyle);
            ObjectSetString(0, name, OBJPROP_TEXT, name + " @ " + DoubleToStringFormatted(price));
            
            PrintDebug("Narysowano linię poziomą: " + name);
            return true;
        }
        
        LogError("Nie można narysować linii poziomej: " + name, "DrawHorizontalLine");
        return false;
    }
    
    //+------------------------------------------------------------------+
    //| Oznaczenie poziomów SL/TP na wykresie - USUNIĘTE                  |
    //+------------------------------------------------------------------+
    void MarkSLTPLevels()
    {
        // FUNKCJA USUNIĘTA - nie rysuje już linii SL/TP
        // PrintDebug("MarkSLTPLevels() - funkcja dezaktywowana");
        return;
        
        /*
        // Usuń istniejące oznaczenia
        DeleteSLTPLevels();
        
        int positions_count = PositionsTotal();
        
        for(int i = 0; i < positions_count; i++)
        {
            if(PositionSelectByTicket(PositionGetTicket(i)))
            {
                double sl = PositionGetDouble(POSITION_SL);
                double tp = PositionGetDouble(POSITION_TP);
                string symbol = PositionGetString(POSITION_SYMBOL);
                ulong ticket = PositionGetInteger(POSITION_TICKET);
                
                if(symbol == _Symbol)
                {
                    // Oznacz SL
                    if(sl > 0)
                    {
                        string sl_name = "SL_" + IntegerToString(ticket);
                        DrawHorizontalLine(sl_name, sl, clrRed, 2, STYLE_DOT);
                    }
                    
                    // Oznacz TP
                    if(tp > 0)
                    {
                        string tp_name = "TP_" + IntegerToString(ticket);
                        DrawHorizontalLine(tp_name, tp, clrGreen, 2, STYLE_DOT);
                    }
                }
            }
        }
        
        if(positions_count > 0)
        {
            PrintDebug("Oznaczono poziomy SL/TP dla " + IntegerToString(positions_count) + " pozycji");
        }
        */
    }
    
    //+------------------------------------------------------------------+
    //| Usunięcie oznaczeń SL/TP - USUNIĘTE                          |
    //+------------------------------------------------------------------+
    void DeleteSLTPLevels()
    {
        // FUNKCJA USUNIĘTA - nie usuwa już linii SL/TP
        // PrintDebug("DeleteSLTPLevels() - funkcja dezaktywowana");
        return;
        
        /*
        // Usuń wszystkie linie SL/TP
        for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
        {
            string obj_name = ObjectName(0, i);
            if(StringFind(obj_name, "SL_") == 0 || StringFind(obj_name, "TP_") == 0)
            {
                ObjectDelete(0, obj_name);
            }
        }
        */
    }
    
    //+------------------------------------------------------------------+
    //| JEDNORAZOWE usunięcie istniejących linii SL/TP                  |
    //+------------------------------------------------------------------+
    void CleanupExistingSLTPLines()
    {
        int removed = 0;
        
        // Usuń wszystkie istniejące linie SL/TP
        for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
        {
            string obj_name = ObjectName(0, i);
            if(StringFind(obj_name, "SL_") == 0 || StringFind(obj_name, "TP_") == 0)
            {
                ObjectDelete(0, obj_name);
                removed++;
            }
        }
        
        if(removed > 0)
        {
            ChartRedraw();
            PrintDebug("Usunięto " + IntegerToString(removed) + " istniejących linii SL/TP");
        }
    }
    
    //+------------------------------------------------------------------+
    //| Czyszczenie wszystkich obiektów rysowania                      |
    //+------------------------------------------------------------------+
    void ClearAllDrawingObjects()
    {
        int total = ObjectsTotal(0);
        
        for(int i = total - 1; i >= 0; i--)
        {
            string obj_name = ObjectName(0, i);
            
            // Nie usuwaj przycisków UI
            if(StringFind(obj_name, "Button") != 0)
            {
                ObjectDelete(0, obj_name);
            }
        }
        
        ChartRedraw();
        PrintDebug("Usunięto wszystkie obiekty rysowania (z wyjątkiem przycisków)");
    }
    
    //+------------------------------------------------------------------+
    //| Czyszczenie tylko obiektów użytkownika                         |
    //+------------------------------------------------------------------+
    void ClearUserObjects()
    {
        int total = ObjectsTotal(0);
        
        for(int i = total - 1; i >= 0; i--)
        {
            string obj_name = ObjectName(0, i);
            
            // Usuń tylko obiekty zaczynające się od AutoRay
            if(StringFind(obj_name, "AutoRay") == 0)
            {
                ObjectDelete(0, obj_name);
            }
        }
        
        ChartRedraw();
        PrintDebug("Usunięto obiekty użytkownika (AutoRay)");
    }
    
    //+------------------------------------------------------------------+
    //| Sprawdzenie czy obiekt istnieje                                 |
    //+------------------------------------------------------------------+
    bool ObjectExists(string name)
    {
        return ObjectFind(0, name) >= 0;
    }
    
    //+------------------------------------------------------------------+
    //| Cleanup przy zamknięciu                                         |
    //+------------------------------------------------------------------+
    void Cleanup()
    {
        // WYKOMENTOWANE: Usuń poziomy SL/TP (funkcja już nie działa)
        // DeleteSLTPLevels();
        
        // ZAKOMENTOWANE: Usuń overlay jeśli istnieje
        // DeleteOverlayOnLastCandle(); // <-- WYKOMENTOWANE NA CZAS TESTÓW
        
        m_initialized = false;
        PrintDebug("DrawingManager: Cleanup completed (SL/TP rysowanie wyłączone)");
    }
};

// Globalna instancja managera rysowania
CDrawingManager Drawing;
