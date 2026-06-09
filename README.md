# Splivy 💰

### Split smart. Settle easy. 🇵🇰

A Flutter expense-splitting app built for Pakistani users. Split bills with friends and groups, track who owes what, and settle up via JazzCash, Easypaisa, SadaPay, or NayaPay.

## Download

Grab the latest Android build from the [Releases page](https://github.com/Haidermushtaq/splivy/releases/latest) — install `app-release.apk` directly on your phone.

## Features

- Split expenses with friends and groups
- Equal and custom splits
- Multiple payers on a single expense
- Pay via JazzCash, Easypaisa, SadaPay, or NayaPay
- Upload payment screenshots as proof
- Smart reminders for pending payments
- Real-time expense sync across devices
- Archive settled expenses and view settlement history
- Dark and Light mode

## Tech Stack

- **Flutter / Dart** — cross-platform UI (Android & iOS)
- **Supabase** — auth, Postgres database, realtime, and storage
- **Riverpod** — state management
- **flutter_local_notifications** — payment reminders
- **Lottie** — animations

## Getting Started

### Prerequisites

- Flutter SDK (Dart `^3.10.0`)
- A Supabase project

### Setup

1. Clone the repo:
   ```bash
   git clone https://github.com/Haidermushtaq/splivy
   cd splivy
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Add a `.env` file in the project root with your Supabase credentials:
   ```
   SUPABASE_URL=your-project-url
   SUPABASE_ANON_KEY=your-anon-key
   ```
4. Run the app:
   ```bash
   flutter run
   ```

### Building a Release

```bash
flutter build apk --release        # APK for direct install
flutter build appbundle --release  # AAB for the Play Store
```

## Team

Haider Mushtaq • Mohsin Ashraf • Shumail Khan • Haider Zahoor

## Support

splivy.support@gmail.com

## Links

- Repository: [github.com/Haidermushtaq/splivy](https://github.com/Haidermushtaq/splivy)
- Releases: [github.com/Haidermushtaq/splivy/releases](https://github.com/Haidermushtaq/splivy/releases)
