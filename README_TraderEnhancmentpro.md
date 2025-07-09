# Trader Enhancement Pro Export HH5 - Zrefaktoryzowany Expert Advisor

## 📁 Struktura Projektu

```
TraderEnhancementPro/
├── shortcuts_exporthh5.mq5          # Główny plik EA
├── Include/                          # Folder z modułami
│   ├── Utils.mqh                    # Funkcje pomocnicze i utilities
│   ├── ConfigManager.mqh            # Zarządzanie konfiguracją i parametrami
│   ├── TradingManager.mqh           # Operacje tradingowe
│   ├── UIManager.mqh                # Interfejs użytkownika i skróty
│   ├── DatabaseManager.mqh          # Zarządzanie bazą danych SQLite
│   └── DrawingManager.mqh           # Obiekty rysowania na wykresie
└── README_REFACTORING.md            # Ten plik
```

## 🏗️ Architektura Modułowa

### **1. Utils.mqh** - Funkcje Pomocnicze
**Przeznaczenie:** Uniwersalne funkcje używane w całym projekcie

**Zawiera:**
- Enumy i stałe systemowe
- Funkcje konwersji i formatowania
- Funkcje matematyczne i walidacji
- Funkcje dla stringów i plików
- Logowanie i obsługa błędów

### **2. ConfigManager.mqh** - Konfiguracja
**Przeznaczenie:** Centralne zarządzanie wszystkimi parametrami

**Zawiera:**
- Wszystkie parametry input
- Zmienne globalne stanu
- Walidację konfiguracji
- Metody dostępowe

**Klasa:** `CConfigManager Config`

### **3. TradingManager.mqh** - Trading
**Przeznaczenie:** Wszystkie operacje związane z handlem

**Zawiera:**
- Wykonywanie zleceń (Market, Limit)
- Modyfikacje SL/TP (Break Even)
- Zarządzanie pozycjami
- Walidację przed wykonaniem zleceń

**Klasa:** `CTradingManager Trading`

### **4. UIManager.mqh** - Interfejs
**Przeznaczenie:** Obsługa przycisków, skrótów klawiszowych

**Zawiera:**
- Tworzenie przycisków
- Obsługę skrótów klawiszowych
- Tryb rysowania półprostych
- Aktualizację interfejsu

**Klasa:** `CUIManager UI`

**Skróty klawiszowe:**
- `1` - tryb rysowania półprostej
- `2,3` - rozmiary pozycji + aktywacja
- `C` - aktywacja/deaktywacja trybu akcji
- `B,S` - Buy/Sell Market
- `E,F` - modyfikacja SL/TP
- `R` - ustawienie TP na +0.5 punktu od ceny otwarcia
- `Q` - zamknięcie ostatniej pozycji
- `T` - usunięcie zleceń oczekujących
- `D` - usuwanie linii
- `H` - export do bazy danych

### **5. DatabaseManager.mqh** - Baza Danych
**Przeznaczenie:** Zarządzanie bazą SQLite, export świeczek

**Zawiera:**
- Inicjalizację bazy danych
- Tworzenie tabel
- Export świeczek i historii pozycji
- Statystyki bazy

**Klasa:** `CDatabaseManager Database`

### **6. DrawingManager.mqh** - Rysowanie
**Przeznaczenie:** Zarządzanie obiektami graficznymi

**Zawiera:**
- Overlay na świeczkach
- Linie poziome/pionowe
- Oznaczanie poziomów SL/TP
- Czyszczenie obiektów

**Klasa:** `CDrawingManager Drawing`

## 🔧 Jak Dodawać Nowe Funkcjonalności

### **Dodawanie Nowego Parametru Input**
1. **ConfigManager.mqh** - dodaj parametr `input`
2. Dodaj getter/setter w klasie `CConfigManager`
3. Rozszerz walidację jeśli potrzeba

### **Dodawanie Nowego Skrótu Klawiszowego**
1. **UIManager.mqh** - rozszerz `HandleKeyPress()`
2. Dodaj obsługę w odpowiednim managerze

### **Dodawanie Nowego Typu Zlecenia**
1. **TradingManager.mqh** - dodaj metodę `ExecuteNowyTyp()`
2. **UIManager.mqh** - dodaj obsługę w UI

## 📋 Konwencje

### **Nazewnictwo**
- Klasy: `CModuleName`
- Globalne instancje: `ModuleName`
- Metody prywatne: `m_nazwaMetody`
- Stałe: `UPPER_CASE`

### **Logowanie**
- `PrintDebug()` - informacje debugowe
- `LogError()` - błędy z nazwą funkcji
- `PlaySoundSafe()` - bezpieczne dźwięki

### **Zarządzanie Błędami**
- Każdy moduł ma `Initialize()` zwracającą `bool`
- Walidacja parametrów przed użyciem
- Graceful degradation

## 🚀 Przykłady Użycia

### **Dodanie Nowego Parametru**
```cpp
// ConfigManager.mqh
input double new_parameter = 1.5;

// W klasie CConfigManager
double GetNewParameter() { return new_parameter; }

// Użycie
double value = Config.GetNewParameter();
```

### **Dodanie Nowego Skrótu**
```cpp
// UIManager.mqh w HandleKeyPress()
case 71: // Klawisz G
    PrintDebug("Nowa akcja");
    break;
```

## 🔍 Debugowanie

### **Sprawdzenie Stanu Modułów**
- `Database.PrintDatabaseStats()` - statystyki bazy
- `Config.PrintConfiguration()` - konfiguracja
- `UI.ShowStatusInfo()` - status interfejsu

### **Najczęstsze Problemy**
1. Błąd inicjalizacji bazy - sprawdź ścieżkę
2. Przyciski nie działają - sprawdź nazwy obiektów
3. Skróty nie odpowiadają - sprawdź kody klawiszy

## 💡 Wskazówki dla AI Assistants

1. **Zawsze sprawdź strukturę modułową** - nie mieszaj logiki
2. **Używaj istniejących getterów/setterów**
3. **Dodawaj odpowiednie logowanie**
4. **Testuj inicjalizację**
5. **Dokumentuj zmiany**

### **Przykład Dodawania Funkcjonalności:**
```cpp
// 1. Określ który moduł odpowiada za funkcjonalność
// 2. Dodaj metodę w odpowiednim managerze
// 3. Dodaj obsługę w UI jeśli potrzeba
// 4. Dodaj parametry konfiguracyjne jeśli potrzeba
// 5. Przetestuj i dodaj logowanie
```

---

**Autor refaktoryzacji:** Claude AI Assistant  
**Data:** Czerwiec 2025  
**Wersja:** 2.0  
**Oryginalny kod:** shortcuts_exporthh5.mq5
