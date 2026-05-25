# 📱 UPI Tracker

A cross-platform **Flutter** app that parses and tracks UPI SMS notifications — helping users monitor their UPI transactions (debits, credits, autopay deductions, and mandate creations) in one clean dashboard.

---

## 🧠 What It Does

Indian bank SMS alerts for UPI transactions follow a largely predictable format. UPI Tracker reads those messages, classifies them by transaction type, and presents a structured transaction history — all stored locally on the device using `shared_preferences`.

The app handles four UPI event types:

| Type | Description | Example Merchant |
|------|-------------|-----------------|
| `debit` | Money sent via UPI | Swiggy, IRCTC, Rent |
| `credit` | Money received via UPI | Friends, Office reimbursement |
| `autopay` | Recurring UPI AutoPay deduction | Spotify, Airtel, Netflix |
| `mandate` | UPI AutoPay mandate creation | Google Cloud, Hotstar, YouTube |

---

## 🛠 Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.35+ |
| Language | Dart 3.11+ |
| Local Storage | `shared_preferences ^2.2.2` |
| UI | Material Design 3 (Flutter) |
| Platform Targets | Android, iOS, Web, Windows, macOS, Linux |

---

## 📂 Project Structure

```
upi-tracker/
├── lib/                    # Dart source code
├── android/                # Android platform files
├── ios/                    # iOS platform files
├── web/                    # Web platform files
├── windows/                # Windows platform files
├── macos/                  # macOS platform files
├── linux/                  # Linux platform files
├── test/                   # Unit & widget tests
├── samples.json            # 50 sample UPI SMS messages for testing/demo
├── pubspec.yaml            # Dependencies & app metadata
└── analysis_options.yaml   # Dart linting rules
```

---

## 📋 Sample Data

The repo ships with `samples.json` — a set of 50 realistic UPI SMS messages covering:

- Transactions across multiple bank SMS senders (`VK-HDFCBK`, `AX-SBIUPI`, `VM-ICICIB`)
- Merchants like Swiggy, Zomato, Blinkit, Netflix, IRCTC, BigBasket, Ola, and more
- AutoPay mandates for Spotify, YouTube Premium, Airtel Postpaid, ACT Fibernet, JioCinema, Hotstar, PhonePe Insurance, and Google Cloud
- Both Ujjivan SFB account credits and debits with reference numbers and available balance

This data is used for local development and UI testing without needing real SMS access.

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) ≥ 3.35.0
- Dart ≥ 3.11.5
- Android Studio / Xcode (for mobile targets) or a web browser (for web target)

### Installation

```bash
# Clone the repo
git clone https://github.com/NamTheGreat/upi-tracker.git
cd upi-tracker

# Install dependencies
flutter pub get

# Run on your connected device / emulator
flutter run
```

### Build for Specific Platforms

```bash
flutter build apk          # Android APK
flutter build ios          # iOS (requires Mac + Xcode)
flutter build web          # Web
flutter build windows      # Windows desktop
```

---

## 📦 Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  shared_preferences: ^2.2.2   # Local persistent storage
  cupertino_icons: ^1.0.8      # iOS-style icons

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0        # Dart/Flutter lint rules
```

---

## 🔮 Planned Features

- [ ] SMS permission integration to auto-read UPI messages on Android
- [ ] Spending analytics dashboard (monthly summaries, category breakdown)
- [ ] AutoPay/mandate calendar view
- [ ] Export transactions as CSV
- [ ] Filter & search by merchant, amount, or date

---

## 👤 Author

**Naman** — [@NamTheGreat](https://github.com/NamTheGreat)

---

## 📄 License

This project is not currently licensed. Contact the author for usage permissions.
