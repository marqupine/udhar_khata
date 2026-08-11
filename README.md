# 🍊 Shree Balaji General Store - Udhar Khata

A modern, offline-first credit ledger and ledger book application built with **Flutter**, **Firebase Authentication**, and **Cloud Firestore**. Designed with a vibrant **Golden & Saffron** visual design system for effortless store debt tracking, payment settlement, and local security.

---

## ✨ Features

- **🔐 Firebase Authentication**: Secure Email/Password sign-in with persistent session handling.
- **☁️ Cloud Firestore Offline Sync**: Offline-first architecture with automatic background synchronization when internet is available.
- **🛡️ App Security Lock**: 4-digit MPIN and Biometric fingerprint/face unlock options with a 10–15 day interval setup prompt.
- **🎨 Golden & Saffron UI Theme**: Premium typography, glassmorphic container cards, custom keypad, and smooth animations.
- **⚡ FIFO Debt Settlement Engine**: Automatically applies partial/full payments to the oldest pending debt items first.
- **🧹 Auto-Purge Old Settled Records**: Automatically cleans up fully paid items and payment receipts older than 7 days while keeping pending debts 100% safe.
- **👤 Customer Management**: Store mandatory unique customer names, optional phone numbers, address details, and track "Added by User" info.

---

## 📱 Screenshots

| Sign-In Screen | Security MPIN Lock | Store Dashboard |
| :---: | :---: | :---: |
| *(Add Sign-In Screenshot here)* | *(Add MPIN Screenshot here)* | *(Add Dashboard Screenshot here)* |

| Customer Ledger Details | Add Borrowed Goods | Security Settings |
| :---: | :---: | :---: |
| *(Add Customer Details Screenshot here)* | *(Add Add Goods Screenshot here)* | *(Add Security Modal Screenshot here)* |

---

## 🛠️ Tech Stack & Dependencies

- **Framework**: Flutter (Dart)
- **Database & Auth**: `firebase_core`, `firebase_auth`, `cloud_firestore`
- **Security**: `local_auth` (Biometrics), `shared_preferences`
- **Design System**: Vanilla Material 3 with HSL Saffron & Royal Gold Palette

---

## 📦 How to Build Android Release APK

To generate an Android Release APK for GitHub Releases:

```bash
# 1. Fetch dependencies
flutter pub get

# 2. Build production APK
flutter build apk --release
```

The compiled APK will be located at:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 🚀 Getting Started Locally

1. Clone the repository:
   ```bash
   git clone https://github.com/marqupine/udhar_khata.git
   cd udhar_khata
   ```

2. Place your `google-services.json` into `android/app/google-services.json`.

3. Run in Chrome or Android:
   ```bash
   flutter run -d chrome
   ```
