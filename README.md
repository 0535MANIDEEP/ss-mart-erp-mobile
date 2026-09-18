<div align="center">

# SS MART ERP Mobile

### Flutter Mobile/Desktop Client for SS MART Retail ERP

**A cross-platform Flutter app with offline-first architecture, SQLite local storage, and background synchronization — built for Indian retail operations.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-blue)](LICENSE)

</div>

---

## Overview

This is the Flutter mobile/desktop client for the SS MART retail ERP system. It provides a native interface for billing, inventory, customer management, and more — all working offline with background sync to the .NET backend.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x |
| Language | Dart 3.x |
| Local DB | SQLite + Drift (type-safe ORM) |
| State | BLoC/Cubit pattern |
| DI | GetIt + Injectable |
| HTTP | Dio |
| Auth | JWT stored in secure storage |

## Features

- **Offline-First** — all operations work without internet
- **21 Feature Modules** — comprehensive retail coverage
- **SQLite Local Storage** — fast, reliable local database
- **Background Sync** — queue-based synchronization when online
- **Biometric Auth** — fingerprint/face unlock
- **Barcode Scanner** — scan products for quick lookup
- **GST Support** — CGST/SGST/IGST calculations
- **Thermal Printing** — ESC/POS receipt printing
- **Cross-Platform** — Android, iOS, Windows, macOS, Linux

## Modules

| Module | Description |
|--------|-------------|
| auth | Login, register, biometric unlock |
| billing | Invoice creation, GST, payments |
| inventory | Stock management, low-stock alerts |
| products | Product CRUD, categories, search |
| customers | Customer profiles, CRM |
| purchases | Purchase orders, receiving |
| suppliers | Supplier management |
| employees | Staff management, roles |
| expenses | Expense tracking |
| loyalty | Points earn/redeem |
| accounting | Financial reports, profit/loss |
| reports | Sales analytics, charts |
| orders | Sales orders management |
| challans | Delivery challans |
| payments | Payment tracking |
| labels | Barcode/QR label generation |
| scanner | Barcode scanner integration |
| settings | Store configuration |
| sync | Offline data synchronization |
| dashboard | Overview with key metrics |
| import_export | Data import/export |

## Getting Started

### Prerequisites

- Flutter 3.x SDK
- Dart 3.x
- Android Studio / VS Code
- Chrome (for web), Android emulator, or physical device

### Setup

```bash
# Clone the repository
git clone https://github.com/0535MANIDEEP/ss-mart-erp-mobile.git
cd ss-mart-erp-mobile

# Get dependencies
flutter pub get

# Run on connected device
flutter run

# Build release APK
flutter build apk --release

# Build for web
flutter build web
```

### Project Structure

```
lib/
├── core/               # Shared utilities, constants, theme
├── database/           # SQLite/Drift database, DAOs, migrations
├── features/           # Feature modules (21 total)
│   ├── auth/
│   ├── billing/
│   ├── inventory/
│   ├── products/
│   └── ...
├── injection/          # Dependency injection setup
├── routes/             # Navigation routes
├── shared/             # Shared widgets, models
├── app.dart            # App configuration
└── main.dart           # Entry point
```

## Related Repos

| Repo | Description |
|------|-------------|
| [ss-mart-erp](https://github.com/0535MANIDEEP/ss-mart-erp) | Architecture docs & system design |
| [ss-mart-erp-backend](https://github.com/0535MANIDEEP/ss-mart-erp-backend) | .NET 8 REST API server |

## Author

**Manideep Daram** — [GitHub](https://github.com/0535MANIDEEP) · [Email](mailto:darammanideep@gmail.com)
