# SpendWise — Smart Budgeting & Subscription Hub 📱
A complete Material Design 3 personal finance and subscription tracking application built with Flutter.

---

## 🏗️ Architecture & Project Structure

The project has been organized following modern clean Flutter standards:

```text
SpendWise_Flutter/
├── pubspec.yaml                        # Project dependencies (Provider, Charts, Cupertino)
├── assets/                             # App icons and graphics
└── lib/
    ├── main.dart                       # App entry point & MultiProvider initialization
    │
    ├── theme/
    │   └── app_theme.dart              # Material 3 Theme & Figma Color Tokens (#1A365D, #10B981)
    │
    ├── models/
    │   └── models.dart                 # Data classes for Expense & Subscription entities
    │
    ├── services/
    │   └── finance_provider.dart       # State management (Safe-to-Spend logic, CRUD operations)
    │
    ├── widgets/
    │   └── quick_add_sheet.dart        # Screen 3: Material 3 Bottom Sheet with custom Numpad
    │
    └── screens/
        ├── onboarding_screen.dart      # Screen 1: Welcome & Currency selection
        ├── main_navigation.dart        # Android Material 3 NavigationBar coordinator
        ├── home_screen.dart            # Screen 2: Dashboard with Safe-to-Spend Hero Card
        ├── subscriptions_screen.dart   # Screen 4: Subscriptions Radar & countdowns
        ├── analytics_screen.dart       # Screen 5: Spending donut chart & savings target
        └── settings_screen.dart        # Screen 6: Biometrics, preferences, and report export
```

---

## 🚀 How to Run the App on Your Computer / Mobile

### Step 1: Open in VS Code
1. Open VS Code on your laptop.
2. Go to **File -> Open Folder...** and select:
   `C:\Users\Lenovo\Desktop\SpendWise_Flutter`

### Step 2: Install Flutter Extension (if not already added)
In VS Code, press `Ctrl + Shift + X`, search for **Flutter**, and click **Install**.

### Step 3: Run the App
Open the terminal inside VS Code (`Ctrl + ~`) and run:
```bash
flutter pub get
flutter run
```
*(You can select Chrome / Windows Desktop to preview it immediately on your screen, or connect your Android phone via USB!)*
