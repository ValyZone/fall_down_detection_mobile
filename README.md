# Fall Detection Mobile App

Flutter mobilalkalmazás motoros balesetek detektálására gyorsulásmérő és giroszkóp szenzorok segítségével.

> **Megjegyzés:** A projekt részletes dokumentációja külön dokumentumban található.

## Előfeltételek

- Flutter SDK (legújabb stabil verzió)
- Fizikai eszköz szenzorral (emulátor nem működik)
- Futó backend szerver

## Telepítés

1. **Függőségek telepítése:**
   ```bash
   flutter pub get
   ```

2. **Szerver URL konfigurálása:**

   Szerkeszd a `lib/config.dart` fájlt:
   ```dart
   static const String serverUrl = 'http://YOUR_SERVER_IP:3030';
   ```

3. **Alkalmazás futtatása:**
   ```bash
   flutter run
   ```

## Elérhető parancsok

### Fejlesztés

```bash
#Függőségek telepítése/frissítése
flutter pub get

# App futtatása fejlesztői módban, telefon legyen USB-vel csatlakoztatva
flutter run

```

### Build

```bash
# Android APK build
flutter build apk
```

### Tesztelés

```bash
# Unit tesztek futtatása
flutter test

# Tesztek futtatása lefedettségi jelentéssel
flutter test --coverage

# Specifikus teszt fájl futtatása
flutter test test/models/ring_buffer_test.dart
```

### Kód minőség

```bash
# Kód elemzés (lint)
flutter analyze
```

### Eszközök és diagnosztika

```bash
# Csatlakozott eszközök listája
flutter devices

# Flutter doktor (környezet ellenőrzése)
flutter doctor

# Alkalmazás tisztítása (build fájlok törlése)
flutter clean
```

### Hibakeresés

```bash
# Részletes logokkal való futtatás
flutter run -v

# Specifikus eszközön futtatás
flutter run -d <device-id>

# Debug információk megtekintése
flutter logs
```

## Függőségek

Az alkalmazás a következő főbb függőségeket használja:

- **sensors_plus**: Szenzor adatok (gyorsulásmérő, giroszkóp) olvasása
- **http**: HTTP kommunikáció a backend szerverrel
- **cupertino_icons**: iOS stílusú ikonok

A teljes függőségi lista a `pubspec.yaml` fájlban található.

## Első lépések

1. Telepítsd a függőségeket: `flutter pub get`
2. Konfiguráld a szerver URL-t a `lib/config.dart` fájlban
3. Csatlakoztass egy fizikai eszközt
4. Futtasd az alkalmazást: `flutter run`
5. Az alkalmazásban teszteld a szerver kapcsolatot a "Test Connection" gombbal

## Hibaelhárítás

**Nem tud csatlakozni a szerverhez:**
- Ellenőrizd, hogy a szerver fut-e
- Az eszköz és a szerver ugyanazon a hálózaton van-e
- A `config.dart` fájlban a helyes IP cím van-e beállítva

**Szenzorok nem működnek:**
- Csak fizikai eszközön működik (emulátornak nincsenek valós szenzorok)
- Ellenőrizd az alkalmazás engedélyeit
